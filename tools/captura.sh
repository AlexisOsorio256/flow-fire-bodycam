#!/usr/bin/env bash
# captura.sh: captura frames REALES del juego para mirarlos.
#
#   tools/captura.sh downrange
#   tools/captura.sh empty --warmup=20 --total=14 --stride=3 --time-scale=0.2
#   tools/captura.sh evidencia     <- TODA la lista de evidencia, de una vez
#
# Los argumentos van en forma --clave=valor: Godot parte su
# get_cmdline_user_args() por espacios, asi que "--out X" llega como dos
# elementos y el parser lo ignora en silencio.
#
# `SHOT_OUT=... tools/captura.sh accion` escribe en otra carpeta. Hace falta para
# capturar la MISMA accion dos veces con parametros distintos (disparo normal y
# disparo a camara lenta), que es lo que pide la lista de evidencia.
#
# Display por defecto :0 (GPU real del usuario). ESO ABRE VENTANA: es la unica
# forma de capturar a su resolucion. En :77 (Xvfb) no abre nada pero renderiza
# con llvmpipe.
set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"
cd "$(dirname "$0")/.."
ACTION="${1:-downrange}"; shift || true
DISP="${SHOT_DISPLAY:-:0}"
RES="${SHOT_RES:-1920x1080}"

fatal_log() {
  grep -Eq "SCRIPT ERROR|Parse Error|Could not preload resource file|referenced non-existent resource|Failed to load resource" "$1"
}

preflight_import() {
  local log
  log="$(mktemp /tmp/flowfire_import.XXXXXX.log)"
  if ! godot4 --headless --path . --editor --quit >"$log" 2>&1; then
    cat "$log"
    rm -f "$log"
    echo "CAPTURE ERROR: fallo la importacion previa de Godot" >&2
    return 1
  fi
  if fatal_log "$log"; then
    grep -E "SCRIPT ERROR|Parse Error|Could not preload resource file|referenced non-existent resource|Failed to load resource" "$log" >&2 || true
    rm -f "$log"
    echo "CAPTURE ERROR: import/parser invalido; no se generan capturas" >&2
    return 1
  fi
  rm -f "$log"
}

run() {
  local action="$1"; shift
  local out="${SHOT_OUT:-captures/shot/$action}"
  local log
  rm -rf "$out"; mkdir -p "$out"
  log="$(mktemp /tmp/flowfire_capture.XXXXXX.log)"
  if ! DISPLAY="$DISP" timeout 1800 godot4 --path . --resolution "$RES" tools/shot.tscn -- \
    "--action=$action" "--out=$out" "$@" 2>&1 \
    >"$log"; then
    cat "$log"
    rm -f "$log"
    echo "CAPTURE ERROR: Godot no termino correctamente ($action)" >&2
    return 1
  fi
  grep -E "^SHOT|^RANGE|^ARMA|SCRIPT ERROR|Parse Error" "$log" || true
  if fatal_log "$log"; then
    grep -E "SCRIPT ERROR|Parse Error|Could not preload resource file|referenced non-existent resource|Failed to load resource" "$log" >&2 || true
    rm -f "$log"
    echo "CAPTURE ERROR: frame invalido por error de runtime/import ($action)" >&2
    return 1
  fi
  local frames
  frames="$(find "$out" -maxdepth 1 -type f -name 'f_*.png' | wc -l)"
  rm -f "$log"
  if [ "$frames" -eq 0 ]; then
    echo "CAPTURE ERROR: no se genero ningun PNG ($action)" >&2
    return 1
  fi
  echo "frames -> $out ($frames)"
}

preflight_import || exit 1

# LA LISTA DE EVIDENCIA COMPLETA, en un solo comando. No es una comodidad: es la
# diferencia entre "el asset se exporto" y "mire lo que dibuja el juego". Cada
# entrada esta aqui porque hubo una pasada que declaro algo sin mirarlo.
if [ "$ACTION" = "evidencia" ]; then
  run downrange --warmup=40 --total=2 || exit 1                                  # HIP
  run ads       --warmup=40 --total=2 || exit 1                                  # ADS
  run fire      --warmup=40 --total=48 --stride=2 --time-scale=1.0 || exit 1     # disparo normal
  # En ADS el arma esta a 0,44 m del ojo y el brazo pasa justo por debajo: es el
  # estado donde mas facil es que la mano tape la boca. Se captura aparte.
  ( SHOT_OUT=captures/shot/ads_fire \
    run ads_fire --warmup=40 --total=8 --time-scale=0.06 ) || exit 1   # fogonazo apuntando
  # En SUBSHELL: `SHOT_OUT=x run ...` sobre una funcion deja la variable puesta
  # en el shell actual y la siguiente accion escribiria en la carpeta equivocada.
  ( SHOT_OUT=captures/shot/fire_slow \
    run fire    --warmup=40 --total=8  --time-scale=0.06 ) || exit 1   # fogonazo/humo/casquillo
  run empty     --warmup=20 --total=24 --stride=6 --time-scale=1.0 || exit 1     # ultimo tiro, bloqueo
  run reload    --warmup=40 --total=140 --stride=7 --time-scale=1.0 || exit 1    # recarga
  run reload_empty --warmup=40 --total=150 --stride=8 --time-scale=1.0 || exit 1 # recarga en seco
  run inspect   --warmup=40 --total=126 --stride=6 --time-scale=1.0 || exit 1    # recamara
  run steel     --warmup=40 --total=18 --stride=3 --time-scale=0.5 || exit 1     # impactos por material
  run aluminum  --warmup=40 --total=18 --stride=3 --time-scale=0.5 || exit 1
  run wood      --warmup=40 --total=18 --stride=3 --time-scale=0.5 || exit 1
  run drywall   --warmup=40 --total=18 --stride=3 --time-scale=0.5 || exit 1
  echo
  echo "Ahora MIRALAS. Una captura que nadie abre no es evidencia."
  exit 0
fi

# Los MP4 son 1920x1080 / 30 FPS por construccion (x11grab -framerate 30):
# documentar 60 es mentir (paso: el handoff afirmo 60 con ficheros de 30).
# El juego arranca PRIMERO y ffmpeg despues: grabar antes solo capturaba
# escritorio + arranque de Godot (medido: 5,5 s de basura en hero_normal,
# 7,5 s en hero_slow). Sin arquitectura nueva: fondo + espera fija.
record_hero() {
  local action="$1"; local out="$2"; local extra="$3"; local espera="$4"
  shift 4
  local game_log
  game_log="$(mktemp /tmp/flowfire_hero.XXXXXX.log)"
  rm -f "$out"
  echo "Grabando video $action en $out..."
  DISPLAY="$DISP" godot4 --path . --resolution "$RES" tools/shot.tscn -- \
    "--action=$action" $extra "$@" > "$game_log" 2>&1 &
  local game_pid=$!
  sleep "$espera"
  if ! kill -0 "$game_pid" 2>/dev/null; then
    wait "$game_pid" 2>/dev/null || true
    cat "$game_log"
    rm -f "$game_log"
    echo "CAPTURE ERROR: el juego termino antes de iniciar video ($action)" >&2
    return 1
  fi
  ffmpeg -y -f x11grab -video_size "$RES" -framerate 30 -i "$DISP.0" \
    -f pulse -i alsa_output.pci-0000_00_1f.3.analog-stereo.monitor \
    -c:v libx264 -preset veryfast -pix_fmt yuv420p -c:a aac "$out" > /dev/null 2>&1 &
  local ffmpeg_pid=$!
  if ! wait "$game_pid"; then
    kill -INT "$ffmpeg_pid" 2>/dev/null || true
    wait "$ffmpeg_pid" 2>/dev/null || true
    cat "$game_log"
    rm -f "$game_log"
    echo "CAPTURE ERROR: Godot fallo durante video ($action)" >&2
    return 1
  fi
  if fatal_log "$game_log"; then
    grep -E "SCRIPT ERROR|Parse Error|Could not preload resource file|referenced non-existent resource|Failed to load resource" "$game_log" >&2 || true
    kill -INT "$ffmpeg_pid" 2>/dev/null || true
    wait "$ffmpeg_pid" 2>/dev/null || true
    rm -f "$game_log"
    echo "CAPTURE ERROR: runtime/import invalido durante video ($action)" >&2
    return 1
  fi
  rm -f "$game_log"
  kill -INT "$ffmpeg_pid" 2>/dev/null || true
  wait "$ffmpeg_pid" 2>/dev/null || true
  if [ ! -s "$out" ]; then
    echo "CAPTURE ERROR: ffmpeg no genero video ($action)" >&2
    return 1
  fi
  echo "Video listo: $out ($(ls -lh "$out" 2>/dev/null | awk '{print $5}'))"
  if ! ffprobe -v error -select_streams v:0 \
    -show_entries stream=width,height,avg_frame_rate,duration \
    -of default=noprint_wrappers=1 "$out"; then
    echo "CAPTURE ERROR: video ilegible para ffprobe ($action)" >&2
    return 1
  fi
}

if [ "$ACTION" = "record_normal" ]; then
  OUT="${SHOT_OUT:-captures/hero_normal.mp4}"
  record_hero "hero_normal" "$OUT" "" 2.5 "$@" || exit 1
  exit 0
fi

if [ "$ACTION" = "record_slow" ]; then
  OUT="${SHOT_OUT:-captures/hero_slow.mp4}"
  record_hero "hero_slow" "$OUT" "--time-scale=0.08" 3 "$@" || exit 1
  exit 0
fi

run "$ACTION" "$@" || exit 1
