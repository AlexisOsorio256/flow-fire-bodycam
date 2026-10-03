extends Node
## Captura el juego real: `godot --path . tools/snap.tscn -- --out=/tmp/a.png
## --pos=x,y,z --yaw=grados --pitch=grados --frames=60 [--fire=n]`.
## Imprime el tiempo medio de los ultimos 30 frames, draws y primitivas.

var args := {"out": "/tmp/snap.png", "frames": "60", "yaw": "0", "pitch": "0", "fire": "0"}
var _frame := 0
var _ms := 0.0
var _main: Node


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := (a as String).trim_prefix("--").split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	_main = load("res://scenes/Main.tscn").instantiate()
	add_child(_main)


func _process(delta: float) -> void:
	_frame += 1
	var player: Node3D = _main.get("player")
	if _frame == 3 and player != null:
		if args.has("pos"):
			var p := (args["pos"] as String).split_floats(",")
			player.global_position = Vector3(p[0], p[1], p[2])
		var yaw := deg_to_rad(float(args["yaw"]))
		var pitch := deg_to_rad(float(args["pitch"]))
		player.set("yaw", yaw)
		player.set("yaw_target", yaw)
		player.set("pitch", pitch)
		player.set("pitch_target", pitch)
	var frames := int(args["frames"])
	var fire := int(args["fire"])
	if fire > 0 and player != null and _frame >= frames - fire and _frame % 6 == 0:
		player.weapon.force_fire_once()
	if _frame > frames - 30:
		_ms += delta * 1000.0
	if _frame == frames:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args["out"])
		print("SNAP %s %.2f ms, %d draws, %d prims" % [args["out"], _ms / 30.0,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
		get_tree().quit()
