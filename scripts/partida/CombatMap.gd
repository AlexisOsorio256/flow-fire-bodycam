extends Node3D

var director: TeamMatch
var posts: Array[Vector3] = []
var spawn := {"pos": Vector3.ZERO, "yaw": 0.0}
var _region: NavigationRegion3D


func spawn_point() -> Dictionary:
	return spawn


func build() -> void:
	for node: Node3D in ($Level as Node3D).get_children():
		_read(node)
	set_mode("duel")
	$Sun.visible = false
	get_viewport().use_occlusion_culling = true
	_cook.call_deferred()


func set_mode(mode: String) -> void:
	var wanted: GDScript = Survival if mode == "survival" else NetMatch if mode == "local" else TeamMatch
	if director != null and director.get_script() == wanted:
		return
	if director != null:
		director.stop()
		director.queue_free()
	director = wanted.new()
	director.name = "Director_" + mode
	director.posts = posts
	add_child(director)
	director.nav_map = get_world_3d().navigation_map


func clear() -> void:
	director.stop()


func _read(node: Node3D) -> void:
	var tag := String(node.name)
	if tag == "player_spawn":
		spawn = {"pos": node.global_position, "yaw": node.global_rotation.y}
	elif tag.begins_with("post_"):
		posts.append(node.global_position)


func _cook() -> void:
	if is_instance_valid(_region):
		return
	_region = NavigationRegion3D.new()
	var nav := NavigationMesh.new()
	nav.agent_radius = Enemy.NAV_RADIUS
	nav.agent_height = 1.87
	nav.agent_max_climb = 0.34
	nav.cell_size = 0.17
	nav.cell_height = 0.17
	nav.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav.geometry_collision_mask = 1
	nav.filter_baking_aabb = AABB(Vector3(-60, -1, -60), Vector3(120, 3, 120))
	_region.navigation_mesh = nav
	add_child(_region)
	NavigationServer3D.map_set_cell_size(get_world_3d().navigation_map, nav.cell_size)
	NavigationServer3D.map_set_cell_height(get_world_3d().navigation_map, nav.cell_height)
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nav, src, self)
	NavigationServer3D.bake_from_source_geometry_data(nav, src)
