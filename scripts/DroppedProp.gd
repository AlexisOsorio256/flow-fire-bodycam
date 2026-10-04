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

	var visual: Node3D = source.duplicate() as Node3D
	visual.transform = Transform3D(Basis.IDENTITY.scaled(source.global_basis.get_scale()), Vector3.ZERO)
	visual.visible = true
	_set_world_layers(visual)
	prop.add_child(visual)

	var box := _local_aabb(visual, visual.transform)
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


static func _set_world_layers(root: Node) -> void:
	var stack: Array = [root]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is VisualInstance3D:
			(n as VisualInstance3D).layers = 1
		for c in n.get_children():
			stack.append(c)


static func _local_aabb(node: Node, xf: Transform3D) -> AABB:
	var box := AABB()
	var first := true
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		box = xf * (node as MeshInstance3D).mesh.get_aabb()
		first = false
	for c in node.get_children():
		if c is Node3D:
			var sub := _local_aabb(c, xf * (c as Node3D).transform)
			if sub.size != Vector3.ZERO:
				box = sub if first else box.merge(sub)
				first = false
	return box


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
