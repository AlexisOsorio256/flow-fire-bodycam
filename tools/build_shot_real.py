#!/usr/bin/env python3
"""Construye la familia de disparos REAL `assets/audio/shot_1..5.wav`.

FUENTE (Glock real con disparos separados, no una ráfaga recortada)
-------------------------------------------------------------------
El builder consume la preview HQ pública de:

    gunshot_glock17_outdoor_range.mp3 (Freesound 34982, "glock17_02.wav")
    Autor: gezortenplotz
    Licencia: Creative Commons Attribution 3.0 (CC BY 3.0)
    URL: https://freesound.org/people/gezortenplotz/sounds/34982/

La ficha oficial identifica la grabación como **Glock 17 9x19 real** en campo de
tiro exterior. El original publicado es WAV 44,1 kHz / 16 bit / estéreo; en este
workspace no hay sesión autenticada de Freesound, por lo que la entrada disponible
es su preview HQ MP3 pública. Contiene 8 disparos separados por varios segundos:
se pueden extraer ventanas de 380 ms sin invadir el disparo siguiente.

POR QUÉ ESTA FUENTE Y NO LA ANTERIOR
------------------------------------
- **Glock 18C (Pole Position, Sonniss 2016)**: era una ráfaga automática con
  solo 177 ms entre disparos, lo que obligaba a cortar a 160 ms para no pillar
  el disparo siguiente. El dueño rechazó ese resultado por sonar a pistola de
  juguete; esa aceptación perceptual manda sobre sus métricas.
- **kante Freesound 35799/35800**: eco de galería cerrada que no baja de -15 dBFS.
- **seroutonin 855652**: compuesto sintético de .22, .357 y .44. Fuera.
- **Walther PPQ**: pistola diferente, solo 3 tomas y sin cuerpo.
- **areniporgen 828786**: solo tiene 1 disparo (imposible dar 5 variantes).
- **gezortenplotz 34982**: 8 disparos separados de una Glock 17 9mm real, misma
  grabación y entorno, con segundos entre eventos.

Este script NO certifica que una fuente "suene mejor". En esta pasada el modelo no
dispone de una modalidad que le permita oír los WAV; la selección perceptual final
debe hacerse escuchando el A/B. Las medidas de abajo son sólo guardarraíles.

QUÉ HACE ESTE SCRIPT
--------------------
1. Detecta los disparos reales mediante picos de envolvente de 1 ms.
2. Conserva 11 ms de pre-roll antes del transitorio, como la referencia B raw
   aprobada en escucha. No aplica EQ, filtro ni fades.
3. Conserva las primeras 5 tomas en orden temporal; ninguna métrica elige por oído.
4. Ventana raw de 380 ms. El builder solo decodifica a mono/48 kHz, corta y baja
   la toma completa hasta pico -0,1 dBFS si la decodificacion MP3 presenta
   overshoot > 0 dBFS. Esa ganancia uniforme no cambia timbre ni dinamica y evita
   fabricar clipping al convertir a PCM16. No hay otro DSP.

Uso:
    python3 tools/build_shot_real.py
    python3 tools/build_shot_real.py --dry-run

Esta etapa deja los WAV en RAW. El timbre de cuerpo (shelf, fade de cierre y
techo comun de familia) lo aplica `tools/build_shot_tune.py` en la etapa 2;
volver a raw = `git restore assets/audio/shot_*.wav`.
"""
from __future__ import annotations

import argparse
import math
import subprocess
import sys
from pathlib import Path

import numpy as np

REPO = Path(__file__).resolve().parents[1]
OUT = REPO / "assets" / "audio"
SOURCE = REPO / "downloads" / "audio" / "gunshot_glock17_outdoor_range.mp3"
SR = 48000
TAKE_MS = 380.0
PRE_ROLL_MS = 11.0
PEAK_DBFS = -0.1
ONSET_FLOOR_DB = -18.0
SHOT_ATTACK_WINDOW_DB = 4.0
TAKES = 5


def decode(path: Path) -> np.ndarray:
    proc = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(SR),
         "-f", "f32le", "-"],
        capture_output=True, check=True,
    )
    return np.frombuffer(proc.stdout, dtype=np.float32).astype(np.float64)


def save(path: Path, x: np.ndarray) -> None:
    """Escribe PCM 16 bits mono 48 kHz."""
    x = np.clip(x, -1.0, 1.0)
    subprocess.run(
        ["ffmpeg", "-v", "error", "-f", "s16le", "-ar", str(SR), "-ac", "1",
         "-i", "-", "-c:a", "pcm_s16le", str(path), "-y"],
        input=(x * 32767.0).astype(np.int16).tobytes(), capture_output=True, check=True,
    )


def db(v: float) -> float:
    return 20.0 * math.log10(v) if v > 1e-12 else -240.0


def rms_db(x: np.ndarray) -> float:
    return db(float(np.sqrt(np.mean(x ** 2)))) if len(x) else -240.0


def detect_onsets(x: np.ndarray) -> list[int]:
    """Picos de la envolvente de 1 ms que de verdad son disparos."""
    w = max(1, int(SR * 0.001))
    n = len(x) // w
    env = np.sqrt((x[: n * w].reshape(n, w) ** 2).mean(axis=1))
    thr = env.max() * (10.0 ** (ONSET_FLOOR_DB / 20.0))
    candidates = [i for i in range(1, n - 1)
                  if env[i] >= thr and env[i] >= env[i - 1] and env[i] > env[i + 1]]
    groups: list[int] = []
    for i in candidates:
        if groups and (i - groups[-1]) * w / SR < 0.5:
            if env[i] > env[groups[-1]]:
                groups[-1] = i
        else:
            groups.append(i)
    onsets = [g * w for g in groups]
    attacks = [rms_db(x[max(0, o - int(0.004 * SR)):][: int(0.04 * SR)]) for o in onsets]
    if not attacks:
        return []
    ceiling = max(attacks)
    return [o for o, a in zip(onsets, attacks) if a >= ceiling - SHOT_ATTACK_WINDOW_DB]


def find_zero_crossing_start(raw: np.ndarray, o: int) -> int:
    """Busca el paso por cero limpio justo antes del transitorio del disparo."""
    p = o
    while p > o - int(0.015 * SR) and np.max(np.abs(raw[max(0, p - 24):p])) > 0.02:
        p -= 1
    zc = p
    while zc > 0 and raw[zc] * raw[zc - 1] > 0:
        zc -= 1
    return zc


def process_shot(clip: np.ndarray) -> np.ndarray:
    y = clip.copy()
    peak = float(np.abs(y).max())
    if peak > 0.0:
        y *= (10.0 ** (PEAK_DBFS / 20.0)) / peak
    return y


def main() -> int:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if not SOURCE.exists():
        print("FALTA la fuente real: %s" % SOURCE, file=sys.stderr)
        print("Descárgala de Freesound 34982 (gezortenplotz):", file=sys.stderr)
        print("  https://freesound.org/people/gezortenplotz/sounds/34982/", file=sys.stderr)
        return 1

    raw = decode(SOURCE)
    onsets = detect_onsets(raw)
    if len(onsets) < TAKES:
        print("La fuente no dio %d disparos, dio %d" % (TAKES, len(onsets)), file=sys.stderr)
        return 1

    take_n = int(round(TAKE_MS / 1000.0 * SR))
    windows = []
    for idx, o in enumerate(onsets):
        start = max(0, find_zero_crossing_start(raw, o) - int(round(PRE_ROLL_MS / 1000.0 * SR)))
        clip = raw[start:start + take_n]
        if len(clip) < take_n:
            continue
        windows.append((idx, start, o, clip))

    keep = windows[:TAKES]

    print("fuente: %s (preview HQ de Glock 17 9mm real, Freesound 34982)" % SOURCE.name)
    print("disparos detectados: %d  ->  se conservan los primeros %d en orden temporal"
          % (len(onsets), len(keep)))
    for n, (idx, start, o, clip) in enumerate(keep, start=1):
        y = process_shot(clip.copy())
        peak = float(np.abs(y).max())
        out_rail = int(np.sum(np.abs(y) >= 32767.0 / 32768.0))
        source_rail = int(np.sum(np.abs(clip) >= 0.9999))
        a40 = rms_db(y[: int(0.04 * SR)])
        tail = rms_db(y[-int(0.03 * SR):])
        print("  shot_%d.wav  fuente@%6.3fs (tiro %d)  dur %3.0f ms  "
              "fuente_al_ras %d  pico %6.2f dBFS  RMS %6.2f  cresta %5.2f  "
              "ataque %6.2f  cola30 %6.2f  decae %5.1f dB  salida_al_ras %d"
              % (n, start / SR, idx + 1, len(y) / SR * 1000.0, source_rail,
                 db(peak), rms_db(y), db(peak) - rms_db(y), a40, tail,
                 a40 - tail, out_rail))
        if not args.dry_run:
            save(OUT / ("shot_%d.wav" % n), y)
    if not args.dry_run:
        for stale in range(len(keep) + 1, 16):
            old = OUT / ("shot_%d.wav" % stale)
            if old.exists():
                old.unlink()
                print("  eliminado %s (la familia ya no lo usa)" % old.name)
    return 0


if __name__ == "__main__":
    sys.exit(main())
