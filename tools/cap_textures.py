import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIMIT = int(sys.argv[1]) if len(sys.argv) > 1 else 1024
MAPS = re.compile(r"^(factory|mapa)")


def patch_import(path: Path) -> bool:
    text = path.read_text()
    made = "process/size_limit=" in text
    text = re.sub(r"process/size_limit=\d+", "process/size_limit=%d" % LIMIT, text)
    if "compress/mode=" in text:
        text = re.sub(r"compress/mode=\d+", "compress/mode=2", text)
    else:
        text = text.replace("[remap]\n", "[remap]\ncompress/mode=2\n")
    if "mipmaps/generate=" in text:
        text = re.sub(r"mipmaps/generate=(true|false)", "mipmaps/generate=true", text)
    else:
        text = text.replace("[remap]\ncompress/mode", "[remap]\nmipmaps/generate=true\ncompress/mode")
    if not made:
        lines = text.splitlines()
        lines = [l for l in lines if not l.startswith("compress/mode") and not l.startswith("mipmaps/generate")]
        head = lines.index("[deps]") - 1
        lines[head:head] = ["process/size_limit=%d" % LIMIT, "compress/mode=2", "mipmaps/generate=true"]
        text = "\n".join(lines) + "\n"
    path.write_text(text)
    return made


def main() -> None:
    total = 0
    for img in sorted((ROOT / "assets" / "models").iterdir()):
        if img.suffix not in (".jpg", ".png", ".webp") or not MAPS.match(img.stem):
            continue
        if img.name.endswith(".import"):
            continue
        total += 1
        patch_import(img.with_name(img.name + ".import"))
    print("limit=%d para %d texturas de mapa" % (LIMIT, total))


if __name__ == "__main__":
    main()
