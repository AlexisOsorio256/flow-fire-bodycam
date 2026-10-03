class_name GlockViewmodel
extends Node3D

## Viewmodel: pistola, brazos animados y pose (cadera, ADS, sprint,
## balanceo, respiracion). Representa el estado de Glock; no decide nada.
##   Viewmodel > PoseRoot > BodyGive > WeaponSocket > (Weapon, ArmsRig): las manos
##   van solidarias con el arma, tambien en el retroceso.

const HIP_POS := Vector3(0.170, -0.020, -0.130)
const HIP_ROT := Vector3(deg_to_rad(-2.8), deg_to_rad(3.8), deg_to_rad(-2.0))
const ADS_SIGHT_DISTANCE := 0.44
const PALM_BONE := "L_palm_016"
const RELOAD_POSE_UP := 0.14
const RELOAD_POSE_RIGHT := -0.035
const RELOAD_POSE_FWD := 0.085
const RELOAD_POSE_PITCH := 0.30
const RELOAD_POSE_ROLL := -0.42
const INSPECT_POSE_UP := 0.080
const INSPECT_POSE_RIGHT := -0.045
const INSPECT_POSE_FWD := 0.045
const INSPECT_POSE_PITCH := -0.15
const INSPECT_POSE_YAW := 0.38
const INSPECT_POSE_ROLL := 0.48


const VIEWMODEL_LAYER := 13
const VIEWMODEL_LAYER_BIT := 1 << (VIEWMODEL_LAYER - 1)

const ARMS_PATH := "res://assets/models/fps_arms.glb"
const CLIP_IDLE := "Idle"
const CLIP_FIRE := "Fire"
const CLIP_RELOAD := "Reload"
const CLIP_RELOAD_EMPTY := "ReloadEmpty"
const CLIP_INSPECT := "Inspect"

var camera: Camera3D

var pose_root: Node3D
var body_give: Node3D
var weapon_socket: Node3D

var weapon: GlockWeapon

var arms_rig: Node3D
var arms_player: AnimationPlayer
var mag_in_hand := false
var _hold_primed := false
var _mag_in_hand_offset := Transform3D()
var _clip := ""

var muzzle: Node3D:
	get:
		return weapon.muzzle if weapon != null else null
var ejection_port: Node3D:
	get:
		return weapon.ejection_port if weapon != null else null

var _in_aim := 0.0
var _in_sprint := 0.0
var _in_speed := 0.0
var _in_look := Vector2.ZERO
var _in_move := Vector2.ZERO
var _in_reload_pose := 0.0
var _in_inspect_pose := 0.0
var _in_phase := 0.0

const BOB_SIDE := 0.0100
const BOB_RISE := 0.0150
const BOB_ROLL := 0.0135
const BOB_LAG := 0.30

var idle_phase := 0.0
var sway := Vector2.ZERO
var ads_offset := Vector3(0.0, 0.15, -0.24)
var ads_rot := Vector3.ZERO
var ads_solved := false

var recoil: GlockRecoil  # estado del retroceso; se aplica en update()


func _ready() -> void:
	pose_root = Node3D.new()
	pose_root.name = "PoseRoot"
	add_child(pose_root)
	body_give = Node3D.new()
	body_give.name = "BodyGive"
	pose_root.add_child(body_give)
	weapon_socket = Node3D.new()
	weapon_socket.name = "WeaponSocket"
	body_give.add_child(weapon_socket)


func mount() -> bool:
	weapon = GlockWeapon.new()
	weapon.name = "Weapon"
	weapon_socket.add_child(weapon)
	if not weapon.build():
		push_error("Viewmodel detenido: el GLB canonico de Glock no monta")
		weapon.queue_free()
		weapon = null
		return false
	if not mount_arms():
		return false
	muzzle = weapon.muzzle
	ejection_port = weapon.ejection_port
	_apply_viewmodel_layer(weapon)
	if recoil != null:
		recoil.set_pivot(weapon.grip_pivot())
	return true


func mount_arms() -> bool:
	var packed := load(ARMS_PATH) as PackedScene
	if packed == null:
		push_error("Viewmodel detenido: falta el asset de brazos " + ARMS_PATH)
		return false
	var instance := packed.instantiate() as Node3D
	if instance == null:
		push_error("Viewmodel detenido: " + ARMS_PATH + " no tiene raiz Node3D")
		return false
	var holder := Node3D.new()
	holder.name = "ArmsRig"
	weapon_socket.add_child(holder)
	holder.add_child(instance)
	arms_rig = holder
	pose_root.force_update_transform()
	weapon_socket.force_update_transform()
	weapon.force_update_transform()
	arms_rig.transform = weapon_socket.global_transform.affine_inverse() * weapon.global_transform
	arms_player = _find_player(arms_rig)
	if arms_player == null:
		push_error("Viewmodel detenido: los brazos no traen AnimationPlayer")
		return false
	for name in [CLIP_IDLE, CLIP_FIRE, CLIP_RELOAD, CLIP_RELOAD_EMPTY, CLIP_INSPECT]:
		if _clip_name(name) == "":
			push_error("Los brazos no traen el clip obligatorio " + name)
			return false
	var idle := arms_player.get_animation(_clip_name(CLIP_IDLE))
	if idle != null:
		idle.loop_mode = Animation.LOOP_LINEAR
	arms_player.animation_finished.connect(_on_clip_finished)
	play_clip(CLIP_IDLE, true)
	_apply_viewmodel_layer(arms_rig)
	_matte_arms(arms_rig)
	print("BRAZOS montados: mallas=", _mesh_count(), " clips=", arms_player.get_animation_list(),
		" huesos=", _bone_count())
	return true


func _matte_arms(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i) as BaseMaterial3D
			if src == null:
				continue
			var mat := src.duplicate() as BaseMaterial3D
			mat.metallic = 0.0
			mat.metallic_texture = null
			mat.metallic_specular = 0.35
			mat.rim_enabled = true
			mat.rim = 0.35
			mat.rim_tint = 0.6
			mi.set_surface_override_material(i, mat)


func _clip_name(clip: String) -> String:
	if arms_player == null:
		return ""
	for candidate in arms_player.get_animation_list():
		var text := String(candidate)
		if text == clip or text.ends_with("/" + clip) or text.ends_with("|" + clip) \
				or text.ends_with("_" + clip):
			return text
	return ""


func play_clip(clip: String, restart := false) -> void:
	if arms_player == null:
		return
	var found := _clip_name(clip)
	if found == "":
		push_error("Los brazos no traen el clip " + clip)
		return
	if _clip == found and arms_player.is_playing():
		if not restart:
			return
		arms_player.seek(0.0, true)
		return
	_clip = found
	arms_player.play(found)


func _on_clip_finished(clip: StringName) -> void:
	if String(clip).ends_with(CLIP_FIRE):
		play_clip(CLIP_IDLE, true)


func _mesh_count() -> int:
	var stack: Array = [arms_rig]
	var total := 0
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			total += 1
		for child in node.get_children():
			stack.append(child)
	return total


func _bone_count() -> int:
	var stack: Array = [arms_rig]
	var total := 0
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Skeleton3D:
			total += (node as Skeleton3D).get_bone_count()
		for child in node.get_children():
			stack.append(child)
	return total


func _find_player(root_node: Node) -> AnimationPlayer:
	var stack: Array = [root_node]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is AnimationPlayer:
			return node as AnimationPlayer
		for child in node.get_children():
			stack.append(child)
	return null


func prime_magazine_hold() -> void:
	if weapon == null:
		return
	var palm := _palm_transform()
	if palm == Transform3D():
		push_error("Viewmodel: el esqueleto de los brazos no trae " + PALM_BONE)
		return
	_mag_in_hand_offset = palm.affine_inverse() * weapon.magazine.global_transform
	_hold_primed = true


func set_magazine_in_hand(held: bool) -> void:
	if weapon == null:
		return
	if not held:
		mag_in_hand = false
		weapon.seat_magazine()
		return
	if not _hold_primed:
		prime_magazine_hold()
		if not _hold_primed:
			return
	mag_in_hand = true


func _palm_transform() -> Transform3D:
	var skel := _find_skeleton(arms_rig)
	if skel == null:
		return Transform3D()
	var idx := skel.find_bone(PALM_BONE)
	if idx < 0:
		return Transform3D()
	return skel.global_transform * skel.get_bone_global_pose(idx)


func _find_skeleton(root_node: Node) -> Skeleton3D:
	if root_node == null:
		return null
	for node in root_node.find_children("*", "Skeleton3D", true, false):
		return node as Skeleton3D
	return null


func set_magazine_visible(v: bool) -> void:
	if weapon != null:
		weapon.set_magazine_attached(v)


func _apply_viewmodel_layer(root_node: Node) -> void:
	var stack: Array = [root_node]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is VisualInstance3D:
			(n as VisualInstance3D).layers = VIEWMODEL_LAYER_BIT
		for c in n.get_children():
			stack.append(c)

func set_pose_inputs(aim: float, sprint: float, speed: float, look: Vector2, move: Vector2,
		reload_pose: float, inspect_pose := 0.0, phase := 0.0) -> void:
	_in_aim = aim
	_in_sprint = sprint
	_in_speed = speed
	_in_look = look
	_in_move = move
	_in_reload_pose = reload_pose
	_in_inspect_pose = inspect_pose
	_in_phase = phase


func _apply_pose(delta: float) -> void:
	idle_phase += delta

	var look_x := clampf(_in_look.x, -12.0, 12.0) * 0.0015
	var look_y := clampf(_in_look.y, -12.0, 12.0) * 0.0015
	sway.x += (-look_x - sway.x) * (1.0 - exp(-10.0 * delta))
	sway.y += (-look_y - sway.y) * (1.0 - exp(-10.0 * delta))
	sway.x = clampf(sway.x, -0.012, 0.012)
	sway.y = clampf(sway.y, -0.012, 0.012)

	var hip_pos := HIP_POS
	var ads_pos := ads_offset
	var sprint_pos := Vector3(0.05, -0.135, -0.02)
	var hip_rot := HIP_ROT
	var ads_pose_rot := ads_rot
	var sprint_rot := Vector3(deg_to_rad(-14.0), deg_to_rad(-5.0), deg_to_rad(5.0))

	var carry_pos := hip_pos.lerp(sprint_pos, _in_sprint)
	var carry_rot := hip_rot.lerp(sprint_rot, _in_sprint)
	var pos := carry_pos.lerp(ads_pos, _in_aim)
	var rot := carry_rot.lerp(ads_pose_rot, _in_aim)

	var move_norm := clampf(_in_speed / 4.35, 0.0, 1.0)
	var step := _in_phase - BOB_LAG
	pos.x += cos(step) * BOB_SIDE * move_norm + sway.x * (1.0 - _in_aim * 0.65)
	pos.y += sin(step * 2.0) * BOB_RISE * move_norm + sin(idle_phase * 1.05) * 0.0016 * (1.0 - _in_aim * 0.55) + sway.y * (1.0 - _in_aim * 0.65)
	var move_x := clampf(_in_move.x, -1.0, 1.0)
	var move_y := clampf(_in_move.y, -1.0, 1.0)
	pos.x -= move_x * 0.02 * (1.0 - _in_aim * 0.5)
	pos.y -= absf(move_y) * 0.008 * (1.0 - _in_aim * 0.5)

	rot.x += sway.y * 0.5 - move_y * 0.008
	rot.y += sway.x * 0.5
	rot.z += -move_x * 0.012 + sin(step) * BOB_ROLL * move_norm - sin(step) * 0.012 * _in_sprint

	pos.x = clampf(pos.x, -0.30, 0.30)
	pos.y = clampf(pos.y, -0.30, maxf(0.18, ads_pos.y))
	pos.z = clampf(pos.z, minf(-0.45, ads_pos.z), 0.15)
	var rot_limit := maxf(0.35, absf(ads_pose_rot.x) + 0.015)
	rot.x = clampf(rot.x, -rot_limit, rot_limit)
	rot.y = clampf(rot.y, -0.35, 0.35)
	rot.z = clampf(rot.z, -0.25, 0.25)

	pos.x += _in_reload_pose * RELOAD_POSE_RIGHT
	pos.y += _in_reload_pose * RELOAD_POSE_UP
	pos.z += _in_reload_pose * RELOAD_POSE_FWD
	rot.x += _in_reload_pose * RELOAD_POSE_PITCH
	rot.z += _in_reload_pose * RELOAD_POSE_ROLL
	pos.y += _in_inspect_pose * INSPECT_POSE_UP
	pos.x += _in_inspect_pose * INSPECT_POSE_RIGHT
	pos.z += _in_inspect_pose * INSPECT_POSE_FWD
	rot.x += _in_inspect_pose * INSPECT_POSE_PITCH
	rot.y += _in_inspect_pose * INSPECT_POSE_YAW
	rot.z += _in_inspect_pose * INSPECT_POSE_ROLL
	pose_root.position = pos
	pose_root.rotation = rot


func update(delta: float) -> void:
	_apply_pose(delta)
	if recoil != null:
		recoil.apply(body_give, weapon_socket)
	if mag_in_hand and arms_player != null:
		arms_player.advance(0.0)
		weapon.carry_magazine(_palm_transform(), _mag_in_hand_offset)


func setup(cam: Camera3D) -> void:
	camera = cam
	if weapon != null and not ads_solved:
		solve_ads()


func solve_ads() -> void:
	if weapon == null or weapon.sight_rear == null or weapon.sight_front == null or camera == null:
		return
	(pose_root as Node3D).force_update_transform()
	(self as Node3D).force_update_transform()
	camera.force_update_transform()
	weapon.sight_rear.force_update_transform()
	weapon.sight_front.force_update_transform()
	var glock_inv: Transform3D = (self as Node3D).global_transform.affine_inverse()
	var rear_g: Vector3 = glock_inv * weapon.sight_rear.global_position
	var front_g: Vector3 = glock_inv * weapon.sight_front.global_position
	var eye_g: Vector3 = glock_inv * camera.global_position
	var axis_g: Vector3 = (glock_inv.basis * -camera.global_transform.basis.z).normalized()
	var sight_dir: Vector3 = (front_g - rear_g).normalized()
	var slide_up_g: Vector3 = (glock_inv.basis * weapon.slide.global_transform.basis.y).normalized()
	var rot := Basis.IDENTITY
	var cross := sight_dir.cross(axis_g)
	if cross.length() > 0.00001 and absf(sight_dir.dot(axis_g)) < 0.99999:
		rot = Basis(cross.normalized(), sight_dir.angle_to(axis_g)) * rot
	var up_after: Vector3 = (rot * slide_up_g).normalized()
	var cam_up_g: Vector3 = (glock_inv.basis * camera.global_transform.basis.y).normalized()
	var up_proj: Vector3 = cam_up_g - axis_g * cam_up_g.dot(axis_g)
	if up_proj.length() > 0.001 and up_after.length() > 0.001:
		up_proj = up_proj.normalized()
		var a := atan2(up_after.cross(up_proj).dot(axis_g), up_after.dot(up_proj))
		rot = Basis(axis_g, a) * rot
	var target_rear: Vector3 = eye_g + axis_g * ADS_SIGHT_DISTANCE
	var origin_g: Vector3 = glock_inv * (pose_root as Node3D).global_position
	var rear_rotated: Vector3 = origin_g + (rot * (rear_g - origin_g))
	ads_offset = target_rear - rear_rotated
	ads_rot = rot.get_euler()
	ads_solved = true
	print("ADS offset=", ads_offset.snapped(Vector3(0.001, 0.001, 0.001)),
		" rot_deg=", (ads_rot * 180.0 / PI).snapped(Vector3(0.1, 0.1, 0.1)))
