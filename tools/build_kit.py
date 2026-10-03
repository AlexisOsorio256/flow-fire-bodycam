#!/usr/bin/env python3
"""Viste el cuerpo de la UAL como soldado (Blender). Lo usa build_enemy.py.

El uniforme es el propio cuerpo inflado por zonas (camisa, pantalon, botas,
guantes, pasamontanas); el equipo son cascaras que siguen la superficie del
cuerpo (placas, faja, tirantes, cinturon, rodilleras, gafas) mas piezas
modeladas (casco de corte alto con railes y soporte NVG, portacargadores,
radios, funda) y la Glock del juego en la mano derecha. Todo queda pesado a los
huesos y soldado en una malla con dos materiales: 0 tela, 1 equipo.
Las cotas estan en metros de un cuerpo de 1,78 m y se escalan con `k`.
"""

from __future__ import annotations

import math
from pathlib import Path

import bpy
import bmesh
from mathutils import Matrix, Vector

SLOT_UNIFORM = 0
SLOT_GEAR = 1
REPO = Path(__file__).resolve().parent.parent
PISTOL = REPO / "assets" / "models" / "g19_pistol.glb"
INFLATE = {"torso": 0.010, "arm": 0.008, "leg": 0.012, "boot": 0.022, "hand": 0.004, "head": 0.005}
TORSO = ("Spine", "Chest", "Chest.001")


class Kit:
    def __init__(self, arm, mesh, skin_mat, gear_mat):
        self.arm = arm
        self.mesh = mesh
        self.mats = (skin_mat, gear_mat)
        self.pieces: list = []
        self.muzzle = None
        self.wm = arm.matrix_world
        self.bones = {b.name: b for b in arm.data.bones}
        self.up = Vector((0.0, 0.0, 1.0))
        side = self.hp("Shoulder_R") - self.hp("Shoulder_L")
        side.z = 0.0
        self.right = side.normalized()
        self.fwd = self.up.cross(self.right).normalized()
        if (self.hp("Toe_L") - self.hp("Foot_L")).dot(self.fwd) < 0.0:
            self.fwd = -self.fwd
            self.right = -self.right
        self.groups = [g.name for g in mesh.vertex_groups]
        self._dominant()
        self.floor = min(self.hp("Foot_L").z, self.hp("Foot_R").z)
        self.k = (self.tp("Head").z - self.floor + 0.10) / 1.78
        print("build_kit: escala k=%.3f" % self.k)

    def _dominant(self):
        self.dominant = {}
        for v in self.mesh.data.vertices:
            best, bw = "", 0.0
            for g in v.groups:
                if g.weight > bw:
                    best, bw = self.groups[g.group], g.weight
            self.dominant[v.index] = best

    def hp(self, name):
        return self.wm @ self.bones[name].head_local

    def tp(self, name):
        return self.wm @ self.bones[name].tail_local

    def verts(self, bones):
        return [v.co.copy() for v in self.mesh.data.vertices if self.dominant[v.index] in bones]

    def profile(self, bones, z, band):
        """Radio del cuerpo alrededor de su eje a la altura z, por angulo
        (36 sectores, suavizado): la base de las piezas que lo rodean."""
        pts = [p for p in self.verts(bones) if abs(p.z - z) < band]
        cx = sum(p.x for p in pts) / len(pts)
        cy = sum(p.y for p in pts) / len(pts)
        rad = [0.0] * 36
        for p in pts:
            d = Vector((p.x - cx, p.y - cy, 0.0))
            a = int(((math.atan2(d.dot(self.fwd), d.dot(self.right)) + math.pi) / math.tau) * 36) % 36
            rad[a] = max(rad[a], d.length)
        for _ in range(3):
            rad = [max(rad[i], (rad[i - 1] + rad[(i + 1) % 36]) * 0.5) for i in range(36)]
        return Vector((cx, cy, 0.0)), rad

    def around(self, centre, rad, angle, z, extra):
        t = (angle + math.pi) / math.tau * 36.0
        i = int(math.floor(t)) % 36
        w = t - math.floor(t)
        r = rad[i] * (1.0 - w) + rad[(i + 1) % 36] * w + extra
        return Vector((centre.x, centre.y, z)) + (self.right * math.cos(angle) + self.fwd * math.sin(angle)) * r

    def wrap(self, name, bones, z0, z1, a0, a1, offset, thick, bone, cols=24, rows=6, flat=0.0, corner=0.0):
        """Pieza que rodea el cuerpo entre z0..z1 y los angulos a0..a1 (0 = derecha,
        pi/2 = frente), separada `offset` y con grosor `thick`. `flat` aplana
        hacia la cuerda (placas); `corner` recorta las esquinas de arriba."""
        bm = bmesh.new()
        grid = []
        for j in range(rows + 1):
            z = z0 + (z1 - z0) * j / rows
            centre, rad = self.profile(bones, z, 0.04 * self.k)
            row = []
            for i in range(cols + 1):
                t = i / cols
                shrink = corner * max(0.0, j / rows - 0.6) / 0.4 * (abs(t - 0.5) * 2.0) ** 2
                a = a0 + (a1 - a0) * (0.5 + (t - 0.5) * (1.0 - shrink))
                p = self.around(centre, rad, a, z, offset)
                if flat > 0.0:
                    mid = self.around(centre, rad, (a0 + a1) * 0.5, z, offset)
                    axis = (self.right * math.cos((a0 + a1) * 0.5) + self.fwd * math.sin((a0 + a1) * 0.5))
                    p = p + axis * ((mid - p).dot(axis)) * flat
                row.append(bm.verts.new(p))
            grid.append(row)
        for j in range(rows):
            for i in range(cols):
                bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
        bm.normal_update()
        centre = self.profile(bones, (z0 + z1) * 0.5, 0.04 * self.k)[0]
        for f in bm.faces:
            out = f.calc_center_median() - Vector((centre.x, centre.y, f.calc_center_median().z))
            if f.normal.dot(out) < 0.0:
                f.normal_flip()
        bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=thick)
        for f in bm.faces:
            f.smooth = True
        return self._object(name, bm, SLOT_GEAR, bone=bone)

    # --- uniforme ----------------------------------------------------------
    def zone(self, b, co):
        if b.startswith(("Hand", "DEF-f_", "DEF-thumb")):
            return "hand"
        if b.startswith(("Foot", "Toe")):
            return "boot"
        if b.startswith("Shin"):
            return "boot" if co.z < self.floor + 0.13 * self.k else "leg"
        if b.startswith(("Thigh", "Hips")):
            return "leg"
        if b.startswith(("Head", "Neck")):
            return "head"
        if b.startswith(("UpperArm", "ForeArm", "Shoulder")):
            return "arm"
        return "torso"

    def dress_body(self):
        k = self.k
        me = self.mesh.data
        bm = bmesh.new()
        bm.from_mesh(me)
        # Los vertices partidos por costuras de UV se inflarian por separado y
        # abririan grietas: se sueldan antes (la UV vive en el loop).
        bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
        bm.normal_update()
        deform = bm.verts.layers.deform.active
        zones = {}
        for v in bm.verts:
            w = v[deform] if deform is not None else {}
            bone = self.groups[max(w.items(), key=lambda kv: kv[1])[0]] if len(w) else ""
            zones[v] = self.zone(bone, v.co)
        sole = min(self.hp("Toe_L").z, self.hp("Toe_R").z) - 0.035 * k
        for v in bm.verts:
            v.co += v.normal * INFLATE[zones[v]] * k
            if zones[v] == "boot":
                v.co.z = max(v.co.z, sole)
        boot_top = self.floor + 0.13 * k
        for f in bm.faces:
            zs = [zones[v] for v in f.verts]
            hard = zs.count("hand") * 2 > len(zs) or (
                any(z in ("boot", "leg") for z in zs) and f.calc_center_median().z < boot_top)
            f.material_index = SLOT_GEAR if hard else SLOT_UNIFORM
            f.smooth = True
        bm.to_mesh(me)
        bm.free()
        self._dominant()

    # --- utilidades --------------------------------------------------------
    def _object(self, name, bm, slot, bone=None, groups=False):
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        obj = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(obj)
        if groups:
            for g in self.groups:
                obj.vertex_groups.new(name=g)
        if bone is not None:
            vg = obj.vertex_groups.get(bone) or obj.vertex_groups.new(name=bone)
            vg.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
        obj.data.materials.append(self.mats[slot])
        self.pieces.append(obj)
        return obj

    def shell(self, name, keep, offset, thick, flatten=None):
        """Caras del cuerpo que cumplen keep(co, normal, hueso), separadas
        `offset`, opcionalmente aplanadas y con grosor `thick`."""
        bm = bmesh.new()
        bm.from_mesh(self.mesh.data)
        bm.verts.ensure_lookup_table()
        bm.normal_update()
        ok = {v.index for v in bm.verts if keep(v.co, v.normal, self.dominant.get(v.index, ""))}
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if not all(v.index in ok for v in f.verts)],
                         context="FACES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        if not bm.faces:
            bm.free()
            print("build_kit: %s sin caras" % name)
            return None
        bm.normal_update()
        for v in bm.verts:
            v.co += v.normal * offset
            if flatten is not None:
                v.co = flatten(v.co)
        print("build_kit: %s %d caras" % (name, len(bm.faces)))
        bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=-thick)
        for f in bm.faces:
            f.smooth = True
            f.material_index = 0
        return self._object(name, bm, SLOT_GEAR, groups=True)

    def box(self, name, center, size, bone, bevel, axes=None, corr=None):
        r, f, u = axes or (self.right, self.fwd, self.up)
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
        if bevel > 0.0:
            bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bevel, segments=2, profile=0.5,
                            affect="EDGES")
        m = Matrix((r, f, u)).transposed()
        for v in bm.verts:
            v.co = m @ v.co + center
            if corr is not None:
                v.co = corr @ v.co
        for fc in bm.faces:
            fc.smooth = True
        return self._object(name, bm, SLOT_GEAR, bone=bone)

    # --- equipo ------------------------------------------------------------
    def torso_gear(self):
        k, f, r, u = self.k, self.fwd, self.right, self.up
        c = self.hp("Chest")
        chest_lo, chest_hi = c.z, self.hp("Chest.001").z
        neck, spine, hips = self.hp("Neck").z, self.hp("Spine").z, self.hp("Hips").z
        tv = self.verts(TORSO)

        body = TORSO + ("Shoulder_L", "Shoulder_R", "Hips")
        half = math.pi / 2.0
        self.wrap("Kit_PlateF", body, chest_lo - 0.09 * k, neck - 0.05 * k, half - 0.85, half + 0.85,
                  0.030 * k, 0.022 * k, "Chest.001", flat=0.55, corner=0.35)
        self.wrap("Kit_PlateB", body, chest_lo - 0.09 * k, neck - 0.03 * k, -half - 0.9, -half + 0.9,
                  0.028 * k, 0.022 * k, "Chest.001", flat=0.5, corner=0.25)
        self.wrap("Kit_Cummerbund", body, spine - 0.01 * k, spine + 0.12 * k, -math.pi, math.pi,
                  0.020 * k, 0.012 * k, "Spine", cols=36, rows=3)
        self.wrap("Kit_Belt", ("Hips", "Spine", "Thigh_L", "Thigh_R"), hips + 0.02 * k, hips + 0.07 * k,
                  -math.pi, math.pi, 0.016 * k, 0.010 * k, "Hips", cols=36, rows=2)
        self.shell("Kit_Collar",
                   lambda co, n, b: b in ("Neck", "Chest.001") and neck - 0.05 * k < co.z < neck + 0.02 * k
                   and n.z < 0.6, 0.010 * k, 0.012 * k)
        front = max((p - c).dot(f) for p in tv)
        base = c + f * (front + 0.085 * k)
        for i in (-1, 0, 1):
            p = base + r * (i * 0.072 * k) - u * (0.02 * k)
            self.box("Kit_MagPouch%d" % (i + 2), p, (0.064 * k, 0.042 * k, 0.115 * k), "Chest", 0.008 * k)
            self.box("Kit_MagFlap%d" % (i + 2), p + u * (0.055 * k) + f * (0.004 * k),
                     (0.066 * k, 0.046 * k, 0.022 * k), "Chest", 0.006 * k)
        self.box("Kit_Admin", base + u * (chest_hi - c.z + 0.02 * k) - f * (0.02 * k),
                 (0.17 * k, 0.03 * k, 0.08 * k), "Chest.001", 0.008 * k)
        for s in (-1.0, 1.0):
            self.box("Kit_Radio" + ("R" if s > 0 else "L"),
                     c + r * (s * 0.17 * k) - f * (0.01 * k) + u * (spine - c.z + 0.07 * k),
                     (0.05 * k, 0.07 * k, 0.10 * k), "Spine", 0.008 * k)
        for tag in ("L", "R"):
            th = self.hp("Thigh_" + tag)
            s = 1.0 if tag == "R" else -1.0
            self.box("Kit_Cargo" + tag, th + r * (s * 0.085 * k) - u * (0.20 * k) + f * (0.01 * k),
                     (0.035 * k, 0.12 * k, 0.15 * k), "Thigh_" + tag, 0.012 * k)

    def legs_gear(self):
        k, f = self.k, self.fwd
        for tag in ("L", "R"):
            knee = self.hp("Shin_" + tag)
            centre, rad = self.profile(("Shin_" + tag, "Thigh_" + tag), knee.z, 0.03 * k)
            p = self.around(centre, rad, math.pi / 2.0, knee.z, 0.012 * k)
            self.box("Kit_Knee" + tag, p - self.up * (0.01 * k), (0.085 * k, 0.03 * k, 0.11 * k),
                     "Shin_" + tag, 0.012 * k)

    def head_gear(self):
        k, f, r, u = self.k, self.fwd, self.right, self.up
        hv = self.verts(("Head",))
        xs, ys, zs = [p.dot(r) for p in hv], [p.dot(f) for p in hv], [p.z for p in hv]
        rx = (max(xs) - min(xs)) * 0.5 + 0.022 * k
        ry = (max(ys) - min(ys)) * 0.5 + 0.024 * k
        top = max(zs) + 0.018 * k
        brow = max(zs) - (max(zs) - min(zs)) * 0.36
        rz = top - brow + 0.03 * k
        centre = r * ((max(xs) + min(xs)) * 0.5) + f * ((max(ys) + min(ys)) * 0.5) + u * (top - rz)
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=32, v_segments=16, radius=1.0)
        cut = []
        for v in bm.verts:
            side, front = abs(v.co.x), v.co.y
            limit = -0.22 + side * side * 0.32 * (1.0 if front > -0.3 else 0.5) - max(0.0, -front) * 0.12
            if v.co.z < limit:
                cut.append(v)
        bmesh.ops.delete(bm, geom=cut, context="VERTS")
        for v in bm.verts:
            v.co = Vector((v.co.x * rx, v.co.y * ry, v.co.z * rz))
        bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.011 * k)
        bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=1, use_grid_fill=True, smooth=0.6)
        m = Matrix((r, f, u)).transposed()
        for v in bm.verts:
            v.co = m @ v.co + centre
        for fc in bm.faces:
            fc.smooth = True
        self._object("Kit_Helmet", bm, SLOT_GEAR, bone="Head")
        hc = centre + u * (rz * 0.15)
        for s in (-1.0, 1.0):
            self.box("Kit_Rail" + ("R" if s > 0 else "L"), hc + r * (s * (rx + 0.004 * k)),
                     (0.008 * k, ry * 1.35, 0.022 * k), "Head", 0.003 * k)
        self.box("Kit_NvgMount", centre + f * (ry + 0.006 * k) + u * (rz * 0.35),
                 (0.05 * k, 0.012 * k, 0.05 * k), "Head", 0.004 * k)
        self.box("Kit_NvgArm", centre + f * (ry + 0.030 * k) + u * (rz * 0.38),
                 (0.03 * k, 0.04 * k, 0.025 * k), "Head", 0.004 * k)
        self.box("Kit_Counterweight", centre - f * (ry + 0.012 * k) + u * (rz * 0.25),
                 (0.08 * k, 0.025 * k, 0.05 * k), "Head", 0.008 * k)
        self.box("Kit_Velcro", centre + u * (rz + 0.002 * k), (0.06 * k, 0.10 * k, 0.004 * k), "Head", 0.002 * k)
        eye = min(zs) + (max(zs) - min(zs)) * 0.55
        self.shell("Kit_Glasses",
                   lambda co, n, b: b == "Head" and n.dot(f) > 0.3 and abs(co.z - eye) < 0.03 * k,
                   0.012 * k, 0.004 * k)

    def pistol(self):
        """La Glock del juego colocada en la mano derecha en la pose de apuntado
        y devuelta a rest (`corr`) para pesarla al hueso de la mano."""
        k = self.k
        pb_h = self.arm.pose.bones.get("Hand_R")
        pb_f = self.arm.pose.bones.get("ForeArm_R")
        if pb_h is None or pb_f is None or not PISTOL.exists():
            return
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(PISTOL))
        new = [o for o in bpy.data.objects if o not in before]
        parts = [o for o in new if o.type == "MESH"]
        bm = bmesh.new()
        for o in parts:
            o.data.calc_loop_triangles()
            tmp = bmesh.new()
            tmp.from_mesh(o.data)
            tmp.transform(o.matrix_world)
            me = bpy.data.meshes.new("tmp")
            tmp.to_mesh(me)
            tmp.free()
            bm.from_mesh(me)
            bpy.data.meshes.remove(me)
        for o in new:
            bpy.data.objects.remove(o, do_unlink=True)
        lo = Vector([min(v.co[i] for v in bm.verts) for i in range(3)])
        hi = Vector([max(v.co[i] for v in bm.verts) for i in range(3)])
        Maw = self.arm.matrix_world
        hand = Maw @ pb_h.matrix
        elbow = (Maw @ pb_f.matrix).translation
        bore = (hand.translation - elbow).normalized()
        upv = (self.up - bore * bore.dot(self.up)).normalized()
        side = bore.cross(upv).normalized()
        grip = hand.translation + bore * (0.07 * k) - upv * (0.01 * k)
        # Modelo: +Y cañon, +Z arriba, empuñadura atras y abajo.
        pivot = Vector(((lo.x + hi.x) * 0.5, lo.y + (hi.y - lo.y) * 0.22, lo.z + (hi.z - lo.z) * 0.62))
        tip = Vector(((lo.x + hi.x) * 0.5, hi.y, lo.z + (hi.z - lo.z) * 0.82))
        rot = Matrix((side, bore, upv)).transposed()
        corr = (Maw @ self.bones["Hand_R"].matrix_local) @ hand.inverted()
        for v in bm.verts:
            v.co = corr @ (rot @ ((v.co - pivot) * k) + grip)
        self.muzzle = corr @ (rot @ ((tip - pivot) * k) + grip)
        for fc in bm.faces:
            fc.smooth = True
            fc.material_index = 0
        self._object("Kit_Pistol", bm, SLOT_GEAR, bone="Hand_R")

    def weld(self):
        for o in self.pieces:
            mat = o.data.materials[0]
            o.data.materials.clear()
            for m in self.mats:
                o.data.materials.append(m)
            for p in o.data.polygons:
                p.material_index = self.mats.index(mat)
            if len(o.data.uv_layers) == 0:
                o.data.uv_layers.new()
        bpy.ops.object.select_all(action="DESELECT")
        for o in self.pieces:
            o.select_set(True)
        self.mesh.select_set(True)
        bpy.context.view_layer.objects.active = self.mesh
        bpy.ops.object.join()
        return len(self.pieces)


def build_kit(arm, mesh, skin_mat, gear_mat):
    """Viste el cuerpo; devuelve (piezas, boca de la pistola en rest)."""
    kit = Kit(arm, mesh, skin_mat, gear_mat)
    kit.dress_body()
    kit.torso_gear()
    kit.legs_gear()
    kit.head_gear()
    kit.pistol()
    return kit.weld(), kit.muzzle
