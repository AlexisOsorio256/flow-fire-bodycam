#!/usr/bin/env bash
# medir.sh: benchmark del RENDER real y desglose por subsistema.
#
#   tools/medir.sh perfil   # desglose (luces / sombras / mundo / glow / hud)
#   tools/medir.sh base     # una sola pasada
#
# Display por defecto :0 (la GPU del usuario, que es el unico numero honesto).
# OJO: en :0 ABRE VENTANA, aunque sea de 64x64 y fuera de pantalla.
# En :77 (Xvfb) no abre nada pero la GPU es llvmpipe y los FPS no valen.
#
# NO lanzar dos instancias a la vez: comparten GPU y el frame time se dispara a
# un multiplo del vsync (se midio 133,333 ms con el juego casi vacio: eso era
# contencion, no render, e invalidaba la medida).
set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"
cd "$(dirname "$0")/.."
MODO="${1:-base}"
DISP="${BENCH_DISPLAY:-:0}"
RES="${BENCH_VIEW:-1920x1080}"
OUT="captures/bench"
mkdir -p "$OUT"

run() {
  local name="$1"; shift
  local log
  log="$(mktemp /tmp/flowfire_bench.XXXXXX.log)"
  rm -f "$OUT/$name.json"
  if ! DISPLAY="$DISP" timeout 900 godot4 --path . --resolution 64x64 \
    tools/bench_render.tscn -- "--view=$RES" --warmup=40 --frames=120 \
    "--tag=$name" "--out=$OUT/$name.json" "$@" >"$log" 2>&1; then
    cat "$log"
    rm -f "$log"
    echo "BENCH tag=$name FALLO" >&2
    return 1
  fi
  if grep -Eq "SCRIPT ERROR|Parse Error|Could not preload resource file|referenced non-existent resource|Failed to load resource" "$log"; then
    cat "$log"
    rm -f "$log"
    echo "BENCH tag=$name FALLO: runtime/import invalido" >&2
    return 1
  fi
  if ! grep -E "^BENCH" "$log"; then
    cat "$log"
    rm -f "$log"
    echo "BENCH tag=$name FALLO: sin resultado BENCH" >&2
    return 1
  fi
  rm -f "$log"
  if [ ! -s "$OUT/$name.json" ]; then
    echo "BENCH tag=$name FALLO: sin JSON de salida" >&2
    return 1
  fi
}

if [ "$MODO" = "perfil" ]; then
  run todo || exit 1
  run sin_sombras  --no-shadows=1 || exit 1
  run sin_luces    --no-lights=1 || exit 1
  run sin_mundo    --no-world=1 || exit 1
  run sin_glow_fog --no-glow=1 --no-fog=1 || exit 1
  run sin_hud      --no-hud=1 || exit 1
else
  run "$MODO" || exit 1
fi
