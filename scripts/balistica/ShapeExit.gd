class_name ShapeExit
extends RefCounted

const EPSILON := 0.0015


static func find(entry: Vector3, direction: Vector3, collider: Object, hit_shape := -1) -> Dictionary:
	if not collider is CollisionObject3D:
		return {}
	var body := collider as CollisionObject3D
	var shape_id := 0
	for owner_id in body.get_shape_owners():
		var shape_transform: Transform3D = body.global_transform * body.shape_owner_get_transform(owner_id)
		for shape_index in range(body.shape_owner_get_shape_count(owner_id)):
			if hit_shape >= 0 and shape_id != hit_shape:
				shape_id += 1
				continue
			var shape := body.shape_owner_get_shape(owner_id, shape_index)
			var hit := _exit_of_shape(shape, shape_transform, entry, direction)
			shape_id += 1
			if hit.is_empty():
				continue
			var distance: float = hit["distance"]
			if distance <= EPSILON:
				continue
			return hit
	return {}


static func _exit_of_shape(shape: Shape3D, shape_transform: Transform3D, entry: Vector3, direction: Vector3) -> Dictionary:
	var inv := shape_transform.affine_inverse()
	var local_entry := inv * entry
	var local_direction := (inv * (entry + direction)) - local_entry
	if shape is BoxShape3D:
		return _exit_box(shape as BoxShape3D, shape_transform, entry, local_entry, local_direction)
	if shape is CylinderShape3D:
		return _exit_cylinder(shape as CylinderShape3D, shape_transform, entry, local_entry, local_direction)
	if shape is SphereShape3D:
		return _exit_sphere(shape as SphereShape3D, shape_transform, entry, local_entry, local_direction)
	return {}


static func _exit_point(shape_transform: Transform3D, entry: Vector3, local_entry: Vector3,
		local_direction: Vector3, t: float, local_normal: Vector3) -> Dictionary:
	if t <= 0.0:
		return {}
	var world_exit: Vector3 = shape_transform * (local_entry + local_direction * t)
	return {
		"point": world_exit,
		"normal": (shape_transform.basis * local_normal).normalized(),
		"distance": entry.distance_to(world_exit),
	}


static func _exit_box(box: BoxShape3D, shape_transform: Transform3D, entry: Vector3,
		local_entry: Vector3, local_direction: Vector3) -> Dictionary:
	var half := box.size * 0.5
	var t_near := -INF
	var t_far := INF
	for axis in 3:
		var origin_axis := local_entry[axis]
		var direction_axis := local_direction[axis]
		if absf(direction_axis) < 0.000001:
			if absf(origin_axis) > half[axis] + EPSILON:
				return {}
			continue
		var t1 := (-half[axis] - origin_axis) / direction_axis
		var t2 := (half[axis] - origin_axis) / direction_axis
		t_near = maxf(t_near, minf(t1, t2))
		t_far = minf(t_far, maxf(t1, t2))
	if t_far <= EPSILON or t_far <= t_near:
		return {}
	if t_near > EPSILON * 4.0:
		return {}
	var local_exit := local_entry + local_direction * t_far
	var exit_axis := 0
	var axis_error := absf(absf(local_exit.x) - half.x)
	var y_error := absf(absf(local_exit.y) - half.y)
	var z_error := absf(absf(local_exit.z) - half.z)
	if y_error < axis_error:
		exit_axis = 1
		axis_error = y_error
	if z_error < axis_error:
		exit_axis = 2
	var local_normal := Vector3.ZERO
	local_normal[exit_axis] = 1.0 if local_exit[exit_axis] >= 0.0 else -1.0
	return _exit_point(shape_transform, entry, local_entry, local_direction, t_far, local_normal)


static func _exit_cylinder(cyl: CylinderShape3D, shape_transform: Transform3D, entry: Vector3,
		local_entry: Vector3, local_direction: Vector3) -> Dictionary:
	var radius := cyl.radius
	var half_h := cyl.height * 0.5
	var epsilon := 0.000001
	var best_t := -INF
	var best_normal := Vector3.ZERO
	var a := local_direction.x * local_direction.x + local_direction.z * local_direction.z
	if a > epsilon:
		var b := 2.0 * (local_entry.x * local_direction.x + local_entry.z * local_direction.z)
		var c := local_entry.x * local_entry.x + local_entry.z * local_entry.z - radius * radius
		var disc := b * b - 4.0 * a * c
		if disc >= 0.0:
			var sq := sqrt(disc)
			var candidates: Array[float] = [(-b - sq) / (2.0 * a), (-b + sq) / (2.0 * a)]
			for t: float in candidates:
				var y := local_entry.y + local_direction.y * t
				if absf(y) <= half_h + epsilon and t > best_t:
					best_t = t
					best_normal = Vector3(
						local_entry.x + local_direction.x * t, 0.0,
						local_entry.z + local_direction.z * t).normalized()
	if absf(local_direction.y) > epsilon:
		for sign_y: float in [1.0, -1.0]:
			var t := (sign_y * half_h - local_entry.y) / local_direction.y
			var px := local_entry.x + local_direction.x * t
			var pz := local_entry.z + local_direction.z * t
			if px * px + pz * pz <= radius * radius + epsilon and t > best_t:
				best_t = t
				best_normal = Vector3(0.0, sign_y, 0.0)
	return _exit_point(shape_transform, entry, local_entry, local_direction, best_t, best_normal)


static func _exit_sphere(sphere: SphereShape3D, shape_transform: Transform3D, entry: Vector3,
		local_entry: Vector3, local_direction: Vector3) -> Dictionary:
	var a := local_direction.dot(local_direction)
	if a < 0.0000000001:
		return {}
	var b := 2.0 * local_entry.dot(local_direction)
	var c := local_entry.dot(local_entry) - sphere.radius * sphere.radius
	var disc := b * b - 4.0 * a * c
	if disc < 0.0:
		return {}
	var t := (-b + sqrt(disc)) / (2.0 * a)
	return _exit_point(shape_transform, entry, local_entry, local_direction, t,
		(local_entry + local_direction * t).normalized())
