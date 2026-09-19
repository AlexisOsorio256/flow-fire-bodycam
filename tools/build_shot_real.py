#!/usr/bin/env python3
"""Construye los TRES disparos reales `assets/audio/shot_1..3.wav`.

POR QUE EXISTE (el defecto concreto, medido 2026-09-19)
------------------------------------------------------
La version anterior intentaba convertir CINCO grabaciones incompatibles en una
familia mediante DSP: una Glock 19X (otra sesion/micro), tres tomas de una
Glock (misma sesion) y una pistola generica Kodack (ni siquiera Glock). El
`build_shot_real.py` anterior las forzaba con matching espectral iterativo
(hasta +-12 dB por banda), modelado de cola y trim de ataque comun
(dispersion 0,00 dB). Esos criterios pasaban POR CONSTRUCCION: median la
salida del DSP, no la coherencia de las fuentes.

Medido sobre las tomas con DSP ligero (solo HPF 36 Hz + pico -0,5 + fade):

  19X    ataque -9,97  cresta 12,22  cola decae 14,3 dB
  trio1  ataque -12,90 cresta 15,60  cola decae 18,6 dB
  trio2  ataque -12,46 cresta 14,41  cola decae 18,6 dB
  trio3  ataque -13,00 cresta 14,59  cola decae 14,4 dB
  kodack ataque -8,39  cresta 9,53   cola decae 4,7 dB (NO decae: falla)

Kodack falla el criterio de cresta (12-18) y no tiene cola que decaiga, ademas
de ser la unica no-Glock y la mas caliente (+4,6 dB sobre el trio). 19X, aun
siendo Glock real, ataca 3 dB por encima del trio (otra sesion, otro micro).
El trio comparte sesion, micro y arma: dispersion de ataque NATURAL de 0,54 dB,
sin trim comun.

QUE HACE ESTE SCRIPT (solucion de raiz)
---------------------------------------
1. Anclaje exacto en el verdadero transitorio de cada toma (pico de boca).
2. SOLO tres tomas de UNA MISMA sesion de Glock real (seroutonin 855652).
   Tres excelentes en lugar de cinco forzadas: eso es mejor.
3. DSP minimo y reversible: HPF Butterworth 4.o orden a 36 Hz (fuera
   infrasonico), normalizacion de pico a -0,5 dBFS y fade de salida de 30 ms.
   Sin matching espectral, sin modelado de cola, sin trim de ataque comun.
   La dispersion de ataque resultante (~0,5 dB) es NATURAL y la verifica
   `tools/measure_shots.py` contra <= 1,5 dB.

Uso:
    python3 tools/build_shot_real.py
    python3 tools/build_shot_real.py --dry-run
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
SOURCE_DIR = REPO / "downloads"
SR = 48000
FADE_MS = 30.0
PEAK_DBFS = -0.5
TAIL_S = 0.38

RECIPES = [
    # Glock real, misma sesion/micro/sala (Freesound CC0, seroutonin) - toma 1
    {
        "src": SOURCE_DIR / "audio/gunshot_glock_3x_punchy_seroutonin.mp3",
        "onset_s": 0.0417,
        "label": "Glock 3x #1 (seroutonin)",
    },
    # Idem - toma 2
    {
        "src": SOURCE_DIR / "audio/gunshot_glock_3x_punchy_seroutonin.mp3",
        "onset_s": 1.6531,
        "label": "Glock 3x #2 (seroutonin)",
    },
    # Idem - toma 3
    {
        "src": SOURCE_DIR / "audio/gunshot_glock_3x_punchy_seroutonin.mp3",
        "onset_s": 3.2204,
        "label": "Glock 3x #3 (seroutonin)",
    },
]


def decode(path: Path) -> np.ndarray:
    proc = subprocess.run(
        [
            "ffmpeg", "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(SR),
            "-f", "f32le", "-",
        ],
        capture_output=True, check=True,
    )
    return np.frombuffer(proc.stdout, dtype=np.float32).astype(np.float64)


def save(path: Path, x: np.ndarray) -> None:
    """Escribe PCM 16 bits mono 48 kHz."""
    x = np.clip(x, -1.0, 1.0)
    subprocess.run(
        [
            "ffmpeg", "-v", "error", "-f", "s16le", "-ar", str(SR), "-ac", "1",
            "-i", "-", "-c:a", "pcm_s16le", str(path), "-y",
        ],
        input=(x * 32767.0).astype(np.int16).tobytes(), capture_output=True, check=True,
    )


def db(v: float) -> float:
    return 20.0 * math.log10(v) if v > 1e-12 else -240.0


def crest_db(x: np.ndarray) -> float:
    return db(float(np.abs(x).max())) - db(float(np.sqrt(np.mean(x ** 2))))


def attack_rms_db(x: np.ndarray) -> float:
    n = max(1, int(0.04 * SR))
    return db(float(np.sqrt(np.mean(x[:n] ** 2))))


def extract_shot(x: np.ndarray, onset_s: float | None = None) -> np.ndarray:
    """Extrae el corte de 380 ms anclado en el verdadero transitorio inicial."""
    target_samples = int(round(TAIL_S * SR))
    if onset_s is not None:
        anchor_nominal = int(round(onset_s * SR))
        search_w = int(0.02 * SR)
        s_lo = max(0, anchor_nominal - search_w)
        s_hi = min(len(x), anchor_nominal + search_w)
        peak_offset = int(np.argmax(np.abs(x[s_lo:s_hi])))
        peak_idx = s_lo + peak_offset
    else:
        peak_idx = int(np.argmax(np.abs(x)))

    start = max(0, peak_idx - int(0.002 * SR))
    end = start + target_samples
    clip = x[start:end]
    if len(clip) < target_samples:
        clip = np.pad(clip, (0, target_samples - len(clip)))
    return clip.copy()


def hpf_36hz(x: np.ndarray) -> np.ndarray:
    """HPF Butterworth 4.o orden a 36 Hz: fuera retumbe infrasonico, nada mas."""
    N = len(x)
    freqs = np.fft.rfftfreq(N, 1.0 / SR)
    h = 1.0 / (1.0 + (36.0 / np.maximum(freqs, 1.0)) ** 4)
    return np.fft.irfft(np.fft.rfft(x) * h, n=N)


def process_shot(clip: np.ndarray) -> np.ndarray:
    y = hpf_36hz(clip)
    pk = float(np.abs(y).max())
    y = y * (10.0 ** (PEAK_DBFS / 20.0)) / max(pk, 1e-12)
    fade = min(int(FADE_MS / 1000.0 * SR), len(y))
    y[-fade:] *= np.linspace(1.0, 0.0, fade)
    return y


def main() -> int:
    ap = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    for n, r in enumerate(RECIPES, start=1):
        src = Path(r["src"])
        if not src.exists():
            print("FALTA la fuente: %s" % src, file=sys.stderr)
            return 1
        raw_audio = decode(src)
        clip = extract_shot(raw_audio, r.get("onset_s"))
        y = process_shot(clip)
        peak = float(np.abs(y).max())
        if db(peak) > PEAK_DBFS + 0.01:
            print("ERROR: shot_%d pasa del techo (%.2f dBFS)" % (n, db(peak)), file=sys.stderr)
            return 1
        rail = int(np.sum(np.abs(y) >= 32767.0 / 32768.0))
        print(
            "shot_%d.wav  %-34s dur %3.0f ms  pico %6.2f dBFS  RMS %6.2f  "
            "cresta %5.2f  ataque %6.2f  al_ras %d"
            % (
                n, r["label"][:34], len(y) / SR * 1000.0, db(peak),
                db(float(np.sqrt(np.mean(y ** 2)))), crest_db(y),
                attack_rms_db(y), rail,
            ),
        )
        if not args.dry_run:
            save(OUT / ("shot_%d.wav" % n), y)
    return 0


if __name__ == "__main__":
    sys.exit(main())
