extends SceneTree

var args := {}
var main: Node
var stage := 0
var clock := 0.0
var sample := 0.0
var gpu := 0.0
var cpu := 0.0
var frames := 0
var worst := 0.0


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"


func _override() -> void:
	var env: Environment = main.get_node("WorldEnvironment").environment
	if args.has("ssao"):
		env.ssao_enabled = args["ssao"] == "1"
	if args.has("glow"):
		env.glow_enabled = args["glow"] == "1"
	if args.has("fog"):
		env.fog_enabled = args["fog"] == "1"
	if args.has("post"):
		main.hud.get_child(0).visible = args["post"] == "1"
	if args.has("msaa"):
		root.msaa_3d = int(args["msaa"])
	if args.has("aa"):
		root.screen_space_aa = int(args["aa"])
	if args.has("bias"):
		root.texture_mipmap_bias = float(args["bias"])
	if args.has("scale"):
		root.scaling_3d_scale = float(args["scale"])
	if args.has("lod"):
		root.mesh_lod_threshold = float(args["lod"])
	if args.has("aniso"):
		_dress(main.map.get_node("Level"), int(args["aniso"]))


func _dress(host: Node, level: int) -> void:
	var filter := BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC if level > 0 \
		else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var seen := {}
	for node in host.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(i) as BaseMaterial3D
			if mat != null and not seen.has(mat.get_instance_id()):
				seen[mat.get_instance_id()] = true
				mat.texture_filter = filter
	print("materiales tocados=", seen.size())


func _process(delta: float) -> bool:
	clock += delta
	if stage == 0 and clock > 0.3:
		Settings.quality = int(args.get("tier", "0"))
		Settings.apply(root)
		Engine.max_fps = 0
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
		MapCatalog.choice = int(args.get("map", "0"))
		main = load("res://scenes/Main.tscn").instantiate()
		root.add_child(main)
		stage = 1
		clock = 0.0
	elif stage == 1 and clock > float(args.get("warm", "3.0")):
		Engine.max_fps = 0
		_override()
		stage = 2
		clock = 0.0
	elif stage == 2:
		frames += 1
		sample += delta
		var rid := root.get_viewport_rid()
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
		worst = maxf(worst, delta)
		if sample > float(args.get("seconds", "10")):
			var env: Environment = main.get_node("WorldEnvironment").environment
			print("tier=%d(%s) mapa=%s gente=%d cuadros=%d fps=%.1f gpu_medio=%.2f cpu_medio=%.2f peor=%.1f escala=%.2f modo=%d msaa=%d aa=%d bias=%.2f deband=%s ssao=%s" % [
				Settings.quality, Settings.TIERS[Settings.quality]["name"], MapCatalog.MAPS[MapCatalog.choice]["name"],
				get_nodes_in_group("enemy").size(), frames, frames / sample, gpu / frames,
				cpu / frames, worst * 1000.0, root.scaling_3d_scale, root.scaling_3d_mode, root.msaa_3d,
				root.screen_space_aa, root.texture_mipmap_bias, str(root.use_debanding), str(env.ssao_enabled)])
			quit()
			return true
	return false
