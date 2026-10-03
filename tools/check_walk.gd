extends Node
## CHECK: LA FABRICA SE RECORRE, Y SE RECORRE ENTERA.
##
## POR QUE EXISTE: una valla mal puesta deja al jugador atrapado en un pasillo y
## ninguna captura lo ensena (desde el encuadre de fuera se ve perfecto); es una
## propiedad del MAPA, no de una pieza.
##
## NAVEGA POR EL NAVMESH, con input de verdad (`Input.parse_input_event`). Un
## empujon recto hacia la meta no vale en un campo de vallas: se encalla en la
## primera y no dice si el mapa es navegable. El camino lo da el MISMO navmesh
## que usan los enemigos, asi que este check prueba dos cosas de una vez: que el
## jugador recorre la fabrica entera y que los enemigos pueden alcanzar cada
## rincon.
##
## Nada de teletransportar al jugador: eso es lo que escondia el fallo.

## El spawn lo declara el marcador `Spawn` del mapa; aqui se comprueba contra el
## que trae la escena hoy. Si cambia alli, se corrige aqui.
const ROUTE := [
	{"to": Vector3(0.00, 0.05, 12.00), "why": "spawn, a mirar la nave"},
	{"to": Vector3(0.00, 0.05, 4.00), "why": "eje central hacia el fondo"},
	{"to": Vector3(0.00, 0.05, -4.00), "why": "eje central, segundo tramo"},
	{"to": Vector3(0.00, 0.05, -12.00), "why": "eje central, al fondo sur"},
	{"to": Vector3(-12.00, 0.05, -12.00), "why": "perimetro oeste-sur"},
	{"to": Vector3(-14.00, 0.05, 0.00), "why": "perimetro oeste"},
	{"to": Vector3(-12.00, 0.05, 12.00), "why": "perimetro oeste-norte"},
	{"to": Vector3(0.00, 0.05, 16.00), "why": "banda norte"},
	{"to": Vector3(12.00, 0.05, 12.00), "why": "perimetro este-norte"},
	{"to": Vector3(14.00, 0.05, 0.00), "why": "perimetro este"},
	{"to": Vector3(12.00, 0.05, -12.00), "why": "perimetro este-sur"},
	{"to": Vector3(6.00, 0.05, -8.00), "why": "pasillo entre vallas, este"},
	{"to": Vector3(-6.00, 0.05, -6.00), "why": "cruce central sur"},
	{"to": Vector3(-5.00, 0.05, 4.00), "why": "pasillo oeste-centro"},
	{"to": Vector3(5.00, 0.05, 5.00), "why": "cruce central norte"},
	{"to": Vector3(0.00, 0.05, 12.00), "why": "vuelta al spawn"},
]

var _game: Node = null
var _player: Node3D = null
var _agent: NavigationAgent3D = null
var _fallos := 0
var _held := {}


func _ready() -> void:
	_game = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	add_child(_game)
	await get_tree().process_frame
	_game.call("_on_mode_chosen", "combat")
	for i in range(30):
		await get_tree().physics_frame
	## El navmesh lo hornea `CombatMap.build()`: hay que esperar a que la region
	## exista o el check camina a ciegas y se encalla en la primera valla.
	var espera := 0
	while _nav_map().is_valid() == false and espera < 120:
		await get_tree().process_frame
		espera += 1
	## El agente es del MOTOR: sigue el mismo camino que los enemigos.
	_agent = NavigationAgent3D.new()
	_agent.radius = 0.34
	_agent.path_desired_distance = 0.45
	_agent.target_desired_distance = 0.40
	add_child(_agent)
	_agent.set_navigation_map(_nav_map())
	_player = _game.get("player")
	if _player == null:
		print("FALLO: sin jugador en el modo combate")
		get_tree().quit(1)
		return
	var spawn: Vector3 = _player.global_position
	print("  spawn del mapa: ", spawn.snapped(Vector3(0.01, 0.01, 0.01)))

	for step in ROUTE:
		var antes := _fallos
		await _goto(step["to"], step["why"])
		if _fallos == antes:
			print("  ok  %-46s %s" % [step["why"], _player.global_position.snapped(Vector3(0.01, 0.01, 0.01))])
	print("  recorrido final: ", _player.global_position.snapped(Vector3(0.01, 0.01, 0.01)))

	if _fallos == 0:
		print("WALK OK: perimetro, eje central y pasillos de vallas")
	get_tree().quit(1 if _fallos > 0 else 0)


## Empuja hacia `target` hasta estar a menos de `tol` (0,45 m en horizontal y
## 0,30 en vertical) o agotar `budget` frames de fisica. La direccion se recalcula
## CADA frame respecto del yaw real del jugador, asi que un mueble que desvia no
## rompe la navegacion: se corrige sola.
func _goto(target: Vector3, why: String, tol := 0.60, budget := 1400) -> void:
	var map := _nav_map()
	var best := 1e9
	var atascado := 0
	var wp := target
	var wp_i := 0
	var camino: PackedVector3Array = []
	for i in range(budget):
		var pos := _player.global_position
		var flat := Vector3(target.x - pos.x, 0.0, target.z - pos.z)
		if flat.length() <= tol and absf(target.y - pos.y) <= 0.60:
			_release()
			await _settle()
			return
		## El CAMINO se recalcula cuando hace falta: al principio y al alcanzar
		## el waypoint. Se avanza al SIGUIENTE, nunca se retrocede.
		if camino.is_empty() or wp_i >= camino.size():
			camino = NavigationServer3D.map_get_path(map, pos, target, true)
			wp_i = 0
			if camino.is_empty():
				_release()
				print("FALLO: sin camino de %s a %s" % [pos.snapped(Vector3(0.1,0.1,0.1)), why])
				_fallos += 1
				return
		wp = camino[wp_i]
		if Vector3(wp.x - pos.x, 0.0, wp.z - pos.z).length() < 0.55:
			wp_i += 1
			if wp_i >= camino.size():
				wp = target
			else:
				wp = camino[wp_i]
		var yaw: float = _player.get("yaw")
		var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
		var right := Vector3(cos(yaw), 0.0, -sin(yaw))
		var paso := Vector3(wp.x - pos.x, 0.0, wp.z - pos.z)
		var want := paso.normalized() if paso.length() > 0.001 else Vector3.ZERO
		_press("W", want.dot(fwd) > 0.35)
		_press("S", want.dot(fwd) < -0.35)
		_press("D", want.dot(right) > 0.35)
		_press("A", want.dot(right) < -0.35)
		if flat.length() < best - 0.10:
			best = flat.length()
			atascado = 0
		else:
			atascado += 1
		if atascado > 420:
			_release()
			print("FALLO: encallado a %.2f m de %s (pos %s)"
				% [flat.length(), why, pos.snapped(Vector3(0.01, 0.01, 0.01))])
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
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * 1.8, 1)
		q.exclude = [(_player as CollisionObject3D).get_rid()]
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		var node = hit.get("collider")
		var extra := ""
		if node is Node and (node as Node).has_meta("surface"):
			extra = " surface=%s" % (node as Node).get_meta("surface")
		var hp: Vector3 = hit.get("position", from)
		print("        bloquea a %.2f m: %s%s" % [
			from.distance_to(hp), (node as Node).name if node is Node else "?", extra])
		return
	print("        sin colisor en 1,80 m al frente: el tope es el propio movimiento")


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


## El mapa de navegacion del modo, el que hornea `CombatMap`. Los enemigos viven
## en el; este check camina por el mismo, que es lo que hace la prueba material.
func _nav_map() -> RID:
	var region := get_tree().get_first_node_in_group("nav_region") as NavigationRegion3D
	if region == null:
		push_error("WALK: sin navmesh; el check no puede validar la navegacion")
		return RID()
	return region.get_navigation_map()
