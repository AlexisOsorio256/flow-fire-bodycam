class_name Nodes
extends RefCounted


static func each(host: Node, act: Callable) -> void:
	var stack: Array = [host]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		act.call(n)
		for c in n.get_children():
			stack.append(c)


static func paint(host: Node, bits: int) -> void:
	each(host, func(n: Node) -> void:
		if n is VisualInstance3D:
			(n as VisualInstance3D).layers = bits)


static func first(host: Node, wanted: String) -> Node:
	if host.name == wanted:
		return host
	for child in host.get_children():
		var found := first(child, wanted)
		if found != null:
			return found
	return null


static func aabb(host: Node3D, at := Transform3D.IDENTITY) -> AABB:
	var box := AABB()
	var stack: Array = [[at, host]]
	var made := false
	while not stack.is_empty():
		var it: Array = stack.pop_back()
		var xf: Transform3D = it[0]
		var n: Node3D = it[1]
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			var part := xf * (n as MeshInstance3D).mesh.get_aabb()
			box = part if not made else box.merge(part)
			made = true
		for c in n.get_children():
			if c is Node3D:
				stack.append([xf * (c as Node3D).transform, c])
	return box


static func verts(host: Node3D, at := Transform3D.IDENTITY, skip: Node = null) -> PackedVector3Array:
	var out := PackedVector3Array()
	var stack: Array = [[at, host]]
	while not stack.is_empty():
		var it: Array = stack.pop_back()
		var xf: Transform3D = it[0]
		var n: Node3D = it[1]
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null and n != skip:
			var mi := n as MeshInstance3D
			for s in mi.mesh.get_surface_count():
				for v in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
					out.append(xf * v)
		for c in n.get_children():
			if c is Node3D and c != skip:
				stack.append([xf * (c as Node3D).transform, c])
	return out
