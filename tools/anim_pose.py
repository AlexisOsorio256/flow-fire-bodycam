import math
from pathlib import Path

import bpy
from mathutils import Euler, Quaternion, Vector

ROOT = Path(__file__).resolve().parent.parent


def _rig() -> bpy.types.Object:
    return next(o for o in bpy.data.objects if o.type == "ARMATURE")


def _action(name: str) -> bpy.types.Action:
    act = bpy.data.actions.get(name)
    if act is None:
        raise KeyError("no existe la accion " + name)
    return act


def _hold(action: str):
    rig = _rig()
    previous = rig.animation_data.action if rig.animation_data else None
    rig.animation_data.action = _action(action)
    bpy.context.view_layer.update()
    return rig, previous


def _spread(frames) -> list:
    return [frames] if isinstance(frames, int) else list(frames)


def _at(act, bone: str, kind: str, frame: int):
    curves = [fc for fc in act.fcurves if fc.data_path == 'pose.bones["%s"].%s' % (bone, kind)]
    if not curves:
        return None
    return sorted(curves, key=lambda c: c.array_index) and [c.evaluate(frame) for c in
                                                            sorted(curves, key=lambda c: c.array_index)]


def _key(rig, bone: str, frame: int, location, rotation) -> None:
    pb = rig.pose.bones[bone]
    if location is not None:
        pb.location = Vector(location)
        pb.keyframe_insert(data_path="location", frame=frame)
    if rotation is not None:
        pb.rotation_quaternion = Quaternion(rotation)
        pb.keyframe_insert(data_path="rotation_quaternion", frame=frame)


def bend(action: str, bone: str, frames, euler_deg, meters=None) -> int:
    """Gira un hueso (grados, ejes del hueso) y opcionalmente lo desplaza (m)."""
    rig, previous = _hold(action)
    act = rig.animation_data.action
    first = int(act.frame_range[0])
    moved = 0
    try:
        for frame in _spread(frames):
            rot = _at(act, bone, "rotation_quaternion", frame)
            if rot is None:
                rot = list(rig.pose.bones[bone].rotation_quaternion)
            loc = _at(act, bone, "location", frame)
            if meters is not None and loc is None:
                loc = list(rig.pose.bones[bone].location)
            want = Quaternion(rot) @ Euler([math.radians(a) for a in euler_deg], "XYZ").to_quaternion()
            _key(rig, bone, frame, None if meters is None else [loc[i] + meters[i] for i in range(3)],
                 list(want))
            moved += 1
    finally:
        rig.animation_data.action = previous
    return moved


def nudge(action: str, bone: str, frames, meters) -> int:
    """Desplaza un hueso (m, ejes locales) dejando su rotacion como esta."""
    rig, previous = _hold(action)
    act = rig.animation_data.action
    moved = 0
    try:
        for frame in _spread(frames):
            loc = _at(act, bone, "location", frame)
            if loc is None:
                loc = list(rig.pose.bones[bone].location)
            rot = _at(act, bone, "rotation_quaternion", frame)
            _key(rig, bone, frame, [loc[i] + meters[i] for i in range(3)], rot)
            moved += 1
    finally:
        rig.animation_data.action = previous
    return moved


def fingers(action: str, frames, degrees) -> int:
    """Gira los dedos de una mano: {hueso: grados} en esos fotogramas."""
    moved = 0
    for bone, amount in degrees.items():
        moved += bend(action, bone, frames, amount)
    return moved


def mirror(target: str, bone: str, frames, source: str, source_frames, scale: float = 1.0) -> int:
    """Copia a target el giro local que source tiene en source_frames (respecto a su frame 1)."""
    rig = _rig()
    src = _action(source)
    dst = _action(target)
    first = int(src.frame_range[0])
    base = _at(src, bone, "rotation_quaternion", first)
    if base is None:
        return 0
    base = Quaternion(base)
    moved = 0
    try:
        rig.animation_data.action = dst
        for frame, src_frame in zip(_spread(frames), _spread(source_frames)):
            value = _at(src, bone, "rotation_quaternion", src_frame)
            if value is None:
                continue
            delta = (Quaternion(value) @ base.inverted()).slerp(Quaternion(), 1.0 - scale) if scale < 1.0 \
                else Quaternion(value) @ base.inverted()
            here = _at(dst, bone, "rotation_quaternion", frame)
            if here is None:
                bpy.context.scene.frame_set(frame)
                bpy.context.view_layer.update()
                here = list(rig.pose.bones[bone].rotation_quaternion)
            _key(rig, bone, frame, None, list(Quaternion(here) @ delta))
            moved += 1
    finally:
        rig.animation_data.action = None
    return moved


def travel(action: str, bone: str, step: int = 1) -> list:
    """Recorrido del hueso a lo largo de la accion, para medirlo."""
    act = _action(action)
    rows = []
    for frame in range(int(act.frame_range[0]), int(act.frame_range[1]) + 1, step):
        rows.append([frame, _at(act, bone, "location", frame),
                     _at(act, bone, "rotation_quaternion", frame)])
    return rows
