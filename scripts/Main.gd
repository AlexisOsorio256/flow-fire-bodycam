extends Node3D

const LOBBY_SCRIPT := preload("res://scripts/Lobby.gd")
const PLAYER_SCRIPT := preload("res://scripts/Player.gd")
const HUD_SCRIPT := preload("res://scripts/HUD.gd")
const COMBAT_SCRIPT := preload("res://scripts/CombatMap.gd")
const DEATH_HOLD := 4.0

var map: Node3D
var player: CharacterBody3D
var hud: CanvasLayer
var lobby: CanvasLayer


func _ready() -> void:
	randomize()
	map = COMBAT_SCRIPT.new()
	map.name = "CombatMap"
	add_child(map)
	map.call("build")
	if OS.get_cmdline_user_args().has("--mode=combat"):
		_play()
	else:
		_enter_lobby()


func _enter_lobby() -> void:
	_clear_match()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	lobby = LOBBY_SCRIPT.new()
	lobby.name = "Lobby"
	add_child(lobby)
	lobby.mode_chosen.connect(_on_mode_chosen)


func _on_mode_chosen(mode: String) -> void:
	if mode == "quit":
		get_tree().quit()
		return
	lobby.queue_free()
	lobby = null
	_play()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE and player != null \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_enter_lobby()


func _play() -> void:
	map.call("populate")
	player = PLAYER_SCRIPT.new()
	player.name = "Player"
	var spawn: Dictionary = map.call("spawn_point")
	player.position = spawn["pos"]
	player.set("yaw_target", spawn["yaw"])
	player.set("yaw", spawn["yaw"])
	add_child(player)
	player.set("ammo", map.get("ammo"))
	player.died.connect(_on_player_died)
	hud = HUD_SCRIPT.new()
	hud.name = "HUD"
	add_child(hud)
	hud.setup(player)


func _on_player_died() -> void:
	var who := player
	await get_tree().create_timer(DEATH_HOLD).timeout
	if player == who:
		_clear_match()
		_play()


func _clear_match() -> void:
	for node in [player, hud]:
		if node != null and is_instance_valid(node):
			node.queue_free()
	player = null
	hud = null
	for child in get_children():
		if child is Shell or child is DroppedProp:
			child.queue_free()
	map.call("clear")
	ImpactFX.clear()
