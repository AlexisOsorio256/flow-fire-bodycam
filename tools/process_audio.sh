#!/usr/bin/env bash
# Regenera únicamente el Foley de cargador que conserva un master versionado.
#
# Fuente canónica:
#   assets/audio/source/g36c_mag_in_out_excerpt.wav
#
# magout.wav y magin.wav salen siempre de ese mismo excerpt. El resto del Foley
# grabado (slide_rear/battery/hand, empty, footstep, shell_drop) está congelado
# en sus WAV de runtime y su procedencia vive en CREDITS_AUDIO.md: no existe una
# ruta oculta desde /tmp ni un backup histórico que pueda cambiar el resultado
# según la máquina. Los cuatro eventos sintetizados los genera
# tools/make_weapon_sounds.py; disparos e impactos tienen builders propios.
#
# Uso:
#   tools/process_audio.sh
#   tools/process_audio.sh --dry-run

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AUDIO_DIR="$ROOT/assets/audio"
MASTER="$AUDIO_DIR/source/g36c_mag_in_out_excerpt.wav"
DRY_RUN="${1:-}"
PEAK_CEILING=-1.5

[ -f "$MASTER" ] || {
    echo "FALLO: falta el master versionado de cargador: $MASTER" >&2
    exit 1
}

peak() {
    ffmpeg -hide_banner -i "$1" -af volumedetect -f null - 2>&1 \
        | grep -m1 max_volume | awk '{print $(NF-1)}'
}

process_mag() {
    local name="$1" start="$2" stop="$3" peak_target="$4" fade="$5"
    local file="$AUDIO_DIR/$name.wav"
    local raw tmp gain keep fade_start out after_peak trim raw_peak

    tmp="$(mktemp "/tmp/flowfire_${name}.XXXXXX.wav")"
    raw="$(mktemp "/tmp/flowfire_${name}_raw.XXXXXX.wav")"

    keep="$(awk -v s="$start" -v e="$stop" 'BEGIN { printf "%.3f", e - s }')"
    fade_start="$(awk -v k="$keep" -v f="$fade" 'BEGIN { s = k - f; printf "%.3f", (s > 0 ? s : 0) }')"

    ffmpeg -v error -y -i "$MASTER" \
        -af "atrim=start=${start}:end=${stop},asetpts=PTS-STARTPTS" \
        -ac 1 -ar 44100 -c:a pcm_s16le "$raw"

    raw_peak="$(peak "$raw")"
    gain="$(awk -v t="$peak_target" -v p="$raw_peak" 'BEGIN { printf "%.2f", t - p }')"

    if [ "$DRY_RUN" = "--dry-run" ]; then
        printf "  %-8s extracto %.3f..%.3f s  pico=%s dB  ganancia=%s dB\n" \
            "$name" "$start" "$stop" "$raw_peak" "$gain"
        rm -f "$tmp" "$raw"
        return
    fi

    ffmpeg -v error -y -i "$raw" \
        -af "volume=${gain}dB,atrim=0:${keep},afade=t=out:st=${fade_start}:d=${fade}" \
        -ac 1 -ar 44100 -c:a pcm_s16le "$tmp"

    after_peak="$(peak "$tmp")"
    if awk -v p="$after_peak" -v c="$PEAK_CEILING" 'BEGIN { exit !(p > c) }'; then
        trim="$(awk -v p="$after_peak" -v c="$PEAK_CEILING" 'BEGIN { printf "%.2f", c - p }')"
        out="$(mktemp "/tmp/flowfire_${name}_peak.XXXXXX.wav")"
        ffmpeg -v error -y -i "$tmp" -af "volume=${trim}dB" \
            -ac 1 -ar 44100 -c:a pcm_s16le "$out"
        mv "$out" "$tmp"
    fi

    mv "$tmp" "$file"
    rm -f "$raw"
    printf "  %-8s extracto %.3f..%.3f s  pico %5s -> %5s\n" \
        "$name" "$start" "$stop" "$raw_peak" "$(peak "$file")"
}

echo "== Cargador (master versionado G36C close-up) =="
process_mag magout 0.105 0.210 -8.0 0.03
process_mag magin  0.210 0.400 -1.5 0.05
echo "Listo. Ningún otro WAV se procesa por esta ruta."
