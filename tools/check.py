import ast
import fnmatch
import re
import subprocess
import sys
import time
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
CHECKS = ROOT / "tools" / "checks"
VIEW = ["--pos=0.6,0.05,6", "--yaw=0", "--pitch=-7"]


def table(path: Path) -> list:
    return [line.split("|") for line in path.read_text().splitlines() if line.strip()]


def load(only: list) -> tuple:
    situations = dict(table(CHECKS / "situaciones.txt"))
    checks = []
    for path in sorted(CHECKS.glob("*.txt")):
        if path.stem == "situaciones" or (only and path.stem not in only):
            continue
        for name, situation, frame, expr, cond in table(path):
            checks.append({"domain": path.stem, "name": name, "situation": situation, "frame": frame,
                           "expr": expr, "cond": cond})
    return situations, checks


def run(situation: str, args: str, checks: list) -> str:
    argv = args.split() + VIEW
    evals = [a.split("=", 1)[1] for a in argv if a.startswith("--eval=")]
    evals += ["%s:%s" % (c["frame"], c["expr"]) for c in checks if c["frame"] != "gpu"]
    argv = [a for a in argv if not a.startswith("--eval=")]
    cmd = ["timeout", "-k", "5", "60", "godot", "--fixed-fps", "30", "--path", ".", "tools/snap.tscn", "--", "--mode=combat",
           "--out=captures/check_%s.png" % situation, *argv, "--eval=" + ";".join(evals)]
    for _ in range(2):
        done = subprocess.run(cmd, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        if done.returncode not in (124, 137):
            return done.stdout
        print("       %s: Godot se colgó, reintento" % situation)
    return done.stdout


def judge(check: dict, out: str) -> tuple:
    if check["frame"] == "gpu":
        found = re.search(r"([\d.]+) ms, gpu ([\d.]+) ms", out)
        raw = found.group(2) if found else None
        shown = "%s (cuadro %s ms)" % (raw, found.group(1)) if found else None
    else:
        found = re.search(r"^EVAL %s %s -> (.*)$" % (check["frame"], re.escape(check["expr"])), out, re.M)
        raw = shown = found.group(1) if found else None
    try:
        x = raw == "true" if raw in ("true", "false") else ast.literal_eval(raw)
        return shown, bool(eval(check["cond"], {}, {"x": x}))
    except (ValueError, SyntaxError):
        return shown, False


def visual() -> None:
    calm = " --eval=4:main.map.director.stop()"
    poses = {"reposo": "--frames=75" + calm, "apuntando": "--frames=90 --act=aim:45" + calm,
             "inspeccionando": "--frames=93 --act=inspect:48" + calm}
    for pose, args in poses.items():
        run("ver_" + pose, args, [])
    ims = [Image.open(ROOT / "captures" / ("check_ver_%s.png" % p)) for p in poses]
    halves = [im.resize((im.width // 2, im.height // 2)) for im in ims]
    sheet = Image.new("RGB", (max(h.width for h in halves), sum(h.height for h in halves)))
    y = 0
    for h in halves:
        sheet.paste(h, (0, y))
        y += h.height
    sheet.save(ROOT / "captures" / "check_ver.png")
    print("captures/check_ver.png: juego en reposo, apuntando e inspeccionando")


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


MAX_LINES = 300
CARD_LINES = {"tools": 130, "blender": 60}
README_LINES = 140


def cards() -> dict:
    found = {}
    for card in sorted((ROOT / "scripts").glob("*/LEEME.md")):
        line = next((l for l in card.read_text().splitlines() if l.startswith("Checks:")), "")
        found[card.parent.name] = [d.strip() for d in line[len("Checks:"):].split(",") if d.strip()]
    return found


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
    domains = {p.stem for p in CHECKS.glob("*.txt")} - {"situaciones"}
    owned = set()
    for folder in sorted(p for p in (ROOT / "scripts").iterdir() if p.is_dir()):
        card = folder / "LEEME.md"
        if not card.exists():
            problems.append("scripts/%s no tiene LEEME.md" % folder.name)
            continue
        if len(card.read_text().splitlines()) > 60:
            problems.append("scripts/%s/LEEME.md pasa de 60 líneas: resume" % folder.name)
        listed = cards().get(folder.name, [])
        if not listed:
            problems.append("scripts/%s/LEEME.md sin línea «Checks:»" % folder.name)
        for d in listed:
            if d not in domains:
                problems.append("scripts/%s/LEEME.md cita el dominio %s, que no existe" % (folder.name, d))
        owned.update(listed)
    for d in sorted(domains - owned):
        problems.append("el dominio de checks %s no aparece en ninguna ficha" % d)
    for name, limit in CARD_LINES.items():
        card = ROOT / name / "LEEME.md"
        if not card.exists() or len(card.read_text().splitlines()) > limit:
            problems.append("%s/LEEME.md falta o pasa de %d líneas" % (name, limit))
    tools_card = (ROOT / "tools" / "LEEME.md").read_text() if (ROOT / "tools" / "LEEME.md").exists() else ""
    for path in sorted((ROOT / "tools").iterdir()):
        if path.is_file() and path.suffix in (".py", ".sh", ".gd", ".tscn") and path.name not in tools_card:
            problems.append("tools/%s no aparece en tools/LEEME.md" % path.name)
    if len((ROOT / "README.md").read_text().splitlines()) > README_LINES:
        problems.append("README.md pasa de %d líneas: lo de un dominio va a su ficha" % README_LINES)
    table = [l.split("|") for l in (ROOT / "assets" / "procedencia.txt").read_text().splitlines() if l.strip()]
    for row in table:
        if len(row) != 5 or row[3] not in ("propio", "adaptado", "ajeno"):
            problems.append("assets/procedencia.txt: fila mal formada: %s" % "|".join(row))
    for path in sorted((ROOT / "assets").rglob("*")):
        rel = str(path.relative_to(ROOT))
        if path.is_file() and path.suffix not in (".import", ".txt") and not any(fnmatch.fnmatch(rel, r[0]) for r in table):
            problems.append("%s sin procedencia en assets/procedencia.txt" % rel)
    return problems


def changed_domains() -> list:
    out = subprocess.run(["git", "status", "--porcelain"], cwd=ROOT, capture_output=True, text=True).stdout
    paths = [l[3:].split(" -> ")[-1] for l in out.splitlines()]
    domains = set()
    for p in paths:
        parts = p.split("/")
        if parts[0] == "scripts" and len(parts) > 2:
            domains.update(cards().get(parts[1], []))
        elif parts[0] == "tools" and len(parts) > 2 and parts[1] == "checks" and parts[2] != "situaciones.txt":
            domains.add(parts[2][:-4])
        elif parts[0] in ("captures",) or p.endswith(".md"):
            continue
        else:
            return []
    return sorted(domains) if domains else ["-"]


def main() -> int:
    only = [a for a in sys.argv[1:] if not a.startswith("--")]
    start = time.time()
    problems = architecture()
    for p in problems:
        print("FALLA arquitectura  " + p)
    print("arquitectura: %s" % ("ok" if not problems else "%d problemas" % len(problems)))
    if "--arquitectura" in sys.argv:
        return len(problems)
    if "--cambios" in sys.argv:
        only = changed_domains()
        print("cambios -> %s" % (", ".join(only) if only else "todo"))
        if only == ["-"]:
            return len(problems)
    register_classes()
    situations, checks = load(only)
    fails = 0
    used = sorted({c["situation"] for c in checks})
    for situation in used:
        group = [c for c in checks if c["situation"] == situation]
        out = run(situation, situations[situation], group)
        for c in group:
            shown, ok = judge(c, out)
            fails += not ok
            print("%-5s %-12s %-42s %s" % ("ok" if ok else "FALLA", c["domain"], c["name"], shown))
        for line in out.splitlines():
            if "SCRIPT ERROR" in line or "-> error" in line:
                print("      ", line[:160])
    print("check: %d/%d ok en %.0f s (%d arranques)" % (len(checks) - fails, len(checks), time.time() - start, len(used)))
    if "--ver" in sys.argv:
        visual()
    return fails + len(problems)


if __name__ == "__main__":
    sys.exit(main())
