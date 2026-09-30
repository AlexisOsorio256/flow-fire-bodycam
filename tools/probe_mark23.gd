extends SceneTree

func _init() -> void:
	var glb_path := "res://assets/models/mark23_viewmodel.glb"
	var scene := load(glb_path) as PackedScene
	if scene == null:
		print("FALLO: no se pudo cargar ", glb_path)
		quit(1)
		return
	var root := scene.instantiate() as Node3D
	if root == null:
		print("FALLO: la raiz no es Node3D")
		quit(1)
		return

	print("=== PROBE MARK 23 ===")
	print("Raiz: ", root.name)

	var skeleton: Skeleton3D = null
	var anim_player: AnimationPlayer = null
	var meshes: Array[MeshInstance3D] = []

	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Skeleton3D and skeleton == null:
			skeleton = node as Skeleton3D
		elif node is AnimationPlayer and anim_player == null:
			anim_player = node as AnimationPlayer
		elif node is MeshInstance3D:
			meshes.append(node as MeshInstance3D)
		for child in node.get_children():
			stack.append(child)

	print("\n--- HUESOS (", 0 if skeleton == null else skeleton.get_bone_count(), ") ---")
	if skeleton != null:
		for i in range(skeleton.get_bone_count()):
			var bname := skeleton.get_bone_name(i)
			var par_idx := skeleton.get_bone_parent(i)
			var par_name := skeleton.get_bone_name(par_idx) if par_idx >= 0 else "None"
			var rest := skeleton.get_bone_rest(i)
			print("  [%2d] %-24s (parent: %-20s) pos=%s" % [i, bname, par_name, rest.origin])

	print("\n--- CLIPS (", 0 if anim_player == null else anim_player.get_animation_list().size(), ") ---")
	if anim_player != null:
		for anim_name in anim_player.get_animation_list():
			var anim := anim_player.get_animation(anim_name)
			print("  Clip: %-20s duracion=%.4f s  pistas=%d" % [anim_name, anim.length, anim.get_track_count()])
			for t in range(anim.get_track_count()):
				var path := str(anim.track_get_path(t))
				if "side" in path or "Mag" in path or "main" in path or "Root" in path:
					print("    track[%d] %s" % [t, path])

	print("\n--- MALLAS (", meshes.size(), ") ---")
	for mi in meshes:
		var m := mi.mesh
		var tris := 0
		var mats: Array[String] = []
		if m != null:
			for s in range(m.get_surface_count()):
				var idx: PackedInt32Array = m.surface_get_arrays(s)[Mesh.ARRAY_INDEX]
				tris += idx.size() / 3
				var mat := mi.get_surface_override_material(s)
				if mat == null:
					mat = m.surface_get_material(s)
				if mat != null:
					mats.append(mat.resource_name if mat.resource_name != "" else mat.get_class())
		var aabb := mi.get_aabb()
		print("  Malla: %-24s tris=%-5d mats=%-15s skin=%s skel=%s aabb_size=%s pos=%s" % [
			mi.name, tris, str(mats), mi.skin != null, mi.skeleton, aabb.size, mi.position
		])

	print("\n--- NODOS Y SOCKETS ---")
	var node_stack: Array[Node] = [root]
	while not node_stack.is_empty():
		var n: Node = node_stack.pop_back()
		if n is Node3D and not (n is Skeleton3D) and not (n is MeshInstance3D):
			var par_name: String = n.get_parent().name if n.get_parent() != null else "None"
			print("  Nodo: %-20s (parent: %-15s) pos=%s" % [n.name, par_name, (n as Node3D).position])
		for c in n.get_children():
			node_stack.append(c)

	print("\n--- CAJAS AABB DE MALLAS DE ARMA ---")
	var weapon_box := AABB()
	var first_box := true
	for mi in meshes:
		if mi.name in ["Frame", "Slide", "Magazine"]:
			var lb: AABB = mi.transform * mi.mesh.get_aabb()
			print("  Pieza: ", mi.name, " size=", lb.size, " pos=", lb.position)
			weapon_box = lb if first_box else weapon_box.merge(lb)
			first_box = false
	print("  Caja total arma: size=", weapon_box.size, " length=", maxf(weapon_box.size.x, maxf(weapon_box.size.y, weapon_box.size.z)))

	root.free()
	quit(0)
