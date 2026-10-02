#!/usr/bin/env python3
"""build_kit.py -- EL EQUIPO DEL SOLDADO, anclado a huesos del contrato.

QUE ES Y QUE NO
---------------
Este modulo NO importa modelos, NO elige donante y NO exporta. Construye el
EQUIPO (casco, pasamontanas, chaleco porta-placas, porta-cargadores, mangas,
guantes, pantalon, rodilleras, botas y rifle) como primitivas rigidas pesadas a
huesos concretos, y lo suelda a la malla que le pasen.

Es la autoridad del EQUIPO y de nadie mas: cualquier cuerpo humanoide que
resuelva el contrato de `Enemy.gd` se viste con esto. Por eso vive aparte de
`build_enemy.py`, que es la autoridad de la CADENA (importar, renombrar, hornear
clips, exportar). Cambiar de soldado no toca este fichero.

POR QUE EXISTE (y no se compra un modelo vestido)
-------------------------------------------------
El equipo es lo que define la SILUETA de un soldado, y la silueta es lo unico
que se lee a 3-10 m con una bodycam. La referencia manda un soldado de negro
con casco, chaleco y rifle, y la cara no entra en cuadro: el contrato no pide
una cara, pide un CASCO con montura, un CHALECO con bolsas y un RIFLE en la
mano, con la boca del cañón declarada para el fogonazo. Eso se construye, y
construido se puede medir.

Todas las cotas salen del ALTO REAL DEL RIG con reglas antropometricas, nunca
de un numero escrito a mano: es el error que dejo al enemigo gigante (el equipo
se cotizaba contra la longitud del hueso `Head`, que en un donante media el
21 % del cuerpo).
"""

from __future__ import annotations

import math

import bpy
import bmesh
from mathutils import Euler, Matrix, Vector

## Huesos del contrato que el equipo puede usar como ancla. Si un cuerpo no
## resuelve uno de estos, `build_enemy.rename_bones` ya ha fallado antes.
ANCHORS = (
    "Hips", "Spine", "Chest", "Chest.001", "Neck", "Head",
    "Shoulder_L", "UpperArm_L", "ForeArm_L", "Hand_L",
    "Shoulder_R", "UpperArm_R", "ForeArm_R", "Hand_R",
    "Thigh_L", "Shin_L", "Foot_L", "Toe_L",
    "Thigh_R", "Shin_R", "Foot_R", "Toe_R",
)

## Reparto de los DOS slots de material que conoce `Enemy.gd`:
##   0 = uniforme (tela gris/verde medio)
##   1 = equipo (tela mas oscura: casco, chaleco, guantes, botas, rifle)
SLOT_UNIFORM = 0
SLOT_GEAR = 1


class Kit:
    """Constructor del equipo. Se instancia con el rig ya renombrado."""

    def __init__(self, arm, mesh, skin_mat, gear_mat):
        self.arm = arm
        self.mesh = mesh
        self.skin_mat = skin_mat
        self.gear_mat = gear_mat
        self.pieces: list = []
        ## Boca del cañon declarada por el kit, en espacio MUNDO de rest. La lee
        ## `build_enemy.py` y la exporta como propiedad del armature; `Enemy.gd`
        ## la convierte en el punto donde nace el fogonazo. None si no hay rifle.
        self.muzzle = None
        wm = arm.matrix_world
        bones = {b.name: b for b in arm.data.bones}
        missing = [n for n in ANCHORS if n not in bones]
        if missing:
            raise SystemExit("build_kit: al rig le faltan anclas: %s" % ", ".join(missing))
        self.bones = bones
        self.wm = wm

        ## COTAS ANTROPOMETRICAS, todas contra el alto real del rig.
        ## Las constantes son fracciones del cuerpo humano de referencia
        ## (7,5 cabezas): cabeza 0,135; hombros 0,245; cintura 0,60 del alto...
        head_lo, head_hi = self.hp("Head"), self.tp("Head")
        self.rig_h = (head_hi - self.hp("Foot_L")).length
        if self.rig_h < 0.5:
            self.rig_h = 1.83
        self.up = Vector((0.0, 0.0, 1.0))
        ## Orientacion del cuerpo: el hueso `Head` apunta hacia arriba, y el
        ## frente se saca del producto vectorial con el eje de hombros. Asi el
        ## kit se coloca igual en un rig que mire a -Y (FBX) o a +Z (glTF).
        self.fwd = self._facing()
        self.right = self.fwd.cross(self.up).normalized()
        self.head_c = (head_lo + head_hi) * 0.5
        self.shoulder_span = (self.hp("Shoulder_R") - self.hp("Shoulder_L")).length

    # -- anclas ------------------------------------------------------------
    def hp(self, name: str) -> Vector:
        return self.wm @ self.bones[name].head_local

    def tp(self, name: str) -> Vector:
        return self.wm @ self.bones[name].tail_local

    def _facing(self) -> Vector:
        """Frente del cuerpo en el mundo.

        El eje de hombros da la derecha; el frente es perpendicular a el y al
        eje del cuerpo. `Thigh_L` a la izquierda del cuerpo y `Foot_L` delante
        del tobillo cierran el signo sin depender de la convencion del donante.
        """
        side = (self.hp("Shoulder_R") - self.hp("Shoulder_L"))
        side = Vector((side.x, side.y, 0.0))
        if side.length < 1e-4:
            return Vector((0.0, 0.0, 1.0))
        side.normalize()
        f = side.cross(Vector((0.0, 0.0, 1.0))).normalized()
        # El pie apunta hacia delante: `Toe` esta por delante de `Foot`.
        probe = (self.hp("Toe_L") - self.hp("Foot_L"))
        if probe.dot(f) < 0.0:
            f = -f
        return f

    # -- primitivas --------------------------------------------------------
    def _corr(self, bone: str):
        """Matriz mundo que devuelve el espacio de apuntado al espacio de rest.

        El rifle se autorra DONDE ESTAN LAS MANOS en la pose de apuntado, pero
        la malla viaja en rest: con peso 1 al hueso, un vertice en rest `v` se
        pinta en pose en `Mp @ Mr^-1 @ v`, asi que el vertice de rest que cae en
        el punto de pose `p` es `Mr @ Mp^-1 @ p`. Identidad en rest, y por eso
        el mismo codigo coloca el rifle bien en apuntado y bien colgado abajo.
        """
        pb = self.arm.pose.bones.get(bone)
        if pb is None:
            return None
        Maw = self.arm.matrix_world
        Mp = Maw @ pb.matrix
        Mr = Maw @ self.bones[bone].matrix_local
        return Mr @ Mp.inverted()

    def _finish(self, obj, bone: str, slot: int, smooth: bool = False):
        vg = obj.vertex_groups.new(name=bone)
        vg.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
        mod = obj.modifiers.new("Armature", "ARMATURE")
        mod.object = self.arm
        obj.data.materials.append(self.gear_mat if slot == SLOT_GEAR else self.skin_mat)
        if smooth:
            for poly in obj.data.polygons:
                poly.use_smooth = True
        self.pieces.append(obj)
        return obj

    def _cube(self, name, center, size, bone, slot=SLOT_GEAR, rot=(0.0, 0.0, 0.0),
              bevel=0.006, corr=None):
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
        if bevel > 0.0005:
            bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bevel, segments=1,
                            profile=0.5, affect="EDGES")
        if any(abs(a) > 1e-6 for a in rot):
            m = Euler(rot, "XYZ").to_matrix()
            for v in bm.verts:
                v.co = m @ v.co
        for v in bm.verts:
            v.co += center
        if corr is not None:
            for v in bm.verts:
                v.co = corr @ v.co
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        obj = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(obj)
        return self._finish(obj, bone, slot)

    def _ball(self, name, center, radius, bone, slot=SLOT_GEAR, seg=10, ring=6,
              squash=(1.0, 1.0, 1.0), corr=None):
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=ring, radius=radius)
        for v in bm.verts:
            v.co.x *= squash[0]
            v.co.y *= squash[1]
            v.co.z *= squash[2]
            v.co += center
        if corr is not None:
            for v in bm.verts:
                v.co = corr @ v.co
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        obj = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(obj)
        return self._finish(obj, bone, slot, smooth=True)

    def _tube(self, name, p0: Vector, p1: Vector, r0: float, r1: float, bone,
              slot=SLOT_GEAR, seg=8, cap=True, corr=None):
        """Tubo de p0 a p1 con radios distintos: la manga y el pantalon son
        conos truncados, no cilindros, o el brazo sale como un canuto."""
        axis = p1 - p0
        ln = axis.length
        if ln < 1e-5:
            ln = 1e-4
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=cap, cap_tris=False, segments=seg,
                              radius1=r0, radius2=r1, depth=ln)
        # `create_cone` nace sobre +Z: se lleva al eje real.
        q = Vector((0.0, 0.0, 1.0)).rotation_difference(axis.normalized())
        m = q.to_matrix()
        mid = (p0 + p1) * 0.5
        for v in bm.verts:
            v.co = m @ v.co
            v.co += mid
        if corr is not None:
            for v in bm.verts:
                v.co = corr @ v.co
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        obj = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(obj)
        return self._finish(obj, bone, slot, smooth=True)

    # -- el equipo ---------------------------------------------------------
    def build(self):
        """Todas las piezas. El orden es el de la referencia, de arriba abajo."""
        self._head()
        self._torso()
        self._arms()
        self._legs()
        self._rifle()

    # CABEZA: casco con montura NIV y railes, pasamontanas y banda de vision.
    def _head(self):
        h = self.rig_h
        c = self.head_c
        skull = (self.tp("Head") - self.hp("Head")).length
        # Radio del casco: media cabeza humana + el grosor del casco.
        r = h * 0.082
        self._ball("Kit_Helmet", c + self.up * h * 0.030, r, "Head",
                   squash=(1.00, 1.06, 0.92), seg=14, ring=8)
        # Ala: aro que baja hasta la nuca y las orejas.
        self._tube("Kit_HelmetRim", c + self.up * h * 0.005 - self.fwd * h * 0.002,
                   c - self.up * h * 0.030, r * 1.02, r * 0.98, "Head", seg=14)
        # Montura NIV en el frente: placa + tubo corto.
        self._cube("Kit_NvgPlate", c + self.fwd * r * 0.92 + self.up * h * 0.045,
                   (h * 0.052, h * 0.020, h * 0.045), "Head")
        self._tube("Kit_NvgTube", c + self.fwd * r * 0.98 + self.up * h * 0.062,
                   c + self.fwd * (r * 0.98 + h * 0.035) + self.up * h * 0.062,
                   h * 0.019, h * 0.019, "Head", seg=10)
        # Raíles laterales.
        for side, bone in ((1.0, "Head"), (-1.0, "Head")):
            self._cube("Kit_Rail%s" % ("R" if side > 0 else "L"),
                       c + self.right * side * r * 1.00 + self.up * h * 0.030,
                       (h * 0.012, h * 0.075, h * 0.016), bone,
                       rot=(0.0, 0.0, 0.0))
        # Pasamontanas: cubre todo menos la banda de vision.
        self._ball("Kit_Balaclava", c - self.up * h * 0.012, r * 1.02, "Head",
                   slot=SLOT_UNIFORM, squash=(0.98, 1.02, 0.86), seg=12, ring=7)
        # Banda de vision (gafas oscuras). El contrato pide una cara que NO se
        # lea, y una banda oscura lo
        # cumple sin inventar una cara que el rig no tiene.
        self._cube("Kit_Visor", c + self.fwd * r * 0.86 + self.up * h * 0.010,
                   (h * 0.105, h * 0.016, h * 0.028), "Head")
        # Cuello cubierto.
        self._tube("Kit_Neck", self.hp("Neck"), self.hp("Chest.001"),
                   h * 0.048, h * 0.056, "Neck", SLOT_UNIFORM, seg=10)

    # TORSO: porta-placas delantero y trasero, faja, tirantes, bolsas.
    def _torso(self):
        h = self.rig_h
        chest_lo = self.hp("Chest")
        chest_hi = self.hp("Chest.001")
        mid = (chest_lo + chest_hi) * 0.5
        span = self.shoulder_span
        # Placas: 25 x 30 cm es una placa de nivel III real; se cotiza contra el
        # ancho de hombros para que un rig estrecho no saque un chaleco de niño.
        plate_w = span * 0.52
        plate_h = h * 0.20
        self._cube("Kit_PlateF", mid + self.fwd * (h * 0.088),
                   (plate_w, h * 0.028, plate_h), "Chest.001", bevel=0.012)
        self._cube("Kit_PlateB", mid - self.fwd * (h * 0.080),
                   (plate_w, h * 0.030, plate_h), "Chest.001", bevel=0.012)
        # Faja (cummerbund) sobre la cintura.
        self._cube("Kit_Cummerbund", self.hp("Spine") + self.up * h * 0.055,
                   (span * 0.50, h * 0.115, h * 0.085), "Spine", bevel=0.010)
        # Tirantes: del plato delantero al trasero por encima del hombro.
        for side, bone in ((1.0, "Chest.001"), (-1.0, "Chest.001")):
            self._cube("Kit_Strap%s" % ("R" if side > 0 else "L"),
                       mid + self.right * side * span * 0.20 + self.up * h * 0.055,
                       (span * 0.11, span * 0.32, h * 0.030), bone, bevel=0.008)
        # Tres bolsas de cargador en el frente, a la altura del vientre.
        for i, off in enumerate((-1, 0, 1)):
            self._cube("Kit_Pouch%d" % i,
                       mid + self.fwd * (h * 0.105) + self.up * h * 0.010
                       + self.right * off * plate_w * 0.30,
                       (plate_w * 0.26, h * 0.048, h * 0.085), "Chest.001",
                       bevel=0.008)
        # Dos bolsas laterales en la faja.
        for side, tag in ((1.0, "R"), (-1.0, "L")):
            self._cube("Kit_SidePouch" + tag,
                       self.hp("Spine") + self.up * h * 0.055
                       + self.right * side * span * 0.30 + self.fwd * h * 0.020,
                       (h * 0.055, h * 0.075, h * 0.075), "Spine", bevel=0.008)
        # Butt pack en la espalda baja (bolsa pequena, no una mochila).
        self._cube("Kit_ButtPack", self.hp("Spine") - self.fwd * h * 0.085
                   + self.up * h * 0.035,
                   (span * 0.34, h * 0.075, h * 0.095), "Spine", bevel=0.010)
        # Hombreras: el maniqui tiene el hombro liso y a 3 m el bulto del
        # chaleco es lo que lee a "equipado".
        for side, tag in ((1.0, "R"), (-1.0, "L")):
            self._ball("Kit_ShoulderPad" + tag,
                       self.hp("UpperArm_" + tag) + self.up * h * 0.012,
                       h * 0.052, "Shoulder_" + tag, squash=(1.0, 0.85, 0.72),
                       seg=10, ring=6)

    # BRAZOS: mangas sobre brazo y antebrazo, guantes.
    def _arms(self):
        h = self.rig_h
        for tag in ("L", "R"):
            ua0, ua1 = self.hp("UpperArm_" + tag), self.hp("ForeArm_" + tag)
            fa0, fa1 = self.hp("ForeArm_" + tag), self.hp("Hand_" + tag)
            self._tube("Kit_SleeveUp" + tag, ua0, ua1, h * 0.052, h * 0.045,
                       "UpperArm_" + tag, SLOT_UNIFORM, seg=10)
            self._tube("Kit_SleeveLo" + tag, fa0, fa1, h * 0.045, h * 0.038,
                       "ForeArm_" + tag, SLOT_UNIFORM, seg=10)
            # Codo: la banda de la articulacion del maniqui queda al aire; un
            # codo de tela la tapa y ademas lee a coderas.
            self._ball("Kit_Elbow" + tag, fa0, h * 0.046, "ForeArm_" + tag,
                       slot=SLOT_GEAR, squash=(1.0, 1.0, 0.9), seg=10, ring=6)
            # Guante: la mano entera, un poco mas gorda que la muneca.
            self._ball("Kit_Glove" + tag, fa1 + self.fwd * h * 0.020,
                       h * 0.048, "Hand_" + tag, squash=(1.0, 1.35, 0.85),
                       seg=10, ring=6)

    # PIERNAS: pantalon, rodillera y bota.
    def _legs(self):
        h = self.rig_h
        for tag in ("L", "R"):
            th0, th1 = self.hp("Thigh_" + tag), self.hp("Shin_" + tag)
            sh0, sh1 = self.hp("Shin_" + tag), self.hp("Foot_" + tag)
            self._tube("Kit_TrouserUp" + tag, th0, th1, h * 0.070, h * 0.055,
                       "Thigh_" + tag, SLOT_UNIFORM, seg=10)
            self._tube("Kit_TrouserLo" + tag, sh0, sh1, h * 0.055, h * 0.042,
                       "Shin_" + tag, SLOT_UNIFORM, seg=10)
            # Rodillera, sobre la rodilla de verdad (la cabeza del hueso Shin).
            self._ball("Kit_Knee" + tag, sh0 + self.fwd * h * 0.030, h * 0.052,
                       "Shin_" + tag, squash=(0.9, 0.75, 1.0), seg=10, ring=6)
            # Bota: cana + pie. El pie va del tobillo a la punta.
            self._tube("Kit_BootShaft" + tag,
                       self.hp("Foot_" + tag) - self.up * h * 0.005,
                       self.hp("Foot_" + tag) + self.up * h * 0.075,
                       h * 0.052, h * 0.050, "Foot_" + tag, seg=10)
            foot = (self.hp("Toe_" + tag) - self.hp("Foot_" + tag))
            ln = max(foot.length * 1.15, h * 0.13)
            self._cube("Kit_Boot" + tag,
                       self.hp("Foot_" + tag) + self.fwd * (ln * 0.42)
                       - self.up * h * 0.030,
                       (h * 0.055, ln, h * 0.045), "Foot_" + tag, bevel=0.010)

    # RIFLE en la mano derecha, canón siguiendo la línea antebrazo→mano.
    def _rifle(self):
        h = self.rig_h
        pb_h = self.arm.pose.bones.get("Hand_R")
        pb_f = self.arm.pose.bones.get("ForeArm_R")
        if pb_h is None or pb_f is None:
            return
        Maw = self.arm.matrix_world
        Mp_h = Maw @ pb_h.matrix
        Mp_f = Maw @ pb_f.matrix
        corr = self._corr("Hand_R")
        # La línea del arma es la del antebrazo a la mano de la pose activa: en
        # apuntado es la dirección del tiro y en rest cuelga pegada al brazo.
        bore = (Mp_h.translation - Mp_f.translation).normalized()
        grip = Mp_h.translation
        # Un fusil de asalto mide 0,85 m = 0,46 del alto de un hombre.
        L = h * 0.46
        top = grip - bore * (L * 0.30)
        q = Vector((0.0, 0.0, 1.0)).rotation_difference(bore)
        rot = q.to_euler()

        def part(name, off, size, slot=SLOT_GEAR):
            self._cube(name, top + bore * off, size, "Hand_R", slot,
                       rot=(rot.x, rot.y, rot.z), bevel=0.004, corr=corr)

        part("Kit_RifleBody", L * 0.30, (h * 0.030, h * 0.055, L * 0.40))
        part("Kit_RifleHand", L * 0.36, (h * 0.024, h * 0.028, L * 0.16))
        part("Kit_RifleBarrel", L * 0.52, (h * 0.013, h * 0.013, L * 0.30))
        part("Kit_RifleStock", -L * 0.02, (h * 0.026, h * 0.048, L * 0.20))
        # Cargador y visor, fuera del eje: la silueta del arma no es un canuto.
        down = (Vector((0.0, 0.0, -1.0)) - bore * bore.dot(Vector((0.0, 0.0, -1.0))))
        down = down.normalized() if down.length > 1e-4 else Vector((0.0, 0.0, -1.0))
        self._cube("Kit_RifleMag", top + bore * L * 0.28 + down * h * 0.045,
                   (h * 0.020, h * 0.070, L * 0.14), "Hand_R",
                   rot=(rot.x, rot.y, rot.z), bevel=0.004, corr=corr)
        self._cube("Kit_RifleOptic", top + bore * L * 0.34 - down * h * 0.028,
                   (h * 0.022, h * 0.022, L * 0.12), "Hand_R",
                   rot=(rot.x, rot.y, rot.z), bevel=0.004, corr=corr)
        # La boca del cañon, declarada: la punta real del tubo en rest.
        punta = L * (0.52 + 0.15)
        self.muzzle = corr @ (grip + bore * punta) if corr is not None \
            else grip + bore * punta

    def weld(self):
        """Suelda el equipo a la malla del cuerpo: UN solo skinned mesh, que es
        lo que exige `check_enemy` (el equipo horneado dentro, no piezas
        sueltas). `join` respeta el mundo, asi que el cuerpo viaja con su
        armature sin sorpresas."""
        bpy.ops.object.select_all(action="DESELECT")
        for o in self.pieces:
            o.select_set(True)
        self.mesh.select_set(True)
        bpy.context.view_layer.objects.active = self.mesh
        bpy.ops.object.join()
        return len(self.pieces)


def build_kit(arm, mesh, skin_mat, gear_mat):
    """Viste el cuerpo. Devuelve (piezas, boca del cañon): la boca es el punto
    mundo de rest donde `Enemy.gd` debe nacer el fogonazo, o None sin rifle."""
    kit = Kit(arm, mesh, skin_mat, gear_mat)
    kit.build()
    piezas = kit.weld()
    return piezas, kit.muzzle
