class_name GlockRecoil
extends RefCounted

## Retroceso en dos capas de resortes: el arma en el agarre (WeaponSocket) y
## el conjunto que cede despues (BodyGive). La camara es de Player.

const RECOIL_PITCH_VEL := 7.60   # rad/s de cabeceo por disparo (pico 8,9 grad)
const RECOIL_YAW_VEL := 0.82     # rad/s de salto lateral simetrico: +-0,35 ->
const RECOIL_ROLL_VEL := 0.92    # rad/s de alabeo de muneca: +-0,40 -> pico
const WEAPON_K := 410.0          # mas blando: mismo golpe, mas lectura de masa
const WEAPON_C := 24.0           # amortiguado: vuelve limpio sin rebote elastico
const RECOIL_BACK_VEL := 0.190   # m/s hacia el tirador (pico 3,9 mm)
const RECOIL_RISE_VEL := 0.020   # m/s subida

const GIVE := 1.00               # todo el impulso llega a manos/brazos
const GIVE_K := 60.0             # mas blando y tardio que el arma
const GIVE_C := 12.0

const POS_LIMIT := Vector3(0.012, 0.018, 0.020)
const ROT_LIMIT := Vector3(0.22, 0.055, 0.065)
const GIVE_POS_LIMIT := Vector3(0.008, 0.008, 0.010)
const GIVE_ROT_LIMIT := Vector3(0.056, 0.0, 0.018)

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
	give_vel += Vector3((randf() - 0.5) * 0.010, 0.016, RECOIL_BACK_VEL * GIVE)
	give_rot_vel += Vector3(0.70 + randf() * 0.06, 0.0, (randf() - 0.5) * 0.065)


func kick_mag_seat() -> void:
	rot_vel.x += 0.48
	vel.z += 0.018
	give_vel += Vector3(0.0, 0.034, 0.024)
	give_rot_vel.x -= 0.12


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
