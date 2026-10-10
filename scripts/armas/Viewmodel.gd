class_name Viewmodel
extends Node3D

const VIEWMODEL_LAYER := 13
const VIEWMODEL_LAYER_BIT := 1 << (VIEWMODEL_LAYER - 1)


var camera: Camera3D

var pose_root: Node3D
var body_give: Node3D
var weapon_socket: Node3D

var weapon: WeaponModel

var arms: FpArms

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
var _in_phase := 0.0
var _in_vertical := 0.0
var _air := 0.0

const BOB_SIDE := 0.0100
const BOB_RISE := 0.0150
const BOB_ROLL := 0.0135
const BOB_LAG := 0.30

var idle_phase := 0.0
var sway := Vector2.ZERO
var hip_pos := Vector3.ZERO
var hip_rot := Vector3.ZERO

var recoil: WeaponRecoil


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


func mount(spec: WeaponSpec) -> bool:
	hip_pos = spec.hip_pos
	hip_rot = spec.hip_rot
	weapon = spec.model.new()
	weapon.name = "Weapon"
	weapon_socket.add_child(weapon)
	if not weapon.build():
		push_error("Viewmodel detenido: el GLB canonico de Glock no monta")
		weapon.queue_free()
		weapon = null
		return false
	arms = FpArms.new()
	arms.name = "ArmsRig"
	arms.prefix = spec.clip_prefix
	weapon_socket.add_child(arms)
	pose_root.force_update_transform()
	weapon_socket.force_update_transform()
	weapon.force_update_transform()
	if not arms.mount(weapon):
		return false
	Nodes.paint(weapon, VIEWMODEL_LAYER_BIT)
	Nodes.paint(arms, VIEWMODEL_LAYER_BIT)
	if recoil != null:
		recoil.set_pivot(weapon.grip_pivot())
	return true


func set_magazine_visible(v: bool) -> void:
	if weapon != null:
		weapon.set_magazine_attached(v)


func set_pose_inputs(aim: float, sprint: float, speed: float, look: Vector2, move: Vector2,
		phase := 0.0, vertical := 0.0) -> void:
	_in_aim = aim
	_in_sprint = sprint
	_in_speed = speed
	_in_look = look
	_in_move = move
	_in_phase = phase
	_in_vertical = vertical


func _apply_pose(delta: float) -> void:
	idle_phase += delta

	var look_x := clampf(_in_look.x, -12.0, 12.0) * 0.0022
	var look_y := clampf(_in_look.y, -12.0, 12.0) * 0.0022
	sway.x += (-look_x - sway.x) * (1.0 - exp(-10.0 * delta))
	sway.y += (-look_y - sway.y) * (1.0 - exp(-10.0 * delta))
	sway.x = clampf(sway.x, -0.022, 0.022)
	sway.y = clampf(sway.y, -0.022, 0.022)

	var sprint_pos := Vector3(0.05, -0.135, -0.02)
	var sprint_rot := Vector3(deg_to_rad(-14.0), deg_to_rad(-5.0), deg_to_rad(5.0))
	var pos := hip_pos.lerp(sprint_pos, _in_sprint)
	var rot := hip_rot.lerp(sprint_rot, _in_sprint)

	var move_norm := clampf(_in_speed / 4.35, 0.0, 1.0)
	var step := _in_phase - BOB_LAG
	pos.x += cos(step) * BOB_SIDE * move_norm + sway.x * (1.0 - _in_aim * 0.65)
	pos.y += sin(step * 2.0) * BOB_RISE * move_norm + sin(idle_phase * 1.05) * 0.0016 * (1.0 - _in_aim * 0.55) + sway.y * (1.0 - _in_aim * 0.65)
	var move_x := clampf(_in_move.x, -1.0, 1.0)
	var move_y := clampf(_in_move.y, -1.0, 1.0)
	pos.x -= move_x * 0.02 * (1.0 - _in_aim * 0.5)
	pos.y -= absf(move_y) * 0.008 * (1.0 - _in_aim * 0.5)

	rot.x += sway.y * 1.3 - move_y * 0.008
	rot.y += sway.x * 1.3
	rot.z += -move_x * 0.012 + sin(step) * BOB_ROLL * move_norm - sin(step) * 0.012 * _in_sprint

	_air += (clampf(_in_vertical, -12.0, 12.0) * 0.0024 - _air) * (1.0 - exp(-9.0 * delta))
	pos.y -= _air
	pos.z += _air * 0.6
	rot.x += _air * 4.0

	pos.x = clampf(pos.x, -0.30, 0.30)
	pos.y = clampf(pos.y, -0.30, 0.18)
	pos.z = clampf(pos.z, -0.45, 0.15)
	rot.x = clampf(rot.x, -0.35, 0.35)
	rot.y = clampf(rot.y, -0.35, 0.35)
	rot.z = clampf(rot.z, -0.25, 0.25)

	pose_root.position = pos
	pose_root.rotation = rot


func update(delta: float) -> void:
	if arms != null:
		arms.aim_pose.influence = _in_aim
	_apply_pose(delta)
	_align_sights()
	if recoil != null:
		recoil.apply(body_give, weapon_socket)


func _align_sights() -> void:
	if _in_aim <= 0.001 or camera == null or weapon == null:
		return
	var inner := (body_give.transform * weapon_socket.transform).affine_inverse()
	var root_inv := pose_root.global_transform.affine_inverse()
	var to_cam := camera.global_transform.affine_inverse() * pose_root.global_transform
	var rear := to_cam * (inner * (root_inv * weapon.sight_rear.global_position))
	var front := to_cam * (inner * (root_inv * weapon.sight_front.global_position))
	var turn := Basis(Quaternion((front - rear).normalized(), Vector3.FORWARD))
	var fix := Transform3D(Basis.IDENTITY, Vector3(-rear.x, -rear.y, 0.0)) * Transform3D(turn, rear - turn * rear)
	pose_root.global_transform = camera.global_transform * Transform3D.IDENTITY.interpolate_with(fix, _in_aim) * to_cam


func setup(cam: Camera3D) -> void:
	camera = cam
