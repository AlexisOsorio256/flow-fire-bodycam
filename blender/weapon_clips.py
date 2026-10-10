from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parent.parent
BLEND = ROOT / "blender" / "fparms.blend"
MODELOS = ROOT / "assets" / "models"
MONTAJE = Vector((-0.004, -0.0805, -0.0326))
PISTOLA = ["Idle", "Aim", "Fire", "Reload", "ReloadEmpty", "Inspect", "Equip", "Trigger"]
FUSIL = ["Rifle" + nombre for nombre in PISTOLA]
ARMAS = [
    {"prefijo": "Deagle", "glb": "desert_eagle.glb", "fuente": PISTOLA},
    {"prefijo": "Barrett", "glb": "barrett.glb", "fuente": FUSIL},
]


def clips(arma):
    hechos = 0
    for nombre in arma["fuente"]:
        origen = bpy.data.actions.get(nombre)
        if origen is None:
            print("FALTA la accion", nombre)
            continue
        sufijo = nombre.replace("Rifle", "")
        copia = origen.copy()
        copia.name = arma["prefijo"] + sufijo
        copia.use_fake_user = True
        hechos += 1
    return hechos


def main():
    bpy.ops.wm.open_mainfile(filepath=str(BLEND))
    for arma in ARMAS:
        if bpy.data.actions.get(arma["prefijo"] + "Idle") is not None:
            print(arma["prefijo"], "ya tenia clips")
            continue
        print(arma["prefijo"], clips(arma), "clips")
        raiz = bpy.data.objects.new(arma["prefijo"] + "Root", None)
        bpy.context.scene.collection.objects.link(raiz)
        raiz.parent = bpy.data.objects["ArmsRig"]
        raiz.location = MONTAJE
        montaje = bpy.data.objects.new(arma["prefijo"] + "Mount", None)
        bpy.context.scene.collection.objects.link(montaje)
        montaje.parent = bpy.data.objects["ArmsRig"]
        montaje.location = MONTAJE
        antes = set(bpy.data.objects.keys())
        bpy.ops.import_scene.gltf(filepath=str(MODELOS / arma["glb"]))
        nuevos = [ob for ob in bpy.data.objects if ob.name not in antes]
        for ob in nuevos:
            ob.name = arma["prefijo"] + "_" + ob.name
            ob.hide_render = True
            if ob.parent is None:
                ob.parent = raiz
                ob.location = Vector((0.0, 0.0, 0.0))
        print("  vista previa:", len(nuevos), "objetos")
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND), compress=True)
    print("GUARDADO", BLEND.name)


main()
