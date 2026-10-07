class_name RoundMesh
extends RefCounted


static func build(host: Node3D) -> void:
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.96, 0.78, 0.32)
	brass.metallic = 0.92
	brass.roughness = 0.16
	var case_mesh := CylinderMesh.new()
	case_mesh.top_radius = 0.0049
	case_mesh.bottom_radius = 0.0049
	case_mesh.height = 0.01915
	case_mesh.radial_segments = 12
	var case_inst := MeshInstance3D.new()
	case_inst.name = "Case"
	case_inst.mesh = case_mesh
	case_inst.material_override = brass
	case_inst.position = Vector3(0.0, 0.0096, 0.0)
	host.add_child(case_inst)
	var copper := StandardMaterial3D.new()
	copper.albedo_color = Color(0.85, 0.46, 0.22)
	copper.metallic = 0.88
	copper.roughness = 0.22
	var nose_mesh := CylinderMesh.new()
	nose_mesh.top_radius = 0.0028
	nose_mesh.bottom_radius = 0.0045
	nose_mesh.height = 0.009
	nose_mesh.radial_segments = 12
	var nose_inst := MeshInstance3D.new()
	nose_inst.name = "Bullet"
	nose_inst.mesh = nose_mesh
	nose_inst.material_override = copper
	nose_inst.position = Vector3(0.0, 0.01915 + 0.0045, 0.0)
	host.add_child(nose_inst)


static func breech_face(part: Node3D, bore: Vector3, axis_point: Vector3, skip: Node) -> Variant:
	var back := -bore
	var verts: Array[Vector3] = []
	var stack: Array = [part]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			var mi := n as MeshInstance3D
			var xform := Transform3D.IDENTITY
			if mi != part:
				xform = mi.transform
				var par := mi.get_parent()
				while par != null and par != part:
					if par is Node3D:
						xform = (par as Node3D).transform * xform
					par = par.get_parent()
			for s in range(mi.mesh.get_surface_count()):
				for v in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
					verts.append(xform * v)
		for c in n.get_children():
			if c != skip:
				stack.append(c)
	if verts.is_empty():
		push_error("GLB de Glock roto: Barrel no tiene vertices para medir la recamara")
		return null
	var deepest := -1e9
	for v in verts:
		deepest = maxf(deepest, v.dot(back))
	return axis_point + back * (deepest - axis_point.dot(back) + 0.001)
