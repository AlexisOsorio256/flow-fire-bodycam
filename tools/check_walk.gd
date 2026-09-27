extends Node
## CHECK: EL MAPA DE COMBATE SE RECORRE.
##
## POR QUE EXISTE (la duda era real, no teorica): el primer bunker de Blender
## tenia el tabique boveda|puesto terminando justo detras del paso central, y el
## jugador se quedaba clavado en z=0,94 al entrar. Ninguna captura lo ensenaba
## (desde el encuadre del spawn se ve perfecto) y ningun check de arma, balistica
## o materiales podia verlo: es una propiedad del MAPA, no de una pieza.
##
## QUE COMPRUEBA: inyecta W/SHIFT/A/D de verdad en el sistema de input (nada de
## teletransportar al jugador, que es lo que escondia el fallo) y exige que el
## recorrido patio -> brecha -> corredor -> paso central -> nave -> boveda llegue
## a cada recinto. Un muro invisible, un dintel bajo de mas o un prop mal puesto
## lo tumban.

const SPAWN := Vector3(0.0, 0.05, 7.4)

var _game: Node = null
var _player: Node3D = null
var _fallos := 0


func _key(code: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _ready() -> void:
	_game = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	add_child(_game)
	await get_tree().process_frame
	_game.call("_on_mode_chosen", "combat")
	for i in range(30):
		await get_tree().physics_frame
	_player = _game.get("player")
	if _player == null:
		print("FALLO: sin jugador en el modo combate")
		get_tree().quit(1)
		return
	if _player.global_position.distance_to(SPAWN) > 0.2:
		print("FALLO: el jugador no nace en el spawn medido ", _player.global_position)
		_fallos += 1

	# 1. Recto: patio -> brecha de entrada -> corredor -> paso central -> nave.
	#    Es LA regresion que motivo este check: con el tabique boveda|puesto
	#    terminando detras del paso, el jugador se quedaba clavado en z=0,94.
	await _leg({"W": true}, 240)
	_check("paso central cruzado (z < -1,0)", _player.global_position.z < -1.0)
	_check("sin caerse del suelo", absf(_player.global_position.y) < 0.4)
	# 2. Sesgo atras-izquierda: se rodea el canto del tabique y el barril
	#    deslizando por el muro (como lo haria una persona) y se entra en la
	#    boveda ciega. Un muro invisible entre la nave y la boveda lo tumba.
	await _leg({"S": true, "A": true}, 110)
	_check("boveda alcanzada (x < -2,5)", _player.global_position.x < -2.5)
	print("  recorrido: ", _player.global_position.snapped(Vector3(0.01, 0.01, 0.01)))

	if _fallos == 0:
		print("WALK OK: patio -> corredor -> nave -> boveda -> nave")
	get_tree().quit(1 if _fallos > 0 else 0)


func _leg(keys: Dictionary, frames: int) -> void:
	for key in keys:
		_key(_code(key), true)
	for i in range(frames):
		await get_tree().physics_frame
	for key in keys:
		_key(_code(key), false)
	for i in range(15):
		await get_tree().physics_frame


func _code(name: String) -> int:
	match name:
		"W":
			return KEY_W
		"A":
			return KEY_A
		"D":
			return KEY_D
	return KEY_S


func _check(what: String, ok: bool) -> void:
	if ok:
		print("  ", what, "  OK")
	else:
		print("FALLO: ", what, " pos=", _player.global_position.snapped(Vector3(0.01, 0.01, 0.01)))
		_fallos += 1
