#!/usr/bin/env python3
"""build_enemy.py -- construye `assets/models/enemy.glb` desde un cuerpo humanoide.

QUE ES
------
La autoridad de la CADENA del enemigo: importa un cuerpo, normaliza su rig al
contrato de `Enemy.gd`, hornea los tres clips que el juego pide (`Idle`, `Walk`,
`Neck`), lo viste con `build_kit.py` y exporta. NO decide como es el equipo: eso
es de `build_kit.py`.

FUENTE (CC0 1.0, dominio publico, sin credito obligatorio):
  "Universal Animation Library" de Quaternius.
  https://store.godotengine.org/asset/quaternius/universal-animation-library/
  Author: Quaternius. Licencia: CC0 1.0 Universal.
  Se descarga como zip del Godot Asset Store (14,5 MB) y se deja en
  `downloads/models/quaternius_animation_library/` (fuera del arbol activo,
  `.gitignore`); este builder y `build_kit.py` son lo unico que se versiona.

  Trae 53 huesos y 46 clips en la libreria de origen (Idle_Loop, Walk_Loop,
  Death01, Hit_Chest, Pistol_Aim_*, Pistol_Shoot...). Del cuerpo solo se
  conservan TRES (Idle, Walk, Neck): son los tres que pide `Enemy.gd`, y cada
  clip extra que viaja al glb se paga en el asset y en el import. El mannequin
  desnudo mide 16.419 tris ya vestido por `build_kit`, no 13.744: ese numero era
  del cuerpo donante sin equipo.

POR QUE ESTE CUERPO Y NO UN SOLDADO VESTIDO
-------------------------------------------
MEDIDO, y es la conclusion de dos busquedas: no existe un soldado realista
COMPLETO, riggeado, con animaciones y licencia limpia en fuentes gratuitas. Lo
gratis se reparte en tres cubos incompatibles: realista pero con licencia que
PROHIBE el uso en un juego de armas (Sketchfab "Standard"), licencia limpia pero
low-poly (Quaternius clasico, Kenney, OpenGameArt) o descargable pero sin
animaciones y con rig de nombres desconocidos.

Lo que SI existe con CC0 y sin cuenta es este par de Quaternius: un cuerpo
humanoide con un rig estandar y una libreria de 46 animaciones profesionales. El equipo lo pone `build_kit.py`, y el equipo es lo que define la
silueta (ver la cabecera de ese fichero). El cuerpo solo tiene que ser humano y
proporcionado; la cara no se ve, y la referencia de ref5 la tiene PIXELADA.

CAMBIAR DE CUERPO es un comando: `--fbx <ruta>` con cualquier humanoide cuyo rig
resuelva el contrato. La comprobacion de huesos falla ANTES de exportar y dice
que falta.
"""

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

## `build_kit.py` vive al lado y es su propia autoridad sobre el equipo.
## Blender no anade el directorio del script a `sys.path`, asi que se hace aqui
## y explicito.
sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_kit import build_kit  # noqa: E402

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "assets" / "models" / "enemy.glb"
##
## Descomprimir en `downloads/models/quaternius_animation_library/`, o pasar
## `--fbx <ruta>` y el builder hace el resto.
DEFAULT_FBX = (REPO / "downloads" / "models" / "quaternius_animation_library"
               / "AnimationLibrary_Godot_Standard.glb")
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
    ## RIGIFY ("DEF-hips", "DEF-spine.001", "DEF-upper_arm.L"): es el rig de la
    ## Universal Animation Library de Quaternius, y el de media biblioteca de
    ## Blender. `canonical()` ya quita los guiones y los puntos, asi que aqui
    ## solo hay que dar la forma resultante.
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
    """Nombre de hueso -> forma canonica de busqueda.

    Quita los separadores y, ADEMAS, quita el prefijo `DEF-` de Rigify: ese
    prefijo lo llevan los 53 huesos de la Universal Animation Library y sin
    quitarlo habria que escribir dos alias por hueso.
    """
    n = name.split(":")[-1]          # mixamorig:LeftArm -> LeftArm
    n = n.replace("_", "").replace(".", "").replace("-", "").replace(" ", "")
    n = n.lower()
    if n.startswith("def") and n[3:] in BONE_ALIASES:
        n = n[3:]
    return n


def scene_setup() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS
    bpy.context.scene.render.fps_base = 1.0


## RETARGET DEL GLB: se renombran los NODOS dentro del JSON y se importa el
## fichero parcheado. Es la forma ROBUSTA de traducir el rig y no un capricho:
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
    """Importa FBX o glTF y devuelve (armadura, malla DEL CUERPO).

    UNA sola malla y no "la primera": el paquete de Quaternius trae un
    `Icosphere` suelto (80 tris, cero vertex groups) que es un accesorio de la
    escena de origen. La malla del cuerpo es la que tiene MAS de 1000 tris y
    grupos de vertice que casan con los huesos de la armadura.
    """
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
    ## Fuera todo lo demas (accesorios, camaras, luces del pack): el GLB del
    ## juego lleva UN cuerpo y su equipo, no la escena del donante.
    for o in list(bpy.context.scene.objects):
        if o not in (arm, best):
            bpy.data.objects.remove(o, do_unlink=True)
    print("build_enemy: cuerpo %s  tris=%d  huesos=%d"
          % (best.name, best_tris, len(arm.data.bones)))
    return arm, best


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
    ## LAS CURVAS DE ANIMACION TAMBIEN SE RENOMBRAN, y esto es un fallo que
    ## estaba latente: una F-curve guarda la ruta `pose.bones["<nombre>"]`, asi
    ## que al renombrar un hueso su animacion se queda HUERFANA y el hueso
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
    """Deja la accion pedida activa y borra las demas: el GLB solo exporta la
    accion activa por hueso, y nueve clips de un donante no son del juego."""
    act = bpy.data.actions[action_name]
    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = act
    return act


def bake_action(arm, source_action, name: str, start: int = 0, end: int = -1,
                pose_fn=None) -> None:
    """Hornera [start, end] de una accion en una accion nueva de 1..N frames.

    `pose_fn(arm, frame)` se llama ANTES de leer la matriz de la fuente y puede
    reescribir la pose (lo usa el clip de cuello). Se hornea por MUESTREO: la
    interpolacion de la fuente (curvas Bezier del FBX) no viaja al glTF."""
    if end < start:
        start = int(math.floor(source_action.frame_range[0]))
        end = int(math.ceil(source_action.frame_range[1]))
    ##
    ## Y EL ORDEN DE ESTAS CUATRO LINEAS ES EL FALLO DE MEDIA NOCHE: `order` se
    ## capturaba ANTES de `animation_data_create()`, y crear el `animation_data`
    ## de una armadura RECONSTRUYE su pose — las referencias a `PoseBone`
    ## guardadas antes quedan muertas y devuelven SIEMPRE la matriz identidad.
    ## Sintoma: un clip de 61 claves TODAS iguales (el enemigo en cruz) sin un
    ## solo error en el log. Primero el `animation_data`, despues la accion, y
    ## la lista de huesos AL FINAL.
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


# ---------------------------------------------------------------------------
# Clip NECK. La fuente no tiene reaccion de cuello: se compone de dos poses del
# propio Idle para que el gesto siga siendo del mismo rig y la misma malla.
# ---------------------------------------------------------------------------
NECK_HEAD_YAW = math.radians(72.0)
NECK_HEAD_PITCH = math.radians(-14.0)
NECK_TWIST = math.radians(16.0)


def build_neck_clip(arm, idle_action) -> None:
    """Un fotograma compuesto sobre el PRIMERO del propio Idle (ver el cuerpo)."""
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
# EL EQUIPO lo pone `build_kit.py`, que es su propia autoridad: cualquier
# cuerpo que resuelva el contrato se viste con el. Aqui solo se le pasa la
# malla, la armadura y los dos materiales que `Enemy.gd` conoce.
# ---------------------------------------------------------------------------


## ACCION POR FORMA, no por el nombre exacto del donante. El fichero de
## Quaternius las llama "Idle_Loop_Rig"; un Mixamo, "mixamorig:Idle"; un GLB de
## Sketchfab, "Armature|Idle". Buscar el nombre literal ataba este builder a UN
## fichero, que es justo lo que impide cambiar de soldado.
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
    ## El nombre MAS CORTO que contiene lo pedido: entre "Idle_Loop_Rig" y
    ## "Crouch_Idle_Loop_Rig", el primero es el que se quiere.
    return sorted(loose, key=lambda a: len(a.name))[0]


## COMPROBACION DEL CLIP: un clip horneado que NO VARIA es una pose congelada,
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
    ## En la via GLB el rig YA viene traducido (`retarget_glb`, en el JSON y
    ## antes de importar). En FBX no se puede parchear el fichero, asi que se
    ## renombra despues — y si eso deja las acciones huerfanas, `assert_clip_varies`
    ## lo dice en vez de exportar un enemigo en cruz.
    if fbx.suffix.lower() not in (".glb", ".gltf"):
        rename_bones(arm)

    ## DOS MATERIALES, y los pone este script aunque el donante traiga los
    ## suyos: `Enemy.gd` pinta el slot 0 (uniforme) y el 1 (equipo), y el
    ## contrato no puede depender de como los llame el fichero de origen. Si el
    ## cuerpo trae una segunda superficie (las bandas de articulacion del
    ## maniqui), va al slot 1: asi leen a codera y rodillera en vez de a plastico.
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
    if not args.no_gear:
        pieces = build_kit(arm, mesh, skin_mat, gear_mat)
    else:
        ## FUENTE QUE YA TRAE EQUIPO (casco, chaleco, rifle modelados por el
        ## autor): volver a hornear primitivas encima duplicaria el equipo.
        print("build_enemy: sin equipo horneado (--no-gear): el huesped ya lo trae")
    print("huesos=%d tris=%d (cuerpo + %d piezas de equipo)"
          % (len(arm.data.bones),
             sum(len(p.vertices) - 2 for p in mesh.data.polygons), pieces))

    ## LOS CLIPS, POR FORMA: el fichero los llama "Idle_Loop_Rig" y
    ## "Walk_Loop_Rig"; un Mixamo, "mixamorig:Idle". El contrato de `Enemy.gd`
    ## solo entiende "Idle", "Walk" y "Neck", y el horneado es quien traduce.
    idle = find_action(args.idle or "Idle_Loop")
    walk = find_action(args.walk or "Walk_Loop")
    bake_action(arm, idle, "Idle")
    bake_action(arm, walk, "Walk")
    build_neck_clip(arm, idle)
    ## El Neck es UNA pose a proposito (no varia): no pasa por la comprobacion.
    assert_clip_varies(bpy.data.actions["Idle"], "Idle")
    assert_clip_varies(bpy.data.actions["Walk"], "Walk")
    keep_action(arm, "Idle")   # el GLB exporta la activa; las demas quedan por accion
    for a in list(bpy.data.actions):
        if a.name not in ("Idle", "Walk", "Neck"):
            bpy.data.actions.remove(a, do_unlink=True)
    export(arm, Path(args.out))


if __name__ == "__main__":
    main()
