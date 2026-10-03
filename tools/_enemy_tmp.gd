extends "res://tools/snap.gd"
func _process(delta: float) -> void:
	if _frame == 5:
		var player: Node3D = _main.get("player")
		player.set("health", 1.0e9)
		var es := get_tree().get_nodes_in_group("enemy")
		for o in es: o.process_mode = Node.PROCESS_MODE_DISABLED
		var e: Node3D = es[0]
		e.process_mode = Node.PROCESS_MODE_INHERIT
		var d := float(args.get("dist", "4"))
		e.global_position = player.global_position + Vector3(float(args.get("dx", "0.4")), 0, -d)
		e.rotation.y = float(args.get("eyaw", "0"))
		if args.has("clip"):
			e.set_physics_process(false)
			e.anim.play(e._clips[args["clip"]], 0.0)
		player.set("yaw", 0.0); player.set("yaw_target", 0.0)
		player.set("pitch", 0.0); player.set("pitch_target", 0.0)
	var k := int(args["kill"])
	if k > 0 and _frame == int(args["frames"]) - k:
		var e2: Node3D = get_tree().get_nodes_in_group("enemy")[0]
		var chest: Vector3 = e2.global_position + Vector3(0, 1.3, 0)
		e2.call("_die", "Chest.001", chest, Vector3(0.15, 0.05, -1).normalized(), 3.0)
		args["kill"] = "0"
	super(delta)
