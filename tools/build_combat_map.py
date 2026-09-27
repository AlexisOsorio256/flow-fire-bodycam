"""Genera el mapa de combate de FlowFire en Blender: BUNKER ROTO de cinco espacios.

Uso (desde la raiz del repo):

    blender --background --python tools/build_combat_map.py

SALIDAS (dos, del MISMO dato; ninguna se escribe a mano)
--------------------------------------------------------
1. ``assets/models/combat_bunker.glb``   geometria + NOMBRE de material, sin
   imagenes dentro (``export_image_format="NONE"``): las texturas PBR ya viven
   en ``assets/textures/real/`` y ``scripts/CombatMap.gd`` las vuelve a enganchar.
   Antes el .glb pesaba 6,6 MB porque embebia 9 imagenes que eran copias byte a
   byte de las del repo (medido por md5).
2. ``scenes/CombatBunker.tscn``  los COLISORES: cajas con ``surface`` y
   ``penetrable``. Se emiten aqui, junto a la geometria que los justifica, para
   que la colision no sea una segunda verdad que se desincronice; el runtime solo
   instancia la escena. Sin ``create_trimesh_collision`` (caro de construir y de
   resolver) y en CAJA: ``Ballistics._find_exit_geometry`` solo sabe sacar la cara
   de salida de una caja, un cilindro o una esfera, asi que una convexa o una
   trimesh dejarian el disparo sin penetracion.

COORDENADAS
-----------
Todo el diseno se escribe en coordenadas de GODOT (X derecha, Y arriba, -Z al
frente) y se convierte a Blender en un solo sitio (``B``). El exportador devuelve
el eje Y arriba, asi que las posiciones de los colisores del .tscn son
exactamente las de este archivo.

LOS CINCO ESPACIOS (12,8 x 18,3 m; pequeno a proposito)
------------------------------------------------------
1. PATIO       z 4,6..10,0   exterior abierto: cielo quemado, derrumbe, brecha.
2. CORREDOR    z 0,6..4,6    cubierto, con boquete en el techo (haz de luz) y
                             vigas de madera caidas.
3. BOVEDA      x -6,4..-0,2  interior CIEGO salvo una aspillera: el sitio oscuro.
4. PUESTO      x  0,2..6,4   aspillera tapiada con chapa, taquilla, cajas.
5. TRASERA     z -3,8..-8,4  muro de fondo derrumbado: cielo quemado por el
                             hueco y escombro dentro.
"""

from __future__ import annotations

import math
import random
from pathlib import Path

import bpy
import bmesh
from mathutils import Matrix, Vector


REPO = Path(__file__).resolve().parents[1]
MODELS = REPO / "assets" / "models"
TEXTURES = REPO / "assets" / "textures" / "real"
SCENES = REPO / "scenes"

# Metros de mundo que cubre UNA vuelta de textura (densidad fisica real).
METROS_POR_TILE = {
    "Bunker_Concrete": 2.4,
    "Bunker_Wood": 1.2,
    "Bunker_Metal": 1.6,
    "Bunker_Gypsum": 2.0,
    "Bunker_Floor": 3.0,
    "Bunker_Roof": 2.4,
}

# ---------------------------------------------------------------------------
# Medidas del mapa. Un solo sitio para cada cota.
# ---------------------------------------------------------------------------
FLOOR_Y = 0.0
ROOF_Y = 3.05          # cara inferior del techo
T = 0.42               # grosor de muro de hormigon
PATIO_Z0, PATIO_Z1 = 4.6, 10.4
PATIO_X = 5.2
CORR_X = 2.4
SIDE_Z1 = 0.6          # tabique del corredor
SIDE_Z0 = -3.8         # tabique de la sala trasera
BACK_Z = -8.6
MID_X = 0.0            # tabique boveda | puesto
VAULT_X = -6.6
POST_X = 6.6
TRAS_X = 4.8

COLLIDERS: list[dict] = []
OBJECTS: list[tuple] = []   # (objeto, grupo) para unir por material y sala


def B(x: float, y: float, z: float) -> Vector:
    """Godot (X, Y arriba, -Z al frente) -> Blender (Z arriba, +Y al fondo)."""
    return Vector((x, -z, y))


def seed_rng(tag: str, salt: int = 0) -> random.Random:
    return random.Random(f"{tag}:{salt}")


# ---------------------------------------------------------------------------
# Materiales y utilidades de malla
# ---------------------------------------------------------------------------
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


def material(name: str, albedo: Path, rough: Path, normal: Path | None,
             color=(0.8, 0.8, 0.8, 1.0), metallic=0.0, roughness=0.8,
             normal_strength=0.75):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    output = nodes.new("ShaderNodeOutputMaterial")
    shader = nodes.new("ShaderNodeBsdfPrincipled")
    if len(color) == 3:
        color = (color[0], color[1], color[2], 1.0)
    shader.inputs["Base Color"].default_value = color
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    links.new(shader.outputs["BSDF"], output.inputs["Surface"])

    scale = METROS_POR_TILE[name]

    def tiled(path: Path | None, non_color: bool):
        if path is None:
            return None
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = image(path, non_color)
        mapping = nodes.new("ShaderNodeMapping")
        mapping.inputs["Scale"].default_value = (1.0 / scale,) * 3
        coords = nodes.new("ShaderNodeTexCoord")
        links.new(coords.outputs["UV"], mapping.inputs["Vector"])
        links.new(mapping.outputs["Vector"], tex.inputs["Vector"])
        return tex

    links.new(tiled(albedo, False).outputs["Color"], shader.inputs["Base Color"])
    links.new(tiled(rough, True).outputs["Color"], shader.inputs["Roughness"])
    if normal is not None:
        bump = nodes.new("ShaderNodeNormalMap")
        bump.inputs["Strength"].default_value = normal_strength
        links.new(tiled(normal, True).outputs["Color"], bump.inputs["Color"])
        links.new(bump.outputs["Normal"], shader.inputs["Normal"])
    mat["metros_por_tile"] = scale
    return mat


def cube_project(obj, scale: float) -> None:
    """UV por proyeccion cubica a densidad fisica, en ESPACIO DE MUNDO.

    Se proyecta DESPUES de unir el grupo: dos paredes contiguas del mismo
    material comparten fase de textura y no aparece una costura que la obra no
    tiene.
    """
    matrix = obj.matrix_world
    mesh = obj.data
    bm = bmesh.new()
    bm.from_mesh(mesh)
    uv = bm.loops.layers.uv.verify()
    for face in bm.faces:
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


def new_object(name: str, bm: bmesh.types.BMesh, mat, group: str):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(mat)
    OBJECTS.append((obj, group))
    return obj


def join(name: str, objects: list, meters_per_tile: float):
    if not objects:
        return None
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    joined = bpy.context.object
    joined.name = name
    bpy.context.view_layer.objects.active = joined
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    cube_project(joined, meters_per_tile)
    joined["metros_por_tile"] = meters_per_tile
    return joined


# ---------------------------------------------------------------------------
# Cajas
# ---------------------------------------------------------------------------
def add_box(name: str, center, size, mat, group: str, bevel: float = 0.012,
            rotation=(0.0, 0.0, 0.0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector((size[0], size[2], size[1])), verts=bm.verts)
    if bevel > 0.001:
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bevel, segments=1,
                        profile=0.5, affect="EDGES")
    # La rotacion se aplica en el mismo espacio de la malla.
    if any(abs(a) > 1e-6 for a in rotation):
        rot = Matrix.Rotation(rotation[2], 4, "Z") @ Matrix.Rotation(rotation[1], 4, "Y") \
            @ Matrix.Rotation(rotation[0], 4, "X")
        for vert in bm.verts:
            vert.co = rot @ vert.co
    offset = B(center[0], center[1], center[2])
    for vert in bm.verts:
        vert.co += offset
    return new_object(name, bm, mat, group)


def collider(name: str, center, size, surface: str, penetrable: bool = False,
             contact=None, shape: str = "box", radius: float = 0.0, height: float = 0.0,
             thin_shell: bool = False, wall_thickness: float = 0.0):
    COLLIDERS.append({
        "name": name, "shape": shape, "center": Vector(center), "size": Vector(size),
        "radius": radius, "height": height, "surface": surface,
        "penetrable": penetrable, "contact": Vector(contact) if contact else None,
        "thin_shell": thin_shell, "wall_thickness": wall_thickness})


def box(name: str, center, size, mat, group: str, surface: str,
        penetrable: bool = False, bevel: float = 0.012, rotation=(0.0, 0.0, 0.0),
        contact=None):
    """Caja VISIBLE + su colision. Una pieza, un cuerpo fisico.

    ``contact`` (Vector2 de semiejes) marca los props que piden sombra de
    contacto en el runtime: el dato viaja con la pieza, no en una lista paralela
    que se desincronice.
    """
    obj = add_box(name, center, size, mat, group, bevel=bevel, rotation=rotation)
    collider(name, center, size, surface, penetrable, contact)
    return obj


# ---------------------------------------------------------------------------
# Panel: solido con canto roto, boquetes y caras imperfectas
# ---------------------------------------------------------------------------
def ragged_profile(seed: int, drop: float, steps: int = 7):
    """Perfil de canto roto: 1,0 arriba y bajadas deterministas."""
    rng = seed_rng("perfil", seed)
    points = [(0.0, 1.0)]
    for k in range(1, steps):
        points.append((k / steps, 1.0 - rng.random() * drop))
    points.append((1.0, 1.0 - rng.random() * drop))

    def height(t: float) -> float:
        t = min(max(t, 0.0), 1.0)
        for i in range(1, len(points)):
            if t <= points[i][0]:
                t0, h0 = points[i - 1]
                t1, h1 = points[i]
                k = (t - t0) / max(t1 - t0, 1e-6)
                return h0 + (h1 - h0) * k
        return points[-1][1]

    return height


def add_panel(name: str, origin, u_dir, v_dir, u_len: float, v_len: float,
              thickness: float, mat, group: str, holes=(), ragged: float = 0.0,
              cell: float = 0.55, seed: int = 1, jitter: float = 0.02):
    """Losa con boquetes REALES y canto roto, construida celda a celda.

    ``holes`` son rectangulos (u0, u1, v0, v1) en unidades locales desde
    ``origin``. Los bordes del panel se cierran con el canto de las celdas
    vecinas ausentes, asi que un boquete tiene su derrame (se ve el grosor del
    muro) y el canto roto no es una silueta de sierra: cada vertice lleva un
    desplazamiento determinista y las dos caras no son planos paralelos.
    """
    u_dir = Vector(u_dir).normalized()
    v_dir = Vector(v_dir).normalized()
    n_dir = u_dir.cross(v_dir).normalized()
    origin = Vector(origin)

    nu = max(2, int(round(u_len / cell)))
    nv = max(2, int(round(v_len / cell)))
    du = u_len / nu
    dv = v_len / nv
    profile = None
    if ragged > 0.0:
        profile = ragged_profile(seed, ragged)
    rng = seed_rng(name, seed)

    def solid(i: int, j: int) -> bool:
        if i < 0 or j < 0 or i >= nu or j >= nv:
            return False
        uc = (i + 0.5) * du
        vc = (j + 0.5) * dv
        for (u0, u1, v0, v1) in holes:
            if u0 <= uc <= u1 and v0 <= vc <= v1:
                return False
        if profile is not None and (j + 1) * dv > v_len * profile(uc / u_len):
            return False
        return True

    verts: dict[tuple, int] = {}
    coords: list[Vector] = []
    faces: list[tuple] = []

    def vid(i: int, j: int, side: int) -> int:
        key = (i, j, side)
        if key in verts:
            return verts[key]
        edge_u = i in (0, nu)
        edge_v = j in (0, nv)
        jx = 0.0 if edge_u else (rng.random() - 0.5) * jitter * 2.0
        jy = 0.0 if edge_v else (rng.random() - 0.5) * jitter * 2.0
        jn = (rng.random() - 0.5) * jitter * 2.0
        point = (origin + u_dir * (i * du + jx) + v_dir * (j * dv + jy)
                 + n_dir * (jn + (thickness * 0.5 if side == 0 else -thickness * 0.5)))
        verts[key] = len(coords)
        coords.append(point)
        return verts[key]

    for i in range(nu):
        for j in range(nv):
            if not solid(i, j):
                continue
            f00, f10, f11, f01 = vid(i, j, 0), vid(i + 1, j, 0), vid(i + 1, j + 1, 0), vid(i, j + 1, 0)
            b00, b10, b11, b01 = vid(i, j, 1), vid(i + 1, j, 1), vid(i + 1, j + 1, 1), vid(i, j + 1, 1)
            faces.append((f00, f10, f11, f01))          # cara +n
            faces.append((b00, b01, b11, b10))          # cara -n
            if not solid(i + 1, j):                     # canto +u
                faces.append((f10, b10, b11, f11))
            if not solid(i - 1, j):                     # canto -u
                faces.append((f00, b00, b01, f01))
            if not solid(i, j + 1):                     # canto +v
                faces.append((f01, f11, b11, b01))
            if not solid(i, j - 1):                     # canto -v
                faces.append((f00, b00, b10, f10))

    bm = bmesh.new()
    bverts = [bm.verts.new(point) for point in coords]
    bm.verts.ensure_lookup_table()
    for face in faces:
        try:
            bm.faces.new([bverts[k] for k in face])
        except ValueError:
            continue
    return new_object(name, bm, mat, group)


def wall(name: str, axis: str, at: float, lo: float, hi: float, y0: float, y1: float,
         mat, group: str, surface: str, penetrable: bool = False, holes=(),
         ragged: float = 0.0, thickness: float = T, seed: int = 1, cell: float = 0.55,
         skip_colliders: bool = False, contact=None):
    """Muro recto con boquetes. Emite la geometria Y los colisores que la tapizan.

    Los colisores se derivan de los MISMOS boquetes: por cada tramo ciego una
    caja, y sobre cada boquete el dintel que de verdad hay. Nada de una caja
    unica tapando el paso.
    """
    if axis == "x":
        origin = B(lo, y0, at)
        u_dir, v_dir = Vector((1, 0, 0)), Vector((0, 0, 1))
    else:
        origin = B(at, y0, lo)
        u_dir, v_dir = Vector((0, -1, 0)), Vector((0, 0, 1))
    add_panel(name, origin, u_dir, v_dir, hi - lo, y1 - y0, thickness, mat, group,
              holes=holes, ragged=ragged, seed=seed, cell=cell)

    if skip_colliders:
        return
    H = y1 - y0
    breaks = [0.0, hi - lo]
    for (u0, u1, _v0, _v1) in holes:
        breaks += [u0, u1]
    breaks = sorted(set(round(v, 4) for v in breaks))
    for k in range(len(breaks) - 1):
        a, b = breaks[k], breaks[k + 1]
        if b - a <= 0.02:
            continue
        spans = [(0.0, H)]
        for (u0, u1, v0, v1) in holes:
            if a >= u0 - 0.01 and b <= u1 + 0.01:
                # Antepecho y dintel se calculan sobre el MISMO tramo de partida:
                # encadenar la segunda lista sobre la primera ya recortada se
                # comia el dintel (boquete con aire por encima = se disparaba a
                # traves de un muro ciego).
                low = [(s0, min(s1, v0)) for (s0, s1) in spans if s0 < v0]
                high = [(max(s0, v1), s1) for (s0, s1) in spans if s1 > v1]
                spans = low + high
        for (v0, v1) in spans:
            if v1 - v0 <= 0.03:
                continue
            center_u = lo + (a + b) * 0.5
            if axis == "x":
                center = Vector((center_u, y0 + (v0 + v1) * 0.5, at))
                size = Vector((b - a, v1 - v0, thickness))
            else:
                center = Vector((at, y0 + (v0 + v1) * 0.5, center_u))
                size = Vector((thickness, v1 - v0, b - a))
            collider(f"{name}_col", center, size, surface, penetrable, contact)


def slab(name: str, y: float, x0: float, x1: float, z0: float, z1: float,
         thickness: float, mat, group: str, surface: str, penetrable: bool = False,
         holes=(), ragged: float = 0.0, seed: int = 1, skip_colliders: bool = False):
    """Losa horizontal (suelo o techo) centrada en y, con boquetes opcionales.

    Los boquetes se dan en coordenadas LOCALES (dx0, dx1, dz0, dz1) desde
    (x0, z0); los colisores se derivan de los mismos rectangulos.
    """
    add_panel(name, B(x0, y, z0), Vector((1, 0, 0)), Vector((0, -1, 0)),
              x1 - x0, z1 - z0, thickness, mat, group,
              holes=holes, ragged=ragged, seed=seed, cell=0.7)
    if skip_colliders:
        return
    breaks = sorted(set([0.0, x1 - x0] + [v for h in holes for v in (h[0], h[1])]))
    for k in range(len(breaks) - 1):
        a, b = breaks[k], breaks[k + 1]
        if b - a <= 0.02:
            continue
        spans = [(0.0, z1 - z0)]
        for (u0, u1, v0, v1) in holes:
            if a >= u0 - 0.01 and b <= u1 + 0.01:
                low = [(s0, min(s1, v0)) for (s0, s1) in spans if s0 < v0]
                high = [(max(s0, v1), s1) for (s0, s1) in spans if s1 > v1]
                spans = low + high
        for (v0, v1) in spans:
            if v1 - v0 <= 0.02:
                continue
            collider(f"{name}_col",
                     Vector((x0 + (a + b) * 0.5, y, z0 + (v0 + v1) * 0.5)),
                     Vector((b - a, thickness, v1 - v0)), surface, penetrable)


def rubble(name: str, center, spread: float, count: int, mat, group: str,
           surface: str, penetrable: bool, seed: int = 7, max_h: float = 0.5):
    """Escombro: cascotes deterministas con vuelo y giro. Una colision por pila."""
    rng = seed_rng(name, seed)
    for k in range(count):
        sx = rng.uniform(0.16, 0.44)
        sy = rng.uniform(0.10, 0.26)
        sz = rng.uniform(0.18, 0.46)
        px = center[0] + rng.uniform(-spread, spread)
        pz = center[2] + rng.uniform(-spread, spread)
        py = center[1] + rng.uniform(0.05, max_h)
        add_box(f"{name}_{k}", (px, py, pz), (sx, sy, sz), mat, group,
                bevel=min(0.02, min(sx, sy, sz) * 0.2),
                rotation=(rng.uniform(-0.35, 0.35), rng.uniform(-0.9, 0.9),
                          rng.uniform(-0.35, 0.35)))
    collider(f"{name}_col", Vector(center) + Vector((0, max_h * 0.5, 0)),
             Vector((spread * 2.0, max_h, spread * 2.0)), surface, penetrable,
             contact=(spread, spread))


def rebar(name: str, base, direction, length: float, mat, group: str, radius: float = 0.008):
    """Armadura: cilindro fino. Silueta barata en un canto roto."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=6,
                          radius1=radius, radius2=radius * 0.7, depth=length)
    axis = B(direction[0], direction[1], direction[2]).normalized()
    rot = Vector((0, 0, 1)).rotation_difference(axis).to_matrix().to_4x4()
    offset = B(base[0], base[1], base[2]) + axis * (length * 0.5)
    for vert in bm.verts:
        vert.co = (rot @ vert.co) + offset
    return new_object(name, bm, mat, group)


# ---------------------------------------------------------------------------
# Props
# ---------------------------------------------------------------------------
def crate(name: str, base, mat, group: str, size: float = 0.62, wall: float = 0.018):
    """Caja HUECA de tablas: la bala atraviesa 2 x 18 mm, no 620 mm de madera.

    Se declara ``thin_shell`` + grosor en vez de casi 40 caras de colision, y la
    silueta se construye con cuatro tablas verticales y dos tapas.
    """
    y = base[1] + size * 0.5
    t = wall
    for k, (size_v, pos) in enumerate([
        ((size, size, t), (0.0, 0.0, -size * 0.5)),
        ((size, size, t), (0.0, 0.0, size * 0.5)),
        ((t, size, size), (-size * 0.5, 0.0, 0.0)),
        ((t, size, size), (size * 0.5, 0.0, 0.0)),
        ((size * 1.02, t, size * 1.02), (0.0, size * 0.5, 0.0)),
        ((size * 1.02, t, size * 1.02), (0.0, -size * 0.5, 0.0)),
    ]):
        add_box(f"{name}_{k}", (base[0] + pos[0], y + pos[1], base[2] + pos[2]),
                size_v, mat, group, bevel=0.006)
    collider(name, (base[0], y, base[2]), (size, size, size), "pine", True,
             contact=(size * 0.5, size * 0.5), thin_shell=True, wall_thickness=t)


def locker(name: str, base, mat, group: str, surface: str = "steel"):
    add_box(name, (base[0], base[1] + 0.95, base[2]), (0.92, 1.9, 0.46), mat, group,
            bevel=0.01)
    add_box(f"{name}_door", (base[0], base[1] + 0.95, base[2] - 0.245),
            (0.86, 1.78, 0.02), mat, group, bevel=0.006)
    collider(name, (base[0], base[1] + 0.95, base[2]), (0.92, 1.9, 0.46), surface,
             False, contact=(0.46, 0.23))


def barrel(name: str, base, mat, group: str, surface: str = "steel", tilt: float = 0.0):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=14,
                          radius1=0.295, radius2=0.295, depth=0.88)
    if abs(tilt) > 1e-6:
        rot = Matrix.Rotation(tilt, 4, "Y")
        for vert in bm.verts:
            vert.co = rot @ vert.co
    offset = B(base[0], base[1] + 0.44, base[2])
    for vert in bm.verts:
        vert.co += offset
    new_object(name, bm, mat, group)
    collider(name, (base[0], base[1] + 0.44, base[2]), (0.59, 0.88, 0.59), surface,
             False, contact=(0.30, 0.30), shape="cylinder", radius=0.295, height=0.88)


def table(name: str, base, mat, group: str, surface: str = "pine"):
    add_box(name, (base[0], base[1] + 0.74, base[2]), (1.34, 0.06, 0.68), mat, group,
            bevel=0.008)
    for dx in (-0.58, 0.58):
        for dz in (-0.26, 0.26):
            add_box(f"{name}_leg", (base[0] + dx, base[1] + 0.36, base[2] + dz),
                    (0.07, 0.72, 0.07), mat, group, bevel=0.006)
    collider(name, (base[0], base[1] + 0.74, base[2]), (1.34, 0.06, 0.68), surface,
             True, contact=(0.68, 0.35), thin_shell=True, wall_thickness=0.06)


def leaning_slab(name: str, base, length: float, tilt: float, mat, group: str,
                 thickness: float = 0.16, width: float = 0.9):
    """Losa desplomada apoyada en un muro: una silueta imposible de caja recta.

    La colision es el AABB de la pieza (el hueco que deja por debajo no se pisa:
    la losa apoya en el suelo por su canto). Es conservadora a proposito: un
    cuerpo girado con transform exacto costaria un formato mas en el .tscn para
    una pieza que nadie atraviesa.
    """
    add_box(name, base, (width, thickness, length), mat, group, bevel=0.01,
            rotation=(tilt, 0.0, 0.0))
    depth = length * math.cos(tilt)
    height = length * math.sin(tilt)
    collider(name, (base[0], base[1] - height * 0.5 + thickness, base[2] - depth * 0.5),
             (width, max(height, 0.4), depth), "concrete", False, contact=(width * 0.5, 0.2))


# ---------------------------------------------------------------------------
# El mapa
# ---------------------------------------------------------------------------
def build() -> None:
    reset_scene()
    mat_concrete = material(
        "Bunker_Concrete", TEXTURES / "concrete_concrete_diff.jpg",
        TEXTURES / "concrete_concrete_rough.jpg", TEXTURES / "concrete_concrete_nor_gl.jpg",
        color=(0.62, 0.62, 0.63), roughness=0.82, normal_strength=0.85)
    mat_wood = material(
        "Bunker_Wood", TEXTURES / "wood_oak_wood_planks_diff.jpg",
        TEXTURES / "wood_oak_wood_planks_rough.jpg", TEXTURES / "wood_oak_wood_planks_nor_gl.jpg",
        color=(0.74, 0.60, 0.44), roughness=0.78, normal_strength=0.9)
    mat_metal = material(
        "Bunker_Metal", TEXTURES / "metal_metal_plate_diff.jpg",
        TEXTURES / "metal_metal_plate_rough.jpg", TEXTURES / "metal_metal_plate_nor_gl.jpg",
        color=(0.42, 0.44, 0.47), metallic=0.65, roughness=0.42, normal_strength=0.7)
    mat_gypsum = material(
        "Bunker_Gypsum", TEXTURES / "gypsum_diff.jpg", TEXTURES / "gypsum_rough.jpg",
        None, color=(0.72, 0.70, 0.66), roughness=0.86)
    # El suelo va con la losa CEPILLADA (la de juntas de losa del banco, 3,0 m
    # por vuelta): con la de encofrado vertical el suelo se leia como tablones.
    mat_floor = material(
        "Bunker_Floor", TEXTURES / "concrete_brushed_concrete_diff.jpg",
        TEXTURES / "concrete_brushed_concrete_rough.jpg",
        TEXTURES / "concrete_brushed_concrete_nor_gl.jpg",
        color=(0.56, 0.56, 0.57), roughness=0.70, normal_strength=0.5)
    # El techo, OSCURO a proposito: en Mobile no hay GI ni AO y el ambiente del
    # cielo es uniforme, asi que un techo claro deja el interior leyendose como
    # una sala iluminada por arriba. Un techo sucio de bunker ademas es verdad.
    mat_roof = material(
        "Bunker_Roof", TEXTURES / "concrete_concrete_diff.jpg",
        TEXTURES / "concrete_concrete_rough.jpg", TEXTURES / "concrete_concrete_nor_gl.jpg",
        color=(0.26, 0.26, 0.27), roughness=0.88, normal_strength=0.9)

    # ---- suelo -----------------------------------------------------------------
    slab("Floor", FLOOR_Y - 0.2, -6.9, 6.9, -8.9, 10.7, 0.4, mat_floor, "base",
         "concrete")

    # ---- 1. PATIO: exterior abierto -------------------------------------------
    wall("Patio_West", "z", -PATIO_X, SIDE_Z1, PATIO_Z1, 0.0, 2.95, mat_concrete,
         "patio", "concrete", holes=[(3.4, 5.0, 1.1, 2.4)], ragged=0.30, seed=11)
    wall("Patio_East", "z", PATIO_X, SIDE_Z1, PATIO_Z1, 0.0, 2.95, mat_concrete,
         "patio", "concrete", holes=[(6.0, 7.6, 0.4, 1.5)], ragged=0.34, seed=12)
    wall("Patio_South", "x", PATIO_Z1, -PATIO_X, PATIO_X, 0.0, 2.05, mat_concrete,
         "patio", "concrete", ragged=0.45, seed=13)
    # Fachada del bunker: la brecha de entrada, con canto roto en los dos lados.
    wall("Facade", "x", PATIO_Z0, -CORR_X, CORR_X, 0.0, 3.00, mat_concrete, "patio",
         "concrete", holes=[(0.9, 3.3, 0.0, 2.28)], ragged=0.05, seed=14)
    # Marcos de madera del portal (identidad del video): postes torcidos.
    add_box("Frame_Entry_L", (-2.42, 1.16, 4.6), (0.16, 2.34, 0.5), mat_wood, "patio",
            bevel=0.008, rotation=(0.0, 0.0, -0.03))
    add_box("Frame_Entry_R", (0.92, 1.14, 4.6), (0.16, 2.30, 0.5), mat_wood, "patio",
            bevel=0.008, rotation=(0.0, 0.0, 0.045))
    add_box("Frame_Entry_Top", (-0.75, 2.32, 4.6), (3.5, 0.17, 0.52), mat_wood, "patio",
            bevel=0.008, rotation=(0.02, 0.0, 0.02))
    # Alero de hormigon sobre el portal, partido.
    box("Canopy_L", (-1.95, 2.62, 4.15), (1.5, 0.22, 1.1), mat_concrete, "patio",
        "concrete", bevel=0.01)
    box("Canopy_R", (0.6, 2.66, 4.2), (2.0, 0.2, 1.2), mat_concrete, "patio",
        "concrete", bevel=0.01, rotation=(0.0, 0.03, 0.0))

    rubble("Rubble_Patio_W", (-3.9, 0.0, 6.4), 1.3, 9, mat_concrete, "patio", "concrete", False, seed=21)
    rubble("Rubble_Patio_S", (2.6, 0.0, 9.1), 1.5, 10, mat_concrete, "patio", "concrete", False, seed=22)
    leaning_slab("Slab_Patio", (-4.3, 1.65, 8.2), 2.6, 0.42, mat_concrete, "patio")
    box("Beam_Patio", (-1.6, 0.15, 8.6), (3.6, 0.26, 0.24), mat_wood, "patio", "pine",
        True, bevel=0.008, contact=(1.8, 0.14))
    rebar("Rebar_1", (-2.3, 2.2, 4.75), (0.25, 0.9, -0.2), 0.55, mat_metal, "patio")
    rebar("Rebar_2", (-2.15, 1.9, 4.8), (0.1, 0.95, 0.15), 0.42, mat_metal, "patio")
    rebar("Rebar_3", (3.05, 2.35, 4.7), (-0.2, 0.9, 0.25), 0.48, mat_metal, "patio")

    # ---- 2. CORREDOR de estrangulamiento --------------------------------------
    wall("Corr_West", "z", -CORR_X, SIDE_Z1, PATIO_Z0, 0.0, 3.00, mat_concrete,
         "corr", "concrete", holes=[(1.7, 2.9, 0.85, 1.95)], ragged=0.03, seed=31)
    wall("Corr_East", "z", CORR_X, SIDE_Z1, PATIO_Z0, 0.0, 3.00, mat_concrete,
         "corr", "concrete", holes=[(2.5, 3.3, 1.4, 2.3)], ragged=0.03, seed=32)
    # Techo con BOQUETE: el haz de luz que separa el patio del interior.
    slab("Corr_Roof", ROOF_Y, -CORR_X, CORR_X, SIDE_Z1, PATIO_Z0, 0.4, mat_roof,
         "corr", "concrete", holes=[(1.5 - -CORR_X, 2.9 + CORR_X, 1.6, 2.9)],
         seed=33)
    for k, (z, y) in enumerate([(1.35, 2.82), (3.45, 2.86)]):
        box(f"Beam_Roof_{k}", (0.0, y, z), (CORR_X * 2.0, 0.2, 0.16), mat_metal,
            "corr", "steel", bevel=0.008)
    # Viga de madera caida en diagonal sobre el paso.
    add_box("Beam_Fallen", (-1.75, 1.35, 2.2), (0.24, 0.24, 2.9), mat_wood, "corr",
            bevel=0.008, rotation=(0.55, 0.0, 0.25))
    collider("Beam_Fallen", (-1.75, 0.75, 2.2), (0.3, 1.5, 2.0), "pine", True,
             contact=(0.25, 0.4), thin_shell=True, wall_thickness=0.24)
    # Planchas de madera apiladas contra el muro este.
    for k in range(3):
        add_box(f"Plank_{k}", (1.95 + k * 0.05, 0.55 + k * 0.04, 1.15),
                (0.06, 2.0, 0.32), mat_wood, "corr", bevel=0.006,
                rotation=(0.05, 0.09 * k, 0.0))
    collider("Planks", (2.0, 0.6, 1.15), (0.3, 2.0, 0.5), "pine", True,
             contact=(0.2, 0.3), thin_shell=True, wall_thickness=0.18)
    # Hoja de chapa apoyada en el muro oeste.
    add_box("Door_Leaf", (-2.0, 0.72, 3.05), (0.05, 1.42, 0.86), mat_metal, "corr",
            bevel=0.006, rotation=(0.0, 0.0, 0.11))
    collider("Door_Leaf", (-2.0, 0.72, 3.05), (0.12, 1.42, 0.86), "steel", True,
             contact=(0.1, 0.45), thin_shell=True, wall_thickness=0.012)
    rubble("Rubble_Corr", (-1.4, 0.0, 4.1), 0.5, 5, mat_concrete, "corr", "concrete", False, seed=34)

    # ---- 3. BOVEDA ciega / 4. PUESTO ------------------------------------------
    # Tabique del corredor (z = 0,6) con paso central y dos boquetes de derrumbe.
    wall("Part_Choke", "x", SIDE_Z1, -POST_X, POST_X, 0.0, 3.00, mat_concrete,
         "nave", "concrete",
         holes=[(POST_X - 0.95, POST_X + 0.95, 0.0, 2.16),
                (POST_X - 5.4, POST_X - 4.2, 0.55, 1.75),
                (POST_X + 1.3, POST_X + 2.4, 0.75, 1.85)],
         ragged=0.03, seed=41)
    add_box("Choke_Jamb_L", (-0.92, 1.1, SIDE_Z1), (0.14, 2.2, 0.5), mat_metal, "nave",
            bevel=0.008)
    add_box("Choke_Jamb_R", (0.92, 1.1, SIDE_Z1), (0.14, 2.2, 0.5), mat_metal, "nave",
            bevel=0.008)
    add_box("Choke_Head", (0.0, 2.2, SIDE_Z1), (2.0, 0.14, 0.5), mat_metal, "nave",
            bevel=0.008)
    # Tabique boveda | puesto, con puerta de madera y esquina hundida.
    wall("Part_Mid", "z", MID_X, SIDE_Z0, SIDE_Z1, 0.0, 3.00, mat_concrete, "nave",
         "concrete", holes=[(1.4, 2.55, 0.0, 2.1), (3.5, 4.4, 0.6, 2.6)],
         ragged=0.03, seed=42)
    add_box("Mid_Jamb_L", (0.0, 1.05, -2.42), (0.5, 2.1, 0.15), mat_wood, "nave",
            bevel=0.006)
    add_box("Mid_Jamb_R", (0.0, 1.02, -1.18), (0.5, 2.05, 0.15), mat_wood, "nave",
            bevel=0.006)
    add_box("Mid_Head", (0.0, 2.1, -1.8), (0.5, 0.16, 1.45), mat_wood, "nave",
            bevel=0.006)
    box("VaultSlab", (-2.4, 2.4, -3.3), (1.7, 0.2, 1.0), mat_concrete, "boveda",
        "concrete", bevel=0.01, rotation=(0.0, 0.18, 0.0))
    for k, z in enumerate([-0.6, -1.2]):
        box(f"Shelf_{k}", (-5.7, 0.62 + k * 0.66, -2.2), (0.9, 0.06, 2.3),
            mat_wood, "boveda", "pine", True, bevel=0.006)
    crate("Crate_Vault", (-4.9, 0.0, -0.35), mat_wood, "boveda")
    crate("Crate_Vault2", (-4.2, 0.0, -0.75), mat_wood, "boveda", size=0.5)
    barrel("Barrel_Vault", (-3.2, 0.0, -1.0), mat_metal, "boveda")
    rubble("Rubble_Vault", (-1.5, 0.0, -2.9), 0.6, 6, mat_concrete, "boveda", "concrete", False, seed=43)
    # Puesto de guardia: aspillera tapiada, chapa, taquilla y mesa.
    add_box("Post_Plate", (POST_X - 0.05, 1.35, -2.0), (0.08, 0.66, 1.1), mat_metal,
            "puesto", bevel=0.008, rotation=(0.0, 0.0, 0.04))
    collider("Post_Plate", (POST_X - 0.05, 1.35, -2.0), (0.1, 0.66, 1.1), "steel", True,
             contact=(0.08, 0.5), thin_shell=True, wall_thickness=0.008)
    locker("Locker", (4.9, 0.0, -3.2), mat_metal, "puesto")
    table("Table", (3.3, 0.0, -0.9), mat_wood, "puesto")
    crate("Crate_Post", (5.0, 0.0, -0.4), mat_wood, "puesto", size=0.55)
    barrel("Barrel_Post", (2.0, 0.0, -3.0), mat_metal, "puesto")
    wall("Post_West", "z", VAULT_X, SIDE_Z0, SIDE_Z1, 0.0, 3.00, mat_concrete,
         "boveda", "concrete", holes=[(-1.0, -0.1, 1.35, 2.05)], ragged=0.03, seed=44)
    wall("Post_East", "z", POST_X, SIDE_Z0, SIDE_Z1, 0.0, 3.00, mat_concrete,
         "puesto", "concrete", holes=[(-2.7, -1.35, 0.95, 1.95), (2.2, 3.3, 0.3, 1.2)],
         ragged=0.03, seed=45)
    slab("Nave_Roof", ROOF_Y, VAULT_X, POST_X, SIDE_Z0, SIDE_Z1, 0.4, mat_roof,
         "nave", "concrete", holes=[(VAULT_X + 5.6, VAULT_X + 6.9, 1.1, 2.3)],
         seed=46)
    # Tabique de yeso roto dentro de la boveda: lo unico que se atraviesa de verdad.
    add_panel("Gypsum_Part", B(-3.3, 0.0, -3.05), Vector((1, 0, 0)), Vector((0, 0, 1)),
              2.4, 2.3, 0.09, mat_gypsum, "boveda",
              holes=[(0.5, 1.4, 0.0, 1.5)], ragged=0.35, seed=47, cell=0.45)
    collider("Gypsum_Part", (-2.1, 1.15, -3.05), (2.4, 2.3, 0.09), "gypsum", True,
             contact=(1.2, 0.1))

    # ---- 5. SALA TRASERA: muro derrumbado -------------------------------------
    wall("Part_Back", "x", SIDE_Z0, -POST_X, POST_X, 0.0, 3.00, mat_concrete,
         "trasera", "concrete",
         holes=[(POST_X - 1.7, POST_X - 0.5, 0.0, 2.12),
                (POST_X + 1.4, POST_X + 3.6, 0.0, 2.5)],
         ragged=0.03, seed=51)
    wall("Tras_West", "z", -TRAS_X, BACK_Z, SIDE_Z0, 0.0, 3.00, mat_concrete, "trasera",
         "concrete", ragged=0.04, seed=52)
    wall("Tras_East", "z", TRAS_X, BACK_Z, SIDE_Z0, 0.0, 3.00, mat_concrete, "trasera",
         "concrete", ragged=0.04, seed=53)
    wall("Tras_Back", "x", BACK_Z, -TRAS_X, TRAS_X, 0.0, 3.00, mat_concrete, "trasera",
         "concrete", holes=[(-0.4, 3.2, 0.0, 2.62)], ragged=0.25, seed=54)
    slab("Tras_Roof", ROOF_Y, -TRAS_X, TRAS_X, BACK_Z, SIDE_Z0, 0.4, mat_roof,
         "trasera", "concrete",
         holes=[(1.2, 3.1, 1.5, 3.5), (7.2, 8.4, 3.0, 4.2)], ragged=0.18, seed=55)
    rubble("Rubble_Back", (1.4, 0.0, -7.2), 1.5, 12, mat_concrete, "trasera",
           "concrete", False, seed=56, max_h=0.75)
    rubble("Rubble_Back_W", (-3.2, 0.0, -6.0), 1.1, 8, mat_concrete, "trasera",
           "concrete", False, seed=57, max_h=0.6)
    leaning_slab("Slab_Back", (2.6, 1.55, -5.2), 2.4, 0.5, mat_concrete, "trasera")
    add_box("Beam_Back", (-1.2, 0.15, -6.6), (3.4, 0.22, 0.24), mat_wood, "trasera",
            bevel=0.008, rotation=(0.34, 0.0, 0.0))
    barrel("Barrel_Back", (-4.0, 0.0, -4.6), mat_metal, "trasera")
    rebar("Rebar_4", (0.35, 2.4, BACK_Z + 0.2), (0.1, 0.85, 0.5), 0.5, mat_metal, "trasera")
    rebar("Rebar_5", (2.6, 2.2, BACK_Z + 0.2), (-0.2, 0.9, 0.4), 0.44, mat_metal, "trasera")

    # ---- union por material y sala --------------------------------------------
    groups: dict[tuple, list] = {}
    for obj, group in OBJECTS:
        key = (obj.data.materials[0].name, group)
        groups.setdefault(key, []).append(obj)
    merged = []
    for (mat_name, group), objects in sorted(groups.items()):
        node = join(f"Bunker_{mat_name.split('_')[1]}_{group}", objects,
                    METROS_POR_TILE[mat_name])
        if node is not None:
            merged.append(node)

    # ---- export ---------------------------------------------------------------
    MODELS.mkdir(parents=True, exist_ok=True)
    out_path = MODELS / "combat_bunker.glb"
    bpy.ops.object.select_all(action="DESELECT")
    for obj in merged:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = merged[0]
    bpy.ops.export_scene.gltf(
        filepath=str(out_path),
        use_selection=True,
        export_format="GLB",
        export_apply=True,
        export_texcoords=True,
        export_normals=True,
        export_tangents=False,
        export_materials="EXPORT",
        # SIN texturas dentro del GLB: la fuente unica es assets/textures/real.
        export_image_format="NONE",
    )
    tris = sum(len(poly.vertices) - 2 for obj in merged for poly in obj.data.polygons)
    print(f"BUNKER built {out_path} {out_path.stat().st_size / 1024:.0f} KB tris={tris} "
          f"mallas={len(merged)}")
    scene = write_scene(len(merged))
    print(f"BUNKER colisiones {scene} ({len(COLLIDERS)} cuerpos)")


# ---------------------------------------------------------------------------
# Escena de colision (cajas y cilindros con material y penetracion)
# ---------------------------------------------------------------------------
def fmt_vec(v) -> str:
    return "Vector3(%s, %s, %s)" % (f"{v[0]:.3f}", f"{v[1]:.3f}", f"{v[2]:.3f}")


def write_scene(mesh_count: int) -> Path:
    shapes: dict[tuple, str] = {}
    bodies: list[str] = []

    def shape_id(c: dict) -> str:
        if c["shape"] == "cylinder":
            key = ("cylinder", round(c["radius"], 3), round(c["height"], 3))
        else:
            key = ("box", round(c["size"][0], 3), round(c["size"][1], 3), round(c["size"][2], 3))
        if key not in shapes:
            name = f"Shape{len(shapes)}"
            if key[0] == "box":
                text = ('[sub_resource type="BoxShape3D" id="%s"]\n' % name
                        + "size = %s\n" % fmt_vec((key[1], key[2], key[3])))
            else:
                text = ('[sub_resource type="CylinderShape3D" id="%s"]\n' % name
                        + "radius = %.3f\nheight = %.3f\n" % (key[1], key[2]))
            shapes[key] = name
            bodies.append(text)
        return shapes[key]

    nodes: list[str] = []
    for index, c in enumerate(COLLIDERS):
        sid = shape_id(c)
        body_name = f"C{index:03d}_{c['name']}"
        props = ["collision_layer = 1", "collision_mask = 1",
                 'metadata/surface = "%s"' % c["surface"],
                 "metadata/penetrable = %s" % ("true" if c["penetrable"] else "false")]
        if c["thin_shell"]:
            props.append("metadata/thin_shell = true")
            props.append("metadata/wall_thickness = %.3f" % c["wall_thickness"])
        if c["contact"] is not None:
            props.append("metadata/contact = Vector2(%.3f, %.3f)"
                         % (c["contact"][0], c["contact"][1]))
        nodes.append('\n[node name="%s" type="StaticBody3D" parent="."]\n%s\n'
                     % (body_name, "\n".join(props)))
        nodes.append('\n[node name="Shape" type="CollisionShape3D" parent="%s"]\n'
                     'position = %s\nshape = SubResource("%s")\n'
                     % (body_name, fmt_vec(c["center"]), sid))

    head = ('[gd_scene load_steps=%d format=3]\n\n'
            '[ext_resource type="PackedScene" path="res://assets/models/combat_bunker.glb" id="1_visual"]\n\n'
            % (len(bodies) + 2))
    tail = ('\n[node name="CombatBunker" type="Node3D"]\n\n'
            '[node name="Visual" parent="." instance=ExtResource("1_visual")]\n')
    path = SCENES / "CombatBunker.tscn"
    path.write_text(head + "\n".join(bodies) + tail + "".join(nodes), encoding="utf-8")
    return path


if __name__ == "__main__":
    build()
