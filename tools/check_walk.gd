extends Node
## CHECK: EL MAPA DE COMBATE SE RECORRE, Y SE RECORRE ENTERO.
##
## POR QUE EXISTE: un tabique mal puesto deja al jugador clavado en un vano y
## ninguna captura lo ensena (desde el encuadre de fuera se ve perfecto); es una
## propiedad del MAPA, no de una pieza.
##
## NAVEGA POR PUNTOS: cada tramo empuja hacia una coordenada hasta llegar o
## agotar el presupuesto, asi que "no se puede pasar" sale como FALLO con la
## posicion donde se encallo. Recorre el patio, el pasillo central, los SEIS
## cuartos y los cuatro tabiques que los encadenan.
##
## Inyecta input de verdad (`Input.parse_input_event`), nada de teletransportar
## al jugador, que es lo que escondia el fallo.

## El spawn lo manda `Main.SPAWN`; aqui se repite porque este check no monta
## `Main`. Si cambia alli, cambia aqui: el check lo comprueba (abajo) y falla.
const SPAWN := Vector3(0.0, 0.05, 12.20)

const ROUTE := [
	{"to": Vector3(0.00, 0.05, 9.00), "why": "patio norte, mirando a la puerta"},
	{"to": Vector3(0.00, 0.05, 7.00), "why": "vano de la puerta norte"},
	{"to": Vector3(0.00, 0.05, 6.00), "why": "pasillo, dentro"},
	# --- CUARTOS DEL OESTE, encadenados por sus tabiques (puertas en x=-3,00).
	#     Cada vano se pasa por un punto SOBRE su linea: sin eso la sonda empuja
	#     en diagonal contra el tabique y se queda clavada a un metro.
	{"to": Vector3(0.00, 0.05, 4.66), "why": "pasillo, a la puerta del cuarto noroeste"},
	{"to": Vector3(-2.60, 0.05, 4.66), "why": "PASO AL CUARTO NOROESTE"},
	{"to": Vector3(-4.40, 0.05, 5.60), "why": "cuarto noroeste, esquina"},
	{"to": Vector3(-3.00, 0.05, 2.33), "why": "tabique, a la puerta del cuarto oeste"},
	{"to": Vector3(-3.00, 0.05, 1.40), "why": "PASO AL CUARTO OESTE"},
	{"to": Vector3(-4.40, 0.05, 0.00), "why": "cuarto oeste, fondo"},
	{"to": Vector3(-3.00, 0.05, -2.33), "why": "tabique sur, a la puerta del cuarto suroeste"},
	{"to": Vector3(-3.00, 0.05, -3.40), "why": "PASO AL CUARTO SUROESTE"},
	{"to": Vector3(-4.40, 0.05, -5.60), "why": "cuarto suroeste, esquina"},
	{"to": Vector3(-2.60, 0.05, -4.66), "why": "vano del cuarto suroeste al pasillo"},
	{"to": Vector3(0.00, 0.05, -4.66), "why": "PASO AL CUARTO SUROESTE, vuelta al pasillo"},
	# --- CUARTOS DEL ESTE, por el mismo patron.
	{"to": Vector3(0.00, 0.05, 0.00), "why": "pasillo, a la puerta del cuarto este"},
	{"to": Vector3(2.60, 0.05, 0.00), "why": "PASO AL CUARTO ESTE"},
	{"to": Vector3(4.40, 0.05, 0.00), "why": "cuarto este, fondo"},
	{"to": Vector3(3.00, 0.05, -2.33), "why": "tabique sur, a la puerta del cuarto sureste"},
	{"to": Vector3(3.00, 0.05, -3.40), "why": "PASO AL CUARTO SURESTE"},
	{"to": Vector3(4.40, 0.05, -5.60), "why": "cuarto sureste, esquina"},
	{"to": Vector3(2.60, 0.05, -4.66), "why": "vano del cuarto sureste al pasillo"},
	{"to": Vector3(0.00, 0.05, -4.66), "why": "PASO AL CUARTO SURESTE, vuelta al pasillo"},
	{"to": Vector3(0.00, 0.05, 4.66), "why": "pasillo entero, de sur a norte"},
	{"to": Vector3(2.60, 0.05, 4.66), "why": "PASO AL CUARTO NORESTE"},
	{"to": Vector3(4.40, 0.05, 5.60), "why": "cuarto noreste, esquina"},
	{"to": Vector3(3.00, 0.05, 2.33), "why": "tabique, a la puerta del cuarto este"},
	{"to": Vector3(3.00, 0.05, 1.40), "why": "PASO AL CUARTO ESTE, por el tabique"},
	{"to": Vector3(3.00, 0.05, 2.33), "why": "vuelta al tabique"},
	{"to": Vector3(2.60, 0.05, 4.66), "why": "vuelta al vano del cuarto noreste"},
	{"to": Vector3(0.00, 0.05, 4.66), "why": "PASO AL CUARTO NORESTE, vuelta al pasillo"},
	{"to": Vector3(0.00, 0.05, 6.40), "why": "pasillo norte"},
	{"to": Vector3(0.00, 0.05, 7.00), "why": "vano de la puerta norte"},
	{"to": Vector3(0.00, 0.05, 9.00), "why": "patio"},
	{"to": Vector3(0.00, 0.05, 12.20), "why": "patio (vuelta al spawn)"},
]

var _game: Node = null
var _player: Node3D = null
var _fallos := 0
var _held := {}


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

	for step in ROUTE:
		var antes := _fallos
		await _goto(step["to"], step["why"])
		if _fallos == antes:
			print("  ok  %-46s %s" % [step["why"], _player.global_position.snapped(Vector3(0.01, 0.01, 0.01))])
	print("  recorrido final: ", _player.global_position.snapped(Vector3(0.01, 0.01, 0.01)))

	if _fallos == 0:
		print("WALK OK: patio -> pasillo -> seis cuartos y sus tabiques -> patio")
	get_tree().quit(1 if _fallos > 0 else 0)


## Empuja hacia `target` hasta estar a menos de `tol` (0,45 m en horizontal y
## 0,30 en vertical) o agotar `budget` frames de fisica. La direccion se recalcula
## CADA frame respecto del yaw real del jugador, asi que un mueble que desvia no
## rompe la navegacion: se corrige sola.
func _goto(target: Vector3, why: String, tol := 0.45, budget := 420) -> void:
	var stall := 0
	var best := 1e9
	for i in range(budget):
		var pos := _player.global_position
		var flat := Vector3(target.x - pos.x, 0.0, target.z - pos.z)
		var dy := target.y - pos.y
		if flat.length() <= tol and absf(dy) <= 0.60:
			_release()
			await _settle()
			return
		var yaw: float = _player.get("yaw")
		# Ejes del jugador en el mundo (mismos que `Player._physics_process`).
		var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
		var right := Vector3(cos(yaw), 0.0, -sin(yaw))
		var want := flat.normalized() if flat.length() > 0.001 else Vector3.ZERO
		_press("W", want.dot(fwd) > 0.35)
		_press("S", want.dot(fwd) < -0.35)
		_press("D", want.dot(right) > 0.35)
		_press("A", want.dot(right) < -0.35)
		if flat.length() < best - 0.05:
			best = flat.length()
			stall = 0
		else:
			stall += 1
		if stall > 200:
			_release()
			print("FALLO: encallado a %.2f m de %s (objetivo %s, pos %s)"
				% [flat.length(), why, target.snapped(Vector3(0.01, 0.01, 0.01)),
				   pos.snapped(Vector3(0.01, 0.01, 0.01))])
			_culpable(pos + Vector3(0.0, 0.95, 0.0), flat)
			_fallos += 1
			return
		await get_tree().physics_frame
	_release()
	print("FALLO: no se llego a %s en %d frames (pos %s)"
		% [why, budget, _player.global_position.snapped(Vector3(0.01, 0.01, 0.01))])
	_fallos += 1


func _culpable(eye: Vector3, flat: Vector3) -> void:
	var space := _player.get_world_3d().direct_space_state
	var dir := Vector3(flat.x, 0.0, flat.z).normalized()
	for dy in [0.0, -0.55, 0.45]:
		var from := eye + Vector3(0.0, dy, 0.0)
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * 1.6, 1)
		q.exclude = [(_player as CollisionObject3D).get_rid()]
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		var node = hit.get("collider")
		var extra := ""
		if node is Node and (node as Node).has_meta("surface"):
			extra = " surface=%s" % (node as Node).get_meta("surface")
		if node is Node:
			extra += " penetrable=%s" % (node as Node).get_meta("penetrable", false)
		var hp: Vector3 = hit.get("position", from)
		print("        bloquea a %.2f m: %s%s" % [
			from.distance_to(hp), (node as Node).name if node is Node else "?", extra])
		return
	print("        sin colisor en 1,60 m al frente: el tope es el propio movimiento")


func _settle() -> void:
	for i in range(12):
		await get_tree().physics_frame


func _press(action: String, on: bool) -> void:
	if _held.get(action, false) == on:
		return
	_held[action] = on
	_key(_code(action), on)


func _release() -> void:
	for action in ["W", "A", "S", "D"]:
		_press(action, false)


func _key(code: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _code(name: String) -> int:
	match name:
		"W":
			return KEY_W
		"A":
			return KEY_A
		"D":
			return KEY_D
	return KEY_S
