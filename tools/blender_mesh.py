from collections import Counter

import bpy
import numpy as np


def _rig_of(ob: bpy.types.Object) -> bpy.types.Object:
    return next(m.object for m in ob.modifiers if m.type == "ARMATURE")


def islands(mesh: str = "Arms_Mesh") -> list:
    ob = bpy.data.objects[mesh]
    me = ob.data
    parent = np.arange(len(me.vertices))

    def root(i: int) -> int:
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    for e in me.edges:
        a, b = root(e.vertices[0]), root(e.vertices[1])
        if a != b:
            parent[a] = b
    groups = {}
    for v in me.vertices:
        groups.setdefault(root(v.index), []).append(v.index)
    names = {g.index: g.name for g in ob.vertex_groups}
    found = []
    for verts in sorted(groups.values(), key=len, reverse=True):
        weight = Counter()
        for i in verts:
            for g in me.vertices[i].groups:
                weight[names[g.group]] += g.weight
        found.append({"island": len(found), "verts": verts, "bone": weight.most_common(1)[0][0] if weight else "-"})
    return found


def _areas(ob: bpy.types.Object) -> np.ndarray:
    ev = ob.evaluated_get(bpy.context.evaluated_depsgraph_get())
    me = ev.to_mesh()
    out = np.empty(len(me.polygons), dtype=np.float32)
    me.polygons.foreach_get("area", out)
    ev.to_mesh_clear()
    return out


def stretch(mesh: str = "Arms_Mesh", clips: list | None = None, top: int = 5) -> dict:
    ob = bpy.data.objects[mesh]
    rig = _rig_of(ob)
    scn = bpy.context.scene
    keep_action, keep_frame = rig.animation_data.action, scn.frame_current
    rig.data.pose_position = "REST"
    bpy.context.view_layer.update()
    rest = np.maximum(_areas(ob), 1e-12)
    rig.data.pose_position = "POSE"
    island_of = np.empty(len(ob.data.vertices), dtype=np.int32)
    found = islands(mesh)
    for isl in found:
        island_of[isl["verts"]] = isl["island"]
    poly_island = np.array([island_of[p.vertices[0]] for p in ob.data.polygons])
    report = {}
    for clip in clips or [a.name for a in bpy.data.actions]:
        act = bpy.data.actions[clip]
        rig.animation_data.action = act
        worst = {}
        for f in range(int(act.frame_range[0]), int(act.frame_range[1]) + 1):
            scn.frame_set(f)
            ratio = _areas(ob) / rest
            for isl in np.unique(poly_island):
                r = float(ratio[poly_island == isl].max())
                if r > worst.get(isl, (0.0, 0))[0]:
                    worst[isl] = (r, f)
        rows = sorted(worst.items(), key=lambda kv: -kv[1][0])[:top]
        report[clip] = [{"island": int(i), "bone": found[i]["bone"], "ratio": round(r, 2), "frame": f}
                        for i, (r, f) in rows]
    rig.animation_data.action = keep_action
    scn.frame_set(keep_frame)
    return report


def paint(mesh: str = "Arms_Mesh", marked: list | None = None) -> str:
    ob = bpy.data.objects[mesh]
    me = ob.data
    if marked == [] and me.color_attributes.get("islands"):
        me.color_attributes.remove(me.color_attributes["islands"])
        return ""
    attr = me.color_attributes.get("islands") or me.color_attributes.new("islands", "FLOAT_COLOR", "POINT")
    colors = np.tile(np.array([0.5, 0.5, 0.5, 1.0], dtype=np.float32), (len(me.vertices), 1))
    found = islands(mesh)
    for n, i in enumerate(marked if marked is not None else range(min(8, len(found)))):
        hue = n / max(1, len(marked or found[:8]))
        colors[found[i]["verts"], :3] = [abs(hue * 6 - 3) - 1, 2 - abs(hue * 6 - 2), 2 - abs(hue * 6 - 4)]
    attr.data.foreach_set("color", np.clip(colors, 0, 1).ravel())
    me.color_attributes.active_color = attr
    me.color_attributes.render_color_index = me.color_attributes.active_color_index
    return attr.name
