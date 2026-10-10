class_name FpArms
extends Node3D

const ASSET := "res://assets/models/fps_arms.glb"
const WEAPON_BONE := "Weapon"
const MAG_BONE := "Mag"
const SLIDE_BONE := "Slide"
const CLIP_IDLE := "Idle"
const CLIP_FIRE := "Fire"
const CLIP_RELOAD := "Reload"
const CLIP_RELOAD_EMPTY := "ReloadEmpty"
const CLIP_INSPECT := "Inspect"
const CLIP_EQUIP := "Equip"
const CLIP_AIM := "Aim"
const CLIP_TRIGGER := "Trigger"
const TRIGGER_FINGER := ["f_index.01.R", "f_index.02.R", "f_index.03.R"]
const EVENT_STEP := 1.0 / 120.0
const MOVED := 0.002
const SEATED := 0.001

var prefix := ""
var player: AnimationPlayer
var skeleton: Skeleton3D
var mag_in_hand := false
var timing := {}
var aim_pose: ArmsPoseBlend
var trigger_pose: ArmsPoseBlend

var _weapon: WeaponModel
var _mag_mount: Node3D
var _mag_home: Node
var _slide_bone := -1
var _clips := {}
var _clip := ""


func mount(weapon: WeaponModel) -> bool:
	_weapon = weapon
	var packed := load(ASSET) as PackedScene
	if packed == null:
		push_error("Viewmodel detenido: falta el asset de brazos " + ASSET)
		return false
	var scene := packed.instantiate() as Node3D
	add_child(scene)
	transform = get_parent().global_transform.affine_inverse() * weapon.global_transform
	skeleton = scene.find_children("*", "Skeleton3D", true, false).front() as Skeleton3D
	player = scene.find_children("*", "AnimationPlayer", true, false).front() as AnimationPlayer
	if skeleton == null or player == null:
		push_error("Viewmodel detenido: los brazos no traen esqueleto o AnimationPlayer")
		return false
	if not _bind_clips() or not _hang_on_bones(scene):
		return false
	for clip in [CLIP_RELOAD, CLIP_RELOAD_EMPTY, CLIP_INSPECT, CLIP_EQUIP]:
		timing[clip] = _events(player.get_animation(_clips[clip]))
	player.get_animation(_clips[CLIP_IDLE]).loop_mode = Animation.LOOP_LINEAR
	aim_pose = _pose_layer("AimPose", CLIP_AIM, PackedStringArray())
	trigger_pose = _pose_layer("TriggerPose", CLIP_TRIGGER, PackedStringArray(TRIGGER_FINGER))
	player.animation_finished.connect(_on_clip_finished)
	play_clip(CLIP_IDLE, true)
	_matte(scene)
	return true


func play_clip(clip: String, restart := false) -> void:
	var found: String = _clips[clip]
	if _clip == found and player.is_playing():
		if restart:
			player.seek(0.0, true)
		return
	_clip = found
	player.play(found)


func animated_slide() -> float:
	return skeleton.get_bone_pose_position(_slide_bone).distance_to(skeleton.get_bone_rest(_slide_bone).origin)


func _pose_layer(layer_name: String, clip: String, only: PackedStringArray) -> ArmsPoseBlend:
	var layer := ArmsPoseBlend.new()
	layer.name = layer_name
	layer.influence = 0.0
	skeleton.add_child(layer)
	layer.capture(player.get_animation(_clips[clip]), skeleton, only)
	return layer


func set_magazine_in_hand(held: bool) -> void:
	if held == mag_in_hand:
		return
	mag_in_hand = held
	if held:
		_weapon.magazine.reparent(_mag_mount, false)
		_weapon.magazine.transform = Transform3D.IDENTITY
	else:
		_weapon.magazine.reparent(_mag_home, false)
		_weapon.seat_magazine()


func _hold_pose(scene: Node) -> void:
	if prefix == "":
		return
	player.play(_clips[CLIP_IDLE])
	player.seek(0.0, true)
	var mount := scene.find_child(prefix + "Mount", true, false) as Node3D
	var bone := skeleton.find_bone(WEAPON_BONE)
	var offset := mount.transform if mount.get_parent() is BoneAttachment3D else Transform3D.IDENTITY
	_weapon.global_transform = skeleton.global_transform * skeleton.get_bone_global_pose(bone) * offset


func _bone_frame(bone: int) -> Transform3D:
	return skeleton.get_bone_global_rest(bone) if prefix == "" else skeleton.get_bone_global_pose(bone)


func _hang_on_bones(scene: Node) -> bool:
	for bone in [WEAPON_BONE, MAG_BONE, SLIDE_BONE]:
		if skeleton.find_bone(bone) < 0:
			push_error("Los brazos no traen el hueso " + bone)
			return false
	_slide_bone = skeleton.find_bone(SLIDE_BONE)
	_hold_pose(scene)
	var mounts := {}
	for bone in [WEAPON_BONE, MAG_BONE]:
		var att := BoneAttachment3D.new()
		att.name = bone
		att.bone_name = bone
		skeleton.add_child(att)
		var rest := skeleton.global_transform * _bone_frame(skeleton.find_bone(bone))
		var anchor := Node3D.new()
		anchor.name = bone + "Mount"
		att.add_child(anchor)
		var piece: Node3D = _weapon if bone == WEAPON_BONE else _weapon.magazine
		anchor.transform = rest.affine_inverse() * piece.global_transform
		mounts[bone] = anchor
	_weapon.reparent(mounts[WEAPON_BONE], true)
	_mag_mount = mounts[MAG_BONE]
	_mag_home = _weapon.magazine.get_parent()
	return true


func _bind_clips() -> bool:
	for clip in [CLIP_IDLE, CLIP_FIRE, CLIP_RELOAD, CLIP_RELOAD_EMPTY, CLIP_INSPECT, CLIP_EQUIP, CLIP_AIM, CLIP_TRIGGER]:
		var text := Clips.find(player, prefix + clip)
		if text != "":
			_clips[clip] = text
		if not _clips.has(clip):
			push_error("Los brazos no traen el clip obligatorio " + clip)
			return false
	return true


func _events(anim: Animation) -> Dictionary:
	var events := {"length": anim.length}
	var slide := _travel(anim, SLIDE_BONE)
	var peak: float = slide.max() if not slide.is_empty() else 0.0
	if peak > MOVED:
		var back := _first(slide, 0, func(d: float) -> bool: return d >= peak * 0.97)
		events["slide_back"] = back * EVENT_STEP
		events["slide_home"] = maxi(0, _first(slide, back, func(d: float) -> bool: return d <= peak * 0.03)) * EVENT_STEP
	var mag := _travel(anim, MAG_BONE)
	var out := _first(mag, 0, func(d: float) -> bool: return d > MOVED)
	if out >= 0:
		var far := mag.find(mag.max())
		events["mag_out"] = out * EVENT_STEP
		events["mag_seat"] = maxi(0, _first(mag, far, func(d: float) -> bool: return d <= SEATED)) * EVENT_STEP
	return events


func _travel(anim: Animation, bone: String) -> Array:
	var travel := []
	for i in anim.get_track_count():
		if anim.track_get_type(i) != Animation.TYPE_POSITION_3D or not String(anim.track_get_path(i)).ends_with(":" + bone):
			continue
		var rest := skeleton.get_bone_rest(skeleton.find_bone(bone)).origin if prefix == "" \
			else anim.position_track_interpolate(i, 0.0)
		for step in int(anim.length / EVENT_STEP) + 1:
			travel.append(anim.position_track_interpolate(i, step * EVENT_STEP).distance_to(rest))
	return travel


func _first(values: Array, from: int, test: Callable) -> int:
	for i in range(maxi(from, 0), values.size()):
		if test.call(values[i]):
			return i
	return -1


func _on_clip_finished(clip: StringName) -> void:
	if String(clip) == _clips[CLIP_FIRE]:
		play_clip(CLIP_IDLE, true)


func _matte(root: Node) -> void:
	Nodes.each(root, func(node: Node) -> void:
		if not node is MeshInstance3D or _weapon.is_ancestor_of(node):
			return
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i) as BaseMaterial3D
			if src == null:
				continue
			var mat := src.duplicate() as BaseMaterial3D
			mat.metallic = 0.0
			mat.metallic_texture = null
			mat.metallic_specular = 0.3
			mat.rim_enabled = true
			mat.rim = 0.06
			mat.rim_tint = 0.6
			mi.set_surface_override_material(i, mat))
