#!/usr/bin/env python3
"""Sustituye la malla del enemigo por un soldado de Sketchfab conservando el
esqueleto, los clips y el contrato de `Enemy.gd`:

    blender --background --python tools/build_soldier.py -- [--body ruta.glb]

El rig de origen es `downloads/models/enemy_rig.glb`, que es la salida de
`tools/build_enemy.py`: aporta los 53 huesos con los nombres del contrato y los
seis clips (Idle/Walk/Neck/Aim/Hit/Death). Aqui solo se cambia QUIEN lleva esos
huesos: se congela el soldado en T, se gira y se escala hasta el rig y se pesa
por calor de hueso. La ropa del soldado no viaja al juego: `Enemy.gd` sustituye
las dos superficies por sus dos negros, asi que lo que se ve es la SILUETA.

El glTF de Sketchfab trae la pose de reposo rota: la armadura lleva una escala
de 0,018 metida en la POSE, no en el resto, y ademas el yaw del modelo vive en
el hueso Hips. Por eso la T se saca dejando quietos solo el rootJoint y Hips, y
el giro se MIDE (eje izquierda-derecha y punta del pie), no se supone.
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "assets" / "models" / "enemy.glb"
RIG_SRC = REPO / "downloads" / "models" / "enemy_rig.glb"
BODY_SRC = REPO / "downloads" / "models" / "swat_animated.glb"
MAX_TEX = 1024

ROOT_JOINT = "GLTF_created_0_rootJoint"
KEEP_POSE = (ROOT_JOINT, "mixamorig:Hips_68")
HAND_L = "mixamorig:LeftHand_27"
HAND_R = "mixamorig:RightHand_51"
FOOT_L = "mixamorig:LeftFoot_60"
TOE_L = "mixamorig:LeftToeBase_59"
HIPS = "mixamorig:Hips_68"

## Huesos que `Enemy.gd` necesita de verdad para el ragdoll y los impactos.
CONTRACT = ("Hips", "Spine", "Chest", "Chest.001", "Neck", "Head",
            "UpperArm_L", "ForeArm_L", "Hand_L",
            "UpperArm_R", "ForeArm_R", "Hand_R",
            "Thigh_L", "Shin_L", "Foot_L", "Toe_L",
            "Thigh_R", "Shin_R", "Foot_R", "Toe_R")

## Reparto en las dos superficies del contrato: 0 uniforme, 1 equipo.
GEAR = ("Object_10", "Object_9")


def scene_setup() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = 24
    bpy.context.scene.render.fps_base = 1.0


def bbox(objs) -> tuple:
    """Caja en espacio de mundo. Fuerza el update antes de leer: Blender no
    recalcula `matrix_world` al asignarlo, y una lectura perezosa devuelve la
    matriz vieja (la del padre, con la escala de 55 del glTF)."""
    bpy.context.view_layer.update()
    mn = Vector((1e9,) * 3)
    mx = Vector((-1e9,) * 3)
    for o in objs:
        for v in o.data.vertices:
            w = o.matrix_world @ v.co
            mn = Vector((min(mn[i], w[i]) for i in range(3)))
            mx = Vector((max(mx[i], w[i]) for i in range(3)))
    return mn, mx


def t_pose(arm) -> None:
    """Deja el soldado en T: se sueltan todos los huesos menos los dos que
    llevan la escala y el yaw del modelo."""
    if arm.animation_data:
        arm.animation_data.action = None
    for pb in arm.pose.bones:
        if pb.name not in KEEP_POSE:
            pb.matrix_basis.identity()
    bpy.context.view_layer.update()


def freeze(objs) -> None:
    """Hornea la T en los vertices: aplica el modificador de armadura y pasa la
    matriz de mundo al dato. NO se usa transform_apply: el objeto cuelga de la
    armadura, asi que su matriz LOCAL lleva la escala grande y la del padre la
    compensa; transform_apply hornearia la local y el modelo saldria x55.
    Las matrices se leen TODAS antes de tocar nada: aplicar un modificador deja
    el depsgraph sucio y la lectura posterior devuelve la matriz vieja."""
    bpy.context.view_layer.update()
    mats = {o.name: o.matrix_world.copy() for o in objs}
    for o in objs:
        bpy.context.view_layer.objects.active = o
        for m in list(o.modifiers):
            if m.type == "ARMATURE":
                bpy.ops.object.modifier_apply(modifier=m.name)
        o.data.transform(mats[o.name])
        o.parent = None
        o.matrix_world = Matrix.Identity(4)
        o.vertex_groups.clear()
    bpy.context.view_layer.update()


def measure_facing(arm) -> Vector:
    """Direccion a la que mira el soldado, en horizontal.

    El eje izquierda-derecha sale de las manos (fiable aunque los pies esten
    abiertos); el signo lo da la punta del pie. `lr x up` mira al frente."""
    lh = arm.matrix_world @ arm.pose.bones[HAND_L].head
    rh = arm.matrix_world @ arm.pose.bones[HAND_R].head
    lr = Vector((lh.x - rh.x, lh.y - rh.y, 0.0))
    if lr.length < 1e-6:
        raise SystemExit("build_soldier: las manos coinciden, no hay eje lateral")
    lr.normalize()
    fwd = Vector((lr.y, -lr.x, 0.0))
    pie = arm.matrix_world @ arm.pose.bones[FOOT_L].head
    toe = arm.matrix_world @ arm.pose.bones[TOE_L].head
    paso = Vector((toe.x - pie.x, toe.y - pie.y, 0.0))
    if paso.length > 1e-6 and fwd.dot(paso) < 0.0:
        fwd = -fwd
    return fwd


def yaw_to(target: Vector, fwd: Vector) -> float:
    """Giro en Z que lleva `fwd` a `target`."""
    a = math.atan2(fwd.y, fwd.x)
    b = math.atan2(target.y, target.x)
    return (b - a + math.pi) % (2.0 * math.pi) - math.pi


def load_rig(path: Path):
    bpy.ops.import_scene.gltf(filepath=str(path))
    scn = bpy.context.scene
    arm = next((o for o in scn.objects if o.type == "ARMATURE"), None)
    if arm is None:
        raise SystemExit("build_soldier: %s no trae armadura" % path)
    donor = next((o for o in scn.objects if o.type == "MESH"), None)
    if donor is None:
        raise SystemExit("build_soldier: %s no trae malla" % path)
    if arm.animation_data:
        arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.matrix_basis.identity()
    bpy.context.view_layer.update()
    faltan = [n for n in CONTRACT if n not in arm.pose.bones]
    if faltan:
        raise SystemExit("build_soldier: al rig le faltan huesos del contrato: %s"
                         % ", ".join(faltan))
    return arm, donor


def two_surfaces(objs) -> None:
    """Una sola malla con dos ranuras: 0 uniforme, 1 equipo."""
    uniform = bpy.data.materials.new("Enemy_Skin")
    uniform.diffuse_color = (0.35, 0.35, 0.31, 1.0)
    gear = bpy.data.materials.new("Enemy_Fabric")
    gear.diffuse_color = (0.10, 0.11, 0.13, 1.0)
    for o in objs:
        o.data.materials.clear()
        o.data.materials.append(uniform)
        o.data.materials.append(gear)
        idx = 1 if o.name in GEAR else 0
        for poly in o.data.polygons:
            poly.material_index = idx


CLIPS = ("Idle", "Walk", "Neck", "Aim", "Hit", "Death")


def keep_clips(arm) -> None:
    """El GLB solo debe llevar los seis clips del contrato: el soldado trae los
    suyos (Idle/jump/walk) y sin borrarlos viajarian al juego."""
    wanted = {a.name for a in bpy.data.actions
              if a.name in CLIPS or a.name in {"%s_%s" % (c, arm.name) for c in CLIPS}}
    for a in list(bpy.data.actions):
        if a.name not in wanted:
            bpy.data.actions.remove(a, do_unlink=True)
    if len(wanted) != len(CLIPS):
        raise SystemExit("build_soldier: se esperaban %d clips y hay %d: %s"
                         % (len(CLIPS), len(wanted), ", ".join(sorted(wanted))))
    print("build_soldier: clips exportados: %s" % ", ".join(sorted(wanted)))


def dist_to_bone(p: Vector, h: Vector, t: Vector) -> float:
    d = t - h
    if d.length_squared < 1e-12:
        return (p - h).length
    u = max(0.0, min(1.0, (p - h).dot(d) / d.length_squared))
    return (p - (h + d * u)).length


def animated_bones() -> set:
    """Huesos que algun clip MUEVE de verdad.

    No basta con que tengan curvas: `bake_action` mete claves de TODOS los
    huesos del rig, asi que los dedos `DEF-f_*` tienen curvas pero CONSTANTES en
    los seis clips. Si se dan por animados, la mano entera (738 vertices) se
    queda atada a un menique que no se mueve: se congela en la T mientras el
    antebrazo sigue, y el brazo se estira en un ala. Hay que mirar si la curva
    VARIA, no si existe."""
    s = set()
    for a in bpy.data.actions:
        for fc in a.fcurves:
            if not fc.data_path.startswith('pose.bones["'):
                continue
            vs = [k.co[1] for k in fc.keyframe_points]
            if vs and max(vs) - min(vs) > 1e-4:
                s.add(fc.data_path.split('"')[1])
    return s


def fill_unweighted(cuerpo, arm) -> None:
    """Todo vertice queda colgado de un hueso que los clips ANIMAN.

    El calor de hueso deja geometria suelta (el rifle, las fundas) en huesos que
    el rig arrastra de Rigify y que ningun clip toca: en el juego se quedan
    clavados en el aire mientras el cuerpo se mueve. No vale con exigir los
    nombres del contrato: los clips SI mueven los dedos `DEF-f_*`, y forzarlos a
    `Hand_L` dejaba las manos abiertas en T. El criterio es "lo anima algun
    clip"; a lo que no, se le da peso 1 al hueso del contrato mas cercano."""
    animados = animated_bones()
    huesos = [(b.name, b.head_local.copy(), b.tail_local.copy())
              for b in arm.data.bones if b.name in CONTRACT]
    if not huesos:
        raise SystemExit("build_soldier: la armadura no trae huesos del contrato")
    inv = arm.matrix_world.inverted()
    for nombre, _, _ in huesos:
        if nombre not in cuerpo.vertex_groups:
            cuerpo.vertex_groups.new(name=nombre)
    tocados = 0
    for v in cuerpo.data.vertices:
        dominante, peso = None, 0.0
        for g in v.groups:
            if g.weight > peso:
                peso, dominante = g.weight, cuerpo.vertex_groups[g.group].name
        if dominante in animados and peso > 1e-4:
            continue
        p = inv @ (cuerpo.matrix_world @ v.co)
        mejor, mejor_d = None, 1e9
        for nombre, h, t in huesos:
            d = dist_to_bone(p, h, t)
            if d < mejor_d:
                mejor_d, mejor = d, nombre
        for g in list(v.groups):
            cuerpo.vertex_groups[g.group].remove([v.index])
        cuerpo.vertex_groups[mejor].add([v.index], 1.0, "REPLACE")
        tocados += 1
    print("build_soldier: %d vertices colgados de un hueso que los clips mueven" % tocados)


def transfer_weights(cuerpo, donor, arm) -> None:
    """Copia los pesos del maniqui al soldado.

    El calor de hueso reparte mal un cuerpo con ropa encima: deja alas de tela
    estirada entre el hombro y el brazo. El maniqui ya viene pesado para ESTE
    esqueleto de fabrica, asi que se transfieren sus grupos por cara mas
    cercana, que es el metodo de Blender para esto, y encima solo se reata lo
    que quede cojo."""
    for g in donor.vertex_groups:
        if g.name not in cuerpo.vertex_groups:
            cuerpo.vertex_groups.new(name=g.name)
    mod = cuerpo.modifiers.new("Pesos", "DATA_TRANSFER")
    mod.object = donor
    mod.use_vert_data = True
    mod.data_types_verts = {"VGROUP_WEIGHTS"}
    mod.vert_mapping = "POLYINTERP_NEAREST"
    mod.layers_vgroup_select_src = "ALL"
    mod.layers_vgroup_select_dst = "NAME"
    bpy.context.view_layer.objects.active = cuerpo
    bpy.ops.object.modifier_apply(modifier=mod.name)
    con = sum(1 for v in cuerpo.data.vertices if v.groups)
    print("build_soldier: pesos copiados del maniqui a %d de %d vertices"
          % (con, len(cuerpo.data.vertices)))


def fix_feet(cuerpo, arm) -> None:
    """Ata cada bota a SU pie.

    La transferencia desde el maniqui busca la cara mas cercana, y como los pies
    del soldado no caen donde los del maniqui, acaba cruzandolos: el pie
    izquierdo se quedaba con 285 vertices y el derecho con 1036, y la bota se
    abria en falda. Aqui no se copia nada: se mide la distancia de cada vertice
    a los huesos de SU pierna y se reparte entre los dos mas cercanos, que da un
    tobillo continuo y cada bota en su lado.

    El lado se toma del hueso que ya domina el vertice, y solo si no hay ninguno
    (o es del tronco) del signo de su x. Elegir los dos huesos mas cercanos sin
    mirar el lado cruzaba las piernas: con las rodillas juntas, un vertice del
    gemelo izquierdo se quedaba a medias con Shin_R y al abrirse la pierna en
    Death esa arista se estiraba 37 veces."""
    animados = animated_bones()
    patas = [n for n in ("Shin_L", "Foot_L", "Toe_L", "Shin_R", "Foot_R", "Toe_R")
             if n in animados]
    if not patas:
        return
    segs = {n: (arm.data.bones[n].head_local.copy(), arm.data.bones[n].tail_local.copy())
            for n in patas}
    inv = arm.matrix_world.inverted()
    for n in patas:
        if n not in cuerpo.vertex_groups:
            cuerpo.vertex_groups.new(name=n)
    tocados = 0
    for v in cuerpo.data.vertices:
        p = inv @ (cuerpo.matrix_world @ v.co)
        if p.z > 0.34:
            continue
        lado = None
        if v.groups:
            dom = max(v.groups, key=lambda g: g.weight)
            nombre_dom = cuerpo.vertex_groups[dom.group].name
            if nombre_dom.endswith("_L"):
                lado = "_L"
            elif nombre_dom.endswith("_R"):
                lado = "_R"
        if lado is None:
            lado = "_L" if p.x > 0.0 else "_R"
        propias = [n for n in patas if n.endswith(lado)]
        if not propias:
            continue
        ds = sorted((dist_to_bone(p, *segs[n]), n) for n in propias)[:2]
        inv_d = [1.0 / (d + 1e-4) ** 3 for d, _ in ds]
        tot = sum(inv_d)
        for g in list(v.groups):
            cuerpo.vertex_groups[g.group].remove([v.index])
        for (d, n), w in zip(ds, inv_d):
            cuerpo.vertex_groups[n].add([v.index], w / tot, "REPLACE")
        tocados += 1
    print("build_soldier: %d vertices de bota atados a su propio pie" % tocados)


def stitch_loose(cuerpo, arm) -> None:
    """Reata cada pieza al hueso de la superficie donde se APOYA.

    El calor de hueso reparte la geometria suelta por cercania en el espacio: un
    tirante del chaleco acaba colgando del antebrazo porque en la T el antebrazo
    le pasa cerca, y al bajar el brazo el tirante se estira en un gancho y deja
    un agujero en la espalda. El hueso bueno no es el mas cercano a la pieza,
    sino el que manda en la superficie que la pieza toca: se busca el vertice
    ajeno mas proximo con un KD-tree y se copia su hueso. Se reata la pieza
    ENTERA a ese hueso, que es lo correcto para un objeto duro."""
    from mathutils import kdtree

    animados = animated_bones()
    huesos = [(b.name, b.head_local.copy(), b.tail_local.copy())
              for b in arm.data.bones if b.name in animados]
    if not huesos:
        return
    inv = arm.matrix_world.inverted()
    n = len(cuerpo.data.vertices)
    dom = [None] * n
    for v in cuerpo.data.vertices:
        mejor, peso = None, 0.0
        for g in v.groups:
            if g.weight > peso:
                peso, mejor = g.weight, cuerpo.vertex_groups[g.group].name
        dom[v.index] = mejor

    ady = {}
    for e in cuerpo.data.edges:
        a, b = e.vertices
        ady.setdefault(a, []).append(b)
        ady.setdefault(b, []).append(a)
    comp_de = [-1] * n
    comps = []
    for arranque in range(n):
        if comp_de[arranque] >= 0:
            continue
        pila, comp = [arranque], []
        comp_de[arranque] = len(comps)
        while pila:
            i = pila.pop()
            comp.append(i)
            for j in ady.get(i, ()):
                if comp_de[j] < 0:
                    comp_de[j] = len(comps)
                    pila.append(j)
        comps.append(comp)

    pos = [inv @ (cuerpo.matrix_world @ v.co) for v in cuerpo.data.vertices]
    kd = kdtree.KDTree(n)
    for i in range(n):
        kd.insert(pos[i], i)
    kd.balance()

    reatadas = 0
    for ci, comp in enumerate(comps):
        cent = Vector((sum(pos[i].x for i in comp) / len(comp),
                       sum(pos[i].y for i in comp) / len(comp),
                       sum(pos[i].z for i in comp) / len(comp)))
        votos = {}
        for i in comp:
            votos[dom[i]] = votos.get(dom[i], 0) + 1
        manda = max(votos, key=votos.get)
        hueso_manda = next((h for h in huesos if h[0] == manda), None)
        if hueso_manda is None:
            continue
        d_manda = dist_to_bone(cent, hueso_manda[1], hueso_manda[2])
        mejor, mejor_d = None, 1e9
        for nombre, h, t in huesos:
            d = dist_to_bone(cent, h, t)
            if d < mejor_d:
                mejor_d, mejor = d, nombre
        if d_manda <= 0.10 or d_manda <= 1.6 * max(mejor_d, 0.03):
            continue
        # hueso de la superficie que la pieza toca
        vecino = None
        for _, j, _ in kd.find_n(cent, 24):
            if comp_de[j] != ci and dom[j] in animados:
                vecino = dom[j]
                break
        if vecino is None or vecino == manda:
            continue
        for i in comp:
            for g in list(cuerpo.data.vertices[i].groups):
                cuerpo.vertex_groups[g.group].remove([i])
            cuerpo.vertex_groups[vecino].add([i], 1.0, "REPLACE")
        reatadas += 1
    print("build_soldier: %d piezas reatadas al hueso de su superficie" % reatadas)


def export(arm, out_path: Path) -> None:
    for img in bpy.data.images:
        if img.size[0] > MAX_TEX or img.size[1] > MAX_TEX:
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
    parser = argparse.ArgumentParser(description="FLOWFIRE soldier swap")
    parser.add_argument("--rig", default=str(RIG_SRC))
    parser.add_argument("--body", default=str(BODY_SRC))
    parser.add_argument("--out", default=str(OUT))
    args = parser.parse_args(argv)

    for etiqueta, ruta in (("rig", args.rig), ("cuerpo", args.body)):
        if not Path(ruta).exists():
            raise SystemExit(
                "build_soldier: falta el %s %s\n"
                "  el rig sale de:  blender -b --python tools/build_enemy.py -- "
                "--out downloads/models/enemy_rig.glb" % (etiqueta, ruta))

    scene_setup()
    arm, donor = load_rig(Path(args.rig))
    arm.name = "EnemyRig"
    arm.data.name = "EnemyRig"
    alto_rig = bbox([donor])[1].z - bbox([donor])[0].z
    hips_rig = arm.matrix_world @ arm.pose.bones["Hips"].head
    pies_rig = bbox([donor])[0].z
    print("build_soldier: rig %s  alto=%.3f  hips=(%.3f,%.3f)"
          % (arm.name, alto_rig, hips_rig.x, hips_rig.y))

    bpy.ops.import_scene.gltf(filepath=str(args.body))
    scn = bpy.context.scene
    sarm = next(o for o in scn.objects if o.type == "ARMATURE" and o is not arm)
    t_pose(sarm)
    for o in list(scn.objects):
        if o.type == "MESH" and o.name.startswith("Icosphere"):
            bpy.data.objects.remove(o, do_unlink=True)
    sold = [o for o in scn.objects if o.type == "MESH" and o is not donor]
    if not sold:
        raise SystemExit("build_soldier: el cuerpo no trae malla")
    fwd = measure_facing(sarm)
    freeze(sold)
    bpy.data.objects.remove(sarm, do_unlink=True)

    # --- alinear: girar, escalar y apoyar los pies donde el rig ---------------
    giro = Matrix.Rotation(yaw_to(Vector((0.0, -1.0, 0.0)), fwd), 4, "Z")
    for o in sold:
        o.data.transform(giro)
    mn, mx = bbox(sold)
    escala = alto_rig / (mx.z - mn.z)
    for o in sold:
        o.data.transform(Matrix.Scale(escala, 4))
    mn, mx = bbox(sold)
    # el centro de masas horizontal de la pelvis manda: los pies pueden estar
    # abiertos y el pelo del casco sobresalir, y eso descentraria el modelo.
    xs = [v.co.x for o in sold for v in o.data.vertices if mn.z + 0.55 * (mx.z - mn.z) < v.co.z < mn.z + 0.62 * (mx.z - mn.z)]
    ys = [v.co.y for o in sold for v in o.data.vertices if mn.z + 0.55 * (mx.z - mn.z) < v.co.z < mn.z + 0.62 * (mx.z - mn.z)]
    cx = sum(xs) / len(xs) if xs else (mn.x + mx.x) / 2.0
    cy = sum(ys) / len(ys) if ys else (mn.y + mx.y) / 2.0
    desplaz = Vector((hips_rig.x - cx, hips_rig.y - cy, pies_rig - mn.z))
    for o in sold:
        o.data.transform(Matrix.Translation(desplaz))
    mn, mx = bbox(sold)
    print("build_soldier: giro=%.1f deg  escala=%.4f  alto=%.3f  x=[%+.2f,%+.2f] y=[%+.2f,%+.2f]"
          % (math.degrees(yaw_to(Vector((0.0, -1.0, 0.0)), fwd)), escala, mx.z - mn.z,
             mn.x, mx.x, mn.y, mx.y))

    # --- una malla, dos superficies ------------------------------------------
    two_surfaces(sold)
    bpy.ops.object.select_all(action="DESELECT")
    for o in sold:
        o.select_set(True)
    bpy.context.view_layer.objects.active = sold[0]
    if len(sold) > 1:
        bpy.ops.object.join()
    cuerpo = bpy.context.view_layer.objects.active
    cuerpo.name = "Enemy_Mesh"
    cuerpo.data.name = "Enemy_Mesh"
    tris = sum(len(p.vertices) - 2 for p in cuerpo.data.polygons)
    print("build_soldier: malla %s tris=%d superficies=%d"
          % (cuerpo.name, tris, len(cuerpo.data.materials)))

    # --- piel ----------------------------------------------------------------
    bpy.ops.object.select_all(action="DESELECT")
    cuerpo.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_NAME")
    transfer_weights(cuerpo, donor, arm)
    bpy.data.objects.remove(donor, do_unlink=True)
    pesos = {}
    for v in cuerpo.data.vertices:
        for g in v.groups:
            if g.weight > 1e-4:
                pesos[cuerpo.vertex_groups[g.group].name] = pesos.get(
                    cuerpo.vertex_groups[g.group].name, 0) + 1
    vacios = [n for n in CONTRACT if pesos.get(n, 0) == 0]
    print("build_soldier: huesos con peso=%d de %d del contrato"
          % (len([n for n in CONTRACT if pesos.get(n, 0)]), len(CONTRACT)))
    if vacios:
        print("build_soldier: AVISO sin pesos -> %s" % ", ".join(vacios))
    sin_peso = sum(1 for v in cuerpo.data.vertices if not v.groups)
    print("build_soldier: vertices sin ningun peso=%d de %d"
          % (sin_peso, len(cuerpo.data.vertices)))
    fill_unweighted(cuerpo, arm)
    fix_feet(cuerpo, arm)
    stitch_loose(cuerpo, arm)

    keep_clips(arm)
    export(arm, Path(args.out))


if __name__ == "__main__":
    main()
