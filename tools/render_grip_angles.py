#!/usr/bin/env python3
"""Render the 7 acceptance angles of the Glock and grip in Blender."""

import math
from pathlib import Path
import bpy
from mathutils import Vector, Euler

OUT_DIR = Path("captures/grip_acceptance")
OUT_DIR.mkdir(parents=True, exist_ok=True)

# 1. Reset
bpy.ops.wm.read_factory_settings(use_empty=True)

# 2. Import Glock
bpy.ops.import_scene.gltf(filepath="assets/models/g19_pistol.glb")

# 3. Import fps_arms.glb
bpy.ops.import_scene.gltf(filepath="assets/models/fps_arms.glb")

# Setup render settings (Cycles or Eevee, 1280x720 is fast and high quality)
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 1280
scene.render.resolution_y = 720
scene.render.film_transparent = False

# Setup background world color
world = bpy.data.worlds.new("StudioWorld")
scene.world = world
world.use_nodes = True
bg = world.node_tree.nodes["Background"]
bg.inputs["Color"].default_value = (0.25, 0.25, 0.28, 1.0)
bg.inputs["Strength"].default_value = 1.0

# Setup 3-point studio lighting
def add_light(name, light_type, energy, location):
    light_data = bpy.data.lights.new(name=name, type=light_type)
    light_data.energy = energy
    light_obj = bpy.data.objects.new(name=name, object_data=light_data)
    scene.collection.objects.link(light_obj)
    light_obj.location = location
    return light_obj

add_light("KeyLight", "POINT", 80.0, Vector((0.3, -0.4, 0.5)))
add_light("FillLight", "POINT", 40.0, Vector((-0.3, -0.4, 0.3)))
add_light("RimLight", "POINT", 60.0, Vector((0.0, 0.5, 0.4)))
add_light("BottomLight", "POINT", 25.0, Vector((0.0, -0.2, -0.4)))

# Setup camera
cam_data = bpy.data.cameras.new("RenderCam")
cam_data.lens = 50.0  # 50mm portrait lens for clear detail without wide distortion
cam_obj = bpy.data.objects.new("RenderCam", cam_data)
scene.collection.objects.link(cam_obj)
scene.camera = cam_obj

# Target center of pistol grip
TARGET = Vector((-0.02, -0.06, -0.02))

def aim_cam_at(pos: Vector, target: Vector):
    cam_obj.location = pos
    direction = target - pos
    rot_quat = direction.to_track_quat("-Z", "Y")
    cam_obj.rotation_euler = rot_quat.to_euler()

ANGLES = {
    "camera_fps": Vector((-0.02, -0.62, 0.07)),
    "left_side": Vector((-0.38, -0.06, -0.02)),
    "right_side": Vector((0.34, -0.06, -0.02)),
    "rear": Vector((-0.02, -0.58, -0.02)),
    "top": Vector((-0.02, -0.06, 0.34)),
    "three_quarter_left": Vector((-0.28, -0.28, 0.15)),
    "three_quarter_right": Vector((0.24, -0.28, 0.15)),
}

for name, cam_pos in ANGLES.items():
    aim_cam_at(cam_pos, TARGET)
    out_file = OUT_DIR / f"{name}.png"
    scene.render.filepath = str(out_file)
    bpy.ops.render.render(write_still=True)
    print(f"Rendered {name} -> {out_file}")

print("ALL 7 GRIP ACCEPTANCE ANGLES RENDERED SUCCESSFULLY")
