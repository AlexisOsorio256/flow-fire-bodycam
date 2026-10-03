class_name HitReact
extends SkeletonModifier3D

const K := 150.0
const C := 15.0
const LIMIT := 0.85
const FALLOFF := 0.55

var _bones := PackedInt32Array()
var _rot := {}
var _vel := {}
var _awake := false


func setup(names: Array) -> void:
	var skel := get_skeleton()
	for n in names:
		var i := skel.find_bone(n)
		if i >= 0:
			_bones.append(i)
			_rot[i] = Vector3.ZERO
			_vel[i] = Vector3.ZERO
	_bones.sort()


func kick(bone_name: String, at: Vector3, dir: Vector3, strength: float) -> void:
	var skel := get_skeleton()
	var xf := skel.global_transform
	var to_skel := xf.basis.orthonormalized().inverse()
	var d := dir.normalized()
	var i := skel.find_bone(bone_name)
	var share := 1.0
	while i >= 0 and share > 0.05:
		if _rot.has(i):
			var o := xf * skel.get_bone_global_pose(i).origin
			var torque := (at - o).cross(d)
			_vel[i] += (to_skel * torque).limit_length(0.5) * strength * share
			share *= FALLOFF
		i = skel.get_bone_parent(i)
	_awake = true


func _process_modification_with_delta(delta: float) -> void:
	if not _awake:
		return
	var skel := get_skeleton()
	var energy := 0.0
	for i in _bones:
		var pair := Springs.vector(_rot[i], _vel[i], K, C, delta)
		var r: Vector3 = pair[0].limit_length(LIMIT)
		_rot[i] = r
		_vel[i] = pair[1]
		energy += r.length_squared() + (pair[1] as Vector3).length_squared() * 0.01
		var angle := r.length()
		if angle < 0.0005:
			continue
		var pose := skel.get_bone_global_pose(i)
		pose.basis = Basis(r / angle, angle) * pose.basis
		skel.set_bone_global_pose(i, pose)
	_awake = energy > 0.000001
