#!/bin/bash
# tools/sheet.sh <nombre> <accion> <t1> <t2> ...   (accion: reload|rempty|inspect|idle; t en segundos)
# Reimporta los assets, captura el juego en cada instante y deja ./captures/<nombre>_sheet.png
cd "$(dirname "$0")/.." || exit 1
mkdir -p captures
name=$1; act=$2; shift 2
godot --headless --path . --import >/dev/null 2>&1
files=(); fc=""; i=0; lay=""
for t in "$@"; do
  f=$(python3 -c "print(int(round($t*30)))")
  godot --path . tools/snap.tscn -- --mode=combat --out=captures/${name}_$i.png --frames=$((f+12)) --act="$act:$f" >/dev/null 2>&1
  files+=(-i captures/${name}_$i.png)
  fc+="[$i]crop=1100:760:410:248,scale=480:-1[v$i];"
  lay+="$(( (i%4)*480 ))_$(( (i/4)*330 ))|"
  i=$((i+1))
done
for ((k=0;k<i;k++)); do fc+="[v$k]"; done
ffmpeg -loglevel error -y "${files[@]}" -filter_complex "${fc}xstack=inputs=$i:layout=${lay%|}" captures/${name}_sheet.png
rm -f captures/${name}_[0-9]*.png
echo captures/${name}_sheet.png
