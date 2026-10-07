class_name NetMatch
extends TeamMatch

const TARGETS := {1: 10, 2: 15, 4: 25}
const LOCAL_DURATION := 300.0
const SEND_EVERY := 0.05

var target := 15
var _puppets := {}
var _player: Player
var _send := 0.0
var _killer := 0


func start() -> void:
	stop()
	score = [0, 0]
	time_left = LOCAL_DURATION
	target = TARGETS.get(Net.team_size, 15)
	running = true
	Net.game = self


func stop() -> void:
	super()
	for puppet in _puppets.values():
		if is_instance_valid(puppet):
			puppet.queue_free()
	_puppets.clear()
	if Net.game == self:
		Net.game = null


func my_team() -> int:
	return Net.team_of(Net.me())


func attach(player: Player) -> void:
	_player = player
	_killer = 0
	player.loadout.fired.connect(func() -> void:
		Net.send_shot(player.weapon.viewmodel.muzzle.global_position, -player.camera.global_basis.z))


func player_down() -> void:
	Net.report_down(_killer, _player.last_zone, _player.last_dir)


func board() -> Dictionary:
	var mine := my_team()
	return {"left": ["Tu equipo", score[mine]], "right": ["Rival", score[1 - mine]],
		"note": "Gana el primer equipo que llegue a %d eliminaciones" % target, "clock": time_left}


func result(winner: int) -> Array:
	var mine := my_team()
	var title := "Empate" if winner < 0 else "Ganó tu equipo" if winner == mine else "Ganó el equipo rival"
	return [title, "Tu equipo %d  —  %d rival" % [score[mine], score[1 - mine]], "win" if winner == mine else "lose"]


func on_state(id: int, pos: Vector3, yaw: float, crouch: bool, alive: bool) -> void:
	if not running or not Net.roster.has(id):
		return
	var puppet: NetPuppet = _puppets.get(id)
	if alive and (not is_instance_valid(puppet) or not puppet.is_alive()):
		puppet = _spawn_puppet(id, pos, yaw)
	if is_instance_valid(puppet) and puppet.is_alive():
		puppet.follow(pos, yaw, crouch)


func on_shot(id: int, _from: Vector3, dir: Vector3) -> void:
	var puppet: NetPuppet = _puppets.get(id)
	if is_instance_valid(puppet):
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
		puppet.remove_from_group("combatant")
		_corpses.append(puppet)
		_puppets.erase(victim)
		while _corpses.size() > MAX_CORPSES:
			var old: Enemy = _corpses.pop_front()
			if is_instance_valid(old):
				old.queue_free()
		actor_down.emit(puppet)
	if Net.hosting and Net.roster.has(victim):
		var scorer := 1 - Net.team_of(victim)
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
	if Net.hosting and running and not Net.ready_to_start():
		Net.end_match(my_team())


func _spawn_puppet(id: int, pos: Vector3, yaw: float) -> NetPuppet:
	var puppet := NetPuppet.new()
	puppet.peer = id
	puppet.team = Net.team_of(id)
	puppet.ally = puppet.team == my_team()
	puppet.name = "Jugador%d" % id
	puppet.position = pos
	puppet.rotation.y = yaw + PI
	add_child(puppet)
	_puppets[id] = puppet
	return puppet


func _process(delta: float) -> void:
	if not running:
		return
	time_left = maxf(0.0, time_left - delta)
	if time_left <= 0.0 and Net.hosting:
		Net.end_match(-1 if score[0] == score[1] else 0 if score[0] > score[1] else 1)
	_send -= delta
	if _send <= 0.0 and is_instance_valid(_player):
		_send = SEND_EVERY
		Net.send_state(_player.global_position, _player.yaw, _player.crouching, _player.is_alive())
