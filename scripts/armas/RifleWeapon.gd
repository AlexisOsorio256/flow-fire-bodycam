class_name RifleWeapon
extends WeaponModel

const MODEL := "res://assets/models/ar15.glb"
const BOLT_TRAVEL := 0.08
const HANDLE_TRAVEL := 0.065
const TRIGGER_TRAVEL := 0.004
const CAPACITY := 30
const SOCKETS := {
	"Muzzle": Vector3(0.0, 0.089, -0.604),
	"EjectionPort": Vector3(0.016, 0.09, -0.12),
	"SightRear": Vector3(0.0, 0.1512, 0.0215),
	"SightFront": Vector3(0.0, 0.1512, -0.395),
	"Grip": Vector3(0.0, -0.02, 0.01),
	"Magwell": Vector3(0.0, 0.0, -0.145),
}

var _bolt_rest := Vector3.ZERO
var _handle_rest := Vector3.ZERO
var _trigger_rest := Vector3.ZERO


func build() -> bool:
	if not _mount(MODEL, "rifle", {"frame": "Receiver", "slide": "Bolt", "handle": "ChargingHandle",
			"trigger": "Trigger", "magazine": "Magazine"}):
		return false
	_make_sockets(SOCKETS)
	slide_offset = BOLT_TRAVEL
	capacity = CAPACITY
	_bolt_rest = slide.position
	_handle_rest = handle.position
	_trigger_rest = trigger.position
	_remember_magazine()
	var nose := Vector3(0.0, 0.0, -1.0)
	var right := nose.cross(Vector3.UP)
	_make_mag_round(Vector3(0.0, 0.043, -0.13), Basis(right, nose, right.cross(nose)), "556")
	return true


func set_slide(t: float) -> void:
	var amount := clampf(t, 0.0, 1.0)
	slide.position = _bolt_rest - muzzle_axis * (BOLT_TRAVEL * amount)
	handle.position = _handle_rest - muzzle_axis * (HANDLE_TRAVEL * amount if by_hand else 0.0)


func set_trigger(t: float) -> void:
	trigger.position = _trigger_rest - muzzle_axis * (TRIGGER_TRAVEL * clampf(t, 0.0, 1.0))
