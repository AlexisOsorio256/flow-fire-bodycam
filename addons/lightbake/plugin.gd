@tool
extends EditorPlugin

const SCENES := ["res://scenes/Patio.tscn", "res://scenes/Callejones.tscn"]
const LAMP := {"energy": 14.0, "range": 14.0, "angle": 75.0}
const TIMEOUT_S := 1800


func _enter_tree() -> void:
	if OS.get_cmdline_user_args().has("--bake-lightmaps"):
		_bake_all.call_deferred()


func _bake_all() -> void:
	await get_tree().create_timer(3.0).timeout
	for path in _requested():
		await _bake(path)
	get_tree().quit()


func _requested() -> Array:
	var asked := []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("res://"):
			asked.append(arg)
	return asked if not asked.is_empty() else SCENES


func _bake(path: String) -> void:
	EditorInterface.open_scene_from_path(path)
	EditorInterface.set_main_screen_editor("3D")
	await get_tree().create_timer(2.0).timeout
	var root := EditorInterface.get_edited_scene_root()
	var gi := root.find_children("*", "LightmapGI", true, false).front() as LightmapGI
	var lamps := _lamps(root, LAMP["energy"])
	var data_path := path.get_basename() + ".lmbake"
	var before := FileAccess.get_modified_time(data_path)
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(gi)
	var pressed := false
	for attempt in 30:
		await get_tree().create_timer(1.0).timeout
		pressed = _press_bake()
		if pressed:
			break
	if not pressed:
		push_error("lightbake: no encuentro el boton de horneado")
		return
	await get_tree().create_timer(1.0).timeout
	for w: Window in get_tree().root.find_children("*", "EditorFileDialog", true, false):
		if w.visible:
			w.hide()
			w.file_selected.emit(data_path)
	var waited := 0
	while FileAccess.get_modified_time(data_path) == before and waited < TIMEOUT_S:
		await get_tree().create_timer(1.0).timeout
		waited += 1
	await get_tree().create_timer(2.0).timeout
	if before == 0:
		for lamp in lamps:
			lamp.owner = null
			root.remove_child(lamp)
		EditorInterface.save_scene()
	print("HORNEADO ", path)


func _lamps(root: Node, energy: float) -> Array[Node]:
	var made: Array[Node] = []
	for marker: Node3D in root.find_children("lamp_*", "Node3D", true, false):
		if marker is MeshInstance3D:
			continue
		var spot := SpotLight3D.new()
		spot.light_bake_mode = Light3D.BAKE_STATIC
		spot.light_energy = energy
		spot.spot_range = LAMP["range"]
		spot.spot_angle = LAMP["angle"]
		spot.light_color = Color(1.0, 0.96, 0.9)
		spot.shadow_enabled = true
		root.add_child(spot)
		spot.owner = root
		spot.global_transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), marker.global_position)
		made.append(spot)
	return made


func _press_bake() -> bool:
	for b: Button in EditorInterface.get_base_control().find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and b.text.ends_with("Lightmaps"):
			b.pressed.emit()
			return true
	return false
