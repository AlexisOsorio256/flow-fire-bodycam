class_name Shell
extends RigidBody3D

var life := 0.0
var last_ping := 0.0
var ring := 1.0
var _still := 0.0
var _settled := false

const CALIBERS := {
    "9mm": {"len": 0.01915, "rad": 0.0049, "mass": 0.0039, "nose_top": 0.0028, "nose_bottom": 0.0045, "nose_len": 0.009},
    "556": {"len": 0.0447, "rad": 0.00479, "mass": 0.0061, "nose_top": 0.0012, "nose_bottom": 0.00285, "nose_len": 0.0127},
    "12ga": {"len": 0.07, "rad": 0.0103, "mass": 0.01},
    "50ae": {"len": 0.0326, "rad": 0.00635, "mass": 0.0071, "nose_top": 0.0045, "nose_bottom": 0.00635, "nose_len": 0.019},
    "50bmg": {"len": 0.0993, "rad": 0.0102, "mass": 0.07, "neck_rad": 0.0073, "neck_len": 0.032, "shoulder_len": 0.011,
        "nose_top": 0.0054, "nose_bottom": 0.00635, "nose_len": 0.030},
}


static func dims_of(caliber: String) -> Dictionary:
    if not CALIBERS.has(caliber):
        push_error("Calibre sin ficha en Shell.CALIBERS: " + caliber)
        return CALIBERS["9mm"]
    return CALIBERS[caliber]

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
        var dims: Dictionary = dims_of(caliber)
        _meshes[caliber] = _case_mesh(dims)
        var shape := CylinderShape3D.new()
        shape.height = dims["len"]
        shape.radius = dims["rad"]
        _shapes[caliber] = shape
    return [_meshes[caliber], _shapes[caliber]]


static func brass() -> StandardMaterial3D:
    var metal := StandardMaterial3D.new()
    metal.albedo_color = Color(0.86, 0.66, 0.30)
    metal.metallic = 0.55
    metal.roughness = 0.36
    return metal


static func case_of(caliber: String) -> Mesh:
    _resources(caliber)
    return _meshes[caliber]


static func _case_mesh(dims: Dictionary) -> Mesh:
    if not dims.has("neck_rad"):
        var tube := CylinderMesh.new()
        tube.top_radius = dims["rad"]
        tube.bottom_radius = dims["rad"]
        tube.height = dims["len"]
        tube.radial_segments = 12
        tube.rings = 1
        tube.material = brass()
        return tube
    return _turned(dims)


static func _turned(dims: Dictionary) -> ArrayMesh:
    var half: float = dims["len"] * 0.5
    var mouth: float = half - dims["neck_len"]
    var shoulder: float = mouth - dims["shoulder_len"]
    var profile := [[dims["rad"], -half], [dims["rad"], shoulder], [dims["neck_rad"], mouth], [dims["neck_rad"], half]]
    var together := SurfaceTool.new()
    together.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in profile.size() - 1:
        var low: Array = profile[i]
        var high: Array = profile[i + 1]
        for j in 12:
            var a0 := TAU * float(j) / 12.0
            var a1 := TAU * float(j + 1) / 12.0
            var p00 := Vector3(cos(a0) * low[0], low[1], sin(a0) * low[0])
            var p01 := Vector3(cos(a1) * low[0], low[1], sin(a1) * low[0])
            var p10 := Vector3(cos(a0) * high[0], high[1], sin(a0) * high[0])
            var p11 := Vector3(cos(a1) * high[0], high[1], sin(a1) * high[0])
            together.add_vertex(p00)
            together.add_vertex(p10)
            together.add_vertex(p11)
            together.add_vertex(p00)
            together.add_vertex(p11)
            together.add_vertex(p01)
    _disc(together, dims["rad"], -half, -1.0)
    _disc(together, dims["neck_rad"], half, 1.0)
    together.generate_normals()
    var turned := together.commit()
    turned.surface_set_material(0, brass())
    return turned


static func _disc(together: SurfaceTool, radius: float, y: float, way: float) -> void:
    for j in 12:
        var a0 := TAU * float(j) / 12.0
        var a1 := TAU * float(j + 1) / 12.0
        if way > 0.0:
            together.add_vertex(Vector3(0.0, y, 0.0))
            together.add_vertex(Vector3(cos(a1) * radius, y, sin(a1) * radius))
            together.add_vertex(Vector3(cos(a0) * radius, y, sin(a0) * radius))
        else:
            together.add_vertex(Vector3(0.0, y, 0.0))
            together.add_vertex(Vector3(cos(a0) * radius, y, sin(a0) * radius))
            together.add_vertex(Vector3(cos(a1) * radius, y, sin(a1) * radius))


static func spawn(scene: Node, port: Transform3D, slide_vel: float, player_vel: Vector3, caliber := "9mm") -> Shell:
    var dims: Dictionary = dims_of(caliber)
    var res := _resources(caliber)
    var shell := Shell.new()
    shell.mass = dims["mass"]
    shell.ring = lerpf(0.62, 1.0, sqrt(clampf(0.01915 / dims["len"], 0.2, 1.0)))
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
    var local_vel := Vector3(0.8 + randf() * 0.5, 1.5 + randf() * 0.6, maxf(0.15, slide_vel * 0.12))
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
    continuous_cd = false
    if life < 0.06 or life - last_ping < 0.12:
        return
    var speed := linear_velocity.length()
    if speed > 0.65:
        last_ping = life
        GameAudio.play_3d("shell_drop", global_position, 0.0, ring * randf_range(0.96, 1.08))
