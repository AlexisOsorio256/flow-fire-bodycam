extends SceneTree

const RAW_PATH := "res://downloads/models/mark23_viewmodel_raw.glb"
const OUT_PATH := "res://assets/models/mark23_viewmodel.glb"

func _build_cylinder_z(radius: float, length: float, segments: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_len := length * 0.5
	for i in range(segments):
		var a0 := (float(i) / segments) * TAU
		var a1 := (float(i + 1) / segments) * TAU
		var x0 := cos(a0) * radius
		var y0 := sin(a0) * radius
		var x1 := cos(a1) * radius
		var y1 := sin(a1) * radius

		# Front cap (at -half_len, muzzle end pointing -Z)
		st.set_normal(Vector3(0, 0, -1))
		st.add_vertex(Vector3(0, 0, -half_len))
		st.add_vertex(Vector3(x0, y0, -half_len))
		st.add_vertex(Vector3(x1, y1, -half_len))

		# Back cap (at +half_len, breech end pointing +Z)
		st.set_normal(Vector3(0, 0, 1))
		st.add_vertex(Vector3(0, 0, half_len))
		st.add_vertex(Vector3(x1, y1, half_len))
		st.add_vertex(Vector3(x0, y0, half_len))

		# Tube quads
		var n0 := Vector3(cos(a0), sin(a0), 0)
		var n1 := Vector3(cos(a1), sin(a1), 0)
		st.set_normal(n0); st.add_vertex(Vector3(x0, y0, -half_len))
		st.set_normal(n1); st.add_vertex(Vector3(x1, y1, -half_len))
		st.set_normal(n1); st.add_vertex(Vector3(x1, y1, half_len))

		st.set_normal(n0); st.add_vertex(Vector3(x0, y0, -half_len))
		st.set_normal(n1); st.add_vertex(Vector3(x1, y1, half_len))
		st.set_normal(n0); st.add_vertex(Vector3(x0, y0, half_len))
	return st.commit()

func _init() -> void:
	var packed := load(RAW_PATH) as PackedScene
	if packed == null:
		push_error("build_mark23: no se pudo cargar raw GLB")
		quit(1)
		return
	var inst: Node3D = packed.instantiate()

	var skeleton: Skeleton3D = null
	for c in inst.find_children("*", "", true, false):
		if c is Skeleton3D:
			skeleton = c
			break
	if skeleton == null:
		push_error("build_mark23: falta Skeleton3D")
		quit(1)
		return

	var bone_idx := skeleton.find_bone("main_j_050")
	var pivot: Vector3 = skeleton.get_bone_global_pose(bone_idx).origin

	inst.rotation_degrees = Vector3(0, 180, 0)
	inst.scale = Vector3(0.01, 0.01, 0.01)
	inst.position = - (Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO) * (pivot * 0.01))

	var to_remove: Array[Node] = []
	var arms_mesh: MeshInstance3D = null
	for c in inst.find_children("*", "", true, false):
		if c is MeshInstance3D:
			var mname: String = c.name
			if "main_Mark23" in mname or mname == "Object_9":
				c.name = "Frame_Mesh"
			elif "Side_Mark23" in mname or mname == "Object_10":
				c.name = "Slide_Mesh"
			elif "mag_Mark23" in mname or mname == "Object_11":
				c.name = "Magazine"
			elif "Glove" in mname or mname == "Object_8":
				c.name = "Arms"
				arms_mesh = c
			elif "Hand_D" in mname or mname == "Object_7" or "Icosphere" in mname:
				to_remove.append(c)
		elif c is Node3D and c != skeleton and c != inst:
			if c.name in ["Object_6", "Hand_Mesh", "Side", "main", "mag"]:
				to_remove.append(c)

	for node in to_remove:
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
			node.queue_free()

	if arms_mesh != null:
		for s in range(arms_mesh.mesh.get_surface_count()):
			var orig_mat := arms_mesh.mesh.surface_get_material(s)
			if orig_mat is StandardMaterial3D:
				var sm := orig_mat.duplicate() as StandardMaterial3D
				sm.albedo_color = Color(0.22, 0.22, 0.22, 1.0)
				arms_mesh.set_surface_override_material(s, sm)

	# Create clean root scene in meters
	var root_scene := Node3D.new()
	root_scene.name = "Mark23_Viewmodel"
	root_scene.add_child(inst)

	# Landmarks in world space (meters, +Y up, -Z fwd, origin at main_j_050)
	var muzzle_pos := Vector3(-0.0032, 0.0894, -0.2138)
	var barrel_pos := Vector3(-0.0032, 0.0894, -0.0686)
	var sight_front_pos := Vector3(-0.0032, 0.1122, -0.1872)
	var sight_rear_pos := Vector3(-0.0038, 0.1124, 0.0212)
	var ejection_port_pos := Vector3(0.0109, 0.0908, -0.0686)
	var grip_pos := Vector3(-0.0015, -0.0248, 0.0098)
	var magwell_pos := Vector3(-0.0030, -0.0496, 0.0196)
	var trigger_pos := Vector3(-0.0032, 0.0450, -0.0450)

	var barrel_len := barrel_pos.distance_to(muzzle_pos)
	var barrel_center := (barrel_pos + muzzle_pos) * 0.5

	# 1. Frame Node3D
	var frame_node := Node3D.new()
	frame_node.name = "Frame"
	frame_node.position = Vector3.ZERO
	root_scene.add_child(frame_node)

	# 2. Barrel under Frame (oriented along Z with identity basis)
	var barrel_inst := MeshInstance3D.new()
	barrel_inst.name = "Barrel"
	barrel_inst.mesh = _build_cylinder_z(0.0078, barrel_len, 16)
	barrel_inst.position = barrel_center
	frame_node.add_child(barrel_inst)

	var muzzle_socket := Node3D.new()
	muzzle_socket.name = "Muzzle"
	muzzle_socket.position = Vector3(0, 0, -barrel_len * 0.5)
	barrel_inst.add_child(muzzle_socket)

	# 3. Trigger under Frame
	var trigger_mesh := CylinderMesh.new()
	trigger_mesh.top_radius = 0.0032
	trigger_mesh.bottom_radius = 0.0032
	trigger_mesh.height = 0.0220
	trigger_mesh.radial_segments = 12

	var trigger_inst := MeshInstance3D.new()
	trigger_inst.name = "Trigger"
	trigger_inst.mesh = trigger_mesh
	trigger_inst.position = trigger_pos
	frame_node.add_child(trigger_inst)

	# 4. Grip and Magwell under Frame
	var grip_socket := Node3D.new()
	grip_socket.name = "Grip"
	grip_socket.position = grip_pos
	frame_node.add_child(grip_socket)

	var magwell_socket := Node3D.new()
	magwell_socket.name = "Magwell"
	magwell_socket.position = magwell_pos
	frame_node.add_child(magwell_socket)

	# 5. Slide Node3D under root_scene
	var slide_node := Node3D.new()
	slide_node.name = "Slide"
	slide_node.position = Vector3.ZERO
	root_scene.add_child(slide_node)

	var sight_front_socket := Node3D.new()
	sight_front_socket.name = "SightFront"
	sight_front_socket.position = sight_front_pos
	slide_node.add_child(sight_front_socket)

	var sight_rear_socket := Node3D.new()
	sight_rear_socket.name = "SightRear"
	sight_rear_socket.position = sight_rear_pos
	slide_node.add_child(sight_rear_socket)

	var ejection_port_socket := Node3D.new()
	ejection_port_socket.name = "EjectionPort"
	ejection_port_socket.position = ejection_port_pos
	slide_node.add_child(ejection_port_socket)

	# Export canonical GLB
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	state.handle_binary_image_mode = GLTFState.HANDLE_BINARY_IMAGE_MODE_EMBED_AS_UNCOMPRESSED
	var err := doc.append_from_scene(root_scene, state)
	if err != OK:
		push_error("Error append_from_scene: " + str(err))
		quit(1)
		return
	err = doc.write_to_filesystem(state, OUT_PATH)
	if err != OK:
		push_error("Error write_to_filesystem: " + str(err))
		quit(1)
		return

	print("SUCCESS: canonical GLB exportado a ", OUT_PATH)
	quit(0)
