import os
import re
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MAX_LINES = 350
CODE = ["scripts/**/*.gd", "addons/**/*.gd", "tools/*.gd", "shaders/*.gdshader", "tools/*.py", "blender/**/*.py"]
VERSION_KEYS = ("application/file_version", "application/product_version", "version/name")


def godot() -> str:
    return os.environ.get("GODOT", "godot")


def run(seconds: int, args: list) -> subprocess.CompletedProcess:
    try:
        return subprocess.run([godot()] + args, cwd=ROOT, capture_output=True, text=True, timeout=seconds)
    except subprocess.TimeoutExpired:
        return subprocess.CompletedProcess(args, 124, "", "")


def code_files() -> list:
    return sorted({path for pattern in CODE for path in ROOT.glob(pattern)})


def is_comment_or_docstring(line: str, suffix: str) -> bool:
    text = line.strip()
    if text.startswith("#!"):
        return False
    if text.startswith(("#", "//")):
        return True
    return suffix == ".py" and text.startswith(('"""', "'''"))


def version_problems() -> list:
    game = re.search(r'^config/version="([^"]+)"', (ROOT / "project.godot").read_text(encoding="utf-8"), re.M)
    if not game:
        return ["project.godot no declara config/version"]
    presets = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
    found = dict(re.findall(r'^([\w/]+)="([^"]+)"', presets, re.M))
    problems = []
    for key in VERSION_KEYS:
        if key not in found:
            problems.append("export_presets.cfg no declara %s" % key)
        elif found[key] != game.group(1):
            problems.append("export_presets.cfg: %s es %s y config/version es %s" % (key, found[key], game.group(1)))
    if not re.search(r"^version/code=\d+", presets, re.M):
        problems.append("export_presets.cfg: version/code debe ser un entero")
    return problems


def architecture() -> list:
    problems = []
    for path in code_files():
        lines = path.read_text(encoding="utf-8").splitlines()
        rel = path.relative_to(ROOT).as_posix()
        if len(lines) > MAX_LINES:
            problems.append("%s tiene %d líneas (máx. %d): hay que partirlo" % (rel, len(lines), MAX_LINES))
        for number, line in enumerate(lines, 1):
            if is_comment_or_docstring(line, path.suffix):
                problems.append("%s:%d lleva comentario o docstring: el código se explica con nombres" % (rel, number))
                break
    loose = [p.name for p in (ROOT / "scripts").glob("*.gd")]
    if loose:
        problems.append("scripts sueltos fuera de un dominio: %s" % ", ".join(loose))
    for folder in sorted(p for p in (ROOT / "scripts").iterdir() if p.is_dir()):
        if not (folder / "AGENTS.md").exists():
            problems.append("scripts/%s no tiene AGENTS.md" % folder.name)
    if "@AGENTS.md" not in (ROOT / "CLAUDE.md").read_text(encoding="utf-8"):
        problems.append("CLAUDE.md no importa AGENTS.md")
    if not (ROOT / "tools" / "AGENTS.md").exists():
        problems.append("falta tools/AGENTS.md")
    return problems + version_problems()


def register_classes() -> None:
    cache = ROOT / ".godot" / "global_script_class_cache.cfg"
    known = cache.read_text(encoding="utf-8") if cache.exists() else ""
    names = [m for path in ROOT.glob("**/*.gd") if ".godot" not in path.parts
             for m in re.findall(r"^class_name (\w+)", path.read_text(encoding="utf-8"), re.M)]
    missing = [n for n in names if '&"%s"' % n not in known]
    if missing:
        print("       clases nuevas sin registrar (%s): reimporto" % ", ".join(missing))
        run(300, ["--headless", "--path", ".", "--import"])


def syntax() -> list:
    r = run(120, ["--headless", "--path", ".", "-s", "tools/syntax.gd"])
    out = r.stdout + r.stderr
    spots = []
    for line in out.splitlines():
        if "SCRIPT ERROR" not in line and "SINTAXIS falla" not in line:
            continue
        found = re.search(r"reload \((res://\S+\.gd):(\d+)\)", line)
        spot = "%s:%s" % (found.group(1), found.group(2)) if found else line.strip()[:120]
        if spot not in spots:
            spots.append(spot)
    if not spots and ("SINTAXIS ok" not in out or r.returncode != 0):
        spots = ["arranque (sin resumen)"]
    return spots


def report() -> None:
    print("%-10s %6s %8s %6s %6s" % ("dominio", "líneas", "scripts", ">250", "pend."))
    for card in sorted((ROOT / "scripts").glob("*/AGENTS.md")):
        files = list(card.parent.glob("*.gd"))
        sizes = [len(f.read_text(encoding="utf-8").splitlines()) for f in files]
        pending = sum(1 for l in card.read_text(encoding="utf-8").splitlines() if l.startswith("- Pendiente"))
        print("%-10s %6d %8d %6d %6d" % (card.parent.name, sum(sizes), len(files),
                                         sum(1 for n in sizes if n > 250), pending))


def weight() -> None:
    listed = subprocess.run(["git", "ls-files", "-z"], cwd=ROOT, capture_output=True, text=True).stdout.split("\0")
    sizes = sorted(((ROOT / name).stat().st_size, name) for name in listed if name and (ROOT / name).exists())
    print("trackeado: %.1f MB en %d ficheros; los mayores:" % (sum(s for s, _ in sizes) / 1048576, len(sizes)))
    for size, name in sizes[-8:][::-1]:
        print("  %6.1f MB  %s" % (size / 1048576, name))


def main() -> int:
    start = time.time()
    problems = architecture()
    for p in problems:
        print("FALLA arquitectura  " + p)
    print("arquitectura: %s (%.2f s)" % ("ok" if not problems else "%d problemas" % len(problems), time.time() - start))
    if "--informe" in sys.argv:
        report()
        weight()
        return len(problems)
    if "--arquitectura" in sys.argv:
        return len(problems)
    register_classes()
    bad = syntax()
    for spot in bad:
        print("FALLA sintaxis  " + spot)
    print("sintaxis: %s (%.2f s)" % ("ok" if not bad else "%d fallos" % len(bad), time.time() - start))
    return len(problems) + len(bad)


if __name__ == "__main__":
    sys.exit(main())
