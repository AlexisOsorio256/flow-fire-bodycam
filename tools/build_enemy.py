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
NO inventa animacion, y el EQUIPO (casco, chaleco, porta-cargadores, mochila y
rifle acordonado) tampoco sale de ningun donante: son ocho primitivas propias
horneadas a la malla y pesadas a huesos del rig (ver `build_gear`). El
DONANTE solo aporta el cuerpo humano; todo lo que viste encima lo construye
este script.
La fuente trae 48 huesos, malla de 1578 tris y nueve
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
from mathutils import Matrix, Quaternion, Vector

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "assets" / "models" / "enemy.glb"
DEFAULT_FBX = REPO / "downloads" / "models" / "quaternius_animated_human" / "Animated Human.fbx"
MAX_TEX = 1024
FPS = 24

# Hueso de la fuente -> nombre que pide `Enemy._bone_share`. El reparto de masa
# del ragdoll se decide por estos nombres; sin el renombrado, todos los huesos
# caerian en la rama por defecto (0,01) y un torso pesaria como un dedo.
## CONTRATO DE HUESOS. `Enemy.gd` reparte los 78 kg del ragdoll por estos
## nombres (`_bone_share`) y lee las tres zonas de impacto por ellos. Cambiarlos
## no es cosmetico: un hueso que no resuelva cae en la rama por defecto (0,01) y
## un torso pesaria como un dedo.
##
## LA TABLA ES UNA NORMALIZACION, NO UN DICCIONARIO DEL DONANTE. Cualquier rig
## humanoide escribe los mismos huesos de otra forma ("mixamorig:LeftArm",
## "LeftArm", "arm.L", "upperarm_l"...). Aqui se limpia el nombre (prefijos de
## Mixamo, separadores, mayusculas) y se busca por forma canonica, con las dos
## convenciones vivas ya dentro: Quaternius (LeftArm/LeftUpLeg/LeftLeg) y Mixamo
## (LeftArm/LeftUpLeg/LeftLeg con prefijo). Un hueso que no aparezca en la tabla
## se queda como esta: la deteccion lo delata antes de exportar.
CONTRACT_BONES = [
    "Hips", "Spine", "Chest", "Chest.001", "Neck", "Head",
    "Shoulder_L", "UpperArm_L", "ForeArm_L", "Hand_L",
    "Shoulder_R", "UpperArm_R", "ForeArm_R", "Hand_R",
    "Thigh_L", "Shin_L", "Foot_L", "Toe_L",
    "Thigh_R", "Shin_R", "Foot_R", "Toe_R",
]

## Forma canonica -> nombres de hueso del huesped, ya normalizados.
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
}


def canonical(name: str) -> str:
    """Nombre de hueso -> forma canonica de busqueda."""
    n = name.split(":")[-1]          # mixamorig:LeftArm -> LeftArm
    n = n.replace("_", "").replace(".", "").replace("-", "").replace(" ", "")
    return n.lower()


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
    """Renombra los huesos del huesped al contrato de `Enemy.gd`.

    DOS PASADAS: un nombre destino puede coincidir con un nombre origen que aun
    no se ha leido. Y comprobacion EXPLICITA de los huesos que `Enemy.gd` usa de
    verdad (los de `_bone_share` y `HEAD_BONES`/`LEG_BONES`/`TORSO_BONES`): si
    falta uno, se dice AQUI y no en el ragdoll, con la lista de lo que si trae.
    """
    pending = {}
    for b in arm.data.bones:
        target = BONE_ALIASES.get(canonical(b.name))
        if target and target != b.name:
            pending[b.name] = target
    for old, new in pending.items():
        arm.data.bones[old].name = new
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


# ---------------------------------------------------------------------------
# FULL EQUIPO (via 2). Buscada la via 1 sin resultado en su presupuesto de
# tiempo: no hay humano MODERNO CC0 con equipo, esqueleto >=47 y clips
# (erik90mx/OpenGameArt es un mesh estatico de 2011 sin animacion;
# military_character_kit no trae clips; KayKit y Quaternius animados son
#fantasia con rigs cortos). El casco, el chaleco, la mochila y el rifle
# acordonado se construyen aqui como primitivas rigidas ancladas a huesos del
# rig actual --viajan DENTRO de la malla del cuerpo (un vertex group de peso 1
# por pieza), o sea mismo material pixelado, mismo skin, y el ragdoll se los
# lleva porque siguen a Head/Chest.001. Cada pieza <800 tris por construccion
# (esferas de 14x8 y cajas); anaden ~450 al cuerpo.
# ---------------------------------------------------------------------------


def build_gear(arm, mesh) -> None:
    bones = {b.name: b for b in arm.data.bones}
    wm = arm.matrix_world

    def hp(name: str):
        return wm @ bones[name].head_local

    def tp(name: str):
        return wm @ bones[name].tail_local

    # Orientacion: el FBX importa el personaje mirando a -Y (verificado en la
    # captura `look`: mochila atras, chaleco delante).
    front = Vector((0.0, -1.0, 0.0))
    up = Vector((0.0, 0.0, 1.0))

    # Cotas leidas del propio rig: ni un numero hardcodeado al tamano del
    # donante (el mismo error de escala que dejo al gigante de 4,41 m).
    chest_lo, chest_hi = hp("Chest"), tp("Chest.001")
    chest_mid = (chest_lo + chest_hi) * 0.5
    chest_h = (chest_hi - chest_lo).length
    span = (hp("Shoulder_R") - hp("Shoulder_L")).length
    head_top = tp("Head")
    ## ALTO REAL DEL RIG. Todo el equipo se cotiza contra ESTO y no contra la
    ## longitud del hueso `Head`, que es lo que se hacia antes y es el defecto
    ## que el dueno vio como "los enemigos estan gigantes".
    ##
    ## MEDIDO sobre el donante Quaternius: su hueso Head mide 0,35 m, o sea el
    ## 21 % del cuerpo (una cabeza humana es el 13 %). Con `skull` como unidad,
    ## el casco salia de 0,74 m de ancho — el doble que unas espaldas — y su
    ## cima quedaba 0,42 m por encima del craneo: silueta de 2,4 m con una seta
    ## por cabeza. Las dos unidades de abajo salen de una regla antropometrica
    ## (cabeza = 0,135 del alto; hombros = 0,245) acotada por lo que mide el
    ## hueso, para que un rig con el Head corto tampoco encoja el casco.
    rig_h = (head_top - hp("Foot_L")).length
    if rig_h < 0.5:
        rig_h = (head_top - tp("Foot_L")).length
    cabeza = min((tp("Head") - hp("Head")).length, rig_h * 0.145)
    cabeza = max(cabeza, rig_h * 0.115)

    pieces = []

    # DOS materiales: piel (slot 0, cuerpo) y tela (slot 1, equipo). El join los
    # conserva como slots separados y Godot importa los dos para sobrescribirlos
    # con las texturas CC0 reales en runtime.
    skin_mat = bpy.data.materials.new("Enemy_Skin")
    skin_mat.diffuse_color = (0.35, 0.25, 0.20, 1.0)
    fabric_mat = bpy.data.materials.new("Enemy_Fabric")
    fabric_mat.diffuse_color = (0.10, 0.11, 0.13, 1.0)
    mesh.data.materials.clear()
    mesh.data.materials.append(skin_mat)

    def piece(obj, bone: str):
        vg = obj.vertex_groups.new(name=bone)
        vg.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
        mod = obj.modifiers.new("Armature", "ARMATURE")
        mod.object = arm
        obj.data.materials.append(fabric_mat)
        pieces.append(obj)

    # --- Casco: casquete achatado sobre la boveda + ala corta, al Head.
    # Un casco de combate mide 0,28 x 0,24 x 0,30 m para una cabeza de 0,23.
    bpy.ops.mesh.primitive_uv_sphere_add(segments=14, ring_count=8,
                                         radius=cabeza * 0.62,
                                         location=head_top + up * cabeza * 0.10)
    helm = bpy.context.active_object
    helm.name = "Gear_Helmet"
    helm.scale = (1.10, 1.18, 0.86)
    piece(helm, "Head")

    bpy.ops.mesh.primitive_cylinder_add(vertices=14, radius=cabeza * 0.70,
                                        depth=cabeza * 0.13,
                                        location=head_top - up * cabeza * 0.28)
    brim = bpy.context.active_object
    brim.name = "Gear_HelmetBrim"
    brim.scale = (1.06, 1.12, 1.0)
    piece(brim, "Head")

    # --- Guantes y botas: se cotizan contra el ALTO del rig, no contra la
    #     cabeza, para que un rig con el hueso Head largo no los infle.

    # --- Chaleco: caja que envuelve el torso + dos porta-cargadores delante.
    vest_c = (chest_mid + chest_lo) * 0.5
    bpy.ops.mesh.primitive_cube_add(size=1, location=vest_c)
    vest = bpy.context.active_object
    vest.name = "Gear_Vest"
    vest.scale = (span * 0.86, chest_h * 0.66, chest_h * 1.02)
    piece(vest, "Chest.001")

    # Porta-cargadores LATERALES (ref3: bolsas en los costados del chaleco, no
    # delante): dos a cada lado, a la altura de la cintura.
    for i, mag_x in enumerate((-0.30, 0.30)):
        bpy.ops.mesh.primitive_cube_add(size=1,
            location=vest_c + Vector((span * mag_x, 0.0, -chest_h * 0.22)))
        mag = bpy.context.active_object
        mag.name = "Gear_Mag%d" % i
        mag.scale = (rig_h * 0.038, rig_h * 0.048, rig_h * 0.085)
        piece(mag, "Chest.001")

    # --- Butt pack: mochila BAJA sobre el cinturon (ref3: pack pequeno en la
    # espalda baja, no una caja al pecho alto).
    bpy.ops.mesh.primitive_cube_add(size=1,
        location=chest_mid - front * chest_h * 0.44 + up * chest_h * 0.30)
    pack = bpy.context.active_object
    pack.name = "Gear_Pack"
    pack.scale = (span * 0.52, chest_h * 0.26, rig_h * 0.13)
    piece(pack, "Chest.001")

    # --- Rifle acordonado COLGANDO del hombro derecho hacia abajo (ref3: el
    # rifle cuelga a un costado, canon hacia abajo, no cruzado sobre el pecho).
    # Inmune a la animacion de brazos: pesa al Chest.001, no a las manos.
    #
    # COTIZADO CONTRA EL ALTO DEL RIG. Antes media `chest_h * 1.05` = 0,26 m: un
    # carabina de 26 cm, o sea una pistola. En la captura `look` se leia como un
    # muñon en la mano, y es la mitad de por que el enemigo parecia un espantapajaros.
    # Un fusil de asalto mide 0,85 m = 0,47 del alto de un hombre.
    dirv = (up * -0.92 + front * 0.22).normalized()
    rcen = chest_mid + Vector((span * 0.42, 0.0, chest_h * 0.05)) + front * chest_h * 0.20
    quat = dirv.to_track_quat("Z", "Y")
    rifle_l = rig_h * 0.47
    for j, (ln, off) in enumerate(((rifle_l * 0.62, rifle_l * 0.16),      # cuerpo
                                   (rifle_l * 0.30, -rifle_l * 0.30),     # canon
                                   (rifle_l * 0.16, -rifle_l * 0.18))):   # cargador
        bpy.ops.mesh.primitive_cube_add(size=1, location=rcen + dirv * off)
        rb = bpy.context.active_object
        rb.name = "Gear_Rifle%d" % j
        rb.rotation_euler = quat.to_euler()
        if j == 1:
            rb.scale = (chest_h * 0.07, chest_h * 0.09, ln)
        elif j == 2:
            rb.scale = (chest_h * 0.10, chest_h * 0.24, ln)
        else:
            rb.scale = (chest_h * 0.13, chest_h * 0.20, ln)
        piece(rb, "Chest.001")

    # --- Guantes: esferas achatadas sobre las manos (ref3: guantes tactiles).
    for side in ("L", "R"):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6,
            radius=rig_h * 0.042, location=hp("Hand_" + side))
        glove = bpy.context.active_object
        glove.name = "Gear_Glove_" + side
        glove.scale = (0.9, 0.9, 1.25)
        piece(glove, "Hand_" + side)

    # --- Botas: cajas sobre los pies (ref3: botas tacticas, no pies pelados).
    for side in ("L", "R"):
        bpy.ops.mesh.primitive_cube_add(size=1,
            location=tp("Foot_" + side) + front * chest_h * 0.04)
        boot = bpy.context.active_object
        boot.name = "Gear_Boot_" + side
        boot.scale = (rig_h * 0.062, rig_h * 0.115, rig_h * 0.085)
        piece(boot, "Foot_" + side)

    # Un solo cuerpo: las piezas se hornean a la malla del personaje (join
    # respeta el mundo: el mesh viaja con la escala del armature sin sorpresas).
    bpy.ops.object.select_all(action="DESELECT")
    for obj in pieces:
        obj.select_set(True)
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = mesh
    bpy.ops.object.join()


## ACCION POR FORMA, no por el nombre exacto del donante. El Quaternius las
## llama "Human Armature|Human Armature|Idle"; un Mixamo, "mixamorig:Idle"; un
## GLB de Sketchfab, "Armature|Idle" o "Idle". Buscar el nombre literal ataba
## este builder a UN fichero, que es justo lo que impide cambiar de soldado.
def find_action(wanted: str):
    want = wanted.split("|")[-1].strip().lower()
    exact = [a for a in bpy.data.actions if a.name.split("|")[-1].strip().lower() == want]
    if exact:
        return exact[0]
    loose = [a for a in bpy.data.actions if want in a.name.lower()]
    if not loose:
        raise SystemExit("build_enemy: no hay accion '%s' en el huesped; trae: %s"
                         % (wanted, ", ".join(a.name for a in bpy.data.actions)))
    return sorted(loose, key=lambda a: len(a.name))[0]


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
    rename_bones(arm)
    if not args.no_gear:
        build_gear(arm, mesh)
    else:
        ## FUENTE QUE YA TRAE EQUIPO (casco, chaleco, rifle modelados por el
        ## autor). Volver a hornear primitivas encima seria duplicar el equipo y
        ## sumar 450 tris a un modelo que ya pesa 11k.
        print("build_enemy: sin equipo horneado (--no-gear): el huesped ya lo trae")
    print("huesos=%d tris=%d (cuerpo+equipo)" % (len(arm.data.bones),
                                  sum(len(p.vertices) - 2 for p in mesh.data.polygons)))

    idle = find_action(args.idle or "Idle")
    walk = find_action(args.walk or "Walk")
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
