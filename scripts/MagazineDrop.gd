class_name MagazineDrop
extends RigidBody3D

## Cargador vacio que cae: cuerpo fisico con la malla del arma; su propio
## contacto dispara el sonido.

const MASS_EMPTY := 0.071
const MASS_PER_ROUND := 0.012
const BOUNCE := 0.28
const FRICTION := 0.55
const PING_SPEED := 0.45
const LIFE := 20.0

var life := 0.0
var last_ping := -1.0


static func spawn(scene: Node, source: Node3D, velocity: Vector3, spin: Vector3, rounds := 0) -> MagazineDrop:
	var mag := MagazineDrop.new()
	mag.name = "MagazineDrop"
	mag.mass = MASS_EMPTY + maxf(0.0, float(rounds)) * MASS_PER_ROUND
	mag.collision_layer = 32   # restos: chocan con el mundo, no con balas ni actores
	mag.collision_mask = 1
	mag.continuous_cd = true

	var scale: Vector3 = source.global_transform.basis.get_scale()
	var visual: Node3D = source.duplicate() as Node3D
	visual.transform = Transform3D(Basis.IDENTITY.scaled(scale), Vector3.ZERO)
	visual.visible = true
	_set_world_layers(visual)
	mag.add_child(visual)

	scene.add_child(mag)
	mag.global_transform = source.global_transform
	mag.reset_physics_interpolation()

	var box: AABB = _visual_aabb(visual)
	var shape := BoxShape3D.new()
	shape.size = box.size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = box.get_center()
	mag.add_child(collider)

	var material := PhysicsMaterial.new()
	material.bounce = BOUNCE
	material.friction = FRICTION
	mag.physics_material_override = material
	mag.linear_damp = 0.08
	mag.angular_damp = 0.30

	mag.linear_velocity = velocity
	mag.angular_velocity = spin
	return mag


static func _set_world_layers(root: Node) -> void:
	var stack: Array = [root]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is VisualInstance3D:
			(n as VisualInstance3D).layers = 1
		for c in n.get_children():
			stack.append(c)


static func _visual_aabb(root: Node) -> AABB:
	var box := AABB()
	var first := true
	var stack: Array = [root]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			var world_box: AABB = (n as Node3D).global_transform * (n as MeshInstance3D).mesh.get_aabb()
			box = world_box if first else box.merge(world_box)
			first = false
		for c in n.get_children():
			stack.append(c)
	return box


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	life += delta
	if life > LIFE:
		queue_free()


func _on_body_entered(_body: Node) -> void:
	if life < 0.04:
		return
	var speed := linear_velocity.length()
	if speed < PING_SPEED:
		return
	if life - last_ping < 0.12:
		return
	last_ping = life
	var db := clampf(-6.0 + speed * 1.2, -6.0, 2.0)
	GameAudio.play_3d("mag_drop", global_position, db, randf_range(0.92, 1.08) + speed * 0.01)
