#!/usr/bin/env python3
"""FLOWFIRE MARK 23 VIEWMODEL BUILDER.

Canonicaliza assets/models/mark23_viewmodel.glb:
- Escala de centimetros a metros (factor 0.01).
- Recentra al origen del arma (cabeza de main_j_050 en reposo).
- Rota 180° sobre Z para alinear el cañón con -Z (forward de Godot) y las miras.
- Elimina mallas no deseadas: Icosphere y mano desnuda (Hand_Mesh_Hand_D_0).
- Conserva mallas de producción con piel y guante negro (Hand_Mesh_Glove_D_0).
- Nombra mallas canónicas: Frame, Slide, Magazine, Arms.
- Crea y nombra los sockets requeridos:
    Frame, Slide, Magazine, Barrel, Muzzle, EjectionPort,
    SightRear, SightFront, Grip, Magwell, Trigger.
- Escala y orienta curvas de animación.
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

REPO = Path(__file__).resolve().parents[1]
RAW_GLB = REPO / "downloads" / "models" / "mark23_viewmodel_raw.glb"
OUT_GLB = REPO / "assets" / "models" / "mark23_viewmodel.glb"
MAX_TEX = 1024


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = 30
    bpy.context.scene.render.fps_base = 1.0


def transform_coord(p: Vector, pivot: Vector, scale: float) -> Vector:
    rel = p - pivot
    # Rotacion de 180° sobre Z: X -> -X, Y -> -Y, Z -> Z
    rot = Vector((-rel.x, -rel.y, rel.z))
    return rot * scale


def build_mark23(raw_path: Path, out_path: Path) -> None:
    reset_scene()

    if not raw_path.exists():
        raise SystemExit(f"Falta el asset de origen: {raw_path}")

    bpy.ops.import_scene.gltf(filepath=str(raw_path))

    # Identificar Armadura
    arm_objs = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
    if len(arm_objs) != 1:
        raise SystemExit(f"Se esperaba 1 armadura, se encontraron {len(arm_objs)}")
    arm = arm_objs[0]

    # Eliminar objetos no deseados (Icosphere, mano desnuda, helpers vacíos de FBX)
    for o in list(bpy.context.scene.objects):
        if o.name == "Icosphere" or (o.type == "MESH" and ("Hand_Mesh_Hand" in o.data.name or "Hand_D" in o.data.name)):
            bpy.data.objects.remove(o, do_unlink=True)
        elif o.type == "EMPTY" and o.name in ("Object_6", "Side", "main", "mag", "Hand_Mesh"):
            bpy.data.objects.remove(o, do_unlink=True)

    # Identificar y renombrar mallas principales
    frame_mesh = None
    slide_mesh = None
    mag_mesh = None
    arms_mesh = None

    for o in list(bpy.context.scene.objects):
        if o.type != "MESH":
            continue
        mname = o.data.name
        if "main_Mark23" in mname:
            frame_mesh = o
            o.name = "Frame"
        elif "Side_Mark23" in mname:
            slide_mesh = o
            o.name = "Slide"
        elif "mag_Mark23" in mname:
            mag_mesh = o
            o.name = "Magazine"
        elif "Glove" in mname:
            arms_mesh = o
            o.name = "Arms"

    if not (frame_mesh and slide_mesh and mag_mesh and arms_mesh):
        raise SystemExit(f"Faltan mallas: Frame={frame_mesh}, Slide={slide_mesh}, Mag={mag_mesh}, Arms={arms_mesh}")

    # Pivote del arma: cabeza de main_j_050
    bone_name = "main_j_050"
    if bone_name not in arm.data.bones:
        raise SystemExit(f"Hueso {bone_name} no encontrado en la armadura")

    pivot = arm.data.bones[bone_name].head_local.copy()
    scale = 0.01

    # 1. Transformar huesos en modo EDIT
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for eb in arm.data.edit_bones:
        eb.head = transform_coord(eb.head, pivot, scale)
        eb.tail = transform_coord(eb.tail, pivot, scale)
        eb.roll = -eb.roll
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.context.view_layer.update()

    # 2. Transformar vértices de todas las mallas
    for o in (frame_mesh, slide_mesh, mag_mesh, arms_mesh):
        for v in o.data.vertices:
            v.co = transform_coord(v.co, pivot, scale)
        o.data.update()

    # 3. Escalar y orientar curvas de posición de animación
    for act in bpy.data.actions:
        for fc in act.fcurves:
            if "location" in fc.data_path:
                # X -> -scale, Y -> -scale, Z -> scale
                mul = -scale if fc.array_index in (0, 1) else scale
                for kp in fc.keyframe_points:
                    kp.co[1] *= mul
                fc.update()

    # 4. Sockets canónicos (calculados en el nuevo espacio de mundo)
    # En coordenadas Blender (+Y al frente/morro, +Z arriba, +X izquierda):
    muzzle_pos = Vector((-0.0032, 0.2138, 0.0894))
    barrel_pos = Vector((-0.0032, 0.1000, 0.0894))
    grip_pos = Vector((-0.0015, -0.0098, -0.0248))
    magwell_pos = Vector((-0.0030, -0.0196, -0.0496))
    trigger_pos = Vector((-0.0032, 0.0450, 0.0450))

    sight_front_pos = Vector((-0.0032, 0.1872, 0.1122))
    sight_rear_pos = Vector((-0.0038, -0.0212, 0.1124))
    ejection_port_pos = Vector((0.0109, 0.0686, 0.0908))

    def make_socket(name: str, parent_obj: bpy.types.Object, world_pos: Vector) -> bpy.types.Object:
        empty = bpy.data.objects.new(name, None)
        empty.empty_display_type = "PLAIN_AXES"
        empty.empty_display_size = 0.02
        bpy.context.scene.collection.objects.link(empty)
        empty.parent = parent_obj
        empty.matrix_world = Matrix.Translation(world_pos)
        return empty

    # Sockets del Frame / Barrel
    barrel_socket = make_socket("Barrel", frame_mesh, barrel_pos)
    muzzle_socket = make_socket("Muzzle", barrel_socket, muzzle_pos)
    grip_socket = make_socket("Grip", frame_mesh, grip_pos)
    magwell_socket = make_socket("Magwell", frame_mesh, magwell_pos)
    trigger_socket = make_socket("Trigger", frame_mesh, trigger_pos)

    # Sockets del Slide
    sight_front_socket = make_socket("SightFront", slide_mesh, sight_front_pos)
    sight_rear_socket = make_socket("SightRear", slide_mesh, sight_rear_pos)
    ejection_port_socket = make_socket("EjectionPort", slide_mesh, ejection_port_pos)

    # Limitar resolución de texturas a MAX_TEX
    for img in bpy.data.images:
        if img.size[0] > MAX_TEX or img.size[1] > MAX_TEX:
            img.scale(MAX_TEX, MAX_TEX)

    # Exportar GLB canónico
    out_path.parent.mkdir(parents=True, exist_ok=True)
    bpy.context.view_layer.objects.active = arm

    bpy.ops.export_scene.gltf(
        filepath=str(out_path),
        export_format="GLB",
        use_selection=False,
        export_apply=False,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_nla_strips=False,
        export_skins=True,
        export_yup=True,
        export_image_format="AUTO",
        export_optimize_animation_size=False,
        export_anim_single_armature=True,
        export_influence_nb=4,
    )

    print(f"SUCCESS: {out_path} exportado ({out_path.stat().st_size / 1024.0:.1f} KB)")


def main() -> None:
    argv = sys.argv
    argv = argv[argv.index("--") + 1:] if "--" in argv else []
    parser = argparse.ArgumentParser(description="FLOWFIRE Mark 23 viewmodel builder")
    parser.add_argument("--raw", default=str(RAW_GLB))
    parser.add_argument("--out", default=str(OUT_GLB))
    args = parser.parse_args(argv)

    build_mark23(Path(args.raw), Path(args.out))


if __name__ == "__main__":
    main()
