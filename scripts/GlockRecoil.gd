class_name GlockRecoil
extends RefCounted

const RECOIL_PITCH_VEL := 10.80
const RECOIL_YAW_VEL := 1.05
const RECOIL_ROLL_VEL := 1.15
const WEAPON_K := 410.0
const WEAPON_C := 24.0
const RECOIL_BACK_VEL := 0.265
const RECOIL_RISE_VEL := 0.070

const GIVE := 1.00
const GIVE_K := 60.0
const GIVE_C := 12.0

const POS_LIMIT := Vector3(0.014, 0.026, 0.028)
const ROT_LIMIT := Vector3(0.290, 0.070, 0.085)
const GIVE_POS_LIMIT := Vector3(0.010, 0.012, 0.014)
const GIVE_ROT_LIMIT := Vector3(0.078, 0.0, 0.024)

var pos := Vector3.ZERO
var vel := Vector3.ZERO
var rot := Vector3.ZERO
var rot_vel := Vector3.ZERO
var give_pos := Vector3.ZERO
var give_vel := Vector3.ZERO
var give_rot := Vector3.ZERO
var give_rot_vel := Vector3.ZERO
var pivot := Vector3(0.0, -0.055, 0.025)


func kick_shot() -> void:
	rot_vel += Vector3(
		RECOIL_PITCH_VEL + randf() * 0.30,
		(randf() - 0.5) * RECOIL_YAW_VEL,
		(randf() - 0.5) * RECOIL_ROLL_VEL)
	vel += Vector3((randf() - 0.5) * 0.012, RECOIL_RISE_VEL, RECOIL_BACK_VEL + randf() * 0.015)
	give_vel += Vector3((randf() - 0.5) * 0.010, 0.024, RECOIL_BACK_VEL * GIVE)
	give_rot_vel += Vector3(0.98 + randf() * 0.08, 0.0, (randf() - 0.5) * 0.085)


func kick_mag_seat() -> void:
	rot_vel.x += 0.48
	vel.z += 0.018
	give_vel += Vector3(0.0, 0.034, 0.024)
	give_rot_vel.x -= 0.12


func kick_mag_touch() -> void:
	rot_vel.x += 0.14
	vel.z += 0.006
	give_vel += Vector3(0.0, 0.012, 0.008)


func kick_slide_battery() -> void:
	rot_vel.x -= 0.28
	vel.z -= 0.018
	give_vel += Vector3(0.0, -0.010, -0.018)
	give_rot_vel.x -= 0.08


func kick_slide_lock() -> void:
	rot_vel.x += 0.32
	vel.z += 0.016
	give_vel += Vector3(0.0, 0.020, 0.022)
	give_rot_vel.x += 0.09


func set_pivot(point: Vector3) -> void:
	pivot = point


func update(delta: float) -> void:
	var rp := Springs.vector(pos, vel, WEAPON_K, WEAPON_C, delta)
	pos = rp[0]
	vel = rp[1]
	var rr := Springs.vector(rot, rot_vel, WEAPON_K, WEAPON_C, delta)
	rot = rr[0]
	rot_vel = rr[1]
	pos = Vector3(clampf(pos.x, -POS_LIMIT.x, POS_LIMIT.x), clampf(pos.y, -POS_LIMIT.y, POS_LIMIT.y), clampf(pos.z, -POS_LIMIT.z, POS_LIMIT.z))
	rot = Vector3(clampf(rot.x, -ROT_LIMIT.x, ROT_LIMIT.x), clampf(rot.y, -ROT_LIMIT.y, ROT_LIMIT.y), clampf(rot.z, -ROT_LIMIT.z, ROT_LIMIT.z))

	var gp := Springs.vector(give_pos, give_vel, GIVE_K, GIVE_C, delta)
	give_pos = gp[0]
	give_vel = gp[1]
	var gr := Springs.vector(give_rot, give_rot_vel, GIVE_K, GIVE_C, delta)
	give_rot = gr[0]
	give_rot_vel = gr[1]
	give_pos = Vector3(clampf(give_pos.x, -GIVE_POS_LIMIT.x, GIVE_POS_LIMIT.x), clampf(give_pos.y, -GIVE_POS_LIMIT.y, GIVE_POS_LIMIT.y), clampf(give_pos.z, -GIVE_POS_LIMIT.z, GIVE_POS_LIMIT.z))
	give_rot = Vector3(clampf(give_rot.x, -GIVE_ROT_LIMIT.x, GIVE_ROT_LIMIT.x), 0.0, clampf(give_rot.z, -GIVE_ROT_LIMIT.z, GIVE_ROT_LIMIT.z))


func apply(give: Node3D, socket: Node3D) -> void:
	give.position = give_pos
	give.rotation = give_rot
	var r := Basis.from_euler(rot)
	socket.position = pivot + (r * -pivot) + pos
	socket.basis = r
