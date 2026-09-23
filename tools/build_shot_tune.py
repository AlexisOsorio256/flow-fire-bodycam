#!/usr/bin/env python3
"""Etapa de timbre de la familia de disparos `assets/audio/shot_1..5.wav`.

Corre DESPUES de `tools/build_shot_real.py`, que extrae las tomas raw sin tocar
el timbre. Esta etapa aplica encima tres cosas medibles:

1. Shelf de cuerpo: +3,0 dB por debajo de 180 Hz, transicion log suave hasta
   0 dB en 360 Hz (dominio FFT, cero fase). Las tomas raw median 4,1-12,8 % de
   energia por debajo de 120 Hz (media 8,0 %) y centroide ~3,2 kHz: finas,
   mid-heavy. Medido, la familia pasa a 7,2-21,2 % (media 13,7 %) de energia
   <120 Hz (relacion cuerpo/medio +3 dB). El cuerpo por debajo de ~200 Hz es
   lo que da al 9 mm cercano su peso de arma en vez de chasquido agudo. Se
   descarto +4,5 dB: sube el cuerpo pero infla el pico de las tomas graves
   hasta comerse la subida de nivel.
2. Fade final de 6 ms. Las tomas 1-3 se cortaban a mitad de decaimiento
   (-36/-43/-46 dB de ultima muestra = tick de corte en el 60 % de los
   disparos). Las tomas 4-5 terminan por debajo de -68 dB: el fade ahi es
   inaudible e inocuo, y uniformar las cinco evita dos contratos distintos.
3. Re-normalizacion de la FAMILIA a techo -0,1 dBFS con UNA sola ganancia (la
   fija la toma mas alta): mismo contrato de pico que el builder raw y, ademas,
   el renorm no ensucia la igualdad de ataque entre variantes. Medido: renorm
   por archivo subia la dispersion de ataque a 1,75 dB (criterio <=1,5 de
   measure_shots); con ganancia comun queda en 0,92 dB, MEJOR que el 1,20 dB
   del raw, porque el shelf levanta mas al ataque de las tomas mas graves.

GUARDA ANI DOBLE PROCESO: `assets/audio/shot_tune_state.json` guarda el
sha256 de cada WAV tunado. Si el archivo actual ya coincide con ese hash, se
omite (un segundo proceso apilaria el shelf sobre el shelf). Tras re-ejecutar
`build_shot_real.py` los hashes dejan de coincidir y esta etapa se vuelve a
aplicar sola. Para volver al raw: `git restore assets/audio/shot_*.wav`.

Lo que NO hace: reverb, compresion, pitch, capas ni HPF. Solo reparto
espectral, fade de cierre y ganancia uniforme. El pase final es
`tools/measure_shots.py` (duracion, pico, cresta, ataque, decaimiento y
dispersion entre variantes), que este script ejecuta y cuyo codigo propaga.

Uso:
    python3 tools/build_shot_tune.py
    python3 tools/build_shot_tune.py --dry-run
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import struct
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

REPO = Path(__file__).resolve().parents[1]
OUT = REPO / "assets" / "audio"
STATE = OUT / "shot_tune_state.json"
MEASURE = REPO / "tools" / "measure_shots.py"
TAKES = 5
SR_EXPECTED = 48000
PEAK_DBFS = -0.1
SHELF_DB = 3.0     # ganancia de cuerpo en la banda baja
SHELF_F0 = 180.0   # plano completo hasta aqui
SHELF_F1 = 360.0   # sin ganancia a partir de aqui
FADE_MS = 6.0


def db(v: float) -> float:
    return 20.0 * math.log10(v) if v > 1e-12 else -240.0


def read_wav(path: Path) -> np.ndarray:
    with wave.open(str(path), "rb") as w:
        if w.getsampwidth() != 2:
            raise ValueError("%s: se esperaba PCM16" % path.name)
        rate = w.getframerate()
        ch = w.getnchannels()
        a = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16)
    if rate != SR_EXPECTED:
        raise ValueError("%s: sample rate %d != %d" % (path.name, rate, SR_EXPECTED))
    x = a.astype(np.float64) / 32768.0
    if ch == 2:
        x = x.reshape(-1, 2).mean(axis=1)
    return x


def write_wav(path: Path, x: np.ndarray) -> None:
    x = np.clip(x, -1.0, 1.0)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR_EXPECTED)
        w.writeframes((x * 32767.0).astype(np.int16).tobytes())


def shelf_gain_db(freqs: np.ndarray) -> np.ndarray:
    """Ganancia del shelf en dB: SHELF_DB hasta F0, log-lineal a 0 en F1."""
    g = np.full(freqs.shape, SHELF_DB)
    g[freqs >= SHELF_F1] = 0.0
    mid = (freqs > SHELF_F0) & (freqs < SHELF_F1)
    t = np.log(freqs[mid] / SHELF_F0) / math.log(SHELF_F1 / SHELF_F0)
    g[mid] = SHELF_DB * (1.0 - t)
    return g


def apply_shelf(x: np.ndarray) -> np.ndarray:
    spec = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(x.size, 1.0 / SR_EXPECTED)
    gain = np.power(10.0, shelf_gain_db(freqs) / 20.0)
    return np.fft.irfft(spec * gain, n=x.size)


def apply_fade(x: np.ndarray) -> np.ndarray:
    n = int(round(SR_EXPECTED * FADE_MS / 1000.0))
    if len(x) > n:
        x[-n:] *= np.linspace(1.0, 0.0, n)
    return x


def family_gain(takes: list[np.ndarray]) -> float:
    """Ganancia unica que deja el pico maximo de la familia en PEAK_DBFS."""
    peak = max(float(np.abs(x).max()) for x in takes)
    if peak <= 0.0:
        return 1.0
    return (10.0 ** (PEAK_DBFS / 20.0)) / peak


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def metrics(x: np.ndarray) -> dict:
    n = len(x)
    spec = np.abs(np.fft.rfft(x * np.hanning(n))) + 1e-12
    freqs = np.fft.rfftfreq(n, 1.0 / SR_EXPECTED)
    power = spec ** 2
    total = float(power.sum()) or 1e-30
    return {
        "peak": db(float(np.abs(x).max())),
        "rms": db(float(np.sqrt((x ** 2).mean()))),
        "atk40": db(float(np.sqrt((x[: int(0.04 * SR_EXPECTED)] ** 2).mean()))),
        "end": db(float(np.abs(x[-1]))),
        "cent": float((freqs * spec).sum() / spec.sum()),
        "lf": 100.0 * float(power[freqs < 120.0].sum()) / total,
        "b400": 100.0 * float(power[freqs < 400.0].sum()) / total,
    }


def main() -> int:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dry-run", action="store_true",
                    help="mide sin escribir WAV ni estado")
    args = ap.parse_args()

    # Line-buffering: sin el, la salida de este script llega entera al final y
    # se ve DESPUES de la de measure_shots.py (hijo), lo que confunde al leer.
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(line_buffering=True)

    state: dict = {}
    if STATE.exists():
        state = json.loads(STATE.read_text())
    new_state: dict = dict(state)

    print("%-10s %6s %7s %7s %7s %7s %7s %6s | %7s %7s %7s %7s %7s %6s %6s"
          % ("toma", "", "pico", "rms", "atk40", "fin_dB", "centro", "LF%",
             "pico", "rms", "atk40", "fin_dB", "centro", "LF%", "b<400"))
    print("%-10s %6s %7s %7s %7s %7s %7s %6s | %7s %7s %7s %7s %7s %6s %6s"
          % ("", "raw", "raw", "raw", "raw", "raw", "raw Hz", "raw",
             "tunado", "tunado", "tunado", "tunado", "tunado Hz", "tun", "tun"))

    wrote = False
    pending: list[tuple[int, Path, np.ndarray, np.ndarray]] = []
    for i in range(1, TAKES + 1):
        path = OUT / ("shot_%d.wav" % i)
        if not path.exists():
            print("FALTA %s: ejecuta tools/build_shot_real.py" % path, file=sys.stderr)
            return 1
        cur = sha256(path)
        if state.get(path.name) == cur:
            print("  shot_%d.wav: ya tunado (sha256 del estado coincide), omitido" % i)
            continue
        raw = read_wav(path)
        y = apply_fade(apply_shelf(raw.copy()))
        pending.append((i, path, raw, y))

    if pending:
        gain = family_gain([y for _, _, _, y in pending])
        for i, path, raw, y in pending:
            y *= gain
            m0, m1 = metrics(raw), metrics(y)
            print("  shot_%d     %6s %7.1f %7.1f %7.1f %7.1f %7.0f %6.1f | %7.1f %7.1f"
                  " %7.1f %7.1f %7.0f %6.1f %6.1f"
                  % (i, "in", m0["peak"], m0["rms"], m0["atk40"], m0["end"], m0["cent"],
                     m0["lf"], m1["peak"], m1["rms"], m1["atk40"], m1["end"], m1["cent"],
                     m1["lf"], m1["b400"]))
            if args.dry_run:
                continue
            write_wav(path, y)
            new_state[path.name] = sha256(path)
            wrote = True

    if wrote and not args.dry_run:
        STATE.write_text(json.dumps(new_state, indent=2, sort_keys=True) + "\n")
        print("estado escrito: %s" % STATE.relative_to(REPO))

    # La guarda de la familia es SIEMPRE measure_shots: este script no certifica
    # por su cuenta, propaga el pase oficial.
    print("\n== tools/measure_shots.py ==")
    rc = subprocess.call([sys.executable, str(MEASURE)])
    if rc != 0:
        print("FALLOS en la guarda de la familia", file=sys.stderr)
    return rc


if __name__ == "__main__":
    sys.exit(main())
