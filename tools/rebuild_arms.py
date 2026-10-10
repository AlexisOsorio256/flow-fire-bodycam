import contextlib
import io
from pathlib import Path

import bpy

TOOLS = Path(__file__).resolve().parent
BLEND = TOOLS.parent / "blender" / "fparms.blend"
OUT = TOOLS.parent / "assets" / "models" / "fps_arms.glb"
DONE = TOOLS.parent / "build" / "avisos" / "arms_done"


def open_source() -> None:
    if Path(bpy.data.filepath) != BLEND:
        bpy.ops.wm.open_mainfile(filepath=str(BLEND))


def export() -> None:
    arm = bpy.data.objects["ArmsRig"]
    action = arm.animation_data.action
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    bpy.data.objects["Arms_Mesh"].select_set(True)
    for obj in bpy.data.objects:
        if obj.name.endswith("Mount"):
            obj.select_set(True)
    bpy.context.view_layer.objects.active = arm
    with contextlib.redirect_stdout(io.StringIO()):
        bpy.ops.export_scene.gltf(filepath=str(OUT), export_format="GLB", use_selection=True,
                                  export_def_bones=True, export_animations=True,
                                  export_animation_mode="ACTIONS", export_force_sampling=True,
                                  export_skins=True, export_yup=True, export_image_format="AUTO",
                                  export_anim_single_armature=True)
    arm.animation_data.action = action
    bpy.ops.wm.save_mainfile(compress=True)


def rebuild() -> None:
    DONE.parent.mkdir(parents=True, exist_ok=True)
    DONE.unlink(missing_ok=True)
    open_source()

    def run() -> None:
        export()
        DONE.write_text("ok")

    bpy.app.timers.register(run, first_interval=0.5)


if __name__ == "__main__":
    rebuild()
