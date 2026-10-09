class_name DroppedProp
extends RigidBody3D

const BOUNCE := 0.28
const FRICTION := 0.55
const PING_SPEED := 0.45

var life := 0.0
var lifetime := 0.0
var sound := ""
var last_ping := -1.0


static func spawn(scene: Node, source: Node3D, kg: float, velocity: Vector3, spin: Vector3,
		sound_name: String, lifetime_s := 0.0) -> DroppedProp:
	var prop := DroppedProp.new()
	prop.name = "DroppedProp"
	prop.mass = kg
	prop.sound = sound_name
	prop.lifetime = lifetime_s
	prop.collision_layer = 32
	prop.collision_mask = 1
	prop.continuous_cd = true

	var visual := _visual_copy(source)
	visual.transform = Transform3D(Basis.IDENTITY.scaled(source.global_basis.get_scale()), Vector3.ZERO)
	visual.visible = true
	Nodes.paint(visual, 1)
	prop.add_child(visual)

	var box := Nodes.aabb(visual, visual.transform)
	var shape := BoxShape3D.new()
	shape.size = box.size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = box.get_center()
	prop.add_child(collider)

	var material := PhysicsMaterial.new()
	material.bounce = BOUNCE
	material.friction = FRICTION
	prop.physics_material_override = material
	prop.linear_damp = 0.08
	prop.angular_damp = 0.30

	scene.add_child(prop)
	prop.global_transform = Transform3D(source.global_basis.orthonormalized(), source.global_position)
	prop.reset_physics_interpolation()
	prop.linear_velocity = velocity
	prop.angular_velocity = spin
	return prop


static func _visual_copy(source: Node3D) -> Node3D:
	var node: Node3D
	if source is MeshInstance3D:
		var mesh := MeshInstance3D.new()
		mesh.material_override = source.material_override
		mesh.mesh = source.mesh
		for i in mesh.mesh.get_surface_count():
			var material: Material = source.get_surface_override_material(i)
			if material != null:
				mesh.set_surface_override_material(i, material)
		node = mesh
	else:
		node = Node3D.new()
	node.name = source.name
	node.transform = source.transform
	node.visible = source.visible
	for child in source.get_children():
		if child is Node3D and not child is WeaponFX and not child is Light3D:
			node.add_child(_visual_copy(child))
	return node


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	life += delta
	if lifetime > 0.0 and life > lifetime:
		queue_free()


func _on_body_entered(_body: Node) -> void:
	if life < 0.04:
		return
	var speed := linear_velocity.length()
	if speed < PING_SPEED or life - last_ping < 0.12:
		return
	last_ping = life
	var db := clampf(-6.0 + speed * 1.2, -6.0, 2.0)
	GameAudio.play_3d(sound, global_position, db, randf_range(0.92, 1.08) + speed * 0.01)
