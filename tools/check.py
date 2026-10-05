import ast
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
    subprocess.run(["tools/refcmp.sh", "idle", "aim", "inspect"], cwd=ROOT)
    ims = [Image.open(ROOT / "captures" / ("ref_%s.png" % n)) for n in ("idle", "aim", "inspect")]
    halves = [im.resize((im.width // 2, im.height // 2)) for im in ims]
    sheet = Image.new("RGB", (max(h.width for h in halves), sum(h.height for h in halves)))
    y = 0
    for h in halves:
        sheet.paste(h, (0, y))
        y += h.height
    sheet.save(ROOT / "captures" / "check_ver.png")
    print("captures/check_ver.png: referencia | juego en reposo, apuntando e inspeccionando")


def main() -> int:
    only = [a for a in sys.argv[1:] if not a.startswith("--")]
    start = time.time()
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
    return fails


if __name__ == "__main__":
    sys.exit(main())
