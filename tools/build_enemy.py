#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import math
import struct
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Matrix, Quaternion, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_kit import build_kit

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "assets" / "models" / "enemy.glb"
DEFAULT_FBX = (REPO / "downloads" / "models" / "quaternius_animation_library"
               / "AnimationLibrary_Godot_Standard.glb")
MAX_TEX = 1024
FPS = 24

BONE_ALIASES = {
    "hips": "Hips", "pelvis": "Hips",
    "spine": "Spine", "spine1": "Chest", "spine2": "Chest.001",
    "chest": "Chest", "upperchest": "Chest.001",
    "neck": "Neck", "head": "Head",
    "leftshoulder": "Shoulder_L", "shoulder_l": "Shoulder_L", "lshoulder": "Shoulder_L",
    "leftarm": "UpperArm_L", "upperarm_l": "UpperArm_L", "leftupperarm": "UpperArm_L",
    "leftforearm": "ForeArm_L", "lowerarm_l": "ForeArm_L", "leftlowerarm": "ForeArm_L",
    "lefthand": "Hand_L", "hand_l": "Hand_L",
    "rightshoulder": "Shoulder_R", "shoulder_r": "Shoulder_R", "rshoulder": "Shoulder_R",
    "rightarm": "UpperArm_R", "upperarm_r": "UpperArm_R", "rightupperarm": "UpperArm_R",
    "rightforearm": "ForeArm_R", "lowerarm_r": "ForeArm_R", "rightlowerarm": "ForeArm_R",
    "righthand": "Hand_R", "hand_r": "Hand_R",
    "leftupleg": "Thigh_L", "thigh_l": "Thigh_L", "leftthigh": "Thigh_L",
    "leftleg": "Shin_L", "shin_l": "Shin_L", "leftshin": "Shin_L",
    "leftfoot": "Foot_L", "foot_l": "Foot_L",
    "lefttoebase": "Toe_L", "toe_l": "Toe_L",
    "rightupleg": "Thigh_R", "thigh_r": "Thigh_R", "rightthigh": "Thigh_R",
    "rightleg": "Shin_R", "shin_r": "Shin_R", "rightshin": "Shin_R",
    "rightfoot": "Foot_R", "foot_r": "Foot_R",
    "righttoebase": "Toe_R", "toe_r": "Toe_R",
    "defhips": "Hips", "defspine001": "Spine", "defspine002": "Chest",
    "defspine003": "Chest.001", "defneck": "Neck", "defhead": "Head",
    "defshoulderl": "Shoulder_L", "defupperarml": "UpperArm_L",
    "defforearml": "ForeArm_L", "defhandl": "Hand_L",
    "defshoulderr": "Shoulder_R", "defupperarmr": "UpperArm_R",
    "defforearmr": "ForeArm_R", "defhandr": "Hand_R",
    "defthighl": "Thigh_L", "defshinl": "Shin_L", "deffootl": "Foot_L",
    "deftoel": "Toe_L",
    "defthighr": "Thigh_R", "defshinr": "Shin_R", "deffootr": "Foot_R",
    "deftoer": "Toe_R",
}


def canonical(name: str) -> str:
    n = name.split(":")[-1]
    n = n.replace("_", "").replace(".", "").replace("-", "").replace(" ", "")
    n = n.lower()
    if n.startswith("def") and n[3:] in BONE_ALIASES:
        n = n[3:]
    return n


def scene_setup() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS
    bpy.context.scene.render.fps_base = 1.0


def retarget_glb(path: Path) -> Path:
    data = path.read_bytes()
    if len(data) < 12 or struct.unpack('<I', data[:4])[0] != 0x46546C67:
        return path
    off = 12
    chunks = []
    js = None
    while off < len(data):
        clen, ctype = struct.unpack('<II', data[off:off + 8])
        chunk = data[off + 8:off + 8 + clen]
        chunks.append((ctype, chunk))
        if ctype == 0x4E4F534A:
            js = json.loads(chunk.decode('utf-8'))
        off += 8 + clen + ((4 - clen % 4) % 4 if clen % 4 else 0)
    if js is None:
        return path
    cambios = 0
    for node in js.get("nodes", []):
        target = BONE_ALIASES.get(canonical(node.get("name", "")))
        if target and target != node.get("name"):
            node["name"] = target
            cambios += 1
    if not cambios:
        return path
    nuevo = json.dumps(js, separators=(",", ":")).encode("utf-8")
    nuevo += b" " * ((4 - len(nuevo) % 4) % 4)
    cuerpo = bytearray()
    for ctype, chunk in chunks:
        if ctype == 0x4E4F534A:
            cuerpo += struct.pack("<II", len(nuevo), ctype) + nuevo
        else:
            relleno = (4 - len(chunk) % 4) % 4
            cuerpo += struct.pack("<II", len(chunk) + relleno, ctype) + chunk + b"\x00" * relleno
    salida = path.with_name(path.stem + "_retarget.glb")
    salida.write_bytes(struct.pack("<III", 0x46546C67, 2, 12 + len(cuerpo)) + bytes(cuerpo))
    print("build_enemy: %d nodos del GLB renombrados al contrato (retarget en el JSON)"
          % cambios)
    return salida


def import_source(path: Path) -> tuple:
    if path.suffix.lower() in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=str(retarget_glb(path)))
    else:
        bpy.ops.import_scene.fbx(filepath=str(path))
    arms = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
    if len(arms) != 1:
        raise SystemExit("build_enemy: se esperaba 1 armadura, hay %d" % len(arms))
    arm = arms[0]
    bone_names = {b.name for b in arm.data.bones}
    best, best_tris = None, 0
    for o in bpy.context.scene.objects:
        if o.type != "MESH":
            continue
        if not any(vg.name in bone_names for vg in o.vertex_groups):
            continue
        tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
        if tris > best_tris:
            best, best_tris = o, tris
    if best is None:
        raise SystemExit("build_enemy: ninguna malla del fichero esta pesada a la armadura")
    for o in list(bpy.context.scene.objects):
        if o not in (arm, best):
            bpy.data.objects.remove(o, do_unlink=True)
    heal_uv(best)
    print("build_enemy: cuerpo %s  tris=%d  huesos=%d"
          % (best.name, best_tris, len(arm.data.bones)))
    return arm, best


def heal_uv(mesh) -> None:
    layers = [l.name for l in mesh.data.uv_layers]
    if len(layers) < 2:
        return
    src = mesh.data.uv_layers[1]
    vals = [tuple(d.uv) for d in src.data]
    unicos = len({(round(u, 4), round(v, 4)) for u, v in vals})
    if unicos < 8:
        return
    dst = mesh.data.uv_layers[0] if len(layers) >= 1 else mesh.data.uv_layers.new()
    for i, d in enumerate(dst.data):
        d.uv = vals[i]
    mesh.data.uv_layers.remove(src)
    for i, layer in enumerate(mesh.data.uv_layers):
        layer.name = "UVMap" if i == 0 else layer.name
    print("build_enemy: UV capa 0 reparada desde TEXCOORD_1 (%d unicos)" % unicos)


GEAR_UV_SCALE = 0.55


def gear_uv(mesh) -> None:
    if mesh.data.uv_layers:
        layer = mesh.data.uv_layers[0]
    else:
        layer = mesh.data.uv_layers.new()

    def sin_uv(li: int) -> bool:
        u, v = layer.data[li].uv
        return abs(u) < 1e-5 and abs(v) < 1e-5

    tocados = 0
    for poly in mesh.data.polygons:
        if not any(sin_uv(li) for li in poly.loop_indices):
            continue
        nrm = poly.normal
        axis = max(range(3), key=lambda i: abs(nrm[i]))
        for li in poly.loop_indices:
            if not sin_uv(li):
                continue
            co = mesh.data.vertices[mesh.data.loops[li].vertex_index].co
            u, v = ((co.y, co.z), (co.x, co.z), (co.x, co.y))[axis]
            layer.data[li].uv = (u / GEAR_UV_SCALE, v / GEAR_UV_SCALE)
            tocados += 1
    print("build_enemy: UV de %d loops del equipo proyectadas (caja)" % tocados)


def rename_bones(arm) -> None:
    pending = {}
    for b in arm.data.bones:
        target = BONE_ALIASES.get(canonical(b.name))
        if target and target != b.name:
            pending[b.name] = target
    for old, new in pending.items():
        arm.data.bones[old].name = new
    if pending:
        for act in bpy.data.actions:
            for fc in act.fcurves:
                ruta = fc.data_path
                if not ruta.startswith('pose.bones["'):
                    continue
                for old, new in pending.items():
                    ruta = ruta.replace('pose.bones["%s"]' % old,
                                        'pose.bones["%s"]' % new)
                if ruta != fc.data_path:
                    fc.data_path = ruta
    present = {b.name for b in arm.data.bones}
    missing = [n for n in ("Hips", "Spine", "Chest", "Neck", "Head",
                           "Thigh_L", "Shin_L", "Foot_L",
                           "Thigh_R", "Shin_R", "Foot_R") if n not in present]
    if missing:
        raise SystemExit(
            "build_enemy: el rig no resuelve al contrato de Enemy.gd.\n"
            "  faltan: %s\n  el huesped trae: %s\n"
            "  anade el alias en BONE_ALIASES (tools/build_enemy.py) antes de "
            "exportar: sin estos nombres el ragdoll reparte mal la masa."
            % (", ".join(missing), ", ".join(sorted(present))[:400]))


def keep_action(arm, action_name: str):
    act = bpy.data.actions[action_name]
    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = act
    return act


def bake_action(arm, source_action, name: str, start: int = 0, end: int = -1,
                pose_fn=None) -> None:
    if end < start:
        start = int(math.floor(source_action.frame_range[0]))
        end = int(math.ceil(source_action.frame_range[1]))
    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = source_action
    order = [b for b in arm.pose.bones]
    muestras = []
    bpy.context.scene.frame_set(start)
    bpy.context.view_layer.update()
    for frame in range(start, end + 1):
        bpy.context.scene.frame_set(frame)
        if pose_fn is not None:
            pose_fn(arm, frame)
        bpy.context.view_layer.update()
        muestras.append([(pb.matrix_basis.copy()) for pb in order])

    new = bpy.data.actions.new(name)
    arm.animation_data.action = new
    for i, cuadro in enumerate(muestras):
        out_frame = i + 1
        for pb, basis in zip(order, cuadro):
            pb.rotation_mode = "QUATERNION"
            pb.location = basis.to_translation()
            pb.rotation_quaternion = basis.to_quaternion()
            pb.scale = basis.to_scale()
            pb.keyframe_insert("location", frame=out_frame, group=pb.name)
            pb.keyframe_insert("rotation_quaternion", frame=out_frame, group=pb.name)
            pb.keyframe_insert("scale", frame=out_frame, group=pb.name)

    for fc in new.fcurves:
        for kp in fc.keyframe_points:
            kp.interpolation = "LINEAR"
    new.use_fake_user = True


LOWER_BODY = ("Hips", "Thigh_L", "Shin_L", "Foot_L", "Toe_L", "Thigh_R", "Shin_R", "Foot_R", "Toe_R")


def bake_mix(arm, lower_action, upper_action, name: str, hips_follow: float = 0.7) -> None:
    upper = [pb for pb in arm.pose.bones if pb.name not in LOWER_BODY]
    arm.animation_data.action = upper_action
    bpy.context.scene.frame_set(int(math.floor(upper_action.frame_range[0])))
    bpy.context.view_layer.update()
    held = {pb.name: pb.matrix_basis.copy() for pb in upper}
    upright = arm.pose.bones["Hips"].matrix_basis.to_quaternion()

    def pose(arm_, _frame):
        for pb in upper:
            pb.matrix_basis = held[pb.name]
        hips = arm_.pose.bones["Hips"]
        loc = hips.matrix_basis.to_translation()
        rot = hips.matrix_basis.to_quaternion().slerp(upright, hips_follow)
        hips.matrix_basis = Matrix.Translation(loc) @ rot.to_matrix().to_4x4()

    bake_action(arm, lower_action, name, pose_fn=pose)


NECK_HEAD_YAW = math.radians(72.0)
NECK_HEAD_PITCH = math.radians(-14.0)
NECK_TWIST = math.radians(16.0)


def build_neck_clip(arm, idle_action) -> None:
    def pose(arm_, _frame):
        pb = arm_.pose.bones
        if "Head" in pb:
            h = pb["Head"]
            h.rotation_mode = "QUATERNION"
            h.rotation_quaternion = Quaternion(
                (0.0, 0.0, 1.0), NECK_HEAD_YAW) @ Quaternion(
                (1.0, 0.0, 0.0), NECK_HEAD_PITCH)
        if "Chest" in pb:
            c = pb["Chest"]
            c.rotation_mode = "QUATERNION"
            c.rotation_quaternion = Quaternion((0.0, 1.0, 0.0), NECK_TWIST)

    bake_action(arm, idle_action, "Neck", 1, 1, pose)


def find_action(wanted: str):
    want = wanted.split("|")[-1].strip().lower()
    cands = list(bpy.data.actions)
    exact = [a for a in cands if a.name.split("|")[-1].strip().lower() == want]
    if exact:
        return exact[0]
    loose = [a for a in cands if want in a.name.lower()]
    if not loose:
        raise SystemExit("build_enemy: no hay accion '%s' en el huesped; trae: %s"
                         % (wanted, ", ".join(sorted(a.name for a in cands))))
    return sorted(loose, key=lambda a: len(a.name))[0]


def assert_clip_varies(action, name: str, min_span: float = 1e-3) -> None:
    span = 0.0
    for fc in action.fcurves:
        vals = [kp.co[1] for kp in fc.keyframe_points]
        if len(vals) > 1:
            span = max(span, max(vals) - min(vals))
    if span < min_span:
        raise SystemExit(
            "build_enemy: el clip '%s' NO VARIA (recorrido maximo %.6f). Es una\n"
            "  pose congelada, no una animacion: el enemigo saldria en cruz.\n"
            "  Revisa que la accion fuente se muestree ANTES de escribir las claves."
            % (name, span))
    print("  clip %-6s fcurves=%d  recorrido maximo %.4f" % (name, len(action.fcurves), span))


def export(arm, out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    for img in bpy.data.images:
        if img.size[0] > 0 and (img.size[0] > MAX_TEX or img.size[1] > MAX_TEX):
            img.scale(MAX_TEX, MAX_TEX)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(
        filepath=str(out_path),
        export_format="GLB",
        use_selection=False,
        export_apply=False,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_nla_strips=False,
        export_frame_range=False,
        export_force_sampling=True,
        export_frame_step=1,
        export_bake_animation=False,
        export_skins=True,
        export_yup=True,
        export_image_format="AUTO",
        export_optimize_animation_size=False,
        export_anim_single_armature=True,
        export_influence_nb=4,
        export_extras=True,
    )
    print("SUCCESS: %s (%.1f KB)" % (out_path, out_path.stat().st_size / 1024.0))


def main() -> None:
    argv = sys.argv
    argv = argv[argv.index("--") + 1:] if "--" in argv else []
    parser = argparse.ArgumentParser(description="FLOWFIRE enemy builder (CC0 Quaternius)")
    parser.add_argument("--fbx", default=str(DEFAULT_FBX))
    parser.add_argument("--out", default=str(OUT))
    parser.add_argument("--no-gear", action="store_true",
                        help="la fuente ya trae casco/chaleco/rifle modelados")
    parser.add_argument("--idle", default="")
    parser.add_argument("--walk", default="")
    args = parser.parse_args(argv)

    fbx = Path(args.fbx)
    if not fbx.exists():
        raise SystemExit("build_enemy: falta la fuente %s\n  descargala con el\n"
                         "  comando que documenta este script en su cabecera." % fbx)

    scene_setup()
    arm, mesh = import_source(fbx)
    arm.name = "EnemyRig"
    arm.data.name = "EnemyRig"
    mesh.name = "Enemy_Mesh"
    if fbx.suffix.lower() not in (".glb", ".gltf"):
        rename_bones(arm)

    skin_mat = bpy.data.materials.new("Enemy_Skin")
    skin_mat.diffuse_color = (0.35, 0.35, 0.31, 1.0)
    gear_mat = bpy.data.materials.new("Enemy_Fabric")
    gear_mat.diffuse_color = (0.10, 0.11, 0.13, 1.0)
    two_surfaces = len(mesh.material_slots) >= 2
    mesh.data.materials.clear()
    mesh.data.materials.append(skin_mat)
    mesh.data.materials.append(gear_mat)
    for poly in mesh.data.polygons:
        poly.material_index = min(poly.material_index, 1) if two_surfaces else 0

    pieces = 0
    muzzle = None
    if not args.no_gear:
        aim_src = find_action("Pistol_Aim_Neutral")
        if arm.animation_data is None:
            arm.animation_data_create()
        arm.animation_data.action = aim_src
        fr = aim_src.frame_range
        bpy.context.scene.frame_set(int(math.floor((fr[0] + fr[1]) * 0.5)))
        bpy.context.view_layer.update()
        pieces, muzzle = build_kit(arm, mesh, skin_mat, gear_mat)
        gear_uv(mesh)
        arm.animation_data.action = None
        for pb in arm.pose.bones:
            pb.matrix_basis = Matrix.Identity(4)
        bpy.context.scene.frame_set(0)
        bpy.context.view_layer.update()
    else:
        print("build_enemy: sin equipo horneado (--no-gear): el huesped ya lo trae")
    if muzzle is not None:
        arm["rifle_muzzle"] = [round(float(muzzle.x), 5),
                               round(float(muzzle.y), 5),
                               round(float(muzzle.z), 5)]
    print("huesos=%d tris=%d (cuerpo + %d piezas de equipo) boca=%s"
          % (len(arm.data.bones),
             sum(len(p.vertices) - 2 for p in mesh.data.polygons), pieces,
             "si" if muzzle is not None else "no"))

    idle = find_action(args.idle or "Idle_Loop")
    walk = find_action(args.walk or "Walk_Loop")
    aim = find_action("Pistol_Aim_Neutral")
    hit = find_action("Hit_Chest")
    death = find_action("Death01")
    bake_action(arm, idle, "Idle")
    bake_action(arm, walk, "Walk")
    bake_action(arm, aim, "Aim")
    bake_action(arm, hit, "Hit")
    bake_action(arm, death, "Death")
    bake_action(arm, find_action("Pistol_Idle_Loop"), "Ready")
    aim_down = find_action("Pistol_Aim_Down")
    bake_mix(arm, find_action("Crouch_Fwd_Loop"), aim, "Sneak")
    bake_mix(arm, find_action("Jog_Fwd_Loop"), aim_down, "Run")
    bake_mix(arm, find_action("Crouch_Idle_Loop"), aim, "CrouchAim")
    build_neck_clip(arm, idle)
    for clip in ("Idle", "Walk", "Hit", "Death"):
        assert_clip_varies(bpy.data.actions[clip], clip)
    keep_action(arm, "Idle")
    for a in list(bpy.data.actions):
        if a.name not in ("Idle", "Walk", "Neck", "Aim", "Hit", "Death", "Ready", "Sneak", "Run", "CrouchAim"):
            bpy.data.actions.remove(a, do_unlink=True)
    export(arm, Path(args.out))


if __name__ == "__main__":
    main()
