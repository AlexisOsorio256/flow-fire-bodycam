extends Node3D

## Arranque y composicion. UN unico punto donde existe un modo: el lobby elige
## una linea, se construye ese mapa y se entra. No hay gestor de niveles, ni
## escena de transicion, ni persistencia: dos modos y un `get_tree().quit()`.
##
## El environment de `Main.tscn` NO se toca al cambiar de modo. El lobby pinta
## el post de bodycam sobre negro opaco y cada mapa aporta su propia
## iluminacion, asi que tonemapping y exposicion son los mismos en los tres
## estados: no hay dos calibraciones que mantener.

const LOBBY_SCRIPT := preload("res://scripts/Lobby.gd")
const PLAYER_SCRIPT := preload("res://scripts/Player.gd")
const HUD_SCRIPT := preload("res://scripts/HUD.gd")
const COMBAT_SCRIPT := preload("res://scripts/CombatMap.gd")

## Punto de entrada de cada modo: donde aparece el jugador mirando al mapa.
##
## La Z sale de la FACHADA, no de un numero suelto: `Z_S = 5,60` es el eje del
## muro de calle tras la ampliacion del 25 %, y 3,4 m por delante deja al
## jugador en el patio mirando la casa entera en cuadro. Antes eran 7,4 en
## absoluto y con la casa nueva quedaba a 1,8 m del muro: la puerta llenaba la
## pantalla y no se veia la casa.
const SPAWN := {
	"combat": {"pos": Vector3(0.0, 0.05, 12.20), "yaw": 0.0},
}

var map: Node3D
var player: CharacterBody3D
var hud: CanvasLayer
var lobby: CanvasLayer


func _ready() -> void:
	randomize()
	# `--mode=combat` (o `range`) entra directo a un modo saltandose el lobby.
	# Lo necesitan las dos herramientas que miden y miran el juego real
	# (`tools/medir.sh`, `tools/captura.sh`): sin esto mediriarian el lobby.
	for arg in OS.get_cmdline_user_args():
		var kv := (arg as String).split("=")
		if kv.size() == 2 and kv[0] == "--mode" and SPAWN.has(kv[1]):
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


## ESC con el raton suelto, dentro de un modo: volver al lobby. El primer ESC lo
## captura el jugador (suelta el raton y el arma); este es el segundo.
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


## Contenedor del mapa: un solo nodo que se borra entero al salir, sea el banco
## (carcasa horneada + props) o el combate.
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
	var spawn: Dictionary = SPAWN[mode]
	player.global_position = spawn["pos"]
	player.set("yaw_target", spawn["yaw"])
	player.set("yaw", spawn["yaw"])
	# La municion la responde el mapa, no el jugador: banco y combate usan el
	# mismo `AmmoTable`, asi que la recarga no sabe que mapa esta cargado.
	if map != null:
		player.set("ammo", map.get("ammo"))

	hud = HUD_SCRIPT.new()
	hud.name = "HUD"
	add_child(hud)
	hud.setup(player)
