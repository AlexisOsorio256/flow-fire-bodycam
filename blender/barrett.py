import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

ROOT = Path(r"C:\Users\josea\Documents\flow-fire-bodycam")
ORIGEN = ROOT / "build" / "modelos" / "m82_a1_218k.glb"
SALIDA = ROOT / "blender" / "barrett.blend"
LARGO = 1.448
ASIENTO = 0.405
DECIMAR = {"Bolt Carrier_0": 0.16, "Main Body_0": 0.5, "Rail, Grip, Stock and others_0": 0.5,
           "Scope_0": 0.4}
EN_FRAME = ["Barrett M82_Barrett M82 Main Body_0", "Barrett M82_Barrett M82 Rail, Grip, Stock and others_0",
            "Barrett M82 Scope_Barrett M82 Scope_0", "Scope Holder_Barrett M82 Scope_0",
            "Barrett M82_Barrett M82 Bolt Carrier_0"]
EN_SLIDE = ["Barrett M82_Barrett M82 Bolt Carrier_0.001"]
EN_MAG = ["M82 Magazine.003_Barrett M82 Magazine and Bullet_0",
          "Magainze Part.001_Barrett M82 Magazine and Bullet_0"]
SOBRA = [".50 BMG"]


def caja(objetos):
    puntos = [ob.matrix_world @ Vector(e) for ob in objetos for e in ob.bound_box]
    return (Vector((min(p.x for p in puntos), min(p.y for p in puntos), min(p.z for p in puntos))),
            Vector((max(p.x for p in puntos), max(p.y for p in puntos), max(p.z for p in puntos))))


def por_prefijo(texto):
    for ob in bpy.data.objects:
        if ob.type == "MESH" and ob.name.startswith(texto):
            return ob
    return None


def main():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    bpy.ops.import_scene.gltf(filepath=str(ORIGEN))
    for ob in list(bpy.data.objects):
        if ob.type == "MESH" and any(ob.name.startswith(s) for s in SOBRA):
            bpy.data.objects.remove(ob, do_unlink=True)
    mallas = [ob for ob in bpy.data.objects if ob.type == "MESH"]
    for ob in mallas:
        ob.parent = None
        ob.matrix_world = Matrix.Rotation(math.pi, 4, "Z") @ ob.matrix_world
    cuerpo = por_prefijo("Barrett M82_Barrett M82 Rail, Grip, Stock and others_0")
    bajo, alto = caja([cuerpo])
    factor = LARGO / (alto.y - bajo.y)
    for ob in mallas:
        ob.matrix_world = Matrix.Scale(factor, 4) @ ob.matrix_world
    for ob in sorted(mallas, key=lambda o: o.name):
        for clave, proporcion in DECIMAR.items():
            if clave in ob.name:
                antes = len(ob.data.polygons)
                mod = ob.modifiers.new("Decimar", "DECIMATE")
                mod.ratio = proporcion
                bpy.context.view_layer.objects.active = ob
                bpy.ops.object.modifier_apply(modifier=mod.name)
                print("  decimado %-46s %d -> %d" % (ob.name[:46], antes, len(ob.data.polygons)))
    bajo, alto = caja(mallas)
    culatin = caja([por_prefijo("Barrett M82_Barrett M82 Rail")])[0].y
    for ob in mallas:
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.bisect(plane_co=(0.0, culatin, 0.0), plane_no=(0.0, 1.0, 0.0), clear_inner=True)
        bpy.ops.object.mode_set(mode="OBJECT")
    print("cortado en el culatin y=%.3f" % culatin)
    bajo, alto = caja(mallas)
    cerrojo = caja([por_prefijo("Barrett M82_Barrett M82 Bolt Carrier_0")])
    visor = caja([por_prefijo("Barrett M82 Scope_Barrett")])
    cuerpo = caja([por_prefijo("Barrett M82_Barrett M82 Main Body")])
    cargador = caja([por_prefijo("M82 Magazine.003")])
    bore = (cerrojo[0].z + cerrojo[1].z) * 0.5
    agArre = cargador[0].y - 0.055
    origen = Vector((0.0, agArre, bore))
    for ob in mallas:
        ob.matrix_world = Matrix.Translation(-origen) @ ob.matrix_world
    bajo, alto = caja(mallas)
    print("caja final: Y %.3f..%.3f  Z %.3f..%.3f  X %.3f..%.3f" % (
        bajo.y, alto.y, bajo.z, alto.z, bajo.x, alto.x))
    print("SOCKETS (Godot):")
    print('  "Muzzle": Vector3(0.0, %.4f, %.4f),' % (bore - origen.z, -(alto.y - 0.010)))
    print('  "EjectionPort": Vector3(%.4f, %.4f, %.4f),' % (cuerpo[1].x - 0.006,
          (cuerpo[0].z + cuerpo[1].z) * 0.5 - origen.z, (cuerpo[0].y + cuerpo[1].y) * 0.5 - origen.y))
    print('  "SightRear": Vector3(0.0, %.4f, %.4f),' % ((visor[0].z + visor[1].z) * 0.5 - origen.z,
          -(visor[0].y - origen.y)))
    print('  "SightFront": Vector3(0.0, %.4f, %.4f),' % ((visor[0].z + visor[1].z) * 0.5 - origen.z,
          -(visor[1].y - origen.y)))
    print('  "Grip": Vector3(0.0, %.4f, %.4f),' % ((cargador[1].z + cargador[0].z) * 0.5 - origen.z - 0.03,
          -(agArre - origen.y) - 0.01))
    print("cerrojo: y=%.3f..%.3f (%.3f m)  visor z=%.3f..%.3f  cargador y=%.3f..%.3f z=%.3f..%.3f" % (
        cerrojo[0].y - origen.y, cerrojo[1].y - origen.y, cerrojo[1].y - cerrojo[0].y,
        visor[0].z - origen.z, visor[1].z - origen.z, cargador[0].y - origen.y, cargador[1].y - origen.y,
        cargador[0].z - origen.z, cargador[1].z - origen.z))
    for ob in list(bpy.data.objects):
        if ob.type == "EMPTY":
            bpy.data.objects.remove(ob, do_unlink=True)
    raiz = bpy.data.objects.new("Barrett", None)
    bpy.context.scene.collection.objects.link(raiz)
    for nombre, lista in [("Frame", EN_FRAME), ("Slide", EN_SLIDE), ("Trigger", []), ("Magazine", EN_MAG)]:
        vacio = bpy.data.objects.new(nombre, None)
        bpy.context.scene.collection.objects.link(vacio)
        vacio.parent = raiz
        for clave in lista:
            ob = por_prefijo(clave)
            if ob is not None:
                ob.parent = vacio
    for imagen in bpy.data.images:
        if imagen.size[0] > 512:
            imagen.scale(512, 512)
        imagen.pack()
    bpy.ops.wm.save_as_mainfile(filepath=str(SALIDA), compress=True)
    print("GUARDADO", SALIDA.name, len(bpy.data.objects), "objetos")


main()
