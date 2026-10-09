class_name RoundMesh
extends RefCounted


static func build(host: Node3D, caliber := "9mm") -> void:
	var dims := Shell.dims_of(caliber)
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.96, 0.78, 0.32)
	brass.metallic = 0.92
	brass.roughness = 0.16
	var case_mesh := CylinderMesh.new()
	case_mesh.top_radius = dims["rad"]
	case_mesh.bottom_radius = dims["rad"]
	case_mesh.height = dims["len"]
	case_mesh.radial_segments = 12
	var case_inst := MeshInstance3D.new()
	case_inst.name = "Case"
	case_inst.mesh = case_mesh
	case_inst.material_override = brass
	case_inst.position = Vector3(0.0, dims["len"] * 0.5, 0.0)
	host.add_child(case_inst)
	if not dims.has("nose_top"):
		return
	var copper := StandardMaterial3D.new()
	copper.albedo_color = Color(0.85, 0.46, 0.22)
	copper.metallic = 0.88
	copper.roughness = 0.22
	var nose_mesh := CylinderMesh.new()
	nose_mesh.top_radius = dims["nose_top"]
	nose_mesh.bottom_radius = dims["nose_bottom"]
	nose_mesh.height = dims["nose_len"]
	nose_mesh.radial_segments = 12
	var nose_inst := MeshInstance3D.new()
	nose_inst.name = "Bullet"
	nose_inst.mesh = nose_mesh
	nose_inst.material_override = copper
	nose_inst.position = Vector3(0.0, dims["len"] + dims["nose_len"] * 0.5, 0.0)
	host.add_child(nose_inst)


static func breech_face(part: Node3D, bore: Vector3, axis_point: Vector3, skip: Node) -> Variant:
	var back := -bore
	var deepest := -1e9
	for v in Nodes.verts(part, Transform3D.IDENTITY, skip):
		deepest = maxf(deepest, v.dot(back))
	if deepest == -1e9:
		push_error("GLB de Glock roto: Barrel no tiene vertices para medir la recamara")
		return null
	return axis_point + back * (deepest - axis_point.dot(back) + 0.001)
