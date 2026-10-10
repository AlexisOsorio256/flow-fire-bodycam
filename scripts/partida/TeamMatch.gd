class_name TeamMatch
extends Node3D

signal actor_down(actor: Enemy)
signal finished(winner: int)

const TARGET := 150
const RESPAWN := 2.2
const SAFE_DIST := 8.0
const MAX_CORPSES := 4
const BASE_SPREAD := 1.3
const RIFLE_CHANCE := [0.15, 0.35, 0.6]
const HOMES := [Vector3(0.6, 0.0, 7.8), Vector3(-5.4, 0.0, -7.8)]

var posts: Array[Vector3] = []
var homes: Array[Vector3] = [HOMES[0], HOMES[1]]
var nav_map: RID
var score := [0, 0]
var time_left := 0.0
var running := false
var _roster: Array[Dictionary] = []
var _corpses: Array[Enemy] = []
var _orders := 0.0


func start() -> void:
	stop()
	score = [0, 0]
	time_left = 0.0
	running = true
	for i in 7:
		var team := 0 if i < 3 else 1
		var slot := i + 1 if team == 0 else i - 3
		_roster.append({"team": team, "slot": slot, "first": true, "actor": null, "wait": 0.2 + i * 0.16})


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
		Voices.radio("near_win" if team == Voices.ally_team else "near_lose", 1.0, true)
	if score[team] >= TARGET:
		_end(team)


func my_team() -> int:
	return 0


func attach(_player: Player) -> void:
	pass


func player_down() -> void:
	point(1)


func elapsed() -> float:
	return time_left


func board() -> Dictionary:
	return {"left": ["TU EQUIPO", score[0]], "right": ["RIVAL", score[1]], "note": "PRIMERO A %d PUNTOS" % TARGET,
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
	var best: Vector3 = homes[team]
	var best_score := -INF
	for p in posts:
		var occupied := false
		for friend in friends:
			if p.distance_to(friend.global_position) < 2.5:
				occupied = true
		if occupied:
			continue
		var nearest := INF
		var closest: Node3D = null
		var exposed := 0
		for opponent in opponents:
			var gap := p.distance_to(opponent.global_position)
			if gap < nearest:
				nearest = gap
				closest = opponent
			if EnemySenses.clear(self, opponent.aim_point(), p + Vector3.UP * 1.4):
				exposed += 1
		var travel := _travel_to(p, closest)
		if closest != null and is_inf(travel):
			continue
		var value: float = -p.distance_to(homes[team]) if closest == null else -absf(travel - 14.0) - exposed * 25.0
		value -= maxf(0.0, SAFE_DIST - nearest) * 100.0
		value += randf() * 3.0
		if value > best_score:
			best_score = value
			best = p
	var look: Vector3 = homes[1 - team]
	if not opponents.is_empty():
		look = opponents[0].global_position
	var dir: Vector3 = look - best
	return {"pos": best + Vector3.UP * 0.05, "yaw": atan2(-dir.x, -dir.z)}


func _travel_to(post: Vector3, opponent: Node3D) -> float:
	if opponent == null:
		return INF
	var path := NavigationServer3D.map_get_path(nav_map, post, opponent.global_position, true)
	if path.size() < 2 or path[0].distance_to(post) > 1.0 \
			or path[-1].distance_to(opponent.global_position) > 1.5:
		return INF
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	return length


func _process(delta: float) -> void:
	if not running:
		return
	time_left += delta
	_advance(delta)


func _advance(delta: float) -> void:
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
	slot["first"] = false
	_wire(actor, slot)
	slot["actor"] = actor


func _wire(actor: Enemy, slot: Dictionary) -> void:
	actor.killed.connect(_on_down.bind(slot))


func opening_point(team: int, slot: int) -> Dictionary:
	var off := Vector3(BASE_SPREAD if slot & 1 else -BASE_SPREAD, 0.0, BASE_SPREAD if slot & 2 else -BASE_SPREAD)
	var at: Vector3 = homes[team] + off
	var dir: Vector3 = homes[1 - team] - at
	return {"pos": at + Vector3.UP * 0.05, "yaw": atan2(-dir.x, -dir.z)}


func _make_actor(slot: Dictionary) -> Enemy:
	var spawn := opening_point(slot["team"], slot["slot"]) if slot.get("first", false) else spawn_point(slot["team"])
	var actor := Enemy.new()
	actor.team = slot["team"]
	actor.name = _actor_name(slot)
	actor.position = spawn["pos"]
	actor.rotation.y = spawn["yaw"] + PI
	actor.nav_map = nav_map
	add_child(actor)
	actor.call_deferred("connect_nav")
	actor.brain.skill = Settings.RIVAL_SKILL[Settings.difficulty]
	actor.brain.rush = randf() < EnemyBrain.rush_chance(actor.brain.skill)
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
		var goal := _goal_for(actor)
		if goal != Vector3.INF:
			actor.brain.hunt(goal)


func _goal_for(actor: Enemy) -> Vector3:
	var goal := Vector3.INF
	var best := -INF
	for p in posts:
		var distance: float = actor.global_position.distance_to(p)
		if distance < 3.0:
			continue
		var value: float = -absf(distance - 10.0) - absf(p.z) * 0.2 + randf() * 9.0
		if value > best:
			best = value
			goal = p
	return goal


func _retire(actor: Enemy, slot: Dictionary) -> void:
	slot["actor"] = null
	slot["wait"] = RESPAWN
	_sink_corpse(actor)


func _on_down(actor: Enemy, slot: Dictionary) -> void:
	_retire(actor, slot)
	if running:
		actor_down.emit(actor)
		point(1 - actor.team)


func _end(winner: int) -> void:
	hold()
	finished.emit(winner)
