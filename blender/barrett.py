import math
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parent.parent
ORIGEN = Path.home() / ".cache" / "flowfire" / "modelos" / "m82_a1_218k.glb"
SALIDA = ROOT / "blender" / "barrett.blend"
LARGO = 1.448

DECIMAR = {
	"Bolt Carrier_0": 0.16,
	"Main Body_0": 0.5,
	"Rail, Grip, Stock and others_0": 0.5,
	"Scope_0": 0.4,
}
EN_FRAME = [
	"Barrett M82_Barrett M82 Main Body_0",
	"Barrett M82_Barrett M82 Rail, Grip, Stock and others_0",
	"Barrett M82 Scope_Barrett M82 Scope_0",
	"Scope Holder_Barrett M82 Scope_0",
	"Barrett M82_Barrett M82 Bolt Carrier_0",
]
EN_SLIDE = ["Barrett M82_Barrett M82 Bolt Carrier_0.001"]
EN_MAG = [
	"M82 Magazine.003_Barrett M82 Magazine and Bullet_0",
	"Magainze Part.001_Barrett M82 Magazine and Bullet_0",
]
SOBRA = [".50 BMG"]


def caja(objetos):
	puntos = [ob.matrix_world @ Vector(e) for ob in objetos for e in ob.bound_box]
	return (
		Vector((min(p.x for p in puntos), min(p.y for p in puntos), min(p.z for p in puntos))),
		Vector((max(p.x for p in puntos), max(p.y for p in puntos), max(p.z for p in puntos))),
	)


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
		mat = ob.matrix_world.copy()
		ob.parent = None
		ob.matrix_world = mat

	import bmesh

	for ob in mallas:
		if "Rail, Grip, Stock and others_0" in ob.name:
			bm = bmesh.new()
			bm.from_mesh(ob.data)
			to_del = [
				v
				for v in bm.verts
				if ((ob.matrix_world @ v.co).x < -0.025 and (ob.matrix_world @ v.co).y >= 0.12)
				or (0.07 <= (ob.matrix_world @ v.co).y <= 0.46 and (ob.matrix_world @ v.co).z < 0.055)
				or (-0.71 <= (ob.matrix_world @ v.co).y <= -0.64 and (ob.matrix_world @ v.co).z < -0.06)
			]
			bmesh.ops.delete(bm, geom=to_del, context="VERTS")
			bm.to_mesh(ob.data)
			bm.free()

	bajo, alto = caja(mallas)
	factor = LARGO / (alto.y - bajo.y)
	for ob in mallas:
		ob.matrix_world = Matrix.Scale(factor, 4) @ ob.matrix_world

	for ob in sorted(mallas, key=lambda o: o.name):
		for clave, proporcion in DECIMAR.items():
			if clave in ob.name and not ob.name.endswith(".001"):
				antes = len(ob.data.polygons)
				mod = ob.modifiers.new("Decimar", "DECIMATE")
				mod.ratio = proporcion
				bpy.context.view_layer.objects.active = ob
				bpy.ops.object.modifier_apply(modifier=mod.name)
				print("  decimado %-46s %d -> %d" % (ob.name[:46], antes, len(ob.data.polygons)))

	cargador = por_prefijo("M82 Magazine.003")
	caja_mag = caja([cargador])
	cerrojo = caja([por_prefijo("Barrett M82_Barrett M82 Bolt Carrier_0.001")])
	bore = (cerrojo[0].z + cerrojo[1].z) * 0.5
	grip_y = caja_mag[0].y - 0.08
	origen = Vector((0.0, grip_y, bore))

	for ob in mallas:
		ob.matrix_world = Matrix.Translation(-origen) @ ob.matrix_world

	bajo, alto = caja(mallas)
	print("caja final: Y %.3f..%.3f  Z %.3f..%.3f  X %.3f..%.3f" % (bajo.y, alto.y, bajo.z, alto.z, bajo.x, alto.x))

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
	glb_out = ROOT / "assets" / "models" / "barrett.glb"
	bpy.ops.object.select_all(action="SELECT")
	bpy.ops.export_scene.gltf(filepath=str(glb_out), export_format="GLB", use_selection=True,
		export_yup=True, export_image_format="AUTO", export_animations=False)
	print("GUARDADO", SALIDA.name, "y", glb_out.name)


main()

