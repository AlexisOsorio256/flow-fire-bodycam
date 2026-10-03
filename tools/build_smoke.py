#!/usr/bin/env python3
"""blender -b --python tools/build_smoke.py -- [--out ruta.png] [--frames carpeta]"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "assets" / "textures" / "muzzle_puff.png"
FPS = 60
FRAMES = 48
COLS = 8
ROWS = 6
CELL = 160

CENTER_Z = ((1, 0.030), (6, 0.085), (14, 0.150), (28, 0.225), (48, 0.290))
RADIUS = ((1, 0.020), (4, 0.050), (10, 0.082), (24, 0.120), (48, 0.165))
DENSITY = ((1, 0.0), (3, 1.0), (14, 0.85), (30, 0.4), (48, 0.0))
TRAIL = ((1, 0.0), (3, 1.0), (10, 0.7), (22, 0.0))


def reset() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scn = bpy.context.scene
    scn.render.fps = FPS
    scn.frame_start = 1
    scn.frame_end = FRAMES


class Graph:
    def __init__(self, tree: bpy.types.NodeTree) -> None:
        self.tree = tree

    def node(self, kind: str, **props):
        n = self.tree.nodes.new(kind)
        for k, v in props.items():
            setattr(n, k, v)
        return n

    def link(self, a, b, out=0, inp=0) -> None:
        self.tree.links.new(a.outputs[out], b.inputs[inp])

    def math(self, op: str, a=None, b=None, clamp=False):
        n = self.node("ShaderNodeMath", operation=op, use_clamp=clamp)
        for i, v in enumerate((a, b)):
            if v is None:
                continue
            if isinstance(v, (int, float)):
                n.inputs[i].default_value = v
            else:
                self.link(v, n, 0, i)
        return n

    def keyed(self, curve) -> bpy.types.Node:
        n = self.node("ShaderNodeValue")
        for frame, value in curve:
            n.outputs[0].default_value = value
            n.outputs[0].keyframe_insert("default_value", frame=frame)
        for fc in self.tree.animation_data.action.fcurves:
            for kp in fc.keyframe_points:
                kp.interpolation = "BEZIER"
        return n


def build_density(tree: bpy.types.NodeTree) -> bpy.types.Node:
    g = Graph(tree)
    pos = g.node("ShaderNodeNewGeometry")
    zc = g.keyed(CENTER_Z)
    radius = g.keyed(RADIUS)
    dens = g.keyed(DENSITY)
    trail = g.keyed(TRAIL)
    t = g.math("DIVIDE", g.keyed(((1, 0.0), (FRAMES, 1.0))), 1.0)

    warp_noise = g.node("ShaderNodeTexNoise", noise_dimensions="4D")
    warp_noise.inputs["Scale"].default_value = 9.0
    warp_noise.inputs["Detail"].default_value = 3.0
    g.link(pos, warp_noise, 0, 0)
    g.link(g.math("MULTIPLY", t, 1.4), warp_noise, 0, 1)
    warp = g.node("ShaderNodeVectorMath", operation="SUBTRACT")
    g.link(warp_noise, warp, 1, 0)
    warp.inputs[1].default_value = (0.5, 0.5, 0.5)
    warp_scaled = g.node("ShaderNodeVectorMath", operation="SCALE")
    g.link(warp, warp_scaled, 0, 0)
    g.link(g.math("MULTIPLY", radius, 1.1), warp_scaled, 0, 3)
    warped = g.node("ShaderNodeVectorMath", operation="ADD")
    g.link(pos, warped, 0, 0)
    g.link(warp_scaled, warped, 0, 1)
    wsep = g.node("ShaderNodeSeparateXYZ")
    g.link(warped, wsep, 0, 0)

    xx = g.math("MULTIPLY")
    yy = g.math("MULTIPLY")
    g.link(wsep, xx, 0, 0)
    g.link(wsep, xx, 0, 1)
    g.link(wsep, yy, 1, 0)
    g.link(wsep, yy, 1, 1)
    sum_xy = g.math("ADD")
    g.link(xx, sum_xy, 0, 0)
    g.link(yy, sum_xy, 0, 1)
    rxy = g.math("SQRT", sum_xy)

    dz = g.math("SUBTRACT")
    g.link(wsep, dz, 2, 0)
    g.link(zc, dz, 0, 1)
    dz_s = g.math("MULTIPLY", dz, 1.25)
    dz2 = g.math("MULTIPLY", dz_s, dz_s)
    rr2 = g.math("MULTIPLY", rxy, rxy)
    dist = g.math("SQRT", g.math("ADD", dz2, rr2))
    rel = g.math("DIVIDE")
    g.link(dist, rel, 0, 0)
    g.link(radius, rel, 0, 1)
    blob = g.node("ShaderNodeMapRange", clamp=True, interpolation_type="SMOOTHSTEP")
    g.link(rel, blob, 0, 0)
    blob.inputs[1].default_value = 0.35
    blob.inputs[2].default_value = 1.0
    blob.inputs[3].default_value = 1.0
    blob.inputs[4].default_value = 0.0

    w = g.math("DIVIDE")
    g.link(wsep, w, 2, 0)
    g.link(zc, w, 0, 1)
    along = g.math("SUBTRACT", 1.0, g.math("MULTIPLY", w, 1.05, True))
    below = g.node("ShaderNodeMapRange", clamp=True, interpolation_type="SMOOTHSTEP")
    g.link(wsep, below, 2, 0)
    below.inputs[1].default_value = 0.0
    below.inputs[2].default_value = 0.02
    below.inputs[3].default_value = 0.0
    below.inputs[4].default_value = 1.0
    tail_r = g.math("MULTIPLY", radius, 0.34)
    tail_rel = g.math("DIVIDE")
    g.link(rxy, tail_rel, 0, 0)
    g.link(tail_r, tail_rel, 0, 1)
    tail_f = g.node("ShaderNodeMapRange", clamp=True, interpolation_type="SMOOTHSTEP")
    g.link(tail_rel, tail_f, 0, 0)
    tail_f.inputs[1].default_value = 0.2
    tail_f.inputs[2].default_value = 1.0
    tail_f.inputs[3].default_value = 1.0
    tail_f.inputs[4].default_value = 0.0
    tail_a = g.math("MULTIPLY", g.math("MULTIPLY", tail_f, along), below)
    tail_t = g.math("MULTIPLY", tail_a, trail)
    shape = g.math("MAXIMUM", blob, g.math("MULTIPLY", tail_t, 0.7))

    detail = g.node("ShaderNodeTexNoise", noise_dimensions="4D")
    detail.inputs["Scale"].default_value = 26.0
    detail.inputs["Detail"].default_value = 5.0
    detail.inputs["Roughness"].default_value = 0.62
    g.link(warped, detail, 0, 0)
    g.link(g.math("MULTIPLY", t, 2.2), detail, 0, 1)
    mask = g.node("ShaderNodeMapRange", clamp=True, interpolation_type="SMOOTHSTEP")
    g.link(detail, mask, 0, 0)
    mask.inputs[1].default_value = 0.40
    mask.inputs[2].default_value = 0.66
    mask.inputs[3].default_value = 0.0
    mask.inputs[4].default_value = 1.0
    final = g.math("MULTIPLY", g.math("MULTIPLY", shape, mask), dens)
    return final


def build_scene() -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 0.0, 0.55))
    dom = bpy.context.active_object
    dom.name = "Domain"
    dom.scale = (0.55, 0.55, 1.1)
    mat = bpy.data.materials.new("Smoke")
    mat.use_nodes = True
    tree = mat.node_tree
    tree.animation_data_create()
    tree.animation_data.action = bpy.data.actions.new("SmokeNodes")
    for n in list(tree.nodes):
        tree.nodes.remove(n)
    out = tree.nodes.new("ShaderNodeOutputMaterial")
    vol = tree.nodes.new("ShaderNodeVolumePrincipled")
    vol.inputs["Color"].default_value = (0.84, 0.85, 0.86, 1.0)
    vol.inputs["Anisotropy"].default_value = 0.3
    final = build_density(tree)
    boost = tree.nodes.new("ShaderNodeMath")
    boost.operation = "MULTIPLY"
    boost.inputs[1].default_value = 28.0
    tree.links.new(final.outputs[0], boost.inputs[0])
    tree.links.new(boost.outputs[0], vol.inputs["Density"])
    tree.links.new(vol.outputs["Volume"], out.inputs["Volume"])
    dom.data.materials.append(mat)
    return dom


def build_camera_and_light() -> None:
    scn = bpy.context.scene
    world = bpy.data.worlds.new("W")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.9, 0.92, 0.95, 1.0)
    bg.inputs["Strength"].default_value = 1.0
    scn.world = world
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = 3.2
    sun_obj = bpy.data.objects.new("Sun", sun)
    sun_obj.rotation_euler = (math.radians(55), math.radians(15), math.radians(35))
    scn.collection.objects.link(sun_obj)
    cam = bpy.data.cameras.new("Cam")
    cam.type = "ORTHO"
    cam.ortho_scale = 0.5
    cam_obj = bpy.data.objects.new("Cam", cam)
    scn.collection.objects.link(cam_obj)
    target = Vector((0.0, 0.0, 0.15))
    cam_obj.location = target + Vector((0.5, -0.72, 0.34)).normalized() * 3.0
    cam_obj.rotation_euler = (target - cam_obj.location).to_track_quat("-Z", "Y").to_euler()
    scn.camera = cam_obj
    scn.render.engine = "CYCLES"
    scn.cycles.device = "CPU"
    scn.cycles.samples = 56
    scn.cycles.use_denoising = False
    scn.cycles.volume_step_rate = 0.5
    scn.cycles.volume_bounces = 2
    scn.render.film_transparent = True
    scn.render.resolution_x = CELL
    scn.render.resolution_y = CELL
    scn.render.image_settings.file_format = "PNG"
    scn.render.image_settings.color_mode = "RGBA"


def render_frames(frames_dir: Path, only=None) -> list[Path]:
    frames_dir.mkdir(parents=True, exist_ok=True)
    scn = bpy.context.scene
    paths = []
    for f in only or range(1, FRAMES + 1):
        scn.frame_set(f)
        path = frames_dir / ("puff_%03d.png" % f)
        scn.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        paths.append(path)
    return paths


def pack(paths: list[Path], out: Path) -> None:
    atlas = bpy.data.images.new("atlas", COLS * CELL, ROWS * CELL, alpha=True)
    pixels = [0.0] * (COLS * CELL * ROWS * CELL * 4)
    for i, path in enumerate(paths):
        img = bpy.data.images.load(str(path))
        src = list(img.pixels)
        col = i % COLS
        row = ROWS - 1 - i // COLS
        for y in range(CELL):
            dst = ((row * CELL + y) * COLS * CELL + col * CELL) * 4
            s = y * CELL * 4
            pixels[dst:dst + CELL * 4] = src[s:s + CELL * 4]
    atlas.pixels = pixels
    atlas.filepath_raw = str(out)
    atlas.file_format = "PNG"
    atlas.save()
    print("SUCCESS", out)


def main() -> None:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = Path(argv[argv.index("--out") + 1]) if "--out" in argv else OUT
    frames = Path(argv[argv.index("--frames") + 1]) if "--frames" in argv else Path("/tmp/flowfire_smoke_frames")
    only = [int(v) for v in argv[argv.index("--only") + 1].split(",")] if "--only" in argv else None
    reset()
    build_scene()
    build_camera_and_light()
    paths = render_frames(frames, only)
    if only is None:
        pack(paths, out)


if __name__ == "__main__":
    main()
