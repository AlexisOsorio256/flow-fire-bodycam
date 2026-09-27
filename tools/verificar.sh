#!/usr/bin/env bash
# verificar.sh: EL GATE. Antes de decir que algo funciona, pasa por aqui.
#
#   tools/verificar.sh        -> parse de TODO (scripts + tools) + 5 checks
#   tools/verificar.sh rapido -> solo el parse (~10 s)
#
# POR QUE ESTE SCRIPT Y NO UN COMANDO SUELTO (dos veces perdidas):
#
# 1. `godot4 --headless --script algo.gd` NO carga los autoloads, asi que un
#    `Ballistics.fire()` da "Identifier not found" con el juego perfectamente
#    sano. Falso positivo. Por eso el parse se hace con `--check-only`, que si
#    carga el proyecto.
# 2. `godot4 --editor --quit` NO parsea los scripts de `tools/` si no estan
#    referenciados, asi que un error de sintaxis en una herramienta se colaba y
#    se descubria en la captura, con VENTANA ABIERTA, colgada hasta que expiraba
#    el timeout. Por eso aqui se parsea `tools/*.gd` uno a uno.
# 3. Toda sonda es HEADLESS y con timeout corto. Una ventana que se queda negra
#    no es informacion: es espera.
set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"
cd "$(dirname "$0")/.."
MODO="${1:-todo}"
FALLO=0

TMP="$(mktemp -d /tmp/flowfire_verify.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

# --- 1. Parse de CADA script, uno a uno. Con --check-only el proyecto entero
#        esta disponible (autoloads incluidos), asi que no hay falsos positivos.
echo "== parse =="
for f in scripts/*.gd tools/*.gd; do
  [ -e "$f" ] || continue
  LOG="$TMP/$(basename "$f").log"
  timeout 40 godot4 --headless --path . --check-only --script "$f" >"$LOG" 2>&1
  if grep -qE "Parse Error" "$LOG"; then
    echo "  $f  PARSE ERROR"
    grep -E "Parse Error|at: GDScript" "$LOG" | head -3 | sed 's/^/     /'
    FALLO=1
  fi
done
[ "$FALLO" = 0 ] && echo "  $(ls scripts/*.gd tools/*.gd | wc -l) scripts OK"
[ "$MODO" = "rapido" ] && exit "$FALLO"

# --- 2. Import de recursos (texturas, glTF). Sin esto los .import pueden faltar.
LOG="$TMP/import.log"
if ! godot4 --headless --path . --editor --quit >"$LOG" 2>&1 \
   || grep -qE "Could not preload resource file|referenced non-existent resource" "$LOG"; then
  grep -E "ERROR|Could not preload|non-existent" "$LOG" | head -5 | sed 's/^/  /'
  echo "  import/recursos  FALLO"
  FALLO=1
else
  echo "  import/recursos  OK"
fi

# --- 3. Los checks headless. Cada uno responde una pregunta MATERIAL; no son
#        cobertura y no se anaden porque haya cambiado codigo.
echo "== checks =="
# `enemy` SI se corre: el cuerpo existe (Quaternius CC0, `tools/build_enemy.py`)
# y la cadena de muerte dejo de ser una dependencia pendiente. Mide las tres
# zonas (cabeza/pecho/pie), que el segundo impacto no hace nada y que el ragdoll
# recibe el impulso real de la bala.
# `walk` inyecta input de verdad sobre el mapa de COMBATE: el mapa se recorre o
# no se recorre, y eso no lo ve ninguna captura desde el spawn (paso: el jugador
# se quedaba clavado detras del paso central y el mapa parecia correcto).
for t in weapon reload slide_lock weapon_fx walk enemy; do
  OUT="$(timeout 300 godot4 --headless --path . "tools/check_$t.tscn" 2>&1)"
  if echo "$OUT" | grep -qE "SCRIPT ERROR|Parse Error"; then
    echo "  $t  ERROR DE PARSEO"
    echo "$OUT" | grep -E "SCRIPT ERROR|Parse Error|at: GDScript" | head -3 | sed 's/^/     /'
    FALLO=1
  elif echo "$OUT" | grep -q "FALLO:"; then
    echo "  $t  FALLO"
    echo "$OUT" | grep "FALLO:" | head -4 | sed 's/^/     /'
    FALLO=1
  else
    echo "  $t  OK"
  fi
done

[ "$FALLO" = 0 ] && echo "VERIFY: todo GREEN" || echo "VERIFY: hay fallos" >&2
exit "$FALLO"
