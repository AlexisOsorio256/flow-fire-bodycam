#!/usr/bin/env python3
"""Casa de tiro de tablero (ref8): malla a `assets/models/map.glb` y cajas de
colision + marcadores a `scenes/Map.tscn`. Las dos salidas salen del MISMO dato.

    blender --background --python tools/build_map.py
    blender --background --python tools/build_map.py -- --shot /tmp/mapa.png

Coordenadas Godot: X derecha, Y arriba, Z al fondo. El pasillo corre por Z.
Un dato por comportamiento: el builder es la UNICA autoridad de cotas, de
posiciones de luz, de puestos de enemigo y del punto de aparicion; el runtime
los lee de los marcadores de la escena y no repite ni un numero.
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
X0, X1 = -5.0, 5.0          # caras interiores de los muros este/oeste
Z0, Z1 = -7.0, 7.0          # caras interiores de los muros norte/sur
H = 2.80                    # cara superior de los muros (= alero)
RIDGE = 4.10                # cumbrera
PANEL = 0.12                # tablero OSB
STUD_W, STUD_D = 0.09, 0.045
CORR = 1.05                 # cara interior de los muros del pasillo
DOOR_W, DOOR_H = 1.30, 2.05
WIN_W, WIN_H, WIN_Y = 1.50, 0.95, 1.00
STEP = 0.60                 # separacion de rastreles
NAVE_X, NAVE_Z = 9.50, 13.50  # caras interiores de los muros de la nave
NAVE_H = 5.20               # cara inferior del alero de la nave
NAVE_RIDGE = 6.00           # cumbrera de la nave
## ALTURA DE LOS TUBOS DEL ANILLO: cuelgan de las cerchas (5,26) con tirantes,
## no flotan a media altura. La luz de un local industrial va alta.
NAVE_TUBE_Y = 4.70
TILE = {                    # metros de mundo que cubre una vuelta de textura
    "Map_Osb": 1.2, "Map_Floor": 1.6, "Map_Stud": 0.9, "Map_Roof": 3.4,
    "Map_Steel": 1.2, "Map_Tube": 2.0, "Map_Tarp": 2.0,
    "Map_Wall": 2.2, "Map_Concrete": 3.0, "Map_Frame": 1.6,
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


def cyl(name, center, radius, height, mat, surface, mass=0.0, collider=True):
    """Cilindro con colision REAL de cilindro: es la forma que `Ballistics`
    recorre de pared a pared. Los unicos del mapa."""
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
                          "surface": surface, "penetrable": False,
                          "thin_shell": False, "wall_thickness": 0.0,
                          "shape": "cylinder", "radius": radius,
                          "height": height, "mass": mass})
    return obj


def cyl_h(name, center, radius, length, mat, surface, axis="z", collider=True):
    """Cilindro tumbado (tuberia de servicio)."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=12,
                          radius1=radius, radius2=radius, depth=length)
    if axis == "z":
        rot = Matrix.Rotation(math.radians(90.0), 3, "X")
    else:
        rot = Matrix.Rotation(math.radians(90.0), 3, "Y")
    for v in bm.verts:
        v.co = rot @ v.co
    off = B(*center)
    for v in bm.verts:
        v.co += off
    return new_object(name, bm, mat)


def marker(name, pos, size=None, yaw=None):
    MARKERS.append({"name": name, "pos": Vector(pos), "size": size, "yaw": yaw})


# --- muros ------------------------------------------------------------------
def solid_rects(lo, hi, openings, height=H):
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


def wall(tag, along, at, lo, hi, openings, faces, thick=PANEL, surface="pine",
         height=H):
    """Muro con vanos. `faces` son los desplazamientos de cara donde van los
    rastreles (una cara en un muro exterior, dos en un tabique)."""
    mat_osb, mat_stud = MATS["Map_Osb"], MATS["Map_Stud"]
    rects = solid_rects(lo, hi, openings, height)
    for index, (a0, a1, y0, y1) in enumerate(rects):
        center = [(a0 + a1) / 2, (y0 + y1) / 2]
        size = [a1 - a0, y1 - y0]
        if along == "z":
            center, size = [at, center[1], center[0]], [thick, size[1], size[0]]
        else:
            center, size = [center[0], center[1], at], [size[0], size[1], thick]
        box("%s_%d" % (tag, index), center, size, mat_osb, surface,
            penetrable=True, thin=thick, occluder=True)
    # rastreles: verticales cada STEP, mas platea baja y alta por cara
    studs = []
    a = lo + STEP / 2
    while a < hi - 1e-3:
        if not any(o[0] - STUD_W <= a <= o[1] + STUD_W for o in openings):
            studs.append(a)
        a += STEP
    for op in openings:                     # montantes de jamba en cada vano
        studs += [op[0] + STUD_W / 2, op[1] - STUD_W / 2]
    for face in faces:
        for a in studs:
            for y0, y1 in ((0.0, height),):
                center = [a, (y0 + y1) / 2]
                size = [STUD_W, y1 - y0]
                off = [0.0, 0.0, 0.0]
                if along == "z":
                    center = [at + face, center[1], center[0]]
                    size = [STUD_D, size[1], size[0]]
                else:
                    center = [center[0], center[1], at + face]
                    size = [size[0], size[1], STUD_D]
                box("%s_r%d" % (tag, len(OBJECTS)), [center[0] + off[0],
                    center[1] + off[1], center[2] + off[2]], size, mat_stud,
                    "pine", collider=False)
        for y0, y1 in ((0.0, STUD_W), (height - STUD_W, height)):
            for rect in rects:
                cut = band(rect, y0, y1)
                if cut is None:
                    continue
                a0, a1, b0, b1 = cut
                center, size = [(a0 + a1) / 2, (b0 + b1) / 2], [a1 - a0, b1 - b0]
                if along == "z":
                    center, size = [at + face, center[1], center[0]], [STUD_D,
                                                                      size[1], size[0]]
                else:
                    center, size = [center[0], center[1], at + face], [size[0],
                                                                      size[1], STUD_D]
                box("%s_p%d" % (tag, len(OBJECTS)), center, size, mat_stud,
                    "pine", collider=False)


def build_walls() -> None:
    face_out = PANEL / 2 + STUD_D / 2
    doors = [(-4.66 - DOOR_W / 2, -4.66 + DOOR_W / 2, 0.0, DOOR_H),
             (-DOOR_W / 2, DOOR_W / 2, 0.0, DOOR_H),
             (4.66 - DOOR_W / 2, 4.66 + DOOR_W / 2, 0.0, DOOR_H)]
    for sign in (-1, 1):                                  # muros del pasillo
        wall("P%+d" % sign, "z", sign * (CORR + PANEL / 2), Z0, Z1, doors,
             (-face_out, face_out))
    cross = [(-3.0 - DOOR_W / 2, -3.0 + DOOR_W / 2, 0.0, DOOR_H),
             (3.0 - DOOR_W / 2, 3.0 + DOOR_W / 2, 0.0, DOOR_H)]
    for z in (-2.33, 2.33):                               # tabiques transversales
        wall("T%+.2f_a" % z, "x", z, X0, -CORR, [cross[0]], (-face_out, face_out))
        wall("T%+.2f_b" % z, "x", z, CORR, X1, [cross[1]], (-face_out, face_out))
    wins = [(-4.6 - WIN_W / 2, -4.6 + WIN_W / 2, WIN_Y, WIN_Y + WIN_H),
            (-WIN_W / 2, WIN_W / 2, WIN_Y, WIN_Y + WIN_H),
            (4.6 - WIN_W / 2, 4.6 + WIN_W / 2, WIN_Y, WIN_Y + WIN_H)]
    for sign in (-1, 1):                                  # fachadas este/oeste
        wall("E%+d" % sign, "z", sign * (X1 + PANEL / 2), Z0, Z1, wins,
             (-face_out * sign,))
    ends = [(-3.4 - WIN_W / 2, -3.4 + WIN_W / 2, WIN_Y, WIN_Y + WIN_H),
            (3.4 - WIN_W / 2, 3.4 + WIN_W / 2, WIN_Y, WIN_Y + WIN_H),
            (-0.55, 0.55, 0.0, DOOR_H)]
    for sign in (-1, 1):                                  # hastiales norte/sur
        wall("N%+d" % sign, "x", sign * (Z1 + PANEL / 2), X0, X1, ends,
             (-face_out * sign,))


def build_shell() -> None:
    osb, floor = MATS["Map_Osb"], MATS["Map_Floor"]
    box("Suelo", [0, -0.02, 0], [X1 - X0 + 2 * PANEL, 0.04, Z1 - Z0 + 2 * PANEL],
        floor, "pine", penetrable=True, thin=0.04)
    eave_x, eave_y = X1 + 0.35, H - 0.05
    z0, z1 = Z0 - 0.35, Z1 + 0.35
    for sign in (-1, 1):
        quad = [(0, RIDGE, z0), (sign * eave_x, eave_y, z0),
                (sign * eave_x, eave_y, z1), (0, RIDGE, z1)]
        if sign < 0:
            quad = quad[::-1]
        prism("Faldon%+d" % sign, quad, (0, 0.035, 0), MATS["Map_Roof"])
        # La losa va inclinada y el colisor es una caja: se aproxima en escalones
        # de 0,9 m. Un plano horizontal a media altura paraba balas en el aire.
        steps = 6
        for i in range(steps):
            a = sign * eave_x * i / steps
            b = sign * eave_x * (i + 1) / steps
            ya = eave_y + (RIDGE - eave_y) * (1 - abs(a) / eave_x)
            yb = eave_y + (RIDGE - eave_y) * (1 - abs(b) / eave_x)
            COLLIDERS.append({
                "name": "Faldon%+d_%d" % (sign, i),
                "center": Vector(((a + b) / 2, (ya + yb) / 2, (z0 + z1) / 2)),
                "size": Vector((abs(b - a), abs(ya - yb) + 0.035, z1 - z0)),
                "surface": "steel", "penetrable": True, "thin_shell": True,
                "wall_thickness": 0.0006})
        tri = [(X0 - PANEL, H, 0), (X1 + PANEL, H, 0), (0, RIDGE, 0)]
        off = (0, 0, PANEL * sign)
        prism("Hastial%+d" % sign, [(-x, y, sign * (Z1 + PANEL)) for x, y, _ in tri],
              off, osb)
        for i in range(4):
            a = (X0 - PANEL) + (X1 - X0 + 2 * PANEL) * i / 4
            b = (X0 - PANEL) + (X1 - X0 + 2 * PANEL) * (i + 1) / 4
            top = RIDGE - max(abs(a), abs(b)) * (RIDGE - H) / (X1 + PANEL)
            COLLIDERS.append({
                "name": "Hastial%+d_%d" % (sign, i),
                "center": Vector(((a + b) / 2, (H + top) / 2,
                                  sign * (Z1 + PANEL / 2))),
                "size": Vector((b - a, top - H, PANEL)),
                "surface": "pine", "penetrable": True, "thin_shell": True,
                "wall_thickness": PANEL})
    box("Cumbrera", [0, RIDGE + 0.02, 0], [0.26, 0.05, Z1 - Z0 + 0.7],
        MATS["Map_Steel"], "steel", collider=False)
    # celosia: 5 cerchas con cordon inferior, dos superiores y montantes
    for z in (-5.6, -2.8, 0.0, 2.8, 5.6):
        steel = MATS["Map_Steel"]
        bar("Cercha%d_b" % int(z * 10), (X0, H + 0.06, z), (X1, H + 0.06, z),
            0.07, steel)
        for sign in (-1, 1):
            bar("Cercha%d_t%+d" % (int(z * 10), sign), (0, RIDGE - 0.04, z),
                (sign * X1, H + 0.02, z), 0.07, steel)
        for x in (-3.75, -2.5, -1.25, 0.0, 1.25, 2.5, 3.75):
            roof_y = RIDGE - abs(x) * (RIDGE - H) / X1
            bar("Cercha%d_v%d" % (int(z * 10), int(x * 100)), (x, H + 0.06, z),
                (x, roof_y - 0.03, z), 0.05, steel)
        COLLIDERS.append({"name": "Cercha%d" % int(z * 10),
                          "center": Vector((0, H + 0.06, z)),
                          "size": Vector((X1 - X0, 0.07, 0.07)),
                          "surface": "steel", "penetrable": False,
                          "thin_shell": False, "wall_thickness": 0.0})
    # tubos fluorescentes colgados bajo la celosia: uno por vano del pasillo y
    # uno por cuarto. El marcador es lo que el runtime convierte en luz.
    for index in range(8):
        z = -6.0 + index * (12.0 / 7.0)
        box("Reflector%02d" % index, [0, 2.76, z], [0.26, 0.05, 1.34],
            MATS["Map_Steel"], "steel", collider=False)
        box("Tubo%02d" % index, [0, 2.68, z], [0.055, 0.055, 1.20],
            MATS["Map_Tube"], "steel", collider=False)
        marker("Tubo%02d" % index, (0, 2.68, z))
    for index, (x, z) in enumerate(((-3.0, -4.66), (-3.0, 0.0), (-3.0, 4.66),
                                    (3.0, -4.66), (3.0, 0.0), (3.0, 4.66))):
        box("TuboC%02d" % index, [x, 2.62, z], [1.10, 0.055, 0.055],
            MATS["Map_Tube"], "steel", collider=False)
        marker("Tubo%02d" % (index + 8), (x, 2.62, z))
    ## Lona oscura con su bulto debajo (ref8), ARRINCONADA en el cuarto noreste:
    ## es un cuerpo con colision de 36 cm y en mitad del cuarto cortaba el paso.
    tarp = MATS["Map_Tarp"]
    box("Bulto", [4.55, 0.18, 6.45], [0.85, 0.36, 0.65], tarp, "paper",
        penetrable=True, thin=0.02)
    prism("Lona", [(4.00, 0.02, 5.80), (5.00, 0.02, 5.80), (5.00, 0.02, 6.90),
                   (4.00, 0.02, 6.90)], (0, 0.012, 0), tarp)


def wall_mat(tag, along, at, lo, hi, openings, faces, mat, thick=PANEL,
             surface="pine", height=H, stud=None):
    """`wall()` con material de panel elegible. La nave NO es de tablero: su
    muro es chapa grecada sobre montantes metalicos, para que la casa de OSB se
    lea DENTRO de otra cosa y no como un tablero infinito del mismo material."""
    mat_osb, mat_stud = mat, (stud if stud is not None else MATS["Map_Stud"])
    rects = solid_rects(lo, hi, openings, height)
    for index, (a0, a1, y0, y1) in enumerate(rects):
        center = [(a0 + a1) / 2, (y0 + y1) / 2]
        size = [a1 - a0, y1 - y0]
        if along == "z":
            center, size = [at, center[1], center[0]], [thick, size[1], size[0]]
        else:
            center, size = [center[0], center[1], at], [size[0], size[1], thick]
        box("%s_%d" % (tag, index), center, size, mat_osb, surface,
            penetrable=True, thin=thick, occluder=True)
    ## CORREAS HORIZONTALES, no montantes verticales cada 0,60 m. En una pared
    ## vista a ras de ojo, una rejilla vertical fina aliasea y el shader del
    ## lente la convierte en franjas de color: la nave industrial se arma con
    ## correas horizontales anchas cada ~1,3 m, que es ademas lo que hace un
    ## cerramiento de verdad.
    for face in faces:
        rows = max(1, int(height / 1.3))
        for i in range(rows):
            y0 = height * i / rows
            center = [0.0, y0]
            size = [0.10, 0.10]
            if along == "z":
                center = [at + face, y0, (lo + hi) / 2]
                size = [0.05, 0.10, hi - lo]
            else:
                center = [(lo + hi) / 2, y0, at + face]
                size = [hi - lo, 0.10, 0.05]
            box("%s_h%d" % (tag, i), center, size, mat_stud, "pine",
                collider=False)


def build_nave() -> None:
    """NAVE que cierra el mapa. La casa de tablero vive DENTRO, y la nave tiene
    su PROPIA identidad: chapa grecada atornillada a montantes de acero sobre
    un anillo de hormigon, suelo de losa de taller y estructura de celosia
    pintada. El material no se repite entre dentro y fuera: asi la casa se lee
    como una pieza metida en un local, no como tablero infinito.
    La luz del anillo cuelga de las cerchas con tirantes. `Enemy` lo navega."""
    steel = MATS["Map_Steel"]
    wall_panel = MATS["Map_Wall"]
    frame = MATS["Map_Frame"]
    face_out = PANEL / 2 + STUD_D / 2
    ## LUCERNARIOS: una fila de vanos altos en las cuatro paredes. La nave estaba
    ## ciega: el sol no entraba en ninguna direccion y el anillo se leia plano.
    ## Con los vanos a 3,60-4,40 m el sol de -58 grados pinta charcos de luz en
    ## el suelo de hormigon y las cerchas recortan su sombra: es la unica luz
    ## dura de dentro y es gratis (el sol ya existia, solo no tenia por donde).
    clere = []
    xs = []
    for sign in (-1, 1):                                   # muros largos (E/O)
        v = -NAVE_Z + 2.2
        while v < NAVE_Z - 1.0:
            clere.append(("z", sign * (NAVE_X + PANEL / 2), v, v + 1.5))
            v += 3.4
    for sign in (-1, 1):                                   # hastiales (N/S)
        v = -NAVE_X + 2.2
        while v < NAVE_X - 1.0:
            clere.append(("x", sign * (NAVE_Z + PANEL / 2), v, v + 1.5))
            v += 3.4
    ## Muro a muro, con sus vanos de una vez:
    for sign in (-1, 1):
        ops = [o[2:] for o in clere if o[0] == "z" and (o[1] > 0) == (sign > 0)]
        wall_mat("NE%+d" % sign, "z", sign * (NAVE_X + PANEL / 2),
                 -NAVE_Z, NAVE_Z,
                 [(a, b, 3.60, 4.40) for a, b in ops], (-face_out * sign,),
                 wall_panel, thick=PANEL, surface="steel", height=NAVE_H,
                 stud=frame)
        ops = [o[2:] for o in clere if o[0] == "x" and (o[1] > 0) == (sign > 0)]
        wall_mat("NN%+d" % sign, "x", sign * (NAVE_Z + PANEL / 2),
                 -NAVE_X, NAVE_X,
                 [(a, b, 3.60, 4.40) for a, b in ops], (-face_out * sign,),
                 wall_panel, thick=PANEL, surface="steel", height=NAVE_H,
                 stud=frame)
    ## Marcos de los lucernarios: cuatro travesaños por vano. Es lo que hace que
    ## el hueco se lea como ventana de nave y no como un agujero en la pared.
    for along, at, lo, hi in clere:
        for sign in (-1, 1):
            for y0, y1 in ((3.60, 3.66), (4.34, 4.40)):
                c = [0.0, (y0 + y1) / 2]
                sz = [0.0, y1 - y0]
                if along == "z":
                    c = [at, c[1], (lo + hi) / 2]
                    sz = [0.05, sz[1], hi - lo + 0.10]
                else:
                    c = [(lo + hi) / 2, c[1], at]
                    sz = [hi - lo + 0.10, sz[1], 0.05]
                box("MarcoV%d" % len(OBJECTS), c, sz, frame, "steel",
                    collider=False)
            for x in (lo, hi):
                c = [0.0, 4.0]
                sz = [0.0, 0.86]
                if along == "z":
                    c = [at, 4.0, x]
                    sz = [0.05, 0.86, 0.06]
                else:
                    c = [x, 4.0, at]
                    sz = [0.06, 0.86, 0.05]
                box("MarcoH%d" % len(OBJECTS), c, sz, frame, "steel",
                    collider=False)
    ## Losa del anillo: hormigon de taller, NO el tablero de la casa.
    ax, az = X1 + PANEL, Z1 + PANEL
    for tag, cx, cz, sx, sz in (
            ("N", 0.0, (az + NAVE_Z) / 2, 2 * NAVE_X + 2 * PANEL, NAVE_Z - az),
            ("S", 0.0, -(az + NAVE_Z) / 2, 2 * NAVE_X + 2 * PANEL, NAVE_Z - az),
            ("E", (ax + NAVE_X) / 2, 0.0, NAVE_X - ax, 2 * az),
            ("O", -(ax + NAVE_X) / 2, 0.0, NAVE_X - ax, 2 * az)):
        box("LosaNave" + tag, [cx, -0.02, cz], [sx, 0.04, sz],
            MATS["Map_Concrete"], "steel", penetrable=True, thin=0.04)
    ## Techo a dos aguas: faldones con colisor en escalones y hastiales que
    ## cierran los extremos sobre los muros norte/sur.
    eave_x, eave_y = NAVE_X + 0.35, NAVE_H - 0.05
    z0, z1 = -(NAVE_Z + 0.35), NAVE_Z + 0.35
    for sign in (-1, 1):
        quad = [(0, NAVE_RIDGE, z0), (sign * eave_x, eave_y, z0),
                (sign * eave_x, eave_y, z1), (0, NAVE_RIDGE, z1)]
        if sign < 0:
            quad = quad[::-1]
        prism("FaldonNave%+d" % sign, quad, (0, 0.035, 0), MATS["Map_Roof"])
        steps = 8
        for i in range(steps):
            a = sign * eave_x * i / steps
            b = sign * eave_x * (i + 1) / steps
            ya = eave_y + (NAVE_RIDGE - eave_y) * (1 - abs(a) / eave_x)
            yb = eave_y + (NAVE_RIDGE - eave_y) * (1 - abs(b) / eave_x)
            COLLIDERS.append({
                "name": "FaldonNave%+d_%d" % (sign, i),
                "center": Vector(((a + b) / 2, (ya + yb) / 2, (z0 + z1) / 2)),
                "size": Vector((abs(b - a), abs(ya - yb) + 0.035, z1 - z0)),
                "surface": "steel", "penetrable": True, "thin_shell": True,
                "wall_thickness": 0.0006})
        tri = [(-NAVE_X - PANEL, NAVE_H, 0), (NAVE_X + PANEL, NAVE_H, 0),
               (0, NAVE_RIDGE, 0)]
        prism("HastialNave%+d" % sign,
              [(-x, y, sign * (NAVE_Z + PANEL)) for x, y, _ in tri],
              (0, 0, PANEL * sign), wall_panel)
        for i in range(4):
            a = (-NAVE_X - PANEL) + (2 * NAVE_X + 2 * PANEL) * i / 4
            b = (-NAVE_X - PANEL) + (2 * NAVE_X + 2 * PANEL) * (i + 1) / 4
            top = NAVE_RIDGE - max(abs(a), abs(b)) * (NAVE_RIDGE - NAVE_H) \
                / (NAVE_X + PANEL)
            COLLIDERS.append({
                "name": "HastialNave%+d_%d" % (sign, i),
                "center": Vector(((a + b) / 2, (NAVE_H + top) / 2,
                                  sign * (NAVE_Z + PANEL / 2))),
                "size": Vector((b - a, top - NAVE_H, PANEL)),
                "surface": "steel", "penetrable": True, "thin_shell": True,
                "wall_thickness": PANEL})
    ## Cerchas de la nave: cordon inferior con colision y par de aguas.
    for z in (-9.0, 0.0, 9.0):
        bar("NaveCercha%d_b" % int(z * 10), (-NAVE_X, NAVE_H + 0.06, z),
            (NAVE_X, NAVE_H + 0.06, z), 0.07, frame)
        for sign in (-1, 1):
            bar("NaveCercha%d_t%+d" % (int(z * 10), sign), (0, NAVE_RIDGE, z),
                (sign * NAVE_X, NAVE_H + 0.02, z), 0.07, frame)
        for x in (-7.5, -5.0, -2.5, 0.0, 2.5, 5.0, 7.5):
            roof_y = NAVE_RIDGE - abs(x) * (NAVE_RIDGE - NAVE_H) / NAVE_X
            bar("NaveCercha%d_v%d" % (int(z * 10), int(x * 100)),
                (x, NAVE_H + 0.06, z), (x, roof_y - 0.03, z), 0.05, frame)
        COLLIDERS.append({"name": "NaveCercha%d" % int(z * 10),
                          "center": Vector((0, NAVE_H + 0.06, z)),
                          "size": Vector((2 * NAVE_X, 0.07, 0.07)),
                          "surface": "steel", "penetrable": False,
                          "thin_shell": False, "wall_thickness": 0.0})
    ## Tubos del anillo: CUELGAN de la cercha con dos tirantes cada uno. Antes
    ## flotaban a 2,96 m en una nave de 5,20: se leian como luces pegadas en el
    ## aire. Ahora el reflector va alto, bajo el cordon, y baja la tulipa con
    ## varillas: el mismo numero de luces, una pieza fisica que las explica.
    for index, (x, z) in enumerate(((-2.0, 10.40), (2.0, 10.40),
                                    (-2.0, -10.40), (2.0, -10.40),
                                    (-7.20, 0.0), (7.20, 0.0))):
        cercha_z = 9.0 if z > 0 else (-9.0 if z < 0 else 0.0)
        if index < 4:
            ref_size, tube_size = [1.34, 0.05, 0.26], [1.20, 0.055, 0.055]
        else:
            ref_size, tube_size = [0.26, 0.05, 1.34], [0.055, 0.055, 1.20]
        box("NaveReflector%02d" % index, [x, NAVE_TUBE_Y + 0.09, z], ref_size,
            frame, "steel", collider=False)
        box("NaveTubo%02d" % index, [x, NAVE_TUBE_Y, z], tube_size,
            MATS["Map_Tube"], "steel", collider=False)
        ## Tirantes: de la cercha mas cercana al reflector. El tubo cuelga de
        ## UNA cercha real, no del aire.
        for dx in (-0.42, 0.42):
            if index < 4:
                tx = x + dx
            else:
                tx = x
            tz = cercha_z
            bar("NaveTirante%02d_%+d" % (index, int(dx * 100)),
                (tx, NAVE_H + 0.03, tz), (tx, NAVE_TUBE_Y + 0.09, z), 0.022,
                frame)
        marker("Tubo%02d" % (index + 14), (x, NAVE_TUBE_Y, z))


def build_kit_props() -> None:
    """MOBILIARIO DE TALLER del anillo. Es lo que convierte un volumen vacio en
    un sitio: bidones, un palet, listones de obra y una caja. Ademas son los
    UNICOS cuerpos del mapa con `aluminum` y con forma de CILINDRO, que es la
    geometria que `Ballistics` sabe abrir por paredes y hoy no tenia donde.
    Mismo dato para malla y colision (no hay dos verdades)."""
    steel = MATS["Map_Frame"]
    conv = MATS["Map_Concrete"]
    tarp = MATS["Map_Tarp"]    ## Cuatro bidones de acero en el anillo sur y este, lejos del paso del
    ## jugador y con linea de tiro desde el spawn.
    for index, (x, z) in enumerate(((-3.2, -9.6), (-1.6, -10.4), (6.6, -7.4),
                                    (7.0, -5.6))):
        cyl("Bidon%02d" % index, [x, 0.44, z], 0.29, 0.88, steel, "aluminum",
            mass=18.0)
    ## Listones y una pila de tablero: la obra del propio local.
    box("PilaTablero", [5.60, 0.22, 10.60], [1.22, 0.44, 2.44], conv, "pine",
        penetrable=True, thin=0.10)
    box("CajaObra", [-6.90, 0.30, -11.60], [0.62, 0.60, 0.82], conv, "pine",
        penetrable=True, thin=0.10)
    ## Palet tumbado (solo masa, sin colision a proposito: es plancha fina).
    box("Palet", [7.60, 0.07, 2.60], [1.10, 0.14, 0.90], tarp, "paper",
        collider=False)
    ## Tuberia de servicio pegada al muro: el detalle que da escala al muro.
    for index, (x, z0, z1) in enumerate(((8.90, -4.0, 2.0), (-8.90, -2.0, 4.0))):
        cyl_h("Tuberia%d" % index, [x, 3.30, (z0 + z1) / 2], 0.11, z1 - z0,
              steel, "steel", axis="z")


def build_markers() -> None:
    marker("Spawn", (0, 0.05, 6.2))
    ## Planta de la CASA: `CombatMap` la usa para separar la exposicion de dentro
    ## (tablero claro) de la del anillo de la nave (hormigon).
    marker("Casa", (0, 0, 0), (X1 - X0 + 2 * PANEL, H, Z1 - Z0 + 2 * PANEL))
    ## Fuera del paso: la caja de municion es un cuerpo con colision y en el vano
    ## lo tapaba.
    marker("Municion", (1.35, 0.0, 8.40))
    ## La zona de exposicion interior es la NAVE entera: el patio dejo de ser
    ## calle abierta, ahora es el anillo de la nave.
    marker("Interior", (0, 0, 0),
           (2 * NAVE_X + 2 * PANEL, NAVE_H, 2 * NAVE_Z + 2 * PANEL))
    ## Puesto de enemigo con su rumbo: miran al pasillo, que es por donde entra
    ## el jugador. El runtime no elige orientacion, la lee.
    posts = [(-3.4, -5.8, 0.9), (3.2, -3.2, -0.7), (-2.4, -1.2, 1.4),
             (2.6, 0.8, -1.6), (-3.6, 2.0, 1.2), (3.6, 4.2, -1.0),
             (-1.6, 5.6, 0.4), (0.0, -6.4, 0.0)]
    for index, (x, z, yaw) in enumerate(posts):
        marker("Puesto%d" % index, (x, 0.05, z), yaw=yaw)


def build() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    material("Map_Osb", TEX_MAP / "osb_diff.jpg", TEX_MAP / "osb_rough.jpg",
             TEX_MAP / "osb_nor_gl.jpg", color=(0.62, 0.52, 0.38), roughness=0.86)
    material("Map_Floor", TEX_MAP / "osb_diff.jpg", TEX_MAP / "osb_rough.jpg",
             TEX_MAP / "osb_nor_gl.jpg", color=(0.44, 0.37, 0.28), roughness=0.92)
    material("Map_Stud", TEX_REAL / "wood_oak_wood_planks_diff.jpg",
             TEX_REAL / "wood_oak_wood_planks_rough.jpg",
             TEX_REAL / "wood_oak_wood_planks_nor_gl.jpg",
             color=(0.72, 0.60, 0.42), roughness=0.80)
    material("Map_Roof", TEX_MAP / "roof_steel_diff.jpg",
             TEX_MAP / "roof_steel_rough.jpg", TEX_MAP / "roof_steel_nor_gl.jpg",
             color=(0.42, 0.38, 0.36), metallic=0.7, roughness=0.72)
    material("Map_Steel", TEX_MAP / "roof_steel_diff.jpg",
             TEX_MAP / "roof_steel_rough.jpg", TEX_MAP / "roof_steel_nor_gl.jpg",
             color=(0.30, 0.26, 0.24), metallic=0.8, roughness=0.62)
    material("Map_Tube", color=(0.95, 0.96, 0.98), roughness=0.4)
    material("Map_Tarp", TEX_ENEMY / "fabric_color.jpg",
             TEX_ENEMY / "fabric_rough.jpg", TEX_ENEMY / "fabric_normal.jpg",
             color=(0.06, 0.06, 0.07), roughness=0.90)
    ## LA NAVE TIENE SU PROPIA PIEL. La casa es tablero claro; la nave es chapa
    ## grecada atornillada y losa de taller. Sin esto, dentro y fuera eran el
    ## mismo tablero y el mapa se leia como una caja de OSB infinita.
    ## Chapa grecada para CERRAMIENTOS VERTICALES = aliasing puro a ras de ojo.
    ## La nave es de HORMIGON con montantes de acero: no repite el tablero de la
    ## casa y no tiene rejilla que muestrear.
    material("Map_Wall", TEX_REAL / "concrete_brushed_concrete_diff.jpg",
             TEX_REAL / "concrete_brushed_concrete_rough.jpg",
             TEX_REAL / "concrete_brushed_concrete_nor_gl.jpg",
             color=(0.52, 0.52, 0.51), roughness=0.93, normal_strength=0.5)
    ## Estructura de la nave (girts, cerchas, tirantes): acero de taller, NO el
    ## oxido del techo de la casa. Dos aceros distintos con dos trabajos.
    material("Map_Frame", TEX_MAP / "roof_steel_diff.jpg",
             TEX_MAP / "roof_steel_rough.jpg", TEX_MAP / "roof_steel_nor_gl.jpg",
             color=(0.28, 0.29, 0.31), metallic=0.55, roughness=0.55,
             normal_strength=0.4)
    material("Map_Concrete", TEX_REAL / "concrete_brushed_concrete_diff.jpg",
             TEX_REAL / "concrete_brushed_concrete_rough.jpg",
             TEX_REAL / "concrete_brushed_concrete_nor_gl.jpg",
             color=(0.46, 0.46, 0.45), roughness=0.95)
    build_nave()
    build_kit_props()
    build_shell()
    build_walls()
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
        if c.get("mass", 0.0) > 0.0:
            props += ["metadata/mass = %.2f" % c["mass"]]
        nodes.append('\n[node name="%s" type="StaticBody3D" parent="."]\n%s\n'
                     % (name, "\n".join(props)))
        nodes.append('\n[node name="Shape" type="CollisionShape3D" parent="%s"]\n'
                     'position = %s\nshape = SubResource("%s")\n'
                     % (name, fmt(c["center"]), shape_id(c)))
        ## OCULTADORES: los MISMOS tramos ciegos que alimentan los colisores, ni
        ## uno mas, para que los vanos queden ABIERTOS en el buffer de oclusion.
        ## El inset de 2 cm por cara deja la cara visible del muro por delante
        ## del ocultador: con las dos en el mismo plano el muro podria testear
        ## como oculto y desaparecer.
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
    """Encuadres de revision: pasillo abajo, cuarto y fachada."""
    scene = bpy.context.scene
    cam_data = bpy.data.cameras.new("Rev")
    cam_data.lens = 18.0
    cam = bpy.data.objects.new("Rev", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.render.resolution_x, scene.render.resolution_y = 1280, 720
    views = [
        ("pasillo", (0.0, 1.65, 6.2), (math.radians(90), 0.0, 0.0)),
        ("cuarto", (-4.2, 1.60, 4.6), (math.radians(90), 0.0,
                                       math.radians(-90))),
        ("fachada", (0.0, 2.4, 13.0), (math.radians(96), 0.0, 0.0)),
    ]
    for tag, loc, rot in views:
        cam.location = B(*loc)
        cam.rotation_euler = rot
        scene.render.filepath = "%s_%s.png" % (path.rsplit(".", 1)[0], tag)
        bpy.ops.render.render(write_still=True)
        print("MAPA revision %s" % scene.render.filepath)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    build()
    if "--shot" in argv:
        shot(argv[argv.index("--shot") + 1])
