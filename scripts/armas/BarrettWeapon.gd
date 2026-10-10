class_name BarrettWeapon
extends WeaponModel

const MODEL := "res://assets/models/barrett.glb"
const BOLT_TRAVEL := 0.115
const CAPACITY := 10
const SOCKETS := {
	"Muzzle": Vector3(0.0, 0.0129, -1.1035),
	"EjectionPort": Vector3(0.0243, -0.0285, -0.1483),
	"SightRear": Vector3(0.0, 0.0966, 0.0531),
	"SightFront": Vector3(0.0, 0.0966, -0.3140),
	"Grip": Vector3(0.0, -0.1219, 0.0),
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
	_make_mag_round(Vector3(0.0, -0.040, -0.090), "50bmg")
	return true


func set_slide(t: float) -> void:
	var amount := clampf(t, 0.0, 1.0)
	slide.position = _slide_rest - muzzle_axis * (BOLT_TRAVEL * amount)
