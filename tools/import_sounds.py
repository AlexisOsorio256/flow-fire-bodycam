import subprocess
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
AUDIO = ROOT / "assets" / "audio"
CACHE = Path.home() / ".cache" / "flowfire" / "freesound"
RATE = 48000

RANGE = "811818_15983207"
MOSSBERG = "https://opengameart.org/sites/default/files/Prepared%20SFX%20Library.7z|Prepared SFX Library/Mossberg/"
DEAGLE = "https://cdn.creazilla.com/sounds/15434355/desert-eagle-ae-desert-eagle-sound.flac"
SOUNDS = [
    ("shotgun_1.ogg", MOSSBERG + "N_26P.wav", "shot", {"at": 0.75}),
    ("shotgun_2.ogg", MOSSBERG + "N_26P.wav", "shot", {"at": 4.54}),
    ("shotgun_3.ogg", MOSSBERG + "N_26P.wav", "shot", {"at": 7.91}),
    ("shotgun_pump.wav", MOSSBERG + "N_26P.wav", "cut", {"span": (1.30, 1.95)}),
    ("shotgun_pump_fwd.wav", MOSSBERG + "N_26P.wav", "cut", {"span": (1.70, 1.95)}),
    ("shotgun_shell.wav", MOSSBERG + "N_26P.wav", "cut", {"span": (1.82, 1.97)}),
    ("shot_1.ogg", RANGE, "shot", {"at": 6.46}),
    ("shot_2.ogg", RANGE, "shot", {"at": 14.30}),
    ("shot_3.ogg", RANGE, "shot", {"at": 226.25}),
    ("shot_4.ogg", RANGE, "shot", {"at": 251.40}),
    ("shot_5.ogg", RANGE, "shot", {"at": 495.98}),
    ("rifle_1.ogg", "815698_15956618", "shot", {"at": 1.01}),
    ("rifle_2.ogg", "815698_15956618", "shot", {"at": 4.965}),
    ("rifle_3.ogg", "815698_15956618", "shot", {"at": 7.275}),
    ("rifle_4.ogg", "815698_15956618", "shot", {"at": 10.73}),
    ("rifle_5.ogg", "815698_15956618", "shot", {"at": 13.06}),
    ("rifle_magout.wav", "725397_7157894", "cut", {"span": (0.38, 0.75)}),
    ("rifle_magin.wav", "725397_7157894", "cut", {"span": (2.10, 2.80)}),
    ("rifle_tap.wav", "725397_7157894", "cut", {"span": (3.08, 3.40)}),
    ("rifle_charge.wav", "725397_7157894", "cut", {"span": (3.58, 3.80)}),
    ("rifle_bolt.wav", "725397_7157894", "cut", {"span": (4.15, 4.50)}),
    ("rifle_shoulder.wav", "725397_7157894", "cut", {"span": (4.85, 5.20)}),
    ("shot_far_0.ogg", RANGE, "far", {"at": 14.30}),    ("shot_far_1.ogg", RANGE, "far", {"at": 226.25}),
    ("shot_far_2.ogg", RANGE, "far", {"at": 251.40}),
    ("deagle_1.ogg", DEAGLE, "shot", {"at": 0.10, "filters": "bass=g=4:f=100:w=0.5,volume=1dB,alimiter=limit=0.95"}),
    ("barrett_1.ogg", "865990_19132311", "shot", {"at": 0.09}),
    ("breath_scared.ogg", "554307_10081166", "loop", {"span": (2.0, 32.0), "rms": -20}),
    ("amb_factory.ogg", "427861_4437257", "loop", {"span": (10.0, 70.0), "rms": -22,
        "layer": ("240895_1134415", (40.0, 100.0), -28)}),
    ("amb_lobby.ogg", "637513_612689", "loop", {"span": (5.0, 65.0), "rms": -20}),
    ("voice/pain_0.wav", "610998_1038806", "take", {"index": 0, "max": 0.8}),
    ("voice/pain_1.wav", "610998_1038806", "take", {"index": 1, "max": 0.8}),
    ("voice/pain_2.wav", "610998_1038806", "take", {"index": 3, "max": 0.8}),
    ("voice/pain_3.wav", "547209_129727", "take", {"index": 0}),
    ("voice/pain_4.wav", "257709_4028838", "take", {"index": 0}),
    ("voice/pain_5.wav", "257710_4028838", "take", {"index": 0}),
    ("voice/dying_0.wav", "610998_1038806", "take", {"index": 4}),
    ("voice/dying_1.wav", "610998_1038806", "take", {"index": 5}),
    ("voice/dying_2.wav", "610998_1038806", "take", {"index": 6}),
]


def fetch(sound: str) -> np.ndarray:
    CACHE.mkdir(parents=True, exist_ok=True)
    if "|" in sound:
        url, member = sound.split("|", 1)
        archive = CACHE / url.split("/")[-1]
        if not archive.exists():
            subprocess.run(["curl", "-sfL", "--retry", "3", "-o", str(archive), url], check=True)
        raw = subprocess.run(["7z", "x", "-so", str(archive), member], capture_output=True, check=True).stdout
        raw = subprocess.run(["ffmpeg", "-v", "error", "-i", "-", "-ac", "2", "-ar", str(RATE), "-f", "s16le", "-"],
                             input=raw, capture_output=True, check=True).stdout
        return np.frombuffer(raw, np.int16).astype(np.float32).reshape(-1, 2) / 32768
    if sound.startswith("http"):
        path = CACHE / sound.split("/")[-1]
        if not path.exists():
            subprocess.run(["curl", "-sfL", "--retry", "3", "-o", str(path), sound], check=True)
        raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-ac", "2", "-ar", str(RATE), "-f", "s16le", "-"],
                             capture_output=True, check=True).stdout
        return np.frombuffer(raw, np.int16).astype(np.float32).reshape(-1, 2) / 32768
    path = CACHE / (sound + ".ogg")
    if not path.exists():
        number = int(sound.split("_")[0])
        url = "https://cdn.freesound.org/previews/%d/%s-hq.ogg" % (number // 1000, sound)
        subprocess.run(["curl", "-sfL", "--retry", "3", "-o", str(path), url], check=True)
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-ac", "2", "-ar", str(RATE), "-f", "s16le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.int16).astype(np.float32).reshape(-1, 2) / 32768


def save(name: str, x: np.ndarray, filters: str = "") -> None:
    pcm = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    out = AUDIO / name
    codec = ["-c:a", "libvorbis", "-q:a", "6"] if out.suffix == ".ogg" else ["-ac", "1"]
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "s16le", "-ar", str(RATE), "-ac", "2", "-i", "-",
                    *(["-af", filters] if filters else []), *codec, str(out)], input=pcm.tobytes(), check=True)


def peak(x: np.ndarray, db: float) -> np.ndarray:
    return x / (np.abs(x).max() + 1e-9) * 10 ** (db / 20)


def rms(x: np.ndarray, db: float) -> np.ndarray:
    return x / (np.sqrt(np.mean(x ** 2)) + 1e-9) * 10 ** (db / 20)


def fade(x: np.ndarray, seconds: float) -> np.ndarray:
    n = int(seconds * RATE)
    x[-n:] *= np.linspace(1, 0, n)[:, None] ** 2
    x[:96] *= np.linspace(0, 1, 96)[:, None]
    return x


def shot(x: np.ndarray, at: float) -> np.ndarray:
    start = int((at - 0.05) * RATE)
    window = np.abs(x[start:start + RATE // 4]).max(axis=1)
    onset = start + int(np.argmax(window > window.max() * 0.3)) - int(0.004 * RATE)
    return fade(x[onset:onset + int(1.6 * RATE)].copy(), 0.9)


def loop(x: np.ndarray, span: tuple, xfade: float = 2.0) -> np.ndarray:
    a, b, n = int(span[0] * RATE), int(span[1] * RATE), int(xfade * RATE)
    y = x[a:b].copy()
    ramp = np.linspace(0, np.pi / 2, n)[:, None]
    y[:n] = y[:n] * np.sin(ramp) + x[b:b + n] * np.cos(ramp)
    return y


def takes(x: np.ndarray, floor_db: float = -38.0, gap: float = 0.18, pad: float = 0.03) -> list:
    m = x.mean(axis=1)
    db = 20 * np.log10(np.sqrt(np.convolve(m ** 2, np.ones(480) / 480, "same")) + 1e-7)
    loud = db > db.max() + floor_db
    hold = np.convolve(loud, np.ones(int(gap * RATE)), "same") > 0
    edges = np.flatnonzero(np.diff(np.concatenate([[0], hold.astype(int), [0]])))
    spans = [(max(0, a - int(pad * RATE)), min(len(m), b + int(pad * RATE))) for a, b in zip(edges[::2], edges[1::2])]
    return [x[a:b].copy() for a, b in spans if b - a > 0.15 * RATE]


def build(name: str, sound: str, kind: str, opts: dict) -> None:
    x = fetch(sound)
    if kind == "shot":
        save(name, peak(shot(x, opts["at"]), -0.5), opts.get("filters", ""))
    elif kind == "far":
        save(name, peak(shot(x, opts["at"]), -0.5),
             "lowpass=f=1100:poles=2,lowpass=f=1100:poles=2,aecho=0.8:0.6:60|130:0.35|0.22,volume=4dB,alimiter=limit=0.89")
    elif kind == "loop":
        y = rms(loop(x, opts["span"]), opts["rms"])
        if "layer" in opts:
            other, span, level = opts["layer"]
            y = y + rms(loop(fetch(other), span), level)
        save(name, y / max(1.0, np.abs(y).max() / 0.95))
    elif kind == "cut":
        a, b = opts["span"]
        save(name, peak(fade(x[int(a * RATE):int(b * RATE)].copy(), 0.05), -6.0))
    elif kind == "take":
        y = takes(x)[opts["index"]]
        save(name, peak(fade(y[:int(opts.get("max", 9.0) * RATE)], 0.12), -1.0))


def main() -> None:
    only = sys.argv[1:]
    for name, sound, kind, opts in SOUNDS:
        if not only or any(o in name for o in only):
            build(name, sound, kind, opts)
            source = sound if ("|" in sound or sound.startswith("http")) else "freesound.org/s/%s" % sound.split("_")[0]
            print(name, "<-", source)


if __name__ == "__main__":
    main()
