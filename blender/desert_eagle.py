import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

ROOT = Path(r"C:\Users\josea\Documents\flow-fire-bodycam")
ORIGEN = Path.home() / ".cache" / "flowfire" / "modelos" / "de_gris13k.glb"
SALIDA = ROOT / "blender" / "desert_eagle.blend"
LARGO = 0.273
WEB_GLOCK = Vector((0.0041, 0.0168, -0.031))

EN_FRAME = ["Frame", "Grip", "Hammer", "BackPart", "Button_01", "Button_02", "Button_03",
            "SideSwitch", "SideSwitchHolder", "GripBolt", "SlideHolder", "BulletThrow", "Barrel", "FrontSight"]
EN_SLIDE = ["Slide", "SlidePart", "BoltMain", "BoltAdd", "BoltBack", "BoltButton", "RearSight", "Safety"]
EN_TRIGGER = ["Trigger"]
EN_MAG = ["Magazine", "MagazineBase", "BaseInside"]
FUERA = ["Bullet", "BulletCase"]


def caja(objetos):
    puntos = [ob.matrix_world @ Vector(e) for ob in objetos for e in ob.bound_box]
    return (Vector((min(p.x for p in puntos), min(p.y for p in puntos), min(p.z for p in puntos))),
            Vector((max(p.x for p in puntos), max(p.y for p in puntos), max(p.z for p in puntos))))


def malla(nombre):
    for ob in bpy.data.objects:
        if ob.type == "MESH" and ob.name.split("_low")[0] == nombre:
            return ob
    return None


def main():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    bpy.ops.import_scene.gltf(filepath=str(ORIGEN))
    mallas = [ob for ob in bpy.data.objects if ob.type == "MESH"]
    for ob in mallas:
        ob.parent = None
        ob.matrix_world = Matrix.Rotation(math.pi, 4, "Z") @ ob.matrix_world
    bajo, alto = caja(mallas)
    factor = LARGO / (alto.y - bajo.y)
    for ob in mallas:
        ob.matrix_world = Matrix.Scale(factor, 4) @ ob.matrix_world
    barril = caja([malla("Barrel")])
    agArre = caja([malla("Grip")])
    bore = (barril[0].z + barril[1].z) * 0.5
    web = Vector((0.0, agArre[0].y + 0.25 * (agArre[1].y - agArre[0].y), agArre[1].z))
    origen = web - WEB_GLOCK
    for ob in mallas:
        ob.matrix_world = Matrix.Translation(-origen) @ ob.matrix_world
    bajo, alto = caja(mallas)
    print("caja final: %.3f..%.3f (Y)  %.3f..%.3f (Z)  %.3f..%.3f (X)" % (
        bajo.y, alto.y, bajo.z, alto.z, bajo.x, alto.x))
    piezas = {nombre: caja([malla(clave)]) for nombre, claves in
              [("Barrel", ["Barrel"]), ("Slide", ["Slide"]), ("Grip", ["Grip"]),
               ("RearSight", ["RearSight"]), ("FrontSight", ["FrontSight"]), ("Trigger", ["Trigger"])]
              for clave in claves[:1] if malla(clave) is not None}
    pista = piezas["Barrel"]
    boquilla = Vector((0.0, pista[1].y, (pista[0].z + pista[1].z) * 0.5))
    alza = piezas["RearSight"]
    punto = piezas["FrontSight"]
    corredera = piezas["Slide"]
    print("SOCKETS (Godot):")
    print('  "Muzzle": Vector3(%.4f, %.4f, %.4f),' % (0.0, boquilla.z, -boquilla.y))
    print('  "EjectionPort": Vector3(%.4f, %.4f, %.4f),' % (corredera[1].x - 0.002,
          (corredera[0].z + corredera[1].z) * 0.5, (corredera[0].y + corredera[1].y) * 0.5))
    print('  "SightRear": Vector3(%.4f, %.4f, %.4f),' % (0.0, alza[1].z, -(alza[0].y + alza[1].y) * 0.5))
    print('  "SightFront": Vector3(%.4f, %.4f, %.4f),' % (0.0, punto[1].z, -(punto[0].y + punto[1].y) * 0.5))
    print('  "Grip": Vector3(%.4f, %.4f, %.4f),' % (0.0, web.z - origen.z, -(web.y - origen.y)))
    print("corredera: y=%.3f..%.3f z=%.3f..%.3f recorrido_max=%.4f" % (
        corredera[0].y, corredera[1].y, corredera[0].z, corredera[1].z, corredera[1].y - corredera[0].y))
    for extra in list(bpy.data.objects):
        if extra.type == "EMPTY":
            bpy.data.objects.remove(extra, do_unlink=True)
    raiz = bpy.data.objects.new("DesertEagle", None)
    bpy.context.scene.collection.objects.link(raiz)
    for nombre, lista in [("Frame", EN_FRAME), ("Slide", EN_SLIDE), ("Trigger", EN_TRIGGER), ("Magazine", EN_MAG)]:
        vacio = bpy.data.objects.new(nombre, None)
        bpy.context.scene.collection.objects.link(vacio)
        vacio.parent = raiz
        for clave in lista:
            ob = malla(clave)
            if ob is not None:
                ob.parent = vacio
    for nombre in FUERA:
        ob = malla(nombre)
        if ob is not None:
            bpy.data.objects.remove(ob, do_unlink=True)
    for imagen in bpy.data.images:
        if imagen.size[0] > 512:
            imagen.scale(512, 512)
        imagen.pack()
    bpy.ops.wm.save_as_mainfile(filepath=str(SALIDA), compress=True)
    print("GUARDADO", SALIDA.name, len(bpy.data.objects), "objetos")


main()
