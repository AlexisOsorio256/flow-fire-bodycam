#!/usr/bin/env python3

import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

PIPER = Path.home() / ".local" / "opt" / "piper"
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio" / "voice"
RATE = 22050
RNG = np.random.default_rng(19)

RADIO = {
    "contact": ["Contact front!", "Contact, contact!", "Eyes on, engaging!", "Hostile, left side!"],
    "fired": ["Shots fired, shots fired!", "Taking fire!", "Under fire, under fire!"],
    "hit": ["I'm hit!", "I'm hit, I'm hit!", "Hit! I'm hit!"],
    "down": ["Man down! Man down!", "We lost one!", "Man down!"],
    "tango": ["Tango down.", "Got him.", "Hostile down."],
    "cover": ["Moving to cover!", "Covering!", "Get down!"],
    "check": ["You good?", "Talk to me, you hit?", "Stay down, stay down!"],
    "start": ["All units, weapons free.", "Go, go, go. Weapons free."],
    "win": ["Area secure. Good work, all units.", "Hostiles neutralized. We're done here."],
    "lose": ["Pull back! Pull back!", "Fall back, we're done here!"],
    "near_win": ["Five more and we're done. Keep pushing!", "Almost there, keep pushing!"],
    "near_lose": ["They're five from winning, hold the line!", "We're losing ground, hold the line!"],
    "minute": ["One minute left.", "Sixty seconds, make it count."],
    "wave": ["More hostiles inbound, get ready!", "Here they come again!", "Second team moving in on you!"],
    "clear": ["Area clear. Reload, they're not done.", "That's all of them. For now.", "Clear. Catch your breath."],
}
SHOUT = {
    "contact": ["There he is!", "Contact!", "Over there!", "I see him!"],
    "down": ["Man down!", "They got him!", "We lost one!"],
    "cover": ["Cover me!", "Moving!", "Get to cover!"],
    "hit": ["I'm hit!", "Hit, I'm hit!"],
    "search": ["Where did he go?", "Check the corners.", "Find him!"],
}
RADIO_VOICES = [(132, 0.9), (36, 0.92), (264, 0.88), (48, 0.9)]
SHOUT_VOICES = [(552, 0.82), (564, 0.85), (288, 0.8), (168, 0.84)]


def write(path: Path, signal: np.ndarray) -> None:
    peak = float(np.max(np.abs(signal))) or 1.0
    data = (np.clip(signal / peak * 0.89, -1, 1) * 32767).astype(np.int16)
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())


def speak(text: str, speaker: int, pace: float, chain: str) -> np.ndarray:
    with tempfile.NamedTemporaryFile(suffix=".wav") as raw:
        subprocess.run([str(PIPER / "venv" / "bin" / "piper"), "-m", str(PIPER / "libritts_r.onnx"), "-s", str(speaker),
                        "--length-scale", str(pace), "--noise-scale", "0.75", "-f", raw.name],
                       input=text.encode(), capture_output=True, check=True)
        out = subprocess.run(["ffmpeg", "-v", "error", "-i", raw.name, "-af", "aresample=%d,%s" % (RATE, chain),
                              "-f", "s16le", "-ac", "1", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(out, dtype=np.int16).astype(np.float32) / 32768.0


def trim(x: np.ndarray, floor: float = 0.02) -> np.ndarray:
    loud = np.nonzero(np.abs(x) > floor * np.max(np.abs(x)))[0]
    return x[max(0, loud[0] - 200):loud[-1] + 600] if loud.size else x


def resonate(x: np.ndarray, freq: float, width: float) -> np.ndarray:
    r = np.exp(-np.pi * width / RATE)
    a1, a2 = -2 * r * np.cos(2 * np.pi * freq / RATE), r * r
    gain = 1 - r
    y = np.zeros_like(x)
    y1 = y2 = 0.0
    for i, v in enumerate(x):
        y0 = gain * v - a1 * y1 - a2 * y2
        y[i] = y0
        y2, y1 = y1, y0
    return y


def lowpass(x: np.ndarray, freq: float, order: int = 3) -> np.ndarray:
    a = np.exp(-2 * np.pi * freq / RATE)
    y = x
    for _ in range(order):
        out = np.zeros_like(y)
        acc = 0.0
        for i, v in enumerate(y):
            acc = (1 - a) * v + a * acc
            out[i] = acc
        y = out
    return y


def band(x: np.ndarray, lo: float, hi: float) -> np.ndarray:
    return lowpass(x - lowpass(x, lo), hi)


def squelch(n: int) -> np.ndarray:
    t = np.arange(n) / RATE
    click = np.sin(2 * np.pi * 1850 * t) * np.exp(-t * 90) * 0.5
    return click + band(RNG.normal(0, 0.5, n), 400, 3500) * np.exp(-t * 35)


def radio(text: str, speaker: int, pace: float) -> np.ndarray:
    chain = ("highpass=f=240,lowpass=f=3900,equalizer=f=2200:t=q:w=1.0:g=4,"
             "acompressor=threshold=0.15:ratio=3:attack=5:release=120:makeup=2")
    words = trim(speak(text, speaker, pace, chain))
    words /= np.max(np.abs(words))
    hiss = band(RNG.normal(0, 0.012, words.size), 400, 3500)
    head, tail = squelch(int(0.07 * RATE)), squelch(int(0.12 * RATE))
    gap = np.zeros(int(0.04 * RATE))
    return np.concatenate([head, gap, words + hiss, tail * 0.8])


def shout(text: str, speaker: int, pace: float) -> np.ndarray:
    chain = "highpass=f=120,equalizer=f=2500:t=q:w=1.0:g=5,acompressor=threshold=0.15:ratio=3:makeup=2"
    return trim(speak(text, speaker, pace, chain))


def thump() -> np.ndarray:
    n = int(0.34 * RATE)
    t = np.arange(n) / RATE
    phase = np.cumsum(2 * np.pi * np.interp(t, [0, 0.3], [72, 36]) / RATE)
    body = np.sin(phase) * np.exp(-t * 10) * np.clip(t / 0.003, 0, 1)
    slap = band(RNG.normal(0, 1, n), 180, 2200) * np.exp(-t * 80) * 0.45
    return np.tanh((body + slap) * 1.8)


def main() -> None:
    for old in [*OUT.glob("radio_*.wav"), *OUT.glob("shout_*.wav")]:
        old.unlink()
    for line, texts in RADIO.items():
        for i, text in enumerate(texts):
            voice, pitch = RADIO_VOICES[i % len(RADIO_VOICES)]
            write(OUT / ("radio_%s_%d.wav" % (line, i)), radio(text, voice, pitch))
    for line, texts in SHOUT.items():
        for i, text in enumerate(texts):
            for v, (voice, pitch) in enumerate(SHOUT_VOICES):
                write(OUT / ("shout_%s_%d.wav" % (line, i * len(SHOUT_VOICES) + v)), shout(text, voice, pitch))
    write(OUT.parent / "hit_thump.wav", thump())
    print(len(list(OUT.glob("*.wav"))), "voces en", OUT)


if __name__ == "__main__":
    main()
