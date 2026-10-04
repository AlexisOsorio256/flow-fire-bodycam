#!/usr/bin/env python3

from __future__ import annotations

import math
import re
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "assets" / "models" / "enemy.glb"
RIG_SRC = REPO / "downloads" / "models" / "enemy_rig.glb"
BODY_SRC = REPO / "downloads" / "models" / "swat_animated.glb"
GUN_SRC = REPO / "assets" / "models" / "g19_pistol.glb"
GUN_ALBEDO = REPO / "assets" / "models" / "g19_pistol_Image_3.png"
GUN_GRIP = Vector((0.0, -0.045, -0.015))
CLIPS = ("Idle", "Walk", "Aim", "Hit", "Death", "Ready", "Sneak", "Run", "CrouchAim")
LODS = (("Enemy_Mesh", 0.7), ("Enemy_Mesh_LOD1", 0.22), ("Enemy_Mesh_LOD2", 0.08))
BIND_POSE = ("root", "Hips")
UNIFORM_GREY = 0.42

BODY = {"Hips": "Hips", "Spine": "Spine", "Spine1": "Chest", "Spine2": "Chest.001", "Neck": "Neck",
        "Neck1": "Neck1", "Head": "Head", "HeadTop_End": "HeadTop", "Jaw": "Jaw",
        "LeftEye": "Eye_L", "RightEye": "Eye_R", "GLTF_created_0_rootJoint": "root"}
LIMBS = {"Shoulder": "Shoulder", "Arm": "UpperArm", "ForeArm": "ForeArm", "Hand": "Hand",
         "UpLeg": "Thigh", "Leg": "Shin", "Foot": "Foot", "ToeBase": "Toe", "Toe_End": "ToeTip"}
FINGERS = {"Index": "f_index", "Middle": "f_middle", "Ring": "f_ring", "Pinky": "f_pinky", "Thumb": "thumb"}


def _reset() -> None:
    for coll in (bpy.data.objects, bpy.data.meshes, bpy.data.armatures, bpy.data.actions,
                 bpy.data.cameras, bpy.data.lights, bpy.data.materials, bpy.data.images):
        for item in list(coll):
            coll.remove(item)


def contract_name(mixamo: str) -> str:
    base = re.sub(r"_\d+$", "", mixamo.replace("mixamorig:", ""))
    if base in BODY:
        return BODY[base]
    m = re.match(r"(Left|Right)Hand(Index|Middle|Ring|Pinky|Thumb)(\d)$", base)
    if m:
        return "%s%s_%s" % (m.group(2), m.group(3), "L" if m.group(1) == "Left" else "R")
    m = re.match(r"(Left|Right)(.+)$", base)
    if m and m.group(2) in LIMBS:
        return "%s_%s" % (LIMBS[m.group(2)], "L" if m.group(1) == "Left" else "R")
    return base


def source_name(target: str) -> str | None:
    m = re.match(r"(Index|Middle|Ring|Pinky|Thumb)(\d)_(L|R)$", target)
    if m:
        n = int(m.group(2))
        return None if n > 3 else "DEF-%s.0%d.%s" % (FINGERS[m.group(1)], n, m.group(3))
    if target in ("Neck1", "HeadTop", "Jaw", "Eye_L", "Eye_R", "root", "ToeTip_L", "ToeTip_R"):
        return None
    return target


def import_glb(path: Path) -> list:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    return [o for o in bpy.data.objects if o not in before]


def load_source():
    objs = import_glb(RIG_SRC)
    arm = next(o for o in objs if o.type == "ARMATURE")
    for o in objs:
        if o is not arm:
            bpy.data.objects.remove(o, do_unlink=True)
    arm.name = "SourceRig"
    if arm.animation_data:
        arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    return arm


def load_body():
    before_actions = set(bpy.data.actions)
    objs = import_glb(BODY_SRC)
    for a in list(bpy.data.actions):
        if a not in before_actions:
            bpy.data.actions.remove(a)
    arm = next(o for o in objs if o.type == "ARMATURE")
    meshes = [o for o in objs if o.type == "MESH" and o.parent is arm]
    if arm.animation_data:
        arm.animation_data.action = None
    for pb in arm.pose.bones:
        if contract_name(pb.name) not in BIND_POSE:
            pb.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    for o in meshes:
        with bpy.context.temp_override(object=o, active_object=o):
            for m in list(o.modifiers):
                if m.type == "ARMATURE":
                    bpy.ops.object.modifier_apply(modifier=m.name)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.armature_apply(selected=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    for o in meshes:
        world = o.matrix_world.copy()
        o.parent = None
        o.data.transform(world)
        o.matrix_world = Matrix.Identity(4)
    world = arm.matrix_world.copy()
    arm.parent = None
    arm.data.transform(world)
    arm.matrix_world = Matrix.Identity(4)
    for o in objs:
        if o.name in bpy.data.objects and o is not arm and o not in meshes:
            bpy.data.objects.remove(o, do_unlink=True)
    return arm, meshes


def rename(arm, meshes) -> None:
    names = {b.name: contract_name(b.name) for b in arm.data.bones}
    for old, new in names.items():
        arm.data.bones[old].name = new
    for o in meshes:
        for g in o.vertex_groups:
            if g.name in names:
                g.name = names[g.name]


def bone_world(arm, name: str, tail=False) -> Vector:
    b = arm.data.bones[name]
    return arm.matrix_world @ (b.tail_local if tail else b.head_local)


def fit_to(src, arm, meshes) -> None:
    up = (bone_world(arm, "Head") - bone_world(arm, "Hips")).normalized()
    fix = up.rotation_difference(Vector((0.0, 0.0, 1.0))).to_matrix().to_4x4()
    arm.data.transform(fix)
    for o in meshes:
        o.data.transform(fix)
    left = bone_world(arm, "Hand_L") - bone_world(arm, "Hand_R")
    toe = bone_world(arm, "Toe_L") - bone_world(arm, "Foot_L")
    fwd = Vector((left.y, -left.x, 0.0))
    if fwd.dot(Vector((toe.x, toe.y, 0.0))) < 0.0:
        fwd = -fwd
    yaw = math.atan2(-1.0, 0.0) - math.atan2(fwd.y, fwd.x)
    lowest = min((o.matrix_world @ v.co).z for o in meshes for v in o.data.vertices)
    tall = bone_world(arm, "Head").z - lowest
    want = bone_world(src, "Head").z
    scale = want / tall
    spin = Matrix.Rotation(yaw, 4, "Z") @ Matrix.Scale(scale, 4)
    arm.data.transform(spin)
    for o in meshes:
        o.data.transform(spin)
    hips, src_hips = bone_world(arm, "Hips"), bone_world(src, "Hips")
    lowest = min((o.matrix_world @ v.co).z for o in meshes for v in o.data.vertices)
    shift = Matrix.Translation(Vector((src_hips.x - hips.x, src_hips.y - hips.y, -lowest)))
    arm.data.transform(shift)
    for o in meshes:
        o.data.transform(shift)
    print("build_soldier: giro %.1f deg, escala %.4f, cabeza a %.3f m"
          % (math.degrees(yaw), scale, bone_world(arm, "Head").z))


def bind(arm, meshes):
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    body = bpy.context.view_layer.objects.active
    body.name = "Enemy_Mesh"
    body.data.name = "Enemy_Mesh"
    body.parent = arm
    mod = body.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    arm.name = "EnemyRig"
    arm.data.name = "EnemyRig"
    return body


def charcoal_uniform(body) -> None:
    for mat in body.data.materials:
        nt = mat.node_tree
        bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
        tex = next((n for n in nt.nodes if n.type == "TEX_IMAGE" and n.image and "baseColor" in n.image.name), None)
        head = "head" in mat.name.lower()
        bsdf.inputs["Roughness"].default_value = 0.62 if head else 0.82
        bsdf.inputs["Metallic"].default_value = 0.0
        if tex is None or head or tex.image.get("charcoal"):
            continue
        img = tex.image
        w, h = img.size
        px = np.empty(w * h * 4, dtype=np.float32)
        img.pixels.foreach_get(px)
        px = px.reshape(-1, 4)
        r, g, b = px[:, 0], px[:, 1], px[:, 2]
        lum = 0.30 * r + 0.59 * g + 0.11 * b
        blue = np.clip((b - np.maximum(r, g)) / 0.04, 0.0, 1.0)
        grey = lum * (1.0 - (1.0 - UNIFORM_GREY) * blue)
        px[:, :3] = grey[:, None] * np.array([1.0, 0.99, 0.97], dtype=np.float32)
        img.pixels.foreach_set(px.reshape(-1))
        img["charcoal"] = True
        img.pack()


def pose_world(arm, name: str) -> Matrix:
    return arm.matrix_world @ arm.pose.bones[name].matrix


def rest_world(arm, name: str) -> Matrix:
    return arm.matrix_world @ arm.data.bones[name].matrix_local


def ordered(arm) -> list:
    out = []
    def walk(b):
        out.append(b.name)
        for c in b.children:
            walk(c)
    for b in arm.data.bones:
        if b.parent is None:
            walk(b)
    return out


def retarget(src, arm) -> None:
    order = ordered(arm)
    pairs = {t: source_name(t) for t in order}
    pairs = {t: s for t, s in pairs.items() if s and s in src.data.bones}
    align = {}
    for t, s in pairs.items():
        tb, sb = arm.data.bones[t], src.data.bones[s]
        tdir = (rest_world(arm, t).to_3x3() @ Vector((0, 1, 0)))
        sdir = (rest_world(src, s).to_3x3() @ Vector((0, 1, 0)))
        align[t] = tdir.rotation_difference(sdir).to_matrix()
    hips_ratio = bone_world(arm, "Hips").z / bone_world(src, "Hips").z
    rest_rel = {}
    for t in order:
        b = arm.data.bones[t]
        rest_rel[t] = (b.parent.matrix_local.inverted() @ b.matrix_local) if b.parent else b.matrix_local.copy()
    scn = bpy.context.scene
    src.animation_data_create()
    arm.animation_data_create()
    for clip in CLIPS:
        sact = next(a for a in bpy.data.actions if a.name == "%s_%s" % (clip, "EnemyRig") or a.name.startswith(clip + "_EnemyRig"))
        src.animation_data.action = sact
        act = bpy.data.actions.new(clip)
        act.use_fake_user = True
        arm.animation_data.action = act
        f0, f1 = int(sact.frame_range[0]), int(sact.frame_range[1])
        prev = {}
        for f in range(f0, f1 + 1):
            scn.frame_set(f)
            posed = {}
            for t in order:
                b = arm.data.bones[t]
                parent = posed[b.parent.name] if b.parent else arm.matrix_world.copy()
                chain = parent @ rest_rel[t]
                s = pairs.get(t)
                if s is None:
                    posed[t] = chain
                    continue
                delta = pose_world(src, s).to_3x3() @ rest_world(src, s).to_3x3().inverted()
                rot = delta @ align[t] @ rest_world(arm, t).to_3x3()
                want = rot.to_4x4()
                if t == "Hips":
                    move = (pose_world(src, s).translation - rest_world(src, s).translation) * hips_ratio
                    want.translation = rest_world(arm, t).translation + move
                else:
                    want.translation = chain.translation
                posed[t] = want
                basis = chain.inverted() @ want
                q = basis.to_quaternion()
                if t in prev and prev[t].dot(q) < 0.0:
                    q.negate()
                prev[t] = q
                pb = arm.pose.bones[t]
                pb.rotation_mode = "QUATERNION"
                pb.rotation_quaternion = q
                pb.keyframe_insert("rotation_quaternion", frame=f)
                if t == "Hips":
                    pb.location = basis.translation
                    pb.keyframe_insert("location", frame=f)
        print("build_soldier: clip %-10s %d frames" % (clip, f1 - f0 + 1))
    src.animation_data.action = None
    arm.animation_data.action = bpy.data.actions["Aim"]


def mount_gun(arm) -> None:
    objs = import_glb(GUN_SRC)
    meshes = [o for o in objs if o.type == "MESH"]
    for o in meshes:
        world = o.matrix_world.copy()
        o.parent = None
        o.data.transform(world)
        o.matrix_world = Matrix.Identity(4)
    for o in objs:
        if o.type != "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    gun = bpy.context.view_layer.objects.active
    gun.name = "Gun"
    gun.data.name = "Gun"
    polymer = bpy.data.materials.new("Gun_Polymer")
    polymer.use_nodes = True
    bsdf = next(n for n in polymer.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    tex = polymer.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(str(GUN_ALBEDO))
    polymer.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.42
    bsdf.inputs["Metallic"].default_value = 0.35
    gun.data.materials.clear()
    gun.data.materials.append(polymer)
    arm.animation_data.action = bpy.data.actions["Aim"]
    bpy.context.scene.frame_set(int(bpy.data.actions["Aim"].frame_range[0]))
    hand = pose_world(arm, "Hand_R").translation
    palm = (pose_world(arm, "Index1_R").translation + pose_world(arm, "Pinky1_R").translation) * 0.5
    aim = Vector((0.0, -1.0, 0.0))
    up = Vector((0.0, 0.0, 1.0))
    basis = Matrix((aim.cross(up), aim, up)).transposed().to_4x4()
    world = Matrix.Translation(hand.lerp(palm, 0.75)) @ basis @ Matrix.Translation(-GUN_GRIP)
    gun.parent = arm
    gun.parent_type = "BONE"
    gun.parent_bone = "Hand_R"
    gun.matrix_world = world
    arm.animation_data.action = None


def make_lods(body) -> None:
    base = body.data
    for name, ratio in LODS:
        obj = body if name == "Enemy_Mesh" else body.copy()
        if obj is not body:
            obj.data = base.copy()
            bpy.context.scene.collection.objects.link(obj)
        obj.name = name
        obj.data.name = name
        mod = obj.modifiers.new("Decimar", "DECIMATE")
        mod.ratio = ratio
        with bpy.context.temp_override(object=obj, active_object=obj):
            bpy.ops.object.modifier_move_to_index(modifier=mod.name, index=0)
            bpy.ops.object.modifier_apply(modifier=mod.name)
        print("build_soldier: %s tris=%d" % (name, sum(len(p.vertices) - 2 for p in obj.data.polygons)))


def export(arm, out: Path) -> None:
    for a in list(bpy.data.actions):
        if a.name not in CLIPS:
            bpy.data.actions.remove(a)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(filepath=str(out), export_format="GLB", export_animations=True,
                              export_animation_mode="ACTIONS", export_force_sampling=True,
                              export_skins=True, export_yup=True, export_image_format="AUTO",
                              export_anim_single_armature=True, export_influence_nb=4)
    print("SUCCESS %s (%.0f KB)" % (out, out.stat().st_size / 1024.0))


def build(out: Path = OUT) -> None:
    _reset()
    bpy.context.scene.render.fps = 24
    src = load_source()
    arm, meshes = load_body()
    for o in list(bpy.data.objects):
        if o.type == "MESH" and o.name.startswith("Icosphere"):
            bpy.data.objects.remove(o, do_unlink=True)
    rename(arm, meshes)
    fit_to(src, arm, meshes)
    body = bind(arm, meshes)
    charcoal_uniform(body)
    retarget(src, arm)
    bpy.data.objects.remove(src, do_unlink=True)
    mount_gun(arm)
    make_lods(body)
    export(arm, out)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    build(Path(argv[argv.index("--out") + 1]) if "--out" in argv else OUT)
