import os
import re
import shutil
import subprocess
import sys
import tarfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUILDS = ROOT / "build"
EXE = {"windows": "FlowFireBodycam.exe", "linux": "FlowFireBodycam.x86_64"}
PRESET = {"windows": "Windows", "linux": "Linux", "android": "Android"}


def godot() -> str:
    return os.environ.get("GODOT", "godot")


def version() -> str:
    cfg = (ROOT / "project.godot").read_text()
    return re.search(r'^config/version="([^"]+)"', cfg, re.M).group(1)


def export(platform: str, out: Path) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    args = [godot(), "--headless", "--path", ".", "--export-release", PRESET[platform], str(out)]
    try:
        r = subprocess.run(args, cwd=ROOT, capture_output=True, text=True, timeout=1200)
    except subprocess.TimeoutExpired:
        print("FALLA %s: el export no acabó en 20 min" % platform)
        raise SystemExit(1)
    for line in (r.stdout + r.stderr).splitlines():
        if "ERROR" in line and "icon" not in line:
            print("FALLA %s: %s" % (platform, line.strip()[:120]))


def zip_exe(platform: str, tag: str) -> None:
    exe = BUILDS / platform / EXE[platform]
    if not exe.exists():
        print("FALLA " + platform + ": faltó el ejecutable")
        raise SystemExit(1)
    with zipfile.ZipFile(BUILDS / "dist" / ("FlowFireBodycam-%s-%s.zip" % (tag, platform)), "w", zipfile.ZIP_DEFLATED) as z:
        z.write(exe, EXE[platform])


def tar_exe(platform: str, tag: str) -> None:
    exe = BUILDS / platform / EXE[platform]
    if not exe.exists():
        print("FALLA " + platform + ": faltó el ejecutable")
        raise SystemExit(1)
    with tarfile.open(BUILDS / "dist" / ("FlowFireBodycam-%s-%s.tar.gz" % (tag, platform)), "w:gz") as t:
        t.add(exe, arcname=EXE[platform])


def build(platform: str) -> None:
    tag = version()
    out = BUILDS / platform / EXE.get(platform, "FlowFireBodycam-%s.apk" % tag)
    if platform == "android":
        out = BUILDS / "dist" / ("FlowFireBodycam-%s-android.apk" % tag)
    export(platform, out)
    if platform == "windows":
        zip_exe(platform, tag)
    elif platform == "linux":
        tar_exe(platform, tag)
    print("listo %s -> %s" % (platform, out))


def main() -> int:
    want = sys.argv[1:] or ["windows", "linux", "android"]
    unknown = [w for w in want if w not in PRESET]
    if unknown:
        print("¿qué plataforma? %s" % ", ".join(sorted(PRESET)))
        return 1
    (BUILDS / "dist").mkdir(parents=True, exist_ok=True)
    for platform in want:
        build(platform)
    for platform in want:
        shutil.rmtree(BUILDS / platform, ignore_errors=True)
    trailing = sorted((BUILDS / "dist").glob("FlowFireBodycam-*"))
    for f in trailing:
        print("%8.1f MB  %s" % (f.stat().st_size / 1048576, f.name))
    return 0


if __name__ == "__main__":
    sys.exit(main())
