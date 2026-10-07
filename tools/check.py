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


def card_line(card: Path, key: str) -> list:
    line = next((l for l in card.read_text().splitlines() if l.startswith(key + ":")), "")
    return [d.strip() for d in line[len(key) + 1:].split(",") if d.strip() and d.strip() != "-"]


def cards(key: str = "Checks") -> dict:
    return {card.parent.name: card_line(card, key) for card in sorted((ROOT / "scripts").glob("*/AGENTS.md"))}


def owners() -> dict:
    found = {}
    for path in (ROOT / "scripts").rglob("*.gd"):
        m = re.search(r"^class_name (\w+)", path.read_text(), re.M)
        if m:
            found[m.group(1)] = path
    for line in (ROOT / "project.godot").read_text().splitlines():
        m = re.match(r'(\w+)="\*res://(scripts/\w+/\w+\.gd)"', line)
        if m:
            found[m.group(1)] = ROOT / m.group(2)
    return found


def dependencies() -> dict:
    who = {name: path.parent.name for name, path in owners().items()}
    graph = {}
    for path in (ROOT / "scripts").rglob("*.gd"):
        domain, text = path.parent.name, path.read_text()
        for name, other in who.items():
            if other != domain and re.search(r"\b%s\b" % name, text):
                graph.setdefault(domain, {}).setdefault(other, "%s en %s" % (name, path.name))
        for m in re.finditer(r"res://scripts/(\w+)/", text):
            if m.group(1) != domain:
                graph.setdefault(domain, {}).setdefault(m.group(1), "ruta en %s" % path.name)
    return graph


def cycles(graph: dict) -> list:
    return sorted({tuple(sorted((a, b))) for a in graph for b in graph[a] if a in graph.get(b, {})})


def stale_mentions(card: Path, known: dict) -> list:
    found = []
    for token in re.findall(r"`([^`\s]+)`", card.read_text()):
        if any(c in token for c in "<>*{}[]()=\"'~") or token.startswith(".") or "://" in token:
            continue
        if re.search(r"\.(gd|py|sh|blend|glb|txt|tscn|cfg|md)$", token) or token.endswith("/"):
            name = token.rstrip("/")
            if not ((ROOT / name).exists() or (card.parent / name).exists() or any(ROOT.rglob(Path(name).name))):
                found.append(token)
        elif re.match(r"^\w+\.\w+$", token) and token.split(".")[0] in known:
            cls, member = token.split(".")
            if not re.search(r"^(static )?(func|var|const|signal) %s\b" % member, known[cls].read_text(), re.M):
                found.append(token)
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
        card = folder / "AGENTS.md"
        if not card.exists():
            problems.append("scripts/%s no tiene AGENTS.md" % folder.name)
            continue
        if len(card.read_text().splitlines()) > 60:
            problems.append("scripts/%s/AGENTS.md pasa de 60 líneas: resume" % folder.name)
        listed = cards().get(folder.name, [])
        if not listed:
            problems.append("scripts/%s/AGENTS.md sin línea «Checks:»" % folder.name)
        for d in listed:
            if d not in domains:
                problems.append("scripts/%s/AGENTS.md cita el dominio %s, que no existe" % (folder.name, d))
        owned.update(listed)
    for d in sorted(domains - owned):
        problems.append("el dominio de checks %s no aparece en ninguna ficha" % d)
    graph = dependencies()
    declared = cards("Usa")
    for domain, used in sorted(graph.items()):
        for other, where in sorted(used.items()):
            if other not in declared.get(domain, []):
                problems.append("scripts/%s usa %s (%s) sin declararlo en «Usa:» de su AGENTS.md: si es a propósito, "
                                "añádelo; mejor, mueve lo común a comun/ o avisa con una señal" % (domain, other, where))
    for domain, listed in sorted(declared.items()):
        for other in listed:
            if other not in graph.get(domain, {}):
                problems.append("scripts/%s declara «Usa: %s» pero ya no lo usa: quítalo (la deuda bajó)" % (domain, other))
    known = owners()
    for card in sorted(list(ROOT.glob("*/AGENTS.md")) + list((ROOT / "scripts").glob("*/AGENTS.md")) + [ROOT / "AGENTS.md"]):
        for token in stale_mentions(card, known):
            problems.append("%s cita `%s`, que ya no existe: actualiza la ficha" % (card.relative_to(ROOT), token))
    if len((ROOT / "AGENTS.md").read_text().splitlines()) > 100 or "@AGENTS.md" not in (ROOT / "CLAUDE.md").read_text():
        problems.append("AGENTS.md pasa de 100 líneas o CLAUDE.md no lo importa")
    for name, limit in CARD_LINES.items():
        card = ROOT / name / "AGENTS.md"
        if not card.exists() or len(card.read_text().splitlines()) > limit:
            problems.append("%s/AGENTS.md falta o pasa de %d líneas" % (name, limit))
    tools_card = (ROOT / "tools" / "AGENTS.md").read_text() if (ROOT / "tools" / "AGENTS.md").exists() else ""
    for path in sorted((ROOT / "tools").iterdir()):
        if path.is_file() and path.suffix in (".py", ".sh", ".gd", ".tscn") and path.name not in tools_card:
            problems.append("tools/%s no aparece en tools/AGENTS.md" % path.name)
    if len((ROOT / "README.md").read_text().splitlines()) > README_LINES:
        problems.append("README.md pasa de %d líneas: lo de un dominio va a su ficha" % README_LINES)
    presets = (ROOT / "export_presets.cfg").read_text()
    game = re.search(r'^config/version="([^"]+)"', (ROOT / "project.godot").read_text(), re.M)
    problems += ["project.godot no declara config/version: la versión del juego vive ahí y solo ahí"] if not game else []
    problems += ["export_presets.cfg: %s dice %s y config/version dice %s: ponlos igual" % (f, v, game.group(1))
                 for f, v in re.findall(r'^(application/(?:prod|file)_version|version/name)="([^"]+)"', presets, re.M) if game and v != game.group(1)]
    problems += ["export_presets.cfg sin version/code entero: Android no distingue una entrega de otra"] if not re.search(r'^version/code=\d+', presets, re.M) else []
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


def report() -> None:
    graph = dependencies()
    loops = cycles(graph)
    rows = []
    for card in sorted((ROOT / "scripts").glob("*/AGENTS.md")):
        domain = card.parent.name
        files = list(card.parent.glob("*.gd"))
        sizes = [len(f.read_text().splitlines()) for f in files]
        big = sum(1 for n in sizes if n > 250)
        pending = sum(1 for l in card.read_text().splitlines() if l.startswith("- Pendiente"))
        loop = sum(1 for c in loops if domain in c)
        score = pending * 3 + big * 2 + loop + len(graph.get(domain, {}))
        rows.append((score, domain, sum(sizes), len(files), big, len(graph.get(domain, {})), loop, pending))
    print("%-10s %6s %7s %8s %5s %7s %9s %6s" % ("dominio", "deuda", "líneas", "scripts", ">250", "usa", "ciclos", "pend."))
    for r in sorted(rows, reverse=True):
        print("%-10s %6d %7d %8d %5d %7d %9d %6d" % (r[1], r[0], r[2], r[3], r[4], r[5], r[6], r[7]))
    print("ciclos entre dominios: %d (%s)" % (len(loops), ", ".join("%s<->%s" % c for c in loops)))


def main() -> int:
    only = [a for a in sys.argv[1:] if not a.startswith("--")]
    start = time.time()
    problems = architecture()
    for p in problems:
        print("FALLA arquitectura  " + p)
    print("arquitectura: %s" % ("ok" if not problems else "%d problemas" % len(problems)))
    if "--informe" in sys.argv:
        report()
        return len(problems)
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
