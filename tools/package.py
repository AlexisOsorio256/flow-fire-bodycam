import os
import re
import shutil
import subprocess
import sys
import tarfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / "build"
DIST = BUILD / "dist"
PRESET = {"windows": "Windows", "linux": "Linux", "android": "Android"}
EXE = {"windows": "FlowFireBodycam.exe", "linux": "FlowFireBodycam.x86_64"}


def godot() -> str:
    return os.environ.get("GODOT", "godot")


def fail(message: str) -> None:
    print("FALLA " + message)
    raise SystemExit(1)


def version() -> str:
    found = re.search(r'^config/version="([^"]+)"', (ROOT / "project.godot").read_text(encoding="utf-8"), re.M)
    if not found:
        fail("project.godot no declara config/version")
    return found.group(1)


def export(platform: str, out: Path) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    out.unlink(missing_ok=True)
    args = [godot(), "--headless", "--path", ".", "--export-release", PRESET[platform], str(out)]
    try:
        result = subprocess.run(args, cwd=ROOT, capture_output=True, text=True, timeout=1200)
    except subprocess.TimeoutExpired:
        fail("%s: el export no acabó en 20 min" % platform)
    if result.returncode != 0 or not out.exists():
        errors = [line.strip()[:160] for line in (result.stdout + result.stderr).splitlines() if "ERROR" in line]
        fail("%s: no salió %s (código %d)\n  %s" % (platform, out.name, result.returncode, "\n  ".join(errors[:8])))


def pack(platform: str, exe: Path, tag: str) -> Path:
    if platform == "windows":
        target = DIST / ("FlowFireBodycam-%s-windows.zip" % tag)
        with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as zipped:
            zipped.write(exe, EXE[platform])
    else:
        target = DIST / ("FlowFireBodycam-%s-linux.tar.gz" % tag)
        with tarfile.open(target, "w:gz") as tarred:
            tarred.add(exe, arcname=EXE[platform])
    return target


def build(platform: str, tag: str) -> Path:
    if platform == "android":
        apk = DIST / ("FlowFireBodycam-%s-android.apk" % tag)
        export(platform, apk)
        return apk
    exe = BUILD / platform / EXE[platform]
    try:
        export(platform, exe)
        return pack(platform, exe, tag)
    finally:
        shutil.rmtree(BUILD / platform, ignore_errors=True)


def main() -> int:
    want = sys.argv[1:] or list(PRESET)
    unknown = [w for w in want if w not in PRESET]
    if unknown:
        print("¿qué plataforma? %s" % ", ".join(PRESET))
        return 1
    tag = version()
    for platform in want:
        out = build(platform, tag)
        print("%8.1f MB  %s" % (out.stat().st_size / 1048576, out.name))
    return 0


if __name__ == "__main__":
    sys.exit(main())
