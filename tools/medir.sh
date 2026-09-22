#!/usr/bin/env bash
# medir.sh: benchmark del RENDER real y desglose por subsistema.
#
#   tools/medir.sh perfil   # desglose A/B interleaved (12 corridas, tabla de restas)
#   tools/medir.sh base     # una sola pasada
#   tools/medir.sh stress   # 600 frames / 120 disparos deterministas
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
if [ "$MODO" = "stress" ]; then
  WARMUP="${BENCH_WARMUP:-80}"
  FRAMES="${BENCH_FRAMES:-600}"
else
  WARMUP="${BENCH_WARMUP:-40}"
  FRAMES="${BENCH_FRAMES:-120}"
fi
mkdir -p "$OUT"

run() {
  local name="$1"; shift
  local log
  log="$(mktemp /tmp/flowfire_bench.XXXXXX.log)"
  rm -f "$OUT/$name.json"
  if ! DISPLAY="$DISP" timeout 900 godot4 --path . --resolution 64x64 \
    tools/bench_render.tscn -- "--view=$RES" "--warmup=$WARMUP" "--frames=$FRAMES" \
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

if [ "$MODO" = "stress" ]; then
  run stress --stress-fire=1 --fire-every=5 || exit 1
elif [ "$MODO" = "perfil" ]; then
  # PERFIL A/B INTERLEAVED. Las seis corridas seguidas mezclaban la deriva de
  # la sesion (hasta +-4 ms dentro de una misma tanda) con el coste del
  # subsistema: cada vuelta lleva su "todo" al lado de las variantes y la
  # segunda vuelta corre en orden inverso, asi la posicion en la cola se
  # cancela en la resta. Al final imprime la tabla de restas por par.
  vars=(
    "sin_sombras --no-shadows=1"
    "sin_luces --no-lights=1"
    "sin_mundo --no-world=1"
    "sin_glow_fog --no-glow=1 --no-fog=1"
    "sin_hud --no-hud=1"
  )
  run todo_r1 || exit 1
  for entry in "${vars[@]}"; do
    name="${entry%% *}"; flags="${entry#* }"
    run "${name}_r1" $flags || exit 1
  done
  for (( i = ${#vars[@]} - 1; i >= 0; i-- )); do
    entry="${vars[$i]}"; name="${entry%% *}"; flags="${entry#* }"
    run "${name}_r2" $flags || exit 1
  done
  run todo_r2 || exit 1
  python3 - "$OUT" <<'PYEOF'
import json
import os
import sys

out = sys.argv[1]


def load(tag):
    with open(os.path.join(out, tag + ".json")) as f:
        return json.load(f)


todos = [load("todo_r1"), load("todo_r2")]
variantes = ["sin_sombras", "sin_luces", "sin_mundo", "sin_glow_fog", "sin_hud"]
print("")
print("PERFIL A/B (resta por par: variante - todo; negativo = ahorro real)")
print("  todo referencia: r1 mean=%.2f  r2 mean=%.2f" % (
    todos[0]["mean"], todos[1]["mean"]))
print("  %-14s %9s %8s %8s %8s" % ("variante", "dmean", "dp50", "dp95", "dp99"))
filas = []
for nombre in variantes:
    restas = []
    for r in (0, 1):
        v = load("%s_r%d" % (nombre, r + 1))
        t = todos[r]
        restas.append({k: v[k] - t[k] for k in ("mean", "p50", "p95", "p99")})
    prom = {k: sum(x[k] for x in restas) / len(restas) for k in restas[0]}
    filas.append((nombre, prom))
for nombre, a in sorted(filas, key=lambda x: x[1]["mean"]):
    print("  %-14s %+9.2f %+8.2f %+8.2f %+8.2f" % (
        nombre, a["mean"], a["p50"], a["p95"], a["p99"]))
PYEOF
else
  run "$MODO" || exit 1
fi
