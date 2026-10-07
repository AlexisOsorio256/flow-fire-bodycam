class_name Shell
extends RigidBody3D

var life := 0.0
var last_ping := 0.0
var _still := 0.0
var _settled := false

const CALIBERS := {
    "9mm": {"len": 0.01915, "rad": 0.0049, "mass": 0.0039},
    "556": {"len": 0.0447, "rad": 0.00479, "mass": 0.0061},
}

const SETTLE_LIN := 0.06
const SETTLE_ANG := 0.6
const SETTLE_S := 0.35

static var _meshes := {}
static var _shapes := {}
static var _casing_physics: PhysicsMaterial


static func _resources(caliber: String) -> Array:
    if _casing_physics == null:
        _casing_physics = PhysicsMaterial.new()
        _casing_physics.bounce = 0.52
        _casing_physics.friction = 0.45
    if not _meshes.has(caliber):
        var dims: Dictionary = CALIBERS.get(caliber, CALIBERS["9mm"])
        var mesh := CylinderMesh.new()
        mesh.top_radius = dims["rad"]
        mesh.bottom_radius = dims["rad"]
        mesh.height = dims["len"]
        mesh.radial_segments = 12
        mesh.rings = 1
        var brass := StandardMaterial3D.new()
        brass.albedo_color = Color(0.72, 0.53, 0.18)
        brass.metallic = 0.95
        brass.roughness = 0.28
        mesh.material = brass
        _meshes[caliber] = mesh
        var shape := CylinderShape3D.new()
        shape.height = dims["len"]
        shape.radius = dims["rad"]
        _shapes[caliber] = shape
    return [_meshes[caliber], _shapes[caliber]]


static func spawn(scene: Node, port: Transform3D, slide_vel: float, player_vel: Vector3, caliber := "9mm") -> Shell:
    var dims: Dictionary = CALIBERS.get(caliber, CALIBERS["9mm"])
    var res := _resources(caliber)
    var shell := Shell.new()
    shell.mass = dims["mass"]
    shell.collision_layer = 32
    shell.collision_mask = 1
    shell.continuous_cd = true

    var casing_inst := MeshInstance3D.new()
    casing_inst.name = "CasingMesh"
    casing_inst.mesh = res[0]
    casing_inst.rotation.x = deg_to_rad(90.0)
    shell.add_child(casing_inst)

    var collider := CollisionShape3D.new()
    collider.shape = res[1]
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
