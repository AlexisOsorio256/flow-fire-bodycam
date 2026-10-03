import os
import runpy
import sys
from pathlib import Path

import bpy

TOOLS = Path(__file__).resolve().parent
DONE = Path("/tmp/flowfire_arms_done")


def run() -> None:
    sys.argv = ["blender", "--"]
    runpy.run_path(str(TOOLS / "build_arms.py"), run_name="__main__")
    runpy.run_path(str(TOOLS / "build_fparms.py"), run_name="__main__")
    DONE.write_text("ok")


DONE.unlink(missing_ok=True)
bpy.app.timers.register(lambda: run(), first_interval=0.5)
