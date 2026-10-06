import math
import re
from pathlib import Path

import bpy
import numpy as np
from mathutils import Quaternion, Vector

ROOT = Path(__file__).resolve().parent.parent
CAPTURES = ROOT / "captures"
GAME_VIEW = (1920, 1008)
GAME_CROP = (410, 248, 1100, 760)
PLAN_COLORS = {"wall": (0.55, 0.27, 0.07), "door": (0.0, 0.63, 0.0), "window": (0.0, 0.0, 1.0),
               "prop": (1.0, 0.65, 0.0), "container": (0.27, 0.27, 0.63), "post": (1.0, 0.0, 1.0)}


def _workbench(scn, size, percent=100, color="MATERIAL") -> None:
    scn.render.engine = "BLENDER_WORKBENCH"
    scn.display.shading.light = "STUDIO"
    scn.display.shading.color_type = color
    scn.render.resolution_x, scn.render.resolution_y = size
    scn.render.resolution_percentage = percent
    scn.render.use_border = False


def _shoot(scn) -> np.ndarray:
    path = CAPTURES / "_blender_view.png"
    scn.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(str(path))
    px = np.array(img.pixels[:], dtype=np.float32).reshape(img.size[1], img.size[0], 4)
    bpy.data.images.remove(img)
    path.unlink()
    return px


def _save_sheet(tiles: list, columns: int, name: str) -> Path:
    while len(tiles) % columns:
        tiles.append(np.zeros_like(tiles[0]))
    for t in tiles:
        t[:, :2, :3] = 1.0
    rows = [np.concatenate(tiles[r:r + columns], axis=1) for r in range(0, len(tiles), columns)]
    sheet = np.concatenate(rows[::-1], axis=0)
    out = bpy.data.images.new(name, sheet.shape[1], sheet.shape[0], alpha=True)
    out.pixels.foreach_set(sheet.ravel())
    path = CAPTURES / ("%s.png" % name)
    out.filepath_raw = str(path)
    out.file_format = "PNG"
    out.save()
    bpy.data.images.remove(out)
    return path


def _rig() -> bpy.types.Object:
    return next(o for o in bpy.data.objects if o.type == "ARMATURE")


def _frame(scn, seconds: float) -> None:
    scn.frame_set(int(round(seconds * scn.render.fps)) + 1)
    bpy.context.view_layer.update()


def _game_const(script: str, name: str) -> float:
    source = (ROOT / "scripts" / script).read_text()
    return float(re.search(r"const %s := ([\d.]+)" % name, source).group(1))


def _through_lens(px: np.ndarray, fov: float) -> np.ndarray:
    circle, barrel = _game_const("HUD.gd", "LENS_CIRCLE"), _game_const("HUD.gd", "LENS_BARREL")
    h, w = px.shape[:2]
    aspect = w / h
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    p = np.stack([((xs + 0.5) / w - 0.5) * aspect * 2.0, ((ys + 0.5) / h - 0.5) * 2.0], -1)
    r = np.maximum(np.linalg.norm(p, axis=-1), 1e-5)
    tv = math.tan(math.radians(fov) * 0.5)
    rc = math.hypot(aspect, 1.0)
    r_fish = np.tan(np.minimum(math.atan(rc * tv) * r / circle, 1.5)) / tv
    q = p * ((r * rc / circle * (1.0 - barrel) + r_fish * barrel) / r)[..., None]
    u = np.clip((q[..., 0] / aspect * 0.5 + 0.5) * w - 0.5, 0, w - 1.001)
    v = np.clip((q[..., 1] * 0.5 + 0.5) * h - 0.5, 0, h - 1.001)
    x0, y0 = u.astype(int), v.astype(int)
    fx, fy = (u - x0)[..., None], (v - y0)[..., None]
    top = px[y0, x0] * (1 - fx) + px[y0, x0 + 1] * fx
    bottom = px[y0 + 1, x0] * (1 - fx) + px[y0 + 1, x0 + 1] * fx
    return (top * (1 - fy) + bottom * fy).astype(np.float32)


def _show(part: str) -> list:
    hidden = []
    for ob in bpy.data.objects:
        if ob.type != "MESH" or part == "all":
            continue
        if (ob.name == "Arms_Mesh") != (part == "arms") and not ob.hide_render:
            ob.hide_render = True
            hidden.append(ob)
    return hidden


def game(clip: str, times: list, name: str, crop: bool = True, columns: int = 4, show: str = "all",
         color: str = "MATERIAL") -> Path:
    scn = bpy.context.scene
    rig = _rig()
    keep = rig.animation_data.action
    rig.animation_data.action = bpy.data.actions[clip]
    keep_cam = scn.camera
    cam = bpy.data.objects["GameCam"]
    scn.camera = cam
    fov = _game_const("BodyCam.gd", "FOV_AIM" if clip == "Aim" else "FOV")
    cam.data.sensor_fit = "VERTICAL"
    cam.data.lens = cam.data.sensor_height * 0.5 / math.tan(math.radians(fov) * 0.5)
    hidden = _show(show)
    _workbench(scn, GAME_VIEW, 50, color)
    x, y, w, h = (v // 2 for v in GAME_CROP)
    rows = GAME_VIEW[1] // 2
    tiles = []
    for t in times:
        _frame(scn, t)
        px = _through_lens(_shoot(scn), fov)
        tiles.append(px[rows - y - h:rows - y, x:x + w].copy() if crop else px)
    for ob in hidden:
        ob.hide_render = False
    cam.data.lens = cam.data.sensor_height * 0.5 / math.tan(math.radians(_game_const("BodyCam.gd", "FOV")) * 0.5)
    scn.camera = keep_cam
    rig.animation_data.action = keep
    return _save_sheet(tiles, min(columns, len(tiles)), name)


def closeup(clip: str, seconds: float, bone: str, eyes: list, name: str, lens: float = 40.0,
            from_game_cam: bool = False) -> Path:
    scn = bpy.context.scene
    rig = _rig()
    keep = rig.animation_data.action
    rig.animation_data.action = bpy.data.actions[clip]
    _frame(scn, seconds)
    data = bpy.data.cameras.new("_closeup")
    data.lens = lens
    cam = bpy.data.objects.new("_closeup", data)
    scn.collection.objects.link(cam)
    keep_cam = scn.camera
    scn.camera = cam
    _workbench(scn, (500, 400))
    target = rig.matrix_world @ rig.pose.bones[bone].head
    base = bpy.data.objects["GameCam"].matrix_world if from_game_cam else None
    tiles = []
    for eye in eyes:
        pos = base @ Vector(eye) if base is not None else target + Vector(eye)
        cam.location = pos
        cam.rotation_euler = (target - pos).to_track_quat("-Z", "Y").to_euler()
        tiles.append(_shoot(scn))
    scn.camera = keep_cam
    bpy.data.objects.remove(cam)
    bpy.data.cameras.remove(data)
    rig.animation_data.action = keep
    return _save_sheet(tiles, len(eyes), name)


def shift_keys(action: str, bone: str, camera_delta: tuple, fade: tuple | None = None) -> int:
    scn = bpy.context.scene
    rig = _rig()
    act = bpy.data.actions[action]
    keep = rig.animation_data.action
    rig.animation_data.action = act
    scn.frame_set(int(act.frame_range[0]))
    bpy.context.view_layer.update()
    pb = rig.pose.bones[bone]
    if pb.parent is None:
        space = pb.bone.matrix_local.to_3x3()
    else:
        space = (pb.parent.matrix @ pb.parent.bone.matrix_local.inverted() @ pb.bone.matrix_local).to_3x3()
    world = bpy.data.objects["GameCam"].matrix_world.to_3x3() @ Vector(camera_delta)
    local = space.inverted() @ (rig.matrix_world.to_3x3().inverted() @ world)
    f0, f1 = act.frame_range
    fps = scn.render.fps
    moved = 0
    for fc in act.fcurves:
        if fc.data_path != 'pose.bones["%s"].location' % bone:
            continue
        for k in fc.keyframe_points:
            w = 1.0
            if fade is not None:
                t, total = (k.co.x - f0) / fps, (f1 - f0) / fps
                x = max(0.0, min(1.0, t / fade[0], (total - t) / fade[1]))
                w = x * x * (3.0 - 2.0 * x)
            d = local[fc.array_index] * w
            k.co.y += d
            k.handle_left.y += d
            k.handle_right.y += d
            moved += 1
        fc.update()
    rig.animation_data.action = keep
    return moved


def turn_keys(action: str, bones: list, axis: tuple, degrees: list) -> int:
    act = bpy.data.actions[action]
    turned = 0
    for bone, deg in zip(bones, degrees):
        path = 'pose.bones["%s"].rotation_quaternion' % bone
        curves = sorted((fc for fc in act.fcurves if fc.data_path == path), key=lambda c: c.array_index)
        if len(curves) != 4:
            continue
        delta = Quaternion(axis, math.radians(deg))
        for i in range(len(curves[0].keyframe_points)):
            q = Quaternion([c.keyframe_points[i].co.y for c in curves]) @ delta
            for c, v in zip(curves, q):
                k = c.keyframe_points[i]
                d = v - k.co.y
                k.co.y = v
                k.handle_left.y += d
                k.handle_right.y += d
            turned += 1
        for c in curves:
            c.update()
    return turned


def plan(name: str = "map_plan", meters: float = 76.0, pixels: int = 900) -> Path:
    scale = pixels / meters
    img = np.ones((pixels, pixels, 4), dtype=np.float32)

    def box(lo: Vector, hi: Vector, color: tuple) -> None:
        x0, x1 = (int((v + meters / 2) * scale) for v in (lo.x, hi.x))
        y0, y1 = (int((v + meters / 2) * scale) for v in (lo.y, hi.y))
        img[max(0, y0):max(y0 + 2, y1), max(0, x0):max(x0 + 2, x1), :3] = color

    for ob in bpy.data.objects:
        if ob.type == "EMPTY" and ob.name.startswith("post_"):
            p = ob.matrix_world.translation
            box(p - Vector((0.3, 0.3, 0)), p + Vector((0.3, 0.3, 0)), PLAN_COLORS["post"])
            continue
        kind = ob.name.split("_")[0]
        if ob.type != "MESH" or kind not in PLAN_COLORS or ob.name.endswith("convcolonly"):
            continue
        pts = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
        lo = Vector([min(p[i] for p in pts) for i in range(3)])
        hi = Vector([max(p[i] for p in pts) for i in range(3)])
        box(lo, hi, PLAN_COLORS[kind])
    return _save_sheet([img], 1, name)
