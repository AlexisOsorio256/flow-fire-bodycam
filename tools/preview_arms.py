import sys
from pathlib import Path

import bpy
import numpy as np

REPO = Path(__file__).resolve().parent.parent
CAPTURES = REPO / "captures"
VIEW = (1920, 1008)
CROP = (410, 248, 1100, 760)
SCALE = 0.4363
COLUMNS = 4


def render(clip: str, times: list[float], name: str) -> Path:
    scn = bpy.context.scene
    arm = bpy.data.objects["ArmsRig"]
    arm.animation_data.action = bpy.data.actions[clip]
    scn.camera = bpy.data.objects["GameCam"]
    scn.render.engine = "BLENDER_WORKBENCH"
    scn.display.shading.light = "STUDIO"
    scn.display.shading.color_type = "MATERIAL"
    scn.display.shading.show_shadows = True
    scn.render.resolution_x, scn.render.resolution_y = VIEW
    scn.render.resolution_percentage = int(SCALE * 100)
    x, y, w, h = CROP
    scn.render.use_border = True
    scn.render.use_crop_to_border = True
    scn.render.border_min_x, scn.render.border_max_x = x / VIEW[0], (x + w) / VIEW[0]
    scn.render.border_min_y, scn.render.border_max_y = 1.0 - (y + h) / VIEW[1], 1.0 - y / VIEW[1]
    CAPTURES.mkdir(exist_ok=True)
    tiles = []
    for i, t in enumerate(times):
        scn.frame_set(int(round(t * scn.render.fps)) + 1)
        scn.render.filepath = str(CAPTURES / ("_%s_%d.png" % (name, i)))
        bpy.ops.render.render(write_still=True)
        img = bpy.data.images.load(scn.render.filepath)
        px = np.array(img.pixels[:], dtype=np.float32).reshape(img.size[1], img.size[0], 4)
        bpy.data.images.remove(img)
        Path(scn.render.filepath).unlink()
        tiles.append(px)
    while len(tiles) % COLUMNS:
        tiles.append(np.zeros_like(tiles[0]))
    rows = [np.concatenate(tiles[r:r + COLUMNS], axis=1) for r in range(0, len(tiles), COLUMNS)]
    sheet = np.concatenate(rows[::-1], axis=0)
    out = bpy.data.images.new(name, sheet.shape[1], sheet.shape[0], alpha=True)
    out.pixels.foreach_set(sheet.ravel())
    out.filepath_raw = str(CAPTURES / ("%s_blend.png" % name))
    out.file_format = "PNG"
    out.save()
    bpy.data.images.remove(out)
    arm.animation_data.action = bpy.data.actions["Idle"]
    return CAPTURES / ("%s_blend.png" % name)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    print(render(argv[0], [float(t) for t in argv[2:]], argv[1]))
