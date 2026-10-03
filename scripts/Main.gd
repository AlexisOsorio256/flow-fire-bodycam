extends Node3D

## Arranque: lobby o `--mode=combat`, construccion del modo, jugador y HUD.

const LOBBY_SCRIPT := preload("res://scripts/Lobby.gd")
const PLAYER_SCRIPT := preload("res://scripts/Player.gd")
const HUD_SCRIPT := preload("res://scripts/HUD.gd")
const COMBAT_SCRIPT := preload("res://scripts/CombatMap.gd")

func spawn(_mode: String) -> Dictionary:
	if map != null:
		var modo := map.find_child("CombatMap", true, false)
		if modo != null and modo.has_method("spawn_point"):
			return modo.call("spawn_point")
	return {"pos": Vector3(0.0, 0.05, 17.5), "yaw": 0.0}

var map: Node3D
var player: CharacterBody3D
var hud: CanvasLayer
var lobby: CanvasLayer


func _ready() -> void:
	randomize()
	for arg in OS.get_cmdline_user_args():
		var kv := (arg as String).split("=")
		if kv.size() == 2 and kv[0] == "--mode" and kv[1] == "combat":
			map = _build_mode(kv[1])
			_enter(kv[1])
			return
	_enter_lobby()


func _enter_lobby() -> void:
	_clear_mode()
	lobby = LOBBY_SCRIPT.new()
	lobby.name = "Lobby"
	add_child(lobby)
	lobby.mode_chosen.connect(_on_mode_chosen)


func _on_mode_chosen(mode: String) -> void:
	if mode == "quit":
		get_tree().quit()
		return
	if lobby != null:
		remove_child(lobby)
		lobby.queue_free()
		lobby = null
	map = _build_mode(mode)
	_enter(mode)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE and player != null \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_enter_lobby()


func _clear_mode() -> void:
	for node in [map, player, hud]:
		if node != null and is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	map = null
	player = null
	hud = null


func _build_mode(mode: String) -> Node3D:
	var root := Node3D.new()
	root.name = mode.capitalize()
	add_child(root)
	var combat := COMBAT_SCRIPT.new()
	combat.name = "CombatMap"
	root.add_child(combat)
	combat.call("build")
	return root


func _enter(mode: String) -> void:
	player = PLAYER_SCRIPT.new()
	player.name = "Player"
	add_child(player)
	var punto: Dictionary = spawn(mode)
	player.global_position = punto["pos"]
	player.set("yaw_target", punto["yaw"])
	player.set("yaw", punto["yaw"])
	if map != null:
		player.set("ammo", map.get("ammo"))

	hud = HUD_SCRIPT.new()
	hud.name = "HUD"
	add_child(hud)
	hud.setup(player)
