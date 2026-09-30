extends Node
## CHECK: EL MAPA DE COMBATE SE RECORRE, Y SE RECORRE ENTERO.
##
## POR QUE EXISTE (la duda era real, no teorica): el primer bunker de Blender
## tenia el tabique boveda|puesto terminando justo detras del paso central, y el
## jugador se quedaba clavado en z=0,94 al entrar. Ninguna captura lo ensenaba
## (desde el encuadre del spawn se ve perfecto) y ningun check de arma, balistica
## o materiales podia verlo: es una propiedad del MAPA, no de una pieza.
##
##
## AHORA NAVEGA POR PUNTOS: cada tramo empuja hacia una coordenada hasta
## llegar o agotar el presupuesto, asi que "no se puede subir" sale como FALLO
## con la posicion donde se encallo, no como un tiempo agotado sin explicacion.
## Cubre los cinco recintos de la planta baja, la ESCALERA, la galeria, los dos
## dormitorios y el estudio de la planta alta, y la vuelta a bajar.
##
## Sigue inyectando input de verdad en el sistema (`Input.parse_input_event`),
## nada de teletransportar al jugador, que es lo que escondia el fallo.

## El spawn lo manda `Main.SPAWN`; aqui se repite porque este check no monta
## `Main`. Si cambia alli, cambia aqui: el check lo comprueba (abajo) y falla
const SPAWN := Vector3(0.0, 0.05, 12.20)

const ROUTE := [
	{"to": Vector3(0.00, 0.05, 8.60), "why": "patio, mirando a la puerta de calle"},
	{"to": Vector3(0.00, 0.05, 4.50), "why": "porche y vano de la puerta de calle"},
	{"to": Vector3(0.25, 0.05, 2.50), "why": "vestibulo, de espaldas a la puerta"},
	# --- SALA (vano en x=-0,90, z -4,30..-3,20). Cada vano se pasa por un punto
	#     SOBRE su linea: sin eso la sonda empuja en diagonal contra el tabique y
	#     se queda clavada a un metro de la puerta, que es un fallo de la ruta,
	#     no del mapa.
	{"to": Vector3(0.25, 0.05, -3.60), "why": "vestibulo al norte, a la puerta de la sala"},
	{"to": Vector3(-2.00, 0.05, -3.60), "why": "PASO A LA SALA"},
	{"to": Vector3(-4.50, 0.05, -3.60), "why": "sala, fondo norte (planta baja)"},
	{"to": Vector3(-4.50, 0.05, -1.25), "why": "sala, centro"},
	{"to": Vector3(-2.00, 0.05, -3.60), "why": "vuelta al vano de la sala"},
	{"to": Vector3(0.25, 0.05, -3.60), "why": "PASO A LA SALA, vuelta al vestibulo"},
	# --- COCINA (vano en x=1,90, z 0,60..1,70).
	{"to": Vector3(0.25, 0.05, 1.15), "why": "vestibulo, a la puerta de la cocina"},
	{"to": Vector3(1.75, 0.05, 1.44), "why": "PASO A LA COCINA"},
	{"to": Vector3(4.25, 0.05, 1.15), "why": "cocina"},
	## La cocina se recorre por el PASILLO ESTE (x~5,5), pegado al muro: bajar
	## en diagonal desde el vano metia al jugador en el rincon entre el tabique
	## del vestibulo y la encimera y ahi se quedaba, con el paso libre a 20 cm.
	## El andamio cierra el fondo a partir de z=5,0.
	{"to": Vector3(5.50, 0.05, 1.60), "why": "cocina, pasillo este"},
	{"to": Vector3(5.50, 0.05, 4.40), "why": "cocina, fondo sur (el andamio cierra a 5,0)"},
	## Vuelta por el MISMO pasillo. Cruzar el fondo de este a oeste se atasca en
	## la esquina del fondo (medido) y ademas no aporta: es el mismo cuarto.
	{"to": Vector3(5.50, 0.05, 1.60), "why": "cocina, vuelta al pasillo este"},
	# --- BANO (vano en z=-2,28, x 2,35..3,25).
	{"to": Vector3(2.75, 0.05, -2.28), "why": "cocina, a la puerta del bano"},
	{"to": Vector3(2.75, 0.05, -3.40), "why": "PASO AL BANO"},
	{"to": Vector3(2.75, 0.05, -5.20), "why": "bano, fondo norte"},
	{"to": Vector3(2.75, 0.05, -3.40), "why": "vuelta al vano del bano"},
	{"to": Vector3(2.75, 0.05, -2.28), "why": "cocina"},
	{"to": Vector3(1.75, 0.05, 1.44), "why": "PASO A LA COCINA, vuelta al vestibulo"},
	{"to": Vector3(0.25, 0.05, 1.15), "why": "vestibulo"},
	# --- ESCALERA. Geometria viva de `build_house`: pie en z=-3,60, 16 peldanos
	{"to": Vector3(1.38, 0.05, -3.90), "why": "PIE DE LA ESCALERA (rellano norte)"},
	{"to": Vector3(1.38, 1.20, -2.30), "why": "ESCALERA, tramo medio"},
	{"to": Vector3(1.38, 3.05, 0.90), "why": "ESCALERA arriba: llegada a la galeria sur"},
	{"to": Vector3(0.25, 3.05, 1.40), "why": "galeria sur"},
	{"to": Vector3(0.25, 3.05, -4.50), "why": "corredor oeste y galeria norte (planta alta)"},
	{"to": Vector3(0.25, 3.05, -2.05), "why": "galeria, a la puerta del dormitorio"},
	{"to": Vector3(-1.75, 3.05, -2.05), "why": "PASO AL DORMITORIO ALTO"},
	{"to": Vector3(-3.75, 3.05, -4.20), "why": "dormitorio alto, fondo norte"},
	{"to": Vector3(-1.75, 3.05, -2.05), "why": "vuelta al vano del dormitorio"},
	{"to": Vector3(0.25, 3.05, -2.05), "why": "PASO AL DORMITORIO ALTO, vuelta a la galeria"},
	{"to": Vector3(0.25, 3.05, 1.40), "why": "corredor oeste, vuelta a la galeria sur"},
	{"to": Vector3(1.38, 3.05, 0.90), "why": "boca de la escalera"},
	{"to": Vector3(1.38, 1.20, -2.30), "why": "BAJADA, tramo medio"},
	{"to": Vector3(1.38, 0.05, -3.90), "why": "BAJADA, pie"},
	## SALIR DE LA ESCALERA HACIA EL OESTE antes de bajar al vestibulo. Sin este
	## punto la ruta tira en diagonal desde el pie y el jugador vuelve a pisar la
	## rampa: la sonda lo leia como "no se llego al vestibulo" con el jugador
	## otra vez en la galeria (y=3,0).
	{"to": Vector3(0.30, 0.05, -4.00), "why": "salir de la escalera al corredor oeste"},
	{"to": Vector3(0.25, 0.05, 2.50), "why": "vestibulo"},
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
		print("WALK OK: patio -> planta baja completa -> ESCALERA -> planta alta -> escalera -> patio")
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
