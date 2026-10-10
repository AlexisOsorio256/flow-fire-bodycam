class_name ShotgunWeapon
extends WeaponModel

const MODEL := "res://assets/models/shotgun.glb"
const PUMP_TRAVEL := 0.085
const CAPACITY := 6
const SOCKETS := {
	"Muzzle": Vector3(-0.00475, 0.10375, -0.637),
	"EjectionPort": Vector3(0.0158, 0.085, -0.15),
	"SightRear": Vector3(-0.00475, 0.1175, 0.015),
	"SightFront": Vector3(-0.00475, 0.111, -0.46),
	"Grip": Vector3(0.0, -0.02, 0.01),
}

var _pump_rest := Vector3.ZERO


func build() -> bool:
	if not _mount(MODEL, "escopeta", {"frame": "Frame", "slide": "Pump", "trigger": "Trigger",
			"magazine": "Magazine"}):
		return false
	_make_sockets(SOCKETS)
	slide_offset = PUMP_TRAVEL
	capacity = CAPACITY
	_pump_rest = slide.position
	_trigger_rest = trigger.position
	_remember_magazine()
	_make_mag_round(Vector3(0.0, 0.0, -0.035), "")
	return true


func set_slide(t: float) -> void:
	var amount := clampf(t, 0.0, 1.0)
	slide.position = _pump_rest - muzzle_axis * (PUMP_TRAVEL * amount)
