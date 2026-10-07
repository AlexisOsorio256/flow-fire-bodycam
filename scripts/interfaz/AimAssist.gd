class_name AimAssist
extends RefCounted

const RANGE := 45.0
const SLOW_CONE := 0.07
const SLOW := 0.55
const SNAP_CONE := 0.21

var _near := false


func update(player: Player) -> void:
	_near = Settings.aim_assist and _target(player, SLOW_CONE) != null


func slow() -> float:
	return SLOW if _near else 1.0


func snap(player: Player) -> void:
	if not Settings.aim_assist:
		return
	var target := _target(player, SNAP_CONE)
	if target == null:
		return
	var d: Vector3 = (target.aim_point() - player.camera.global_position).normalized()
	player.yaw_target = player.yaw + wrapf(atan2(-d.x, -d.z) - player.yaw, -PI, PI)
	player.pitch_target = clampf(asin(d.y), -1.38, 1.38)


func _target(player: Player, cone: float) -> Node3D:
	var eye := player.camera.global_position
	var look := -player.camera.global_basis.z
	var best: Node3D = null
	var best_angle := cone
	for actor: Node3D in player.get_tree().get_nodes_in_group("enemy"):
		if not actor.is_alive() or actor.team == player.team:
			continue
		var to: Vector3 = actor.aim_point() - eye
		if to.length() > RANGE:
			continue
		var angle := look.angle_to(to)
		if angle < best_angle and EnemySenses.clear(player, eye, actor.aim_point()):
			best_angle = angle
			best = actor
	return best
