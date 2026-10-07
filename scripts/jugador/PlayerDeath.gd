class_name PlayerDeath
extends RigidBody3D

const HEIGHT := 1.2
const RADIUS := 0.2
const MASS := 72.0
const HEAD := 0.5
const FOLLOW := 40.0
const SPRING := 190.0
const DAMP := 13.0
const JOLT := 7.0
const ROLL := 6.0
const STYLES := {
	"head": {"push": 0.6, "tip": 3.4, "twist": 1.6, "kneel": 0.0, "hold": 0.0, "lean": 0.3, "side": 1.0},
	"torso": {"push": 1.5, "tip": 2.2, "twist": 1.0, "kneel": 0.15, "hold": 0.12, "lean": 1.0, "side": 0.6},
	"legs": {"push": 0.3, "tip": 1.6, "twist": 0.6, "kneel": 0.5, "hold": 0.4, "lean": -1.0, "side": 0.4},
}

var camera: Camera3D
var _cam_local := Transform3D.IDENTITY
var _style: Dictionary
var _push := Vector3.ZERO
var _hold := 0.0
var _landed := false
var _spin := Vector3.ZERO


static func drop_gun(player: CharacterBody3D, weapon: Node3D, dir: Vector3) -> void:
	DroppedProp.spawn(player.get_parent(), weapon.viewmodel.weapon, 0.7, player.velocity + dir.normalized() * 0.8 + Vector3.UP * 0.5,
		Vector3(randf_range(-7, 7), randf_range(-5, 5), randf_range(-7, 7)), "gun_drop", 16.0)
	weapon.visible = false


static func fall(player: Node3D, cam: Camera3D, zone: String, dir: Vector3) -> PlayerDeath:
	var body := PlayerDeath.new()
	body.camera = cam
	body._style = STYLES.get(zone, STYLES["torso"])
	var flat := Vector3(dir.x, 0.0, dir.z)
	body._push = flat.normalized() if flat.length() > 0.01 else -cam.global_basis.z
	player.get_parent().add_child(body)
	var view := cam.global_transform
	var facing := Basis(Vector3.UP, view.basis.get_euler().y)
	body.global_transform = Transform3D(facing, view.origin - Vector3.UP * HEAD)
	body._cam_local = body.global_transform.affine_inverse() * view
	body.reset_physics_interpolation()
	body._begin()
	return body


func _ready() -> void:
	mass = MASS
	collision_layer = 0
	collision_mask = 1
	angular_damp = 1.6
	linear_damp = 0.3
	contact_monitor = true
	max_contacts_reported = 4
	var mat := PhysicsMaterial.new()
	mat.friction = 0.9
	mat.bounce = 0.04
	physics_material_override = mat
	var shape := CapsuleShape3D.new()
	shape.radius = RADIUS
	shape.height = HEIGHT
	var col := CollisionShape3D.new()
	col.shape = shape
	add_child(col)
	body_entered.connect(_on_contact)


func _begin() -> void:
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	_hold = _style["hold"]
	var kneel: float = _style["kneel"]
	if kneel > 0.0:
		var tw := create_tween()
		tw.tween_property(self, "global_position", global_position + Vector3.DOWN * kneel + _push * 0.08, _hold * 0.8) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if _hold <= 0.0:
		_release()


func _physics_process(delta: float) -> void:
	if _hold > 0.0:
		_hold -= delta
		if _hold <= 0.0:
			_release()


func _release() -> void:
	freeze = false
	var across := Vector3.UP.cross(_push).normalized()
	var toward: Vector3 = (_push * _style["lean"] + across * _style["side"] * randf_range(-1.0, 1.0)).normalized()
	linear_velocity = _push * _style["push"] + Vector3.DOWN * 0.4
	angular_velocity = Vector3.UP.cross(toward).normalized() * _style["tip"] * randf_range(0.8, 1.2) \
		+ Vector3.UP * _style["twist"] * randf_range(-1.0, 1.0)


func _process(delta: float) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	var goal := get_global_transform_interpolated() * _cam_local
	var xf := camera.global_transform
	var error := (goal.basis.orthonormalized() * xf.basis.inverse()).get_rotation_quaternion()
	var axis_angle := error.get_axis() * error.get_angle() if error.get_angle() > 0.0001 else Vector3.ZERO
	_spin += (axis_angle * SPRING - _spin * DAMP) * delta
	var turned := Basis.IDENTITY
	if _spin.length() > 0.0001:
		turned = Basis(_spin.normalized(), _spin.length() * delta)
	camera.global_transform = Transform3D((turned * xf.basis).orthonormalized(),
		xf.origin.lerp(goal.origin, 1.0 - exp(-FOLLOW * delta)))


func _on_contact(_other: Node) -> void:
	var speed := linear_velocity.length() + angular_velocity.length() * 0.3
	if speed < 0.6:
		return
	_spin += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * JOLT * clampf(speed / 2.5, 0.3, 1.2)
	if _landed:
		return
	_landed = true
	angular_velocity += global_basis.y * ROLL * randf_range(-1.0, 1.0)
	GameAudio.play_3d("body_fall", global_position, 0.0, randf_range(0.92, 1.05))
	GameAudio.play_3d("cloth", global_position, 4.0, randf_range(0.85, 1.0))
