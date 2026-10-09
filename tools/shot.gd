extends Node3D

const MAIN := "res://scenes/Main.tscn"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var tag: String = args[0]
	var map_path: String = args[1]
	var env: Environment = (load(MAIN) as PackedScene).instantiate().get_node("WorldEnvironment").environment
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var map := (load(map_path) as PackedScene).instantiate()
	add_child(map)
	map.build()
	var cam := Camera3D.new()
	cam.fov = 75.0
	add_child(cam)
	cam.current = true
	for i in range(2, args.size()):
		var pair := args[i].split("/")
		cam.global_position = _vec(pair[0])
		cam.look_at(_vec(pair[1]), Vector3.UP)
		for f in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var name := "%s_%d" % [tag, i - 2]
		get_viewport().get_texture().get_image().save_png("res://captures/%s.png" % name)
		print("SHOT ", name)
	get_tree().quit()


func _vec(text: String) -> Vector3:
	var p := text.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))
