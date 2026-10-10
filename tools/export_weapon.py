import contextlib
import io
from pathlib import Path

import bpy

TOOLS = Path(__file__).resolve().parent
NAME = globals().get("NAME", "ar15")
BLEND = TOOLS.parent / "blender" / (NAME + ".blend")
OUT = TOOLS.parent / "assets" / "models" / (NAME + ".glb")
DONE = TOOLS.parent / "build" / "avisos" / "weapon_done"


def export() -> None:
    for obj in bpy.data.objects:
        obj.name = obj.name.split(".")[0]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.data.objects:
        obj.select_set(True)
    with contextlib.redirect_stdout(io.StringIO()):
        bpy.ops.export_scene.gltf(filepath=str(OUT), export_format="GLB", use_selection=True,
                                  export_yup=True, export_image_format="AUTO", export_animations=False)
    bpy.ops.wm.save_mainfile(compress=True)


def rebuild() -> None:
    DONE.parent.mkdir(parents=True, exist_ok=True)
    DONE.unlink(missing_ok=True)
    if Path(bpy.data.filepath) != BLEND:
        bpy.ops.wm.open_mainfile(filepath=str(BLEND))

    def run() -> None:
        export()
        DONE.write_text("ok")

    bpy.app.timers.register(run, first_interval=0.5)


if __name__ == "__main__":
    rebuild()
