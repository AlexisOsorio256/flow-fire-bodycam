class_name ArmsPoseBlend
extends SkeletonModifier3D

var _bones := PackedInt32Array()
var _positions := PackedVector3Array()
var _rotations: Array[Quaternion] = []


func capture(anim: Animation, skeleton: Skeleton3D, only := PackedStringArray()) -> void:
	for track in anim.get_track_count():
		var bone_name := String(anim.track_get_path(track).get_concatenated_subnames())
		var bone := skeleton.find_bone(bone_name)
		if bone < 0 or (not only.is_empty() and not only.has(bone_name)):
			continue
		var at := _bones.find(bone)
		if at < 0:
			_bones.append(bone)
			_positions.append(skeleton.get_bone_pose_position(bone))
			_rotations.append(skeleton.get_bone_pose_rotation(bone))
			at = _bones.size() - 1
		match anim.track_get_type(track):
			Animation.TYPE_POSITION_3D:
				_positions[at] = anim.position_track_interpolate(track, 0.0)
			Animation.TYPE_ROTATION_3D:
				_rotations[at] = anim.rotation_track_interpolate(track, 0.0)


func _process_modification() -> void:
	var skeleton := get_skeleton()
	for i in _bones.size():
		skeleton.set_bone_pose_position(_bones[i], _positions[i])
		skeleton.set_bone_pose_rotation(_bones[i], _rotations[i])
