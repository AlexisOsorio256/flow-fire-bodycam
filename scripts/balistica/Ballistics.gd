extends Node3D

const PROJECTILE_MASS := 0.00745
const DRAG_K := 0.00142
const GRAVITY := 9.81
const MAX_DISTANCE := 520.0
const COLLISION_MASK := 1 | Player.LAYER | Enemy.HITBOX_LAYER
const PENETRATION_EPSILON := 0.0015
const EXIT_SPEED_MIN := 75.0

var bullets: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func fire(origin: Vector3, direction: Vector3, speed: float, shooter: Node3D, harmless := false) -> void:
	var dir := direction.normalized()
	var exclude: Array[RID] = []
	if shooter is Enemy:
		exclude = (shooter as Enemy).hitbox_rids
	elif shooter is CollisionObject3D:
		exclude = [(shooter as CollisionObject3D).get_rid()]
	get_tree().call_group("enemy", "hear", origin, shooter)
	var b := {
		"active": true,
		"pos": origin + dir * 0.004,
		"vel": dir * speed,
		"life": 0.0,
		"distance": 0.0,
		"penetrations": 0,
		"ricochets": 0,
		"flyby": false,
		"charged": [],
		"shooter": shooter,
		"harmless": harmless,
		"exclude": exclude,
	}
	bullets.append(b)


func _physics_process(delta: float) -> void:
	if bullets.is_empty():
		return
	var space := get_world_3d().direct_space_state
	for i in range(bullets.size() - 1, -1, -1):
		var b: Dictionary = bullets[i]
		if not b.active:
			bullets.remove_at(i)
			continue

		b.life += delta
		if not b.flyby and _passes_near_player(b):
			b.flyby = true
			GameAudio.play_3d("bullet_flyby", _closest_point(b), -4.0, randf_range(0.94, 1.08))
			get_tree().call_group("player", "suppress", 0.7)
		if b.vel.length() < 45.0:
			b.active = false
		else:
			_step_bullet(b, delta, space)

		if b.life > 2.2 or b.distance > MAX_DISTANCE:
			b.active = false


func _step_bullet(b: Dictionary, h: float, space: PhysicsDirectSpaceState3D) -> void:
	var speed: float = b.vel.length()
	var accel: Vector3 = b.vel * (-DRAG_K * speed) + Vector3.DOWN * GRAVITY
	b.vel = b.vel + accel * h
	var delta_pos: Vector3 = b.vel * h
	var dist: float = delta_pos.length()
	if dist < 0.00001:
		return
	var dir: Vector3 = delta_pos / dist
	var query := PhysicsRayQueryParameters3D.create(b.pos, b.pos + delta_pos, COLLISION_MASK, b.exclude)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.hit_from_inside = true
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		b.pos = b.pos + delta_pos
		b.distance += dist
		return

	var point: Vector3 = hit.position
	var collider: Object = hit.collider
	var normal: Vector3 = hit.normal
	if normal.length_squared() < 0.5:
		normal = -dir
	else:
		normal = normal.normalized()
	b.distance += point.distance_to(b.pos)
	var surface := ""
	var penetrable := false
	var thin_shell := false
	var wall_thickness := 0.0
	if collider is Node:
		surface = str(collider.get_meta("surface", ""))
		penetrable = bool(collider.get_meta("penetrable", false))
		thin_shell = bool(collider.get_meta("thin_shell", false))
		wall_thickness = float(collider.get_meta("wall_thickness", 0.0))
	var p_in: float = PROJECTILE_MASS * speed
	var shooter: Node3D = b.shooter if is_instance_valid(b.shooter) else null
	if collider is PhysicalBone3D and (collider as Node).has_meta("actor"):
		b.active = false
		var actor: Enemy = (collider as Node).get_meta("actor")
		var bone: String = (collider as PhysicalBone3D).bone_name
		if b.harmless:
			return
		if actor.is_alive() and is_instance_valid(shooter) and actor.team != shooter.team:
			actor.hit(point, dir, p_in, bone, shooter)
		elif not actor.is_alive():
			actor.shove(point, dir, p_in, bone)
		return
	if collider is Player:
		b.active = false
		if not b.harmless and is_instance_valid(shooter) and shooter.team != (collider as Player).team:
			(collider as Player).hit(point, dir, p_in, shooter)
		return
	if not ImpactProfiles.SURFACES.has(surface):
		push_error("Colision balistica sin perfil de superficie: " + str(collider))
		_push_body(collider, point, dir, p_in)
		b.active = false
		return
	var penetration_resistance: float = ImpactProfiles.SURFACES[surface]["resistance"]
	var hit_shape := int(hit.get("shape", -1))
	var already_charged := false
	var body_id := 0
	if collider is RigidBody3D:
		body_id = (collider as Node).get_instance_id()
		already_charged = (b.charged as Array).has(body_id)

	if penetrable:
		var exit := ShapeExit.find(point, dir, collider, hit_shape)
		var thickness: float = exit.get("distance", 0.0)
		if exit.is_empty() and already_charged:
			b.pos = point + dir * PENETRATION_EPSILON
			b.distance += PENETRATION_EPSILON
			return
		if thin_shell and thickness > PENETRATION_EPSILON:
			thickness = 2.0 * wall_thickness / maxf(absf(dir.dot(normal)), 0.3) if wall_thickness > 0.0 else 0.0
		if thickness <= PENETRATION_EPSILON:
			_stop(b, point, normal, collider, surface, dir, p_in, already_charged)
			return
		var retained_energy := exp(-penetration_resistance * thickness)
		var exit_speed := speed * sqrt(retained_energy)
		if exit_speed < EXIT_SPEED_MIN:
			if not already_charged and surface == "pine":
				ImpactFX.spawn_embedded(point, dir, collider)
			_stop(b, point, normal, collider, surface, dir, p_in, already_charged)
			if _try_ricochet(b, point, normal, surface, speed, true):
				b.active = true
			return
		var exit_point: Vector3 = exit["point"]
		var geometric_thickness: float = exit["distance"]
		ImpactFX.spawn_impact(point, normal, collider, surface, false)
		ImpactFX.spawn_impact(exit_point, exit["normal"], collider, surface, true)
		b.pos = exit_point + dir * PENETRATION_EPSILON
		b.distance += geometric_thickness + PENETRATION_EPSILON
		if already_charged:
			return
		_push_body(collider, point, dir, p_in - PROJECTILE_MASS * exit_speed)
		if collider is RigidBody3D:
			(b.charged as Array).append(body_id)
		b.vel *= sqrt(retained_energy)
		b.penetrations += 1
		if b.penetrations > 4:
			b.active = false
		return

	ImpactFX.spawn_impact(point, normal, collider, surface, false)
	_push_body(collider, point, dir, p_in)
	if _try_ricochet(b, point, normal, surface, speed):
		return

	b.active = false


func _stop(b: Dictionary, point: Vector3, normal: Vector3, collider: Object, surface: String, dir: Vector3,
		p_in: float, already_charged: bool) -> void:
	if not already_charged:
		ImpactFX.spawn_impact(point, normal, collider, surface, false)
		_push_body(collider, point, dir, p_in)
	b.active = false


func _try_ricochet(b: Dictionary, point: Vector3, normal: Vector3, surface: String, speed: float, force := false) -> bool:
	var n := normal.normalized()
	var dir: Vector3 = (b.vel as Vector3).normalized()
	if (force or absf(dir.dot(n)) < 0.31) and speed > 110.0 and int(b.ricochets) < 2 \
			and (surface == "steel" or surface == "concrete" or surface == "aluminum"):
		var reflected: Vector3 = b.vel - 2.0 * (b.vel as Vector3).dot(n) * n
		reflected = reflected.normalized()
		var h := float(absi(int(point.x * 1000.0) * 374761393 + int(point.y * 1000.0) * 668265263 + int(point.z * 1000.0) * 1274126177) % 1000) / 1000.0
		b.vel = reflected * speed * (0.50 + h * 0.06)
		b.pos = point + reflected * 0.012
		b.ricochets = int(b.ricochets) + 1
		GameAudio.play_3d("ricochet", point, 0.0, randf_range(0.9, 1.1))
		return true
	return false


func _push_body(collider: Object, point: Vector3, dir: Vector3, impulse: float) -> void:
	if not collider is RigidBody3D:
		return
	var body := collider as RigidBody3D
	if impulse <= 0.0:
		return
	body.apply_impulse(dir.normalized() * impulse, point - body.global_position)


func _closest_point(b: Dictionary) -> Vector3:
	var eye := _listener_position()
	var dir: Vector3 = b.vel.normalized()
	var to_bullet: Vector3 = b.pos - eye
	var along: float = to_bullet.dot(dir)
	return b.pos + dir * maxf(0.0, -along)


func _passes_near_player(b: Dictionary) -> bool:
	if not _has_listener():
		return false
	var eye := _listener_position()
	var dir: Vector3 = b.vel.normalized()
	var to_bullet: Vector3 = b.pos - eye
	var along: float = to_bullet.dot(dir)
	if along > 0.0:
		return false
	var closest: Vector3 = b.pos + dir * (-along)
	return closest.distance_to(eye) < 1.1


func _has_listener() -> bool:
	var viewport := get_viewport()
	return viewport != null and viewport.get_camera_3d() != null


func _listener_position() -> Vector3:
	return get_viewport().get_camera_3d().global_position
