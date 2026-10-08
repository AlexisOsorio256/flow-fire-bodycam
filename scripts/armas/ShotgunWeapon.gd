class_name ShotgunWeapon
extends WeaponModel

const MODEL := "res://assets/models/shotgun.glb"
const PUMP_TRAVEL := 0.085
const TRIGGER_TRAVEL := 0.004
const CAPACITY := 6
const SOCKETS := {
	"Muzzle": Vector3(0.0, 0.072, -0.592),
	"EjectionPort": Vector3(0.022, 0.045, -0.005),
	"SightRear": Vector3(0.0, 0.1075, 0.06),
	"SightFront": Vector3(0.0, 0.101, -0.415),
	"Grip": Vector3(0.0, -0.03, 0.055),
	"Magwell": Vector3(0.02, 0.008, -0.02),
}

var _pump_rest := Vector3.ZERO
var _trigger_rest := Vector3.ZERO


func build() -> bool:
	var packed := load(MODEL) as PackedScene
	if packed == null:
		push_error("No se pudo cargar la escopeta: " + MODEL)
		return false
	var root := packed.instantiate()
	add_child(root)
	frame = _find_child(root, "Frame")
	slide = _find_child(root, "Pump")
	trigger = _find_child(root, "Trigger")
	magazine = _find_child(root, "Magazine")
	for part in [frame, slide, trigger, magazine]:
		if part == null:
			push_error("GLB de escopeta roto: faltan piezas")
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
	slide_offset = PUMP_TRAVEL
	capacity = CAPACITY
	_pump_rest = slide.position
	_trigger_rest = trigger.position
	_remember_magazine()
	mag_round = Node3D.new()
	mag_round.name = "MagRound"
	mag_round.position = Vector3(0.0, 0.0, -0.035)
	magazine.add_child(mag_round)
	print("ARMA escopeta de bombeo largo_modelo_m=0.69 bomba=", snappedf(PUMP_TRAVEL * 1000.0, 0.1),
		"mm piezas=Frame/Pump/Trigger/Magazine + 6 sockets")
	return true


func set_slide(t: float) -> void:
	var amount := clampf(t, 0.0, 1.0)
	slide.position = _pump_rest - muzzle_axis * (PUMP_TRAVEL * amount)


func set_trigger(t: float) -> void:
	trigger.position = _trigger_rest - muzzle_axis * (TRIGGER_TRAVEL * clampf(t, 0.0, 1.0))
