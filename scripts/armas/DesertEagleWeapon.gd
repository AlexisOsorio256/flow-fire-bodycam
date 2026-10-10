class_name DesertEagleWeapon
extends WeaponModel

const MODEL := "res://assets/models/desert_eagle.glb"
const SLIDE_TRAVEL := 0.048
const CAPACITY := 7
const SOCKETS := {
	"Muzzle": Vector3(0.0, 0.0, -0.2151),
	"EjectionPort": Vector3(0.016, 0.005, -0.070),
	"SightRear": Vector3(0.0, 0.0285, 0.0015),
	"SightFront": Vector3(0.0, 0.0286, -0.2041),
	"Grip": Vector3(0.0, -0.0195, 0.0170),
}


func build() -> bool:
	if not _mount(MODEL, "desert eagle", {"frame": "Frame", "slide": "Slide", "trigger": "Trigger",
			"magazine": "Magazine"}):
		return false
	_make_sockets(SOCKETS)
	slide_offset = SLIDE_TRAVEL
	capacity = CAPACITY
	_trigger_rest = trigger.position
	_remember_magazine()
	_make_mag_round(Vector3(-0.012, -0.004, 0.026), "50ae")
	return true
