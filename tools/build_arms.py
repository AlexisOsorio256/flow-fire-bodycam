#!/usr/bin/env python3
"""FLOWFIRE PRODUCTION ARMS BUILDER — DIRECTLY AUTHORED HERO ANIMATIONS.

Constructs assets/models/fps_arms.glb from the donor rig (djmaesen_animated_pistol):
- Preserves 1 deform mesh (Object_83, 13,536 triangles), 1 material ('arms'), 51 deform bones.
- Aligns master combat grip directly with g19_pistol.glb (174 mm).
- Directly authors all 5 mechanical animation clips:
    * Idle (3.00 s): Seamless breathing cycle, index finger along frame shelf.
    * Fire (0.26 s): Trigger break at 0.02s + recoil impulse & smooth recovery.
    * Reload (2.10 s): Mag out (0.28s), pouch reach (0.62s), mag in (1.02s), palm strike (1.40s), return (2.10s).
    * ReloadEmpty (2.35 s): Mag cycle + slide stop release lever press at 1.72s, return (2.35s).
    * Inspect (2.00 s): Torso counter-rotation + left-hand chamber-presentation gesture, synchronized with Glock.gd slide lock/release (0.30s–1.20s).
- Analytical 2-bone IK prevents joint dislocation and mesh distortion.
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector, Quaternion, Euler

REPO = Path(__file__).resolve().parents[1]
DONOR = REPO / "downloads" / "models" / "djmaesen_animated_pistol" / "extracted" / "scene.gltf"
GUN = REPO / "assets" / "models" / "g19_pistol.glb"
OUT = REPO / "assets" / "models" / "fps_arms.glb"

FPS = 100

CLIPS = {
    "Idle": 3.00,
    "Fire": 0.26,
    "Reload": 2.10,
    "ReloadEmpty": 2.35,
    "Inspect": 2.00,
}


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS
    bpy.context.scene.render.fps_base = 1.0


def smooth_step(t: float, t0: float, t1: float) -> float:
    if t <= t0:
        return 0.0
    if t >= t1:
        return 1.0
    k = (t - t0) / (t1 - t0)
    return k * k * (3.0 - 2.0 * k)


def solve_2bone_ik(S: Vector, W: Vector, P: Vector, L1: float, L2: float) -> Vector:
    """Solves elbow position E given shoulder S, wrist W, pole P, and bone lengths L1, L2."""
    D_vec = W - S
    D = D_vec.length
    D = max(0.01, min(D, L1 + L2 - 0.0005))
    V = D_vec.normalized()

    pole_vec = P - S
    N = D_vec.cross(pole_vec)
    if N.length < 1e-5:
        N = Vector((1.0, 0.0, 0.0))
    else:
        N = N.normalized()

    U = N.cross(V).normalized()

    cos_alpha = (L1 * L1 + D * D - L2 * L2) / (2.0 * L1 * D)
    cos_alpha = max(-1.0, min(1.0, cos_alpha))
    alpha = math.acos(cos_alpha)

    E = S + L1 * (math.cos(alpha) * V + math.sin(alpha) * U)
    return E


def orient_arm_chain(
    S: Vector, E: Vector, W: Vector,
    rest_S_mat: Matrix, rest_E_mat: Matrix,
    rest_S_pos: Vector, rest_E_pos: Vector, rest_W_pos: Vector
) -> tuple[Matrix, Matrix]:
    """Computes world matrices for upper arm and forearm bones given solved S, E, W."""
    v_rest = (rest_E_pos - rest_S_pos).normalized()
    v_targ = (E - S).normalized()
    q_upper = v_rest.rotation_difference(v_targ)
    R_upper = q_upper.to_matrix().to_4x4()
    M_upper = Matrix.Translation(S) @ R_upper @ Matrix.Translation(-rest_S_pos) @ rest_S_mat

    w_rest = (rest_W_pos - rest_E_pos).normalized()
    w_targ = (W - E).normalized()
    q_fore = w_rest.rotation_difference(w_targ)
    R_fore = q_fore.to_matrix().to_4x4()
    M_fore = Matrix.Translation(E) @ R_fore @ Matrix.Translation(-rest_E_pos) @ rest_E_mat

    return M_upper, M_fore


def verify(glb_path: Path) -> bool:
    reset_scene()
    bpy.ops.import_scene.gltf(filepath=str(glb_path))
    arm = [o for o in bpy.context.selected_objects if o.type == "ARMATURE"]
    mesh = [o for o in bpy.context.selected_objects if o.type == "MESH"]
    if not arm or not mesh:
        print("VERIFY FAIL: Missing armature or mesh in", glb_path)
        return False

    n_bones = len(arm[0].data.bones)
    n_tris = sum(len(p.vertices) - 2 for p in mesh[0].data.polygons)
    print("VERIFY OK: bones=%d tris=%d meshes=%d in %s" % (n_bones, n_tris, len(mesh), glb_path))
    return True


def build_arms(donor_path: Path, gun_path: Path, out_path: Path, max_tex: int = 1024, bind_only: bool = False) -> None:
    reset_scene()

    # 1. Load Glock reference
    bpy.ops.import_scene.gltf(filepath=str(gun_path))
    glock_objs = list(bpy.context.selected_objects)

    # 2. Load Donor
    bpy.ops.import_scene.gltf(filepath=str(donor_path))
    donor_objs = [o for o in bpy.context.selected_objects if o not in glock_objs]

    donor_arm = [o for o in donor_objs if o.type == "ARMATURE"][0]
    donor_mesh = [o for o in donor_objs if o.type == "MESH" and "Object_83" in o.name][0]

    # Target combat grip transform
    total_scale = 0.01 * 0.84
    M_rot180 = Matrix.Rotation(math.radians(180), 4, "Z")
    M_scale = Matrix.Scale(total_scale, 4)
    # Beavertail alignment: ty = -0.2819, tz = 0.0983
    M_trans = Matrix.Translation(Vector((0.0, -0.2819, 0.0983)))
    M_total = M_trans @ M_rot180 @ M_scale

    donor_arm.parent = None
    donor_arm.matrix_basis = Matrix.Identity(4)
    donor_arm.matrix_world = M_total
    donor_mesh.parent = donor_arm
    donor_mesh.matrix_basis = Matrix.Identity(4)
    donor_mesh.matrix_parent_inverse = Matrix.Identity(4)

    def get_norm(raw_dict: dict[str, Matrix]) -> dict[str, Matrix]:
        out = {}
        for name, T in raw_dict.items():
            R = T.to_3x3().normalized().to_4x4()
            R.translation = T.translation
            out[name] = R
        return out

    # Sample frame 0 rest targets in world space
    bpy.context.scene.frame_set(0, subframe=0.0)
    bpy.context.view_layer.update()
    targets0_raw = {pb.name: donor_arm.matrix_world @ pb.matrix for pb in donor_arm.pose.bones}
    targets0_norm = get_norm(targets0_raw)

    # 3. Transform mesh vertices by linear blend skinning using targets0_raw:
    rest_orig = {b.name: b.matrix_local.copy() for b in donor_arm.data.bones}
    vgs = {vg.index: vg.name for vg in donor_mesh.vertex_groups}
    verts = []
    for v in donor_mesh.data.vertices:
        acc = Vector()
        total = 0.0
        for g in v.groups:
            name = vgs.get(g.group)
            if name in targets0_raw and g.weight > 0.0:
                diff = rest_orig[name].inverted() @ v.co
                acc += (targets0_raw[name] @ diff) * g.weight
                total += g.weight
        verts.append(acc / total if total > 1e-9 else v.co.copy())

    flat = []
    for v in verts:
        flat += [v.x, v.y, v.z]
    donor_mesh.data.vertices.foreach_set("co", flat)
    donor_mesh.data.update()

    # 4. Set edit bones to targets0_norm (scale 1.0):
    bpy.context.view_layer.objects.active = donor_arm
    bpy.ops.object.mode_set(mode="EDIT")
    for name, T in targets0_norm.items():
        eb = donor_arm.data.edit_bones.get(name)
        if eb:
            eb.matrix = T
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.context.view_layer.update()

    # 5. Clear transforms to identity:
    donor_arm.parent = None
    donor_arm.matrix_basis = Matrix.Identity(4)
    donor_arm.matrix_world = Matrix.Identity(4)
    donor_mesh.parent = donor_arm
    donor_mesh.matrix_basis = Matrix.Identity(4)
    donor_mesh.matrix_parent_inverse = Matrix.Identity(4)
    donor_mesh.matrix_world = Matrix.Identity(4)

    # 6. Clean objects and materials
    for o in list(donor_objs) + list(glock_objs):
        if o != donor_arm and o != donor_mesh:
            bpy.data.objects.remove(o, do_unlink=True)

    for mat in list(bpy.data.materials):
        if mat.name != "arms":
            bpy.data.materials.remove(mat, do_unlink=True)

    for img in bpy.data.images:
        if img.size[0] > 0 and (img.size[0] > max_tex or img.size[1] > max_tex):
            img.scale(max_tex, max_tex)

    # Bone hierarchy ordering
    order = []
    stack = [b for b in donor_arm.data.bones if b.parent is None]
    while stack:
        b = stack.pop(0)
        order.append(b)
        stack += list(b.children)

    def compute_local_basis(b_bone, W_dict: dict[str, Matrix]) -> Matrix:
        if b_bone.parent is None:
            return b_bone.matrix_local.inverted() @ W_dict[b_bone.name]
        p_name = b_bone.parent.name
        return (b_bone.matrix_local.inverted() @ b_bone.parent.matrix_local) @ (
            W_dict[p_name].inverted() @ W_dict[b_bone.name]
        )

    # Rest positions and bone lengths for 2-bone IK
    # Left arm:
    S_L_rest = targets0_norm["L_arm_00"].translation.copy()
    E_L_rest = targets0_norm["L_elbow_01"].translation.copy()
    W_L_rest = targets0_norm["L_wrist_03"].translation.copy()
    L1_left = (E_L_rest - S_L_rest).length
    L2_left = (W_L_rest - E_L_rest).length
    Pole_L = Vector((-0.25, -0.45, -0.30))  # Elbow points out/down

    # Right arm:
    S_R_rest = targets0_norm["R_arm_025"].translation.copy()
    E_R_rest = targets0_norm["R_elbow_026"].translation.copy()
    W_R_rest = targets0_norm["R_wrist_028"].translation.copy()
    L1_right = (E_R_rest - S_R_rest).length
    L2_right = (W_R_rest - E_R_rest).length
    Pole_R = Vector((0.25, -0.45, -0.20))

    # Left hand finger bone names:
    left_hand_sub_bones = [
        b.name for b in donor_arm.data.bones
        if b.name.startswith("L_thumb") or b.name.startswith("L_point") or
           b.name.startswith("L_middle") or b.name.startswith("L_ring") or
           b.name.startswith("L_pink") or b.name == "L_palm_016"
    ]

    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a, do_unlink=True)

    def apply_pose_and_keyframe(act, step: int, W: dict[str, Matrix]):
        for b in order:
            basis = compute_local_basis(b, W)
            pb = donor_arm.pose.bones[b.name]
            pb.rotation_mode = "QUATERNION"
            pb.location = basis.to_translation()
            pb.rotation_quaternion = basis.to_quaternion()
            pb.scale = basis.to_scale()
            pb.keyframe_insert("location", frame=step, group=pb.name)
            pb.keyframe_insert("rotation_quaternion", frame=step, group=pb.name)

    if not bind_only:
        # =========================================================================
        # CLIP 1: Idle (3.00 s)
        # =========================================================================
        act_idle = bpy.data.actions.new("Idle")
        act_idle.use_fake_user = True
        donor_arm.animation_data.action = act_idle
        dur_idle = CLIPS["Idle"]
        n_idle = int(round(dur_idle * FPS))

        for step in range(n_idle + 1):
            t = step / float(FPS)
            phase = 2.0 * math.pi * t / dur_idle
            breathe = math.sin(phase)

            W = {}
            for b in order:
                M = targets0_norm[b.name].copy()
                if b.name in ("L_arm_00", "R_arm_025"):
                    M.translation += Vector((0.0, -0.0003 * breathe, 0.0008 * breathe))
                elif b.name.startswith("R_point"):
                    # Right index finger along frame shelf
                    rot_off = Matrix.Rotation(math.radians(12.0), 4, "Z") @ Matrix.Rotation(math.radians(-6.0), 4, "X")
                    M = M @ rot_off
                W[b.name] = M

            apply_pose_and_keyframe(act_idle, step, W)

        for fc in act_idle.fcurves:
            for kp in fc.keyframe_points:
                kp.interpolation = "LINEAR"

        # =========================================================================
        # CLIP 2: Fire (0.26 s)
        # =========================================================================
        act_fire = bpy.data.actions.new("Fire")
        act_fire.use_fake_user = True
        donor_arm.animation_data.action = act_fire
        dur_fire = CLIPS["Fire"]
        n_fire = int(round(dur_fire * FPS))

        for step in range(n_fire + 1):
            t = step / float(FPS)
            recoil = 0.0
            if t <= 0.04:
                recoil = t / 0.04
            else:
                recoil = math.exp(-15.0 * (t - 0.04))

            trigger_curl = 0.0
            if t <= 0.02:
                trigger_curl = t / 0.02
            else:
                trigger_curl = max(0.0, 1.0 - (t - 0.02) / 0.14)

            W = {}
            for b in order:
                M = targets0_norm[b.name].copy()
                if b.name.startswith("R_point"):
                    flex_angle = 12.0 * (1.0 - trigger_curl) - 8.0 * trigger_curl
                    rot_flex = Matrix.Rotation(math.radians(flex_angle), 4, "Z") @ Matrix.Rotation(math.radians(-6.0 * (1.0 - trigger_curl)), 4, "X")
                    M = M @ rot_flex
                elif b.name in ("R_wrist_028", "L_wrist_03"):
                    pitch_rot = Matrix.Rotation(math.radians(1.8 * recoil), 4, "X")
                    M = Matrix.Translation(Vector((0.0, -0.0015 * recoil, 0.0018 * recoil))) @ M @ pitch_rot
                W[b.name] = M

            apply_pose_and_keyframe(act_fire, step, W)

        for fc in act_fire.fcurves:
            for kp in fc.keyframe_points:
                kp.interpolation = "LINEAR"

        # =========================================================================
        # CLIP 3: Reload (2.10 s) — 2-Bone IK Left Hand Trajectory
        # =========================================================================
        act_reload = bpy.data.actions.new("Reload")
        act_reload.use_fake_user = True
        donor_arm.animation_data.action = act_reload
        dur_reload = CLIPS["Reload"]
        n_reload = int(round(dur_reload * FPS))

        def get_reload_left_wrist(t: float) -> tuple[Vector, Matrix]:
            if t <= 0.28:
                # Drop from grip to below magwell
                k = smooth_step(t, 0.0, 0.28)
                pos = W_L_rest.lerp(Vector((-0.030, -0.120, -0.120)), k)
                rot = Matrix.Rotation(math.radians(-15.0 * k), 4, "X")
                return pos, rot
            elif t <= 0.62:
                # Move down to pouch
                k = smooth_step(t, 0.28, 0.62)
                pos = Vector((-0.030, -0.120, -0.120)).lerp(Vector((-0.090, -0.240, -0.290)), k)
                rot = Matrix.Rotation(math.radians(-15.0 - 20.0 * k), 4, "X") @ Matrix.Rotation(math.radians(15.0 * k), 4, "Z")
                return pos, rot
            elif t <= 1.02:
                # Bring fresh mag up to magwell entrance
                k = smooth_step(t, 0.62, 1.02)
                pos = Vector((-0.090, -0.240, -0.290)).lerp(Vector((-0.025, -0.095, -0.140)), k)
                rot = Matrix.Rotation(math.radians(-35.0 + 30.0 * k), 4, "X") @ Matrix.Rotation(math.radians(15.0 - 10.0 * k), 4, "Z")
                return pos, rot
            elif t <= 1.40:
                # Drive mag up and deliver sharp palm strike on basepad at 1.40s
                k = smooth_step(t, 1.02, 1.40)
                pos = Vector((-0.025, -0.095, -0.140)).lerp(Vector((-0.020, -0.075, -0.068)), k)
                rot = Matrix.Rotation(math.radians(-5.0 + 15.0 * k), 4, "X")
                return pos, rot
            elif t <= 1.75:
                # Rebound from palm strike and move toward support grip
                k = smooth_step(t, 1.40, 1.75)
                pos = Vector((-0.020, -0.075, -0.068)).lerp(W_L_rest + Vector((0.0, 0.015, -0.010)), k)
                rot = Matrix.Rotation(math.radians(10.0 * (1.0 - k)), 4, "X")
                return pos, rot
            else:
                # Settle firmly into master support grip
                k = smooth_step(t, 1.75, 2.10)
                pos = (W_L_rest + Vector((0.0, 0.015, -0.010))).lerp(W_L_rest, k)
                rot = Matrix.Identity(4)
                return pos, rot

        for step in range(n_reload + 1):
            t = step / float(FPS)
            W_targ, rot_wrist = get_reload_left_wrist(t)

            # Solve 2-bone IK for left arm:
            E_solved = solve_2bone_ik(S_L_rest, W_targ, Pole_L, L1_left, L2_left)
            M_upper, M_fore = orient_arm_chain(
                S_L_rest, E_solved, W_targ,
                targets0_norm["L_arm_00"], targets0_norm["L_elbow_01"],
                S_L_rest, E_L_rest, W_L_rest
            )

            # Wrist world matrix
            diff_wrist = W_targ - W_L_rest
            M_wrist = Matrix.Translation(diff_wrist) @ targets0_norm["L_wrist_03"] @ rot_wrist

            W = {}
            for b in order:
                if b.name == "L_arm_00":
                    W[b.name] = M_upper
                elif b.name == "L_elbow_01" or b.name == "L_forearm_02":
                    W[b.name] = M_fore
                elif b.name == "L_wrist_03":
                    W[b.name] = M_wrist
                elif b.name in left_hand_sub_bones:
                    rel_to_rest_wrist = targets0_norm["L_wrist_03"].inverted() @ targets0_norm[b.name]
                    W[b.name] = M_wrist @ rel_to_rest_wrist
                elif b.name.startswith("R_point"):
                    rot_off = Matrix.Rotation(math.radians(12.0), 4, "Z") @ Matrix.Rotation(math.radians(-6.0), 4, "X")
                    W[b.name] = targets0_norm[b.name] @ rot_off
                else:
                    W[b.name] = targets0_norm[b.name].copy()

            apply_pose_and_keyframe(act_reload, step, W)

        for fc in act_reload.fcurves:
            for kp in fc.keyframe_points:
                kp.interpolation = "LINEAR"

        # =========================================================================
        # CLIP 4: ReloadEmpty (2.35 s) — Mag Cycle + Slide Release Lever Press
        # =========================================================================
        act_reload_empty = bpy.data.actions.new("ReloadEmpty")
        act_reload_empty.use_fake_user = True
        donor_arm.animation_data.action = act_reload_empty
        dur_reload_empty = CLIPS["ReloadEmpty"]
        n_reload_empty = int(round(dur_reload_empty * FPS))

        def get_reload_empty_left_wrist(t: float) -> tuple[Vector, Matrix]:
            if t <= 1.40:
                return get_reload_left_wrist(t)
            elif t <= 1.72:
                # Move from palm strike up to slide release lever at (-0.035, -0.040, 0.015)
                k = smooth_step(t, 1.40, 1.72)
                pos = Vector((-0.020, -0.075, -0.068)).lerp(Vector((-0.035, -0.040, 0.015)), k)
                rot = Matrix.Rotation(math.radians(15.0 * k), 4, "Y") @ Matrix.Rotation(math.radians(-10.0 * k), 4, "X")
                return pos, rot
            elif t <= 1.95:
                # Press lever down and begin return
                k = smooth_step(t, 1.72, 1.95)
                pos = Vector((-0.035, -0.040, 0.015)).lerp(W_L_rest + Vector((0.0, 0.020, 0.0)), k)
                rot = Matrix.Rotation(math.radians(15.0 * (1.0 - k)), 4, "Y")
                return pos, rot
            else:
                # Settle into master support grip
                k = smooth_step(t, 1.95, 2.35)
                pos = (W_L_rest + Vector((0.0, 0.020, 0.0))).lerp(W_L_rest, k)
                rot = Matrix.Identity(4)
                return pos, rot

        for step in range(n_reload_empty + 1):
            t = step / float(FPS)
            W_targ, rot_wrist = get_reload_empty_left_wrist(t)

            E_solved = solve_2bone_ik(S_L_rest, W_targ, Pole_L, L1_left, L2_left)
            M_upper, M_fore = orient_arm_chain(
                S_L_rest, E_solved, W_targ,
                targets0_norm["L_arm_00"], targets0_norm["L_elbow_01"],
                S_L_rest, E_L_rest, W_L_rest
            )

            diff_wrist = W_targ - W_L_rest
            M_wrist = Matrix.Translation(diff_wrist) @ targets0_norm["L_wrist_03"] @ rot_wrist

            W = {}
            for b in order:
                if b.name == "L_arm_00":
                    W[b.name] = M_upper
                elif b.name == "L_elbow_01" or b.name == "L_forearm_02":
                    W[b.name] = M_fore
                elif b.name == "L_wrist_03":
                    W[b.name] = M_wrist
                elif b.name in left_hand_sub_bones:
                    rel_to_rest_wrist = targets0_norm["L_wrist_03"].inverted() @ targets0_norm[b.name]
                    W[b.name] = M_wrist @ rel_to_rest_wrist
                elif b.name.startswith("R_point"):
                    rot_off = Matrix.Rotation(math.radians(12.0), 4, "Z") @ Matrix.Rotation(math.radians(-6.0), 4, "X")
                    W[b.name] = targets0_norm[b.name] @ rot_off
                else:
                    W[b.name] = targets0_norm[b.name].copy()

            apply_pose_and_keyframe(act_reload_empty, step, W)

        for fc in act_reload_empty.fcurves:
            for kp in fc.keyframe_points:
                kp.interpolation = "LINEAR"

        # =========================================================================
        # CLIP 5: Inspect (2.00 s) — Chamber Presentation with Torso Counter-Rotation
        # =========================================================================
        act_inspect = bpy.data.actions.new("Inspect")
        act_inspect.use_fake_user = True
        donor_arm.animation_data.action = act_inspect
        dur_inspect = CLIPS["Inspect"]
        n_inspect = int(round(dur_inspect * FPS))

        INSPECT_PITCH = 0.16
        INSPECT_YAW = -0.28
        INSPECT_ROLL = 0.42

        # Agarre y pinza en las estrias traseras de corredera:
        # En reposo las estrias se alcanzan con la mano elevada desde W_L_rest.
        # Al retroceder la corredera 39mm (-Y), la mano tira de ella hacia W_L_inspect_hold.
        W_L_inspect_reach = Vector((-0.035, -0.155, -0.015))
        W_L_inspect_hold = Vector((-0.035, -0.194, -0.015))
        rot_wrist_pinch = (
            Matrix.Rotation(math.radians(0.0), 4, "X") @
            Matrix.Rotation(math.radians(-15.0), 4, "Z")
        )

        def get_inspect_left_wrist(t: float) -> tuple[Vector, Matrix]:
            if t <= 0.20:
                # Salida del soporte a dos manos y aproximacion a las estrias traseras
                k = smooth_step(t, 0.0, 0.20)
                pos = W_L_rest.lerp(W_L_inspect_reach, k)
                rot = Matrix.Rotation(math.radians(-15.0 * k), 4, "Z")
                return pos, rot
            elif t <= 0.30:
                # La corredera retrocede 39mm hacia atras: la mano izquierda la desplaza acompanando
                k = smooth_step(t, 0.20, 0.30)
                pos = W_L_inspect_reach.lerp(W_L_inspect_hold, k)
                return pos, rot_wrist_pinch
            elif t <= 1.20:
                # Retencion firme de la corredera abierta para presentar la recamara
                tremor = 0.0003 * math.sin(t * 14.0)
                pos = W_L_inspect_hold + Vector((0.0, tremor, 0.0))
                return pos, rot_wrist_pinch
            elif t <= 1.35:
                # Suelta de corredera (bateria a 1.20s): dedos liberan y la mano se aparta levemente
                k = smooth_step(t, 1.20, 1.35)
                pos = W_L_inspect_hold.lerp(Vector((-0.035, -0.165, -0.025)), k)
                rot = Matrix.Rotation(math.radians(-15.0 * (1.0 - 0.3 * k)), 4, "Z")
                return pos, rot
            else:
                # Regreso fluido al agarre de soporte a dos manos
                k = smooth_step(t, 1.35, 2.00)
                pos = Vector((-0.035, -0.165, -0.025)).lerp(W_L_rest, k)
                rot = Matrix.Rotation(math.radians(-10.5 * (1.0 - k)), 4, "Z")
                return pos, rot

        def get_inspect_finger_pinch(t: float) -> float:
            if t <= 0.20:
                return smooth_step(t, 0.05, 0.20)
            elif t <= 1.20:
                return 1.0
            elif t <= 1.35:
                return 1.0 - smooth_step(t, 1.20, 1.35) * 0.8
            else:
                return 0.2 * (1.0 - smooth_step(t, 1.35, 2.00))

        for step in range(n_inspect + 1):
            t = step / float(FPS)

            # Cadena del brazo derecho: empuñadura firme
            E_R_solved = solve_2bone_ik(S_R_rest, W_R_rest, Pole_R, L1_right, L2_right)
            M_R_upper, M_R_fore = orient_arm_chain(
                S_R_current if "S_R_current" in locals() else S_R_rest,
                E_R_solved, W_R_rest,
                targets0_norm["R_arm_025"], targets0_norm["R_elbow_026"],
                S_R_rest, E_R_rest, W_R_rest
            )

            # Cadena del brazo izquierdo: hombro y codo naturales
            W_L_targ, rot_wrist = get_inspect_left_wrist(t)
            E_L_solved = solve_2bone_ik(S_L_rest, W_L_targ, Pole_L, L1_left, L2_left)
            M_L_upper, M_L_fore = orient_arm_chain(
                S_L_rest, E_L_solved, W_L_targ,
                targets0_norm["L_arm_00"], targets0_norm["L_elbow_01"],
                S_L_rest, E_L_rest, W_L_rest
            )

            diff_wrist = W_L_targ - W_L_rest
            M_L_wrist = Matrix.Translation(diff_wrist) @ targets0_norm["L_wrist_03"] @ rot_wrist

            f_pinch = get_inspect_finger_pinch(t)
            rot_thumb = Matrix.Rotation(math.radians(6.0 * f_pinch), 4, "Z") @ Matrix.Rotation(math.radians(-4.0 * f_pinch), 4, "X")
            rot_point = Matrix.Rotation(math.radians(-10.0 * f_pinch), 4, "Z") @ Matrix.Rotation(math.radians(8.0 * f_pinch), 4, "X")
            rot_middle = Matrix.Rotation(math.radians(-8.0 * f_pinch), 4, "Z") @ Matrix.Rotation(math.radians(10.0 * f_pinch), 4, "X")
            rot_ring = Matrix.Rotation(math.radians(-6.0 * f_pinch), 4, "Z") @ Matrix.Rotation(math.radians(14.0 * f_pinch), 4, "X")
            rot_pink = Matrix.Rotation(math.radians(-4.0 * f_pinch), 4, "Z") @ Matrix.Rotation(math.radians(18.0 * f_pinch), 4, "X")

            W = {}
            for b in order:
                if b.name == "L_arm_00":
                    W[b.name] = M_L_upper
                elif b.name == "L_elbow_01" or b.name == "L_forearm_02":
                    W[b.name] = M_L_fore
                elif b.name == "L_wrist_03":
                    W[b.name] = M_L_wrist
                elif b.name.startswith("L_thumb"):
                    rel_to_rest_wrist = targets0_norm["L_wrist_03"].inverted() @ targets0_norm[b.name]
                    W[b.name] = M_L_wrist @ rel_to_rest_wrist @ rot_thumb
                elif b.name.startswith("L_point"):
                    rel_to_rest_wrist = targets0_norm["L_wrist_03"].inverted() @ targets0_norm[b.name]
                    W[b.name] = M_L_wrist @ rel_to_rest_wrist @ rot_point
                elif b.name.startswith("L_middle"):
                    rel_to_rest_wrist = targets0_norm["L_wrist_03"].inverted() @ targets0_norm[b.name]
                    W[b.name] = M_L_wrist @ rel_to_rest_wrist @ rot_middle
                elif b.name.startswith("L_ring"):
                    rel_to_rest_wrist = targets0_norm["L_wrist_03"].inverted() @ targets0_norm[b.name]
                    W[b.name] = M_L_wrist @ rel_to_rest_wrist @ rot_ring
                elif b.name.startswith("L_pink"):
                    rel_to_rest_wrist = targets0_norm["L_wrist_03"].inverted() @ targets0_norm[b.name]
                    W[b.name] = M_L_wrist @ rel_to_rest_wrist @ rot_pink
                elif b.name in left_hand_sub_bones:
                    rel_to_rest_wrist = targets0_norm["L_wrist_03"].inverted() @ targets0_norm[b.name]
                    W[b.name] = M_L_wrist @ rel_to_rest_wrist
                elif b.name == "R_arm_025":
                    W[b.name] = M_R_upper
                elif b.name == "R_elbow_026" or b.name == "R_forearm_027":
                    W[b.name] = M_R_fore
                elif b.name.startswith("R_point"):
                    rot_off = Matrix.Rotation(math.radians(12.0), 4, "Z") @ Matrix.Rotation(math.radians(-6.0), 4, "X")
                    W[b.name] = targets0_norm[b.name] @ rot_off
                else:
                    W[b.name] = targets0_norm[b.name].copy()

            apply_pose_and_keyframe(act_inspect, step, W)

        for fc in act_inspect.fcurves:
            for kp in fc.keyframe_points:
                kp.interpolation = "LINEAR"

        donor_arm.animation_data.action = act_idle

    donor_arm.name = "ArmsRig"
    donor_arm.data.name = "ArmsRig"
    donor_mesh.name = "Arms_Mesh"

    out_path.parent.mkdir(parents=True, exist_ok=True)
    bpy.context.view_layer.objects.active = donor_arm

    print("Exporting GLB to:", out_path)
    bpy.ops.export_scene.gltf(
        filepath=str(out_path),
        export_format="GLB",
        use_selection=False,
        export_apply=False,
        export_animations=not bind_only,
        export_animation_mode="ACTIONS",
        export_nla_strips=False,
        export_frame_range=False,
        export_force_sampling=True,
        export_frame_step=1,
        export_bake_animation=False,
        export_skins=True,
        export_yup=True,
        export_image_format="AUTO",
        export_optimize_animation_size=False,
        export_anim_single_armature=True,
        export_influence_nb=4,
    )
    print("SUCCESS: exported fps_arms.glb (%.1f KB)" % (out_path.stat().st_size / 1024.0))


def main() -> None:
    argv = sys.argv
    argv = argv[argv.index("--") + 1:] if "--" in argv else []
    parser = argparse.ArgumentParser(description="FLOWFIRE FPS Arms Builder")
    parser.add_argument("--donor", default=str(DONOR), help="Path to donor glTF")
    parser.add_argument("--gun", default=str(GUN), help="Path to reference Glock glb")
    parser.add_argument("--out", default=str(OUT), help="Output GLB path")
    parser.add_argument("--tex", "--max-tex", dest="max_tex", type=int, default=1024, help="Max texture dimension")
    parser.add_argument("--bind-only", action="store_true", help="Export rest bind pose only")
    parser.add_argument("--verify", action="store_true", help="Verify exported GLB")
    parser.add_argument("--verify-only", type=str, default="", help="Verify existing GLB without building")
    args = parser.parse_args(argv)

    if args.verify_only:
        verify(Path(args.verify_only))
        return

    out_path = Path(args.out)
    build_arms(Path(args.donor), Path(args.gun), out_path, args.max_tex, args.bind_only)

    if args.verify:
        verify(out_path)


if __name__ == "__main__":
    main()
