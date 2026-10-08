import re
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MAX_LINES = 350


def architecture() -> list:
    problems = []
    for path in sorted(list((ROOT / "scripts").rglob("*.gd")) + list((ROOT / "tools").glob("*.gd"))):
        lines = path.read_text().splitlines()
        rel = path.relative_to(ROOT)
        if len(lines) > MAX_LINES:
            problems.append("%s tiene %d líneas (máx. %d): parte el módulo" % (rel, len(lines), MAX_LINES))
        if any(l.lstrip().startswith("#") for l in lines):
            problems.append("%s lleva comentarios: el código se explica con nombres" % rel)
    loose = [p.name for p in (ROOT / "scripts").glob("*.gd")]
    if loose:
        problems.append("scripts sueltos fuera de un dominio: %s" % ", ".join(loose))
    for folder in sorted(p for p in (ROOT / "scripts").iterdir() if p.is_dir()):
        if not (folder / "AGENTS.md").exists():
            problems.append("scripts/%s no tiene AGENTS.md" % folder.name)
    if "@AGENTS.md" not in (ROOT / "CLAUDE.md").read_text():
        problems.append("CLAUDE.md no importa AGENTS.md")
    if not (ROOT / "tools" / "AGENTS.md").exists():
        problems.append("falta tools/AGENTS.md")
    presets = (ROOT / "export_presets.cfg").read_text()
    game = re.search(r'^config/version="([^"]+)"', (ROOT / "project.godot").read_text(), re.M)
    problems += ["project.godot no declara config/version: la versión del juego vive ahí y solo ahí"] if not game else []
    problems += ["export_presets.cfg: %s dice %s y config/version dice %s: ponlos igual" % (f, v, game.group(1))
                 for f, v in re.findall(r'^(application/(?:prod|file)_version|version/name)="([^"]+)"', presets, re.M) if game and v != game.group(1)]
    problems += ["export_presets.cfg sin version/code entero: Android no distingue una entrega de otra"] if not re.search(r'^version/code=\d+', presets, re.M) else []
    return problems


def register_classes() -> None:
    cache = ROOT / ".godot" / "global_script_class_cache.cfg"
    known = cache.read_text() if cache.exists() else ""
    names = [m for path in ROOT.glob("**/*.gd") if ".godot" not in path.parts
             for m in re.findall(r"^class_name (\w+)", path.read_text(), re.M)]
    missing = [n for n in names if '&"%s"' % n not in known]
    if missing:
        print("       clases nuevas sin registrar (%s): reimporto" % ", ".join(missing))
        subprocess.run(["timeout", "300", "godot", "--headless", "--path", ".", "--import"], cwd=ROOT,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def syntax() -> list:
    r = subprocess.run(["timeout", "120", "godot", "--headless", "--path", ".", "-s", "tools/syntax.gd"],
                       cwd=ROOT, capture_output=True, text=True)
    out = r.stdout + r.stderr
    spots = []
    for line in out.splitlines():
        if "SCRIPT ERROR" not in line:
            continue
        m = re.search(r"reload \((res://\S+\.gd):(\d+)\)", line)
        spot = "%s:%s" % (m.group(1), m.group(2)) if m else line.strip()[:120]
        if spot not in spots:
            spots.append(spot)
    if not spots and ("SINTAXIS ok" not in out or r.returncode != 0):
        spots = ["arranque (sin resumen)"]
    return spots


def report() -> None:
    print("%-10s %6s %8s %6s %6s" % ("dominio", "líneas", "scripts", ">250", "pend."))
    for card in sorted((ROOT / "scripts").glob("*/AGENTS.md")):
        files = list(card.parent.glob("*.gd"))
        sizes = [len(f.read_text().splitlines()) for f in files]
        pending = sum(1 for l in card.read_text().splitlines() if l.startswith("- Pendiente"))
        print("%-10s %6d %8d %6d %6d" % (card.parent.name, sum(sizes), len(files),
                                         sum(1 for n in sizes if n > 250), pending))


def main() -> int:
    start = time.time()
    problems = architecture()
    for p in problems:
        print("FALLA arquitectura  " + p)
    print("arquitectura: %s (%.2f s)" % ("ok" if not problems else "%d problemas" % len(problems), time.time() - start))
    if "--informe" in sys.argv:
        report()
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
