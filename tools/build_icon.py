import math
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "icon.png"
DONE = Path("/tmp/flowfire_icon_done")


def _material(name: str, color: tuple, rough: float, metal: float = 0.0) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    return mat


def _fabric() -> bpy.types.Material:
    mat = _material("icon_vest", (0.018, 0.02, 0.023), 0.92)
    tree = mat.node_tree
    bsdf = next(n for n in tree.nodes if n.type == "BSDF_PRINCIPLED")
    weave = tree.nodes.new("ShaderNodeMath")
    weave.operation = "MULTIPLY"
    for axis in ("X", "Z"):
        wave = tree.nodes.new("ShaderNodeTexWave")
        wave.bands_direction = axis
        wave.inputs["Scale"].default_value = 160.0
        wave.inputs["Distortion"].default_value = 1.5
        tree.links.new(wave.outputs["Fac"], weave.inputs[0 if axis == "X" else 1])
    grain = tree.nodes.new("ShaderNodeTexNoise")
    grain.inputs["Scale"].default_value = 900.0
    grain.inputs["Detail"].default_value = 6.0
    mix = tree.nodes.new("ShaderNodeMath")
    mix.operation = "ADD"
    tree.links.new(weave.outputs["Value"], mix.inputs[0])
    tree.links.new(grain.outputs["Fac"], mix.inputs[1])
    bump = tree.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.35
    bump.inputs["Distance"].default_value = 0.0008
    tree.links.new(mix.outputs["Value"], bump.inputs["Height"])
    tree.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def _emissive(name: str, color: tuple, strength: float) -> bpy.types.Material:
    mat = _material(name, color, 0.3)
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
    bsdf.inputs["Emission Strength"].default_value = strength
    return mat


def _box(name: str, size: tuple, location: tuple, bevel: float, mat: bpy.types.Material) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(location=location)
    ob = bpy.context.object
    ob.name = name
    ob.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(scale=True)
    mod = ob.modifiers.new("bevel", "BEVEL")
    mod.width = bevel
    mod.segments = 6
    ob.data.materials.append(mat)
    bpy.ops.object.shade_smooth()
    return ob


def _disc(name: str, radius: float, depth: float, location: tuple, mat: bpy.types.Material) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=radius, depth=depth, location=location,
                                        rotation=(math.pi / 2, 0, 0))
    ob = bpy.context.object
    ob.name = name
    ob.data.materials.append(mat)
    bpy.ops.object.shade_smooth()
    return ob


def build() -> None:
    scene = bpy.data.scenes.new("FlowFireIcon")
    bpy.context.window.scene = scene
    plastic = _material("icon_plastic", (0.012, 0.012, 0.013), 0.42)
    rubber = _material("icon_rubber", (0.008, 0.008, 0.009), 0.75)
    metal = _material("icon_ring", (0.25, 0.25, 0.26), 0.25, 1.0)
    glass = _material("icon_glass", (0.0, 0.0, 0.0), 0.02)
    _box("vest", (0.5, 0.02, 0.5), (0, 0.025, 0), 0.004, _fabric())
    _box("strap", (0.05, 0.012, 0.16), (0, 0.009, 0), 0.003, rubber)
    _box("body", (0.06, 0.026, 0.088), (0, -0.01, 0), 0.008, plastic)
    _box("plate", (0.046, 0.004, 0.05), (0, -0.0235, -0.012), 0.003, rubber)
    _disc("ring", 0.0135, 0.006, (0, -0.026, 0.017), metal)
    _disc("lens", 0.0105, 0.004, (0, -0.0285, 0.017), glass)
    _disc("led", 0.0026, 0.003, (0.019, -0.0245, 0.036), _emissive("icon_led", (1.0, 0.04, 0.02), 60.0))
    _disc("button", 0.0055, 0.004, (-0.015, -0.0245, -0.031), rubber)
    for ob in list(scene.collection.objects):
        ob.select_set(False)
    rim = bpy.data.lights.new("rim", "AREA")
    rim.energy = 1.4
    rim.size = 0.08
    rim.color = (0.62, 0.72, 1.0)
    rim_ob = bpy.data.objects.new("rim", rim)
    rim_ob.location = (-0.22, -0.12, 0.26)
    rim_ob.rotation_euler = (math.radians(55), 0, math.radians(-60))
    scene.collection.objects.link(rim_ob)
    glow = bpy.data.lights.new("led_glow", "POINT")
    glow.energy = 0.05
    glow.color = (1.0, 0.05, 0.02)
    glow.shadow_soft_size = 0.002
    glow_ob = bpy.data.objects.new("led_glow", glow)
    glow_ob.location = (0.019, -0.03, 0.036)
    scene.collection.objects.link(glow_ob)
    cam = bpy.data.cameras.new("icon_cam")
    cam.lens = 85
    cam.dof.use_dof = True
    cam.dof.aperture_fstop = 2.2
    cam_ob = bpy.data.objects.new("icon_cam", cam)
    cam_ob.location = (0.11, -0.25, 0.06)
    aim = bpy.data.objects.new("icon_aim", None)
    aim.location = (0.002, -0.02, 0.012)
    scene.collection.objects.link(aim)
    track = cam_ob.constraints.new("TRACK_TO")
    track.target = aim
    track.track_axis = "TRACK_NEGATIVE_Z"
    track.up_axis = "UP_Y"
    cam.dof.focus_distance = math.dist(cam_ob.location, (0, -0.028, 0.02))
    scene.collection.objects.link(cam_ob)
    scene.camera = cam_ob
    world = bpy.data.worlds.new("icon_world")
    world.use_nodes = True
    next(n for n in world.node_tree.nodes if n.type == "BACKGROUND").inputs["Strength"].default_value = 0.0
    scene.world = world
    try:
        scene.render.engine = "CYCLES"
    except TypeError:
        pass
    scene.cycles.samples = 256
    scene.cycles.use_denoising = False
    scene.render.resolution_x = scene.render.resolution_y = 512
    scene.view_settings.view_transform = "Filmic"
    looks = [i.identifier for i in scene.view_settings.bl_rna.properties["look"].enum_items]
    scene.view_settings.look = next((l for l in looks if "Very High Contrast" in l), "None")
    scene.view_settings.exposure = -0.6
    scene.use_nodes = True
    tree = scene.node_tree
    layers = next(n for n in tree.nodes if n.type == "R_LAYERS")
    composite = next(n for n in tree.nodes if n.type == "COMPOSITE")
    glare = tree.nodes.new("CompositorNodeGlare")
    glare.glare_type = "FOG_GLOW"
    glare.threshold = 0.8
    glare.size = 7
    tree.links.new(layers.outputs["Image"], glare.inputs["Image"])
    tree.links.new(glare.outputs["Image"], composite.inputs["Image"])
    scene.render.filepath = str(OUT)


def render() -> None:
    DONE.unlink(missing_ok=True)
    build()

    def run() -> None:
        bpy.ops.render.render(write_still=True)
        DONE.write_text("ok")

    bpy.app.timers.register(run, first_interval=0.5)


if __name__ == "__main__":
    render()
