class_name WeaponSpec
extends RefCounted

var id := ""
var caliber := "9mm"
var clip_prefix := ""
var model: GDScript
var muzzle_speed := 372.0
var fire_delay := 0.15
var pellets := 1
var shells := false
var move_mult := 1.0
var shot_streams := "pistol"
var hip_spread := 1.0
var cam_kick := 1.0
var mag_empty_kg := 0.071
var round_kg := 0.012
var times := {}
var sounds := {}
var recoil := {}


static func all() -> Array[WeaponSpec]:
	return [glock(), rifle(), shotgun()]


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
	spec.shot_streams = "rifle"
	spec.hip_spread = 1.4
	spec.cam_kick = 0.8
	spec.mag_empty_kg = 0.12
	spec.times = {"mag_in": 1.0, "mag_touch": 1.58, "action_release": 2.21, "inspect_grab": 0.75, "inspect_touch": 2.17,
		"magin_lead": 0.03, "tap": 0.12, "raise_at": 0.85}
	spec.sounds = {"mag_out": "rifle_magout", "mag_in": "rifle_magin", "mag_grab": "cloth", "mag_touch": "",
		"tap": "rifle_tap", "action_rear": "rifle_charge", "action_release": "rifle_bolt", "action_battery": "", "raise": "rifle_shoulder"}
	spec.recoil = {"pitch": 5.6, "yaw": 1.5, "roll": 0.6, "back": 0.36, "rise": 0.035, "give": 1.3, "k": 300.0, "c": 22.0}
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
	spec.hip_spread = 2.2
	spec.cam_kick = 1.3
	spec.mag_empty_kg = 0.03
	spec.round_kg = 0.04
	spec.times = {"seat": 2.37, "action_release": 2.47, "raise_at": 0.55,
		"shells": [0.5, 0.833, 1.167, 1.5, 1.833, 2.167],
		"shells_empty": [0.567, 0.9, 1.233, 1.567, 1.9, 2.233]}
	spec.sounds = {"mag_out": "shotgun_shell", "mag_in": "shotgun_shell", "mag_grab": "cloth", "mag_touch": "",
		"tap": "", "action_rear": "shotgun_pump", "action_release": "shotgun_pump_fwd", "action_battery": "", "raise": "cloth"}
	spec.recoil = {"pitch": 6.4, "yaw": 1.6, "roll": 0.8, "back": 0.58, "rise": 0.05, "give": 0.36, "k": 260.0, "c": 24.0}
	return spec
