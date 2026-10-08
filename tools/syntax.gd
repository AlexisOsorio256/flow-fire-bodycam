extends SceneTree

var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_check()
	return true


func _check() -> void:
	var paths := _scripts()
	var bad := 0
	for path in paths:
		var res := ResourceLoader.load(path, "GDScript")
		if res == null:
			bad += 1
			print("SINTAXIS falla: %s" % path)
	print("SINTAXIS %s (%d scripts)" % ["ok" if bad == 0 else "falla", paths.size()])
	quit(1 if bad > 0 else 0)


func _scripts() -> Array:
	var out := []
	var stack := ["res://scripts", "res://tools", "res://addons"]
	while not stack.is_empty():
		var dir := DirAccess.open(stack.pop_back())
		if dir == null:
			continue
		for entry in dir.get_files():
			if entry.ends_with(".gd"):
				out.append(dir.get_current_dir() + "/" + entry)
		for sub in dir.get_directories():
			if not sub.begins_with("."):
				stack.append(dir.get_current_dir() + "/" + sub)
	out.sort()
	return out
