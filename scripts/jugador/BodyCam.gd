class_name BodyCam
extends RefCounted

const FOV := 100.0
const FOV_AIM := 86.0
const FOV_SPRINT := 96.0
const STAND_Y := 1.62
const CROUCH_Y := 1.1
const LAG_MAX := 0.026
const ANGLE_K := 72.0
const ANGLE_C := 13.5
const POS_K := 95.0
const POS_C := 17.0

var cam_y := STAND_Y
var climb := 0.0

var _cam_y_vel := 0.0
var _lag := Vector3.ZERO
var _lift := 0.0
var _prev_velocity := Vector3.ZERO
var _lean := 0.0
var _breath := 0.0
var _angle := Vector3.ZERO
var _angle_vel := Vector3.ZERO
var _pos := Vector3.ZERO
var _pos_vel := Vector3.ZERO
var _spring: Array = [Vector3.ZERO, Vector3.ZERO]


func kick_shot(aim := 0.0, strength := 1.0) -> void:
	var steadiness := lerpf(1.0, 0.6, aim) * strength
	_angle_vel += Vector3(randf_range(2.1, 2.3), randf_range(-0.35, 0.35),
		randf_range(0.55, 0.75) * (1.0 if randf() < 0.6 else -1.0)) * steadiness
	climb += randf_range(0.012, 0.018) * steadiness
	_pos_vel += Vector3(randf_range(-0.008, 0.008), randf_range(0.019, 0.027), randf_range(0.055, 0.068)) * steadiness


func kick_hit(zone: String, side: float, punch: float) -> void:
	match zone:
		"head":
			_angle_vel += Vector3(2.8 * punch, -side * 2.0 * punch, side * 1.6 * punch)
		"legs":
			_angle_vel += Vector3(-0.8 * punch, -side * 0.4 * punch, side * 1.1 * punch)
			_cam_y_vel -= 3.0 * punch
		_:
			_angle_vel += Vector3(1.7 * punch, -side * 1.0 * punch, side * 0.7 * punch)
			_cam_y_vel -= 1.6 * punch


func kick_suppress() -> void:
	_angle_vel += Vector3(randf_range(-0.35, 0.35), randf_range(-0.25, 0.25), randf_range(-0.12, 0.12))


func kick_land(punch: float) -> void:
	_cam_y_vel -= 2.6 * punch
	_angle_vel += Vector3(0.55 * punch, 0.0, randf_range(-0.25, 0.25) * punch)


func kick_mag_seat() -> void:
	_angle_vel += Vector3(randf_range(0.14, 0.18), randf_range(-0.02, 0.02), randf_range(0.04, 0.07))


func kick_battery() -> void:
	_angle_vel += Vector3(-randf_range(0.08, 0.14), randf_range(-0.01, 0.01), randf_range(-0.02, 0.02))


func fov_for(aim_blend: float, sprinting: bool, aim_target_fov := FOV_AIM) -> float:
	return lerpf(FOV, aim_target_fov, clampf(aim_blend, 0.0, 1.0)) if aim_blend > 0.01 else (FOV_SPRINT if sprinting else FOV)


func update(delta: float, body: Vector3, velocity: Vector3, look: Vector2, strafe: float, turn_lag: float,
		crouching: bool, aim_blend: float, bob: Vector2, airborne := false) -> Transform3D:
	_breath += delta
	climb = lerpf(climb, 0.0, 1.0 - exp(-3.5 * delta))
	_lift += ((clampf(velocity.y, -12.0, 12.0) * 0.0022 if airborne else 0.0) - _lift) * (1.0 - exp(-9.0 * delta))
	var goal := CROUCH_Y if crouching else STAND_Y
	var lifted := Springs.scalar(cam_y - goal, _cam_y_vel, 185.0, 21.0, delta)
	cam_y = lifted.x + goal
	_cam_y_vel = lifted.y
	var accel := (velocity - _prev_velocity) / maxf(delta, 0.0001)
	_prev_velocity = velocity
	var lag_goal := Vector3(-accel.x, 0.0, -accel.z) * 0.00042
	if lag_goal.length() > LAG_MAX:
		lag_goal = lag_goal.normalized() * LAG_MAX
	_lag = _lag.lerp(lag_goal, 1.0 - exp(-7.5 * delta))
	_lean += (-strafe * 0.038 + clampf(turn_lag * 0.35, -0.012, 0.012) - _lean) * (1.0 - exp(-8.0 * delta))
	_update_springs(delta)
	var breath := sin(_breath * 1.15) * 0.0014 * (1.0 - aim_blend * 0.58)
	var basis := Basis.from_euler(Vector3(
		look.y + climb + breath + _angle.x,
		look.x + _angle.y,
		_lean + _angle.z))
	return Transform3D(basis, body + Vector3(_lag.x + bob.x, cam_y + bob.y - _lift, _lag.z) + _pos)


func _update_springs(delta: float) -> void:
	for i in 3:
		var pair := Springs.scalar(_angle[i], _angle_vel[i], ANGLE_K, ANGLE_C, delta)
		_angle[i] = pair.x
		_angle_vel[i] = pair.y
	_angle = _angle.clamp(Vector3(-0.18, -0.12, -0.12), Vector3(0.18, 0.12, 0.12))
	Springs.vector_into(_pos, _pos_vel, POS_K, POS_C, delta, _spring)
	_pos = (_spring[0] as Vector3).clamp(Vector3(-0.010, -0.012, -0.005), Vector3(0.010, 0.012, 0.018))
	_pos_vel = _spring[1]
