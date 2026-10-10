class_name DesertEagleWeapon
extends WeaponModel

const MODEL := "res://assets/models/desert_eagle.glb"
const SLIDE_TRAVEL := 0.048
const CAPACITY := 7
const SOCKETS := {
	"Muzzle": Vector3(0.0, -0.0115, -0.2489),
	"EjectionPort": Vector3(0.017, 0.0, -0.025),
	"SightRear": Vector3(0.0, 0.0170, -0.0323),
	"SightFront": Vector3(0.0, 0.0171, -0.2379),
	"Grip": Vector3(0.0, -0.0310, -0.0168),
}


var _slide_rest := Vector3.ZERO


func build() -> bool:
	if not _mount(MODEL, "desert eagle", {"frame": "Frame", "slide": "Slide", "trigger": "Trigger",
			"magazine": "Magazine"}):
		return false
	_make_sockets(SOCKETS)
	slide_offset = SLIDE_TRAVEL
	capacity = CAPACITY
	_slide_rest = slide.position
	_trigger_rest = trigger.position
	_remember_magazine()
	_make_mag_round(Vector3(0.004, -0.018, -0.046), "50ae")
	return true


func set_slide(t: float) -> void:
	var amount := clampf(t, 0.0, 1.0)
	slide.position = _slide_rest - muzzle_axis * (SLIDE_TRAVEL * amount)

