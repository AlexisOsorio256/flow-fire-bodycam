class_name WeaponSpec
extends RefCounted

var id := ""
var caliber := "9mm"
var clip_prefix := ""
var model: GDScript
var muzzle_speed := 372.0
var bullet_kg := 0.0
var drag := 0.0
var punch := 1.0
var fire_delay := 0.15
var pellets := 1
var shells := false
var automatic := false
var move_mult := 1.0
var shot_streams := "pistol"
var hip_spread := 1.0
var hip_pos := Vector3(0.085, 0.035, -0.050)
var hip_rot := Vector3(deg_to_rad(-2.8), deg_to_rad(3.8), deg_to_rad(-2.0))
var cam_kick := 1.0
var mag_empty_kg := 0.071
var round_kg := 0.012
var times := {}
var sounds := {}
var recoil := {}
var aim_fov := 86.0


static func all() -> Array[WeaponSpec]:
	return [glock(), rifle(), shotgun(), desert_eagle(), barrett()]


func ballistic() -> Dictionary:
	var shot := {}
	if bullet_kg > 0.0:
		shot["mass"] = bullet_kg
	if drag > 0.0:
		shot["drag"] = drag
	if punch != 1.0:
		shot["punch"] = punch
	return shot


static func glock() -> WeaponSpec:
	var spec := WeaponSpec.new()
	spec.id = "glock"
	spec.model = GlockWeapon
	spec.times = {"mag_in": 0.33, "mag_touch": 1.09, "action_release": 2.275, "inspect_grab": 0.46, "inspect_touch": 2.04,
		"magin_lead": 0.06}
	spec.sounds = {"mag_out": "magout", "mag_in": "magin", "mag_grab": "mag_insert", "mag_touch": "mag_insert",
		"action_rear": "slide_rear", "action_release": "slide_release", "action_battery": "slide_battery", "raise": "cloth"}
	return spec


static func rifle() -> WeaponSpec:
	var spec := WeaponSpec.new()
	spec.id = "rifle"
	spec.caliber = "556"
	spec.clip_prefix = "Rifle"
	spec.model = RifleWeapon
	spec.muzzle_speed = 900.0
	spec.fire_delay = 0.1
	spec.automatic = true
	spec.shot_streams = "rifle"
	spec.hip_spread = 1.4
	spec.cam_kick = 1.4
	spec.mag_empty_kg = 0.12
	spec.times = {"mag_in": 1.0, "mag_touch": 1.58, "action_release": 2.21, "inspect_grab": 0.75, "inspect_touch": 2.17,
		"magin_lead": 0.03, "tap": 0.12, "raise_at": 0.85}
	spec.sounds = {"mag_out": "rifle_magout", "mag_in": "rifle_magin", "mag_grab": "cloth", "mag_touch": "",
		"tap": "rifle_tap", "action_rear": "rifle_charge", "action_release": "rifle_bolt", "action_battery": "", "raise": "rifle_shoulder"}
	spec.recoil = {"pitch": 9.5, "yaw": 2.8, "roll": 1.2, "back": 0.68, "rise": 0.055, "give": 1.2, "k": 310.0, "c": 20.0}
	return spec


static func shotgun() -> WeaponSpec:
	var spec := WeaponSpec.new()
	spec.id = "shotgun"
	spec.caliber = "12ga"
	spec.clip_prefix = "Shotgun"
	spec.model = ShotgunWeapon
	spec.muzzle_speed = 380.0
	spec.fire_delay = 0.9
	spec.pellets = 9
	spec.shells = true
	spec.move_mult = 1.08
	spec.shot_streams = "shotgun"
	spec.hip_spread = 1.2
	spec.hip_pos = Vector3(0.0, 0.035, -0.050)
	spec.hip_rot = Vector3(deg_to_rad(3.0), deg_to_rad(6.0), deg_to_rad(-2.0))
	spec.cam_kick = 2.4
	spec.mag_empty_kg = 0.03
	spec.round_kg = 0.04
	spec.times = {"seat": 2.50, "action_release": 3.258, "raise_at": 0.55,
		"shells": [0.729, 1.042, 1.354, 1.667, 1.979, 2.292],
		"shells_empty": [0.717, 1.017, 1.317, 1.617, 1.917, 2.217]}
	spec.sounds = {"mag_out": "shotgun_shell", "mag_in": "shotgun_shell", "mag_grab": "cloth", "mag_touch": "",
		"tap": "", "action_rear": "shotgun_pump", "action_release": "shotgun_pump_fwd", "action_battery": "", "raise": "cloth"}
	spec.recoil = {"pitch": 14.5, "yaw": 3.2, "roll": 2.0, "back": 1.10, "rise": 0.110, "give": 0.65, "k": 210.0, "c": 16.0}
	return spec


static func desert_eagle() -> WeaponSpec:
	var spec := WeaponSpec.new()
	spec.id = "deagle"
	spec.caliber = "50ae"
	spec.clip_prefix = "Deagle"
	spec.model = DesertEagleWeapon
	spec.muzzle_speed = 470.0
	spec.bullet_kg = 0.0194
	spec.drag = 0.0011
	spec.fire_delay = 0.42
	spec.shot_streams = "deagle"
	spec.hip_spread = 1.8
	spec.hip_pos = Vector3(0.085, 0.035, -0.050)
	spec.hip_rot = Vector3(deg_to_rad(-2.8), deg_to_rad(3.8), deg_to_rad(-2.0))
	spec.cam_kick = 3.6
	spec.mag_empty_kg = 0.16
	spec.round_kg = 0.026
	spec.times = {"mag_in": 0.833, "mag_touch": 1.375, "action_release": 2.167, "inspect_grab": 0.46, "inspect_touch": 2.04,
		"magin_lead": 0.06}
	spec.sounds = {"mag_out": "magout", "mag_in": "magin", "mag_grab": "mag_insert", "mag_touch": "mag_insert",
		"action_rear": "slide_rear", "action_release": "slide_release", "action_battery": "slide_battery", "raise": "cloth"}
	spec.recoil = {"pitch": 24.0, "yaw": 4.4, "roll": 3.0, "back": 1.45, "rise": 0.145, "give": 0.45, "k": 230.0, "c": 14.0}
	return spec


static func barrett() -> WeaponSpec:
	var spec := WeaponSpec.new()
	spec.id = "barrett"
	spec.caliber = "50bmg"
	spec.clip_prefix = "Barrett"
	spec.model = BarrettWeapon
	spec.muzzle_speed = 853.0
	spec.bullet_kg = 0.0427
	spec.drag = 0.00012
	spec.punch = 8.0
	spec.fire_delay = 1.5
	spec.shot_streams = "barrett"
	spec.hip_spread = 2.6
	spec.hip_pos = Vector3(0.085, -0.080, -0.180)
	spec.hip_rot = Vector3(deg_to_rad(-1.0), deg_to_rad(8.5), deg_to_rad(-3.0))
	spec.move_mult = 0.92
	spec.cam_kick = 6.2
	spec.mag_empty_kg = 1.1
	spec.round_kg = 0.114
	spec.aim_fov = 28.0
	spec.times = {"mag_in": 1.083, "mag_touch": 1.667, "action_release": 2.767, "inspect_grab": 0.75, "inspect_touch": 2.17,
		"magin_lead": 0.04, "tap": 0.12, "raise_at": 0.85}
	spec.sounds = {"mag_out": "barrett_magout", "mag_in": "barrett_magin", "mag_grab": "cloth", "mag_touch": "",
		"tap": "rifle_tap", "action_rear": "barrett_charge", "action_release": "barrett_bolt", "action_battery": "",
		"raise": "rifle_shoulder"}
	spec.recoil = {"pitch": 34.0, "yaw": 6.0, "roll": 4.5, "back": 2.10, "rise": 0.190, "give": 0.30, "k": 170.0, "c": 12.0}
	return spec
