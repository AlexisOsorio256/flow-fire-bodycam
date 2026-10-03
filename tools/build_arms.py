#!/usr/bin/env python3
"""blender -b --python tools/build_arms.py -- [--out ruta] [--preview carpeta]"""

from __future__ import annotations

import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

REPO = Path(__file__).resolve().parent.parent
SRC = REPO / "assets" / "models" / "fps_arms.glb"
FABRIC = REPO / "assets" / "textures" / "enemy"
SIDES = 12
FINGERS = ("thumb", "point", "middle", "ring", "pink")
RADIUS = {"thumb": (0.0112, 0.0090), "point": (0.0084, 0.0066), "middle": (0.0088, 0.0068),
          "ring": (0.0081, 0.0063), "pink": (0.0074, 0.0057)}
SLEEVE = ((0.0, 0.052), (0.25, 0.049), (0.5, 0.045), (0.78, 0.040), (0.96, 0.037), (1.0, 0.040))
FOREARM = ((0.0, 0.044), (0.35, 0.040), (0.8, 0.034), (0.93, 0.033), (1.0, 0.037))
SMOOTH = 1


def bone(arm, side: str, key: str):
    return next(b for b in arm.data.bones if b.name.startswith("%s_%s_" % (side, key)))


def bone_chain(arm, side: str, finger: str) -> list[Vector]:
    names = [b.name for b in arm.data.bones if b.name.startswith("%s_%s" % (side, finger))]
    names.sort(key=lambda n: int("".join(c for c in n.split("_")[1] if c.isdigit()) or 0))
    pts = [arm.data.bones[n].head_local.copy() for n in names]
    pts.append(arm.data.bones[names[-1]].tail_local.copy())
    return pts


def frame_along(points: list[Vector]) -> list[Matrix]:
    frames = []
    ref = Vector((0.0, 0.0, 1.0))
    prev_n = None
    for i, p in enumerate(points):
        if i == 0:
            t = points[1] - p
        elif i == len(points) - 1:
            t = p - points[i - 1]
        else:
            t = points[i + 1] - points[i - 1]
        t.normalize()
        n = prev_n if prev_n is not None else ref - t * ref.dot(t)
        if prev_n is not None:
            n = prev_n - t * prev_n.dot(t)
        if n.length < 1e-4:
            n = Vector((1.0, 0.0, 0.0)) - t * t.x
        n.normalize()
        prev_n = n
        frames.append((t, n, t.cross(n)))
    return frames


def tube(bm, points, radii, squash=1.0, tip="round"):
    frames = frame_along(points)
    rings = []
    for p, r, (t, n, b) in zip(points, radii, frames):
        ring = []
        for k in range(SIDES):
            a = math.tau * k / SIDES
            ring.append(bm.verts.new(p + (n * math.cos(a) + b * math.sin(a) * squash) * r))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(SIDES):
            bm.faces.new((rings[i][k], rings[i][(k + 1) % SIDES], rings[i + 1][(k + 1) % SIDES], rings[i + 1][k]))
    for ring, end, sign in ((rings[0], points[0], -1.0), (rings[-1], points[-1], 1.0)):
        t = frames[0][0] if sign < 0 else frames[-1][0]
        r = radii[0] if sign < 0 else radii[-1]
        tipv = bm.verts.new(end + t * sign * r * (0.55 if tip == "round" else 0.0))
        for k in range(SIDES):
            a, b = ring[k], ring[(k + 1) % SIDES]
            bm.faces.new((a, b, tipv) if sign > 0 else (b, a, tipv))
    return rings


def refine(points, radii, joints: int):
    out_p, out_r = [], []
    for i in range(len(points) - 1):
        for k in range(joints):
            t = k / joints
            out_p.append(points[i].lerp(points[i + 1], t))
            out_r.append((radii[i] + (radii[i + 1] - radii[i]) * t) * (1.0 + 0.09 * math.cos(t * math.tau)))
    out_p.append(points[-1])
    out_r.append(radii[-1])
    return out_p, out_r


def lerp_curve(curve, t):
    for (t0, v0), (t1, v1) in zip(curve, curve[1:]):
        if t <= t1:
            return v0 + (v1 - v0) * (t - t0) / max(t1 - t0, 1e-6)
    return curve[-1][1]


def limb(bm, a: Vector, b: Vector, curve, segments: int, folds: float = 0.0, seed: int = 0):
    pts = [a.lerp(b, i / segments) for i in range(segments + 1)]
    rng = random.Random(seed)
    phase = rng.uniform(0.0, 6.0)
    radii = []
    for i in range(segments + 1):
        t = i / segments
        edge = min(t, 1.0 - t)
        wave = math.sin(t * 17.0 + phase) * 0.6 + math.sin(t * 41.0 + phase * 2.0) * 0.4
        radii.append(lerp_curve(curve, t) * (1.0 + folds * wave * min(1.0, edge * 6.0)))
    tube(bm, pts, radii, squash=0.92)


def hand(bm, gear, arm, side: str) -> None:
    wrist = bone(arm, side, "wrist").head_local.copy()
    index_base = bone(arm, side, "point1").head_local.copy()
    pink_base = bone(arm, side, "pink1").head_local.copy()
    middle_base = bone(arm, side, "middle1").head_local.copy()
    knuckle = (index_base + pink_base) * 0.5
    along = (middle_base - wrist)
    length = along.length
    across = (index_base - pink_base)
    width = across.length * 1.18
    up = along.cross(across).normalized()
    center = wrist.lerp(middle_base, 0.55)
    sx = across.normalized()
    sy = along.normalized()
    sz = up
    mat = Matrix(((sx.x, sy.x, sz.x, center.x), (sx.y, sy.y, sz.y, center.y), (sx.z, sy.z, sz.z, center.z), (0, 0, 0, 1)))
    bmesh.ops.create_uvsphere(bm, u_segments=SIDES, v_segments=10, radius=1.0,
                              matrix=mat @ Matrix.Diagonal((width * 0.5, length * 0.6, 0.0145, 1.0)))
    for finger in FINGERS:
        pts = bone_chain(arm, side, finger)
        if finger != "thumb":
            pts = [pts[0].lerp(wrist, 0.0)] + pts[1:]
        r0, r1 = RADIUS[finger]
        radii = [r0 + (r1 - r0) * i / (len(pts) - 1) for i in range(len(pts))]
        radii[-1] *= 1.12
        pts, radii = refine(pts, radii, 3)
        tube(bm, pts, radii, squash=0.78)
    back = Vector()
    for finger in ("point", "middle", "ring", "pink"):
        chain = bone_chain(arm, side, finger)
        chord = (chain[0] + chain[-1]) * 0.5
        back += (chain[2] - chord)
    if back.dot(up) < 0.0:
        up = -up
    plate_center = (index_base + pink_base) * 0.5 + along.normalized() * 0.006 + up * 0.014
    plate_basis = Matrix(((sx.x, sy.x, up.x, plate_center.x), (sx.y, sy.y, up.y, plate_center.y),
                          (sx.z, sy.z, up.z, plate_center.z), (0, 0, 0, 1)))
    bmesh.ops.create_uvsphere(gear, u_segments=14, v_segments=8, radius=1.0,
                              matrix=plate_basis @ Matrix.Diagonal((width * 0.46, 0.020, 0.0055, 1.0)))
    for k in range(4):
        base = bone(arm, side, ("point", "middle", "ring", "pink")[k] + "1").head_local.copy()
        bmesh.ops.create_uvsphere(gear, u_segments=10, v_segments=6, radius=1.0,
                                  matrix=Matrix.Translation(base + up * 0.0125 + along.normalized() * 0.018) @ Matrix.Diagonal((0.0075, 0.010, 0.0042, 1.0)))
    for finger in ("point", "middle", "ring", "pink", "thumb"):
        chain = bone_chain(arm, side, finger)
        seam = [pt + up * 0.0058 for pt in chain]
        tube(gear, seam, [0.0016] * len(seam), squash=1.0, tip="flat")
    thenar = bone(arm, side, "thumb1").head_local.lerp(wrist, 0.35)
    bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=1.0,
                              matrix=Matrix.Translation(thenar) @ Matrix.Diagonal((0.017, 0.017, 0.012, 1.0)))


def fold_displace(obj) -> None:
    me = obj.data
    me.calc_normals_split() if hasattr(me, "calc_normals_split") else None
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.normal_update()
    tex = bpy.data.textures.new("folds", "CLOUDS")
    tex.noise_scale = 0.018
    tex.noise_depth = 3
    for v in bm.verts:
        n = tex.evaluate(v.co * 1.0)[0] - 0.5
        ridge = abs(math.sin(v.co.dot(Vector((9.0, 23.0, 14.0))) * 4.0 + n * 6.0))
        v.co += v.normal * (n * 0.0035 + (ridge - 0.5) * 0.0012)
    bm.to_mesh(me)
    bm.free()
    me.update()


def smart_uv(obj) -> None:
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.004)
    bpy.ops.object.mode_set(mode="OBJECT")


def tinted_image(source: str, factor, name: str) -> bpy.types.Image:
    import numpy as np
    src = bpy.data.images.load(str(FABRIC / source))
    w, h = src.size
    px = np.empty(w * h * 4, dtype=np.float32)
    src.pixels.foreach_get(px)
    px = px.reshape(-1, 4)
    lum = px[:, :3].mean(axis=1, keepdims=True)
    px[:, :3] = (0.55 * px[:, :3] + 0.45 * lum) * np.array(factor, dtype=np.float32)
    rng = np.random.default_rng(abs(hash(name)) % (2 ** 32))
    coarse = rng.random((9, 9)).astype(np.float32)
    fine = rng.random((33, 33)).astype(np.float32)
    ys = np.linspace(0.0, 8.0, h, dtype=np.float32)
    xs = np.linspace(0.0, 8.0, w, dtype=np.float32)
    def sample(grid, scale):
        gy = np.clip((np.linspace(0.0, grid.shape[0] - 1.001, h)), 0, grid.shape[0] - 1.001)
        gx = np.clip((np.linspace(0.0, grid.shape[1] - 1.001, w)), 0, grid.shape[1] - 1.001)
        y0 = gy.astype(int); x0 = gx.astype(int)
        fy = (gy - y0)[:, None]; fx = (gx - x0)[None, :]
        a = grid[y0][:, x0]; b = grid[y0][:, x0 + 1]; c = grid[y0 + 1][:, x0]; d = grid[y0 + 1][:, x0 + 1]
        return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy
    wear = 0.78 + 0.5 * (0.65 * sample(coarse, 1) + 0.35 * sample(fine, 1))
    px[:, :3] *= wear.reshape(-1, 1)
    out = bpy.data.images.new(name, w, h)
    out.pixels.foreach_set(px.reshape(-1))
    out.pack()
    return out


def fabric_material(name: str, color, roughness: float) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = tinted_image("fabric_diff.jpg", color, name + "_albedo")
    mapping = nt.nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (5.0, 5.0, 5.0)
    uv = nt.nodes.new("ShaderNodeTexCoord")
    nt.links.new(uv.outputs["UV"], mapping.inputs["Vector"])
    nt.links.new(mapping.outputs["Vector"], tex.inputs["Vector"])
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = 0.0
    return mat


def segments_of(arm, side: str):
    segs = []
    for b in arm.data.bones:
        if not b.name.startswith(side + "_") or b.name in ("Weapon", "Mag"):
            continue
        if b.name.startswith(side + "_forearm"):
            continue
        segs.append((b.name, b.head_local.copy(), b.tail_local.copy()))
    return segs


def seg_dist(p: Vector, h: Vector, t: Vector) -> float:
    d = t - h
    if d.length_squared < 1e-12:
        return (p - h).length
    u = max(0.0, min(1.0, (p - h).dot(d) / d.length_squared))
    return (p - (h + d * u)).length


def skin_weights(obj, arm, side: str, verts) -> None:
    segs = segments_of(arm, side)
    groups = {n: obj.vertex_groups.get(n) or obj.vertex_groups.new(name=n) for n, _, _ in segs}
    for v in verts:
        ds = sorted(((seg_dist(v.co, h, t), n) for n, h, t in segs))[:3]
        inv = [1.0 / (d + 0.004) ** 3 for d, _ in ds]
        total = sum(inv)
        for (d, n), w in zip(ds, inv):
            groups[n].add([v.index], w / total, "REPLACE")


def build(out: Path, preview: Path | None) -> None:
    for coll in (bpy.data.objects, bpy.data.meshes, bpy.data.armatures, bpy.data.actions,
                 bpy.data.cameras, bpy.data.materials, bpy.data.images):
        for item in list(coll):
            coll.remove(item)
    bpy.ops.import_scene.gltf(filepath=str(SRC))
    scn = bpy.context.scene
    arm = next(o for o in scn.objects if o.type == "ARMATURE")
    for o in list(scn.objects):
        if o.type == "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    for img in list(bpy.data.images):
        if not img.users:
            bpy.data.images.remove(img)
    for mat in list(bpy.data.materials):
        bpy.data.materials.remove(mat)
    arm.data.pose_position = "REST"
    parts = {}
    sleeve_mat = fabric_material("arms", (0.17, 0.175, 0.185), 0.9)
    gear_mat = fabric_material("gear", (0.15, 0.155, 0.165), 0.5)
    glove_mat = fabric_material("glove", (0.24, 0.245, 0.26), 0.58)
    for side in ("L", "R"):
        bm = bmesh.new()
        shoulder = bone(arm, side, "arm").head_local.copy()
        elbow = bone(arm, side, "elbow").head_local.copy()
        wrist = bone(arm, side, "wrist").head_local.copy()
        limb(bm, shoulder - (elbow - shoulder).normalized() * 0.02, elbow, SLEEVE, 18, 0.045, 1 if side == "L" else 2)
        limb(bm, elbow, wrist + (wrist - elbow).normalized() * 0.012, FOREARM, 18, 0.05, 3 if side == "L" else 4)
        hbm = bmesh.new()
        gbm = bmesh.new()
        hand(hbm, gbm, arm, side)
        strap_dir = (wrist - elbow).normalized()
        tube(gbm, [wrist - strap_dir * 0.050, wrist - strap_dir * 0.042, wrist - strap_dir * 0.022, wrist - strap_dir * 0.014],
             [0.0335, 0.0368, 0.0368, 0.0335], squash=0.92, tip="flat")
        for tag, source in (("sleeve", bm), ("glove", hbm), ("gear", gbm)):
            me = bpy.data.meshes.new("Arms_%s_%s" % (tag, side))
            source.to_mesh(me)
            source.free()
            obj = bpy.data.objects.new("Arms_%s_%s" % (tag, side), me)
            scn.collection.objects.link(obj)
            obj.data.materials.append({"sleeve": sleeve_mat, "glove": glove_mat, "gear": gear_mat}[tag])
            parts[(tag, side)] = obj
    for key, obj in parts.items():
        skin_weights(obj, arm, key[1], obj.data.vertices)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in parts.values():
        obj.select_set(True)
    bpy.context.view_layer.objects.active = parts[("sleeve", "L")]
    bpy.ops.object.join()
    mesh = bpy.context.view_layer.objects.active
    mesh.name = "Arms_Mesh"
    mesh.data.name = "Arms_Mesh"
    mod = mesh.modifiers.new("Subsurf", "SUBSURF")
    mod.levels = SMOOTH
    mod.render_levels = SMOOTH
    with bpy.context.temp_override(object=mesh, active_object=mesh):
        bpy.ops.object.modifier_apply(modifier=mod.name)
    fold_displace(mesh)
    for poly in mesh.data.polygons:
        poly.use_smooth = True
    smart_uv(mesh)
    mesh.parent = arm
    arm_mod = mesh.modifiers.new("Armature", "ARMATURE")
    arm_mod.object = arm
    arm.data.pose_position = "POSE"
    tris = sum(len(p.vertices) - 2 for p in mesh.data.polygons)
    print("brazos: %d vertices, %d triangulos" % (len(mesh.data.vertices), tris))
    if preview:
        render_preview(arm, preview)
    for a in list(bpy.data.actions):
        a.use_fake_user = True
    bpy.ops.export_scene.gltf(filepath=str(out), export_format="GLB", export_animations=True,
                              export_animation_mode="ACTIONS", export_force_sampling=True,
                              export_skins=True, export_yup=True, export_image_format="AUTO",
                              export_anim_single_armature=True)
    print("SUCCESS", out)


def render_preview(arm, folder: Path) -> None:
    folder.mkdir(parents=True, exist_ok=True)
    scn = bpy.context.scene
    scn.render.engine = "BLENDER_WORKBENCH"
    scn.display.shading.light = "STUDIO"
    scn.display.shading.color_type = "MATERIAL"
    scn.render.resolution_x = 900
    scn.render.resolution_y = 600
    cam = bpy.data.objects.new("PrevCam", bpy.data.cameras.new("PrevCam"))
    scn.collection.objects.link(cam)
    scn.camera = cam
    cam.data.clip_start = 0.01
    for name, loc, target in (("lado", (0.9, -0.3, 0.1), (0.0, -0.3, 0.0)),
                              ("mano", (0.35, 0.25, 0.2), (0.0, -0.05, -0.05)),
                              ("frente", (0.05, 0.9, 0.1), (0.0, -0.3, 0.0))):
        cam.location = loc
        cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        scn.render.filepath = str(folder / (name + ".png"))
        bpy.ops.render.render(write_still=True)


def main() -> None:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = Path(argv[argv.index("--out") + 1]) if "--out" in argv else SRC
    preview = Path(argv[argv.index("--preview") + 1]) if "--preview" in argv else None
    build(out, preview)


if __name__ == "__main__":
    main()
