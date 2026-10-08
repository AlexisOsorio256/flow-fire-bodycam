class_name NetMatch
extends TeamMatch

const SEND_EVERY := 0.05

var target := 15
var _puppets := {}
var _player: Player
var _send := 0.0
var _killer := 0
var _next_bot := 0
var _elapsed := 0.0


func start() -> void:
	stop()
	score = [0, 0]
	time_left = float(Net.match_time)
	target = Net.match_target
	_elapsed = 0.0
	running = true
	Net.game = self
	if Net.hosting and Settings.fill_bots:
		_fill_bots()


func stop() -> void:
	super()
	for puppet in _puppets.values():
		if is_instance_valid(puppet):
			puppet.queue_free()
	_puppets.clear()
	_next_bot = 0
	if Net.game == self:
		Net.game = null


func my_team() -> int:
	return Net.team_of(Net.me())


func attach(player: Player) -> void:
	_player = player
	_killer = 0
	player.loadout.fired.connect(func() -> void:
		Net.send_shot(player.weapon.viewmodel.muzzle.global_position, -player.camera.global_basis.z, player.weapon.spec.id))


func player_down() -> void:
	Net.report_down(_killer, _player.last_zone, _player.last_dir)


func board() -> Dictionary:
	var mine := my_team()
	var goal := "Gana el primer equipo que llegue a %d eliminaciones" % target
	if Net.match_time <= 0:
		goal += ", sin límite"
	return {"left": ["Tu equipo", score[mine]], "right": ["Rival", score[1 - mine]],
		"note": goal, "clock": time_left}


func elapsed() -> float:
	return _elapsed


func result(winner: int) -> Array:
	var mine := my_team()
	var title := "Empate" if winner < 0 else "Ganó tu equipo" if winner == mine else "Ganó el equipo rival"
	return [title, "Tu equipo %d  —  %d rival" % [score[mine], score[1 - mine]], "win" if winner == mine else "lose"]


func on_state(id: int, pos: Vector3, yaw: float, crouch: bool, alive: bool, weapon := "glock") -> void:
	if not running or not Net.roster.has(id):
		return
	var puppet: NetPuppet = _puppets.get(id)
	if alive and (not is_instance_valid(puppet) or not puppet.is_alive()):
		puppet = _spawn_puppet(id, pos, yaw, weapon, Net.team_of(id))
	if is_instance_valid(puppet) and puppet.is_alive():
		puppet.follow(pos, yaw, crouch)
		puppet.set_weapon(weapon)


func on_shot(id: int, _from: Vector3, dir: Vector3, weapon := "glock") -> void:
	var puppet: NetPuppet = _puppets.get(id)
	if is_instance_valid(puppet):
		puppet.set_weapon(weapon)
		puppet.show_shot(dir)


func on_hit(id: int, zone: String, dir: Vector3, impulse: float) -> void:
	if running and is_instance_valid(_player) and _player.is_alive() and Net.team_of(id) != my_team():
		_killer = id
		_player.take(zone, dir, impulse)


func on_down(victim: int, killer: int, zone: String, dir: Vector3) -> void:
	if not running:
		return
	var puppet: NetPuppet = _puppets.get(victim)
	if victim != Net.me() and is_instance_valid(puppet) and puppet.is_alive():
		puppet.last_by_player = killer == Net.me()
		puppet.fall(zone, dir)
		_puppets.erase(victim)
		_sink_corpse(puppet)
		actor_down.emit(puppet)
	var squad := _slot_of(victim)
	if Net.hosting and (Net.roster.has(victim) or not squad.is_empty()):
		var team: int = Net.team_of(victim) if Net.roster.has(victim) else int(squad["team"])
		var scorer := 1 - team
		score[scorer] += 1
		Net.push_score(score, time_left)
		if score[scorer] >= target:
			Net.end_match(scorer)


func on_score(new_score: Array, clock: float) -> void:
	score = new_score
	time_left = clock


func on_end(winner: int) -> void:
	_end(winner)


func on_left(id: int) -> void:
	var puppet: NetPuppet = _puppets.get(id)
	if is_instance_valid(puppet):
		puppet.queue_free()
	_puppets.erase(id)
	if Net.hosting and running and not Net.can_start():
		Net.end_match(my_team())


func on_bots(states: Array) -> void:
	if not running:
		return
	for s in states:
		var puppet: NetPuppet = _puppets.get(s[0])
		if is_instance_valid(puppet) and puppet.is_alive():
			puppet.follow(s[2], s[3], s[5] if s.size() > 5 else false)
			puppet.set_weapon(s[4])
		else:
			_spawn_puppet(s[0], s[2], s[3], s[4], s[1])


func on_bot_shot(id: int, _from: Vector3, dir: Vector3, weapon: String) -> void:
	var puppet: NetPuppet = _puppets.get(id)
	if is_instance_valid(puppet):
		puppet.set_weapon(weapon)
		puppet.show_shot(dir)


func on_bot_hit(sender: int, bot_id: int, zone: String, dir: Vector3, impulse: float) -> void:
	var slot := _slot_of(bot_id)
	var actor: Enemy = slot.get("actor")
	if not is_instance_valid(actor) or not actor.is_alive():
		return
	slot["killer"] = sender
	slot["dir"] = dir
	var bone: String = NetPuppet.BONE_OF.get(zone, "Chest.001")
	actor.hit(actor.model.bone_world(bone), dir, impulse, bone, _puppets.get(sender))


func _slot_of(id: int) -> Dictionary:
	for slot in _roster:
		if slot["id"] == id:
			return slot
	return {}


func _fill_bots() -> void:
	var taken := [0, 0]
	for id: int in Net.roster:
		taken[Net.team_of(id)] += 1
	for team in 2:
		for i in Net.team_size - taken[team]:
			_next_bot -= 1
			_roster.append({"id": _next_bot, "team": team, "actor": null, "wait": 0.2 + i * 0.16})


func _spawn_bot(slot: Dictionary) -> void:
	var actor := _make_actor(slot)
	actor.killed.connect(_on_bot_down.bind(slot))
	actor.fired.connect(func(from: Vector3, dir: Vector3) -> void: Net.send_bot_shot(slot["id"], from, dir, actor.weapon_id))
	slot["actor"] = actor


func _actor_name(slot: Dictionary) -> String:
	return "Bot%d" % absi(slot["id"])


func _on_bot_down(actor: Enemy, slot: Dictionary) -> void:
	slot["actor"] = null
	slot["wait"] = RESPAWN
	_sink_corpse(actor)
	var killer := 0
	var dir := Vector3.FORWARD
	if slot.has("killer"):
		killer = slot["killer"]
		dir = slot["dir"]
	elif actor.last_by_player:
		killer = Net.me()
		if is_instance_valid(_player):
			dir = (actor.global_position - _player.global_position).normalized()
	slot.erase("killer")
	slot.erase("dir")
	actor_down.emit(actor)
	Net.report_bot_down(slot["id"], killer, actor.last_region, dir)


func _send_bots() -> void:
	var states: Array = []
	for slot in _roster:
		var actor: Enemy = slot["actor"]
		if is_instance_valid(actor) and actor.is_alive():
			states.append([slot["id"], slot["team"], actor.global_position, actor.yaw(), actor.weapon_id,
				actor.wounds.downed])
	Net.send_bots(states)


func _spawn_puppet(id: int, pos: Vector3, yaw: float, weapon: String, team: int) -> NetPuppet:
	var puppet := NetPuppet.new()
	puppet.peer = id
	puppet.team = team
	puppet.ally = team == my_team()
	puppet.weapon_id = weapon
	puppet.name = ("Jugador%d" % id) if id > 0 else ("Bot%d" % absi(id))
	puppet.position = pos
	puppet.rotation.y = yaw + PI
	add_child(puppet)
	puppet.set_weapon(weapon)
	_puppets[id] = puppet
	return puppet


func _process(delta: float) -> void:
	if not running:
		return
	_elapsed += delta
	if time_left > 0.0:
		time_left = maxf(0.0, time_left - delta)
		if time_left <= 0.0 and Net.hosting:
			Net.end_match(-1 if score[0] == score[1] else 0 if score[0] > score[1] else 1)
	if Net.hosting:
		for slot in _roster:
			if is_instance_valid(slot["actor"]):
				continue
			slot["wait"] -= delta
			if slot["wait"] <= 0.0:
				_spawn_bot(slot)
		_orders -= delta
		if _orders <= 0.0:
			_orders = 1.5
			_command()
	_send -= delta
	if _send <= 0.0 and is_instance_valid(_player):
		_send = SEND_EVERY
		Net.send_state(_player.global_position, _player.yaw, _player.crouching, _player.is_alive(), _player.weapon.spec.id if is_instance_valid(_player.weapon) else "glock")
		if Net.hosting and not _roster.is_empty():
			_send_bots()
