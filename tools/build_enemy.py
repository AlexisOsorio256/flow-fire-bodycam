#!/usr/bin/env python3
"""build_enemy.py -- construye `assets/models/enemy.glb` a partir del unico
personaje con esqueleto humano y animacion que cumple la decision del dueno:
humano moderno, con huesos, licencia relajada.

FUENTE (CC0 1.0, dominio publico, sin credito obligatorio):
  "Animated Human" de Quaternius.
  https://opengameart.org/content/animated-human-low-poly
  Autor: Quaternius. Licencia: CC0 1.0 Universal.
  Se descarga como `downloads/models/quaternius_animated_human.zip` (fuera del
  arbol activo, `.gitignore`); este builder es lo unico que se versiona.

QUE HACE Y QUE NO
-----------------
NO inventa animacion. La fuente trae 48 huesos, malla de 1578 tris y nueve
clips (Idle, Walk, Run, Death, Jump, Punch, Working y dos acciones sueltas). El
juego exige tres nombres EXACTOS --`Enemy.gd`: CLIP_IDLE, CLIP_WALK, CLIP_NECK--
y el clip de muerte es de cuerpo entero, no de cuello, asi que la reaccion del
cuello se construye aqui sobre el fotograma 1 del propio clip Idle: la cabeza
se gira ~72 grados y el tronco tuerce ~16 grados. Sale UN fotograma horneado
(velocidad nominal, sin bucle): `Enemy._die` lo reproduce en el pecho y suelta
el ragdoll a los 0,12 s (PUSH_REACTION), y a 24 fps mas frames nadie los veria.

Los nombres de hueso se traducen a la nomenclatura que `Enemy._bone_share` ya
conoce (Hips, Spine, Chest, Neck, Head, Shoulder/Arm/ForeArm/Hand, Thigh, Shin)
porque ese reparto de masa esta medido, no es decorativo.
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Quaternion

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "assets" / "models" / "enemy.glb"
DEFAULT_FBX = REPO / "downloads" / "models" / "quaternius_animated_human" / "Animated Human.fbx"
MAX_TEX = 1024
FPS = 24

# Hueso de la fuente -> nombre que pide `Enemy._bone_share`. El reparto de masa
# del ragdoll se decide por estos nombres; sin el renombrado, todos los huesos
# caerian en la rama por defecto (0,01) y un torso pesaria como un dedo.
RENAME = {
    "Hips": "Hips",
    "Spine": "Spine",
    "Spine1": "Chest",
    "Spine2": "Chest",
    "Neck": "Neck",
    "Head": "Head",
    "LeftShoulder": "Shoulder_L",
    "LeftArm": "UpperArm_L",
    "LeftForeArm": "ForeArm_L",
    "LeftHand": "Hand_L",
    "RightShoulder": "Shoulder_R",
    "RightArm": "UpperArm_R",
    "RightForeArm": "ForeArm_R",
    "RightHand": "Hand_R",
    "LeftUpLeg": "Thigh_L",
    "LeftLeg": "Shin_L",
    "LeftFoot": "Foot_L",
    "RightUpLeg": "Thigh_R",
    "RightLeg": "Shin_R",
    "RightFoot": "Foot_R",
}


def scene_setup() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS
    bpy.context.scene.render.fps_base = 1.0


def import_source(fbx: Path) -> tuple:
    bpy.ops.import_scene.fbx(filepath=str(fbx))
    arms = [o for o in bpy.context.selected_objects if o.type == "ARMATURE"]
    meshes = [o for o in bpy.context.selected_objects if o.type == "MESH"]
    if len(arms) != 1 or len(meshes) != 1:
        raise SystemExit("build_enemy: se esperaba 1 armadura y 1 malla, hay %d/%d"
                         % (len(arms), len(meshes)))
    return arms[0], meshes[0]


def rename_bones(arm) -> None:
    # Dos pasadas: un nombre destino puede coincidir con un nombre origen que
    # aun no se ha leido (Spine2 -> Chest no colisiona, pero se hace igual).
    pending = {b.name: RENAME[b.name] for b in arm.data.bones if b.name in RENAME}
    for old, new in pending.items():
        arm.data.bones[old].name = new


def keep_action(arm, action_name: str):
    """Deja la accion pedida activa y borra las demas: el GLB solo exporta la
    accion activa por hueso, y nueve clips de un donante no son del juego."""
    act = bpy.data.actions[action_name]
    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = act
    return act


def strip_pose(arm, frame: int) -> None:
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()


def bake_action(arm, source_action, name: str, start: int, end: int, pose_fn=None) -> None:
    """Hornera [start, end] de una accion en una accion nueva de 1..N frames.

    `pose_fn(arm, frame)` se llama ANTES de leer la matriz de la fuente y puede
    reescribir la pose (lo usa el clip de cuello). Se hornea por MUESTREO: la
    interpolacion de la fuente (curvas Bezier del FBX) no viaja al glTF."""
    arm.animation_data.action = source_action
    new = bpy.data.actions.new(name)
    arm.animation_data.action = new
    order = [b for b in arm.pose.bones]

    for i, frame in enumerate(range(start, end + 1)):
        bpy.context.scene.frame_set(frame)
        if pose_fn is not None:
            pose_fn(arm, frame)
        bpy.context.view_layer.update()
        out_frame = i + 1
        for pb in order:
            basis = pb.matrix_basis
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


# ---------------------------------------------------------------------------
# Clip NECK. La fuente no tiene reaccion de cuello: se compone de dos poses del
# propio Idle para que el gesto siga siendo del mismo rig y la misma malla.
# ---------------------------------------------------------------------------
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
    )
    print("SUCCESS: %s (%.1f KB)" % (out_path, out_path.stat().st_size / 1024.0))


def main() -> None:
    argv = sys.argv
    argv = argv[argv.index("--") + 1:] if "--" in argv else []
    parser = argparse.ArgumentParser(description="FLOWFIRE enemy builder (CC0 Quaternius)")
    parser.add_argument("--fbx", default=str(DEFAULT_FBX))
    parser.add_argument("--out", default=str(OUT))
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
    rename_bones(arm)
    print("huesos=%d tris=%d" % (len(arm.data.bones),
                                 sum(len(p.vertices) - 2 for p in mesh.data.polygons)))

    idle = bpy.data.actions["Human Armature|Human Armature|Idle"]
    walk = bpy.data.actions["Human Armature|Human Armature|Walk"]
    bake_action(arm, idle, "Idle", 1, 24)
    bake_action(arm, walk, "Walk", 1, 24)
    build_neck_clip(arm, idle)
    keep_action(arm, "Idle")   # el GLB exporta la activa; las demas quedan por accion
    for a in list(bpy.data.actions):
        if a.name not in ("Idle", "Walk", "Neck"):
            bpy.data.actions.remove(a, do_unlink=True)
    export(arm, Path(args.out))


if __name__ == "__main__":
    main()
