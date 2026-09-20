#!/usr/bin/env python3
"""Construye la familia de disparos REAL `assets/audio/shot_1..5.wav`.

FUENTE (que es de verdad, no lo que dice un nombre)
---------------------------------------------------
Sonniss #GameAudioGDC Bundle 2016, pack *Pole Position Production - Glock 18c*:

    Glock_18_1m_left_off_axis_MKH416_clean_Six_shots_x_1.wav
    96 kHz / 24 bit mono, 3,733 s

Es una **Glock real del 9x19**: la 18C es la variante selectiva de la 17 con
compensador (la misma familia que la 19 de este proyecto). El pack trae UNA toma
con SEIS disparos seguidos, grabada con UN micro (Sennheiser MKH416 a 1 m a la
izquierda del arma, fuera del eje del anima) en UNA sesion. Eso es exactamente
lo que pide la regla de identidad: un arma, un entorno, un micro.

POR QUE ESTA FUENTE Y NO OTRA (medido, no de oido)
--------------------------------------------------
- **kante `glock_one_shot` / `glock_rapid_fire`** (Freesound, Glock 19 9 mm
  real, CC BY 3.0): el propio autor avisa de un eco de galeria interior que no
  pudo quitar. Medido: entre los 8 disparos de la rafaga la envolvente no baja
  de -15 dBFS, o sea que cada tiro arrastra la cola del anterior y no se puede
  aislar una toma limpia. Se conserva como referencia A/B, no como produccion.
- **seroutonin 855652** (la familia anterior): NO es una Glock grabada; su autor
  documenta que apilo .22 LR, .22 Magnum, .357 y .44 Magnum. Fuera.
- **Walther PPQ 9 mm** (Still North Media, CC0, 96 kHz/24 bit): real y muy seco,
  pero es OTRA pistola, solo tiene 3 tomas y su energia muere a los 50 ms
  (-33 dB), sin cuerpo. Descartada por identidad y por cuerpo; su molde sirve
  de A/B.
- **db465 `glock_fire`**: sintetizado por procedimiento, no es una grabacion.
- **gsparrysound Glock 18**: salva de fogueo en un teatro.
- **JG_Booysen Glock G42**: .380 y CC BY-NC (no comercial).

QUE HACE ESTE SCRIPT
--------------------
1. Detecta los seis disparos REALES de la toma (envolvente de 1 ms; los rebotes
   de sala caen >=4 dB por debajo del ataque y se descartan solos).
2. Descarta la toma mas recortada (la fuente normaliza a tope y deja rachas de
   <=8 muestras al ras en cada transitorio: se eligen las cinco menos tocadas).
3. Corta las cinco tomas a la MISMA ventana (160 ms) que termina ANTES del
   disparo siguiente: la fuente es una rafaga y una ventana mas larga meteria
   el tiro de despues dentro de la muestra. La sala no se hornea: la pone el bus
   `Range`, que es el unico lugar con reverberacion del proyecto.
4. DSP minimo: HPF Butterworth de 4.o orden a 36 Hz (dB inaudible de retumbe
   infrasonico), normalizacion de pico a -0,5 dBFS por toma y fade de salida de
   20 ms. Sin matching espectral, sin modelado de cola, sin pitch, sin capas.

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
SOURCE = REPO / "downloads" / "audio" / "gunshot_glock18c_6shots_1m_mkh416.wav"
SR = 48000
## Ventana comun de cada toma. 160 ms es el hueco mas corto entre dos disparos
## de la rafaga (177 ms) menos guarda: mas largo meteria el disparo siguiente.
TAKE_MS = 160.0
FADE_MS = 20.0
PEAK_DBFS = -0.5
## Deteccion de disparos: pico de la envolvente de 1 ms por debajo del maximo.
ONSET_FLOOR_DB = -18.0
## Un rebote de sala no es un disparo: su ataque de 40 ms cae mucho mas bajo.
SHOT_ATTACK_WINDOW_DB = 4.0
TAKES = 5
HPF_HZ = 36.0


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
    """Picos de la envolvente de 1 ms que de verdad son disparos.

    Devuelve indices de MUESTRA. Agrupa picos a menos de 120 ms (el mismo tiro
    puede dar varios maximos locales) y luego exige que el ataque de 40 ms quede
    a menos de SHOT_ATTACK_WINDOW_DB del ataque mas fuerte: los rebotes de sala
    entran ~10 dB por debajo y se caen aqui, sin umbrales magicos por archivo."""
    w = max(1, int(SR * 0.001))
    n = len(x) // w
    env = np.sqrt((x[: n * w].reshape(n, w) ** 2).mean(axis=1))
    thr = env.max() * (10.0 ** (ONSET_FLOOR_DB / 20.0))
    candidates = [i for i in range(1, n - 1)
                  if env[i] >= thr and env[i] >= env[i - 1] and env[i] > env[i + 1]]
    groups: list[int] = []
    for i in candidates:
        if groups and (i - groups[-1]) * w / SR < 0.12:
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


def rail_count(x: np.ndarray) -> int:
    """Muestras a pleno uso en la fuente (24 bit normalizada a tope)."""
    return int(np.sum(np.abs(x) >= 1.0 - 1e-6))


def biquad_hpf(x: np.ndarray, f0: float, q: float) -> np.ndarray:
    """Una etapa RBJ high-pass. Dos etapas con Q de Butterworth = 4.o orden."""
    w0 = 2.0 * math.pi * f0 / SR
    alpha = math.sin(w0) / (2.0 * q)
    cw = math.cos(w0)
    b0, b1, b2 = (1.0 + cw) / 2.0, -(1.0 + cw), (1.0 + cw) / 2.0
    a0, a1, a2 = 1.0 + alpha, -2.0 * cw, 1.0 - alpha
    b = [b0 / a0, b1 / a0, b2 / a0]
    a = [1.0, a1 / a0, a2 / a0]
    y = np.empty_like(x)
    x1 = x2 = y1 = y2 = 0.0
    for i, v in enumerate(x):
        out = b[0] * v + b[1] * x1 + b[2] * x2 - a[1] * y1 - a[2] * y2
        x2, x1 = x1, v
        y2, y1 = y1, out
        y[i] = out
    return y


def process_shot(clip: np.ndarray) -> np.ndarray:
    y = biquad_hpf(clip, HPF_HZ, 0.54119610)
    y = biquad_hpf(y, HPF_HZ, 1.30656296)
    pk = float(np.abs(y).max())
    y = y * (10.0 ** (PEAK_DBFS / 20.0)) / max(pk, 1e-12)
    fade = min(int(FADE_MS / 1000.0 * SR), len(y))
    y[-fade:] *= np.linspace(1.0, 0.0, fade)
    return y


def main() -> int:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if not SOURCE.exists():
        print("FALTA la fuente real: %s" % SOURCE, file=sys.stderr)
        print("Es material de trabajo (downloads/ no se versiona). Se descarga de", file=sys.stderr)
        print("  http://ftpmirror.your.org/pub/misc/sonniss2016/individual/"
              "Pole%20Position%20Production%20-%20Glock%2018c/"
              "Glock_18_1m_left_off_axis_MKH416_clean_Six_shots_x_1.wav", file=sys.stderr)
        return 1

    raw = decode(SOURCE)
    onsets = detect_onsets(raw)
    if len(onsets) < TAKES:
        print("La fuente no dio %d disparos, dio %d" % (TAKES, len(onsets)), file=sys.stderr)
        return 1

    take_n = int(round(TAKE_MS / 1000.0 * SR))
    windows = []
    for o in onsets:
        start = max(0, o - int(0.002 * SR))
        clip = raw[start:start + take_n]
        rail = rail_count(clip)
        windows.append((rail, o, clip))
    # La fuente normaliza a tope: se descartan las tomas mas recortadas y se
    # conserva el orden temporal de las que quedan.
    keep = sorted(sorted(windows, key=lambda t: (t[0], t[1]))[:TAKES], key=lambda t: t[1])

    print("fuente: %s" % SOURCE.name)
    print("disparos detectados: %d  ->  se conservan %d (menos muestras al ras)"
          % (len(onsets), len(keep)))
    for n, (rail, o, clip) in enumerate(keep, start=1):
        y = process_shot(clip)
        peak = float(np.abs(y).max())
        if db(peak) > PEAK_DBFS + 0.01:
            print("ERROR: shot_%d pasa del techo (%.2f dBFS)" % (n, db(peak)), file=sys.stderr)
            return 1
        out_rail = int(np.sum(np.abs(y) >= 32767.0 / 32768.0))
        a40 = rms_db(y[: int(0.04 * SR)])
        tail = rms_db(y[-int(0.03 * SR):])
        print("  shot_%d.wav  fuente@%6.3fs  fuente_al_ras %2d  dur %3.0f ms  "
              "pico %6.2f dBFS  RMS %6.2f  cresta %5.2f  ataque %6.2f  cola30 %6.2f  decae %5.1f dB  al_ras %d"
              % (n, o / SR, rail, len(y) / SR * 1000.0, db(peak), rms_db(y),
                 db(peak) - rms_db(y), a40, tail, a40 - tail, out_rail))
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
