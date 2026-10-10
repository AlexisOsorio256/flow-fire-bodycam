import math
import os

import bmesh
import bpy

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
MODELOS = os.path.join(REPO, "assets", "models")
CELDA = 24.0

FICHEROS = {
    "hormigon": ("mapa_hormigon_diff.jpg", "mapa_hormigon_nor.jpg", "mapa_hormigon_rough.jpg"),
    "chapa": ("mapa_chapa_diff.jpg", "mapa_chapa_nor.jpg", "mapa_chapa_rough.jpg"),
    "oxido": ("mapa_oxido_diff.jpg", "mapa_oxido_nor.jpg", "mapa_oxido_rough.jpg"),
    "caja": ("mapa_caja_diff.jpg", "mapa_caja_nor.jpg", "mapa_caja_rough.jpg"),
    "tablon": ("mapa_tablon_diff.jpg", "mapa_tablon_nor.jpg", None),
    "carton": ("mapa_carton_diff.jpg", "mapa_carton_nor.jpg", "mapa_carton_rough.jpg"),
    "yeso": ("mapa_yeso_diff.jpg", "mapa_yeso_nor.jpg", None),
    "cont_verde": ("mapa_cont_verde_diff.jpg", "mapa_chapa_nor.jpg", "mapa_chapa_rough.jpg"),
    "cont_azul": ("mapa_cont_azul_diff.jpg", "mapa_chapa_nor.jpg", "mapa_chapa_rough.jpg"),
    "cont_rojo": ("mapa_cont_rojo_diff.jpg", "mapa_chapa_nor.jpg", "mapa_chapa_rough.jpg"),
    "cont_ocre": ("mapa_cont_ocre_diff.jpg", "mapa_chapa_nor.jpg", "mapa_chapa_rough.jpg"),
    "cal": ("mapa_cal_diff.jpg", "mapa_yeso_nor.jpg", None),
    "ocre": ("mapa_ocre_diff.jpg", "mapa_yeso_nor.jpg", None),
    "arena": ("mapa_arena_diff.jpg", "mapa_hormigon_nor.jpg", "mapa_hormigon_rough.jpg"),
    "piedra": ("mapa_piedra_diff.jpg", "mapa_piedra_nor.jpg", "mapa_piedra_rough.jpg"),
}
METROS = {"hormigon": 4.0, "chapa": 2.4, "oxido": 2.0, "caja": 1.2, "tablon": 1.6, "carton": 1.0,
          "yeso": 3.0, "cont_verde": 2.4, "cont_azul": 2.4, "cont_rojo": 2.4, "cont_ocre": 2.4,
          "cal": 3.0, "ocre": 3.0, "arena": 4.0, "piedra": 2.0}
PLANOS = {
    "cristal": ((0.035, 0.05, 0.065), 0.08),
    "caucho": ((0.035, 0.035, 0.035), 0.9),
}


def imagen(nombre, color):
    img = bpy.data.images.get(nombre) or bpy.data.images.load(os.path.join(MODELOS, nombre), check_existing=True)
    img.colorspace_settings.name = "sRGB" if color else "Non-Color"
    return img


def material(clave):
    existente = bpy.data.materials.get(clave)
    if existente is not None:
        return existente
    if clave in PLANOS:
        color, rugosidad = PLANOS[clave]
        mat = bpy.data.materials.new(clave)
        mat.use_nodes = True
        principal = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        principal.inputs["Base Color"].default_value = (color[0], color[1], color[2], 1.0)
        principal.inputs["Roughness"].default_value = rugosidad
        return mat
    diff, nor, rough = FICHEROS[clave]
    mat = bpy.data.materials.new(clave)
    mat.use_nodes = True
    arbol = mat.node_tree
    arbol.nodes.clear()
    salida = arbol.nodes.new("ShaderNodeOutputMaterial")
    principal = arbol.nodes.new("ShaderNodeBsdfPrincipled")
    arbol.links.new(principal.outputs["BSDF"], salida.inputs["Surface"])
    color_tex = arbol.nodes.new("ShaderNodeTexImage")
    color_tex.image = imagen(diff, True)
    arbol.links.new(color_tex.outputs["Color"], principal.inputs["Base Color"])
    if nor:
        nor_tex = arbol.nodes.new("ShaderNodeTexImage")
        nor_tex.image = imagen(nor, False)
        normal = arbol.nodes.new("ShaderNodeNormalMap")
        arbol.links.new(nor_tex.outputs["Color"], normal.inputs["Color"])
        arbol.links.new(normal.outputs["Normal"], principal.inputs["Normal"])
    if rough:
        rough_tex = arbol.nodes.new("ShaderNodeTexImage")
        rough_tex.image = imagen(rough, False)
        arbol.links.new(rough_tex.outputs["Color"], principal.inputs["Roughness"])
    else:
        principal.inputs["Roughness"].default_value = 0.85
    return mat


def _fusionar(coleccion, temporal):
    grupos = {}
    for ob in coleccion.objects:
        if ob.type != "MESH":
            continue
        me = ob.data
        mw = ob.matrix_world
        capa = me.uv_layers.active.data
        mat = me.materials[0].name
        for poly in me.polygons:
            centro = mw @ poly.center
            llave = (mat, math.floor(centro.x / CELDA), math.floor(centro.y / CELDA))
            verts = [mw @ me.vertices[i].co for i in poly.vertices]
            uvs = [tuple(capa[li].uv) for li in poly.loop_indices]
            grupos.setdefault(llave, []).append((verts, uvs))
    hechos = []
    for (mat, cx, cy), caras in grupos.items():
        bm = bmesh.new()
        uv = bm.loops.layers.uv.new("UVMap")
        for verts, uvs in caras:
            cara = bm.faces.new([bm.verts.new(v) for v in verts])
            for bucle, t in zip(cara.loops, uvs):
                bucle[uv].uv = t
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        me = bpy.data.meshes.new("fusion_%s_%d_%d" % (mat, cx + 1000, cy + 1000))
        bm.to_mesh(me)
        bm.free()
        me.materials.append(bpy.data.materials[mat])
        ob = bpy.data.objects.new(me.name, me)
        temporal.objects.link(ob)
        hechos.append(ob)
    return hechos


def exportar_colecciones(ruta, colecciones):
    temporal = bpy.data.collections.new("_exportar")
    bpy.context.scene.collection.children.link(temporal)
    fusion = _fusionar(colecciones[0], temporal)
    try:
        seleccion = list(fusion)
        for col in colecciones[1:]:
            seleccion.extend(col.objects)
        bpy.ops.object.select_all(action="DESELECT")
        for ob in seleccion:
            ob.select_set(True)
        bpy.context.view_layer.objects.active = seleccion[0]
        bpy.ops.export_scene.gltf(filepath=ruta, export_format="GLB", use_selection=True, export_yup=True,
                                  export_image_format="JPEG", export_jpeg_quality=80, export_image_quality=80,
                                  export_materials="EXPORT", export_cameras=False,
                                  export_lights=False, export_animations=False)
    finally:
        for ob in fusion:
            me = ob.data
            bpy.data.objects.remove(ob, do_unlink=True)
            bpy.data.meshes.remove(me)
        bpy.data.collections.remove(temporal)
