extends "res://tools/snap.gd"
func _process(delta: float) -> void:
	if _frame == 5:
		var player: Node3D = _main.get("player")
		var es := get_tree().get_nodes_in_group("enemy")
		print("ENEMIES ", es.size())
		if es.size() > 0:
			var e: Node3D = es[int(args.get("idx","0"))]
			var p := e.global_position + e.global_basis.z * 3.0 + e.global_basis.x * 1.0
			player.global_position = p
			var d := e.global_position - p
			var yaw := atan2(-d.x, -d.z)
			for k in ["yaw","yaw_target"]: player.set(k, yaw)
			for k in ["pitch","pitch_target"]: player.set(k, deg_to_rad(-10))
			for o in es:
				if o != e: o.process_mode = Node.PROCESS_MODE_DISABLED
	super(delta)
