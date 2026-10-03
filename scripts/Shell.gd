class_name Shell
extends RigidBody3D

var life := 0.0
var last_ping := 0.0
var _still := 0.0
var _settled := false

const CASING_LEN := 0.01915
const CASING_RAD := 0.0049

const SETTLE_LIN := 0.06
const SETTLE_ANG := 0.6
const SETTLE_S := 0.35

static var _casing_mesh: CylinderMesh
static var _casing_shape: CylinderShape3D
static var _casing_physics: PhysicsMaterial


static func _resources() -> void:
    if _casing_mesh != null:
        return
    _casing_mesh = CylinderMesh.new()
    _casing_mesh.top_radius = CASING_RAD
    _casing_mesh.bottom_radius = CASING_RAD
    _casing_mesh.height = CASING_LEN
    _casing_mesh.radial_segments = 12
    _casing_mesh.rings = 1
    var brass := StandardMaterial3D.new()
    brass.albedo_color = Color(0.72, 0.53, 0.18)
    brass.metallic = 0.95
    brass.roughness = 0.28
    _casing_mesh.material = brass
    _casing_shape = CylinderShape3D.new()
    _casing_shape.height = CASING_LEN
    _casing_shape.radius = CASING_RAD
    _casing_physics = PhysicsMaterial.new()
    _casing_physics.bounce = 0.52
    _casing_physics.friction = 0.45


static func spawn(scene: Node, port: Transform3D, slide_vel: float, player_vel: Vector3) -> Shell:
    _resources()
    var shell := Shell.new()
    shell.mass = 0.0039
    shell.collision_layer = 32
    shell.collision_mask = 1
    shell.continuous_cd = true

    var casing_inst := MeshInstance3D.new()
    casing_inst.name = "CasingMesh"
    casing_inst.mesh = _casing_mesh
    casing_inst.rotation.x = deg_to_rad(90.0)
    shell.add_child(casing_inst)

    var collider := CollisionShape3D.new()
    collider.shape = _casing_shape
    collider.rotation.x = deg_to_rad(-90.0)
    shell.add_child(collider)

    shell.physics_material_override = _casing_physics
    shell.linear_damp = 0.9
    shell.angular_damp = 0.5

    scene.add_child(shell)
    shell.global_transform = port
    shell.reset_physics_interpolation()
    var local_vel := Vector3(1.5 + randf() * 0.7, 1.3 + randf() * 0.6, maxf(0.6, slide_vel * 0.35))
    shell.linear_velocity = port.basis * local_vel + player_vel * 0.8
    shell.angular_velocity = Vector3(randf_range(-34.0, 34.0), randf_range(-34.0, 34.0), randf_range(-34.0, 34.0))
    return shell


func _ready() -> void:
    contact_monitor = true
    max_contacts_reported = 4
    body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
    life += delta
    if life > 14.0:
        queue_free()
        return
    if _settled:
        return
    if linear_velocity.length() < SETTLE_LIN and angular_velocity.length() < SETTLE_ANG:
        _still += delta
        if _still >= SETTLE_S:
            _settled = true
            continuous_cd = false
            contact_monitor = false
    else:
        _still = 0.0


func _on_body_entered(_body: Node) -> void:
    if life < 0.06 or life - last_ping < 0.12:
        return
    var speed := linear_velocity.length()
    if speed > 0.65:
        last_ping = life
        GameAudio.play_3d("shell_drop", global_position, 0.0, randf_range(0.92, 1.12))
