class_name EnemySenses
extends RefCounted

const SIGHT := 26.0
const FOV_COS := -0.10
const ALERT_COS := -0.55
const NOTICE_CALM := 0.7
const NOTICE_PER_M := 0.05
const NOTICE_ALERT := 0.12

var _notice := {}
static var _sight := PhysicsRayQueryParameters3D.new()
static var _friend_ray := PhysicsRayQueryParameters3D.new()


func spot(body: Enemy, hostiles: Array, calm: bool, target: Node3D, attacker: Node3D, dt: float) -> Node3D:
	var eye := body.eye()
	var fwd := body.forward()
	var best: Node3D = null
	var best_score := INF
	var seen := {}
	for actor: Node3D in hostiles:
		var aim := chest_of(actor)
		var to := aim - eye
		var d := to.length()
		if d > SIGHT:
			continue
		var known := actor == target or actor == attacker
		if fwd.dot(to / d) < (ALERT_COS if known or not calm else FOV_COS):
			continue
		if not clear(body, eye, aim):
			continue
		seen[actor] = true
		var need := NOTICE_CALM + d * NOTICE_PER_M if calm else NOTICE_ALERT
		_notice[actor] = float(_notice.get(actor, 0.0)) + dt
		if _notice[actor] < need and not known:
			continue
		var score := d - (10.0 if actor == attacker else 0.0) - (5.0 if actor == target else 0.0)
		if score < best_score:
			best_score = score
			best = actor
	for actor in _notice.keys():
		if not seen.has(actor):
			_notice.erase(actor)
	return best


static func clear(body: Node3D, from: Vector3, to: Vector3) -> bool:
	_sight.from = from
	_sight.to = to
	_sight.collision_mask = 1
	return body.get_world_3d().direct_space_state.intersect_ray(_sight).is_empty()


static func alive(actor: Node3D) -> bool:
	if actor == null or not is_instance_valid(actor):
		return false
	return actor.call("is_alive")


static func chest_of(actor: Node3D) -> Vector3:
	return actor.call("aim_point")


static func cover_from(body: Node3D, threat: Node3D, nav_map: RID) -> Vector3:
	var eye: Vector3 = chest_of(threat) + Vector3(0, 0.25, 0)
	var best := Vector3.INF
	var best_d := INF
	for k in 16:
		var ang := TAU * k / 16.0 + randf() * 0.3
		var p := body.global_position + Vector3(cos(ang), 0, sin(ang)) * randf_range(2.0, 8.0)
		p = NavigationServer3D.map_get_closest_point(nav_map, p)
		if p.distance_to(threat.global_position) < 3.0 or clear(body, eye, p + Vector3(0, 1.3, 0)):
			continue
		var d := p.distance_to(body.global_position)
		if d < best_d:
			best_d = d
			best = p
	return best


static func friend_in_line(body: Enemy, to: Vector3) -> bool:
	_friend_ray.from = body.model.bone_world("Hand_R")
	_friend_ray.to = to
	_friend_ray.collision_mask = 1 | Player.LAYER | Enemy.HITBOX_LAYER
	_friend_ray.exclude = body.hitbox_rids
	var hit := body.get_world_3d().direct_space_state.intersect_ray(_friend_ray)
	if hit.is_empty():
		return false
	var blocker: Object = hit.collider
	if blocker is Player:
		return (blocker as Player).team == body.team and (blocker as Player).is_alive()
	if blocker is Node and (blocker as Node).has_meta("actor"):
		var mate: Enemy = (blocker as Node).get_meta("actor")
		return mate.team == body.team and mate.is_alive()
	return false
