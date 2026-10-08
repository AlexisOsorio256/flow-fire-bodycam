class_name TeamMatch
extends Node3D

signal actor_down(actor: Enemy)
signal finished(winner: int)

const TARGET := 25
const DURATION := 240.0
const RESPAWN := 2.2
const SAFE_DIST := 8.0
const MAX_CORPSES := 4
const ALLY_SKILL := 0.0
const RIFLE_CHANCE := [0.15, 0.35, 0.6]
const HOMES := [Vector3(0.6, 0.0, 7.8), Vector3(-5.4, 0.0, -7.8)]

var posts: Array[Vector3] = []
var nav_map: RID
var score := [0, 0]
var time_left := DURATION
var running := false
var _roster: Array[Dictionary] = []
var _corpses: Array[Enemy] = []
var _orders := 0.0


func start() -> void:
	stop()
	score = [0, 0]
	time_left = DURATION
	running = true
	for i in 7:
		_roster.append({"team": 0 if i < 3 else 1, "actor": null, "wait": 0.2 + i * 0.16})


func stop() -> void:
	running = false
	for slot in _roster:
		var actor = slot["actor"]
		if is_instance_valid(actor):
			actor.remove_from_group("combatant")
			actor.remove_from_group("enemy")
			actor.queue_free()
	for corpse in _corpses:
		if is_instance_valid(corpse):
			corpse.queue_free()
	_roster.clear()
	_corpses.clear()
	_orders = 0.0


func hold() -> void:
	running = false
	for slot in _roster:
		if is_instance_valid(slot["actor"]):
			slot["actor"].process_mode = Node.PROCESS_MODE_DISABLED


func point(team: int) -> void:
	if not running:
		return
	score[team] += 1
	if score[team] == TARGET - 5:
		Voices.radio("near_win" if team == Voices.ALLY_TEAM else "near_lose", 1.0, true)
	if score[team] >= TARGET:
		_end(team)


func my_team() -> int:
	return 0


func attach(_player: Player) -> void:
	pass


func player_down() -> void:
	point(1)


func elapsed() -> float:
	return DURATION - time_left


func board() -> Dictionary:
	return {"left": ["TU EQUIPO", score[0]], "right": ["RIVAL", score[1]], "note": "PRIMERO A %d BAJAS" % TARGET,
		"clock": time_left}


func result(winner: int) -> Array:
	var title: String = {0: "ZONA ASEGURADA", 1: "REPLIEGUE"}.get(winner, "SIN RESOLUCIÓN")
	return [title, "TU EQUIPO %02d  —  %02d RIVAL" % [score[0], score[1]], "win" if winner == 0 else "lose"]


func spawn_point(team: int) -> Dictionary:
	var opponents: Array[Node3D] = []
	var friends: Array[Node3D] = []
	for actor in get_tree().get_nodes_in_group("combatant"):
		if not actor.is_alive():
			continue
		if actor.team != team:
			opponents.append(actor)
		else:
			friends.append(actor)
	var best: Vector3 = HOMES[team]
	var best_score := -INF
	for p in posts:
		var occupied := false
		for friend in friends:
			if p.distance_to(friend.global_position) < 2.5:
				occupied = true
		if occupied:
			continue
		var nearest := INF
		var exposed := 0
		var travel := INF
		for opponent in opponents:
			nearest = minf(nearest, p.distance_to(opponent.global_position))
			if EnemySenses.clear(self, opponent.aim_point(), p + Vector3.UP * 1.4):
				exposed += 1
			var path := NavigationServer3D.map_get_path(nav_map, p, opponent.global_position, true)
			if path.size() < 2 or path[0].distance_to(p) > 1.0 or path[-1].distance_to(opponent.global_position) > 1.5:
				continue
			var length := 0.0
			for i in range(1, path.size()):
				length += path[i - 1].distance_to(path[i])
			travel = minf(travel, length)
		if not opponents.is_empty() and is_inf(travel):
			continue
		var value: float = -p.distance_to(HOMES[team]) if opponents.is_empty() else -absf(travel - 14.0) - exposed * 25.0
		value -= maxf(0.0, SAFE_DIST - nearest) * 100.0
		value += randf() * 3.0
		if value > best_score:
			best_score = value
			best = p
	var look: Vector3 = HOMES[1 - team]
	if not opponents.is_empty():
		look = opponents[0].global_position
	var dir: Vector3 = look - best
	return {"pos": best + Vector3.UP * 0.05, "yaw": atan2(-dir.x, -dir.z)}


func _process(delta: float) -> void:
	if not running:
		return
	if time_left > 60.0 and time_left - delta <= 60.0:
		Voices.radio("minute", 1.0, true)
	time_left = maxf(0.0, time_left - delta)
	if time_left <= 0.0:
		_end(-1 if score[0] == score[1] else 0 if score[0] > score[1] else 1)
		return
	for slot in _roster:
		if is_instance_valid(slot["actor"]):
			continue
		slot["wait"] -= delta
		if slot["wait"] <= 0.0:
			_spawn(slot)
	_orders -= delta
	if _orders <= 0.0:
		_orders = 1.5
		_command()


func _spawn(slot: Dictionary) -> void:
	var actor := _make_actor(slot)
	actor.killed.connect(_on_down.bind(slot))
	slot["actor"] = actor


func _make_actor(slot: Dictionary) -> Enemy:
	var spawn := spawn_point(slot["team"])
	var actor := Enemy.new()
	actor.team = slot["team"]
	actor.name = _actor_name(slot)
	actor.position = spawn["pos"]
	actor.rotation.y = spawn["yaw"] + PI
	actor.nav_map = nav_map
	add_child(actor)
	actor.call_deferred("connect_nav")
	actor.brain.skill = Settings.RIVAL_SKILL[Settings.difficulty] if actor.team == 1 else ALLY_SKILL
	actor.brain.rush = randf() < EnemyBrain.rush_chance(actor.brain.skill)
	if actor.team == 1:
		actor.set_weapon("rifle" if randf() < RIFLE_CHANCE[clampi(Settings.difficulty, 0, 2)] else "glock")
	return actor


func _actor_name(slot: Dictionary) -> String:
	return "Aliado" if slot["team"] == 0 else "Rival"


func _sink_corpse(actor: Enemy) -> void:
	actor.remove_from_group("combatant")
	_corpses.append(actor)
	while _corpses.size() > MAX_CORPSES:
		var old: Enemy = _corpses.pop_front()
		if is_instance_valid(old):
			old.queue_free()


func _command() -> void:
	for slot in _roster:
		var actor = slot["actor"]
		if not is_instance_valid(actor) or actor.brain.state != EnemyBrain.HOLD:
			continue
		var goal := Vector3.INF
		var score := -INF
		for p in posts:
			var distance: float = actor.global_position.distance_to(p)
			if distance < 3.0:
				continue
			var value: float = -absf(distance - 10.0) - absf(p.z) * 0.2 + randf() * 9.0
			if value > score:
				score = value
				goal = p
		if goal != Vector3.INF:
			actor.brain.hunt(goal)


func _on_down(actor: Enemy, slot: Dictionary) -> void:
	slot["actor"] = null
	slot["wait"] = RESPAWN
	_sink_corpse(actor)
	if running:
		actor_down.emit(actor)
		point(1 - actor.team)


func _end(winner: int) -> void:
	hold()
	finished.emit(winner)
