import contextlib
import io
from pathlib import Path

import bpy

TOOLS = Path(__file__).resolve().parent
BLEND = TOOLS.parent / "blender" / "soldier.blend"
OUT = TOOLS.parent / "assets" / "models" / "enemy.glb"
DONE = Path("/tmp/flowfire_soldier_done")
HELPERS = ("Floor", "ViewCam")


def export() -> None:
    arm = bpy.data.objects["EnemyRig"]
    action = arm.animation_data.action
    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.data.objects:
        obj.select_set(obj.name not in HELPERS)
    bpy.context.view_layer.objects.active = arm
    with contextlib.redirect_stdout(io.StringIO()):
        bpy.ops.export_scene.gltf(filepath=str(OUT), export_format="GLB", use_selection=True,
                                  export_def_bones=True, export_animations=True,
                                  export_animation_mode="ACTIONS", export_force_sampling=True,
                                  export_skins=True, export_yup=True, export_image_format="AUTO",
                                  export_anim_single_armature=True, export_influence_nb=4)
    arm.animation_data.action = action
    bpy.ops.wm.save_mainfile(compress=True)


def rebuild() -> None:
    DONE.unlink(missing_ok=True)
    if Path(bpy.data.filepath) != BLEND:
        bpy.ops.wm.open_mainfile(filepath=str(BLEND))

    def run() -> None:
        export()
        DONE.write_text("ok")

    bpy.app.timers.register(run, first_interval=0.5)


if __name__ == "__main__":
    rebuild()
