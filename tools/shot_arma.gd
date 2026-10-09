extends SceneTree

var args := {}
var main: Node
var stage := 0
var clock := 0.0
var fire_clock := -1.0
var times := PackedFloat32Array()
var next := 0
var want := false
var saved := 0


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	for t in String(args.get("times", "0")).split(","):
		times.append(t.to_float())
	RenderingServer.frame_post_draw.connect(_on_post_draw)


func _on_post_draw() -> void:
	if not want:
		return
	want = false
	root.get_texture().get_image().save_png("res://captures/%s_%d.png" % [args.get("out", "arma"), saved])
	saved += 1


func _process(delta: float) -> bool:
	clock += delta
	if fire_clock >= 0.0:
		fire_clock += delta
	if stage == 0 and clock > 0.6:
		main = load("res://scenes/Main.tscn").instantiate()
		root.add_child(main)
		stage = 1
		clock = 0.0
	elif stage == 1 and clock > 1.0:
		_setup()
		stage = 2
		clock = 0.0
	elif stage == 2 and clock > float(args.get("settle", "0.8")):
		if args.has("fire"):
			main.player.weapon.press_trigger()
			fire_clock = 0.0
		stage = 3
		clock = 0.0
	elif stage == 3:
		var now := fire_clock if args.has("fire") else clock
		if next < times.size() and now >= times[next]:
			want = true
			next += 1
		if next >= times.size() and saved >= times.size():
			quit()
			return true
	return false


func _setup() -> void:
	main.lobby.queue_free()
	main.lobby = null
	MapCatalog.choice = int(args.get("map", "2"))
	main._mode = "duel"
	main._load_map()
	main.map.set_mode("duel")
	main._spawn_player()
	if args.has("gente"):
		main.map.director.start()
	if args.has("x"):
		main.player.position = Vector3(float(args["x"]), float(args["y"]), float(args["z"]))
	if args.has("yaw"):
		main.player.yaw = deg_to_rad(float(args["yaw"]))
		main.player.yaw_target = main.player.yaw
	if args.has("pitch"):
		main.player.pitch = deg_to_rad(float(args["pitch"]))
		main.player.pitch_target = main.player.pitch
	main.player.loadout.select(int(args.get("weapon", "1")))
	current_scene = main
