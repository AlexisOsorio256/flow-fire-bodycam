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
FRAMES = 32
COLS = 8
ROWS = 4
CELL = 160

RES = 128
CACHE = Path("/tmp/flowfire_smoke_cache")


def reset() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scn = bpy.context.scene
    scn.render.fps = FPS
    scn.frame_start = 1
    scn.frame_end = FRAMES


def build_scene() -> bpy.types.Object:
    CACHE.mkdir(parents=True, exist_ok=True)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 0.0, 0.5))
    dom = bpy.context.active_object
    dom.name = "Domain"
    dom.scale = (0.5, 0.5, 1.0)
    bpy.ops.object.modifier_add(type="FLUID")
    dom.modifiers["Fluid"].fluid_type = "DOMAIN"
    ds = dom.modifiers["Fluid"].domain_settings
    ds.domain_type = "GAS"
    ds.resolution_max = RES
    ds.cache_type = "REPLAY"
    ds.cache_directory = str(CACHE)
    ds.cache_frame_start = 1
    ds.cache_frame_end = FRAMES
    ds.use_dissolve_smoke = True
    ds.dissolve_speed = 48
    ds.use_noise = False
    ds.vorticity = 0.9
    ds.beta = 0.25
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.022, location=(0.0, 0.0, 0.04))
    flow = bpy.context.active_object
    flow.name = "Muzzle"
    flow.hide_render = True
    bpy.ops.object.modifier_add(type="FLUID")
    flow.modifiers["Fluid"].fluid_type = "FLOW"
    fs = flow.modifiers["Fluid"].flow_settings
    fs.flow_type = "SMOKE"
    fs.flow_behavior = "GEOMETRY"
    fs.use_initial_velocity = True
    fs.velocity_normal = 1.8
    fs.velocity_coord = (0.0, 0.0, 1.6)
    fs.density = 1.0
    fs.subframes = 2
    mat = bpy.data.materials.new("Smoke")
    mat.use_nodes = True
    tree = mat.node_tree
    for n in list(tree.nodes):
        tree.nodes.remove(n)
    out = tree.nodes.new("ShaderNodeOutputMaterial")
    vol = tree.nodes.new("ShaderNodeVolumePrincipled")
    vol.inputs["Color"].default_value = (0.84, 0.85, 0.86, 1.0)
    vol.inputs["Density"].default_value = 140.0
    vol.inputs["Anisotropy"].default_value = 0.3
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
    cam.ortho_scale = 0.7
    cam_obj = bpy.data.objects.new("Cam", cam)
    scn.collection.objects.link(cam_obj)
    target = Vector((0.0, 0.0, 0.22))
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
    wanted = set(only) if only else set(range(1, FRAMES + 1))
    paths = []
    for f in range(1, max(wanted) + 1):
        scn.frame_set(f)
    for f in sorted(wanted):
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
    dom = build_scene()
    build_camera_and_light()
    paths = render_frames(frames, only)
    if only is None:
        pack(paths, out)


if __name__ == "__main__":
    main()
