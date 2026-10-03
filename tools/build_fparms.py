#!/usr/bin/env python3

from __future__ import annotations

import math
import sys
from pathlib import Path

import bpy
from mathutils import Euler, Matrix, Quaternion, Vector

REPO = Path(globals().get("FPARMS_REPO") or Path(__file__).resolve().parent.parent)
SRC = REPO / "assets" / "models" / "fps_arms.glb"
GUN = REPO / "assets" / "models" / "g19_pistol.glb"
FPS = 60
CLIPS = {"Idle": 3.0, "Fire": 0.26, "Reload": 2.55, "ReloadEmpty": 3.10, "Inspect": 3.60}
WRIST = {"L": "L_wrist_03", "R": "R_wrist_028"}
ELBOW = {"L": "L_elbow_01", "R": "R_elbow_026"}
UPPER = {"L": "L_arm_00", "R": "R_arm_025"}
POLE = {"L": (-0.55, -0.75, 0.25), "R": (0.55, -0.75, 0.25)}
FOREARM_TWIST = 0.6
EYE = (-0.08, 0.16, 0.315)


def G(x, y, z):
    return Vector((x, -z, y))


def rot_gltf(rx, ry, rz):
    return Euler([math.radians(a) for a in (rx, -rz, ry)], "XYZ").to_matrix().to_4x4()


def F(t):
    return int(round(t * FPS)) + 1


def _reset():
    for coll in (bpy.data.objects, bpy.data.meshes, bpy.data.armatures, bpy.data.actions,
                 bpy.data.cameras, bpy.data.materials, bpy.data.images):
        for item in list(coll):
            coll.remove(item)


def setup():
    global ARM, REST, T, GUNPARTS
    _reset()
    scn = bpy.context.scene
    scn.render.fps = FPS
    bpy.ops.import_scene.gltf(filepath=str(SRC))
    ARM = next(o for o in scn.objects if o.type == "ARMATURE")
    for o in list(scn.objects):
        if o.type == "MESH" and o.parent is None:
            bpy.data.objects.remove(o, do_unlink=True)
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    ARM.animation_data_create()
    ARM.animation_data.action = None
    bpy.ops.import_scene.gltf(filepath=str(GUN))
    GUNPARTS = [o for o in scn.objects if o.type in {"MESH", "EMPTY"} and o.name not in ARM.children
                and o != ARM and o.parent is not ARM]
    mag = bpy.data.objects["Magazine"]
    _ensure_bones(mag)
    for pb in ARM.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
        pb.rotation_mode = "QUATERNION"
    bpy.context.view_layer.update()
    REST = {b.name: ARM.matrix_world @ b.matrix_local for b in ARM.data.bones}
    for o in GUNPARTS:
        if o.parent is None:
            mw = o.matrix_world.copy()
            o.parent = ARM
            o.parent_type = "BONE"
            o.parent_bone = "Weapon"
            o.matrix_world = mw
    T = {}
    for side in ("L", "R"):
        e = bpy.data.objects.new("T_" + side, None)
        scn.collection.objects.link(e)
        e.rotation_mode = "QUATERNION"
        e.matrix_world = REST[WRIST[side]]
        T[side] = e
    _hold_mag_offset()


def _ensure_bones(mag):
    bpy.context.view_layer.objects.active = ARM
    bpy.ops.object.mode_set(mode="EDIT")
    eb = ARM.data.edit_bones
    inv = ARM.matrix_world.inverted()
    if "Weapon" not in eb:
        b = eb.new("Weapon")
        b.head = inv @ Vector((0.0, 0.0, 0.0))
        b.tail = inv @ Vector((0.0, 0.08, 0.0))
        b.roll = 0.0
        b.parent = eb[WRIST["R"]]
        b.use_deform = False
    if "Mag" not in eb:
        b = eb.new("Mag")
        m = mag.matrix_world
        b.head = inv @ m.translation
        b.tail = inv @ (m.translation + m.to_3x3() @ Vector((0.0, 0.0, 0.06)))
        b.roll = 0.0
        b.parent = eb["L_palm_016"]
        b.use_deform = False
    bpy.ops.object.mode_set(mode="OBJECT")


def solve_arm(side, target):
    up, el, wr = UPPER[side], ELBOW[side], WRIST[side]
    S = REST[up].translation
    Ej0 = REST[el].translation
    Wp0 = REST[wr].translation
    L1 = (Ej0 - S).length
    L2 = (Wp0 - Ej0).length
    P = target.translation.copy()
    to = P - S
    d = min(max(to.length, abs(L1 - L2) + 1e-4), L1 + L2 - 1e-4)
    n = to.normalized()
    hint = G(*POLE[side])
    b = (hint - n * hint.dot(n)).normalized()
    cos_a = (L1 * L1 + d * d - L2 * L2) / (2.0 * L1 * d)
    sin_a = math.sqrt(max(0.0, 1.0 - cos_a * cos_a))
    E = S + (n * cos_a + b * sin_a) * L1
    Pr = S + n * d
    def frame(u, m):
        u = u.normalized()
        m = (m - u * m.dot(u)).normalized()
        return Matrix((u, m, u.cross(m))).transposed()
    m0 = (Ej0 - S).cross(Wp0 - Ej0)
    m1 = (E - S).cross(Pr - E)
    Ra = frame(E - S, m1) @ frame(Ej0 - S, m0).transposed()
    A = Matrix.Translation(S) @ Ra.to_4x4() @ Matrix.Translation(-S) @ REST[up]
    Eb = A @ REST[up].inverted() @ REST[el]
    Wp1 = (A @ REST[up].inverted() @ REST[el] @ REST[el].inverted() @ REST[wr]).translation
    Ej = Eb.translation
    Re = (Wp1 - Ej).rotation_difference(Pr - Ej).to_matrix()
    Eb = Matrix.Translation(Ej) @ Re.to_4x4() @ Matrix.Translation(-Ej) @ Eb
    q0 = (Eb @ REST[el].inverted() @ REST[wr]).to_quaternion()
    qd = target.to_quaternion() @ q0.inverted()
    f = (Pr - Ej).normalized()
    proj = f * Vector(qd[1:]).dot(f)
    twist = Quaternion((qd.w, proj.x, proj.y, proj.z)).normalized()
    angle = twist.angle if Vector(twist[1:]).dot(f) >= 0.0 else -twist.angle
    angle = (angle + math.pi) % math.tau - math.pi
    Rt = Matrix.Rotation(angle * FOREARM_TWIST, 4, f)
    Eb = Matrix.Translation(Ej) @ Rt @ Matrix.Translation(-Ej) @ Eb
    Wr = target.to_quaternion().to_matrix().to_4x4()
    Wr.translation = (Eb @ REST[el].inverted() @ REST[wr]).translation
    inv = ARM.matrix_world.inverted()
    for name, m in ((up, A), (el, Eb), (wr, Wr)):
        ARM.pose.bones[name].matrix = inv @ m
        bpy.context.view_layer.update()
    return (P - Pr).length


L_REST = (-0.033, -0.068, 0.138)
R_REST = (0.023, -0.024, 0.140)
L_INSERT = ((0.020, -0.031, -0.007), (15.0, 0.0, -90.0))
MAG_TRAVEL = 0.075


def hand_matrix(side, d=(0.0, 0.0, 0.0), rot=(0.0, 0.0, 0.0)):
    rest = L_REST if side == "L" else R_REST
    loc = G(*[rest[i] + d[i] for i in range(3)])
    base = REST[WRIST[side]]
    return Matrix.Translation(loc) @ rot_gltf(*rot) @ base.to_3x3().normalized().to_4x4()


def key(e, frame, m):
    e.matrix_world = m
    e.keyframe_insert("location", frame=frame)
    e.keyframe_insert("rotation_quaternion", frame=frame)


def R(t, d=(0.0, 0.0, 0.0), rot=(0.0, 0.0, 0.0)):
    key(T["R"], F(t), hand_matrix("R", d, rot))


def gun_at(t):
    bpy.context.scene.frame_set(F(t))
    return T["R"].matrix_world @ REST[WRIST["R"]].inverted()


L_GRIP_ROT = (30.0, 0.0, 0.0)


def Lg(t, d=(0.0, 0.0, 0.0), rot=(0.0, 0.0, 0.0), grip=True):
    base = L_GRIP_ROT if grip else (0.0, 0.0, 0.0)
    key(T["L"], F(t), gun_at(t) @ hand_matrix("L", d, tuple(base[i] + rot[i] for i in range(3))))


def Lb(t, d=(0.0, 0.0, 0.0), rot=(0.0, 0.0, 0.0)):
    key(T["L"], F(t), hand_matrix("L", d, rot))


def Lmag(t, travel, off=0.0, tilt=(0.0, 0.0, 0.0)):
    d, rot = L_INSERT
    Lg(t, (d[0], d[1] - travel, d[2] + off), tuple(rot[i] + tilt[i] for i in range(3)), grip=False)


def _hold_mag_offset():
    global MAG_BASIS
    miss = solve_arm("L", hand_matrix("L", *L_INSERT))
    palm = ARM.matrix_world @ ARM.pose.bones["L_palm_016"].matrix
    want_local = palm.inverted() @ REST["Mag"]
    rest_local = REST["L_palm_016"].inverted() @ REST["Mag"]
    MAG_BASIS = rest_local.inverted() @ want_local
    print("mano izquierda en L_INSERT: falta %.1f mm de alcance" % (miss * 1000))
    for pb in ARM.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()


def finger_names(side):
    return [b for b in ARM.data.bones.keys() if b.startswith(side + "_") and any(
        k in b for k in ("thumb", "point", "middle", "ring", "pink"))]


def fingers(side, t, curl=0.0, spread=0.0, thumb=0.0, index=None):
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
        pb.keyframe_insert("rotation_quaternion", frame=F(t))


def clip_idle():
    n = 6
    for i in range(n + 1):
        t = CLIPS["Idle"] * i / n
        s = math.sin(i / n * math.tau)
        c = math.cos(i / n * math.tau)
        R(t, (0.0006 * c, 0.0012 * s, -0.0005 * s), (0.5 * s, 0.25 * c, 0.3 * c))
        Lg(t, (0.0, 0.0003 * s, 0.0), (0.2 * s, 0.0, 0.0))
        fingers("L", t, curl=0.55 + 0.03 * s)
        fingers("R", t, index=-0.25 + 0.04 * s)


def clip_fire():
    for t, idx, d, rot in ((0.0, -0.25, 0.0, 0.0), (0.03, 0.9, 0.0, 0.0), (0.06, 0.8, 0.013, 6.5),
                           (0.12, 0.3, 0.005, 2.4), (0.19, -0.1, -0.002, -0.5), (0.26, -0.25, 0.0, 0.0)):
        R(t, (0.0, d * 0.5, d), (rot, 0.0, -rot * 0.15))
        fingers("R", t, index=idx)
    for t in (0.0, 0.03, 0.06, 0.12, 0.19, 0.26):
        Lg(t)
        fingers("L", t, curl=0.12 if 0.02 < t < 0.15 else 0.0)


MAG_ORIENT = ((-0.050, 0.050, 0.015), (16.0, -10.0, -32.0))
L_RACK = ((-0.006, 0.030, -0.006), (-4.0, 0.0, 6.0))
L_VIEW = ((-0.012, 0.100, -0.075), (62.0, 0.0, -90.0))
L_VIEW_TURN = (6.0, 0.0, 16.0)


def _insert_hand(t0):
    Lmag(t0, 0.075)
    Lmag(t0 + 0.16, 0.030, -0.013)
    Lmag(t0 + 0.24, 0.010, -0.013, (5.0, 0.0, 0.0))
    Lmag(t0 + 0.32, 0.030, -0.012, (3.0, 0.0, 0.0))
    Lmag(t0 + 0.46, 0.026, -0.001)
    Lmag(t0 + 0.62, 0.006)
    Lmag(t0 + 0.70, -0.004)
    Lmag(t0 + 0.78, 0.012)


def _insert_fingers(t0):
    for t, c in ((t0, 0.85), (t0 + 0.24, 0.8), (t0 + 0.62, 0.8), (t0 + 0.70, 0.9), (t0 + 0.80, -0.4)):
        fingers("L", t, curl=c, thumb=c * 0.6)


def _insert_gun_from(t0):
    d, r = MAG_ORIENT
    R(t0 + 0.20, d, r)
    R(t0 + 0.24, (d[0] - 0.003, d[1] - 0.007, d[2] + 0.002), (r[0] + 3.0, r[1] + 1.0, r[2] + 1.0))
    R(t0 + 0.34, d, r)
    R(t0 + 0.54, (d[0] - 0.002, d[1] + 0.001, d[2]), (r[0] + 1.0, r[1], r[2]))
    R(t0 + 0.70, (d[0] + 0.002, d[1] - 0.012, d[2] + 0.006), (r[0] + 4.0, r[1] + 1.0, r[2] + 2.0))
    R(t0 + 0.80, (d[0], d[1] - 0.002, d[2] + 0.001), (r[0] + 1.0, r[1], r[2]))


def _reload_gun(end, empty):
    d, r = MAG_ORIENT
    R(0.00)
    R(0.10, (-0.004, 0.006, 0.004), (-2.0, 1.0, 3.0))
    R(0.46, d, r)
    _insert_gun_from(1.04)
    if empty:
        R(2.05, (-0.042, 0.056, -0.008), (20.0, -6.0, -34.0))
        R(2.22, (-0.040, 0.054, -0.014), (20.0, -6.0, -34.0))
        R(2.34, (-0.040, 0.058, -0.006), (22.0, -6.0, -34.0))
        R(2.60, (-0.020, 0.025, 0.0), (8.0, -3.0, -14.0))
    else:
        R(2.10, (-0.030, 0.040, -0.003), (14.0, -5.0, -22.0))
    R(end - 0.18, (-0.004, 0.003, 0.001), (1.0, 0.0, 1.0))
    R(end)


def _reload_left(end, empty):
    Lg(0.00)
    Lg(0.12, (-0.012, -0.010, 0.012), (-8.0, 0.0, 10.0))
    Lb(0.34, (-0.090, -0.170, 0.120), (-35.0, 10.0, 30.0))
    Lb(0.52, (-0.150, -0.330, 0.250), (-60.0, 15.0, 40.0))
    Lb(0.66, (-0.152, -0.345, 0.255), (-62.0, 15.0, 42.0))
    Lb(0.88, (-0.060, -0.200, 0.120), (-10.0, 5.0, 0.0))
    _insert_hand(1.04)
    rack_d, rack_r = L_RACK
    if empty:
        Lg(1.96, (rack_d[0], rack_d[1] - 0.010, rack_d[2] - 0.020), rack_r)
        Lg(2.14, rack_d, rack_r)
        Lg(2.24, (rack_d[0], rack_d[1], rack_d[2] + 0.044), rack_r)
        Lg(2.30, (rack_d[0], rack_d[1], rack_d[2] + 0.044), rack_r)
        Lg(2.38, (rack_d[0], rack_d[1], rack_d[2] - 0.010), rack_r)
        Lg(2.55, (0.004, -0.004, 0.010), (3.0, 0.0, -2.0))
        Lg(2.80, (0.0, -0.002, 0.002))
    else:
        Lg(1.96, (0.006, -0.010, 0.012), (4.0, 0.0, -3.0))
        Lg(2.20, (0.002, -0.004, 0.004), (1.0, 0.0, -1.0))
    Lg(end - 0.20, (0.0, -0.002, 0.002))
    Lg(end)


def _reload_fingers(end, empty):
    for t, c in ((0.0, 0.55), (0.12, -0.5), (0.45, 0.4), (0.58, -0.2), (0.66, 0.9), (0.88, 0.8)):
        fingers("L", t, curl=c, spread=1.0 if c < 0 else 0.0, thumb=c * 0.5)
    _insert_fingers(1.04)
    if empty:
        for t, c, th in ((1.96, -0.3, -0.4), (2.14, 0.6, 0.3), (2.30, 0.6, 0.3), (2.38, -0.5, -0.5), (2.55, 0.4, 0.0)):
            fingers("L", t, curl=c, thumb=th)
    else:
        fingers("L", 1.96, curl=0.3)
    fingers("L", end - 0.2, curl=0.55)
    fingers("L", end, curl=0.55)
    for t, th, idx in ((0.0, 0.0, -0.25), (0.18, 0.0, -0.45), (0.26, 0.9, -0.45), (0.34, 0.0, -0.45),
                       (end - 0.2, 0.0, -0.3), (end, 0.0, -0.25)):
        fingers("R", t, thumb=th, index=idx)


def clip_reload(empty):
    end = CLIPS["ReloadEmpty" if empty else "Reload"]
    _reload_gun(end, empty)
    _reload_left(end, empty)
    _reload_fingers(end, empty)


def clip_inspect():
    d, r = MAG_ORIENT
    R(0.00)
    R(0.12, (0.0, 0.004, 0.002), (-2.0, 2.0, 3.0))
    R(0.44, d, r)
    R(0.80, (d[0] + 0.004, d[1] - 0.010, d[2] + 0.004), (r[0] - 4.0, r[1] + 2.0, r[2] + 4.0))
    R(1.10, (-0.036, 0.026, 0.022), (12.0, -4.0, -20.0))
    R(2.00, (-0.038, 0.030, 0.020), (13.0, -4.0, -22.0))
    R(2.34, d, r)
    _insert_gun_from(2.20)
    R(3.20, (-0.010, 0.010, 0.0), (4.0, -1.0, -6.0))
    R(3.60)
    Lg(0.00)
    Lg(0.12, (-0.012, -0.010, 0.012), (-8.0, 0.0, 10.0))
    Lmag(0.30, 0.060)
    Lmag(0.42, 0.0)
    Lmag(0.50, -0.002)
    Lmag(0.62, 0.040)
    Lmag(0.76, 0.070)
    view_d, view_r = L_VIEW
    Lg(1.20, view_d, view_r, grip=False)
    Lg(1.55, view_d, tuple(view_r[i] + L_VIEW_TURN[i] for i in range(3)), grip=False)
    Lg(1.95, view_d, tuple(view_r[i] - 0.6 * L_VIEW_TURN[i] for i in range(3)), grip=False)
    _insert_hand(2.20)
    Lg(3.15, (0.002, -0.004, 0.006), (2.0, 0.0, -1.0))
    Lg(3.60)
    for t, c in ((0.0, 0.55), (0.12, -0.5), (0.30, 0.5), (0.42, 0.9), (1.20, 0.8), (1.95, 0.8)):
        fingers("L", t, curl=c, thumb=c * 0.6)
    _insert_fingers(2.20)
    fingers("L", 3.15, curl=0.55)
    fingers("L", 3.60, curl=0.55)
    for t, th, idx in ((0.0, 0.0, -0.25), (0.40, 0.0, -0.45), (0.46, 0.9, -0.45), (0.56, 0.0, -0.45),
                       (3.4, 0.0, -0.3), (3.6, 0.0, -0.25)):
        fingers("R", t, thumb=th, index=idx)


def author(name, fn):
    for e in (T["L"], T["R"]):
        e.animation_data_clear()
        e.animation_data_create()
        e.animation_data.action = bpy.data.actions.new("%s_%s" % (name, e.name))
    for pb in ARM.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    ARM.animation_data.action = action
    pb = ARM.pose.bones["Mag"]
    pb.matrix_basis = MAG_BASIS
    pb.keyframe_insert("location", frame=1)
    pb.keyframe_insert("rotation_quaternion", frame=1)
    fn()
    for obj in (T["L"], T["R"], ARM):
        for fc in obj.animation_data.action.fcurves:
            for kp in fc.keyframe_points:
                kp.interpolation = "BEZIER"
                kp.handle_left_type = kp.handle_right_type = "AUTO_CLAMPED"
            fc.update()
    end = F(CLIPS[name])
    worst = 0.0
    scn = bpy.context.scene
    for f in range(1, end + 1):
        scn.frame_set(f)
        for side in ("L", "R"):
            worst = max(worst, solve_arm(side, T[side].matrix_world.copy()))
            for bone in (UPPER[side], ELBOW[side], WRIST[side]):
                ARM.pose.bones[bone].keyframe_insert("rotation_quaternion", frame=f)
                ARM.pose.bones[bone].keyframe_insert("location", frame=f)
    print("clip %-12s %d frames, peor alcance %.1f mm, lo mas cerca del ojo %.0f mm"
          % (name, end, worst * 1000, nearest_to_eye(end) * 1000))


NEAR_LIMIT = 0.12


def nearest_to_eye(end, step=4):
    import numpy as np
    eye = G(*EYE)
    mesh_obj = next(o for o in ARM.children if any(m.type == "ARMATURE" for m in o.modifiers))
    deps = bpy.context.evaluated_depsgraph_get()
    best = 1e9
    for f in range(1, end + 1, step):
        bpy.context.scene.frame_set(f)
        ev = mesh_obj.evaluated_get(deps)
        me = ev.to_mesh()
        co = np.empty(len(me.vertices) * 3, dtype=np.float32)
        me.vertices.foreach_get("co", co)
        ev.to_mesh_clear()
        co = co.reshape(-1, 3) @ np.array(mesh_obj.matrix_world.to_3x3()).T + np.array(mesh_obj.matrix_world.translation)
        best = min(best, float(np.min(np.linalg.norm(co - np.array(eye), axis=1))))
    if best < NEAR_LIMIT:
        print("AVISO: la malla llega a %.0f mm del ojo" % (best * 1000))
    return best


def preview(folder, name, step=6, times=None, side=False):
    scn = bpy.context.scene
    cam = bpy.data.objects.get("PreviewCam")
    if cam is None:
        data = bpy.data.cameras.new("PreviewCam")
        data.sensor_fit = "VERTICAL"
        data.clip_start = 0.02
        cam = bpy.data.objects.new("PreviewCam", data)
        scn.collection.objects.link(cam)
    if side:
        cam.data.angle = math.radians(50.0)
        cam.location = G(-0.75, 0.05, -0.05)
        cam.rotation_euler = (math.radians(90.0), 0.0, math.radians(-90.0))
    else:
        cam.data.angle = math.radians(80.0)
        cam.location = G(*EYE)
        cam.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    scn.camera = cam
    scn.render.engine = "BLENDER_WORKBENCH"
    scn.display.shading.light = "STUDIO"
    scn.render.resolution_x = 640
    scn.render.resolution_y = 360
    ARM.animation_data.action = bpy.data.actions[name]
    frames = [F(t) for t in times] if times else list(range(1, F(CLIPS[name]) + 1, step))
    for i, f in enumerate(frames):
        scn.frame_set(f)
        scn.render.filepath = str(Path(folder) / ("%s%s_%02d.png" % (name, "_lado" if side else "", i)))
        bpy.ops.render.render(write_still=True)


def build(out=None, preview_dir=None):
    setup()
    author("Idle", clip_idle)
    author("Fire", clip_fire)
    author("Reload", lambda: clip_reload(False))
    author("ReloadEmpty", lambda: clip_reload(True))
    author("Inspect", clip_inspect)
    if preview_dir:
        for name in CLIPS:
            preview(preview_dir, name)
    for name in ("T_L", "T_R", "PreviewCam"):
        if name in bpy.data.objects:
            bpy.data.objects.remove(bpy.data.objects[name], do_unlink=True)
    for o in GUNPARTS:
        if o.name in bpy.data.objects:
            bpy.data.objects.remove(o, do_unlink=True)
    for a in list(bpy.data.actions):
        if a.name not in CLIPS:
            bpy.data.actions.remove(a)
    ARM.animation_data.action = bpy.data.actions["Idle"]
    if out:
        bpy.ops.export_scene.gltf(filepath=str(out), export_format="GLB", export_animations=True,
                                  export_animation_mode="ACTIONS", export_force_sampling=True,
                                  export_skins=True, export_yup=True, export_image_format="AUTO",
                                  export_anim_single_armature=True)
        print("SUCCESS", out)


if __name__ == "__main__" and "--" in sys.argv:
    argv = sys.argv[sys.argv.index("--") + 1:]
    out = Path(argv[argv.index("--out") + 1]) if "--out" in argv else SRC
    prev = argv[argv.index("--preview") + 1] if "--preview" in argv else None
    build(out, prev)
