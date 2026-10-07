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

var handle: Node3D
var _bolt_rest := Vector3.ZERO
var _handle_rest := Vector3.ZERO
var _trigger_rest := Vector3.ZERO


func build() -> bool:
	var packed := load(MODEL) as PackedScene
	if packed == null:
		push_error("No se pudo cargar el rifle: " + MODEL)
		return false
	var root := packed.instantiate()
	add_child(root)
	frame = _find_child(root, "Receiver")
	slide = _find_child(root, "Bolt")
	handle = _find_child(root, "ChargingHandle")
	trigger = _find_child(root, "Trigger")
	magazine = _find_child(root, "Magazine")
	for part in [frame, slide, handle, trigger, magazine]:
		if part == null:
			push_error("GLB del rifle roto: faltan piezas")
			return false
	var sockets := {}
	for socket_name: String in SOCKETS:
		var node := Node3D.new()
		node.name = socket_name
		node.position = SOCKETS[socket_name]
		frame.add_child(node)
		sockets[socket_name] = node
	muzzle = sockets["Muzzle"]
	ejection_port = sockets["EjectionPort"]
	sight_rear = sockets["SightRear"]
	sight_front = sockets["SightFront"]
	grip = sockets["Grip"]
	magwell = sockets["Magwell"]
	slide_offset = BOLT_TRAVEL
	capacity = CAPACITY
	_bolt_rest = slide.position
	_handle_rest = handle.position
	_trigger_rest = trigger.position
	_remember_magazine()
	mag_round = Node3D.new()
	mag_round.name = "MagRound"
	magazine.add_child(mag_round)
	var nose := Vector3(0.0, 0.0, -1.0)
	var right := nose.cross(Vector3.UP)
	mag_round.basis = Basis(right, nose, right.cross(nose))
	mag_round.position = Vector3(0.0, 0.072, -0.13)
	RoundMesh.build(mag_round)
	return true


func set_slide(t: float) -> void:
	var amount := clampf(t, 0.0, 1.0)
	slide.position = _bolt_rest - muzzle_axis * (BOLT_TRAVEL * amount)
	handle.position = _handle_rest - muzzle_axis * (HANDLE_TRAVEL * amount if by_hand else 0.0)


func set_trigger(t: float) -> void:
	trigger.position = _trigger_rest - muzzle_axis * (TRIGGER_TRAVEL * clampf(t, 0.0, 1.0))
