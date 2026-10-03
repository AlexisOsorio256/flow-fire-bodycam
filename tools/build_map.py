#!/usr/bin/env python3
"""FABRICA de vallas (ref9): vallas de OSB EXENTAS dentro de una nave grande a
`assets/models/map.glb` + cajas de colision + marcadores a `scenes/Map.tscn`.

    blender --background --python tools/build_map.py
    blender --background --python tools/build_map.py -- --shot /tmp/mapa.png

Coordenadas Godot: X derecha, Y arriba, Z al fondo.

LA REFERENCIA NO PIDE UNA CASA. `docs/refs/ref9_fabrica.jpg` es una nave
industrial con el suelo de hormigon y **vallas de tablero sueltas** que forman
pasillos y cobertura; fuera de las vallas todo es espacio abierto. El chiste es
"pequeno pero bien hecho": un recinto grande con cobertura exenta donde quepan
muchos enemigos, no seis cuartos encadenados.

Un dato por comportamiento: este builder es la UNICA autoridad de cotas, luces,
puestos y spawn; el runtime los lee de los marcadores y no repite un numero.
"""

import math
import os
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

REPO = Path(__file__).resolve().parents[1]
DEST = Path(os.environ.get("MAP_DEST", REPO))
MODELS = DEST / "assets" / "models"
SCENES = DEST / "scenes"
TEX = REPO / "assets" / "textures"
TEX_MAP = TEX / "map"
TEX_REAL = TEX / "real"
TEX_ENEMY = TEX / "enemy"

# --- COTAS (una sola vez) ---------------------------------------------------
# La NAVE es el recinto: grande y despejado, como una nave de fabrica de verdad.
NAVE_X, NAVE_Z = 16.0, 20.0     # semianchos interiores: 32 x 40 m de planta
NAVE_H = 6.20                   # cara inferior del alero
NAVE_RIDGE = 8.00               # cumbrera
PANEL = 0.12                    # tablero OSB de las vallas
STUD_W, STUD_D = 0.09, 0.045    # rastrel
VY = 2.60                       # alto de valla (ref8/ref9: por encima del hombro)
TILE = {                        # metros de mundo que cubre una vuelta de textura
    "Map_Osb": 1.6, "Map_Floor": 2.4, "Map_Stud": 1.0, "Map_Roof": 14.0,
    "Map_Steel": 1.4, "Map_Tube": 2.0, "Map_Tarp": 2.0,
    "Map_Wall": 3.0, "Map_Concrete": 4.0, "Map_Frame": 2.0, "Map_Rust": 2.0,
    "Map_Wood": 1.4,
}
MATS: dict[str, object] = {}
OBJECTS: list = []
COLLIDERS: list = []
MARKERS: list = []


# --- utilidades de Blender --------------------------------------------------
def B(x: float, y: float, z: float) -> Vector:
    """Godot (X, Y arriba, Z al fondo) -> Blender (Z arriba, -Y al fondo)."""
    return Vector((x, -z, y))


def image(path: Path, non_color: bool = False):
    img = bpy.data.images.load(str(path), check_existing=True)
    if non_color:
        img.colorspace_settings.name = "Non-Color"
    return img


def material(name, albedo=None, rough=None, normal=None, color=(0.8, 0.8, 0.8),
             metallic=0.0, roughness=0.8, normal_strength=0.75):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    sh = nodes.new("ShaderNodeBsdfPrincipled")
    sh.inputs["Base Color"].default_value = (*color, 1.0)
    sh.inputs["Metallic"].default_value = metallic
    sh.inputs["Roughness"].default_value = roughness
    links.new(sh.outputs["BSDF"], out.inputs["Surface"])
    scale = TILE[name]

    def tiled(path, non_color):
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

    if albedo:
        links.new(tiled(albedo, False).outputs["Color"], sh.inputs["Base Color"])
    if rough:
        links.new(tiled(rough, True).outputs["Color"], sh.inputs["Roughness"])
    if normal:
        bump = nodes.new("ShaderNodeNormalMap")
        bump.inputs["Strength"].default_value = normal_strength
        links.new(tiled(normal, True).outputs["Color"], bump.inputs["Color"])
        links.new(bump.outputs["Normal"], sh.inputs["Normal"])
    MATS[name] = mat
    return mat


def cube_project(obj, scale: float) -> None:
    """UV por proyeccion cubica a densidad fisica, en espacio de mundo: dos
    tableros contiguos comparten fase y no aparece una costura falsa."""
    matrix = obj.matrix_world
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    uv = bm.loops.layers.uv.verify()
    for face in bm.faces:
        normal = matrix.to_3x3() @ face.normal
        axis = max(range(3), key=lambda i: abs(normal[i]))
        for loop in face.loops:
            co = matrix @ loop.vert.co
            u, v = ((co.y, co.z), (co.x, co.z), (co.x, co.y))[axis]
            loop[uv].uv = (u / scale, v / scale)
    bm.to_mesh(obj.data)
    bm.free()


def new_object(name, bm, mat):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(mat)
    OBJECTS.append((obj, mat.name))
    return obj


def prism(name, quad, offset, mat):
    """Prisma de 6 caras a partir de un poligono plano y un desplazamiento."""
    bm = bmesh.new()
    off = Vector(offset)
    low = [bm.verts.new(B(*p)) for p in quad]
    high = [bm.verts.new(B(*(Vector(p) + off))) for p in quad]
    bm.faces.new(low)
    bm.faces.new(high)
    for i in range(len(quad)):
        j = (i + 1) % len(quad)
        bm.faces.new([low[i], low[j], high[j], high[i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return new_object(name, bm, mat)


def bar(name, p0, p1, width, mat):
    """Barra de seccion cuadrada entre dos puntos (miembros de celosia)."""
    a, b = Vector(p0), Vector(p1)
    d = (b - a).normalized()
    up = Vector((0, 1, 0)) if abs(d.y) < 0.9 else Vector((0, 0, 1))
    right = d.cross(up).normalized() * (width / 2)
    vert = right.cross(d).normalized() * (width / 2)
    quad = [a - right - vert, a + right - vert, a + right + vert, a - right + vert]
    return prism(name, quad, b - a, mat)


def box(name, center, size, mat, surface, penetrable=False, thin=0.0,
        bevel=0.0, collider=True, occluder=False):
    """Caja con colision. `size` va en Godot (x, alto, z)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector((size[0], size[2], size[1])), verts=bm.verts)
    if bevel > 0.001:
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bevel, segments=1,
                        profile=0.5, affect="EDGES")
    off = B(*center)
    for v in bm.verts:
        v.co += off
    obj = new_object(name, bm, mat)
    if collider:
        COLLIDERS.append({"name": name, "center": Vector(center),
                          "size": Vector(size), "surface": surface,
                          "penetrable": penetrable, "thin_shell": thin > 0.0,
                          "wall_thickness": thin, "occluder": occluder})
    return obj


def cyl(name, center, radius, height, mat, surface, thin=0.0, collider=True):
    """Cilindro con colision REAL de cilindro: es la forma que `Ballistics`
    recorre de pared a pared. `thin` > 0 declara cascara fina."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=16,
                          radius1=radius, radius2=radius, depth=height)
    off = B(*center)
    for v in bm.verts:
        v.co += off
    obj = new_object(name, bm, mat)
    if collider:
        COLLIDERS.append({"name": name, "center": Vector(center),
                          "size": Vector((radius * 2, height, radius * 2)),
                          "surface": surface, "penetrable": thin > 0.0,
                          "shape": "cylinder", "radius": radius,
                          "height": height, "thin_shell": thin > 0.0,
                          "wall_thickness": thin})
    return obj


def cyl_h(name, center, radius, length, mat, surface, axis="z", collider=True):
    """Cilindro tumbado (tuberia de servicio)."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=12,
                          radius1=radius, radius2=radius, depth=length)
    rot = Matrix.Rotation(math.radians(90.0), 3, "X" if axis == "z" else "Y")
    for v in bm.verts:
        v.co = rot @ v.co
    off = B(*center)
    for v in bm.verts:
        v.co += off
    return new_object(name, bm, mat)


def marker(name, pos, size=None, yaw=None):
    MARKERS.append({"name": name, "pos": Vector(pos), "size": size, "yaw": yaw})


# --- la nave (el recinto) ---------------------------------------------------
def nave_wall(tag, along, at, lo, hi, openings, mat, thick=0.22,
              surface="steel", height=NAVE_H, girts=None, girt_mat=None):
    """Cerramiento de la nave: paño + correas horizontales + vanos."""
    mat_girt = girt_mat if girt_mat is not None else mat
    rects = solid_rects(lo, hi, openings, height)
    for index, (a0, a1, y0, y1) in enumerate(rects):
        center = [(a0 + a1) / 2, (y0 + y1) / 2]
        size = [a1 - a0, y1 - y0]
        if along == "z":
            center, size = [at, center[1], center[0]], [thick, size[1], size[0]]
        else:
            center, size = [center[0], center[1], at], [size[0], size[1], thick]
        box("%s_%d" % (tag, index), center, size, mat, surface,
            penetrable=True, thin=thick, occluder=True)
    if girts is None:
        return
    for face in girts:
        for i in range(max(1, int(height / girts_step(height)))):
            y = height * i / max(1, int(height / girts_step(height)))
            if along == "z":
                c, s = [at + face, y, (lo + hi) / 2], [0.07, 0.16, hi - lo]
            else:
                c, s = [(lo + hi) / 2, y, at + face], [hi - lo, 0.16, 0.07]
            box("%s_g%d_%d" % (tag, int(face * 100), i), c, s, mat_girt,
                "steel", collider=False)


def girts_step(_h):
    return 1.30


def solid_rects(lo, hi, openings, height):
    """Tramos macizos de un muro: (a0, a1, y0, y1) en el plano del muro."""
    cuts = sorted({lo, hi} | {o[0] for o in openings} | {o[1] for o in openings})
    out = []
    for a0, a1 in zip(cuts, cuts[1:]):
        if a1 - a0 < 1e-4:
            continue
        mid = (a0 + a1) / 2
        op = next((o for o in openings if o[0] - 1e-6 <= mid <= o[1] + 1e-6), None)
        if op is None:
            out.append((a0, a1, 0.0, height))
        else:
            if op[2] > 1e-4:
                out.append((a0, a1, 0.0, op[2]))
            if op[3] < height - 1e-4:
                out.append((a0, a1, op[3], height))
    return out


def band(rect, y0, y1):
    a0, a1, r0, r1 = rect
    lo, hi = max(r0, y0), min(r1, y1)
    return (a0, a1, lo, hi) if hi - lo > 1e-4 else None


def build_nave() -> None:
    """EL RECINTO: una nave de fabrica grande y despejada. Su unica mision es
    cerrar y dar luz; toda la estructura jugable son las VALLAS de dentro."""
    wall_panel = MATS["Map_Wall"]
    frame = MATS["Map_Frame"]
    ## SUELO DE HORMIGON: la losa de taller de ref9. Sin ella no hay donde
    ## pisar; es lo primero que se ve en cuadro y por eso lleva su propio
    ## material (albedo claro) y no el tablero de las vallas.
    box("Suelo", [0, -0.10, 0], [2 * NAVE_X + 1.0, 0.20, 2 * NAVE_Z + 1.0],
        MATS["Map_Concrete"], "concrete", penetrable=False, occluder=False)
    ## JUNTAS DE LA LOSA: cada 4 m en las dos direcciones, 1 cm hundidas. Es el
    ## detalle que da escala al suelo de una nave (ref9 las muestra).
    ## JUNTAS: pegadas ENCIMA de la losa (0,002-0,008), nunca metidas dentro: una
    ## junta que corta la losa hace z-fighting y el suelo se llena de puntos de
    ## color. 6 mm de canto es lo que se ve a ras de ojo sin ser un escalon.
    for i in range(8):
        x = -NAVE_X + 4.0 * (i + 1)
        box("JuntaX%d" % i, [x, 0.005, 0], [0.035, 0.006, 2 * NAVE_Z - 0.2],
            MATS["Map_Steel"], "concrete", collider=False)
    for i in range(10):
        z = -NAVE_Z + 4.0 * (i + 1)
        box("JuntaZ%d" % i, [0, 0.005, z], [2 * NAVE_X - 0.2, 0.006, 0.035],
            MATS["Map_Steel"], "concrete", collider=False)
    ## Lucernarios altos: dejan entrar el sol, que es la unica luz dura gratis.
    clere = []
    for sign in (-1, 1):
        v = -NAVE_Z + 2.4
        while v < NAVE_Z - 1.6:
            clere.append(("z", sign * (NAVE_X + 0.11), v, v + 1.8))
            v += 3.6
    for sign in (-1, 1):
        v = -NAVE_X + 2.4
        while v < NAVE_X - 1.6:
            clere.append(("x", sign * (NAVE_Z + 0.11), v, v + 1.8))
            v += 3.6
    for sign in (-1, 1):
        ops = [(a, b, 4.20, 5.20) for ax, at, a, b in clere if ax == "z"
               and (at > 0) == (sign > 0)]
        nave_wall("NE%+d" % sign, "z", sign * (NAVE_X + 0.11),
                  -NAVE_Z, NAVE_Z, ops, wall_panel, girts=(-0.22,),
                  girt_mat=frame)
        ops = [(a, b, 4.20, 5.20) for ax, at, a, b in clere if ax == "x"
               and (at > 0) == (sign > 0)]
        nave_wall("NN%+d" % sign, "x", sign * (NAVE_Z + 0.11),
                  -NAVE_X, NAVE_X, ops, wall_panel, girts=(-0.22,),
                  girt_mat=frame)
    ## Marcos de los lucernarios.
    for ax, at, lo, hi in clere:
        for y0, y1 in ((4.14, 4.20), (5.20, 5.26)):
            if ax == "z":
                box("MV%d" % len(OBJECTS), [at, (y0 + y1) / 2, (lo + hi) / 2],
                    [0.08, y1 - y0, hi - lo + 0.12], frame, "steel", collider=False)
            else:
                box("MH%d" % len(OBJECTS), [(lo + hi) / 2, (y0 + y1) / 2, at],
                    [hi - lo + 0.12, y1 - y0, 0.08], frame, "steel", collider=False)
        for x in (lo, hi):
            if ax == "z":
                box("MJ%d" % len(OBJECTS), [at, 4.70, x], [0.08, 1.12, 0.08],
                    frame, "steel", collider=False)
            else:
                box("MJ%d" % len(OBJECTS), [x, 4.70, at], [0.08, 1.12, 0.08],
                    frame, "steel", collider=False)
    ## Techo a dos aguas sobre la luz larga (X), con colisor en escalones.
    eave_y = NAVE_H - 0.05
    z0, z1 = -(NAVE_Z + 0.5), NAVE_Z + 0.5
    for sign in (-1, 1):
        quad = [(0, NAVE_RIDGE, z0), (sign * (NAVE_X + 0.5), eave_y, z0),
                (sign * (NAVE_X + 0.5), eave_y, z1), (0, NAVE_RIDGE, z1)]
        if sign < 0:
            quad = quad[::-1]
        prism("Faldon%+d" % sign, quad, (0, 0.05, 0), MATS["Map_Roof"])
        steps = 10
        for i in range(steps):
            a = sign * (NAVE_X + 0.5) * i / steps
            b = sign * (NAVE_X + 0.5) * (i + 1) / steps
            ya = eave_y + (NAVE_RIDGE - eave_y) * (1 - abs(a) / (NAVE_X + 0.5))
            yb = eave_y + (NAVE_RIDGE - eave_y) * (1 - abs(b) / (NAVE_X + 0.5))
            COLLIDERS.append({
                "name": "Faldon%+d_%d" % (sign, i),
                "center": Vector(((a + b) / 2, (ya + yb) / 2, (z0 + z1) / 2)),
                "size": Vector((abs(b - a), abs(ya - yb) + 0.05, z1 - z0)),
                "surface": "steel", "penetrable": True, "thin_shell": True,
                "wall_thickness": 0.0006})
        tri = [(-(NAVE_X + 0.5), NAVE_H, 0), (NAVE_X + 0.5, NAVE_H, 0),
               (0, NAVE_RIDGE, 0)]
        prism("Hastial%+d" % sign,
              [(-x, y, sign * (NAVE_Z + 0.11)) for x, y, _ in tri],
              (0, 0, 0.22 * sign), wall_panel)
        for i in range(5):
            a = -(NAVE_X + 0.5) + (2 * (NAVE_X + 0.5)) * i / 5
            b = -(NAVE_X + 0.5) + (2 * (NAVE_X + 0.5)) * (i + 1) / 5
            top = NAVE_RIDGE - max(abs(a), abs(b)) * (NAVE_RIDGE - NAVE_H) / (NAVE_X + 0.5)
            COLLIDERS.append({
                "name": "Hastial%+d_%d" % (sign, i),
                "center": Vector(((a + b) / 2, (NAVE_H + top) / 2,
                                  sign * (NAVE_Z + 0.11))),
                "size": Vector((b - a, top - NAVE_H, 0.22)),
                "surface": "steel", "penetrable": True, "thin_shell": True,
                "wall_thickness": 0.22})
    ## Cerchas ROJAS OXIDADAS (ref9) cada 4 m: cordon inferior, par de aguas,
    ## montantes y tirante. Son las que dan la escala de nave industrial.
    rust = MATS["Map_Rust"]
    for z in [round(-NAVE_Z + 2.0 + i * 4.0, 2) for i in range(10)]:
        bar("C_b%d" % int(z * 10), (-NAVE_X, NAVE_H + 0.10, z),
            (NAVE_X, NAVE_H + 0.10, z), 0.10, rust)
        for sign in (-1, 1):
            bar("C_t%+d%d" % (sign, int(z * 10)), (0, NAVE_RIDGE - 0.05, z),
                (sign * NAVE_X, NAVE_H + 0.05, z), 0.09, rust)
        for x in (-12.0, -8.0, -4.0, 0.0, 4.0, 8.0, 12.0):
            ry = NAVE_RIDGE - abs(x) * (NAVE_RIDGE - NAVE_H) / NAVE_X
            bar("C_v%d_%d" % (int(x * 10), int(z * 10)), (x, NAVE_H + 0.10, z),
                (x, ry - 0.05, z), 0.06, rust)
        COLLIDERS.append({"name": "Cercha%d" % int(z * 10),
                          "center": Vector((0, NAVE_H + 0.10, z)),
                          "size": Vector((2 * NAVE_X, 0.10, 0.10)),
                          "surface": "steel", "penetrable": False,
                          "thin_shell": False, "wall_thickness": 0.0})
    ## VIGAS DE RODAPIE: el cordon inferior de cada cercha lleva una viga de
    ## cuelgue con sus tirantes a la chapa; la luz y las tuberias van ahi.
    for z in [round(-NAVE_Z + 2.0 + i * 4.0, 2) for i in range(10)]:
        box("Viga%d" % int(z * 10), [0, NAVE_H - 0.14, z], [2 * NAVE_X, 0.16, 0.10],
            rust, "steel", collider=False)
    ## Tubos fluorescentes: de las cerchas, con tirantes. Uno por vano.
    for index, z in enumerate([round(-NAVE_Z + 4.0 + i * 4.0, 2) for i in range(9)]):
        for x in (-8.0, 0.0, 8.0):
            box("Reflector%d_%d" % (index, int(x)), [x, NAVE_H - 0.26, z],
                [1.44, 0.06, 0.28], frame, "steel", collider=False)
            box("Tubo%d_%d" % (index, int(x)), [x, NAVE_H - 0.36, z],
                [1.30, 0.06, 0.06], MATS["Map_Tube"], "steel", collider=False)
            for dx in (-0.50, 0.50):
                bar("Tir%d_%d_%d" % (index, int(x), int(dx * 100)),
                    (x + dx, NAVE_H - 0.06, z), (x + dx, NAVE_H - 0.24, z),
                    0.025, frame)
            marker("Tubo%02d" % (index * 3 + int(x / 8) + 1), (x, NAVE_H - 0.36, z))
    ## RODAPIE de hormigon: la chapa no toca el suelo, apoya en un zocalo.
    box("RodapieN", [0, 0.20, -NAVE_Z - 0.05], [2 * NAVE_X, 0.40, 0.30],
        MATS["Map_Concrete"], "steel", collider=False)
    box("RodapieS", [0, 0.20, NAVE_Z + 0.05], [2 * NAVE_X, 0.40, 0.30],
        MATS["Map_Concrete"], "steel", collider=False)
    box("RodapieE", [NAVE_X + 0.05, 0.20, 0], [0.30, 0.40, 2 * NAVE_Z],
        MATS["Map_Concrete"], "steel", collider=False)
    box("RodapieO", [-NAVE_X - 0.05, 0.20, 0], [0.30, 0.40, 2 * NAVE_Z],
        MATS["Map_Concrete"], "steel", collider=False)


# --- LAS VALLAS (el unico objeto jugable de la referencia) ------------------
def panel(tag, x, z, angle_deg, length, height=VY, mat=None, stud=False):
    """Una VALLA de tablero EXENTA: panel + travesaños horizontales por las dos
    caras, como en ref9. Se coloca por centro y giro. No cierra cuartos: se
    planta suelta para dar cobertura."""
    mat = mat or MATS["Map_Osb"]
    stud_mat = MATS["Map_Stud"]
    a = math.radians(angle_deg)
    ca, sa = math.cos(a), math.sin(a)
    half = length / 2
    x0, z0 = x - ca * half, z - sa * half
    x1, z1 = x + ca * half, z + sa * half
    if abs(sa) > 0.999:                     # a lo largo de Z
        center = [x, height / 2, (z0 + z1) / 2]
        size = [PANEL, height, abs(z1 - z0)]
    else:                                   # a lo largo de X (caso general)
        span = length
        center = [x, height / 2, z]
        size = [abs(ca) * span + 0.001, height, abs(sa) * span + 0.001]
        if abs(ca) < 0.999 and abs(sa) < 0.999:
            size = [span, height, PANEL]
    box("%s_p" % tag, center, size, mat, "pine", penetrable=True,
        thin=PANEL, occluder=True)
    if not stud:
        return
    ## Travesaños: tres horizontales por cara (ref9 las muestra vistos).
    for face in (-1, 1):
        for y in (0.35, height * 0.55, height - 0.25):
            if abs(sa) > 0.999:
                c, s = [x + face * (PANEL / 2 + STUD_D), y, (z0 + z1) / 2], \
                       [STUD_D, 0.14, abs(z1 - z0)]
            else:
                c, s = [(x0 + x1) / 2, y, z + face * (PANEL / 2 + STUD_D)], \
                       [abs(x1 - x0), 0.14, STUD_D]
            box("%s_t%d_%d" % (tag, face, int(y * 100)), c, s, stud_mat,
                "pine", collider=False)


def build_vallas() -> None:
    """LAS VALLAS. Leidas de ref9: paneles de OSB exentos, altos al hombro, con
    travesaños vistos, plantados en el hormigon para cortar lineas de tiro.

    EL CAMPO SE GENERA, NO SE LISTA. Se reservan un EJE CENTRAL y un ANILLO
    perimetral libres (son la circulacion, y `check_walk` los recorre), y las
    vallas se plantan en cuadricula alterna dentro de los cuatro cuadrantes con
    calles de 2,6 m entre filas. Asi el paso nunca se cierra: una lista a mano
    de 28 vallas dejo el mapa encerrado en la primera pasada.
    """
    ## --- circulacion reservada ---------------------------------------------
    LANE_X = 2.20       # semiancho del eje central
    LANE_Z = 2.20       # semiancho de la calle de cruce
    RING = 2.40         # anillo libre contra el cerramiento (la ruta lo recorre)
    ## --- cuadricula de vallas ----------------------------------------------
    ROW = 5.40          # separacion entre filas: valla 3,4 + calle de 2,0
    COL = 5.40          # paso por columna
    LEN = 3.40          # largo de valla: deja >1 m de hueco por lado
    HEIGHT = VY
    XMAX = NAVE_X - RING - 0.4
    ZMAX = NAVE_Z - RING - 0.4
    vallas = []
    # Filas de vallas paralelas a X (cortan la linea de tiro en Z).
    z = -ZMAX + 1.0
    fila = 0
    while z <= ZMAX - 1.0:
        if abs(z) > LANE_Z + 1.2:
            x = -XMAX + (COL / 2 if fila % 2 else COL)
            while x <= XMAX - 0.6:
                if abs(x) > LANE_X + LEN / 2 + 0.4:
                    vallas.append((x, z, 0.0, LEN))
                x += COL
        z += ROW
        fila += 1
    # Columnas de vallas paralelas a Z (cortan la linea de tiro en X).
    x = -XMAX + 1.0
    col = 0
    while x <= XMAX - 1.0:
        if abs(x) > LANE_X + 1.2:
            z = -ZMAX + (COL / 2 if col % 2 else COL)
            while z <= ZMAX - 0.6:
                if abs(z) > LANE_Z + LEN / 2 + 0.4:
                    vallas.append((x, z, 90.0, LEN))
                z += COL
        x += ROW
        col += 1
    for i, (x, z, ang, ln) in enumerate(vallas):
        panel("V%03d" % i, x, z, ang, ln, height=HEIGHT, stud=True)
    ## OBRA: bidones, tablero apilado y cajas en los huecos de la cuadricula.
    steel = MATS["Map_Frame"]
    obra = [(-6.5, -9.0), (-5.4, -9.6), (10.0, -9.2), (10.9, -8.4),
            (-11.0, 9.0), (12.0, 9.5), (3.0, -15.5), (-2.0, 16.5)]
    for i, (x, z) in enumerate(obra):
        cyl("Bidon%02d" % i, [x, 0.44, z], 0.29, 0.88, steel, "aluminum",
            thin=0.0015)
    for i, (x, z, ang, ln) in enumerate([(6.4, 6.4, 0.0, 2.6), (-6.4, -6.4, 90.0, 2.6),
                                         (6.4, -6.4, 0.0, 2.6), (-6.4, 6.4, 90.0, 2.6)]):
        panel("Pila%02d" % i, x, z, ang, ln, height=0.55, stud=False)
    for i, (x, z) in enumerate([(9.2, 13.0), (-9.2, -13.0), (13.0, 3.0)]):
        box("Caja%02d" % i, [x, 0.35, z], [0.85, 0.70, 1.05],
            MATS["Map_Wood"], "pine", penetrable=True, thin=0.05)
    print("MAPA vallas: %d paneles" % len(vallas))


def _spawn_libre() -> tuple:
    """El spawn mira al centro de la nave: se elige en el extremo sur, libre."""
    for z in (17.5, 16.0, 14.5, 13.0, -17.5):
        for x in (0.0, 2.0, -2.0, 4.0, -4.0):
            if _libre(x, z, r=0.90):
                return (x, z)
    return (0.0, 17.5)


def _libre(x: float, z: float, y: float = 1.0, r: float = 0.55) -> bool:
    """Hay sitio de pie en (x, z)? Comprueba contra TODOS los colisores puestos
    hasta ahora. Un marcador dentro de una valla es un enemigo atrapado, y ese
    fallo no se ve en una captura."""
    for c in COLLIDERS:
        if c["center"].y + c["size"].y / 2 < y - r and c["center"].y < 0.05:
            continue
        if c["center"].y > y + r * 2:
            continue
        dx = abs(c["center"].x - x) - c["size"].x / 2
        dz = abs(c["center"].z - z) - c["size"].z / 2
        if dx < r and dz < r:
            return False
    return True


def build_markers() -> None:
    ## EL SPAWN TIENE QUE ESTAR LIBRE. Un spawn dentro de una valla mete al
    ## jugador en la geometria y la primera captura sale mirando tablero.
    sx, sz = _spawn_libre()
    marker("Spawn", (sx, 0.05, sz))
    ## La nave entera es el volumen interior: una sola exposicion para un
    ## recinto sin techos interiores.
    marker("Interior", (0, 0, 0), (2 * NAVE_X, NAVE_H, 2 * NAVE_Z))
    marker("Municion", (-3.0, 0.0, 14.0))
    ## PUESTOS: repartidos por las vallas, todos con linea de tiro al eje
    ## central. Muchos: la nave es grande y el combate es de cobertura.
    posts = [
        (-12.0, -16.0, 0.5), (-6.0, -16.5, 0.2), (2.0, -16.0, -0.2),
        (9.0, -16.0, -0.5), (14.5, -9.0, -1.2), (15.0, 0.0, -1.4),
        (14.5, 9.0, -1.9), (9.5, 16.5, -2.4), (2.0, 16.0, -2.9),
        (-6.0, 16.5, 3.1), (-13.0, 16.0, 2.7), (-15.0, 8.0, 1.6),
        (-15.0, -2.0, 1.4), (-14.5, -10.0, 1.0), (-7.0, 0.0, 1.6),
        (7.0, 0.5, -1.5), (-2.0, -8.0, 0.4), (3.0, -8.5, -0.4),
        (-2.5, 8.0, 3.0), (3.5, 8.5, -3.0),
        (-9.0, -4.0, 1.2), (9.5, -4.5, -1.3), (-5.5, 11.5, 2.2),
        (5.5, 12.0, -2.3), (0.0, -18.0, 0.0), (0.0, 18.0, 3.1),
        (-16.0, -5.0, 1.5), (16.0, 5.0, -1.6), (-6.0, 5.0, 2.6),
        (6.0, -12.0, -0.9),
    ]
    colocados = 0
    for x, z, yaw in posts:
        ## Si el sitio ideal cae dentro de una valla, se BUSCA el mas cercano
        ## libre en espiral. Descartar el puesto dejaba la nave con menos
        ## enemigos de los que la ficha publica.
        puesto = None
        if _libre(x, z):
            puesto = (x, z)
        else:
            for r in (0.8, 1.2, 1.6, 2.0, 2.6, 3.2):
                for k in range(16):
                    a = k * math.tau / 16.0
                    cx, cz = x + math.cos(a) * r, z + math.sin(a) * r
                    if abs(cx) > NAVE_X - 1.2 or abs(cz) > NAVE_Z - 1.2:
                        continue
                    if _libre(cx, cz):
                        puesto = (cx, cz)
                        break
                if puesto is not None:
                    break
        if puesto is None:
            print("MAPA AVISO: puesto sin sitio cerca de (%.1f, %.1f)" % (x, z))
            continue
        marker("Puesto%d" % colocados, (puesto[0], 0.05, puesto[1]), yaw=yaw)
        colocados += 1
    print("MAPA puestos: %d" % colocados)


def build() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    material("Map_Osb", TEX_MAP / "osb_diff.jpg", TEX_MAP / "osb_rough.jpg",
             TEX_MAP / "osb_nor_gl.jpg", color=(0.60, 0.51, 0.40), roughness=0.86)
    material("Map_Floor", TEX_MAP / "osb_diff.jpg", TEX_MAP / "osb_rough.jpg",
             TEX_MAP / "osb_nor_gl.jpg", color=(0.42, 0.36, 0.28), roughness=0.92)
    material("Map_Stud", TEX_REAL / "wood_oak_wood_planks_diff.jpg",
             TEX_REAL / "wood_oak_wood_planks_rough.jpg",
             TEX_REAL / "wood_oak_wood_planks_nor_gl.jpg",
             color=(0.70, 0.58, 0.42), roughness=0.80)
    ## TECHO: la chapa grecada a ras de ojo aliasea SIEMPRE (la onda mide 2 cm y
    ## a 8 m de altura cae por debajo del pixel). En vez de pelear con el
    ## filtrado, el techo de la nave es LISO: se le quita el normal y sube el
    ## tile a 14 m, asi el unico patron que queda es el de las juntas.
    material("Map_Roof", TEX_MAP / "roof_steel_diff.jpg",
             TEX_MAP / "roof_steel_rough.jpg", None,
             color=(0.55, 0.54, 0.52), metallic=0.45, roughness=0.72)
    material("Map_Rust", TEX_MAP / "roof_steel_diff.jpg",
             TEX_MAP / "roof_steel_rough.jpg", TEX_MAP / "roof_steel_nor_gl.jpg",
             color=(0.56, 0.24, 0.12), metallic=0.45, roughness=0.62,
             normal_strength=0.5)
    material("Map_Steel", TEX_MAP / "roof_steel_diff.jpg",
             TEX_MAP / "roof_steel_rough.jpg", TEX_MAP / "roof_steel_nor_gl.jpg",
             color=(0.30, 0.26, 0.24), metallic=0.8, roughness=0.62)
    material("Map_Tube", color=(0.95, 0.96, 0.98), roughness=0.4)
    material("Map_Tarp", TEX_ENEMY / "fabric_color.jpg",
             TEX_ENEMY / "fabric_rough.jpg", TEX_ENEMY / "fabric_normal.jpg",
             color=(0.06, 0.06, 0.07), roughness=0.90)
    ## EL CERRAMIENTO ES HORMIGON (ref9: la nave es de bloques y chapa, no de
    ## tablero). El tablero es de las VALLAS, que es lo que mira el jugador.
    material("Map_Wall", TEX_REAL / "concrete_brushed_concrete_diff.jpg",
             TEX_REAL / "concrete_brushed_concrete_rough.jpg",
             TEX_REAL / "concrete_brushed_concrete_nor_gl.jpg",
             color=(0.78, 0.77, 0.75), roughness=0.88, normal_strength=0.35)
    material("Map_Frame", TEX_MAP / "roof_steel_diff.jpg",
             TEX_MAP / "roof_steel_rough.jpg", TEX_MAP / "roof_steel_nor_gl.jpg",
             color=(0.30, 0.31, 0.33), metallic=0.55, roughness=0.55,
             normal_strength=0.4)
    ## SUELO DE HORMIGON de taller (ref9): claro, con juntas y manchas.
    material("Map_Concrete", TEX_REAL / "concrete_brushed_concrete_diff.jpg",
             TEX_REAL / "concrete_brushed_concrete_rough.jpg",
             TEX_REAL / "concrete_brushed_concrete_nor_gl.jpg",
             color=(0.72, 0.71, 0.69), roughness=0.90, normal_strength=0.55)
    material("Map_Wood", TEX_REAL / "wood_oak_wood_planks_diff.jpg",
             TEX_REAL / "wood_oak_wood_planks_rough.jpg",
             TEX_REAL / "wood_oak_wood_planks_nor_gl.jpg",
             color=(0.52, 0.42, 0.30), roughness=0.85)
    build_nave()
    build_vallas()
    build_markers()
    merge_and_export()


def merge_and_export() -> None:
    groups: dict[tuple, list] = {}
    for obj, mat_name in OBJECTS:
        groups.setdefault(mat_name, []).append(obj)
    merged = []
    for mat_name in sorted(groups):
        node = join(mat_name, groups[mat_name], TILE[mat_name])
        if node is not None:
            merged.append(node)
    bake_ao(merged)
    MODELS.mkdir(parents=True, exist_ok=True)
    out = MODELS / "map.glb"
    bpy.ops.object.select_all(action="DESELECT")
    for obj in merged:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = merged[0]
    bpy.ops.export_scene.gltf(filepath=str(out), use_selection=True,
                              export_format="GLB", export_apply=True,
                              export_texcoords=True, export_normals=True,
                              export_tangents=False, export_materials="EXPORT",
                              export_colors=True, export_attributes=False,
                              export_image_format="NONE")
    tris = sum(len(p.vertices) - 2 for obj in merged for p in obj.data.polygons)
    print("MAPA %s %.0f KB tris=%d mallas=%d colisores=%d marcadores=%d"
          % (out, out.stat().st_size / 1024, tris, len(merged), len(COLLIDERS),
             len(MARKERS)))
    write_scene()


def join(name, objects, scale):
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
    cube_project(joined, scale)
    return joined


## AO DE VERTICE: las esquinas se oscurecen donde dos superficies se encuentran.
AO_RAYS = 14
AO_DISTANCE = 1.20
AO_MIN = 0.45


def bake_ao(objects) -> None:
    from mathutils.bvhtree import BVHTree
    tris, verts = [], []
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        m = obj.matrix_world
        mesh = obj.data
        mesh.calc_loop_triangles()
        base = len(verts)
        verts += [m @ v.co for v in mesh.vertices]
        for lt in mesh.loop_triangles:
            tris.append(tuple(base + i for i in lt.vertices))
    if len(tris) < 10:
        return
    tree = BVHTree.FromPolygons(verts, tris, all_triangles=True)
    hemi = []
    for i in range(AO_RAYS):
        z = (i + 0.5) / AO_RAYS
        r = math.sqrt(max(0.0, 1.0 - z * z))
        a = i * 2.399963
        hemi.append(Vector((math.cos(a) * r, math.sin(a) * r, z)))
    total = 0
    for obj in objects:
        mesh = obj.data
        if not mesh.color_attributes:
            mesh.color_attributes.new(name="AO", type="BYTE_COLOR", domain="CORNER")
        col = mesh.color_attributes[0]
        nrm = [Vector((0.0, 0.0, 0.0)) for _ in mesh.vertices]
        for poly in mesh.polygons:
            for vi in poly.vertices:
                nrm[vi] += poly.normal
        m = obj.matrix_world
        rot = m.to_3x3()
        hits = [0] * len(mesh.vertices)
        for poly in mesh.polygons:
            for vi in poly.vertices:
                p = m @ mesh.vertices[vi].co
                n = (rot @ nrm[vi]).normalized() if nrm[vi].length > 1e-6 \
                    else Vector((0, 0, 1))
                up = Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0))
                t = n.cross(up).normalized()
                b = n.cross(t)
                for d in hemi:
                    w = t * d.x + b * d.y + n * d.z
                    if tree.ray_cast(p + n * 0.004, w, AO_DISTANCE) is not None:
                        hits[vi] += 1
        for li, loop in enumerate(mesh.loops):
            v = hits[loop.vertex_index] / float(AO_RAYS)
            ao = max(AO_MIN, 1.0 - v)
            col.data[li].color = (ao, ao, ao, 1.0)
        total += len(mesh.loops)
    print("MAPA AO horneado en %d loops de vertice" % total)


def fmt(v) -> str:
    return "Vector3(%s, %s, %s)" % tuple("%.3f" % a for a in v)


def write_scene() -> None:
    shapes: dict[tuple, str] = {}
    bodies: list[str] = []

    def shape_id(c) -> str:
        if c.get("shape") == "cylinder":
            key = ("cyl", round(c["radius"], 3), round(c["height"], 3))
            if key not in shapes:
                name = "Shape%d" % len(shapes)
                shapes[key] = name
                bodies.append('[sub_resource type="CylinderShape3D" id="%s"]'
                              '\nradius = %.3f\nheight = %.3f\n'
                              % (name, key[1], key[2]))
            return shapes[key]
        key = ("box",) + tuple(round(a, 3) for a in c["size"])
        if key not in shapes:
            name = "Shape%d" % len(shapes)
            shapes[key] = name
            bodies.append('[sub_resource type="BoxShape3D" id="%s"]\nsize = %s\n'
                          % (name, fmt((key[1], key[2], key[3]))))
        return shapes[key]

    nodes: list[str] = []
    occluders: dict[tuple, str] = {}
    occl = 0
    for index, c in enumerate(COLLIDERS):
        name = "C%03d_%s" % (index, c["name"])
        props = ["collision_layer = 1", "collision_mask = 1",
                 'metadata/surface = "%s"' % c["surface"],
                 "metadata/penetrable = %s" % ("true" if c["penetrable"] else "false")]
        if c["thin_shell"]:
            props += ["metadata/thin_shell = true",
                      "metadata/wall_thickness = %.4f" % c["wall_thickness"]]
        nodes.append('\n[node name="%s" type="StaticBody3D" parent="."]\n%s\n'
                     % (name, "\n".join(props)))
        nodes.append('\n[node name="Shape" type="CollisionShape3D" parent="%s"]\n'
                     'position = %s\nshape = SubResource("%s")\n'
                     % (name, fmt(c["center"]), shape_id(c)))
        if not c.get("occluder"):
            continue
        size = tuple(max(c["size"][i] - 0.04, 0.02) for i in range(3))
        key = tuple(round(v, 3) for v in size)
        if key not in occluders:
            occluders[key] = "Occluder%d" % len(occluders)
            bodies.append('[sub_resource type="BoxOccluder3D" id="%s"]\nsize = %s\n'
                          % (occluders[key], fmt(size)))
        nodes.append('\n[node name="O%03d_%s" type="OccluderInstance3D" parent="."]\n'
                     'position = %s\noccluder = SubResource("%s")\n'
                     % (occl, c["name"], fmt(c["center"]), occluders[key]))
        occl += 1
    for m in MARKERS:
        text = '\n[node name="%s" type="Marker3D" parent="."]\nposition = %s\n' \
               % (m["name"], fmt(m["pos"]))
        if m["size"] is not None:
            text += "metadata/tamano = %s\n" % fmt(m["size"])
        if m["yaw"] is not None:
            text += "metadata/rumbo = %.4f\n" % m["yaw"]
        nodes.append(text)
    head = ('[gd_scene load_steps=%d format=3]\n\n'
            '[ext_resource type="PackedScene" path="res://assets/models/map.glb" '
            'id="1_visual"]\n\n' % (len(bodies) + 2))
    tail = ('\n[node name="Map" type="Node3D"]\n\n'
            '[node name="Visual" parent="." instance=ExtResource("1_visual")]\n')
    SCENES.mkdir(parents=True, exist_ok=True)
    path = SCENES / "Map.tscn"
    path.write_text(head + "\n".join(bodies) + tail + "".join(nodes),
                    encoding="utf-8")
    print("MAPA escena %s (%d cuerpos, %d ocultadores, %d marcadores)"
          % (path, len(COLLIDERS), occl, len(MARKERS)))


def shot(path: str) -> None:
    bpy.context.scene.render.resolution_x = 1280
    bpy.context.scene.render.resolution_y = 720
    cam_data = bpy.data.cameras.new("Cam")
    cam = bpy.data.objects.new("Cam", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    cam.location = (18.0, -26.0, 14.0)
    cam.rotation_euler = (math.radians(64.0), 0.0, math.radians(38.0))
    bpy.context.scene.camera = cam
    bpy.context.scene.render.engine = "BLENDER_EEVEE"
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    build()
    if "--shot" in argv:
        shot(argv[argv.index("--shot") + 1])
