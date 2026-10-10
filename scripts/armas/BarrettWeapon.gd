class_name BarrettWeapon
extends WeaponModel

const MODEL := "res://assets/models/barrett.glb"
const BOLT_TRAVEL := 0.09
const CAPACITY := 10
const SOCKETS := {
	"Muzzle": Vector3(0.0, 0.0, -0.9170),
	"EjectionPort": Vector3(0.0402, -0.0630, 0.1784),
	"SightRear": Vector3(0.0, 0.1277, 0.0769),
	"SightFront": Vector3(0.0, 0.1277, -0.4827),
	"Grip": Vector3(0.0, -0.1746, -0.0100),
}

var _slide_rest := Vector3.ZERO


func build() -> bool:
	if not _mount(MODEL, "barrett", {"frame": "Frame", "slide": "Slide", "trigger": "Trigger",
			"magazine": "Magazine"}):
		return false
	_make_sockets(SOCKETS)
	slide_offset = BOLT_TRAVEL
	capacity = CAPACITY
	_slide_rest = slide.position
	_trigger_rest = trigger.position
	_remember_magazine()
	_make_mag_round(Vector3(-0.010, -0.050, -0.070), "50bmg")
	return true


func set_slide(t: float) -> void:
	var amount := clampf(t, 0.0, 1.0)
	slide.position = _slide_rest - muzzle_axis * (BOLT_TRAVEL * amount)
