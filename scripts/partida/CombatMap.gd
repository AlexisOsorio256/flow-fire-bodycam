extends Node3D

var director: TeamMatch
var posts: Array[Vector3] = []
var homes: Array[Vector3] = []
var _region: NavigationRegion3D


func build() -> void:
	for node: Node3D in ($Level as Node3D).get_children():
		_read(node)
	if _baked():
		$Sun.visible = false
	else:
		$Sun.light_bake_mode = Light3D.BAKE_DISABLED
	get_viewport().use_occlusion_culling = true
	_cook.call_deferred()


func _baked() -> bool:
	var gi := find_child("LightmapGI", false, false) as LightmapGI
	return gi != null and gi.light_data != null


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
	if homes.size() == 2:
		director.homes = homes
	add_child(director)
	director.nav_map = get_world_3d().navigation_map


func clear() -> void:
	if director != null:
		director.stop()


func _read(node: Node3D) -> void:
	if String(node.name).begins_with("post_"):
		posts.append(node.global_position)
	if String(node.name).begins_with("home_"):
		var team := int(String(node.name).get_slice("_", 1))
		homes.resize(maxi(homes.size(), team + 1))
		homes[team] = node.global_position


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
