import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
MODELOS = os.path.join(REPO, "assets", "models")
BIBLIOTECA = os.path.join(REPO, "blender", "biblioteca_mapas.glb")
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


def G(x, y, z):
    return Vector((x, -z, y))


def _nuevos(verts):
    conjunto = set(verts)
    caras = {f for v in verts for f in v.link_faces if all(x in conjunto for x in f.verts)}
    aristas = {e for v in verts for e in v.link_edges if all(x in conjunto for x in e.verts)}
    return list(caras), list(aristas)


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


class Escena:
    def __init__(self):
        self.contador = 0
        self.alturas = []
        self.biblioteca = {}
        self.estatica = self._coleccion("Static")
        self.utilerias = self._coleccion("Props")
        self.colisiones = self._coleccion("Colliders")
        self.marcas = self._coleccion("Markers")

    def _coleccion(self, nombre):
        col = bpy.data.collections.new(nombre)
        bpy.context.scene.collection.children.link(col)
        return col

    def importar(self):
        antes = set(bpy.data.objects.keys())
        bpy.ops.import_scene.gltf(filepath=BIBLIOTECA)
        nuevos = [o for o in bpy.data.objects if o.name not in antes]
        bpy.ops.object.select_all(action="DESELECT")
        for o in nuevos:
            o.select_set(True)
        bpy.context.view_layer.objects.active = nuevos[0]
        bpy.ops.object.make_single_user(type="SELECTED_OBJECTS", obdata=True)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        for o in nuevos:
            if o.type == "MESH":
                self.biblioteca[o.name] = o

    def _nueva(self):
        bm = bmesh.new()
        return bm, bm.loops.layers.uv.new("UVMap")

    def _publicar(self, clave, bm, nombre):
        self.contador += 1
        etiqueta = "%s_%d" % (nombre, self.contador)
        me = bpy.data.meshes.new(etiqueta)
        bm.to_mesh(me)
        bm.free()
        me.materials.append(material(clave))
        self.estatica.objects.link(bpy.data.objects.new(etiqueta, me))

    def _uv(self, cara, capa, metros, cilindro=None):
        n = cara.normal
        for bucle in cara.loops:
            p = bucle.vert.co
            if cilindro is not None and abs(n.z) < 0.5:
                cx, cy, radio = cilindro
                angulo = math.atan2(p.y - cy, p.x - cx)
                bucle[capa].uv = ((angulo * radio) / metros, p.z / metros)
            elif abs(n.z) >= abs(n.x) and abs(n.z) >= abs(n.y):
                bucle[capa].uv = (p.x / metros, p.y / metros)
            elif abs(n.x) >= abs(n.y):
                bucle[capa].uv = (p.y / metros, p.z / metros)
            else:
                bucle[capa].uv = (p.x / metros, p.z / metros)

    def caja(self, clave, centro, tam, giro=0.0, bisel=0.0, nombre="caja"):
        centro_bl = G(*centro)
        tam_bl = Vector((tam[0], tam[2], tam[1]))
        bm, capa = self._nueva()
        verts = bmesh.ops.create_cube(bm, size=1.0)["verts"]
        caras, aristas = _nuevos(verts)
        m = Matrix.Translation(centro_bl) @ Matrix.Rotation(giro, 4, "Z") @ Matrix.Diagonal((tam_bl.x, tam_bl.y, tam_bl.z, 1.0))
        bmesh.ops.transform(bm, matrix=m, verts=verts)
        bm.normal_update()
        for cara in caras:
            self._uv(cara, capa, METROS.get(clave, 1.0))
        if bisel > 0.0:
            bmesh.ops.bevel(bm, geom=aristas, offset=bisel, offset_type="OFFSET", segments=2,
                            profile=0.5, affect="EDGES", clamp_overlap=True)
        self._publicar(clave, bm, nombre)

    def cilindro(self, clave, base, radio, alto, lados=32, radio_alto=None, nombre="cilindro"):
        base_bl = G(*base)
        bm, capa = self._nueva()
        cima = radio if radio_alto is None else radio_alto
        verts = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=lados, radius1=radio,
                                      radius2=cima, depth=alto,
                                      matrix=Matrix.Translation(base_bl + Vector((0, 0, alto * 0.5))))["verts"]
        caras, _ = _nuevos(verts)
        bm.normal_update()
        for cara in caras:
            lateral = abs(cara.normal.z) < 0.5
            cara.smooth = lateral
            self._uv(cara, capa, METROS.get(clave, 1.0), (base_bl.x, base_bl.y, radio) if lateral else None)
        self._publicar(clave, bm, nombre)

    def rueda(self, centro, radio, ancho, giro=0.0):
        centro_bl = G(*centro)
        bm, capa = self._nueva()
        m = Matrix.Translation(centro_bl) @ Matrix.Rotation(giro, 4, "Z") @ Matrix.Rotation(math.pi * 0.5, 4, "X")
        verts = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=20, radius1=radio, radius2=radio,
                                      depth=ancho, matrix=m)["verts"]
        caras, _ = _nuevos(verts)
        bm.normal_update()
        for cara in caras:
            self._uv(cara, capa, 1.0)
        self._publicar("caucho", bm, "rueda")

    def techo(self, clave, centro, largo, ancho, altura, giro=0.0, nombre="techo"):
        centro_bl = G(*centro)
        bm, capa = self._nueva()
        L, W, h = largo, ancho, altura
        puntos = [Vector((-L / 2, -W / 2, 0)), Vector((L / 2, -W / 2, 0)), Vector((L / 2, W / 2, 0)),
                  Vector((-L / 2, W / 2, 0)), Vector((-L / 2, 0, h)), Vector((L / 2, 0, h))]
        v = [bm.verts.new(q) for q in puntos]
        caras = [bm.faces.new((v[0], v[1], v[5], v[4])), bm.faces.new((v[3], v[2], v[5], v[4])),
                 bm.faces.new((v[0], v[4], v[3])), bm.faces.new((v[1], v[2], v[5]))]
        bmesh.ops.transform(bm, matrix=Matrix.Translation(centro_bl) @ Matrix.Rotation(giro, 4, "Z"), verts=v)
        bmesh.ops.recalc_face_normals(bm, faces=caras)
        bm.normal_update()
        for cara in caras:
            self._uv(cara, capa, METROS.get(clave, 1.0))
        self._publicar(clave, bm, nombre)

    def muro(self, clave, a, b, alto, grosor, aberturas=(), superficie=None, nombre="muro"):
        dx, dz = b[0] - a[0], b[1] - a[1]
        largo = math.hypot(dx, dz)
        ux, uz = dx / largo, dz / largo
        giro = math.atan2(-uz, ux)
        cortes_y = sorted({0.0, alto} | {ab[2] for ab in aberturas} | {ab[3] for ab in aberturas})
        for y0, y1 in zip(cortes_y, cortes_y[1:]):
            ym = (y0 + y1) * 0.5
            huecos = sorted((ab[0], ab[1]) for ab in aberturas if ab[2] <= ym <= ab[3])
            tramos = []
            pos = 0.0
            for h0, h1 in huecos:
                if h0 > pos:
                    tramos.append((pos, h0))
                pos = max(pos, h1)
            if pos < largo:
                tramos.append((pos, largo))
            for s0, s1 in tramos:
                sm = (s0 + s1) * 0.5
                centro = (a[0] + ux * sm, (y0 + y1) * 0.5, a[1] + uz * sm)
                tam = (s1 - s0, y1 - y0, grosor)
                self.caja(clave, centro, tam, giro, nombre=nombre)
                if superficie is not None:
                    self.colisor(superficie, nombre, centro, tam, giro)
        for ab in aberturas:
            sm = (ab[0] + ab[1]) * 0.5
            centro = (a[0] + ux * sm, (ab[2] + ab[3]) * 0.5, a[1] + uz * sm)
            tam = (ab[1] - ab[0], ab[3] - ab[2], grosor)
            self.caja("cristal", centro, tam, giro)
            if superficie is not None:
                self.colisor("glass", nombre + "_cristal", centro, tam, giro)

    def colisor(self, superficie, nombre, centro, tam, giro=0.0):
        centro_bl = G(*centro)
        self._colision_caja(superficie, nombre, centro_bl, Vector((tam[0], tam[2], tam[1])), giro)

    def _colision_caja(self, superficie, nombre, centro_bl, tam_bl, giro):
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        m = Matrix.Translation(centro_bl) @ Matrix.Rotation(giro, 4, "Z") @ Matrix.Diagonal((tam_bl.x, tam_bl.y, tam_bl.z, 1.0))
        bmesh.ops.transform(bm, matrix=m, verts=bm.verts[:])
        self._objeto_colision(superficie, nombre, bm, centro_bl, tam_bl, giro)

    def colisor_cilindro(self, superficie, nombre, base, radio, alto):
        self._colision_cilindro_bl(superficie, nombre, G(*base), radio, alto)

    def _colision_cilindro_bl(self, superficie, nombre, base_bl, radio, alto, lados=16):
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=lados, radius1=radio, radius2=radio,
                              depth=alto, matrix=Matrix.Translation(base_bl + Vector((0, 0, alto * 0.5))))
        self._objeto_colision(superficie, nombre, bm, base_bl + Vector((0, 0, alto * 0.5)), Vector((radio * 2, radio * 2, alto)))

    def _objeto_colision(self, superficie, nombre, bm, centro_bl, tam_bl, giro=0.0):
        self.contador += 1
        nombre_final = "%s_%s_%d-convcolonly" % (superficie, nombre, self.contador)
        me = bpy.data.meshes.new(nombre_final)
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new(nombre_final, me)
        self.colisiones.objects.link(ob)
        self.alturas.append((superficie, nombre_final, centro_bl, tam_bl, giro))

    def utileria(self, origen, centro, giro=0.0, colision=None):
        src = self.biblioteca[origen]
        xs = [c[0] for c in src.bound_box]
        ys = [c[1] for c in src.bound_box]
        zs = [c[2] for c in src.bound_box]
        mn = Vector((min(xs), min(ys), min(zs)))
        mx = Vector((max(xs), max(ys), max(zs)))
        cen = (mn + mx) * 0.5
        tam = mx - mn
        rot = Matrix.Rotation(giro, 3, "Z")
        objetivo = G(centro[0], 0.0, centro[1])
        base_xy = objetivo - rot @ Vector((cen.x, cen.y, 0.0))
        loc = Vector((base_xy.x, base_xy.y, -mn.z))
        self.contador += 1
        ob = bpy.data.objects.new("%s_%d" % (origen, self.contador), src.data)
        ob.location = loc
        ob.rotation_euler = (0.0, 0.0, giro)
        self.utilerias.objects.link(ob)
        if colision is not None:
            superficie, nombre = colision
            centro_bl = loc + rot @ cen
            if superficie == "barrel":
                self._colision_cilindro_bl("barrel", nombre, Vector((centro_bl.x, centro_bl.y, 0.0)),
                                           max(tam.x, tam.y) * 0.5, tam.z)
            else:
                self._colision_concava(superficie, nombre, ob, centro_bl, tam, giro)

    def _colision_concava(self, superficie, nombre, ob, centro_bl, tam_bl, giro):
        self.contador += 1
        nombre_final = "%s_%s_%d-colonly" % ("steel" if superficie == "rack" else superficie, nombre, self.contador)
        col = bpy.data.objects.new(nombre_final, ob.data)
        col.matrix_world = ob.matrix_world.copy()
        self.colisiones.objects.link(col)
        self.alturas.append((superficie, nombre_final, centro_bl, tam_bl, giro))

    def marca(self, nombre, x, z):
        ob = bpy.data.objects.new(nombre, None)
        ob.empty_display_type = "PLAIN_AXES"
        ob.empty_display_size = 0.6
        ob.location = G(x, 0.0, z)
        self.marcas.objects.link(ob)

    def solapa(self, x, z, margen=0.6, alto=1.8):
        p = Vector((x, -z, 0.0))
        for superficie, nombre, centro, tam, giro in self.alturas:
            if not (centro.z - tam.z * 0.5 < alto and centro.z + tam.z * 0.5 > 0.0):
                continue
            d = (p - centro).to_2d()
            c, s = math.cos(-giro), math.sin(-giro)
            lx = c * d.x - s * d.y
            ly = s * d.x + c * d.y
            if abs(lx) < tam.x * 0.5 + margen and abs(ly) < tam.y * 0.5 + margen:
                return "%s:%s" % (superficie, nombre)
        return None

    def guardar(self, ruta):
        for ob in self.biblioteca.values():
            bpy.data.objects.remove(ob, do_unlink=True)
        bpy.ops.wm.save_as_mainfile(filepath=ruta, compress=True)
        bpy.ops.file.make_paths_relative()
        bpy.ops.wm.save_mainfile(compress=True)

    def exportar(self, ruta):
        exportar_colecciones(ruta, [self.estatica, self.utilerias, self.colisiones, self.marcas])


def cajas_pila(e, x, z, filas):
    for dx, dz, n in filas:
        for k in range(n):
            centro = (x + dx, 0.45 + k * 0.9, z + dz)
            e.caja("caja", centro, (1.0, 0.9, 0.9), 0.0, 0.03)
            e.colisor("pine", "caja", centro, (1.0, 0.9, 0.9))


def cajas_carton(e, x, z, filas):
    for dx, dz, n in filas:
        for k in range(n):
            centro = (x + dx, 0.3 + k * 0.6, z + dz)
            e.caja("carton", centro, (0.6, 0.6, 0.6), 0.0, 0.02)
            e.colisor("paper", "carton", centro, (0.6, 0.6, 0.6))


def comprobar_base(e, nombre, x, z, hueco=1.3, margen=0.4):
    for dx in (-hueco, hueco):
        for dz in (-hueco, hueco):
            libre = e.solapa(x + dx, z + dz, margen)
            if libre is not None:
                print("BASE EN OBJETO", nombre, x + dx, z + dz, libre)
