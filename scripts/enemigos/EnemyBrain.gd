class_name EnemyBrain
extends Node

const THINK_HZ := 8.0
const HEAR_SHOT := 34.0
const INVESTIGATE := 18.0
const FEAR_TIME := 2.5
const FEAR_RANGE := 9.0
const WALK_SPEED := 1.3
const RUN_SPEED := 3.6
const SEARCH_SPEED := 1.4
const RUSH_STOP := 4.5
const ALERT_TIME := 45.0
const RETREAT := 3.5

enum { HOLD, ENGAGE, COVER, SEARCH }

var body: Enemy
var nav: NavigationAgent3D
var nav_map: RID
var state := HOLD
var skill := 0.5
var rush := false
var fear := 0.0
var aim_bad := 0.0
var want := Vector3.ZERO
var face := 0.0
var alert := 0.0
var trigger := EnemyTrigger.new()

var _target: Node3D
var _target_visible := false
var _target_pos := Vector3.ZERO
var _target_time := 0.0
var _lost := 0.0
var _attacker: Node3D
var _senses := EnemySenses.new()
var _think := 0.0
var _goal := Vector3.INF
var _post := Vector3.ZERO
var _post_yaw := 0.0
var _look_yaw := 0.0
var _scan := 0.0
var _cover_wait := 0.0
var _engage_time := 0.0


static func cover_after(skill: float) -> float:
	return lerpf(4.5, 2.0, clampf(skill, 0.0, 1.0))

static func search_for(skill: float) -> float:
	return lerpf(2.5, 5.0, clampf(skill, 0.0, 1.0))

static func rush_chance(skill: float) -> float:
	return lerpf(0.3, 0.6, clampf(skill, 0.0, 1.0))


func setup(owner_body: Enemy) -> void:
	body = owner_body
	nav = NavigationAgent3D.new()
	nav.name = "Nav"
	nav.radius = Enemy.NAV_RADIUS
	nav.height = 1.80
	nav.path_desired_distance = 0.35
	nav.target_desired_distance = 0.45
	nav.avoidance_enabled = false
	body.add_child(nav)
	_post = body.global_position
	_post_yaw = body.yaw()
	_look_yaw = _post_yaw
	face = _look_yaw
	_think = randf() / THINK_HZ


func connect_nav() -> void:
	if nav_map.is_valid():
		nav.set_navigation_map(nav_map)


func engaged() -> bool:
	return state == ENGAGE or (state == COVER and _target_visible)


func alerted() -> bool:
	return alert > 0.0 or state != HOLD


func tick(delta: float) -> void:
	if not is_instance_valid(_target):
		_target = null
		_target_visible = false
	if not is_instance_valid(_attacker):
		_attacker = null
	_think -= delta
	if _think <= 0.0:
		_think += 1.0 / THINK_HZ
		_perceive(1.0 / THINK_HZ)
	aim_bad = maxf(0.0, aim_bad - delta * 0.08)
	fear = maxf(0.0, fear - delta)
	alert = maxf(0.0, alert - delta)
	if _target_visible:
		_target_time += delta
	else:
		_target_time = maxf(0.0, _target_time - delta * 2.0)
	want = Vector3.ZERO
	face = _look_yaw
	if body.wounds.stagger > 0.0:
		face = body.yaw()
		return
	match state:
		HOLD:
			_hold(delta)
		ENGAGE:
			want = _engage(delta)
			face = _yaw_to(_target_pos)
		COVER:
			want = _step(_goal, RUN_SPEED)
			face = _yaw_to(_target_pos) if _target_visible else _yaw_of(want)
			if want == Vector3.ZERO:
				_cover_wait -= delta
				if _cover_wait <= 0.0:
					state = ENGAGE if _target != null else SEARCH
					_go(_target_pos)
		SEARCH:
			want = _step(_goal, SEARCH_SPEED)
			face = _yaw_of(want) if want != Vector3.ZERO else _look_yaw
			_lost += delta
			if want == Vector3.ZERO and _lost > search_for(skill):
				state = HOLD
				_post = body.global_position
				_post_yaw = _look_yaw


func hunt(at: Vector3) -> void:
	alert = ALERT_TIME
	if state == HOLD or state == SEARCH:
		state = SEARCH
		_lost = 0.0
		_go(NavigationServer3D.map_get_closest_point(nav_map, at) if nav_map.is_valid() else at)


func hear(at: Vector3, shooter: Node3D) -> void:
	if not is_instance_valid(shooter) or shooter.team == body.team:
		return
	var d := body.global_position.distance_to(at)
	if d < FEAR_RANGE:
		fear = FEAR_TIME
	if d > HEAR_SHOT:
		return
	alert = ALERT_TIME
	if _target_visible:
		return
	_look_yaw = _yaw_to(at)
	if d < INVESTIGATE and state == HOLD:
		Voices.say(body, "fired", 0.6)
		state = SEARCH
		_go(at.lerp(body.global_position, clampf(5.0 / maxf(d, 0.1), 0.0, 1.0)))
		_lost = 0.0


func alarm(shooter: Node3D) -> void:
	fear = FEAR_TIME
	alert = ALERT_TIME
	if shooter != null and shooter != body and EnemySenses.alive(shooter):
		_attacker = shooter
		_look_yaw = _yaw_to(shooter.global_position)
		if not _target_visible:
			_target = shooter
			_target_pos = shooter.global_position


func attacker() -> Node3D:
	return _attacker if is_instance_valid(_attacker) else null


func flinch(region: String, from_front: float, shooter: Node3D) -> void:
	Voices.hurt(body, region)
	if region == "arm":
		aim_bad = 1.0
	rush = false
	trigger.hold(body.wounds.stagger + 0.2 + from_front * 0.3)
	_target_time *= 0.4
	if state != COVER and (body.wounds.wounded() or randf() < lerpf(0.45, 0.9, skill)):
		_seek_cover(shooter if shooter != null else _target)


func _hold(delta: float) -> void:
	_scan -= delta
	if _scan <= 0.0:
		_scan = randf_range(1.2, 2.4) if alerted() else randf_range(2.5, 5.0)
		_look_yaw = _yaw_to(_post) if body.global_position.distance_to(_post) > 1.5 \
			else _post_yaw + randf_range(-0.7, 0.7)
	if body.global_position.distance_to(_post) > 1.0:
		want = _step(_post, WALK_SPEED)
		face = _yaw_of(want)


func _hostiles() -> Array:
	var out := []
	for actor in get_tree().get_nodes_in_group("combatant"):
		if actor.team != body.team and EnemySenses.alive(actor):
			out.append(actor)
	return out


func _perceive(dt: float) -> void:
	var best := _senses.spot(body, _hostiles(), state == HOLD, _target, _attacker, dt)
	if best != null:
		if best != _target:
			_target = best
			_target_time = 0.0
			trigger.react(skill)
		_target_visible = true
		_target_pos = best.global_position
		_lost = 0.0
		alert = ALERT_TIME
		if state == HOLD or state == SEARCH:
			Voices.say(body, "contact", 0.85 if state == HOLD else 0.3)
			state = ENGAGE
	else:
		_target_visible = false
		if not EnemySenses.alive(_target):
			_target = null


func _engage(delta: float) -> Vector3:
	if not EnemySenses.alive(_target):
		_target = null
		state = SEARCH
		_go(_target_pos)
		return Vector3.ZERO
	if not _target_visible:
		_lost += delta
		trigger.hold(randf_range(EnemyTrigger.REACTION.x, EnemyTrigger.REACTION.y) * 0.6)
		if _lost > lerpf(0.8, 1.8, skill):
			Voices.say(body, "search", 0.45)
			state = SEARCH
			_go(_target_pos)
		return Vector3.ZERO
	_engage_time += delta
	if rush:
		if absf(angle_difference(body.yaw(), _yaw_to(_target_pos))) < 0.35:
			_shoot(delta)
		if trigger.busy() or body.global_position.distance_to(_target_pos) < RUSH_STOP:
			return Vector3.ZERO
		return _step(_target_pos, WALK_SPEED)
	if _engage_time > cover_after(skill) and randf() < delta * lerpf(0.3, 0.7, skill):
		_engage_time = 0.0
		if _seek_cover(_target):
			return Vector3.ZERO
	if absf(angle_difference(body.yaw(), _yaw_to(_target_pos))) < 0.25:
		_shoot(delta)
	return Vector3.ZERO


func _shoot(delta: float) -> void:
	trigger.pull(body, _target, delta, _target_time, skill, aim_bad)


func _seek_cover(threat: Node3D) -> bool:
	if threat == null or not nav_map.is_valid():
		return false
	var best := EnemySenses.cover_from(body, threat, nav_map)
	if best == Vector3.INF:
		var away := (body.global_position - threat.global_position) * Vector3(1, 0, 1)
		best = NavigationServer3D.map_get_closest_point(nav_map, body.global_position + away.normalized() * RETREAT)
		if best.distance_to(body.global_position) < 1.0:
			return false
	state = COVER
	Voices.say(body, "cover", 0.4)
	_cover_wait = randf_range(1.0, 2.6)
	_go(best)
	return true


func _go(to: Vector3) -> void:
	if _goal.distance_to(to) > 0.4:
		_goal = to
		nav.target_position = to


func _step(to: Vector3, speed: float) -> Vector3:
	_go(to)
	var next := nav.get_next_path_position()
	if nav.is_navigation_finished():
		return Vector3.ZERO
	var dir := Vector3(next.x - body.global_position.x, 0.0, next.z - body.global_position.z)
	if dir.length() < 0.02:
		return Vector3.ZERO
	return dir.normalized() * speed


func _yaw_to(p: Vector3) -> float:
	return atan2(p.x - body.global_position.x, p.z - body.global_position.z)


func _yaw_of(v: Vector3) -> float:
	return _look_yaw if v.length_squared() < 0.0001 else atan2(v.x, v.z)
