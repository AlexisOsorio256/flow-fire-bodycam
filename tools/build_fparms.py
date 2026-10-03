#!/usr/bin/env python3
"""Anima los brazos en primera persona (Blender):
    blender -b --python tools/build_fparms.py -- [--out ruta]

Parte de assets/models/fps_arms.glb (malla y rig ya alineados a la Glock) y
reescribe sus cinco clips como un animador: poses clave de las manos sobre
objetivos IK (codo y hombro los resuelve Blender), dedos posados a mano,
curvas Bezier con anticipacion y asentamiento, y horneado visual a 60 fps.
Los instantes casan con Glock.gd (RELOAD_*, INSPECT_*): la mano llega al
brocal cuando suena el cargador. Coordenadas en el espacio del arma glTF
(+Y arriba, -Z cañon, m).
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import bpy
from mathutils import Euler, Matrix, Vector

REPO = Path(__file__).resolve().parent.parent
SRC = REPO / "assets" / "models" / "fps_arms.glb"
FPS = 60

CLIPS = {"Idle": 3.0, "Fire": 0.26, "Reload": 2.10, "ReloadEmpty": 2.35, "Inspect": 2.00}


def G(x, y, z):
    """Arma glTF -> Blender."""
    return Vector((x, -z, y))


def finger_names(side):
    return [b for b in ARM.data.bones.keys() if b.startswith(side + "_") and any(
        k in b for k in ("thumb", "point", "middle", "ring", "pink"))]


def setup():
    global ARM, REST
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scn = bpy.context.scene
    scn.render.fps = FPS
    bpy.ops.import_scene.gltf(filepath=str(SRC))
    ARM = next(o for o in scn.objects if o.type == "ARMATURE")
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    ARM.animation_data_create()
    ARM.animation_data.action = None
    for pb in ARM.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
        pb.rotation_mode = "QUATERNION"
    bpy.context.view_layer.update()
    REST = {b.name: ARM.matrix_world @ b.matrix_local for b in ARM.data.bones}
    targets = {}
    for side, wrist, elbow in (("L", "L_wrist_03", "L_elbow_01"), ("R", "R_wrist_028", "R_elbow_026")):
        e = bpy.data.objects.new("T_" + side, None)
        scn.collection.objects.link(e)
        e.rotation_mode = "QUATERNION"
        e.matrix_world = REST[wrist]
        targets[side] = e
        # El efector del IK es la cola del codo; un hijo del objetivo la lleva
        # consigo para que mover y girar la mano arrastre el antebrazo.
        tail = ARM.matrix_world @ ARM.data.bones[elbow].tail_local
        ik_pt = bpy.data.objects.new("IK_" + side, None)
        scn.collection.objects.link(ik_pt)
        ik_pt.parent = e
        ik_pt.matrix_parent_inverse = Matrix.Identity(4)
        ik_pt.location = REST[wrist].inverted() @ tail
        ik = ARM.pose.bones[elbow].constraints.new("IK")
        ik.target = ik_pt
        ik.use_tail = True
        ik.chain_count = 2
        ik.use_stretch = False
        cr = ARM.pose.bones[wrist].constraints.new("COPY_ROTATION")
        cr.target = e
        targets["ik_" + side] = ik_pt
    return targets


def pose_target(e, frame, loc, rot=(0.0, 0.0, 0.0), rest=None, interp="BEZIER"):
    """Clave de la mano: posicion en espacio del arma y giro (grados, XYZ del
    arma) sobre la orientacion de reposo de la muñeca."""
    base = REST[rest]
    r = Euler([math.radians(a) for a in (rot[0], -rot[2], rot[1])], "XYZ").to_matrix().to_4x4()
    m = Matrix.Translation(G(*loc)) @ r @ base.to_3x3().normalized().to_4x4()
    e.matrix_world = m
    e.keyframe_insert("location", frame=frame)
    e.keyframe_insert("rotation_quaternion", frame=frame)


def finger_pose(side, frame, curl=0.0, spread=0.0, thumb=0.0, index=None):
    """Dedos: `curl` cierra (+) o abre (-) todas las falanges sobre el agarre de
    reposo; `index` sobreescribe el indice (gatillo); `thumb` flexiona el pulgar."""
    for name in finger_names(side):
        pb = ARM.pose.bones[name]
        amount = curl
        if "point" in name and index is not None:
            amount = index
        if "thumb" in name:
            amount = thumb
        seg = 1.0 if "1_" in name else 0.8 if "2_" in name else 0.6
        q = Euler((math.radians(-28.0 * amount * seg), 0.0,
                   math.radians(spread * (6.0 if "pink" in name else 3.0 if "ring" in name else 0.0))),
                  "XYZ").to_quaternion()
        pb.rotation_quaternion = q
        pb.keyframe_insert("rotation_quaternion", frame=frame)


def F(t):
    return int(round(t * FPS)) + 1


# --- poses de la mano izquierda en el espacio del arma ----------------------
L_REST = (-0.033, -0.068, 0.138)
R_REST = (0.023, -0.024, 0.140)


def L(e, t, d=(0.0, 0.0, 0.0), rot=(0.0, 0.0, 0.0)):
    pose_target(e, F(t), tuple(L_REST[i] + d[i] for i in range(3)), rot, "L_wrist_03")


def R(e, t, d=(0.0, 0.0, 0.0), rot=(0.0, 0.0, 0.0)):
    pose_target(e, F(t), tuple(R_REST[i] + d[i] for i in range(3)), rot, "R_wrist_028")


def clip_idle(T):
    for i in range(5):
        t = CLIPS["Idle"] * i / 4.0
        s = math.sin(i / 4.0 * math.tau)
        L(T["L"], t, (0.0, 0.0012 * s, -0.0006 * s), (0.4 * s, 0.0, 0.0))
        R(T["R"], t, (0.0, 0.0008 * s, -0.0004 * s))
        finger_pose("L", F(t), curl=0.02 * s)
        finger_pose("R", F(t), index=-0.25 + 0.04 * s)


def clip_fire(T):
    # El arma retrocede en la mano (GlockRecoil); aqui solo el dedo y la
    # compresion de las muñecas que la siguen.
    for t, idx, d, rot in ((0.0, 0.10, 0.0, 0.0), (0.02, 0.85, 0.0, 0.0), (0.05, 0.75, 0.006, 3.0),
                           (0.11, 0.35, 0.002, 0.8), (0.26, 0.10, 0.0, 0.0)):
        R(T["R"], t, (0.0, d * 0.6, d), (rot, 0.0, 0.0))
        L(T["L"], t, (0.0, d * 0.5, d * 0.9), (rot * 0.8, 0.0, 0.0))
        finger_pose("R", F(t), index=idx)
        finger_pose("L", F(t), curl=0.0)


def reload_left(T, empty):
    e = T["L"]
    L(e, 0.00)
    L(e, 0.10, (-0.010, -0.006, 0.010), (-6.0, 0.0, 8.0))           # suelta el agarre
    L(e, 0.28, (-0.090, -0.150, 0.120), (-35.0, 10.0, 30.0))        # baja al portacargadores
    L(e, 0.48, (-0.150, -0.330, 0.250), (-60.0, 15.0, 40.0))        # en la bolsa
    L(e, 0.58, (-0.150, -0.345, 0.255), (-62.0, 15.0, 42.0))        # saca el lleno
    L(e, 0.80, (-0.070, -0.180, 0.150), (-25.0, 5.0, 20.0))         # sube con el cargador
    L(e, 0.96, (0.022, -0.075, -0.040), (15.0, 0.0, -10.0))         # bajo el brocal, alineado
    L(e, 1.20, (0.028, -0.030, -0.065), (18.0, 0.0, -12.0))         # lo mete
    L(e, 1.36, (0.030, -0.012, -0.068), (20.0, 0.0, -12.0))         # palma abajo
    L(e, 1.40, (0.030, 0.000, -0.068), (22.0, 0.0, -12.0))          # golpe de asiento
    L(e, 1.46, (0.030, -0.014, -0.066), (18.0, 0.0, -10.0))         # rebote
    if not empty:
        L(e, 1.70, (0.006, -0.010, 0.012), (4.0, 0.0, -3.0))
        L(e, 1.90, (-0.002, 0.002, -0.002), (-1.0, 0.0, 0.0))
        L(e, 2.10)
        return
    # Corredera abierta: vuelve al agarre y el pulgar izquierdo baja el retén.
    L(e, 1.62, (0.004, -0.004, 0.008), (3.0, 0.0, -2.0))
    L(e, 1.72, (0.002, -0.006, 0.004), (5.0, 0.0, -4.0))
    L(e, 1.78, (0.000, -0.002, 0.002), (1.0, 0.0, -1.0))
    L(e, 2.35)


def reload_fingers(T, empty):
    for t, c in ((0.0, 0.0), (0.10, -0.6), (0.40, 0.5), (0.58, 0.9), (0.96, 0.85), (1.30, -0.4),
                 (1.40, -0.7), (1.55, 0.0)):
        finger_pose("L", F(t), curl=c, spread=1.0 if c < 0 else 0.0, thumb=c * 0.5)
    if empty:
        for t, th in ((1.62, 0.0), (1.68, -0.6), (1.72, 0.9), (1.80, 0.0)):
            finger_pose("L", F(t), curl=0.0, thumb=th)
    end = CLIPS["ReloadEmpty" if empty else "Reload"]
    finger_pose("L", F(end), curl=0.0)
    for t, th, idx in ((0.0, 0.0, -0.25), (0.18, 0.0, -0.4), (0.26, 0.9, -0.4), (0.34, 0.0, -0.4),
                       (end - 0.2, 0.0, -0.3), (end, 0.0, -0.25)):
        finger_pose("R", F(t), thumb=th, index=idx)


def clip_reload(T, empty):
    end = CLIPS["ReloadEmpty" if empty else "Reload"]
    for t, d, rot in ((0.0, (0, 0, 0), (0, 0, 0)), (0.25, (0.0, 0.004, 0.006), (-3.0, 0.0, 2.0)),
                      (1.40, (0.0, 0.010, 0.004), (4.0, 0.0, 0.0)), (1.46, (0.0, 0.002, 0.0), (1.0, 0.0, 0.0)),
                      (end, (0, 0, 0), (0, 0, 0))):
        R(T["R"], t, d, rot)
    reload_left(T, empty)
    reload_fingers(T, empty)


def clip_inspect(T):
    e = T["L"]
    L(e, 0.00)
    L(e, 0.12, (0.010, -0.040, -0.020), (10.0, 0.0, -8.0))
    L(e, 0.20, (0.026, -0.060, -0.060), (18.0, 0.0, -12.0))       # coge la base del cargador
    L(e, 0.34, (0.026, -0.110, -0.060), (15.0, 0.0, -12.0))       # lo saca
    L(e, 0.85, (-0.050, -0.090, 0.050), (-20.0, 35.0, -50.0))     # lo enseña girado
    L(e, 1.25, (-0.045, -0.085, 0.045), (-24.0, 40.0, -55.0))
    L(e, 1.55, (0.026, -0.100, -0.060), (15.0, 0.0, -12.0))
    L(e, 1.66, (0.028, -0.040, -0.064), (20.0, 0.0, -12.0))       # lo asienta
    L(e, 1.72, (0.026, -0.052, -0.060), (16.0, 0.0, -10.0))
    L(e, 2.00)
    for t, c in ((0.0, 0.0), (0.14, -0.5), (0.20, 0.8), (0.85, 0.8), (1.62, 0.8), (1.70, -0.4), (2.0, 0.0)):
        finger_pose("L", F(t), curl=c, thumb=c * 0.6)
    for t in (0.0, 1.0, 2.0):
        R(T["R"], t, (0.0, 0.0, 0.0), (0.0, 6.0 * math.sin(t * math.pi), 0.0))
        finger_pose("R", F(t), index=-0.3)


def author(name, T, fn):
    for e in (T["L"], T["R"]):
        e.animation_data_clear()
        e.animation_data_create()
        e.animation_data.action = bpy.data.actions.new("%s_%s" % (name, e.name))
    ARM.animation_data.action = bpy.data.actions.new(name + "_src")
    fn()
    for obj in (T["L"], T["R"], ARM):
        for fc in obj.animation_data.action.fcurves:
            for kp in fc.keyframe_points:
                kp.interpolation = "BEZIER"
                kp.handle_left_type = kp.handle_right_type = "AUTO_CLAMPED"
            fc.update()
    end = F(CLIPS[name])
    bpy.context.view_layer.objects.active = ARM
    ARM.select_set(True)
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.select_all(action="SELECT")
    bpy.ops.nla.bake(frame_start=1, frame_end=end, only_selected=True, visual_keying=True,
                     clear_constraints=False, use_current_action=False, bake_types={"POSE"})
    bpy.ops.object.mode_set(mode="OBJECT")
    baked = ARM.animation_data.action
    baked.name = name
    baked.use_fake_user = True
    print("clip %-12s %d frames" % (name, end))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = Path(argv[argv.index("--out") + 1]) if "--out" in argv else SRC
    T = setup()
    author("Idle", T, lambda: clip_idle(T))
    author("Fire", T, lambda: clip_fire(T))
    author("Reload", T, lambda: clip_reload(T, False))
    author("ReloadEmpty", T, lambda: clip_reload(T, True))
    author("Inspect", T, lambda: clip_inspect(T))
    for pb in ARM.pose.bones:
        for c in list(pb.constraints):
            pb.constraints.remove(c)
    for e in T.values():
        bpy.data.objects.remove(e, do_unlink=True)
    for a in list(bpy.data.actions):
        if a.name not in CLIPS:
            bpy.data.actions.remove(a)
    ARM.animation_data.action = bpy.data.actions["Idle"]
    bpy.ops.export_scene.gltf(filepath=str(out), export_format="GLB", export_animations=True,
                              export_animation_mode="ACTIONS", export_force_sampling=True,
                              export_skins=True, export_yup=True, export_image_format="AUTO",
                              export_anim_single_armature=True)
    print("SUCCESS", out)


main()
