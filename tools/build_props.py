#!/usr/bin/env python3
"""build_props.py -- mobiliario de la CASA de FlowFire (muebles + cobertura).

Uso (desde la raiz del repo):

    blender --background --python tools/build_props.py

SALIDA (una sola, y viaja TODO el dato dentro)
-----------------------------------------------
``assets/models/props.glb``: geometria + NOMBRE de material, SIN imagenes dentro
(``export_image_format="NONE"``). Las texturas PBR ya viven en
``assets/textures/real/`` y quien instancie el GLB las vuelve a enganchar por
nombre; una textura se paga una vez (decision ya tomada en el bunker y en el
rango, aqui se respeta).

La COLISION NO sale en un .tscn paralelo: sale en los ``extras`` de cada nodo
glTF, que Godot importa como ``metadata/extras`` (medido: un Dictionary con
``col_shape``, ``col_size``, ``surface``...). Asi ``props.glb`` se instancia
SIN editar este fichero ni tocar ``scenes/House.tscn``: quien monta la casa
recorre los hijos, lee el extra y levanta el ``StaticBody3D``. Toda forma es
CAJA o CILINDRO porque ``Ballistics._find_exit_geometry`` solo sabe sacar la
cara de salida de una caja, un cilindro o una esfera.

POR QUE LOS PROPS VAN SEPARADOS DEL SHELL
-----------------------------------------
El shell (muros, losa, hueco, ventanas) lo modela otro fichero; aqui solo hay
mobiliario colocado en coordenadas de MUNDO, de modo que la casa se puede
repartir: el shell pone la caja, este GLB pone los muebles, y las cotas que
ambos comparten estan escritas en ``docs/HOUSE_DESIGN.md`` (la ficha de arte
es el contrato; este script no lee de ahi nada, solo la cumple).

ESCALA / COORDENADAS
---------------------
Todo se escribe en coordenadas de GODOT (X derecha, Y arriba, -Z al frente) y
se convierte a Blender en un solo sitio (``G``/``B``). El exportador devuelve
el eje Y arriba, asi que la posicion del nodo en Godot es exactamente la de
este archivo. Cada pieza se construye con el ORIGEN en el centro de su
huella y suelo (y=0 del nivel), y el ``yaw`` decide hacia donde mira:
TODA pieza mira su +X local, y el colisionador se calcula del AABB LOCAL, que
gira con el nodo.

AUTOCOMPROBACION (falsifica, no decora)
---------------------------------------
Antes de exportar se comprueba que cada pieza cae dentro de la cota de su
cuarto (no atraviesa muros ni se va al patio), que no se hunde en el suelo ni
pasa del techo, que todo ``surface`` existe en ``Ballistics.MATERIALS`` y que
dos cuerpos no se solapan. Si algo falla, no se escribe el GLB.
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Matrix, Vector

REPO = Path(__file__).resolve().parents[1]
MODELS = REPO / "assets" / "models"
TEXTURES = REPO / "assets" / "textures" / "real"
OUT = MODELS / "props.glb"

## Los UNICOS `surface` que el runtime acepta (`Ballistics.MATERIALS`). Un valor
## fuera de aqui es un push_error en cada impacto, asi que el builder aborta.
SURFACES = {"pine", "gypsum", "paper", "aluminum", "steel", "concrete"}

## Metros de mundo que cubre UNA vuelta de textura (densidad fisica real).
MATERIALES: dict[str, dict] = {
    "House_Wood": {
        "albedo": "wood_oak_wood_planks_diff.jpg",
        "rough": "wood_oak_wood_planks_rough.jpg",
        "normal": "wood_oak_wood_planks_nor_gl.jpg",
        ## El roble del repo es de croma fuerte (media lineal 0,362/0,179/0,088).
        ## Dentro, con luz calida, hace falta menos empuje azul que en el bunker
        ## (que va a sol): 0,72/0,76/0,84 deja la madera curtida sin ir a rosa.
        "color": (0.72, 0.76, 0.84),
        "metallic": 0.0, "roughness": 0.78, "normal_scale": 0.85, "tile": 1.2,
    },
    "House_Metal": {
        "albedo": "metal_metal_plate_diff.jpg",
        "rough": "metal_metal_plate_rough.jpg",
        "normal": "metal_metal_plate_nor_gl.jpg",
        "color": (1.00, 1.06, 1.18),
        "metallic": 0.35, "roughness": 0.45, "normal_scale": 0.75, "tile": 1.6,
    },
    "House_Plaster": {
        ## Sin textura: blanco de cocina/bano es liso, y el yeso del repo es
        ## gris medio (0,39 sRGB) que solo se consigue multiplicando por 6.
        "albedo": "", "rough": "", "normal": "",
        "color": (0.88, 0.86, 0.82),
        "metallic": 0.0, "roughness": 0.34, "normal_scale": 0.0, "tile": 1.0,
    },
    "House_Concrete": {
        "albedo": "concrete_brushed_concrete_diff.jpg",
        "rough": "concrete_brushed_concrete_rough.jpg",
        "normal": "concrete_brushed_concrete_nor_gl.jpg",
        "color": (0.74, 0.74, 0.76),
        "metallic": 0.0, "roughness": 0.82, "normal_scale": 0.6, "tile": 2.4,
    },
    "House_Fabric": {
        ## Trampa medida: el repo no tiene tela. El yeso es el unico ruido fino
        ## y neutro que hay; a tile 0,40 m y tinte calido lee como tejido.
        "albedo": "gypsum_diff.jpg", "rough": "gypsum_rough.jpg", "normal": "",
        "color": (1.10, 1.02, 0.90),
        "metallic": 0.0, "roughness": 0.96, "normal_scale": 0.0, "tile": 0.40,
    },
    "House_Linen": {
        ## Plano a proposito: ropa de cama lisa, sin ruido que delate la escala.
        "albedo": "", "rough": "", "normal": "",
        "color": (0.86, 0.84, 0.80),
        "metallic": 0.0, "roughness": 0.90, "normal_scale": 0.0, "tile": 1.0,
    },
    "House_Rug": {
        ## La brocha del repo tiene direccion de lijado: a tile 0,60 m se lee
        ## como trama tejida, y el tinte la deja en herrumbre.
        "albedo": "concrete_brushed_concrete_diff.jpg",
        "rough": "concrete_brushed_concrete_rough.jpg", "normal": "",
        "color": (1.00, 0.40, 0.31),
        "metallic": 0.0, "roughness": 1.0, "normal_scale": 0.0, "tile": 0.60,
    },
    "House_Glass": {
        ## Espejos y pantallas: reflejo de environment, no plano real. Sin mapa:
        ## el brillo del cristal es escalar.
        "albedo": "", "rough": "", "normal": "",
        "color": (0.90, 0.93, 0.96),
        "metallic": 1.0, "roughness": 0.05, "normal_scale": 0.0, "tile": 1.0,
    },
}

# ---------------------------------------------------------------------------
# Cotas de la casa. Un solo sitio para cada numero (los dos builders los leen
# de docs/HOUSE_DESIGN.md, aqui estan escritos tal cual).
# ---------------------------------------------------------------------------
ALTURA = 2.70        # altura libre de cada planta
NIVEL_ALTA = 2.90    # cara superior de la losa = nivel de piso de la planta alta

## Rectangulo interior de cada cuarto: (x0, x1, z0, z1, y_piso). Los caras de
## muro ya estan descontadas: un mueble que se salga de aqui atraviesa un muro.
ROOMS: dict[str, tuple] = {
    "patio":        (-6.00, 6.00, 4.00, 11.00, 0.00),
    "salon":        (-4.88, -0.82, -0.94, 3.88, 0.00),
    "comedor":      (0.82, 4.88, -0.94, 3.88, 0.00),
    "cocina":       (-4.88, -0.82, -5.88, -1.06, 0.00),
    "bano_pb":      (2.28, 4.88, -5.88, -3.46, 0.00),
    "lavadero":     (2.28, 4.88, -3.34, -1.06, 0.00),
    "pasillo":      (-0.70, 0.70, -5.88, 3.88, 0.00),
    "dorm1":        (0.82, 4.88, -0.94, 3.88, NIVEL_ALTA),
    "dorm2":        (-4.88, -0.82, -0.94, 3.88, NIVEL_ALTA),
    "dorm3":        (-4.88, -0.82, -4.34, -1.06, NIVEL_ALTA),
    "bano_alta":    (-4.88, -0.82, -5.88, -4.46, NIVEL_ALTA),
    "estudio":      (2.28, 4.88, -5.88, -1.06, NIVEL_ALTA),
    "pasillo_alta": (-0.70, 0.70, -5.88, 3.88, NIVEL_ALTA),
}

TOL = 0.03           # tolerancia de cota (medidas reales vs. redondeo)

PROPS: list[dict] = []
_USED: set[str] = set()


# ---------------------------------------------------------------------------
# Conversion de espacios y materiales
# ---------------------------------------------------------------------------
def G(x: float, y: float, z: float) -> Vector:
    """Godot local (X derecha, Y arriba, -Z al frente) -> Blender local."""
    return Vector((x, -z, y))


def B(x: float, y: float, z: float) -> Vector:
    """Godot MUNDO -> Blender MUNDO."""
    return Vector((x, -z, y))


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for datablocks in (
        bpy.data.meshes, bpy.data.curves, bpy.data.materials,
        bpy.data.cameras, bpy.data.lights, bpy.data.images,
    ):
        for datablock in list(datablocks):
            if datablock.users == 0:
                datablocks.remove(datablock)


def image(path: Path, non_color: bool = False):
    img = bpy.data.images.load(str(path), check_existing=True)
    if non_color:
        img.colorspace_settings.name = "Non-Color"
    return img


def material(name: str):
    spec = MATERIALES[name]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    output = nodes.new("ShaderNodeOutputMaterial")
    shader = nodes.new("ShaderNodeBsdfPrincipled")
    shader.inputs["Base Color"].default_value = (*spec["color"], 1.0)
    shader.inputs["Metallic"].default_value = spec["metallic"]
    shader.inputs["Roughness"].default_value = spec["roughness"]
    links.new(shader.outputs["BSDF"], output.inputs["Surface"])

    tile = spec["tile"]

    def tiled(key: str, non_color: bool):
        file = spec[key]
        if not file:
            return None
        path = TEXTURES / file
        if not path.exists():
            raise SystemExit("build_props: falta la textura %s" % path)
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = image(path, non_color)
        mapping = nodes.new("ShaderNodeMapping")
        mapping.inputs["Scale"].default_value = (1.0 / tile,) * 3
        coords = nodes.new("ShaderNodeTexCoord")
        links.new(coords.outputs["UV"], mapping.outputs["Vector"])
        links.new(mapping.outputs["Vector"], tex.inputs["Vector"])
        return tex

    albedo = tiled("albedo", False)
    if albedo is not None:
        links.new(albedo.outputs["Color"], shader.inputs["Base Color"])
    rough = tiled("rough", True)
    if rough is not None:
        links.new(rough.outputs["Color"], shader.inputs["Roughness"])
    normal = tiled("normal", True)
    if normal is not None:
        bump = nodes.new("ShaderNodeNormalMap")
        bump.inputs["Strength"].default_value = spec["normal_scale"]
        links.new(normal.outputs["Color"], bump.inputs["Color"])
        links.new(bump.outputs["Normal"], shader.inputs["Normal"])
    mat["metros_por_tile"] = tile
    return mat


MAT: dict[str, object] = {}


# ---------------------------------------------------------------------------
# Piezas: cada una nace en (0,0,0) con la malla en coordenadas LOCALES del
# prop, para que el join conserve el origen en el centro de la huella.
# ---------------------------------------------------------------------------
def _obj(name: str, bm: bmesh.types.BMesh, mat_name: str):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    mesh.materials.append(MAT[mat_name])
    return obj


def box(center, size, mat_name: str, bevel: float = 0.008):
    """Caja en ejes GODOT locales: center y size = (x, y, z)."""
    cx, cy, cz = center
    sx, sy, sz = size
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector((sx, sz, sy)), verts=bm.verts)
    if bevel > 0.0005:
        offset = min(bevel, min(sx, sy, sz) * 0.24)
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=offset, segments=1,
                        profile=0.5, affect="EDGES")
    offset = G(cx, cy, cz)
    for vert in bm.verts:
        vert.co += offset
    return _obj("p", bm, mat_name)


def _spin(bm: bmesh.types.BMesh, axis: str) -> None:
    """Pone el cilindro (nace en Z de Blender) sobre el eje GODOT pedido."""
    if axis == "y":
        return
    rot = Matrix.Rotation(math.radians(90.0), 4, "Y" if axis == "x" else "X")
    for vert in bm.verts:
        vert.co = rot @ vert.co


def cyl(center, radius: float, height: float, mat_name: str,
        segments: int = 20, axis: str = "y", smooth: bool = True):
    cx, cy, cz = center
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segments,
                          radius1=radius, radius2=radius, depth=height)
    if smooth:
        for face in bm.faces:
            if abs(face.normal.z) < 0.9:
                face.smooth = True
    _spin(bm, axis)
    offset = G(cx, cy, cz)
    for vert in bm.verts:
        vert.co += offset
    return _obj("p", bm, mat_name)


def cone(center, r_bottom: float, r_top: float, height: float, mat_name: str,
         segments: int = 20):
    cx, cy, cz = center
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segments,
                          radius1=r_bottom, radius2=r_top, depth=height)
    for face in bm.faces:
        if abs(face.normal.z) < 0.9:
            face.smooth = True
    offset = G(cx, cy, cz)
    for vert in bm.verts:
        vert.co += offset
    return _obj("p", bm, mat_name)


def blob(center, radius: float, mat_name: str, squash: float = 1.0):
    """Icosfera barata: macetas y arbustos."""
    cx, cy, cz = center
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=1, radius=radius)
    for vert in bm.verts:
        vert.co.z *= squash
    offset = G(cx, cy, cz)
    for vert in bm.verts:
        vert.co += offset
    return _obj("p", bm, mat_name)


# ---------------------------------------------------------------------------
# Ensamblaje del prop: une, coloca, hornea UV por material y deja los extras.
# ---------------------------------------------------------------------------
def _unique(name: str) -> str:
    if name not in _USED:
        _USED.add(name)
        return name
    k = 2
    while f"{name}_{k}" in _USED:
        k += 1
    _USED.add(f"{name}_{k}")
    return f"{name}_{k}"


def _join(name: str, objs: list):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objs:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    joined = bpy.context.object
    joined.name = name
    joined.data.name = name
    return joined


def cube_project(obj) -> None:
    """UV por proyeccion cubica a densidad fisica, en ESPACIO DE MUNDO.

    Se hornea DESPUES de colocar: dos piezas del mismo mueble comparten fase y
    no aparece una costura que el mueble no tiene.
    """
    matrix = obj.matrix_world
    mesh = obj.data
    tiles = [MATERIALES[slot.material.name]["tile"] for slot in obj.material_slots]
    bm = bmesh.new()
    bm.from_mesh(mesh)
    uv = bm.layers.uv.verify()
    for face in bm.faces:
        scale = tiles[face.material_index] if face.material_index < len(tiles) else 1.0
        world_normal = matrix.to_3x3() @ face.normal
        axis = max(range(3), key=lambda i: abs(world_normal[i]))
        for loop in face.loops:
            co = matrix @ loop.vert.co
            if axis == 0:
                u, v = co.y, co.z
            elif axis == 1:
                u, v = co.x, co.z
            else:
                u, v = co.x, co.y
            loop[uv].uv = (u / scale, v / scale)
    bm.to_mesh(mesh)
    bm.free()


def prop(name: str, room: str, origin, pieces: list, *, yaw: float = 0.0,
         collider: bool = True, surface: str = "pine", penetrable: bool = False,
         thin_shell: float = 0.0, shape: str = "box", contact: bool = True):
    """Une las piezas, la coloca en MUNDO y escribe el contrato de colision.

    ``origin`` es el centro de la huella sobre el suelo del cuarto (Godot). El
    colisionador es el AABB LOCAL de la malla: gira con el nodo, asi que no se
    desincroniza aunque quien instancia mueva la pieza.
    """
    if room not in ROOMS:
        raise SystemExit("build_props: cuarto desconocido %s" % room)
    if collider and surface not in SURFACES:
        raise SystemExit("build_props: %s declara surface=%s fuera de "
                         "Ballistics.MATERIALS" % (name, surface))

    node = _unique(name)
    obj = _join(node, pieces)
    obj.location = B(*origin)
    obj.rotation_mode = "XYZ"
    obj.rotation_euler = (0.0, 0.0, math.radians(yaw))
    bpy.context.view_layer.update()
    cube_project(obj)

    mesh = obj.data
    local = [Vector((v.co.x, v.co.y, v.co.z)) for v in mesh.vertices]
    lo = Vector((min(v.x for v in local), min(v.y for v in local), min(v.z for v in local)))
    hi = Vector((max(v.x for v in local), max(v.y for v in local), max(v.z for v in local)))
    mid = (lo + hi) * 0.5
    size = hi - lo

    ## Rotacion del yaw para pasar de AABB local a AABB de MUNDO (la pieza
    ## puede ir girada y la cota del cuarto se cumple en ejes de mundo).
    c, s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    corners = [(lo.x, lo.y), (lo.x, hi.y), (hi.x, lo.y), (hi.x, hi.y)]
    wx = [origin[0] + c * px - s * py for px, py in corners]
    wz = [origin[2] + s * px + c * py for px, py in corners]
    world = (min(wx), max(wx), min(wz), max(wz), origin[1] + lo.z, origin[1] + hi.z)

    if collider:
        ## Cilindro solo si el eje del solido es vertical: CylinderShape3D en
        ## Godot es siempre Y, y una barra horizontal quedaria mal orientada.
        used = "cylinder" if shape == "cylinder" else "box"
        obj["col_shape"] = used
        obj["col_center"] = [round(mid.x, 4), round(mid.z, 4), round(-mid.y, 4)]
        if used == "cylinder":
            obj["col_radius"] = round(max(size.x, size.y) * 0.5, 4)
            obj["col_height"] = round(size.z, 4)
        else:
            obj["col_size"] = [round(size.x, 4), round(size.z, 4), round(size.y, 4)]
        obj["surface"] = surface
        obj["penetrable"] = bool(penetrable)
        if thin_shell > 0.0:
            obj["thin_shell"] = True
            obj["wall_thickness"] = round(thin_shell, 4)
        if contact:
            ## Sombra de contacto en ejes de MUNDO (asi la usa ContactBlob tal
            ## cual con la colocacion que lleva el builder).
            reach_x = max(abs(w - origin[0]) for w in (wx[0], wx[-1]))
            reach_z = max(abs(w - origin[2]) for w in (wz[0], wz[-1]))
            obj["contact"] = [round(reach_x, 3), round(reach_z, 3)]
    obj["room"] = room
    PROPS.append({"name": node, "room": room, "world": world, "collider": collider,
                  "origin": tuple(origin), "yaw": yaw})
    return obj


# ---------------------------------------------------------------------------
# Mobiliario generico. TODA pieza mira su +X local: con yaw=0 mira al este.
# ---------------------------------------------------------------------------
def sofa(name, room, origin, yaw, width=2.10, depth=0.88, mat="House_Fabric"):
    p = []
    p.append(box((0.0, 0.20, 0.0), (depth, 0.40, width), mat, 0.02))      # caja
    p.append(box((-depth * 0.5 + 0.09, 0.55, 0.0), (0.18, 0.70, width), mat, 0.025))  # respaldo
    for sign in (-1, 1):
        p.append(box((0.0, 0.50, sign * (width * 0.5 - 0.11)),
                     (depth, 0.34, 0.22), mat, 0.03))                      # brazos
    seat_w = (width - 0.44) / 3.0
    for i in range(3):
        z = (i - 1) * seat_w
        p.append(box((0.04, 0.47, z), (depth - 0.24, 0.14, seat_w - 0.03), mat, 0.03))
        p.append(box((-depth * 0.5 + 0.20, 0.66, z), (0.14, 0.34, seat_w - 0.03), mat, 0.03))
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.append(box((sx * (depth * 0.5 - 0.07), 0.035, sz * (width * 0.5 - 0.09)),
                         (0.06, 0.07, 0.07), "House_Wood", 0.01))
    prop(name, room, origin, p, yaw=yaw, surface="pine", penetrable=True,
         contact=True)


def butaca(name, room, origin, yaw, mat="House_Fabric"):
    sofa(name, room, origin, yaw, width=0.92, depth=0.86, mat=mat)


def mesa(name, room, origin, yaw, largo, ancho, alto=0.75, mat="House_Wood",
         patas=0.055):
    p = [box((0.0, alto - 0.025, 0.0), (largo, 0.05, ancho), mat, 0.006)]
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.append(box((sx * (largo * 0.5 - 0.07), (alto - 0.05) * 0.5,
                          sz * (ancho * 0.5 - 0.07)),
                         (patas, alto - 0.05, patas), mat, 0.006))
    p.append(box((0.0, alto - 0.12, 0.0), (largo - 0.20, 0.06, ancho - 0.16), mat, 0.004))
    prop(name, room, origin, p, yaw=yaw, surface="pine", penetrable=False)


def silla(name, room, origin, yaw, mat="House_Wood"):
    p = [box((0.0, 0.44, 0.0), (0.44, 0.05, 0.44), mat, 0.008)]
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.append(box((sx * 0.18, 0.21, sz * 0.18), (0.04, 0.42, 0.04), mat, 0.005))
    p.append(box((-0.20, 0.72, 0.0), (0.05, 0.55, 0.42), mat, 0.008))
    p.append(box((-0.20, 0.94, 0.0), (0.05, 0.09, 0.42), mat, 0.012))
    for z in (-0.12, 0.12):
        p.append(box((-0.20, 0.66, z), (0.04, 0.44, 0.05), mat, 0.006))
    prop(name, room, origin, p, yaw=yaw, surface="pine", penetrable=False,
         contact=False)


def estanteria(name, room, origin, yaw, largo, prof=0.32, alto=1.90,
               baldas=5, libros=True, mat="House_Wood"):
    p = []
    p.append(box((0.0, alto * 0.5, 0.0), (prof, alto, 0.02), mat, 0.004))   # trasera
    for sign in (-1, 1):
        p.append(box((0.0, alto * 0.5, sign * (largo * 0.5 - 0.012)),
                     (prof, alto, 0.025), mat, 0.005))
    for i in range(baldas + 1):
        y = 0.02 + i * (alto - 0.04) / baldas
        p.append(box((0.0, y, 0.0), (prof, 0.025, largo - 0.04), mat, 0.004))
    if libros:
        ## Libros como parte del mueble: comparten colision, no cuestan cuerpos.
        rng = [0.55, 0.72, 0.41, 0.63, 0.48, 0.68, 0.37, 0.59]
        for i in range(1, baldas + 1):
            y = 0.02 + i * (alto - 0.04) / baldas + 0.012
            z = -largo * 0.5 + 0.10
            for k in range(6):
                grosor = 0.035 + (rng[(i * 6 + k) % 8] * 0.02)
                alto_li = 0.17 + rng[(i + k) % 8] * 0.07
                if z + grosor > largo * 0.5 - 0.08:
                    break
                p.append(box((-0.02, y + alto_li * 0.5, z + grosor * 0.5),
                             (0.19, alto_li, grosor),
                             "House_Linen" if k % 3 else "House_Rug", 0.003))
                z += grosor + 0.006
    prop(name, room, origin, p, yaw=yaw, surface="pine", penetrable=False)


def armario(name, room, origin, yaw, largo=1.80, prof=0.60, alto=2.10,
            puertas=2, mat="House_Wood"):
    """Frente local +X: la profundidad va en X y el largo en Z."""
    p = []
    p.append(box((0.0, alto * 0.5, 0.0), (0.02, alto, largo), mat, 0.004))
    for sign in (-1, 1):
        p.append(box((0.0, alto * 0.5, sign * (largo * 0.5 - 0.015)),
                     (prof, alto, 0.03), mat, 0.005))
    p.append(box((0.0, alto - 0.015, 0.0), (prof, 0.03, largo), mat, 0.006))
    p.append(box((0.0, 0.015, 0.0), (prof, 0.03, largo), mat, 0.006))
    ancho_p = (largo - 0.04) / puertas
    for i in range(puertas):
        z = -largo * 0.5 + 0.02 + ancho_p * (i + 0.5)
        p.append(box((prof * 0.5 - 0.01, alto * 0.5, z),
                     (0.02, alto - 0.06, ancho_p - 0.02), mat, 0.006))
        lado = 1 if i % 2 == 0 else -1
        p.append(box((prof * 0.5 + 0.005, alto * 0.52, z + lado * (ancho_p * 0.5 - 0.06)),
                     (0.03, 0.16, 0.025), "House_Metal", 0.004))
    prop(name, room, origin, p, yaw=yaw, surface="pine", penetrable=False)


def cama(name, room, origin, yaw, ancho=1.60, largo=2.00, con_mesas=True):
    """Cabezal en -X local (los pies miran a +X)."""
    p = []
    p.append(box((-0.02, 0.22, 0.0), (largo - 0.06, 0.30, ancho), "House_Wood", 0.012))
    p.append(box((-largo * 0.5 + 0.04, 0.55, 0.0), (0.08, 0.80, ancho), "House_Wood", 0.012))
    p.append(box((0.0, 0.44, 0.0), (largo - 0.14, 0.20, ancho - 0.06), "House_Linen", 0.03))
    p.append(box((0.14, 0.56, 0.0), (largo - 0.42, 0.10, ancho - 0.02), "House_Linen", 0.045))
    for sign in (-1, 1):
        p.append(box((-largo * 0.5 + 0.34, 0.58, sign * (ancho * 0.28)),
                     (0.34, 0.13, ancho * 0.34), "House_Linen", 0.045))
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.append(box((sx * (largo * 0.5 - 0.14), 0.04, sz * (ancho * 0.5 - 0.10)),
                         (0.08, 0.08, 0.08), "House_Wood", 0.01))
    prop(name, room, origin, p, yaw=yaw, surface="pine", penetrable=True)


def mesita(name, room, origin, yaw):
    p = [box((0.0, 0.27, 0.0), (0.44, 0.54, 0.42), "House_Wood", 0.008)]
    p.append(box((0.225, 0.40, 0.0), (0.02, 0.22, 0.36), "House_Wood", 0.004))
    p.append(box((0.225, 0.40, 0.0), (0.03, 0.03, 0.10), "House_Metal", 0.004))
    p.append(box((0.0, 0.555, 0.0), (0.46, 0.03, 0.44), "House_Wood", 0.006))
    prop(name, room, origin, p, yaw=yaw, surface="pine", penetrable=False)


def comoda(name, room, origin, yaw, largo=1.30, prof=0.48, alto=0.85, cajones=3):
    p = [box((0.0, alto * 0.5, 0.0), (prof, alto, largo), "House_Wood", 0.008)]
    p.append(box((0.0, alto + 0.015, 0.0), (prof + 0.03, 0.03, largo + 0.02),
                 "House_Wood", 0.006))
    h = (alto - 0.10) / cajones
    for i in range(cajones):
        y = 0.05 + h * (i + 0.5)
        p.append(box((prof * 0.5 + 0.006, y, 0.0), (0.02, h - 0.02, largo - 0.04),
                     "House_Wood", 0.005))
        p.append(box((prof * 0.5 + 0.02, y, 0.0), (0.02, 0.03, 0.16),
                     "House_Metal", 0.004))
    prop(name, room, origin, p, yaw=yaw, surface="pine", penetrable=False)


def mueble_bajo(name, room, origin, yaw, largo, prof=0.62, alto=0.90, puertas=4,
                mat="House_Plaster"):
    p = []
    p.append(box((-0.03, 0.05, 0.0), (prof - 0.06, 0.10, largo), "House_Metal", 0.004))
    p.append(box((0.0, 0.50, 0.0), (prof, 0.70, largo), "House_Wood", 0.006))
    p.append(box((0.01, 0.875, 0.0), (prof + 0.06, 0.05, largo + 0.02), mat, 0.008))
    ancho_p = (largo - 0.04) / puertas
    for i in range(puertas):
        z = -largo * 0.5 + 0.02 + ancho_p * (i + 0.5)
        p.append(box((prof * 0.5 + 0.008, 0.50, z), (0.02, 0.66, ancho_p - 0.02),
                     mat, 0.005))
        p.append(box((prof * 0.5 + 0.022, 0.80, z), (0.02, 0.025, 0.14),
                     "House_Metal", 0.003))
    prop(name, room, origin, p, yaw=yaw, surface="pine", penetrable=False)


def muebles_altos(name, room, origin, yaw, largo, prof=0.35, alto=0.70,
                  puertas=3, mat="House_Plaster"):
    p = [box((0.0, alto * 0.5, 0.0), (prof, alto, largo), "House_Wood", 0.005)]
    ancho_p = (largo - 0.03) / puertas
    for i in range(puertas):
        z = -largo * 0.5 + 0.015 + ancho_p * (i + 0.5)
        p.append(box((prof * 0.5 + 0.008, alto * 0.5, z),
                     (0.02, alto - 0.04, ancho_p - 0.02), mat, 0.005))
        p.append(box((prof * 0.5 + 0.022, 0.12, z), (0.02, 0.025, 0.13),
                     "House_Metal", 0.003))
    prop(name, room, origin, p, yaw=yaw, surface="pine", penetrable=False,
         contact=False)


def frigorifico(name, room, origin, yaw):
    p = [box((0.0, 0.925, 0.0), (0.66, 1.85, 0.72), "House_Metal", 0.012)]
    p.append(box((0.335, 0.62, 0.0), (0.02, 1.24, 0.68), "House_Metal", 0.006))
    p.append(box((0.35, 1.30, 0.30), (0.03, 0.34, 0.04), "House_Metal", 0.006))
    prop(name, room, origin, p, yaw=yaw, surface="aluminum", penetrable=False)


def fregadero(name, room, origin):
    """Fregadero + grifo SIN colision: la cuenta se lleva el mueble de abajo."""
    p = []
    for sx, sz in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
        p.append(box((0.0, 0.905, sz * 0.34), (0.56, 0.03, 0.10),
                     "House_Metal", 0.006))
    for sx in (-1, 1):
        p.append(box((sx * 0.28, 0.905, 0.0), (0.10, 0.03, 0.58),
                     "House_Metal", 0.006))
    p.append(box((0.0, 0.84, 0.0), (0.50, 0.10, 0.58), "House_Metal", 0.01))
    p.append(cyl((-0.20, 1.06, 0.0), 0.028, 0.30, "House_Metal", 16))
    p.append(box((-0.10, 1.19, 0.0), (0.22, 0.03, 0.03), "House_Metal", 0.008))
    prop(name, room, origin, p, collider=False)


def placa(name, room, origin):
    p = [box((0.0, 0.016, 0.0), (0.56, 0.03, 0.54), "House_Glass", 0.006)]
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.append(cyl((sx * 0.14, 0.034, sz * 0.13), 0.07, 0.006,
                         "House_Metal", 16))
    prop(name, room, origin, p, collider=False)


def lavadora(name, room, origin, yaw):
    p = [box((0.0, 0.425, 0.0), (0.60, 0.85, 0.62), "House_Plaster", 0.012)]
    p.append(cyl((0.31, 0.44, 0.0), 0.21, 0.03, "House_Metal", 20, axis="x"))
    p.append(box((0.30, 0.76, 0.0), (0.03, 0.12, 0.54), "House_Metal", 0.006))
    prop(name, room, origin, p, yaw=yaw, surface="aluminum", penetrable=False)


def inodoro(name, room, origin, yaw):
    p = [box((-0.05, 0.32, 0.0), (0.34, 0.44, 0.38), "House_Plaster", 0.03)]
    p.append(box((-0.20, 0.74, 0.0), (0.16, 0.62, 0.44), "House_Plaster", 0.012))
    p.append(box((0.06, 0.56, 0.0), (0.44, 0.06, 0.40), "House_Plaster", 0.02))
    p.append(box((0.06, 0.60, 0.0), (0.42, 0.03, 0.36), "House_Linen", 0.02))
    prop(name, room, origin, p, yaw=yaw, surface="gypsum", penetrable=False)


def lavabo(name, room, origin, yaw, largo=1.10, mueble=True):
    p = []
    if mueble:
        p.append(box((0.0, 0.42, 0.0), (0.50, 0.84, largo), "House_Wood", 0.008))
        p.append(box((0.26, 0.42, 0.0), (0.02, 0.78, largo - 0.04),
                     "House_Plaster", 0.005))
    p.append(box((0.0, 0.87, 0.0), (0.54, 0.06, largo + 0.02), "House_Plaster", 0.01))
    p.append(box((0.0, 0.94, 0.0), (0.40, 0.10, largo - 0.22), "House_Plaster", 0.02))
    p.append(cyl((-0.14, 1.03, 0.0), 0.024, 0.24, "House_Metal", 16))
    p.append(box((-0.04, 1.13, 0.0), (0.20, 0.03, 0.03), "House_Metal", 0.008))
    prop(name, room, origin, p, yaw=yaw, surface="gypsum", penetrable=False)


def banera(name, room, origin, yaw, largo=1.70, ancho=0.72):
    p = []
    p.append(box((0.0, 0.28, 0.0), (largo, 0.56, ancho), "House_Plaster", 0.02))
    for sx, sz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        pass
    p.append(box((0.0, 0.56, 0.0), (largo + 0.02, 0.04, ancho + 0.02),
                 "House_Plaster", 0.015))
    p.append(box((0.0, 0.52, 0.0), (largo - 0.24, 0.06, ancho - 0.20),
                 "House_Linen", 0.02))
    p.append(cyl((-largo * 0.5 + 0.12, 0.74, 0.0), 0.026, 0.36, "House_Metal", 16))
    prop(name, room, origin, p, yaw=yaw, surface="gypsum", penetrable=False)


def ducha(name, room, origin, yaw, ancho=0.90):
    """Plato + mampara de vidrio. La mampara va con colision propia fina."""
    plato = [box((0.0, 0.05, 0.0), (ancho, 0.10, ancho), "House_Plaster", 0.012)]
    prop(name, room, origin, plato, yaw=yaw, surface="gypsum", penetrable=False,
         contact=False)
    mampara = [
        box((0.0, 1.02, 0.0), (0.05, 1.84, ancho), "House_Glass", 0.004),
        box((0.0, 1.94, 0.0), (0.07, 0.05, ancho), "House_Metal", 0.004),
        box((0.0, 1.02, -ancho * 0.5 + 0.02), (0.07, 1.84, 0.04), "House_Metal", 0.004),
        box((0.0, 1.02, ancho * 0.5 - 0.02), (0.07, 1.84, 0.04), "House_Metal", 0.004),
    ]
    prop(name + "_Mampara", room, (origin[0], origin[1], origin[2]), mampara,
         yaw=yaw, surface="gypsum", penetrable=True, thin_shell=0.006,
         contact=False)


def alfombra(name, room, origin, largo, ancho, mat="House_Rug"):
    p = [box((0.0, 0.012, 0.0), (largo, 0.024, ancho), mat, 0.004)]
    p.append(box((0.0, 0.014, 0.0), (largo - 0.16, 0.026, ancho - 0.16),
                 mat, 0.004))
    prop(name, room, origin, p, collider=False)


def lampara_pie(name, room, origin):
    p = [cyl((0.0, 0.03, 0.0), 0.17, 0.05, "House_Metal", 20),
         cyl((0.0, 0.75, 0.0), 0.022, 1.44, "House_Metal", 12),
         cone((0.0, 1.62, 0.0), 0.22, 0.17, 0.34, "House_Fabric", 20)]
    prop(name, room, origin, p, collider=False)


def lampara_colgante(name, room, origin, desc=1.10):
    techo = ALTURA
    p = [cyl((0.0, (techo + techo - desc) * 0.5, 0.0), 0.008, desc, "House_Metal", 8),
         cone((0.0, techo - desc - 0.10, 0.0), 0.24, 0.10, 0.26, "House_Metal", 20),
         cyl((0.0, techo - desc - 0.22, 0.0), 0.09, 0.03, "House_Linen", 16)]
    prop(name, room, origin, p, collider=False, contact=False)


def lampara_mesa(name, room, origin):
    p = [cyl((0.0, 0.02, 0.0), 0.09, 0.03, "House_Metal", 16),
         cyl((0.0, 0.14, 0.0), 0.016, 0.22, "House_Metal", 10),
         cone((0.0, 0.33, 0.0), 0.13, 0.10, 0.20, "House_Linen", 16)]
    prop(name, room, origin, p, collider=False, contact=False)


def cuadro(name, room, origin, yaw, ancho=0.60, alto=0.44):
    p = [box((0.0, 0.0, 0.0), (0.03, alto, ancho), "House_Wood", 0.006),
         box((0.015, 0.0, 0.0), (0.012, alto - 0.07, ancho - 0.07), "House_Linen", 0.003)]
    prop(name, room, origin, p, yaw=yaw, collider=False, contact=False)


def espejo(name, room, origin, yaw, ancho=0.90, alto=0.70, pared=None):
    p = [box((0.0, 0.0, 0.0), (0.04, alto, ancho), "House_Glass", 0.004),
         box((-0.01, 0.0, 0.0), (0.03, alto + 0.05, ancho + 0.05), "House_Wood", 0.006)]
    prop(name, room, origin, p, yaw=yaw, surface="gypsum", penetrable=True,
         thin_shell=0.02, contact=False)


def maceta(name, room, origin, radio=0.24, arbusto=0.42):
    p = [cone((0.0, 0.20, 0.0), radio * 0.78, radio, 0.40, "House_Concrete", 18),
         cyl((0.0, 0.41, 0.0), radio * 0.94, 0.03, "House_Wood", 18),
         blob((0.0, 0.42 + arbusto * 0.6, 0.0), arbusto, "House_Fabric", 1.25),
         blob((0.12, 0.42 + arbusto * 0.35, 0.10), arbusto * 0.6, "House_Fabric", 1.2)]
    prop(name, room, origin, p, shape="cylinder", surface="concrete",
         penetrable=False)


def consola(name, room, origin, yaw, largo=0.80, prof=0.30, alto=0.80):
    p = [box((0.0, alto - 0.02, 0.0), (prof, 0.04, largo), "House_Wood", 0.006)]
    for sign in (-1, 1):
        p.append(box((0.0, (alto - 0.04) * 0.5, sign * (largo * 0.5 - 0.03)),
                     (prof, alto - 0.04, 0.05), "House_Wood", 0.006))
    p.append(box((0.0, 0.22, 0.0), (prof - 0.06, 0.03, largo - 0.14), "House_Wood", 0.004))
    prop(name, room, origin, p, yaw=yaw, surface="pine", penetrable=False)


def radiador(name, room, origin, yaw, largo=1.20):
    p = []
    n = max(4, int(largo / 0.09))
    for i in range(n):
        z = -largo * 0.5 + (i + 0.5) * (largo / n)
        p.append(box((0.0, 0.36, z), (0.10, 0.52, largo / n - 0.02),
                     "House_Plaster", 0.008))
    p.append(box((0.0, 0.36, -largo * 0.5 - 0.01), (0.11, 0.05, 0.03),
                 "House_Metal", 0.004))
    p.append(box((0.0, 0.36, largo * 0.5 + 0.01), (0.11, 0.05, 0.03),
                 "House_Metal", 0.004))
    p.append(cyl((0.0, 0.10, -largo * 0.5 - 0.03), 0.02, 0.20, "House_Metal", 10))
    prop(name, room, origin, p, yaw=yaw, surface="steel", penetrable=False)


def toallero(name, room, origin, yaw, largo=0.60):
    p = [cyl((0.0, 1.20, 0.0), 0.016, largo, "House_Metal", 10, axis="z")]
    for sign in (-1, 1):
        p.append(box((-0.03, 1.20, sign * (largo * 0.5 - 0.02)),
                     (0.06, 0.05, 0.04), "House_Metal", 0.004))
    p.append(box((-0.05, 1.03, 0.0), (0.03, 0.36, largo - 0.06), "House_Linen", 0.01))
    prop(name, room, origin, p, yaw=yaw, collider=False, contact=False)


def escritorio(name, room, origin, yaw, largo=1.40, prof=0.55, alto=0.75):
    p = [box((0.0, alto - 0.025, 0.0), (prof, 0.05, largo), "House_Wood", 0.006)]
    for sz in (-1, 1):
        p.append(box((0.0, (alto - 0.05) * 0.5, sz * (largo * 0.5 - 0.06)),
                     (prof - 0.05, alto - 0.05, 0.05), "House_Wood", 0.006))
    p.append(box((0.0, 0.56, -largo * 0.5 + 0.28), (prof - 0.06, 0.30, 0.50),
                 "House_Wood", 0.006))
    p.append(box((prof * 0.5 - 0.02, 0.62, -largo * 0.5 + 0.28),
                 (0.03, 0.03, 0.22), "House_Metal", 0.004))
    prop(name, room, origin, p, yaw=yaw, surface="pine", penetrable=False)


def caja_carton(name, room, origin, size=0.52, rot=0.0):
    p = [box((0.0, size * 0.5, 0.0), (size, size, size * 0.92), "House_Linen", 0.012),
         box((0.0, size * 0.94, 0.0), (size * 0.98, 0.04, size * 0.6), "House_Rug", 0.006)]
    prop(name, room, origin, p, yaw=rot, surface="paper", penetrable=True)


def palé(name, room, origin, yaw):
    p = []
    for nivel in range(2):
        base = 0.16 * nivel + 0.08
        for i in range(4):
            z = -0.45 + i * 0.30
            p.append(box((0.0, base - 0.05, z), (1.20, 0.03, 0.16),
                         "House_Wood", 0.005))
        for i in range(3):
            x = -0.50 + i * 0.50
            p.append(box((x, base + 0.02, 0.0), (0.10, 0.04, 1.00),
                         "House_Wood", 0.005))
        for sz in (-1, 1):
            p.append(box((0.0, base - 0.02, sz * 0.46), (1.20, 0.05, 0.08),
                         "House_Wood", 0.005))
    prop(name, room, origin, p, yaw=yaw, surface="pine", penetrable=True)


def banco_jardin(name, room, origin, yaw, largo=1.60):
    p = []
    for i in range(3):
        z = -0.16 + i * 0.16
        p.append(box((0.0, 0.44, z), (largo, 0.04, 0.13), "House_Wood", 0.006))
    for i in range(3):
        y = 0.60 + i * 0.17
        p.append(box((-largo * 0.5 + 0.05, y, -0.20), (0.04, 0.13, largo - 0.10),
                     "House_Wood", 0.006))
    for sx in (-1, 1):
        p.append(box((sx * (largo * 0.5 - 0.10), 0.22, 0.0),
                     (0.06, 0.44, 0.44), "House_Metal", 0.006))
        p.append(box((sx * (largo * 0.5 - 0.10), 0.55, -0.20),
                     (0.05, 0.66, 0.05), "House_Metal", 0.006))
    prop(name, room, origin, p, yaw=yaw, surface="pine", penetrable=False)


def cubo(name, room, origin, radio=0.26, alto=1.00):
    p = [cone((0.0, alto * 0.5, 0.0), radio * 0.86, radio, alto, "House_Metal", 20),
         cyl((0.0, alto + 0.03, 0.0), radio * 1.04, 0.06, "House_Metal", 20)]
    prop(name, room, origin, p, shape="cylinder", surface="aluminum",
         penetrable=False)


def macetero(name, room, origin, largo=1.60, prof=0.50, alto=0.90):
    """Macetero de hormigon: COBERTURA del puesto 1, no es decoracion."""
    p = [box((0.0, alto * 0.5, 0.0), (largo, alto, prof), "House_Concrete", 0.02)]
    p.append(box((0.0, alto - 0.03, 0.0), (largo - 0.14, 0.06, prof - 0.14),
                 "House_Wood", 0.008))
    p.append(box((0.0, alto + 0.06, 0.0), (largo - 0.18, 0.14, prof - 0.18),
                 "House_Wood", 0.01))
    rng = [0.34, 0.46, 0.28, 0.52, 0.38, 0.30]
    for i in range(6):
        x = -largo * 0.5 + 0.20 + i * ((largo - 0.40) / 5.0)
        r = rng[i % 6]
        p.append(blob((x, alto + 0.18 + r * 0.5, (i % 3 - 1) * 0.06), r,
                      "House_Fabric", 1.3))
    prop(name, room, origin, p, surface="concrete", penetrable=False)


def puerta_entrada(name, room, origin, yaw, largo=0.95, alto=2.05):
    """Hoja abierta contra el muro: el paso se ve, no se imagina."""
    p = [box((0.0, alto * 0.5, 0.0), (0.045, alto, largo), "House_Wood", 0.006)]
    p.append(box((0.026, 1.02, -largo * 0.5 + 0.10), (0.03, 0.30, 0.60),
                 "House_Wood", 0.004))
    p.append(cyl((0.04, 1.02, -largo * 0.5 + 0.09), 0.022, 0.12,
                 "House_Metal", 12, axis="x"))
    for y in (0.20, 1.02, 1.86):
        p.append(cyl((-0.03, y, -largo * 0.5 + 0.02), 0.018, 0.06,
                     "House_Metal", 10, axis="z"))
    prop(name, room, origin, p, yaw=yaw, surface="pine", penetrable=True,
         thin_shell=0.045)


def tv(name, room, origin, yaw, ancho=1.30):
    p = [box((0.0, 0.36, 0.0), (0.05, 0.72, ancho), "House_Glass", 0.004),
         box((-0.03, 0.36, 0.0), (0.04, 0.76, ancho + 0.05), "House_Metal", 0.006),
         box((-0.04, -0.06, 0.0), (0.10, 0.04, 0.34), "House_Metal", 0.004)]
    prop(name, room, origin, p, yaw=yaw, surface="gypsum", penetrable=True,
         thin_shell=0.05, contact=False)


def mesa_cocina(name, room, origin, yaw, largo=0.90, ancho=0.60):
    mesa(name, room, origin, yaw, largo, ancho, alto=0.75)


# ---------------------------------------------------------------------------
# COLOCACION. Cada linea es una decision de arte con su cota.
# ---------------------------------------------------------------------------
def build_patio() -> None:
    macetero("Macetero_Patio", "patio", (-3.20, 0.0, 6.20))
    palé("Pales_Patio", "patio", (2.60, 0.0, 6.80), yaw=6.0)
    banco_jardin("Banco_Patio", "patio", (4.90, 0.0, 7.60), yaw=180.0)
    cubo("Cubo_Patio", "patio", (5.30, 0.0, 9.60))
    caja_carton("Cajas_Patio", "patio", (-5.10, 0.0, 9.20), size=0.56, rot=14.0)
    caja_carton("Cajas_Patio_2", "patio", (-4.75, 0.56, 9.05), size=0.44, rot=-9.0)
    maceta("Maceta_Patio", "patio", (0.95, 0.0, 4.60), radio=0.26, arbusto=0.40)


def build_pasillo_pb() -> None:
    consola("Consola_Pasillo", "pasillo", (-0.40, 0.0, -3.20), yaw=0.0)
    alfombra("Alfombra_Pasillo", "pasillo", (0.0, 0.0, 1.40), 2.60, 0.90)
    cuadro("Cuadro_Pasillo_1", "pasillo", (-0.66, 1.55, 0.40), yaw=0.0,
           ancho=0.70, alto=0.50)
    cuadro("Cuadro_Pasillo_2", "pasillo", (-0.66, 1.55, -4.80), yaw=0.0,
           ancho=0.52, alto=0.68)
    puerta_entrada("Puerta_Entrada", "pasillo", (0.677, 0.0, 3.405), yaw=0.0)


def build_salon() -> None:
    sofa("Sofa_Salon", "salon", (-3.60, 0.0, 1.60), yaw=0.0)
    mesa("Mesa_Aux_Salon", "salon", (-2.60, 0.0, 1.60), yaw=0.0, largo=1.10,
         ancho=0.55, alto=0.42)
    mueble_tv("Mueble_TV_Salon", "salon", (-1.06, 0.0, 1.60), yaw=0.0)
    tv("TV_Salon", "salon", (-1.12, 0.53, 1.60), yaw=0.0, ancho=1.30)
    estanteria("Estanteria_Salon", "salon", (-0.98, 0.0, -0.10), yaw=0.0,
               largo=1.20, prof=0.32, alto=1.90)
    butaca("Butaca_Salon", "salon", (-2.20, 0.0, -0.40), yaw=-90.0)
    lampara_pie("Lampara_Salon", "salon", (-4.55, 0.0, -0.30))
    alfombra("Alfombra_Salon", "salon", (-2.85, 0.0, 1.60), 2.60, 1.80)
    radiador("Radiador_Salon", "salon", (-3.30, 0.0, 3.70), yaw=0.0, largo=1.20)
    maceta("Maceta_Salon", "salon", (-1.20, 0.0, 3.40))
    cuadro("Cuadro_Salon_1", "salon", (-3.40, 1.60, -0.90), yaw=0.0,
           ancho=0.86, alto=0.56)
    cuadro("Cuadro_Salon_2", "salon", (-2.10, 1.60, -0.90), yaw=0.0,
           ancho=0.54, alto=0.70)
    cuadro("Cuadro_Salon_3", "salon", (-4.84, 1.55, 3.10), yaw=0.0,
           ancho=0.60, alto=0.44)


def mueble_tv(name, room, origin, yaw):
    p = [box((0.0, 0.24, 0.0), (0.46, 0.48, 1.60), "House_Wood", 0.008),
         box((0.0, 0.50, 0.0), (0.50, 0.04, 1.66), "House_Wood", 0.006)]
    for i in range(3):
        z = -0.53 + i * 0.53
        p.append(box((0.236, 0.24, z), (0.02, 0.42, 0.49), "House_Plaster", 0.005))
        p.append(box((0.25, 0.36, z), (0.02, 0.03, 0.16), "House_Metal", 0.003))
    prop(name, room, origin, p, yaw=yaw, surface="pine", penetrable=False)


def build_comedor() -> None:
    mesa("Mesa_Comedor", "comedor", (2.90, 0.0, 1.30), yaw=0.0, largo=1.60,
         ancho=0.90, alto=0.75)
    silla("Silla_Comedor_1", "comedor", (2.55, 0.0, 0.62), yaw=-90.0)
    silla("Silla_Comedor_2", "comedor", (3.25, 0.0, 0.62), yaw=-90.0)
    silla("Silla_Comedor_3", "comedor", (2.55, 0.0, 1.98), yaw=90.0)
    silla("Silla_Comedor_4", "comedor", (3.25, 0.0, 1.98), yaw=90.0)
    silla("Silla_Comedor_5", "comedor", (1.90, 0.0, 1.30), yaw=0.0)
    comoda("Aparador_Comedor", "comedor", (4.62, 0.0, 0.10), yaw=180.0,
           largo=1.60, prof=0.50, alto=0.85, cajones=2)
    lampara_colgante("Lampara_Comedor", "comedor", (2.90, 0.0, 1.30), desc=1.05)
    alfombra("Alfombra_Comedor", "comedor", (2.90, 0.0, 1.30), 2.40, 1.60)
    maceta("Maceta_Comedor", "comedor", (4.50, 0.0, 3.30))
    cuadro("Cuadro_Comedor", "comedor", (4.84, 1.58, 2.60), yaw=0.0,
           ancho=0.66, alto=0.50)


def build_cocina() -> None:
    mueble_bajo("Fregadero_Cocina", "cocina", (-4.57, 0.0, -4.10), yaw=0.0,
                largo=3.00, puertas=4)
    fregadero("Fregadero", "cocina", (-4.57, 0.0, -4.60))
    placa("Placa_Cocina", "cocina", (-4.55, 0.0, -3.40))
    mueble_bajo("Armario_Cocina", "cocina", (-2.98, 0.0, -5.57), yaw=90.0,
                largo=2.56, puertas=3)
    muebles_altos("Cajalera_Cocina", "cocina", (-4.71, 1.45, -4.00), yaw=0.0,
                  largo=2.40, puertas=3)
    frigorifico("Frigorifico", "cocina", (-1.25, 0.0, -5.52), yaw=0.0)
    estanteria("Despensa_Cocina", "cocina", (-1.00, 0.0, -1.61), yaw=0.0,
               largo=1.10, prof=0.35, alto=1.85, baldas=4)
    mesa_cocina("Mesa_Cocina", "cocina", (-3.00, 0.0, -3.00), yaw=0.0)
    silla("Silla_Cocina_1", "cocina", (-3.00, 0.0, -3.62), yaw=90.0)
    silla("Silla_Cocina_2", "cocina", (-3.78, 0.0, -3.00), yaw=0.0)
    cubo("Cubo_Cocina", "cocina", (-4.52, 0.0, -2.15), radio=0.20, alto=0.55)
    cuadro("Cuadro_Cocina", "cocina", (-0.86, 1.60, -4.60), yaw=0.0,
           ancho=0.50, alto=0.40)


def build_bano_pb() -> None:
    lavabo("Lavabo_Bano", "bano_pb", (4.62, 0.0, -5.20), yaw=180.0, largo=1.10)
    espejo("Espejo_Bano", "bano_pb", (4.85, 1.45, -5.20), yaw=180.0,
           ancho=0.90, alto=0.70)
    inodoro("Inodoro_Bano", "bano_pb", (2.62, 0.0, -5.52), yaw=-90.0)
    ducha("Ducha_Bano", "bano_pb", (4.30, 0.0, -4.00), yaw=0.0)
    toallero("Toallero_Bano", "bano_pb", (3.42, 0.0, -5.84), yaw=0.0, largo=0.60)
    alfombra("Alfombra_Bano", "bano_pb", (3.30, 0.0, -4.40), 1.20, 0.70,
             mat="House_Linen")


def build_lavadero() -> None:
    lavadora("Lavadora", "lavadero", (2.70, 0.0, -1.36), yaw=0.0)
    estanteria("Estante_Lavadero", "lavadero", (4.68, 0.0, -2.60), yaw=180.0,
               largo=1.20, prof=0.36, alto=1.80, baldas=4, libros=False)
    cubo("Cubo_Lavadero", "lavadero", (3.60, 0.0, -2.90), radio=0.22, alto=0.52)
    toallero("Toallero_Lavadero", "lavadero", (4.84, 0.0, -1.60), yaw=180.0,
             largo=0.55)
    caja_carton("Cajas_Lavadero", "lavadero", (2.72, 0.87, -1.36), size=0.44, rot=5.0)


def build_dorm1() -> None:
    armario("Armario_Dorm1", "dorm1", (2.10, NIVEL_ALTA, -0.64), yaw=-90.0,
            largo=2.00, prof=0.60, alto=2.10, puertas=3)
    cama("Cama_Dorm1", "dorm1", (3.88, NIVEL_ALTA, 1.60), yaw=180.0,
         ancho=1.60, largo=2.00)
    mesita("Mesita_Dorm1_1", "dorm1", (4.60, NIVEL_ALTA, 0.30), yaw=180.0)
    mesita("Mesita_Dorm1_2", "dorm1", (4.60, NIVEL_ALTA, 2.90), yaw=180.0)
    comoda("Comoda_Dorm1", "dorm1", (1.10, NIVEL_ALTA, 2.60), yaw=0.0,
           largo=1.30, prof=0.52, alto=0.85, cajones=3)
    espejo("Espejo_Dorm1", "dorm1", (1.02, NIVEL_ALTA + 0.85, 1.40), yaw=0.0,
           ancho=0.55, alto=1.70)
    lampara_mesa("Lampara_Dorm1", "dorm1", (4.60, NIVEL_ALTA + 0.57, 0.30))
    alfombra("Alfombra_Dorm1", "dorm1", (3.20, NIVEL_ALTA, 3.10), 2.40, 1.40)
    radiador("Radiador_Dorm1", "dorm1", (3.40, NIVEL_ALTA, 3.70), yaw=0.0, largo=1.20)
    cuadro("Cuadro_Dorm1", "dorm1", (1.60, NIVEL_ALTA + 1.55, 3.84), yaw=180.0,
           ancho=0.70, alto=0.50)


def build_dorm2() -> None:
    cama("Cama_Dorm2", "dorm2", (-3.00, NIVEL_ALTA, 0.06), yaw=-90.0,
         ancho=1.50, largo=2.00)
    mesita("Mesita_Dorm2_1", "dorm2", (-3.98, NIVEL_ALTA, -0.62), yaw=90.0)
    mesita("Mesita_Dorm2_2", "dorm2", (-2.02, NIVEL_ALTA, -0.62), yaw=90.0)
    escritorio("Escritorio_Dorm2", "dorm2", (-4.60, NIVEL_ALTA, 3.58), yaw=180.0,
               largo=1.40, prof=0.55)
    silla("Silla_Dorm2", "dorm2", (-3.10, NIVEL_ALTA, 3.02), yaw=-90.0)
    estanteria("Estante_Dorm2", "dorm2", (-1.00, NIVEL_ALTA, -0.10), yaw=0.0,
               largo=1.20, prof=0.36, alto=1.85, baldas=5)
    alfombra("Alfombra_Dorm2", "dorm2", (-2.60, NIVEL_ALTA, 2.60), 2.20, 1.60)
    cuadro("Cuadro_Dorm2", "dorm2", (-0.86, NIVEL_ALTA + 1.55, -0.50), yaw=0.0,
           ancho=0.56, alto=0.44)
    lampara_mesa("Lampara_Dorm2", "dorm2", (-3.98, NIVEL_ALTA + 0.57, -0.62))


def build_dorm3() -> None:
    cama("Cama_Dorm3", "dorm3", (-1.795, NIVEL_ALTA, -3.00), yaw=180.0,
         ancho=1.40, largo=1.95)
    mesita("Mesita_Dorm3_1", "dorm3", (-1.18, NIVEL_ALTA, -3.95), yaw=180.0)
    mesita("Mesita_Dorm3_2", "dorm3", (-1.18, NIVEL_ALTA, -2.05), yaw=180.0)
    armario("Armario_Dorm3", "dorm3", (-3.90, NIVEL_ALTA, -4.02), yaw=-90.0,
            largo=1.50, prof=0.56, alto=2.10, puertas=2)
    comoda("Comoda_Dorm3", "dorm3", (-3.40, NIVEL_ALTA, -1.38), yaw=90.0,
           largo=1.10, prof=0.44, alto=0.85, cajones=3)
    alfombra("Alfombra_Dorm3", "dorm3", (-2.00, NIVEL_ALTA, -2.60), 2.00, 1.40)
    cuadro("Cuadro_Dorm3", "dorm3", (-1.60, NIVEL_ALTA + 1.55, -1.10), yaw=90.0,
           ancho=0.62, alto=0.46)
    lampara_mesa("Lampara_Dorm3", "dorm3", (-1.18, NIVEL_ALTA + 0.57, -3.95))


def build_bano_alta() -> None:
    banera("Banera_Bano", "bano_alta", (-3.90, NIVEL_ALTA, -5.50), yaw=0.0)
    inodoro("Inodoro_Bano", "bano_alta", (-1.22, NIVEL_ALTA, -5.52), yaw=-90.0)
    lavabo("Lavabo_Bano", "bano_alta", (-2.10, NIVEL_ALTA, -5.62), yaw=-90.0,
           largo=0.70, mueble=False)
    espejo("Espejo_Bano", "bano_alta", (-2.10, NIVEL_ALTA + 1.50, -5.85),
           yaw=-90.0, ancho=0.62, alto=0.70)
    toallero("Toallero_Bano", "bano_alta", (-3.50, NIVEL_ALTA, -4.50), yaw=90.0,
             largo=0.60)
    alfombra("Alfombra_Bano", "bano_alta", (-2.20, NIVEL_ALTA, -4.85), 1.00, 0.60,
             mat="House_Linen")


def build_estudio() -> None:
    escritorio("Escritorio_Estudio", "estudio", (4.60, NIVEL_ALTA, -5.10),
               yaw=180.0, largo=1.40, prof=0.55)
    silla("Silla_Estudio", "estudio", (4.05, NIVEL_ALTA, -5.10), yaw=0.0)
    estanteria("Estante_Estudio", "estudio", (3.20, NIVEL_ALTA, -5.66), yaw=0.0,
               largo=1.40, prof=0.36, alto=1.90, baldas=5)
    cama("Cama_Estudio", "estudio", (2.80, NIVEL_ALTA, -2.04), yaw=90.0,
         ancho=0.88, largo=1.95, con_mesas=False)
    mesita("Mesita_Estudio", "estudio", (3.50, NIVEL_ALTA, -1.30), yaw=-90.0)
    alfombra("Alfombra_Estudio", "estudio", (3.60, NIVEL_ALTA, -3.60), 1.80, 1.40)
    cuadro("Cuadro_Estudio", "estudio", (2.32, NIVEL_ALTA + 1.55, -4.80), yaw=0.0,
           ancho=0.58, alto=0.44)
    lampara_mesa("Lampara_Estudio", "estudio", (4.55, NIVEL_ALTA + 0.77, -4.55))


def build_pasillo_alta() -> None:
    consola("Consola_Pasillo", "pasillo_alta", (0.55, NIVEL_ALTA, -0.55), yaw=0.0)
    alfombra("Alfombra_Pasillo", "pasillo_alta", (0.0, NIVEL_ALTA, 1.60), 3.00, 0.90)
    maceta("Maceta_Pasillo", "pasillo_alta", (-0.34, NIVEL_ALTA, 3.50),
           radio=0.20, arbusto=0.34)
    cuadro("Cuadro_Pasillo", "pasillo_alta", (-0.66, NIVEL_ALTA + 1.55, -3.60),
           yaw=0.0, ancho=0.66, alto=0.48)


# ---------------------------------------------------------------------------
# Comprobaciones previas a exportar
# ---------------------------------------------------------------------------
def check() -> None:
    fallos: list[str] = []
    boxes: list[tuple] = []
    for p in PROPS:
        x0, x1, z0, z1, y0, y1 = p["world"]
        rx0, rx1, rz0, rz1, floor = ROOMS[p["room"]]
        if x0 < rx0 - TOL or x1 > rx1 + TOL:
            fallos.append("%s: x [%.2f, %.2f] fuera de %s [%.2f, %.2f]"
                          % (p["name"], x0, x1, p["room"], rx0, rx1))
        if z0 < rz0 - TOL or z1 > rz1 + TOL:
            fallos.append("%s: z [%.2f, %.2f] fuera de %s [%.2f, %.2f]"
                          % (p["name"], z0, z1, p["room"], rz0, rz1))
        if y0 < floor - TOL:
            fallos.append("%s: se hunde %.3f m bajo el suelo de %s"
                          % (p["name"], floor - y0, p["room"]))
        if y1 > floor + ALTURA + TOL:
            fallos.append("%s: sube a %.2f y el techo de %s esta en %.2f"
                          % (p["name"], y1, p["room"], floor + ALTURA))
        if p["collider"]:
            boxes.append((p["name"], x0, x1, z0, z1, y0, y1))

    ## Dos cuerpos fisicos que se solapan es una bala que golpea a ciegas.
    for i in range(len(boxes)):
        for j in range(i + 1, len(boxes)):
            a, b = boxes[i], boxes[j]
            ox = min(a[2], b[2]) - max(a[1], b[1])
            oy = min(a[6], b[6]) - max(a[5], b[5])
            oz = min(a[4], b[4]) - max(a[3], b[3])
            if ox > 0.05 and oy > 0.05 and oz > 0.05:
                fallos.append("%s y %s solapan %.2f/%.2f/%.2f m"
                              % (a[0], b[0], ox, oy, oz))
    if fallos:
        for f in fallos:
            print("  FALLO:", f)
        raise SystemExit("build_props: %d problemas de cota; NO se exporta" % len(fallos))


def stats(out_path: Path) -> None:
    tris = 0
    for obj in PROPS_OBJ:
        tris += sum(len(poly.vertices) - 2 for poly in obj.data.polygons)
    colliders = sum(1 for p in PROPS if p["collider"])
    por_sala: dict[str, int] = {}
    for p in PROPS:
        por_sala[p["room"]] = por_sala.get(p["room"], 0) + 1
    kb = out_path.stat().st_size / 1024.0
    print("PROPS %s  %.0f KB  tris=%d  nodos=%d  colisiones=%d  materiales=%d"
          % (out_path, kb, tris, len(PROPS), colliders, len(MATERIALES)))
    print("PROPS por cuarto:", ", ".join(f"{k}={v}" for k, v in sorted(por_sala.items())))


PROPS_OBJ: list = []


def build() -> None:
    global PROPS_OBJ
    reset_scene()
    for name in MATERIALES:
        MAT[name] = material(name)

    build_patio()
    build_pasillo_pb()
    build_salon()
    build_comedor()
    build_cocina()
    build_bano_pb()
    build_lavadero()
    build_dorm1()
    build_dorm2()
    build_dorm3()
    build_bano_alta()
    build_estudio()
    build_pasillo_alta()

    check()
    PROPS_OBJ = [o for o in bpy.context.scene.objects if o.type == "MESH"]

    MODELS.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in PROPS_OBJ:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = PROPS_OBJ[0]
    bpy.ops.export_scene.gltf(
        filepath=str(OUT),
        use_selection=True,
        export_format="GLB",
        export_apply=False,
        export_texcoords=True,
        export_normals=True,
        export_tangents=False,
        export_materials="EXPORT",
        ## SIN texturas dentro del GLB: la fuente unica es assets/textures/real.
        export_image_format="NONE",
        ## EL CONTRATO: extras del nodo -> metadata/extras en Godot.
        export_extras=True,
    )
    stats(OUT)


if __name__ == "__main__":
    build()
