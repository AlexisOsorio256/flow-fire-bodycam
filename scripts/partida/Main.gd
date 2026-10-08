extends Node3D

const RESPAWN := 2.6
const FALL_TIME := 1.3

var map: Node3D
var player: Player
var hud: CanvasLayer
var board: Scoreboard
var lobby: CanvasLayer
var _death: DeathScreen
var _pause: PauseMenu
var _ambience: AudioStreamPlayer
var _respawn_left := 0.0
var _finished := false
var _kills := 0
var _deaths := 0
var _mode := "duel"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	if not OS.get_cmdline_user_args().has("--mode=combat"):
		Settings.load_saved()
	Settings.apply(get_viewport())
	Net.match_started.connect(_on_net_start)
	Net.closed.connect(_on_net_closed)
	if OS.get_cmdline_user_args().has("--mode=survival"):
		_play("survival")
	elif OS.get_cmdline_user_args().has("--mode=combat"):
		_play("duel")
	else:
		_load_map()
		_enter_lobby()


func _load_map() -> void:
	if map != null:
		remove_child(map)
		map.free()
	map = MapCatalog.scene().instantiate()
	map.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(map)
	map.build()


func _process(delta: float) -> void:
	if _finished or hud == null:
		return
	if get_tree().paused:
		return
	if _respawn_left > 0.0:
		_respawn_left = maxf(0.0, _respawn_left - delta)
		if _death == null and _respawn_left <= RESPAWN - FALL_TIME:
			_death = DeathScreen.new()
			add_child(_death)
			_death.show_respawn()
		if _death != null:
			_death.countdown(_respawn_left)
		if _respawn_left <= 0.0:
			_respawn()


func _enter_lobby(panel := "") -> void:
	_clear_match()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	lobby = preload("res://scripts/interfaz/Lobby.gd").new()
	add_child(lobby)
	lobby.mode_chosen.connect(_on_mode_chosen)
	if panel != "":
		lobby.show_panel(panel)


func _on_net_start() -> void:
	if lobby != null:
		lobby.queue_free()
		lobby = null
	else:
		_clear_match()
		await get_tree().process_frame
	_play("local")


func _on_net_closed(reason: String) -> void:
	if lobby == null:
		_enter_lobby()
	lobby.notice(reason)


func leave_match() -> void:
	if _mode == "local" and _finished:
		_enter_lobby("local")
		return
	Net.leave()
	_enter_lobby()


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	if lobby != null:
		lobby.back()
	elif _finished:
		_on_death_choice("lobby")
	elif player != null and not player.paused:
		player.release_mouse()
	elif player != null:
		leave_match()


func _on_mode_chosen(mode: String) -> void:
	if mode == "quit":
		get_tree().quit()
		return
	lobby.queue_free()
	lobby = null
	Net.leave()
	_play(mode)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE \
			and not _finished and player != null:
		if not player.is_alive() or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			leave_match()
			get_viewport().set_input_as_handled()


func _play(mode: String) -> void:
	_mode = mode
	if mode != "local":
		MapCatalog.pick()
	_load_map()
	map.set_mode(mode)
	if not map.director.actor_down.is_connected(_on_actor_down):
		map.director.actor_down.connect(_on_actor_down)
		map.director.finished.connect(_finish)
	_finished = false
	_kills = 0
	_deaths = 0
	_spawn_player()
	hud = preload("res://scripts/interfaz/HUD.gd").new()
	add_child(hud)
	hud.setup(player)
	board = Scoreboard.new()
	board.director = map.director
	board.player = player
	add_child(board)
	_pause = PauseMenu.new()
	_pause.main = self
	_pause.player = player
	add_child(_pause)
	_ambience = GameAudio.loop("factory")
	map.director.start()
	Voices.radio("start")


func _spawn_player() -> void:
	player = Player.new()
	player.name = "Player"
	player.team = map.director.my_team()
	var spawn: Dictionary = map.director.spawn_point(player.team)
	player.position = spawn["pos"]
	player.yaw_target = spawn["yaw"]
	player.yaw = spawn["yaw"]
	add_child(player)
	player.capture_mouse()
	player.died.connect(_on_player_died)
	map.director.attach(player)


func _respawn() -> void:
	player.remove_from_group("player")
	player.remove_from_group("combatant")
	player.queue_free()
	_death.queue_free()
	_death = null
	for child in get_children():
		if child is PlayerDeath:
			child.queue_free()
	_spawn_player()
	hud.setup(player)
	board.player = player
	_pause.player = player


func _on_actor_down(actor: Enemy) -> void:
	if _finished:
		return
	Voices.on_down(actor, actor.last_region, actor.brain.attacker() if actor.brain != null else null)
	if actor.last_by_player:
		_kills += 1
		board.kills = _kills


func _on_player_died() -> void:
	if _finished:
		return
	_deaths += 1
	board.deaths = _deaths
	map.director.player_down()
	if _finished:
		return
	_respawn_left = RESPAWN


func _finish(winner: int) -> void:
	_finished = true
	_respawn_left = 0.0
	Ballistics.bullets.clear()
	player.weapon.release_trigger()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	if player.touch != null:
		player.touch.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _death != null:
		_death.queue_free()
	_death = DeathScreen.new()
	add_child(_death)
	var summary: Array = map.director.result(winner)
	_death.show_result(summary[0], summary[1], _kills, _deaths, map.director.elapsed(), not Net.active() or Net.hosting)
	_death.chosen.connect(_on_death_choice)
	Voices.radio(summary[2], 1.0, true)


func _on_death_choice(action: String) -> void:
	if action == "lobby":
		leave_match()
		return
	if Net.active():
		Net.start_match()
		return
	_clear_match()
	await get_tree().process_frame
	_play(_mode)


func _clear_match() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	AudioServer.playback_speed_scale = 1.0
	Ballistics.bullets.clear()
	for node in [player, hud, board, _death, _ambience, _pause]:
		if is_instance_valid(node):
			node.queue_free()
	player = null
	hud = null
	board = null
	_death = null
	_ambience = null
	_pause = null
	_respawn_left = 0.0
	for child in get_children():
		if child is Shell or child is DroppedProp or child is PlayerDeath:
			child.queue_free()
	map.clear()
	ImpactFX.clear()
