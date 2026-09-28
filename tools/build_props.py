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
repartir: el shell pone la caja, este GLB pone los muebles. Las cotas de la
casa NO estan escritas a mano aqui: se miden en cada ejecucion leyendo
``scenes/House.tscn`` (solo lectura), y ``docs/HOUSE_DESIGN.md`` es la ficha
de arte que este script se limita a no tocar.

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
pasa del techo, que todo ``surface`` existe en ``Ballistics.MATERIALS``, que
dos cuerpos no se solapan y que NINGUNA caja de prop se mete dentro de la
casa. La casa se lee de ``scenes/House.tscn`` en modo SOLO LECTURA (240
colisionadores con su forma y su ``position``): este script no la escribe ni
la mueve, solo comprueba contra ella. Si algo falla, no se escribe el GLB.

Ademas recorre la planta baja en malla (BFS con la capsula del jugador,
radio 0,34, como ``tools/check_walk.gd``) y exige que desde el spawn siga
habiendo camino hasta ``z < -1,0`` y hasta ``x < -2,5``. Si un mueble tapa
esa ruta se imprime un AVISO con el culpable: el GLB se escribe igual,
porque mover el mueble es decision de arte y no del check.

MATERIALES: los NOMBRES son claves de ``CombatMap.MAPS``. La casa ya engancha
sus texturas por nombre en runtime, de modo que un nombre que no este en ese
mapa dejaria el enganche de los props sin resolver en el futuro.
"""

from __future__ import annotations

import math
import re
from collections import deque
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
## Los NOMBRES son a proposito claves de ``CombatMap.MAPS``: la casa engancha
## sus texturas por nombre en runtime y el mismo nombre resuelto en los props
## deja el enganche futuro sin casos pendientes. Solo se declaran los que se
## usan.
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
    "House_Gypsum": {
        ## Sin textura a proposito: papel y blanco de mueble de baño, y el yeso
        ## del repo es gris medio (0,39 sRGB) que solo se consigue multiplicando
        ## por 6. El enganche por nombre de runtime le pone su textura encima.
        "albedo": "", "rough": "", "normal": "",
        "color": (0.88, 0.86, 0.82),
        "metallic": 0.0, "roughness": 0.34, "normal_scale": 0.0, "tile": 1.0,
    },
    "House_Tile": {
        ## LA obra del lote: macetas y cajonera de hormigon, mismo gris calido
        ## que la losa del patio en CombatMap.
        "albedo": "concrete_brushed_concrete_diff.jpg",
        "rough": "concrete_brushed_concrete_rough.jpg",
        "normal": "concrete_brushed_concrete_nor_gl.jpg",
        "color": (0.74, 0.74, 0.76),
        "metallic": 0.0, "roughness": 0.82, "normal_scale": 0.6, "tile": 2.4,
    },
    "House_Fabric": {
        ## Trampa medida: el repo no tiene tela. El yeso es el unico ruido fino
        ## y neutro que hay; a tile 0,40 m y tinte calido lee como tejido, y
        ## cubre tapiceria, alfombras, cuadros y arbustos.
        "albedo": "gypsum_diff.jpg", "rough": "gypsum_rough.jpg", "normal": "",
        "color": (1.10, 1.02, 0.90),
        "metallic": 0.0, "roughness": 0.96, "normal_scale": 0.0, "tile": 0.40,
    },
}

# ---------------------------------------------------------------------------
# Cotas de la casa. Estas son las que mide scenes/House.tscn HOY, y check() las
# vuelve a comprobar contra los 240 colisionadores que lee de ahi: si la casa
# cambia, el builder se queja en el acto en vez de exportar muebles embebidos.
# ---------------------------------------------------------------------------
NIVEL_ALTA = 3.00    # cara superior de la losa alta (y=2,80..3,00) = piso de arriba

## Interior de cada cuarto: (x0, x1, z0, z1, y_piso, altura libre). Las caras de
## muro ya estan descontadas: un mueble que se salga de aqui atraviesa un muro.
##   PB (y=0)  techo = cara inferior de la losa alta, y=2,80
##   PA (y=3)  techo = cara inferior del tejado, y=5,60 -> 2,60 de altura libre
##   patio     techo = la tabla del porche, y=2,63 (mas bajo que el alero)
## La galeria arranca en z=-0,96: al norte de ahi esta la caja del hueco de la
## escalera, que no tiene losa en toda su anchura.
ROOMS: dict[str, tuple] = {
    "patio":   (-7.40, 7.40, 4.60, 8.60, 0.00, 2.63),
    "salon":   (-5.36, -0.98, -6.28, 4.36, 0.00, 2.80),
    "pasillo": (-0.82, 1.82, -6.28, 4.36, 0.00, 2.80),
    "cocina":  (1.98, 6.30, -2.20, 4.36, 0.00, 2.80),
    "bano":    (1.98, 6.30, -6.28, -2.36, 0.00, 2.80),
    "dorm":    (-5.36, -0.98, -6.28, 4.36, NIVEL_ALTA, 2.60),
    ## GALERIA = solo la galeria SUR. Al norte de z=+0,56 esta el HUECO de la
    ## escalera (x 0,95..1,82, z -2,60..+0,56) y, pegado a el, el corredor oeste
    ## de 1,67 m (x -0,82..0,85) que une galeria sur y norte: los dos son
    ## CIRCULACION, no sitio de mueble. El rect viejo (-0,96..4,36) metia el
    ## mueble encima del hueco y no lo veia nadie porque el hueco se movio en
    ## `build_house.py` y este fichero no se entero.
    "galeria": (-0.82, 1.82, 0.56, 4.36, NIVEL_ALTA, 2.60),
    "estudio": (1.98, 6.30, -6.28, 4.36, NIVEL_ALTA, 2.60),
}

EPS = 0.005          # tolerancia de cota: cero piezas hundidas en muro/suelo
SOLAPE = 0.02        # un solape de 2 cm ya es un cuerpo dentro de otro

PROPS: list[dict] = []
## Piezas DECORATIVAS sin colisor (alfombras, cuadros, lamparas de pie): se
## fusionan en UN nodo antes de exportar. Cada una era un MeshInstance con
## 1-2 superficies = un draw; 12 piezas eran ~19 draws de 97. El contrato de
## runtime no las echa de menos: `CombatMap._props` solo levanta colisor para
## nodos con `col_shape`, y el merge no toca piezas con colisor ni su cota.
DECOR_OBJ: list = []
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
        links.new(coords.outputs["UV"], mapping.inputs["Vector"])
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
    """Icosfera barata: macetas y jardineras."""
    cx, cy, cz = center
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=1, radius=radius)
    for vert in bm.verts:
        vert.co.z *= squash
    offset = G(cx, cy, cz)
    for vert in bm.verts:
        vert.co += offset
    return _obj("p", bm, mat_name)


def twigs(center, radius: float, mat_name: str, n: int = 7, alto: float = 0.5):
    """Matas de RAMAS SECAS: n prismas finos abiertos en abanico desde un punto.
    Sustituye al `blob` de arbusto, y el motivo es la referencia: ref4 y ref2 son
    INVIERNO (los arboles del fondo estan pelados). Una icosfera facetada de
    0,5 m pintada de gris azulado no lee a arbusto, lee a ROCA — medido en
    captura depot, donde las dos matas del macetero salian como dos pedruscos
    grises flotando sobre el hormigon."""
    cx, cy, cz = center
    bm = bmesh.new()
    for k in range(n):
        ang = math.tau * k / n + (k % 3) * 0.21
        ln = radius * (0.9 + 0.3 * ((k * 7) % 5) / 5.0)
        d = Vector((math.cos(ang), 0.0, math.sin(ang)))
        side = Vector((-math.sin(ang), 0.0, math.cos(ang)))
        w = radius * 0.055
        base = Vector((cx, cy, cz))
        tip = base + d * ln + Vector((0.0, ln * (0.7 + 0.5 * alto), 0.0))
        v = [bm.verts.new(G(*(base + side * w))),
             bm.verts.new(G(*(base - side * w))),
             bm.verts.new(G(*(tip + side * w * 0.2))),
             bm.verts.new(G(*(tip - side * w * 0.2)))]
        for tri in ([v[0], v[1], v[3]], [v[0], v[3], v[2]]):
            try:
                bm.faces.new(tri)
            except ValueError:
                pass
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
    uv = bm.loops.layers.uv.verify()
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
    ## puede ir girada y la cota del cuarto se cumple en ejes de mundo). Blender
    ## rota su eje +Y, que es el -Z de Godot, de ahi el signo de wz.
    c, s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    corners = [(lo.x, lo.y), (lo.x, hi.y), (hi.x, lo.y), (hi.x, hi.y)]
    wx = [origin[0] + c * px - s * py for px, py in corners]
    wz = [origin[2] - (s * px + c * py) for px, py in corners]
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
            reach_x = max(abs(min(wx) - origin[0]), abs(max(wx) - origin[0]))
            reach_z = max(abs(min(wz) - origin[2]), abs(max(wz) - origin[2]))
            obj["contact"] = [round(reach_x, 3), round(reach_z, 3)]
    obj["room"] = room
    if not collider:
        DECOR_OBJ.append(obj)
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
    ## TAPICERIA = COBERTURA REAL: la bala NO atraviesa el mueble, igual que los
    ## muebles horneados de la casa. Un sofa es sitio donde esconderse.
    prop(name, room, origin, p, yaw=yaw, surface="pine", penetrable=False)


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
    ## Trasera pegada al muro (x = -prof): antes iba en el centro y salia un
    ## tabique cruzado en medio del mueble.
    p.append(box((-prof * 0.5 + 0.01, alto * 0.5, 0.0), (0.02, alto, largo),
                 mat, 0.004))
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
                             "House_Gypsum" if k % 3 else "House_Fabric", 0.003))
                z += grosor + 0.006
    prop(name, room, origin, p, yaw=yaw, surface="pine", penetrable=False)


def armario(name, room, origin, yaw, largo=1.80, prof=0.60, alto=2.10,
            puertas=2, mat="House_Wood"):
    """Frente local +X: la profundidad va en X y el largo en Z."""
    p = []
    ## Trasera pegada al muro: con la pieza en x=0 salia un tabique por el
    ## centro del ropero y el fondo quedaba abierto.
    p.append(box((-prof * 0.5 + 0.01, alto * 0.5, 0.0), (0.02, alto, largo),
                 mat, 0.004))
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


def cama(name, room, origin, yaw, ancho=1.60, largo=2.00):
    """Cabezal en -X local (los pies miran a +X)."""
    p = []
    p.append(box((-0.02, 0.22, 0.0), (largo - 0.06, 0.30, ancho), "House_Wood", 0.012))
    p.append(box((-largo * 0.5 + 0.04, 0.55, 0.0), (0.08, 0.80, ancho), "House_Wood", 0.012))
    p.append(box((0.0, 0.44, 0.0), (largo - 0.14, 0.20, ancho - 0.06),
                 "House_Gypsum", 0.03))                              # colchon
    p.append(box((0.14, 0.56, 0.0), (largo - 0.42, 0.10, ancho - 0.02),
                 "House_Fabric", 0.045))                              # manta
    for sign in (-1, 1):
        p.append(box((-largo * 0.5 + 0.34, 0.58, sign * (ancho * 0.28)),
                     (0.34, 0.13, ancho * 0.34), "House_Gypsum", 0.045))
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.append(box((sx * (largo * 0.5 - 0.14), 0.04, sz * (ancho * 0.5 - 0.10)),
                         (0.08, 0.08, 0.08), "House_Wood", 0.01))
    ## COBERTURA: la cama es madera maciza, la bala no la cruza.
    prop(name, room, origin, p, yaw=yaw, surface="pine", penetrable=False)


def alfombra(name, room, origin, largo, ancho, mat="House_Fabric"):
    p = [box((0.0, 0.012, 0.0), (largo, 0.024, ancho), mat, 0.004)]
    p.append(box((0.0, 0.014, 0.0), (largo - 0.16, 0.026, ancho - 0.16),
                 mat, 0.004))
    prop(name, room, origin, p, collider=False)


def lampara_pie(name, room, origin):
    p = [cyl((0.0, 0.03, 0.0), 0.17, 0.05, "House_Metal", 20),
         cyl((0.0, 0.75, 0.0), 0.022, 1.44, "House_Metal", 12),
         cone((0.0, 1.62, 0.0), 0.22, 0.17, 0.34, "House_Fabric", 20)]
    prop(name, room, origin, p, collider=False)


def cuadro(name, room, origin, yaw, ancho=0.60, alto=0.44):
    p = [box((0.0, 0.0, 0.0), (0.03, alto, ancho), "House_Wood", 0.006),
         box((0.015, 0.0, 0.0), (0.012, alto - 0.07, ancho - 0.07),
             "House_Fabric", 0.003)]
    prop(name, room, origin, p, yaw=yaw, collider=False, contact=False)


def maceta(name, room, origin, radio=0.24, arbusto=0.42):
    # Maceta de invierno: tierra y ramas secas, cero icorferas (ver `twigs`).
    p = [cone((0.0, 0.20, 0.0), radio * 0.78, radio, 0.40, "House_Tile", 18),
         cyl((0.0, 0.41, 0.0), radio * 0.94, 0.03, "House_Wood", 18),
         box((0.0, 0.425, 0.0), (radio * 1.66, 0.04, radio * 1.66),
             "House_Fabric", 0.004),
         twigs((0.0, 0.44, 0.0), arbusto * 0.55, "House_Wood", 6, 0.9)]
    prop(name, room, origin, p, shape="cylinder", surface="concrete",
         penetrable=False)


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
    p = [box((0.0, size * 0.5, 0.0), (size, size, size * 0.92), "House_Gypsum", 0.012),
         box((0.0, size * 0.94, 0.0), (size * 0.98, 0.04, size * 0.6), "House_Fabric", 0.006)]
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
    p = [box((0.0, alto * 0.5, 0.0), (largo, alto, prof), "House_Tile", 0.02)]
    p.append(box((0.0, alto - 0.03, 0.0), (largo - 0.14, 0.06, prof - 0.14),
                 "House_Wood", 0.008))
    p.append(box((0.0, alto + 0.06, 0.0), (largo - 0.18, 0.14, prof - 0.18),
                 "House_Wood", 0.01))
    # TIERRA dentro del macetero + matas de ramas secas (invierno). Antes eran
    # seis icorferas de 0,3-0,5 m en `House_Fabric`: en captura leian a seis
    # pedruscos grises flotando sobre el hormigon.
    p.append(box((0.0, alto + 0.02, 0.0), (largo - 0.18, 0.10, prof - 0.18),
                 "House_Fabric", 0.006))
    rng = [0.30, 0.40, 0.26, 0.44, 0.34, 0.28]
    for i in range(6):
        x = -largo * 0.5 + 0.20 + i * ((largo - 0.40) / 5.0)
        r = rng[i % 6]
        p.append(twigs((x, alto + 0.08, (i % 3 - 1) * 0.06), r, "House_Wood", 7,
                       0.8))
    prop(name, room, origin, p, surface="concrete", penetrable=False)


# ---------------------------------------------------------------------------
# COLOCACION. Cada linea es una decision de arte con su cota.
# ---------------------------------------------------------------------------
def build_patio() -> None:
    ## JARDIN FRONTAL. Laja seca hasta x[-7,40,7,40] z[4,60,8,60]; el techo mas
    ## bajo es la tabla del porche (y=2,63). El eje de entrada x[-0,62,0,62]
    ## queda libre: por ahi nace el jugador y corre a la puerta.
    macetero("Macetero_Patio", "patio", (-3.60, 0.0, 5.60))
    palé("Pales_Patio", "patio", (2.90, 0.0, 6.90), yaw=6.0)
    ## Banco al OESTE y madera al ESTE: el banco de 1,60 m llegaba a x=5,70 y la
    ## pila de tablones nueva (build_house) empieza en 5,35 — el autocote lo
    ## canto antes de exportar (0,25/0,18/0,22 de solape). Uno de los dos tenia
    ## que moverse y el banco es el que no aporta nada en esa esquina.
    banco_jardin("Banco_Patio", "patio", (4.35, 0.0, 7.35), yaw=180.0)
    cubo("Cubo_Patio", "patio", (6.20, 0.0, 8.10))
    caja_carton("Cajas_Patio", "patio", (-5.10, 0.0, 7.90), size=0.56, rot=14.0)
    caja_carton("Cajas_Patio_2", "patio", (-4.75, 0.56, 7.75), size=0.44, rot=-9.0)
    maceta("Maceta_Patio", "patio", (1.30, 0.0, 5.10), radio=0.26, arbusto=0.40)


def build_salon() -> None:
    ## SALON (x[-5,36,-0,98]). La casa ya hornea sofa, mesa de centro, TV y
    ## radiador; aqui solo tapiza huecos y da cobertura sin tapar la ventana
    ## Norte (x[-3,40,-1,60]) ni la lateral Oeste (z[-3,20,-1,20]).
    estanteria("Estante_Salon", "salon", (-4.50, 0.0, -6.12), yaw=-90.0,
               largo=1.60, prof=0.32, alto=1.90)
    butaca("Butaca_Salon", "salon", (-3.75, 0.0, 0.55), yaw=0.0)
    sofa("Sofa_Salon", "salon", (-4.85, 0.0, 2.05), yaw=0.0, width=1.40)
    mesa("Mesa_Aux_Salon", "salon", (-1.255, 0.0, -2.55), yaw=90.0,
         largo=1.10, ancho=0.55, alto=0.75)
    alfombra("Alfombra_Salon", "salon", (-2.90, 0.0, 2.60), 2.60, 1.80)
    lampara_pie("Lampara_Salon", "salon", (-4.95, 0.0, -3.60))
    cuadro("Cuadro_Salon_1", "salon", (-3.20, 1.70, -6.265), yaw=-90.0,
           ancho=0.86, alto=0.56)
    cuadro("Cuadro_Salon_2", "salon", (-5.345, 1.85, 3.10), yaw=0.0,
           ancho=0.70, alto=0.50)


def build_pasillo() -> None:
    ## PASILLO (x[-0,82,1,82]) con la escalera pegada al muro Este: aqui NO
    ## cabe nada con colision, y encima la casa ya puso consola y perchero.
    ## Alfombra corrida y dos cuadros, que es lo que si pide el corredor.
    alfombra("Alfombra_Pasillo", "pasillo", (0.50, 0.0, 1.40), 0.90, 2.60)
    cuadro("Cuadro_Pasillo_1", "pasillo", (-0.805, 1.55, 0.10), yaw=0.0,
           ancho=0.50, alto=0.50)
    cuadro("Cuadro_Pasillo_2", "pasillo", (-0.805, 1.60, -5.72), yaw=0.0,
           ancho=0.52, alto=0.68)


def build_cocina() -> None:
    ## COCINA: encimeras, electrodomesticos y las 4 sillas del desayuno ya los
    ## hornea la casa. Solo falta mueble alto de despensa contra el muro Oeste,
    ## sobre el tramo macizo del P_Hall (z 1,70..4,36; el unico vano de ese
    ## muro es la puerta del corredor, z 0,60..1,70).
    ##
    ## Medido contra el poste 2 de CombatMap (2,65 / 3,60), que pide dos cosas a
    ## la vez: >= 0,34 de sitio de pie alrededor (capsula del jugador) y no
    ## estrecharle a los 0,26 del enemigo el cuello de 0,270 que ya deja la casa
    ## entre el tabique y C208_Chair_C1. Con 1,10 x 0,35 no hay desplazamiento
    ## posible: 0,55 al norte dejaba la cara sur justo en el poste (0,320) y el
    ## cuello en 0,256, o sea la cocina sellada. 1,00 x 0,32 desde (2,14 / 3,05)
    ## es el recorte menor que cumple las dos: 0,354 al poste y cuello 0,270.
    estanteria("Despensa_Cocina", "cocina", (2.14, 0.0, 3.05), yaw=0.0,
               largo=1.00, prof=0.32, alto=1.85, baldas=4, libros=False)
    cuadro("Cuadro_Cocina", "cocina", (3.70, 1.60, -2.185), yaw=-90.0,
           ancho=0.66, alto=0.50)


def build_dorm() -> None:
    ## DORMITORIO PRINCIPAL (planta alta oeste). Cama, mesillas, armario y
    ## espejo ya los hornea la casa; el escritorio va bajo la ventana Norte
    ## (x[-3,90,-2,30]) y el estante contra el tabique, dejando libre la
    ## puerta (hueco z[-2,60,-1,50]) y el resto de la habitacion.
    escritorio("Escritorio_Dorm", "dorm", (-4.66, NIVEL_ALTA, -5.085), yaw=-90.0,
               largo=1.40, prof=0.55, alto=0.75)
    silla("Silla_Dorm", "dorm", (-4.66, NIVEL_ALTA, -4.50), yaw=90.0)
    estanteria("Estante_Dorm", "dorm", (-1.14, NIVEL_ALTA, -3.60), yaw=180.0,
               largo=1.20, prof=0.32, alto=1.90)
    alfombra("Alfombra_Dorm", "dorm", (-3.20, NIVEL_ALTA, 3.50), 2.20, 1.60)
    cuadro("Cuadro_Dorm", "dorm", (-0.995, NIVEL_ALTA + 1.55, 1.20), yaw=180.0,
           ancho=0.70, alto=0.50)


def build_galeria() -> None:
    ## GALERIA (planta alta centro): rellan de la escalera. Rincon de desayuno
    ## junto al ventanal del frente; al norte de z=-0,96 ya esta la caja del
    ## hueco y la barandilla, que quedan DESPEJADAS.
    mesa("Mesa_Galeria", "galeria", (0.30, NIVEL_ALTA, 3.00), yaw=0.0,
         largo=1.20, ancho=0.80, alto=0.75)
    silla("Silla_Galeria_1", "galeria", (0.50, NIVEL_ALTA, 2.25), yaw=-90.0)
    silla("Silla_Galeria_2", "galeria", (0.50, NIVEL_ALTA, 3.75), yaw=90.0)


def build_estudio() -> None:
    ## ESTUDIO (planta alta este). La casa hornea dos estantes fijos al Norte,
    ## mesa y silla al centro y las puertas del balcon; aqui: cama de invitado
    ## con la cabeza al hueco de la pared Norte, ropero contra el muro Este y
    ## estante cerrando el muro Oeste entre la puerta y el tabique.
    estanteria("Estante_Estudio", "estudio", (2.14, NIVEL_ALTA, -1.00), yaw=0.0,
               largo=1.60, prof=0.32, alto=1.90)
    cama("Cama_Estudio", "estudio", (2.45, NIVEL_ALTA, -3.75), yaw=-90.0,
         ancho=0.90, largo=1.95)
    armario("Ropero_Estudio", "estudio", (5.06, NIVEL_ALTA, 0.60), yaw=180.0,
            largo=1.50, prof=0.60, alto=2.10, puertas=2)
    alfombra("Alfombra_Estudio", "estudio", (3.40, NIVEL_ALTA, 1.20), 2.00, 1.60)
    cuadro("Cuadro_Estudio", "estudio", (1.995, NIVEL_ALTA + 1.55, 3.60), yaw=0.0,
           ancho=0.60, alto=0.46)


# ---------------------------------------------------------------------------
# Comprobaciones previas a exportar
# ---------------------------------------------------------------------------
CASA_TSCN = Path("scenes/House.tscn")

## Capsula del jugador (scripts/Player.gd: shape.radius = 0,34), spawn y metas
## del recorrido (tools/check_walk.gd: Vector3(0.0, 0.05, 7.4), y despues
## z < -1,0 y x < -2,5). Una sola definicion para los dos lados.
RADIO_JUG = 0.34
SPAWN = (0.0, 7.4)
PASO = 0.05                                   ## lado de celda de la malla
X0, X1, Z0, Z1 = -7.45, 7.45, -7.85, 8.65     ## el lote completo
NX = int(round((X1 - X0) / PASO)) + 1
NZ = int(round((Z1 - Z0) / PASO)) + 1
def casa_aabb() -> list[tuple]:
    """AABB de MUNDO de los colisionadores de la casa. SOLO LECTURA.

    El formato lo escribe build_house.py: un ``sub_resource`` BoxShape3D con su
    ``size`` (o CylinderShape3D, que se mide como su caja envolvente) y un hijo
    CollisionShape3D con ``position`` y ``shape = SubResource(...)``. La unica
    pieza girada de toda la casa es la rampa de escalera, sobre su eje X; si
    alguna vez aparece otra rotacion, el builder se para en vez de medir mal.
    """
    if not CASA_TSCN.exists():
        raise SystemExit("build_props: no existe %s y sin el no hay cota"
                         % CASA_TSCN)
    txt = CASA_TSCN.read_text(encoding="utf-8")
    formas: dict = {}
    for m in re.finditer(r'\[sub_resource type="(\w+)" id="(Shape\d+)"\]\n([^\[]*)',
                         txt):
        tipo, sid, cuerpo = m.group(1), m.group(2), m.group(3)
        if tipo == "BoxShape3D":
            v3 = re.search(r"Vector3\(([^)]*)\)", cuerpo)
            if v3:
                formas[sid] = tuple(float(x) for x in v3.group(1).split(","))
        elif tipo == "CylinderShape3D":
            rad = re.search(r"radius = ([-\d.]+)", cuerpo)
            alt = re.search(r"height = ([-\d.]+)", cuerpo)
            if rad and alt:
                r, h = float(rad.group(1)), float(alt.group(1))
                formas[sid] = (2.0 * r, h, 2.0 * r)
    cajas: list[tuple] = []
    for bloque in re.split(r"\n(?=\[node )", txt):
        cabecera = bloque.split("\n", 1)[0]
        if 'type="CollisionShape3D"' not in cabecera:
            continue
        nombre = re.search(r'parent="([^"]+)"', cabecera).group(1)
        pos = [0.0, 0.0, 0.0]
        rot = [0.0, 0.0, 0.0]
        sid = None
        for linea in bloque.splitlines()[1:]:
            if linea.startswith("position = Vector3"):
                pos = [float(x) for x in re.search(r"\(([^)]*)\)", linea).group(1).split(",")]
            elif linea.startswith("rotation = Vector3"):
                rot = [float(x) for x in re.search(r"\(([^)]*)\)", linea).group(1).split(",")]
            elif linea.startswith("shape = SubResource"):
                sid = re.search(r'"([^"]+)"', linea).group(1)
        if sid not in formas:
            continue
        if abs(rot[1]) > 1e-6 or abs(rot[2]) > 1e-6:
            # LOS PILONES DE OBRA (Reno_pile) GIRON EN YAW desde la pasada que
            # los puso esquilados contra el muro. La caja envolvente del
            # volumen girado vale para las DOS comprobaciones que usan esta
            # lista ("no atraviesa muro: colisionador mayor", "no se solapa
            # con otro cuerpo") y el builder ya no se para por una caja que
            # nada se contradice.
            hx, hy, hz = (d * 0.5 for d in formas[sid])
            cy, sy = math.cos(rot[1]), math.sin(rot[1])
            xs, ys, zs = [], [], []
            for dx in (-hx, hx):
                for dy in (-hy, hy):
                    for dz in (-hz, hz):
                        xs.append(pos[0] + dx * cy + dz * sy)
                        ys.append(pos[1] + dy)
                        zs.append(pos[2] - dx * sy + dz * cy)
        elif abs(rot[0]) > 1e-6:
            # La rampa comparte el eje de la geometria (rotacion en X).
            hx, hy, hz = (d * 0.5 for d in formas[sid])
            cx, sx = math.cos(rot[0]), math.sin(rot[0])
            xs, ys, zs = [], [], []
            for dx in (-hx, hx):
                for dy in (-hy, hy):
                    for dz in (-hz, hz):
                        xs.append(pos[0] + dx)
                        ys.append(pos[1] + dy * cx - dz * sx)
                        zs.append(pos[2] + dy * sx + dz * cx)
        else:
            hx, hy, hz = (d * 0.5 for d in formas[sid])
            xs = [pos[0] - hx, pos[0] + hx]
            ys = [pos[1] - hy, pos[1] + hy]
            zs = [pos[2] - hz, pos[2] + hz]
        cajas.append((nombre, min(xs), max(xs), min(ys), max(ys),
                      min(zs), max(zs)))
    return cajas


def _en_banda(y0: float, y1: float) -> bool:
    """¿Ocupa la altura del jugador (0 .. 1,70) por encima del suelo?

    Con eso la losa del suelo (acaba en y=0), la losa alta (empieza en 2,80) y
    el porche (2,63) quedan fuera del calculo y NO cortan la malla.
    """
    return y0 < 1.65 and y1 > 0.05


def _pinta(grid: bytearray, x0: float, x1: float, z0: float, z1: float) -> None:
    ## Cerrado por dentro del cuerpo, ABIERTO por fuera: si los centros de celda
    ## estan a RADIO_JUG del solido, el punto esta a mas de RADIO_JUG y la
    ## capsula no lo cruza. Cerrado en ambos extremos NO deja la diagonal.
    i0 = max(0, math.ceil((x0 - RADIO_JUG - X0) / PASO))
    i1 = min(NX - 1, math.floor((x1 + RADIO_JUG - X0) / PASO))
    j0 = max(0, math.ceil((z0 - RADIO_JUG - Z0) / PASO))
    j1 = min(NZ - 1, math.floor((z1 + RADIO_JUG - Z0) / PASO))
    for j in range(j0, j1 + 1):
        base = j * NX
        for i in range(i0, i1 + 1):
            grid[base + i] = 1


def _bloqueados(casa: list, props: list) -> bytearray:
    grid = bytearray(NX * NZ)
    for nombre, x0, x1, y0, y1, z0, z1 in casa:
        if _en_banda(y0, y1):
            _pinta(grid, x0, x1, z0, z1)
    for b in props:
        if _en_banda(b[3], b[4]):
            _pinta(grid, b[1], b[2], b[5], b[6])
    return grid


def _interior(x: float, z: float) -> bool:
    for sala in ("salon", "pasillo", "cocina", "bano"):
        rx0, rx1, rz0, rz1, _piso, _alto = ROOMS[sala]
        if rx0 <= x <= rx1 and rz0 <= z <= rz1:
            return True
    return False


def _recorre(grid: bytearray) -> list:
    """BFS desde el spawn. Devuelve [z<-1,0 · x<-2,5 · Norte de la cocina].

    Los dos primeros son las metas que exige ``tools/check_walk.gd`` recorriendo
    la casa a pulsos de teclado: primero entro hasta el fondo y luego me voy al
    salon. El tercero protege el hueco de los POSTES de spawn, que check_walk
    no visita. Aca no se simula el input, solo la libertad de la capsula, por
    eso es un AVISO: el gate de verdad es el check de Godot.
    """
    si = int(round((SPAWN[0] - X0) / PASO))
    sj = int(round((SPAWN[1] - Z0) / PASO))
    if grid[sj * NX + si]:
        return [False, False, False]
    visto = bytearray(NX * NZ)
    visto[sj * NX + si] = 1
    cola = deque([sj * NX + si])
    llega = [False, False, False]
    vecinos = ((1, 0), (-1, 0), (0, 1), (0, -1),
               (1, 1), (1, -1), (-1, 1), (-1, -1))
    while cola:
        c = cola.popleft()
        j, i = divmod(c, NX)
        x = X0 + i * PASO
        z = Z0 + j * PASO
        dentro = _interior(x, z)
        if not llega[0] and dentro and z <= -1.0:
            llega[0] = True
        if not llega[1] and dentro and x <= -2.5:
            llega[1] = True
        ## Tercer objetivo: el Norte de la cocina, que es donde COMBATMAP pone
        ## el poste de spawn (2,65 / 3,6) y donde esta el canal mas estrecho de
        ## la casa (la despensa contra la isla). Sellarlo dejaria enemigos
        ## nacidos en un saco sin salida, y check_walk no pasa por ahi.
        if not llega[2] and dentro and x >= 2.10 and z >= 3.30:
            llega[2] = True
        if all(llega):
            break
        for di, dj in vecinos:
            ni, nj = i + di, j + dj
            if 0 <= ni < NX and 0 <= nj < NZ:
                n = nj * NX + ni
                if not visto[n] and not grid[n]:
                    visto[n] = 1
                    cola.append(n)
    return llega


def check() -> None:
    fallos: list[str] = []
    boxes: list[tuple] = []

    ## 1. Cota de cuarto: cero piezas hundidas en suelo, muro o techo.
    for p in PROPS:
        x0, x1, z0, z1, y0, y1 = p["world"]
        rx0, rx1, rz0, rz1, piso, alto = ROOMS[p["room"]]
        techo = piso + alto
        if x0 < rx0 - EPS or x1 > rx1 + EPS:
            fallos.append("%s: x [%.2f, %.2f] fuera de %s [%.2f, %.2f]"
                          % (p["name"], x0, x1, p["room"], rx0, rx1))
        if z0 < rz0 - EPS or z1 > rz1 + EPS:
            fallos.append("%s: z [%.2f, %.2f] fuera de %s [%.2f, %.2f]"
                          % (p["name"], z0, z1, p["room"], rz0, rz1))
        if y0 < piso - EPS:
            fallos.append("%s: se hunde %.3f m bajo el suelo de %s"
                          % (p["name"], piso - y0, p["room"]))
        if y1 > techo + EPS:
            fallos.append("%s: sube a %.2f y el techo de %s esta en %.2f"
                          % (p["name"], y1, p["room"], techo))
        if p["collider"]:
            boxes.append((p["name"], x0, x1, y0, y1, z0, z1))

    ## 2. Dos cuerpos fisicos solapados es una bala que golpea a ciegas.
    for i in range(len(boxes)):
        for j in range(i + 1, len(boxes)):
            a, b = boxes[i], boxes[j]
            sol = (min(a[2], b[2]) - max(a[1], b[1]),
                   min(a[4], b[4]) - max(a[3], b[3]),
                   min(a[6], b[6]) - max(a[5], b[5]))
            if all(s > SOLAPE for s in sol):
                fallos.append("%s y %s solapan %.2f/%.2f/%.2f m"
                              % (a[0], b[0], sol[0], sol[1], sol[2]))

    ## 3. NADA de esto se mete dentro de la casa.
    casa = casa_aabb()
    for a in boxes:
        for c in casa:
            sol = (min(a[2], c[2]) - max(a[1], c[1]),
                   min(a[4], c[4]) - max(a[3], c[3]),
                   min(a[6], c[6]) - max(a[5], c[5]))
            if all(s > SOLAPE for s in sol):
                fallos.append("%s se mete en %s (%.2f/%.2f/%.2f m)"
                              % (a[0], c[0], sol[0], sol[1], sol[2]))

    if fallos:
        for f in fallos:
            print("  FALLO:", f)
        raise SystemExit("build_props: %d problemas de cota; NO se exporta"
                         % len(fallos))

    ## 4. AVISO (NO corta la exportacion): ¿sigue habiendo recorrido?
    ##    Primero sin props, para no culpar a un mueble de un mapa que ya no
    ##    conectaba; despues con ellos, y si alguien tapa el paso se nombra.
    ##    Si la casa SOLA no llega, el False es de la casa y no se avisa: aqui
    ##    solo se juzga lo que tocan estos props.
    objetivos = ("z<-1,0", "x<-2,5", "Norte de la cocina")
    meta_sola = _recorre(_bloqueados(casa, []))
    meta_props = _recorre(_bloqueados(casa, boxes))
    bloqueantes = [b for b in boxes if _en_banda(b[3], b[4])]
    for k in range(len(objetivos)):
        if meta_props[k] or not meta_sola[k]:
            continue
        culpables = []
        for b in bloqueantes:
            resto = [o for o in bloqueantes if o is not b]
            if _recorre(_bloqueados(casa, resto))[k]:
                culpables.append(b[0])
        print("  aviso: %s lo tapa %s; no se mueve (decision de arte, el gate "
              "es check_walk)"
              % (objetivos[k], ", ".join(culpables) or "varios muebles a la vez"))
    print("  recorrido desde el spawn:", " · ".join(
        "%s casa=%s props=%s" % (objetivos[k], meta_sola[k], meta_props[k])
        for k in range(len(objetivos))))


def stats(out_path: Path) -> None:
    tris = 0
    for obj in PROPS_OBJ:
        tris += sum(len(poly.vertices) - 2 for poly in obj.data.polygons)
    colliders = sum(1 for p in PROPS if p["collider"])
    por_sala: dict = {}
    for p in PROPS:
        por_sala[p["room"]] = por_sala.get(p["room"], 0) + 1
    kb = out_path.stat().st_size / 1024.0
    print("PROPS %s  %.0f KB  tris=%d  nodos=%d  colisiones=%d  materiales=%d"
          % (out_path, kb, tris, len(PROPS), colliders, len(MATERIALES)))
    print("PROPS por cuarto:", ", ".join("%s=%d" % kv
                                         for kv in sorted(por_sala.items())))


PROPS_OBJ: list = []


def _merge_decor() -> None:
    """Fusiona las piezas decorativas sin colisor en UN nodo en el origen.

    Las transformaciones de cada pieza (origin + yaw) se hornean a la malla y
    el nodo queda identidad: el glb exportado gana un solo MeshInstance donde
    habia 12, con una primitiva por material. La cota por cuarto ya valido
    cada pieza suelta en `check()`; el nodo fusionado viaja con
    ``room="decor"`` y sin `col_shape`, asi que `CombatMap._props` le pinta
    materiales y no intenta levantarle colisor.
    """
    global DECOR_OBJ, PROPS
    if len(DECOR_OBJ) < 2:
        return
    bpy.ops.object.select_all(action="DESELECT")
    for obj in DECOR_OBJ:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = DECOR_OBJ[0]
    bpy.ops.object.join()
    merged = bpy.context.view_layer.objects.active
    merged.name = "Decor_NoCol"
    merged.data.name = "Decor_NoCol"
    merged.data.transform(merged.matrix_basis)
    merged.matrix_basis = Matrix()
    merged["room"] = "decor"
    vivos = {o.name for o in bpy.context.scene.objects if o.type == "MESH"}
    PROPS[:] = [p for p in PROPS if p["name"] in vivos]
    PROPS.append({"name": merged.name, "room": "decor", "world": None,
                  "collider": False, "origin": (0.0, 0.0, 0.0), "yaw": 0.0})
    print("PROPS decor fusionados: %d piezas -> 1 nodo" % len(DECOR_OBJ))
    DECOR_OBJ = []


def build() -> None:
    global PROPS_OBJ
    reset_scene()
    for name in MATERIALES:
        MAT[name] = material(name)

    build_patio()
    build_salon()
    build_pasillo()
    build_cocina()
    build_dorm()
    build_galeria()
    build_estudio()

    check()
    _merge_decor()

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
