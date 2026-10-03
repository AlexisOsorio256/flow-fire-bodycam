#!/usr/bin/env python3
"""blender -b --python tools/build_flash.py -- [--out ruta.png] [--preview carpeta]"""

from __future__ import annotations

import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Euler, Matrix

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "assets" / "textures" / "muzzle_flash.png"
VARIANTS = 4
CELL = 160


def new_scene() -> bpy.types.Scene:
    scn = bpy.data.scenes.new("FlashBake")
    if bpy.context.window is not None:
        bpy.context.window.scene = scn
    scn.render.engine = "CYCLES"
    scn.cycles.device = "CPU"
    scn.cycles.samples = 48
    scn.cycles.use_denoising = False
    scn.cycles.max_bounces = 0
    scn.render.film_transparent = True
    scn.render.resolution_x = CELL
    scn.render.resolution_y = CELL
    scn.render.image_settings.file_format = "PNG"
    scn.render.image_settings.color_mode = "RGBA"
    scn.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("FlashWorld")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.0
    scn.world = world
    return scn


def flame_material() -> bpy.types.Material:
    mat = bpy.data.materials.new("Flame")
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    emit = nt.nodes.new("ShaderNodeEmission")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    length = nt.nodes.new("ShaderNodeVectorMath")
    length.operation = "LENGTH"
    mapr = nt.nodes.new("ShaderNodeMapRange")
    mapr.inputs[1].default_value = 0.0
    mapr.inputs[2].default_value = 0.22
    mapr.inputs[3].default_value = 0.0
    mapr.inputs[4].default_value = 1.0
    mapr.clamp = True
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = (1.0, 0.98, 0.9, 1.0)
    ramp.color_ramp.elements[1].position = 1.0
    ramp.color_ramp.elements[1].color = (1.0, 0.42, 0.08, 1.0)
    mid = ramp.color_ramp.elements.new(0.45)
    mid.color = (1.0, 0.78, 0.35, 1.0)
    emit.inputs["Strength"].default_value = 2.4
    nt.links.new(geo.outputs["Position"], length.inputs[0])
    nt.links.new(length.outputs["Value"], mapr.inputs[0])
    nt.links.new(mapr.outputs[0], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], emit.inputs["Color"])
    fade = nt.nodes.new("ShaderNodeMapRange")
    fade.clamp = True
    fade.interpolation_type = "SMOOTHSTEP"
    fade.inputs[1].default_value = 0.03
    fade.inputs[2].default_value = 0.25
    fade.inputs[3].default_value = 1.0
    fade.inputs[4].default_value = 0.0
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 38.0
    noise.inputs["Detail"].default_value = 4.0
    nt.links.new(geo.outputs["Position"], noise.inputs["Vector"])
    ripple = nt.nodes.new("ShaderNodeMath")
    ripple.operation = "MULTIPLY"
    nt.links.new(fade.outputs[0], ripple.inputs[0])
    gain = nt.nodes.new("ShaderNodeMapRange")
    gain.clamp = True
    gain.inputs[1].default_value = 0.25
    gain.inputs[2].default_value = 0.75
    gain.inputs[3].default_value = 0.35
    gain.inputs[4].default_value = 1.15
    nt.links.new(noise.outputs["Fac"], gain.inputs[0])
    nt.links.new(gain.outputs[0], ripple.inputs[1])
    clear = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(length.outputs["Value"], fade.inputs[0])
    nt.links.new(ripple.outputs[0], mix.inputs[0])
    nt.links.new(clear.outputs[0], mix.inputs[1])
    nt.links.new(emit.outputs["Emission"], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    return mat


def glow_material() -> bpy.types.Material:
    mat = bpy.data.materials.new("Glow")
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    mix = nt.nodes.new("ShaderNodeMixShader")
    emit = nt.nodes.new("ShaderNodeEmission")
    clear = nt.nodes.new("ShaderNodeBsdfTransparent")
    tex = nt.nodes.new("ShaderNodeTexCoord")
    fall = nt.nodes.new("ShaderNodeMapRange")
    fall.clamp = True
    fall.interpolation_type = "SMOOTHSTEP"
    fall.inputs[1].default_value = 0.0
    fall.inputs[2].default_value = 0.5
    fall.inputs[3].default_value = 1.0
    fall.inputs[4].default_value = 0.0
    shape = nt.nodes.new("ShaderNodeMath")
    shape.operation = "POWER"
    shape.inputs[1].default_value = 2.0
    emit.inputs["Color"].default_value = (1.0, 0.55, 0.14, 1.0)
    emit.inputs["Strength"].default_value = 1.4
    sub = nt.nodes.new("ShaderNodeVectorMath")
    sub.operation = "DISTANCE"
    nt.links.new(tex.outputs["Generated"], sub.inputs[0])
    sub.inputs[1].default_value = (0.5, 0.5, 0.5)
    nt.links.new(sub.outputs["Value"], fall.inputs[0])
    nt.links.new(fall.outputs[0], shape.inputs[0])
    nt.links.new(shape.outputs[0], mix.inputs[0])
    nt.links.new(clear.outputs[0], mix.inputs[1])
    nt.links.new(emit.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    return mat


def spike(scn, mat, angle: float, length: float, width: float, tilt: float) -> None:
    bpy.ops.mesh.primitive_cone_add(vertices=14, radius1=width, radius2=0.0, depth=length,
                                    location=(0, 0, 0))
    obj = bpy.context.active_object
    obj.data.transform(Matrix.Translation((0, 0, length * 0.5)))
    obj.rotation_euler = Euler((math.radians(tilt), angle, 0.0), "XYZ")
    obj.data.materials.append(mat)
    for poly in obj.data.polygons:
        poly.use_smooth = True


def build_variant(scn, mat, seed: int) -> list[bpy.types.Object]:
    rng = random.Random(seed)
    before = set(scn.objects)
    count = rng.randint(6, 8)
    for i in range(count):
        base = math.tau * i / count + rng.uniform(-0.25, 0.25)
        spike(scn, mat, base, rng.uniform(0.14, 0.30), rng.uniform(0.022, 0.05), rng.uniform(-14.0, 14.0))
    for _ in range(3):
        spike(scn, mat, rng.uniform(0.0, math.tau), rng.uniform(0.07, 0.12), rng.uniform(0.02, 0.035), 0.0)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=rng.uniform(0.032, 0.045))
    core = bpy.context.active_object
    core.scale = (1.0, 0.45, 1.0)
    core.data.materials.append(mat)
    bpy.ops.mesh.primitive_plane_add(size=0.5, rotation=(math.radians(90.0), 0.0, 0.0), location=(0.0, 0.05, 0.0))
    halo = bpy.context.active_object
    halo.data.materials.append(glow_material())
    return [o for o in scn.objects if o not in before]


def camera(scn) -> None:
    cam = bpy.data.cameras.new("FlashCam")
    cam.type = "ORTHO"
    cam.ortho_scale = 0.72
    obj = bpy.data.objects.new("FlashCam", cam)
    scn.collection.objects.link(obj)
    obj.location = (0.0, -2.0, 0.0)
    obj.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    scn.camera = obj


def bake(out: Path, preview: Path | None) -> None:
    scn = new_scene()
    mat = flame_material()
    camera(scn)
    atlas = bpy.data.images.new("atlas", VARIANTS * CELL, CELL, alpha=True)
    pixels = [0.0] * (VARIANTS * CELL * CELL * 4)
    for v in range(VARIANTS):
        objs = build_variant(scn, mat, 101 + v * 17)
        path = (preview or Path("/tmp")) / ("flash_%d.png" % v)
        path.parent.mkdir(parents=True, exist_ok=True)
        scn.render.filepath = str(path)
        bpy.ops.render.render(write_still=True, scene=scn.name)
        img = bpy.data.images.load(str(path), check_existing=False)
        src = list(img.pixels)
        for y in range(CELL):
            dst = (y * VARIANTS * CELL + v * CELL) * 4
            pixels[dst:dst + CELL * 4] = src[y * CELL * 4:(y + 1) * CELL * 4]
        bpy.data.images.remove(img)
        for o in objs:
            bpy.data.objects.remove(o, do_unlink=True)
    atlas.pixels = pixels
    atlas.filepath_raw = str(out)
    atlas.file_format = "PNG"
    atlas.save()
    print("SUCCESS", out)


def main() -> None:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = Path(argv[argv.index("--out") + 1]) if "--out" in argv else OUT
    preview = Path(argv[argv.index("--preview") + 1]) if "--preview" in argv else None
    bake(out, preview)


if __name__ == "__main__":
    main()
