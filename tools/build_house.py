"""Genera la CASA USA DE MADERA de dos pisos de FlowFire en Blender (correccion
del dueno: la primera entrega leia a bunker de hormigon; esto es madera).

Uso (desde la raiz del repo):

    blender --background --python tools/build_house.py

SALIDAS (dos, del MISMO dato; ninguna se escribe a mano)
--------------------------------------------------------
1. ``assets/models/house.glb``  geometria + NOMBRE de material, sin imagenes
   dentro (``export_image_format="NONE"``): las texturas PBR viven en
   ``assets/textures/real/`` y ``scripts/CombatMap.gd`` las reengancha por
   nombre (una textura se paga una vez).
2. ``scenes/House.tscn``  los COLISORES: cajas y cilindros, y UNA caja
   ROTADA (la rampa de la escalera) con ``surface``, ``penetrable`` y, donde
   es cascara, ``thin_shell`` / ``wall_thickness``. Cero
   ``create_trimesh_collision``. ``Ballistics._exit_of_shape`` recorre la caja
   en el ESPACIO LOCAL de su transform, asi que incluso la rampa inclinada
   tiene cara de salida analitica.

CASA USA DE MADERA, NO LOWPOLY
------------------------------
Dos plantas utiles de 2,80 m sobre losa de patio. ESTRUCTURA DE MADERA, no
hormigon visto: fachada de entablado horizontal blanco (``House_Siding``),
forjados y cubierta con la madera a la vista en cantos y zancas, PORCHE
delantero con techo y barandal de madera y DECK trasero al patio. El colisor
del muro exterior se declara ``thin_shell`` pine 30 mm (forro completo:
siding + OSB + drywall). Ballistics cobra DOS paredes (2 x 30 = 60 mm de
pino): la 9 mm cruza la fachada conservando ~65 % -- entra luz y plomo por
la casa, como en una wood-frame de verdad; la cobertura la ponen los
macizos (forjado de 20 cm solido, electrodomesticos de acero, ropero y
bastidor de cama), no los tabiques. Tabiques interiores de DOBLE PLACA de yeso (cascara 12,5 mm por placa:
se cruzan perdiendo ~40 %). Vidrio de 3,5 mm ``thin_shell``: se casca y pasa.
Puertas FRANCESAS vidriadas (calle doble abatible, trasera y balcon): el
colisor de cada hoja es cascara YESO porque el cristal domina el area de la
hoja. Radiadores y espejos cascaron, electrodomesticos de acero MACIZOS
(paran: cobertura). TODO cerrado con geometria visible: jambas, dinteles,
antepechos, alfizares, contrahuellas, barandillas con balaustres reales y
POSTES del porche con su caja. Ni un muro invisible ni un vaco sin proteccion.

LA ESCALERA
-----------
16 peldaunos: contrahuella 187,5 mm, huella 260 mm, pendiente 35,8 grados. La
GEOMETRIA son tablas y contrahuellas de roble por pieza + dos zancas giradas.
LA COLISION es UNA caja continua girada -35,8 grados sobre X: sube con el
``floor_max_angle`` default (45) de CharacterBody3D (sondeado: 16 cajas sueltas
atoraban al jugador en la cuarta contrahuella; la rampa continua no). La rampa
entra en el suelo bajo el primer paso: dos solidos estaticos solapados no se
pelean.

LOS CINCO ESPACIOS
------------------
Planta baja (suelo y = 0):
  1. SALA      todo el flanco oeste (4,3 x 9,7 m): ventana de fachada, ventana
               lateral norte y ventana trasera; puerta a la sala (sur) y arco
               (norte) al vestibulo. Cobertura: sofa de tres cuerpos, mesa
               baja, mueble de TV con pantalla de vidrio.
  2. COCINA    sureste: L de encimera con fregadero de acero, nevera, mesa con
               cuatro sillas, radiador de aluminio, ventana al patio.
  3. BANO      noreste: inodoro y lavabo de ceramica (cascara yeso), lavadora,
               termo cilindro de acero; ventanita esmerilada alta con la hoja
               superior FALTANTE (geometria que no esta, no cristal invisible).
               Se entra desde la cocina, como en las casas de este tamano.
     VESTIBULO franja central: PUERTAS FRANCESAS de entrada (doble hoja
     acristalada, abierta contra los muros), puertas francesas traseras al
     DECK del patio, consola, percha y la ESCALERA contra el tabique este.
Planta alta (sobre forjado de 20 cm; suelo y = 3,0):
  4. DORMITORIO oeste: cama king (bastidor MACIZO: para balas; somier de tela),
               ropero de 1,7 m que es cobertura, mesillas, espejo de cuerpo
               entero barato (cascara de aluminio: se casca y pasa). Ventana al
               frente y lateral.
  5. ESTUDIO  este: escritorio bajo la ventana, estanterias con libros de
               papel, radiador, y puerta al BALCON: losa volada sobre la
               fachada con barandilla de balaustres (geometria + colision).
     GALERIA   la banda frontal asoma al vestibulo por el hueco de escalera con
               barandilla de pasamanos; la ventana alta del frente (sobre la
               puerta de calle) la ilumina.

COORDENADAS: todo se escribe en GODOT (X derecha, Y arriba, -Z al frente) y se
convierte a Blender en un solo sitio (``B``). Las cotas del .tscn son las de
este archivo. Blender R_x(a) coincide con Godot R_x(a) bajo este mapeo, por eso
la rampa comparte el angulo en geometria y en colision.

CAMINATA (diseñada contra ``tools/check_walk.gd``, que NO se toca):
spawn (0, 0.05, 7.4) mirando -Z. Tramo 1: W 4 s: 16 m disponibles; entra por la
puerta de calle (vano 1,10 centrado en x=0), cruza el vestibulo a la izquierda
de la escalera (paso libre de 1,8 m) y muere contra la puerta trasera en
z ~ -4,9: pasa ``z < -1,0`` y ``|y| < 0,4`` (ningun peldano en la linea).
Tramo 2: S+A (-X/+Z a 2,83 m/s de deslizamiento): topa el tabique oeste,
resbala 0,7 m hasta la puerta SUR de la sala (vano z -4,3..-3,2) y entra con
1,3 s libres: llega a x < -2,5 sin mobiliario en esa banda (sofa, mesa y TV
viven al norte del arco, y la mesa baja esta a 1,6 m de la linea).
"""

from __future__ import annotations

import math
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
    "House_Siding": 1.2,     # entablado horizontal blanco de madera (roble tintado)
    "House_Tile": 2.6,       # losa del patio: gris calido, la UNICA superficie "de obra"
    "House_Wood": 1.2,       # roble: estructura, forjados vistos, suelos, escalera, muebles
    "House_Gypsum": 2.0,     # yeso pintado calido: tabiques, techos, guarnecido
    "House_Metal": 1.6,      # chapa: SOLO herrajes (grifo, termo, electro, canopas)
    # Sin textura: la UV viaja igual (densidad indiferente, color plano).
    "House_Glass": 2.0,
    "House_Mirror": 2.0,
    "House_Fabric": 2.0,
    "House_Lamp": 2.0,
}

# ---------------------------------------------------------------------------
# Cotas. Un solo sitio para cada medida.
# ---------------------------------------------------------------------------
SLAB_Y0, SLAB_Y1 = 2.80, 3.00     # forjado: techo P1 (2,80) / suelo P2 (3,00)
CEIL_Y = 5.60                     # techo de planta alta
ROOF_Y0 = 5.60                    # losa de cubierta 5,60..5,75

X_W = 5.48                        # eje de muros exteriores este/oeste
Z_S, Z_N = 4.48, -5.48            # ejes de fachada y pared trasera
T_EXT = 0.24
X_WI, X_WE = -5.36, 5.36          # caras interiores (x)
Z_WI, Z_NI = 4.36, -5.36          # caras interiores (z)

X_SALA = -0.90                    # tabique sala|vestibulo (caras -0,98/-0,82)
X_HALL = 1.90                     # tabique vestibulo|este (caras 1,82/1,98)
Z_DIV = -2.28                     # tabique cocina|bano (caras -2,20/-2,36)
T_PART = 0.16

H_W1 = (0.95, 2.35)               # ventana P1 (y0, y1)
H_W2 = (3.95, 5.15)               # ventana P2
DOOR1_H = 2.15                    # altura de puerta P1
DOOR2_Y, DOOR2_H = 3.00, 1.95     # puerta de balcon (umbral arriba, 1,95 alto)

# Escalera: huella 260 x contrahuella 187,5, 16 pasos. Sube hacia +Z (sur).
STEPS, RISE, RUN = 16, 0.1875, 0.26
STAIR_X0, STAIR_X1 = 0.98, 1.78
STAIR_Z0 = -5.12                  # canto norte del primer paso
THETA = math.atan2(RISE, RUN)     # 0,6235 rad = 35,8 grados
HOLE_X0, HOLE_X1 = 0.92, 1.82     # hueco de escalera en el forjado
HOLE_Z1 = -0.96                   # borde sur del hueco (llegada a la galeria)

COLLIDERS: list[dict] = []
OBJECTS: list[tuple] = []  # (objeto, nombre de material) para unir


def B(x: float, y: float, z: float) -> Vector:
    """Godot (X, Y arriba, -Z al frente) -> Blender (Z arriba, +Y al fondo)."""
    return Vector((x, -z, y))


# ---------------------------------------------------------------------------
# Escena y materiales
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


def material(name: str, albedo: Path | None, rough: Path | None,
             normal: Path | None, color=(0.8, 0.8, 0.8, 1.0), metallic=0.0,
             roughness=0.8, normal_strength=0.75):
    """Look de Blender; en runtime el NOMBRE se reengancha a los mapas del repo.
    Sin imagenes dentro del GLB. Materiales sin textura (vidrio, espejo, tela)
    son iguales de legales: una textura se paga una vez, cero texturas no se
    paga nunca."""
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

    if albedo is not None:
        links.new(tiled(albedo, False).outputs["Color"], shader.inputs["Base Color"])
    if rough is not None:
        links.new(tiled(rough, True).outputs["Color"], shader.inputs["Roughness"])
    if normal is not None:
        bump = nodes.new("ShaderNodeNormalMap")
        bump.inputs["Strength"].default_value = normal_strength
        links.new(tiled(normal, True).outputs["Color"], bump.inputs["Color"])
        links.new(bump.outputs["Normal"], shader.inputs["Normal"])
    return mat


def cube_project(obj, scale: float) -> None:
    """UV por proyeccion cubica a densidad fisica, en ESPACIO DE MUNDO. Las dos
    paredes contiguas del mismo material comparten fase: sin costura falsa."""
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


def new_object(name: str, bm: bmesh.types.BMesh, mat):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(mat)
    OBJECTS.append((obj, mat.name))
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
    return joined


# ---------------------------------------------------------------------------
# Primitivas + colisores (el MISMO dato para las dos salidas)
# ---------------------------------------------------------------------------
def add_box(name: str, center, size, mat, bevel: float = 0.012,
            rotation=(0.0, 0.0, 0.0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector((size[0], size[2], size[1])), verts=bm.verts)
    if bevel > 0.001:
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bevel, segments=1,
                        profile=0.5, affect="EDGES")
    if any(abs(a) > 1e-6 for a in rotation):
        rot = (Matrix.Rotation(rotation[2], 4, "Z") @ Matrix.Rotation(rotation[1], 4, "Y")
               @ Matrix.Rotation(rotation[0], 4, "X"))
        for vert in bm.verts:
            vert.co = rot @ vert.co
    offset = B(center[0], center[1], center[2])
    for vert in bm.verts:
        vert.co += offset
    return new_object(name, bm, mat)


def collider(name: str, center, size, surface: str, penetrable: bool = False,
             contact=None, shape: str = "box", radius: float = 0.0,
             height: float = 0.0, thin_shell: bool = False,
             wall_thickness: float = 0.0, rot=(0.0, 0.0, 0.0)):
    COLLIDERS.append({
        "name": name, "shape": shape, "center": Vector(center), "size": Vector(size),
        "radius": radius, "height": height, "surface": surface,
        "penetrable": penetrable, "contact": Vector(contact) if contact else None,
        "thin_shell": thin_shell, "wall_thickness": wall_thickness,
        "rot": Vector(rot)})


def box(name: str, center, size, mat, surface: str, penetrable: bool = False,
        bevel: float = 0.012, contact=None, thin: float = 0.0):
    """Caja VISIBLE + su colision. ``thin`` > 0: cascara franca de grosor
    ``thin`` por pared (Ballistics cobra 2*thin)."""
    add_box(name, center, size, mat, bevel=bevel)
    collider(name, center, size, surface, penetrable, contact,
             thin_shell=thin > 0.0, wall_thickness=thin)


def plate(name: str, center, size, mat, bevel: float = 0.004):
    """Lamina DECORATIVA sin colision: suelos pegados al forjado, guarnecidos
    de pared, frentes finos. El cuerpo que los sostiene ya responde; duplicar
    el colisor seria pagar dos veces el mismo muro."""
    add_box(name, center, size, mat, bevel=bevel)


def cylinder(name: str, center, radius: float, height: float, mat, surface: str,
             segments: int = 12, penetrable: bool = False, contact=None,
             thin: float = 0.0):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segments,
                          radius1=radius, radius2=radius, depth=height)
    for vert in bm.verts:
        vert.co += B(center[0], center[1], center[2])
    new_object(name, bm, mat)
    collider(name, center, (2 * radius, height, 2 * radius), surface, penetrable,
             contact, shape="cylinder", radius=radius, height=height,
             thin_shell=thin > 0.0, wall_thickness=thin)


# ---------------------------------------------------------------------------
# Muros: panel con vanos REALES; los colisores salen del MISMO dato que el
# panel: una caja por tramo ciego y, sobre cada vano, dintel y antepecho.
# ---------------------------------------------------------------------------
def panel(name, origin, u_dir, v_dir, u_len, v_len, thickness, mat, holes=(),
          cell=0.55):
    u_dir = Vector(u_dir).normalized()
    v_dir = Vector(v_dir).normalized()
    n_dir = u_dir.cross(v_dir).normalized()
    origin = Vector(origin)
    nu = max(2, int(round(u_len / cell)))
    nv = max(2, int(round(v_len / cell)))
    du, dv = u_len / nu, v_len / nv

    # La rejilla hereda los BORDES EXACTOS de cada vano (union de lineas de
    # rejilla con u0,u1 y v0,v1, acotadas a [0, len]): la abertura geométrica
    # ES la declarada, no la cuantizada a 0,55 m. Como ninguna celda cruza un
    # borde, el centro decide igual que antes y los quads de canto
    # (if not solid(i±1,...)) caen sobre el plano del vano y cierran su jamba.
    def _lines(total, step, n, edges):
        vals = [round(k * step, 4) for k in range(n + 1)]
        vals += [round(e, 4) for e in edges if -1e-6 <= e <= total + 1e-6]
        out: list[float] = []
        for v in sorted(set(vals)):
            if not out or v - out[-1] > 1e-4:
                out.append(min(max(v, 0.0), total))
        out[0], out[-1] = 0.0, total
        return out

    us = _lines(u_len, du, nu, [e for h in holes for e in (h[0], h[1])])
    vs = _lines(v_len, dv, nv, [e for h in holes for e in (h[2], h[3])])
    nu, nv = len(us) - 1, len(vs) - 1

    def solid(i, j):
        if i < 0 or j < 0 or i >= nu or j >= nv:
            return False
        uc = (us[i] + us[i + 1]) * 0.5
        vc = (vs[j] + vs[j + 1]) * 0.5
        for (u0, u1, v0, v1) in holes:
            if u0 <= uc <= u1 and v0 <= vc <= v1:
                return False
        return True

    verts, coords, faces = {}, [], []

    def vid(i, j, side):
        key = (i, j, side)
        if key not in verts:
            coords.append(origin + u_dir * us[i] + v_dir * vs[j]
                          + n_dir * (thickness * 0.5 if side == 0 else -thickness * 0.5))
            verts[key] = len(coords) - 1
        return verts[key]

    for i in range(nu):
        for j in range(nv):
            if not solid(i, j):
                continue
            f00, f10, f11, f01 = vid(i, j, 0), vid(i + 1, j, 0), vid(i + 1, j + 1, 0), vid(i, j + 1, 0)
            b00, b10, b11, b01 = vid(i, j, 1), vid(i + 1, j, 1), vid(i + 1, j + 1, 1), vid(i, j + 1, 1)
            faces.append((f00, f10, f11, f01))
            faces.append((b00, b01, b11, b10))
            if not solid(i + 1, j):
                faces.append((f10, b10, b11, f11))
            if not solid(i - 1, j):
                faces.append((f00, b00, b01, f01))
            if not solid(i, j + 1):
                faces.append((f01, f11, b11, b01))
            if not solid(i, j - 1):
                faces.append((f00, b00, b10, f10))

    bm = bmesh.new()
    bverts = [bm.verts.new(p) for p in coords]
    bm.verts.ensure_lookup_table()
    for f in faces:
        try:
            bm.faces.new([bverts[k] for k in f])
        except ValueError:
            continue
    new_object(name, bm, mat)


def wall(name, axis, at, lo, hi, y0, y1, mat, surface, penetrable=False, holes=(),
         thickness=T_EXT, cell=0.55, thin: float = 0.0):
    """Muro vertical con vanos. axis "x" (recorre X, plano a z=at) o "z".
    ``thin``>0: tabique de doble placa (cascara), no macizo."""
    if axis == "x":
        origin, u_dir, v_dir = B(lo, y0, at), (1, 0, 0), (0, 0, 1)
    else:
        origin, u_dir, v_dir = B(at, y0, lo), (0, -1, 0), (0, 0, 1)
    panel(name, origin, u_dir, v_dir, hi - lo, y1 - y0, thickness, mat, holes, cell)

    breaks = [0.0, hi - lo]
    for (u0, u1, _v0, _v1) in holes:
        breaks += [u0, u1]
    breaks = sorted(set(round(v, 4) for v in breaks))
    H = y1 - y0
    for k in range(len(breaks) - 1):
        a, b = breaks[k], breaks[k + 1]
        if b - a <= 0.02:
            continue
        spans = [(0.0, H)]
        for (u0, u1, v0, v1) in holes:
            if a >= u0 - 0.01 and b <= u1 + 0.01:
                low = [(s0, min(s1, v0)) for (s0, s1) in spans if s0 < v0]
                high = [(max(s0, v1), s1) for (s0, s1) in spans if s1 > v1]
                spans = low + high
        for (v0, v1) in spans:
            if v1 - v0 <= 0.03:
                continue
            cu, cy = lo + (a + b) * 0.5, y0 + (v0 + v1) * 0.5
            if axis == "x":
                center = Vector((cu, cy, at))
                size = Vector((b - a, v1 - v0, thickness))
            else:
                center = Vector((at, cy, cu))
                size = Vector((thickness, v1 - v0, b - a))
            collider(f"{name}_col", center, size, surface, penetrable,
                     thin_shell=thin > 0.0, wall_thickness=thin)


def slab(name, y, x0, x1, z0, z1, thickness, mat, surface, penetrable=False,
         holes=(), cell=0.8, colision=True):
    """Losa horizontal con su CARA INFERIOR en y. Vanos en (dx0, dx1, dz0, dz1)
    locales desde (x0, z0): el hueco de escalera deja de emitir colision Y de
    existir en geometria (del MISMO dato salen ambos). ``cell`` grande = un solo
    quad (el suelo plano no necesita rejilla: eran 36.840 tris de relleno);
    ``colision=False`` para terreno lejano que ningun jugador pisa (los
    bordillos ya cierran el recorrido y el costo de 4 cuerpos a 40 m es puro
    broadphase)."""
    panel(name, B(x0, y + thickness * 0.5, z0), (1, 0, 0), (0, -1, 0),
          x1 - x0, z1 - z0, thickness, mat, holes, cell)
    if not colision:
        return
    breaks = sorted(set([0.0, x1 - x0] + [v for h in holes for v in (h[0], h[1])]))
    for k in range(len(breaks) - 1):
        a, b = breaks[k], breaks[k + 1]
        if b - a <= 0.02:
            continue
        spans = [(0.0, z1 - z0)]
        for (dx0, dx1, dz0, dz1) in holes:
            if a >= dx0 - 0.01 and b <= dx1 + 0.01:
                low = [(s0, min(s1, dz0)) for (s0, s1) in spans if s0 < dz0]
                high = [(max(s0, dz1), s1) for (s0, s1) in spans if s1 > dz1]
                spans = low + high
        for (v0, v1) in spans:
            if v1 - v0 <= 0.02:
                continue
            collider(f"{name}_col",
                     Vector((x0 + (a + b) * 0.5, y + thickness * 0.5, z0 + (v0 + v1) * 0.5)),
                     Vector((b - a, thickness, v1 - v0)), surface, penetrable)


# ---------------------------------------------------------------------------
# Carpinteria: vanos con marco, vidrio y hoja REALES
# ---------------------------------------------------------------------------
def _place(axis, at, u, y):
    if axis == "x":
        return Vector((u, y, at))
    return Vector((at, y, u))


def _span(axis, su, sy, depth):
    if axis == "x":
        return Vector((su, sy, depth))
    return Vector((depth, sy, su))


def window(axis, at, lo_u, hi_u, y0, y1, mats, tag, broken_high=False):
    """Marco de roble con travesera central + dos hojas de vidrio de 3,5 mm.

    El vidrio es cascara YESO: la 9 mm lo rompe sin perder nada y el polvo de
    impacto blanco lee "cristal". ``broken_high`` deja la hoja superior SIN
    cristal: el hueco abierto es una pieza que FALTA, no un muro invisible.
    Alféizar de obra por fuera del plano del marco.
    """
    w, h = hi_u - lo_u, y1 - y0
    cu, cy = (lo_u + hi_u) * 0.5, (y0 + y1) * 0.5
    f = 0.06
    for part, su, sy, uu, yy in [
        ("bot", w, f, cu, y0 + f / 2), ("top", w, f, cu, y1 - f / 2),
        ("l", f, h, lo_u + f / 2, cy), ("r", f, h, hi_u - f / 2, cy),
        ("mid", 0.045, h - 2 * f, cu, cy),
    ]:
        c, s = _place(axis, at, uu, yy), _span(axis, su, sy, T_EXT - 0.04)
        plate(f"{tag}_{part}", c, s, mats["wood"])
        # El marco es tablon de 20 cm de roble VISIBLE: sin colisor se dispara
        # a traves de la madera. Cascara pine 30 mm, la del muro exterior (la
        # bala paga 2 x 30 = 60 mm al cruzar el canto, igual que por pared).
        collider(f"{tag}_{part}", c, s, "pine", True,
                 thin_shell=True, wall_thickness=0.03)
    plate(f"{tag}_sill", _place(axis, at, cu, y0 - 0.04),
          _span(axis, w + 0.12, 0.07, 0.34), mats["siding"])
    inner = h / 2 - f - 0.02
    panes = [(cy - (f + inner) / 2, inner)]
    if not broken_high:
        panes.append((cy + (f + inner) / 2, inner))
    for k, (py, hh) in enumerate(panes):
        add_box(f"{tag}_glass{k}", _place(axis, at, cu, py),
                _span(axis, w - 2 * f, hh, 0.008), mats["glass"], bevel=0.0)
        collider(f"{tag}_glass{k}", _place(axis, at, cu, py),
                 _span(axis, w - 2 * f, hh, 0.008), "gypsum", True,
                 thin_shell=True, wall_thickness=0.0035)


def door_leaf(axis, at, lo_u, hi_u, y0, h, mats, tag, glazed=False,
              open_to=None):
    """Hoja de puerta: tablero de 45 mm declarado cascara pine 22 mm (una hoja
    real SON 4 cm: la bala la cruza perdiendo poco). ``open_to`` coloca la hoja
    girada 90 grados apoyada en el muro de dentro: se ve, se dispara, no cierra
    el paso. ``glazed``: mitad superior de vidrio (puerta trasera de casa).
    """
    w = hi_u - lo_u
    if open_to is not None:
        # Abierta: eje en el quicio ``open_to`` (lado en u), hoja recorriendo el
        # muro 14 cm hacia dentro.
        cz = at - 0.14 if axis == "x" else None
        if axis == "x":
            center = Vector((open_to + math.copysign(w / 2, open_to - (lo_u + hi_u) / 2),
                             y0 + h / 2, at - 0.14))
            size = Vector((w, h, 0.045))
        else:
            center = Vector((at - 0.14, y0 + h / 2,
                             open_to + math.copysign(w / 2, open_to - (lo_u + hi_u) / 2)))
            size = Vector((0.045, h, w))
    else:
        center = _place(axis, at, (lo_u + hi_u) / 2, y0 + h / 2)
        size = _span(axis, w, h, 0.045)
    add_box(f"{tag}_leaf", center, size, mats["wood"], bevel=0.008)
    if glazed and open_to is None:
        # La ventana de la hoja vive en el MISMO plano del tablero: la bala la
        # casca (cascara yeso 3,5 mm) y despues cruza el tablerillo de abajo.
        g_center = _place(axis, at, (lo_u + hi_u) / 2, y0 + h * 0.74)
        g_size = _span(axis, w - 0.18, h * 0.40, 0.008)
        add_box(f"{tag}_glass", g_center, g_size, mats["glass"], bevel=0.0)
        collider(f"{tag}_glass", g_center, g_size, "gypsum", True,
                 thin_shell=True, wall_thickness=0.0035)
    collider(f"{tag}_leaf", center, size, "pine", True,
             thin_shell=True, wall_thickness=0.0225)


def door_french(axis, at, lo_u, hi_u, y0, h, mats, tag, open_inward=False):
    """Ventanales FRANCESES dobles: dos hojas casi todo cristal (palo central y
    travesera de madera). La hoja abierta apoya en el muro de dentro a 90
    grados: se ve, se dispara, no cierra el paso.

    El colisor de cada hoja CERRADA es cascara YESO de 3,5 mm: el area de
    cristal DOMINA la hoja (un ventanal no es un tablon) y la bala lo trata
    como lo que es. El jugador si choca: la caja cubre la hoja entera.
    """
    lw = (hi_u - lo_u) / 2.0
    mid = (lo_u + hi_u) / 2.0
    for s in (-1.0, 1.0):
        side = "L" if s < 0 else "R"
        if open_inward:
            hinge = mid + s * lw
            run = lw - 0.02
            if axis == "x":
                center = Vector((hinge + s * run / 2, y0 + h / 2, at - 0.15))
                size = Vector((run, h, 0.045))
            else:
                center = Vector((at - 0.15, y0 + h / 2, hinge + s * run / 2))
                size = Vector((0.045, h, run))
            add_box(f"{tag}_{side}", center, size, mats["wood"], bevel=0.006)
            collider(f"{tag}_{side}", center, size, "pine", True,
                     thin_shell=True, wall_thickness=0.0225)
            continue
        c = _place(axis, at, mid + s * lw / 2, y0 + h / 2)
        size = _span(axis, lw - 0.02, h, 0.05)
        add_box(f"{tag}_{side}", c, size, mats["glass"], bevel=0.0)
        add_box(f"{tag}_{side}_rail", _place(axis, at, mid + s * lw / 2, y0 + h * 0.55),
                _span(axis, lw - 0.02, 0.05, 0.07), mats["wood"], bevel=0.004)
        add_box(f"{tag}_{side}_stail", c, _span(axis, 0.045, h - 0.06, 0.07),
                mats["wood"], bevel=0.004)
        collider(f"{tag}_{side}", c, size, "gypsum", True,
                 thin_shell=True, wall_thickness=0.0035)


def jamb(axis, at, lo_u, hi_u, y0, y1, mats, tag):
    """Revestido de roble dentro del vano de puerta: 3 piezas pegas al quicio.
    Decorativo: la colision del muro ya llega hasta el borde del vano."""
    f = 0.04
    depth = T_EXT - 0.02 if abs(at) > 5 else T_PART - 0.01
    mid = (lo_u + hi_u) / 2
    for uu, su in [(lo_u + f / 2, f), (hi_u - f / 2, f)]:
        plate(f"{tag}_j{uu}", _place(axis, at, uu, (y0 + y1) / 2),
              _span(axis, su, y1 - y0, depth), mats["wood"])
    plate(f"{tag}_jtop", _place(axis, at, mid, y1 - f / 2),
          _span(axis, hi_u - lo_u - 2 * f, f, depth), mats["wood"])


# ---------------------------------------------------------------------------
# Barandillas: pasamanos + balaustres, y SU colision (nadie se cae por un hueco
# dibujado; el pasamanos es cascaron pine que para balas ligeras)
# ---------------------------------------------------------------------------
def rail(name, p0, p1, y_floor, mats, tag, mat_key="wood"):
    """Barandilla REAL: p0/p1 son (x, z). Balaustres + pasamanos. Las dos cajas
    de colision (pasamanos y linea de balaustres) son cascaron pine: nadie se
    cae al vaco y la bala las casca como listones de madera."""
    dx, dz = p1[0] - p0[0], p1[1] - p0[1]
    length = math.hypot(dx, dz)
    along_x = abs(dx) > abs(dz)
    cx, cz = (p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2
    h = 1.0
    size = Vector((length, 0.06, 0.09)) if along_x else Vector((0.09, 0.06, length))
    add_box(f"{name}_hand", Vector((cx, y_floor + h, cz)), size, mats[mat_key], bevel=0.008)
    n = max(2, int(round(length / 0.32)))
    for k in range(n + 1):
        t = k / n
        add_box(f"{name}_p{k}", Vector((p0[0] + dx * t, y_floor + (h - 0.03) / 2,
                                        p0[1] + dz * t)),
                Vector((0.045, h - 0.03, 0.045)), mats[mat_key], bevel=0.004)
    collider(f"{name}_hand", Vector((cx, y_floor + h, cz)), size, "pine", True,
             thin_shell=True, wall_thickness=0.03)
    collider(f"{name}_posts", Vector((cx, y_floor + h / 2, cz)),
             Vector((length, h, 0.06)) if along_x else Vector((0.06, h, length)),
             "pine", True, thin_shell=True, wall_thickness=0.022)


# ---------------------------------------------------------------------------
# Escalera: geometria de peldanos + rampa continua de colision
# ---------------------------------------------------------------------------
def staircase(mats):
    xc = (STAIR_X0 + STAIR_X1) / 2.0
    hyp = math.hypot(RISE, RUN)
    for t in range(1, STEPS + 1):
        zc = STAIR_Z0 + RUN * (t - 0.5)
        plate(f"Stair_t{t}", Vector((xc, RISE * t - 0.025, zc)),
              Vector((STAIR_X1 - STAIR_X0, 0.05, RUN)), mats["wood"], bevel=0.005)
    for t in range(0, STEPS):
        plate(f"Stair_r{t}", Vector((xc, RISE * t + RISE / 2,
                                     STAIR_Z0 + RUN * t - 0.016)),
              Vector((STAIR_X1 - STAIR_X0, RISE, 0.032)), mats["wood"],
              bevel=0.003)
    # La linea de narices va de (z=STAIR_Z0, y=0) a (z=-0.96, y=3.0). Rampa de
    # colision: caja girada -35,8 grados cuya CARA SUPERIOR es esa linea, del
    # paso -0.6 (entra en el suelo: dos solidos solapados no se pelean) al paso
    # 16 exacto, que es el borde del forjado: ni un diente sobre la galeria.
    t_c = (STEPS - 0.6) / 2.0
    p_mid = Vector((xc, RISE * t_c, STAIR_Z0 + RUN * t_c))
    up = Vector((0, RUN, -RISE)).normalized()
    L = (STEPS + 0.6) * hyp
    for xs in (STAIR_X0 - 0.028, STAIR_X1 + 0.028):
        add_box(f"Stair_stringer_{xs:.2f}", p_mid - up * 0.17 + Vector((xs - xc, 0, 0)),
                Vector((0.055, 0.34, L)), mats["wood"], bevel=0.004,
                rotation=(-THETA, 0, 0))
    collider("Stair_ramp", p_mid - up * 0.19,
             Vector((STAIR_X1 - STAIR_X0, 0.38, L)), "pine", False,
             rot=(-THETA, 0.0, 0.0))



# ---------------------------------------------------------------------------
# La casa
# ---------------------------------------------------------------------------
def build() -> None:
    reset_scene()
    M = {
        # FACHADA USA: entablado horizontal de madera PINTADA DE BLANCO. No hay
        # textura de siding en el repo y no se paga una nueva: el roble existe
        # y una mano de pintura es exactamente "misma madera, color casi blanco,
        # roughness arriba, normal abajo". El runtime reengancha este nombre a
        # la textura de roble con ese tinte.
        "siding": material(
            "House_Siding", TEXTURES / "wood_oak_wood_planks_diff.jpg",
            TEXTURES / "wood_oak_wood_planks_rough.jpg",
            TEXTURES / "wood_oak_wood_planks_nor_gl.jpg",
            color=(0.85, 0.83, 0.78), roughness=0.85, normal_strength=0.5),
        "tile": material(
            "House_Tile", TEXTURES / "concrete_brushed_concrete_diff.jpg",
            TEXTURES / "concrete_brushed_concrete_rough.jpg",
            TEXTURES / "concrete_brushed_concrete_nor_gl.jpg",
            color=(0.56, 0.54, 0.51), roughness=0.72, normal_strength=0.45),
        "wood": material(
            "House_Wood", TEXTURES / "wood_oak_wood_planks_diff.jpg",
            TEXTURES / "wood_oak_wood_planks_rough.jpg",
            TEXTURES / "wood_oak_wood_planks_nor_gl.jpg",
            color=(0.55, 0.41, 0.26), roughness=0.78, normal_strength=0.9),
        "gypsum": material(
            "House_Gypsum", TEXTURES / "gypsum_diff.jpg", TEXTURES / "gypsum_rough.jpg",
            None, color=(0.86, 0.82, 0.74), roughness=0.9),
        "metal": material(
            "House_Metal", TEXTURES / "metal_metal_plate_diff.jpg",
            TEXTURES / "metal_metal_plate_rough.jpg",
            TEXTURES / "metal_metal_plate_nor_gl.jpg",
            color=(0.55, 0.57, 0.60), metallic=0.75, roughness=0.38,
            normal_strength=0.7),
        # Cero textura: el vidrio se paga con dos numeros. Oscuro y pulido:
        # de dia espejea el cielo y de noche come luz.
        "glass": material("House_Glass", None, None, None,
                          color=(0.045, 0.055, 0.065), metallic=0.3, roughness=0.06),
        "mirror": material("House_Mirror", None, None, None,
                           color=(0.80, 0.84, 0.88), metallic=0.95, roughness=0.05),
        "fabric": material("House_Fabric", None, None, None,
                           color=(0.30, 0.31, 0.34), roughness=0.95),
        # Campana de lampara: AMBAR PLANO sin textura. Medido en captura depot:
        # la chapa sobre 26 cm de pantalla era una mancha naranja ruidosa (el
        # 6). Sin veta ni herrumbre, con emision en runtime, lee a bombilla.
        "lamp": material("House_Lamp", None, None, None,
                         color=(0.95, 0.78, 0.50), roughness=0.60),
    }

    # ---- suelo del mundo ------------------------------------------------------
    # LOSAS PLANAS SIN VANOS a celda unica (cell=999): la rejilla de 0.8 las
    # partia en miles de quads inutiles (solo el Ground eran 36.840 tris).
    slab("Ground", -0.30, -7.4, 7.4, -7.8, 8.6, 0.30, M["tile"], "concrete",
         cell=999)

    # ---- REMATE DE CALLE (el patio cerraba en corte recto contra cielo) ------
    # La solar termina en x=+7.4 y desde el spawn se veia el vacio tras el canto
    # (captura patio x1050-1400). Remate real de manzana USA: la ACERA levantada
    # +0.12 con su cara de bordillo contra la parcela, la CALLE a nivel, la acera
    # del otro lado, y relleno hasta 40 m para que el borde muera en el horizonte.
    # La calle corre de norte a sur a lo largo de toda la manzana (z -30..30).
    # SIN SALIDA: la cara de +0.12 bloquea al CharacterBody (no hay paso de
    # bordillo) y el perimetro del relleno lleva bordillo de 0.30 a 30-40 m.
    slab("Sidewalk_E", 0.0, 7.4, 8.9, -30.0, 30.0, 0.12, M["tile"], "concrete",
         cell=999)
    slab("Street_E", -0.12, 8.9, 11.9, -30.0, 30.0, 0.12, M["tile"], "concrete",
         cell=999)
    slab("Sidewalk_E2", 0.0, 11.9, 13.4, -30.0, 30.0, 0.12, M["tile"], "concrete",
         cell=999)
    # Relleno lejano: MISMA cota que la parcela (se camina hasta el bordillo
    # perimetral), asi que CON colision: quitarla abria un caida al vacio en
    # los tres lados sin acera. El ahorro de FPS no estaba en los cuerpos.
    slab("Fill_E", -0.30, 13.4, 40.0, -30.0, 30.0, 0.30, M["tile"], "concrete",
         cell=999)
    slab("Fill_N", -0.30, -40.0, 7.4, -30.0, -7.8, 0.30, M["tile"], "concrete",
         cell=999)
    slab("Fill_S", -0.30, -40.0, 7.4, 8.6, 30.0, 0.30, M["tile"], "concrete",
         cell=999)
    slab("Fill_W", -0.30, -40.0, -7.4, -7.8, 8.6, 0.30, M["tile"], "concrete",
         cell=999)
    slab("Curb_BN", 0.0, -40.0, 40.0, -30.4, -30.0, 0.30, M["tile"], "concrete",
         cell=999)
    slab("Curb_BS", 0.0, -40.0, 40.0, 30.0, 30.4, 0.30, M["tile"], "concrete",
         cell=999)
    slab("Curb_BE", 0.0, 40.0, 40.4, -30.4, 30.4, 0.30, M["tile"], "concrete",
         cell=999)
    slab("Curb_BW", 0.0, -40.4, -40.0, -30.4, 30.4, 0.30, M["tile"], "concrete",
         cell=999)

    # ---- obra exterior (una pieza por fachada, dos plantas de vanos) ---------
    front_holes = [
        (1.3, 3.3, *H_W1),                      # ventana salon
        (5.05, 6.15, 0.0, DOOR1_H),             # puerta de calle
        (5.05, 6.15, 3.50, 5.15),               # ventana alta de galeria
        (8.80, 9.75, 3.00, 4.95),               # puerta del balcon
        (1.3, 3.3, *H_W2),                      # ventana dormitorio
    ]
    wall("W_Front", "x", Z_S, -5.6, 5.6, 0.0, CEIL_Y, M["siding"], "pine",
         True, holes=front_holes, thin=0.03)
    back_holes = [
        (2.2, 4.0, *H_W1),                      # ventana trasera del salon
        (5.05, 6.15, 0.0, DOOR1_H),             # puerta trasera acristalada
        (8.3, 9.3, 1.70, 2.30),                 # ventanita del bano
        (1.7, 3.3, *H_W2),                      # ventana trasera dormitorio
        (8.2, 9.8, *H_W2),                      # ventana trasera estudio
    ]
    wall("W_Back", "x", Z_N, -5.6, 5.6, 0.0, CEIL_Y, M["siding"], "pine",
         True, holes=back_holes, thin=0.03)
    west_holes = [
        (2.4, 4.4, *H_W1),                      # ventana lateral del salon
        (5.8, 7.4, *H_W2),                      # ventana lateral dormitorio
    ]
    wall("W_West", "z", -X_W, -5.6, 5.6, 0.0, CEIL_Y, M["siding"], "pine",
         True, holes=west_holes, thin=0.03)
    east_holes = [
        (6.8, 8.4, 1.30, 2.35),                 # ventana de cocina
        (1.0, 2.2, 1.70, 2.30),                 # ventana del bano
        (2.0, 3.6, *H_W2),                      # ventana del estudio
    ]
    wall("W_East", "z", X_W, -5.6, 5.6, 0.0, CEIL_Y, M["siding"], "pine",
         True, holes=east_holes, thin=0.03)

    # Carpinteria de fachada: cada vano de su lista de huecos, en MUNDO.
    window("x", Z_S, -4.30, -2.30, *H_W1, M, "Win_F_Sala")
    window("x", Z_S, -0.55, 0.55, 3.50, 5.15, M, "Win_F_Galeria")
    window("x", Z_S, -4.30, -2.30, *H_W2, M, "Win_F_Dorm")
    door_french("x", Z_S, 3.20, 4.15, DOOR2_Y, DOOR2_H, M, "Door_Balcon")
    window("x", Z_N, -3.40, -1.60, *H_W1, M, "Win_B_Sala")
    window("x", Z_N, 2.70, 3.70, 1.70, 2.30, M, "Win_B_Bano", broken_high=True)
    window("x", Z_N, -3.90, -2.30, *H_W2, M, "Win_B_Dorm")
    window("x", Z_N, 2.60, 4.20, *H_W2, M, "Win_B_Estudio")
    window("z", -X_W, -3.20, -1.20, *H_W1, M, "Win_W_Sala")
    window("z", -X_W, 0.20, 1.80, *H_W2, M, "Win_W_Dorm", broken_high=True)
    window("z", X_W, 1.20, 2.80, 1.30, 2.35, M, "Win_E_Cocina")
    window("z", X_W, -4.60, -3.40, 1.70, 2.30, M, "Win_E_Bano", broken_high=True)
    window("z", X_W, -3.60, -2.00, *H_W2, M, "Win_E_Estudio")

    # Puertas FRANCEAS vidriadas: la de calle, doble hoja ABIERTA apoyada en
    # los muros del vestibulo (se ve, se dispara, no cierra el paso); la
    # trasera al deck y la del balcon, CERRADAS: son cristal de 3,5 mm y la
    # bala las casca, pero el jugador choca con la hoja entera.
    door_french("x", Z_S, -0.55, 0.55, 0.0, DOOR1_H, M, "Door_Street",
                open_inward=True)
    door_french("x", Z_N, -0.55, 0.55, 0.0, DOOR1_H, M, "Door_Back")
    jamb("x", Z_S, -0.55, 0.55, 0.0, DOOR1_H, M, "Jamb_Street")
    jamb("x", Z_N, -0.55, 0.55, 0.0, DOOR1_H, M, "Jamb_Back")

    # ---- forjado, cubierta, balcon: MADERA a la vista en cantos --------------
    slab("Slab2", SLAB_Y0, X_WI, X_WE, Z_NI, Z_WI, 0.20, M["wood"], "pine", True,
         holes=[(HOLE_X0 - X_WI, HOLE_X1 - X_WI, 0.0, HOLE_Z1 - Z_NI)])
    slab("Roof", ROOF_Y0, -5.6, 5.6, -5.6, 4.6, 0.15, M["wood"], "pine", True)
    box("Balcony", (3.70, 2.90, 5.45), (1.60, 0.20, 1.70), M["wood"],
        "pine", True, thin=0.05, contact=(0.80, 0.85))
    rail("Rail_Balcon_S", (2.95, 6.25), (4.45, 6.25), 3.0, M, "balk", "siding")
    rail("Rail_Balcon_W", (2.95, 4.68), (2.95, 6.25), 3.0, M, "balk", "siding")
    rail("Rail_Balcon_E", (4.45, 4.68), (4.45, 6.25), 3.0, M, "balk", "siding")

    # ---- PORCHE frontal: deck, techo de madera sobre 4 postes, barandal con
    #      portillo AL CENTRO (la linea recta del spawn entra por el medio:
    #      check_walk pasa entre los barrotes, igual que una persona). --------
    # Deck por tablas (plancha unitaria leia a losa negra: defecto medido).
    for k in range(8):
        plate(f"Porch_Plank_{k}", (0.0, 0.013, 4.68 + 0.24 * k),
              (3.90, 0.026, 0.215), M["wood"])
    # Techo RECORTADO: antes volaba 2.16 m y a la altura de los ojos del spawn
    # se comia el 40 % del cuadro (medido en depot). Vuelo 1.5 m, madero a
    # 2.50: sigue cubriendo el vano, deja leer la fachada.
    for px, pz in [(-1.85, 6.05), (1.85, 6.05), (-1.85, 4.72), (1.85, 4.72)]:
        box(f"Porch_Post_{px:.2f}_{pz:.2f}", (px, 1.25, pz), (0.12, 2.50, 0.12),
            M["siding"], "pine", True, bevel=0.006)
    box("Porch_Roof", (0.0, 2.55, 5.34), (4.20, 0.12, 1.50), M["siding"],
        "pine", True, thin=0.009, bevel=0.008)
    # Cornisa: banda de cierre alrededor del madero (el corte duro del alero
    # contra el cielo era el defecto 4).
    plate("Porch_Cornice_T", (0.0, 2.645, 5.32), (4.44, 0.07, 1.76), M["siding"])
    plate("Porch_Cornice_F", (0.0, 2.565, 6.13), (4.44, 0.20, 0.06), M["siding"])
    plate("Porch_Cornice_W", (-2.16, 2.565, 5.32), (0.06, 0.20, 1.76), M["siding"])
    plate("Porch_Cornice_E", (2.16, 2.565, 5.32), (0.06, 0.20, 1.76), M["siding"])
    rail("Rail_Porch_W", (-1.85, 4.72), (-1.85, 6.05), 0.0, M, "porch", "siding")
    rail("Rail_Porch_E", (1.85, 4.72), (1.85, 6.05), 0.0, M, "porch", "siding")
    rail("Rail_Porch_S1", (-1.79, 6.05), (-0.62, 6.05), 0.0, M, "porch", "siding")
    rail("Rail_Porch_S2", (0.62, 6.05), (1.79, 6.05), 0.0, M, "porch", "siding")

    # ---- DECK trasero al patio (la puerta francesa sale a el) ----------------
    for k in range(6):
        plate(f"Deck_Plank_{k}", (0.0, 0.013, -5.70 - 0.25 * k),
              (4.00, 0.026, 0.225), M["wood"])
    rail("Rail_Deck_W", (-1.95, -5.62), (-1.95, -7.05), 0.0, M, "deck")
    rail("Rail_Deck_E", (1.95, -5.62), (1.95, -7.05), 0.0, M, "deck")
    rail("Rail_Deck_S1", (-1.95, -7.05), (-0.62, -7.05), 0.0, M, "deck")
    rail("Rail_Deck_S2", (0.62, -7.05), (1.95, -7.05), 0.0, M, "deck")

    # ---- tabiqueria (doble placa: cascaron yeso de 12,5 mm) ------------------
    wall("P_Sala_F1", "z", X_SALA, Z_NI, Z_WI, 0.0, SLAB_Y0, M["gypsum"], "gypsum",
         True, holes=[(1.06, 2.16, 0.0, DOOR1_H), (5.76, 7.56, 0.0, 2.45)],
         thickness=T_PART, thin=0.0125)
    wall("P_Sala_F2", "z", X_SALA, Z_NI, Z_WI, SLAB_Y1, CEIL_Y, M["gypsum"],
         "gypsum", True, holes=[(2.76, 3.86, 0.0, DOOR1_H)], thickness=T_PART,
         thin=0.0125)
    wall("P_Hall_F1", "z", X_HALL, Z_NI, Z_WI, 0.0, SLAB_Y0, M["gypsum"], "gypsum",
         True, holes=[(5.96, 7.06, 0.0, DOOR1_H)], thickness=T_PART, thin=0.0125)
    wall("P_Hall_F2", "z", X_HALL, Z_NI, Z_WI, SLAB_Y1, CEIL_Y, M["gypsum"],
         "gypsum", True, holes=[(5.96, 7.06, 0.0, DOOR1_H)], thickness=T_PART,
         thin=0.0125)
    wall("P_Div", "x", Z_DIV, 1.98, 5.36, 0.0, SLAB_Y0, M["gypsum"], "gypsum",
         True, holes=[(0.37, 1.27, 0.0, DOOR1_H)], thickness=T_PART, thin=0.0125)
    jamb("z", X_SALA, -4.30, -3.20, 0.0, DOOR1_H, M, "Jamb_Sala")
    jamb("z", X_SALA, -2.60, -1.50, SLAB_Y1, SLAB_Y1 + DOOR1_H, M, "Jamb_Dorm")
    door_leaf("z", X_SALA, -2.60, -1.50, SLAB_Y1, DOOR1_H, M, "Door_Dorm",
              open_to=-1.50)

    # ---- revestimiento interior de la obra (yeso, sin colision propia: la
    #      caja del muro ya responde; el forro es una lamina de 24 mm pegada) --
    for tag, ax, at, holes_all, y0, y1 in [
        ("Ln_F1_Front", "x", Z_S - 0.13, front_holes, 0.0, SLAB_Y0),
        ("Ln_F2_Front", "x", Z_S - 0.13, front_holes, SLAB_Y1, CEIL_Y),
        ("Ln_F1_Back", "x", Z_N + 0.13, back_holes, 0.0, SLAB_Y0),
        ("Ln_F2_Back", "x", Z_N + 0.13, back_holes, SLAB_Y1, CEIL_Y),
        ("Ln_F1_West", "z", -X_W + 0.13, west_holes, 0.0, SLAB_Y0),
        ("Ln_F2_West", "z", -X_W + 0.13, west_holes, SLAB_Y1, CEIL_Y),
        ("Ln_F1_East", "z", X_W - 0.13, east_holes, 0.0, SLAB_Y0),
        ("Ln_F2_East", "z", X_W - 0.13, east_holes, SLAB_Y1, CEIL_Y),
    ]:
        holes = [(a, b, v0 - y0, v1 - y0) for (a, b, v0, v1) in holes_all
                 if v0 >= y0 - 0.01 and v1 <= y1 + 0.01]
        o, u, v = wall_axes(ax, at, -5.6, y0)
        panel(tag, o, u, v, 11.2, y1 - y0, 0.024, M["gypsum"], holes, 0.7)

    # ---- escalera --------------------------------------------------------------
    staircase(M)
    rail("Rail_Galeria", (HOLE_X0, -5.20), (HOLE_X0, -1.06), SLAB_Y1, M, "gal")

    # ---- suelos, techos, remates ------------------------------------------------
    finishes(M)

    # ---- muebles y cobertura -----------------------------------------------------
    furniture(M)

    merge_and_export()


def wall_axes(axis, at, lo, y0):
    """(origin, u_dir, v_dir) del plano del muro, en coords de Blender."""
    if axis == "x":
        return B(lo, y0, at), (1, 0, 0), (0, 0, 1)
    if axis == "z":
        return B(at, y0, lo), (0, -1, 0), (0, 0, 1)
    return B(lo, y0, at), (1, 0, 0), (0, -1, 0)


# ---------------------------------------------------------------------------
# Acabados: suelos nobles sobre la losa, techos de escayola, todo con el MISMO
# criterio: lamina decorativa sin colision (la losa de arriba ya responde).
# ---------------------------------------------------------------------------
def finishes(M):
    W, T, G = M["wood"], M["tile"], M["gypsum"]
    # Suelos P1: ROBLE por toda la casa (pisos de madera, no gres).
    plate("Floor_Sala", (-3.17, 0.011, -0.50), (4.38, 0.022, 9.72), W)
    plate("Floor_Hall", (0.50, 0.011, -0.50), (2.64, 0.022, 9.72), W)
    plate("Floor_Cocina", (3.67, 0.011, 1.08), (3.38, 0.022, 6.56), W)
    plate("Floor_Bano", (3.67, 0.011, -3.78), (3.38, 0.022, 3.16), W)
    for k in range(6):
        plate(f"Balcon_Plank_{k}", (3.70, 2.999, 4.74 + 0.28 * k),
              (1.58, 0.018, 0.255), W)
    # Suelos P2: roble en dormitorios/estudio; galeria con el hueco de escalera.
    plate("Floor_Dorm", (-3.17, 3.011, -0.50), (4.38, 0.022, 9.72), W)
    plate("Floor_Estudio", (3.67, 3.011, -0.50), (3.38, 0.022, 9.72), W)
    panel("Floor_Galeria", B(X_SALA + 0.08, SLAB_Y1, Z_NI), (1, 0, 0), (0, -1, 0),
          2.64, 9.72, 0.022, W,
          [(HOLE_X0 - (X_SALA + 0.08), HOLE_X1 - (X_SALA + 0.08),
            0.0, HOLE_Z1 - Z_NI)], 0.8)
    # Techos: escayola bajo el forjado (P1) y bajo la cubierta (P2).
    plate("Ceil_Sala", (-3.17, SLAB_Y0 - 0.011, -0.50), (4.38, 0.022, 9.72), G)
    plate("Ceil_Este", (3.67, SLAB_Y0 - 0.011, -0.50), (3.38, 0.022, 9.72), G)
    panel("Ceil_Hall", B(-0.82, SLAB_Y0 - 0.022, Z_NI), (1, 0, 0), (0, -1, 0),
          2.64, 9.72, 0.022, G,
          [(HOLE_X0 + 0.82, HOLE_X1 + 0.82, 0.0, HOLE_Z1 - Z_NI)], 0.8)
    plate("Ceil_Dorm", (-3.17, CEIL_Y - 0.011, -0.50), (4.38, 0.022, 9.72), G)
    plate("Ceil_Estudio", (3.67, CEIL_Y - 0.011, -0.50), (3.38, 0.022, 9.72), G)
    plate("Ceil_Galeria", (0.50, CEIL_Y - 0.011, -0.50), (2.64, 0.022, 9.72), G)
    # LAMPARAS de techo en cada recinto: campana AMBAR (material propio, cero
    # textura, emision en runtime) + vastago de chapa. Decorativas, cero
    # colision: el techo ya responde. CUIDADO (medido): la campana NO puede
    # heredar House_Metal: 26 cm de chapa herrumbrosa = mancha naranja ruido.
    for tag, lx, ly, lz in [("Lamp_Sala", -2.6, 2.42, 0.6), ("Lamp_Hall", 0.5, 2.42, 2.6),
                            ("Lamp_Cocina", 3.5, 2.42, 1.8), ("Lamp_Dorm", -3.0, 5.25, 0.8),
                            ("Lamp_Estudio", 3.5, 5.25, -1.2)]:
        plate(f"{tag}_stem", (lx, ly + 0.19, lz), (0.025, 0.32, 0.025), M["metal"])
        add_box(f"{tag}_shade", (lx, ly, lz), (0.26, 0.11, 0.26), M["lamp"],
                bevel=0.02)


# ---------------------------------------------------------------------------
# Muebles: cobertura jugable. Criterio balistico de casa real:
#   - tablero macizo de 4 cm = pine SOLIDO para piezas que paran (bastidor de
#     cama, ropero, sofa); la bala se queda dentro, y eso es cobertura.
#   - tapizado y colchon = cascara yeso/paper: no paran nada, se ven y suenan.
#   - encimera/mesa = cascara pine 22 mm: la bala pasa de tabla a tabla.
#   - electrodomesticos de acero y ceramica de bano: los macizos paran, las
#     cascaras finas (fregadero, radiadores, espejos) se cascan y pasan.
# ---------------------------------------------------------------------------
def furniture(M):
    W, G, T = M["wood"], M["gypsum"], M["tile"]
    MET, GL, MIR, F = M["metal"], M["glass"], M["mirror"], M["fabric"]

    # ---- 1. SALA -------------------------------------------------------------
    box("Sofa_base", (-3.05, 0.21, 3.62), (2.20, 0.42, 0.95), W, "pine",
        contact=(1.10, 0.48))
    box("Sofa_back", (-3.05, 0.62, 4.06), (2.20, 0.62, 0.16), W, "pine")
    box("Sofa_armL", (-4.05, 0.40, 3.62), (0.20, 0.38, 0.95), W, "pine")
    box("Sofa_armR", (-2.05, 0.40, 3.62), (0.20, 0.38, 0.95), W, "pine")
    box("Sofa_cushL", (-3.62, 0.50, 3.55), (0.94, 0.16, 0.72), F, "gypsum", True,
        thin=0.06)
    box("Sofa_cushR", (-2.48, 0.50, 3.55), (0.94, 0.16, 0.72), F, "gypsum", True,
        thin=0.06)
    box("Coffee_body", (-2.90, 0.22, 1.90), (1.16, 0.44, 0.58), W, "pine",
        contact=(0.58, 0.29))
    plate("Coffee_top", (-2.90, 0.462, 1.90), (1.24, 0.045, 0.66), W)
    plate("Rug_Sala", (-2.90, 0.026, 2.30), (3.00, 0.012, 2.60), F)
    box("TV_stand", (-1.24, 0.28, -0.60), (0.46, 0.56, 1.70), W, "pine",
        contact=(0.23, 0.85))
    box("TV_screen", (-1.20, 0.95, -0.60), (0.05, 0.68, 1.20), GL, "gypsum", True,
        thin=0.004)
    plate("Plant_Sala", (-4.90, 0.16, -2.30), (0.36, 0.32, 0.36), T)  # maceta gres

    # ---- VESTIBULO ------------------------------------------------------------
    box("Console", (-0.66, 0.42, 3.30), (0.30, 0.84, 1.00), W, "pine", True,
        thin=0.02, contact=(0.15, 0.50))
    cylinder("CoatRack", (-0.60, 0.95, 1.60), 0.05, 1.90, W, "pine", segments=8)

    # ---- 2. COCINA -------------------------------------------------------------
    box("Counter_N", (3.67, 0.45, -1.89), (3.00, 0.90, 0.62), W, "pine",
        contact=(1.50, 0.31))
    plate("Counter_N_top", (3.67, 0.925, -1.89), (3.06, 0.05, 0.68), T)
    box("Sink", (3.00, 0.945, -1.89), (0.56, 0.12, 0.46), MET, "steel", True,
        thin=0.004)
    box("Counter_E", (5.05, 0.45, 2.90), (0.62, 0.90, 2.60), W, "pine",
        contact=(0.31, 1.30))
    plate("Counter_E_top", (5.05, 0.925, 2.90), (0.68, 0.05, 2.66), T)
    box("Stove", (5.02, 0.46, 1.30), (0.66, 0.92, 0.60), MET, "steel",
        contact=(0.33, 0.30))
    box("Fridge", (4.98, 0.93, 3.95), (0.72, 1.86, 0.70), MET, "steel",
        contact=(0.36, 0.35))
    box("Rad_Cocina", (4.30, 1.30, -2.08), (0.80, 0.50, 0.06), MET, "aluminum",
        True, thin=0.006)
    box("Kitchen_top", (3.60, 0.76, 1.80), (1.40, 0.05, 0.86), W, "pine", True,
        thin=0.0225, contact=(0.70, 0.43))
    plate("Kitchen_base", (3.60, 0.36, 1.80), (0.12, 0.72, 0.70), W)
    chair("Chair_C1", 2.75, 1.80, (-1.0, 0.0), W)
    chair("Chair_C2", 4.45, 1.80, (1.0, 0.0), W)
    chair("Chair_C3", 3.60, 0.95, (0.0, -1.0), W)
    chair("Chair_C4", 3.60, 2.65, (0.0, 1.0), W)

    # ---- 3. BANO ---------------------------------------------------------------
    box("WC_base", (4.90, 0.20, -4.90), (0.38, 0.40, 0.55), G, "gypsum", True,
        thin=0.02)
    box("WC_tank", (4.90, 0.62, -5.14), (0.50, 0.44, 0.18), G, "gypsum", True,
        thin=0.02)
    box("Sink", (2.30, 0.86, -3.10), (0.56, 0.16, 0.46), G, "gypsum", True,
        thin=0.015)
    box("Sink_ped", (2.30, 0.43, -3.10), (0.26, 0.86, 0.20), G, "gypsum", True,
        thin=0.012)
    box("Mirror_Bano", (2.30, 1.50, -5.29), (0.55, 0.75, 0.014), MIR, "aluminum",
        True, thin=0.002)
    box("Washer", (2.30, 0.42, -4.80), (0.60, 0.84, 0.60), MET, "steel",
        contact=(0.30, 0.30))
    cylinder("Boiler", (5.05, 0.62, -2.62), 0.30, 1.24, MET, "steel",
             contact=(0.30, 0.30))

    # ---- 4. DORMITORIO ---------------------------------------------------------
    box("Bed_frame", (-4.25, 3.17, 1.90), (2.00, 0.34, 1.80), W, "pine",
        contact=(1.00, 0.90))
    box("Bed_mattress", (-4.25, 3.47, 1.90), (1.90, 0.26, 1.70), F, "paper",
        contact=(0.95, 0.85))
    plate("Bed_head", (-5.22, 3.85, 1.90), (0.06, 1.00, 1.86), W)
    box("Pillow_L", (-4.90, 3.66, 1.48), (0.30, 0.12, 0.60), F, "paper", True,
        thin=0.06)
    box("Pillow_R", (-4.90, 3.66, 2.32), (0.30, 0.12, 0.60), F, "paper", True,
        thin=0.06)
    box("Wardrobe", (-2.60, 4.05, -4.90), (1.70, 2.10, 0.60), W, "pine",
        contact=(0.85, 0.30))
    box("Nightstand_L", (-5.05, 3.28, 3.30), (0.46, 0.56, 0.46), W, "pine")
    box("Nightstand_R", (-5.05, 3.28, 0.50), (0.46, 0.56, 0.46), W, "pine")
    # Espejo de cuerpo entero BARATO: laminilla de aluminio sobre liston de
    # pino, apoyado en el tabique. Se casca y la bala pasa (cascara 2 mm).
    plate("Mirror_Dorm_frame", (-1.03, 3.95, 2.60), (0.030, 1.78, 0.68), W)
    plate("Mirror_Dorm", (-1.005, 3.95, 2.60), (0.010, 1.70, 0.60), MIR)
    collider("Mirror_Dorm", Vector((-1.00, 3.95, 2.60)), Vector((0.020, 1.70, 0.60)),
             "aluminum", True, thin_shell=True, wall_thickness=0.002)

    # ---- 5. ESTUDIO --------------------------------------------------------------
    box("Desk_top", (4.30, 3.75, -2.80), (1.20, 0.05, 0.66), W, "pine", True,
        thin=0.0225, contact=(0.60, 0.33))
    box("Desk_legW", (3.78, 3.375, -2.80), (0.06, 0.75, 0.60), W, "pine")
    box("Desk_legE", (4.82, 3.375, -2.80), (0.06, 0.75, 0.60), W, "pine")
    chair("Chair_studio", 4.30, -1.95, (0.0, 1.0), W, 3.0)
    box("Shelf_1", (2.90, 3.95, -5.05), (1.60, 1.90, 0.32), W, "pine",
        contact=(0.80, 0.16))
    box("Shelf_2", (4.60, 3.95, -5.05), (1.20, 1.90, 0.32), W, "pine",
        contact=(0.60, 0.16))
    for k, yy in enumerate((3.50, 4.05, 4.60)):
        plate(f"Books_{k}", (2.90, yy, -4.88), (1.50 - 0.10 * k, 0.30, 0.06),
              M["fabric"])
    box("Rad_Estudio", (3.40, 3.37, -5.25), (0.90, 0.50, 0.06), MET, "aluminum",
        True, thin=0.006)
    box("Rad_Sala", (-3.30, 0.37, 4.24), (0.90, 0.50, 0.06), MET, "aluminum",
        True, thin=0.006)


def chair(tag, cx, cz, away, W, y0=0.0):
    """Silla de tablas: asiento y respaldo de 20 mm declarados cascara. Una
    silla maciza seria una mentira balistica y un desperdicio de tris. ``away``
    es el lado (x, z) hacia el que mira el respaldo (lejos de la mesa)."""
    box(f"{tag}_seat", (cx, y0 + 0.44, cz), (0.44, 0.04, 0.44), W, "pine", True,
        thin=0.018)
    back_c = (cx + away[0] * 0.20, y0 + 0.68, cz + away[1] * 0.20)
    back_s = (0.04, 0.46, 0.44) if abs(away[0]) > 0.5 else (0.44, 0.46, 0.04)
    box(f"{tag}_back", back_c, back_s, W, "pine", True, thin=0.018)
    for lx in (-0.17, 0.17):
        for lz in (-0.17, 0.17):
            plate(f"{tag}_leg{lx:.2f}{lz:.2f}", (cx + lx, y0 + 0.22, cz + lz),
                  (0.045, 0.44, 0.045), W)


# ---------------------------------------------------------------------------
# Union por MATERIAL (un MeshInstance3D por material: los draw calls del mapa
# son 8, las salas se separan en el glTF por nombre de objeto antes de unir)
# ---------------------------------------------------------------------------
def merge_and_export():
    groups: dict[str, list] = {}
    for obj, mat_name in OBJECTS:
        groups.setdefault(mat_name, []).append(obj)

    merged = []
    for mat_name in sorted(groups):
        node = join(mat_name, groups[mat_name], METROS_POR_TILE[mat_name])
        if node is not None:
            merged.append(node)

    MODELS.mkdir(parents=True, exist_ok=True)
    out_path = MODELS / "house.glb"
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
        export_image_format="NONE",
    )
    tris = sum(len(p.vertices) - 2 for obj in merged for p in obj.data.polygons)
    print(f"CASA built {out_path} {out_path.stat().st_size / 1024:.0f} KB "
          f"tris={tris} mallas={len(merged)}")
    scene = write_scene()
    print(f"CASA colisiones {scene} ({len(COLLIDERS)} cuerpos)")


# ---------------------------------------------------------------------------
# Escena de colision (cajas y cilindros con material y penetracion)
# ---------------------------------------------------------------------------
def fmt_vec(v) -> str:
    return "Vector3(%s, %s, %s)" % (f"{v[0]:.3f}", f"{v[1]:.3f}", f"{v[2]:.3f}")


def write_scene() -> Path:
    shapes: dict[tuple, str] = {}
    bodies: list[str] = []

    def shape_id(c: dict) -> str:
        if c["shape"] == "cylinder":
            key = ("cylinder", round(c["radius"], 3), round(c["height"], 3))
        else:
            key = ("box", round(c["size"][0], 3), round(c["size"][1], 3),
                   round(c["size"][2], 3))
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
            props.append("metadata/wall_thickness = %.4f" % c["wall_thickness"])
        if c["contact"] is not None:
            props.append("metadata/contact = Vector2(%.3f, %.3f)"
                         % (c["contact"][0], c["contact"][1]))
        nodes.append('\n[node name="%s" type="StaticBody3D" parent="."]\n%s\n'
                     % (body_name, "\n".join(props)))
        shape_lines = ['\n[node name="Shape" type="CollisionShape3D" parent="%s"]'
                       % body_name]
        if any(abs(a) > 1e-4 for a in c["rot"]):
            shape_lines.append("rotation = %s" % fmt_vec(c["rot"]))
        shape_lines.append("position = %s" % fmt_vec(c["center"]))
        shape_lines.append('shape = SubResource("%s")' % sid)
        nodes.append("\n".join(shape_lines) + "\n")

    head = ('[gd_scene load_steps=%d format=3]\n\n'
            '[ext_resource type="PackedScene" path="res://assets/models/house.glb" id="1_visual"]\n\n'
            % (len(bodies) + 2))
    tail = ('\n[node name="House" type="Node3D"]\n\n'
            '[node name="Visual" parent="." instance=ExtResource("1_visual")]\n')
    path = SCENES / "House.tscn"
    path.write_text(head + "\n".join(bodies) + tail + "".join(nodes), encoding="utf-8")
    return path


if __name__ == "__main__":
    build()
