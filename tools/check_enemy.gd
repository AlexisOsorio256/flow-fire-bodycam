extends Node
## Check del ENEMIGO. Preguntas MATERIALES, no cobertura:
##
##   1. ¿El asset monta con el rig, los clips y un esqueleto con huesos legibles?
##   2. ¿UN impacto valido MATA? (y el segundo no hace nada: no hay vida)
##   3. ¿La ZONA decide COMO cae? cabeza = fisica ya; pecho = retroceso; pie = tropiezo
##   4. ¿El ragdoll recibe de verdad el impulso del proyectil?
##   5. ¿El enemigo deja de procesar IA y colisiones despues de morir?
##   6. ¿Engancha al jugador si este aparece DESPUES? El orden real de `Main` es
##      poblar el mapa (enemigos) y despues entrar con el `Player`.
##
## La lectura en IMAGEN (sangre, cara pixelada, caida de la planta alta) NO se
## comprueba aqui: eso se responde en una captura. Aqui solo se mide lo que una
## captura no puede decir: zonas, impulso y estado del solver.
##
##   godot4 --path . --headless tools/check_enemy.tscn

var _fallos := 0


func _ready() -> void:
	# Un suelo para el check: un cadaver del ragdoll tiene que tener donde
	# posarse. Sin el, unos huesos sin forma de colision se caen al vacio y
	# el check no lo veria: esto reproduce el fallo real de la captura `kill`
	# (cuerpo que desaparece y solo quedan las gotas flotando).
	var floor_body := StaticBody3D.new()
	floor_body.name = "CheckFloor"
	var floor_col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(12, 0.2, 12)
	floor_col.shape = box
	floor_body.add_child(floor_col)
	floor_body.position = Vector3(0, -0.1, 0)
	add_child(floor_body)
	await _probe_player_lazy()
	await _probe_anatomia()
	for zona in ["cabeza", "pecho", "pie"]:
		await _probe(zona)
	_finish()


## El CUERPO COMPLETO tiene que estar EN CUADRO, y eso empieza por que mida lo
## que mide una persona. Paso medido: el glTF salia con el rig a escala del
## donante (Head a 4,41 m, Foot_L a 0,20) y en la captura `kill` a 4,5 m solo
## entraban piernas y manos: el torso y la cabeza quedaban por encima de la
## banda visible (-0,33..3,57 m). La autoridad de la talla es el RIG (la malla
## es un skinned mesh: su AABB es la caja de bind del nodo y no sigue a los
## huesos, asi que no sirve de medida).
func _probe_anatomia() -> void:
	var enemy := Enemy.new()
	enemy.name = "Enemy_anatomia"
	add_child(enemy)
	await get_tree().process_frame
	await get_tree().process_frame
	if enemy.visual == null or enemy.skeleton == null:
		_fallos += 1
		print("  FALLO: anatomia: el enemigo no monto")
		return
	var head_y := _bone_world(enemy, "Head").y
	var foot_y := _bone_world(enemy, "Foot_L").y
	var alto := head_y - foot_y
	print("  anatomia: rig %.2f m (cabeza %.2f, pie %.2f) tris=%d"
		% [alto, head_y, foot_y, enemy._tris()])
	_check(alto > 1.60 and alto < 2.00,
		"anatomia: el rig mide una persona (%.2f m)" % alto)
	_check(absf(foot_y) < 0.15, "anatomia: los pies apoyan en el suelo (%.2f m)" % foot_y)
	_check(head_y > 1.50, "anatomia: la cabeza queda en la parte alta (%.2f m)" % head_y)
	_check(enemy._tris() > 1000, "anatomia: el mesh trae geometria (%d tris)" % enemy._tris())
	enemy.queue_free()
	await get_tree().process_frame


## El ORDEN real de arranque. `Main` construye el mapa y `CombatMap` puebla los
## enemigos ANTES de `_enter`, que es quien anade al `Player`. Un enemigo que
## resuelve al jugador una sola vez en `_ready` se queda con `_player` nulo para
## siempre: no ve, no apunta y revienta en `_player.global_position` en cuanto un
## disparo lo despierta. Aqui se reproduce ese orden: primero el enemigo, el
## jugador aparece despues.
func _probe_player_lazy() -> void:
	var enemy := Enemy.new()
	enemy.name = "Enemy_lazy"
	add_child(enemy)
	enemy.global_position = Vector3(0, 0, 0)
	await get_tree().process_frame
	await get_tree().process_frame

	if enemy.visual == null or enemy.skeleton == null:
		_fallos += 1
		print("  FALLO: el enemigo no monto (asset o rig)")
		return
	_check(not is_instance_valid(enemy._player),
		"sin jugador: el enemigo arranca sin objetivo (orden de Main)")

	# Un disparo cerca lo despierta SIN verlo: es la ruta que llegaba a
	# `_player.global_position` con `_player` nulo y reventaba cada frame.
	enemy.hear(enemy.global_position)
	for _i in range(4):
		await get_tree().physics_frame
	_check(enemy.state != Enemy.IDLE,
		"sin jugador: el aviso lo despierta sin reventar")

	# Ahora entra el jugador, como en `Main._enter`, y el enemigo tiene que
	# engancharlo en el bucle.
	var player := preload("res://scripts/Player.gd").new()
	player.name = "Player"
	add_child(player)
	player.global_position = Vector3(0, 0.05, 6.0)
	for _i in range(3):
		await get_tree().physics_frame
	_check(is_instance_valid(enemy._player) and enemy._player == player,
		"jugador despues: el enemigo lo re-resuelve en el bucle")

	player.queue_free()
	enemy.queue_free()
	await get_tree().process_frame


func _probe(zona: String) -> void:
	# El jugador DE VERDAD, no un maniqui: el enemigo lo busca por el grupo
	# "player" y la balistica necesita su camara para el silbido de paso. Con un
	# CharacterBody3D vacio el check haria cosas que en partida no pasan.
	var player := preload("res://scripts/Player.gd").new()
	player.name = "Player"
	add_child(player)
	player.global_position = Vector3(0, 0.05, 6.0)

	var enemy := Enemy.new()
	enemy.name = "Enemy_" + zona
	add_child(enemy)
	enemy.global_position = Vector3(0, 0, 0)
	await get_tree().process_frame
	await get_tree().process_frame

	if enemy.visual == null or enemy.skeleton == null:
		_fallos += 1
		print("  FALLO: el enemigo no monto (asset o rig)")
		return
	for clip in ["Idle", "Walk", "Neck"]:
		_check(enemy._clip(clip) != "", "clip %s presente" % clip)
	_check(enemy.ragdoll == null, "vivo sin rigid bodies (se crean al morir)")

	# El punto de impacto por ZONA, leido del propio esqueleto y no de un numero
	# escrito a mano: si el hueso no esta donde el check cree, el check falla.
	var bone: String = {"cabeza": "Head", "pecho": "Chest", "pie": "Shin_L"}[zona]
	var point: Vector3 = enemy.to_global(_bone_local(enemy, bone))
	_check(enemy.is_target(), "%s: vivo es objetivo" % zona)
	enemy.hit(point, Vector3(0, 0, 1), 2.77)
	_check(not enemy.is_target(), "%s: tras el impacto ya no es objetivo" % zona)
	_check(not enemy.is_physics_processing(), "%s: deja de procesar IA" % zona)
	# La sangre es el UNICO feedback (no hay hitmarker): tiene que salir siempre.
	_check(enemy._blood.emitting, "%s: el chorro de sangre sale" % zona)
	_check(enemy._blood.amount >= 20, "%s: la sangre se lee a distancia de juego" % zona)
	_check(enemy._blood_spot.visible, "%s: la mancha queda visible" % zona)

	var before: int = _bones(enemy).size()
	enemy.hit(point, Vector3(0, 0, 1), 2.77)
	_check(_bones(enemy).size() == before, "%s: el segundo impacto no hace nada" % zona)

	# El retardo por zona: la cabeza no tiene reaccion; el pecho y el pie si.
	var delay := 1
	match zona:
		"pecho":
			delay = 6
		"pie":
			delay = 30
	for _i in range(delay):
		await get_tree().physics_frame
	if zona == "pecho":
		_check(enemy.ragdoll == null, "pecho: el retroceso dura su retardo (ragdoll aun no)")
	if zona == "pie":
		_check(enemy.ragdoll == null, "pie: el tropiezo dura su retardo (ragdoll aun no)")
		_check(enemy._hit_leg != "", "pie: se recuerda la pierna golpeada para el tropiezo")
		_check(enemy._region_at(_bone_local(enemy, "Shin_L") + Vector3(0.02, 0, 0)) == "leg",
			"pie: la pantorrilla se lee como pierna")
	if zona == "cabeza":
		_check(enemy.ragdoll != null, "cabeza: la fisica toma el cuerpo en el mismo frame")
	if zona == "pecho":
		_check(enemy._region_at(_bone_local(enemy, "Chest") + Vector3(0.02, 0, 0)) == "torso",
			"pecho: el tronco se lee como torso")
	# El impulso mueve el cuerpo de verdad: se espera a que el simulador tome
	# el control y la ventana de medida empieza EN ESE instante. Medir tarde,
	# con el cuerpo ya posado y con friccion, dejaba el check pasando solo
	# mientras los huesos caian al vacio: con colision eso era invisible.
	for _i in range(60):
		if enemy.ragdoll != null and enemy.ragdoll.is_simulating_physics():
			break
		await get_tree().physics_frame
	_check(enemy.ragdoll != null and enemy.ragdoll.is_simulating_physics(),
		"%s: el simulador toma el control" % zona)

	# Se mide el estado del CUERPO FISICO, no `Skeleton3D.get_bone_global_pose()`:
	# ese getter devuelve la pose de ANIMACION, no la final tras los modificadores
	# (documentado en Skeleton3D: "the final global pose can get overridden by
	# modifiers in the deferred process"). Leyendolo ahi, un ragdoll que funciona
	# se ve como si no se moviera: asi se perdio una hora.
	var hip := _bone_physics(enemy, "Hips")
	_check(hip != null, "%s: la cadera tiene cuerpo fisico" % zona)
	if hip == null:
		player.queue_free()
		enemy.queue_free()
		await get_tree().process_frame
		return
	var start: Vector3 = hip.global_position
	var speed := 0.0
	var moved := 0.0
	for _i in range(30):
		await get_tree().physics_frame
		speed = maxf(speed, hip.linear_velocity.length())
		moved = maxf(moved, hip.global_position.distance_to(start))
	_check(moved > 0.05, "%s: la cadera se desplaza (%.2f m)" % [zona, moved])
	_check(speed > 0.05, "%s: el impulso llego al cuerpo (pico %.2f m/s)" % [zona, speed])

	# La direccion de la caida por zona: cabeza y pecho caen hacia atras (la bala
	# entra por delante); el pie se va de lado.
	var head := _bone_physics(enemy, "Head")
	_check(head != null, "%s: la cabeza tiene cuerpo fisico" % zona)
	_check(_bones(enemy).size() == enemy.skeleton.get_bone_count(),
		"%s: un PhysicalBone3D por hueso (%d/%d)"
			% [zona, _bones(enemy).size(), enemy.skeleton.get_bone_count()])
	_check(enemy.collision_layer == 0 and enemy.collision_mask == 0,
		"%s: el cadaver no esta en ninguna capa de colision" % zona)
	# SANGRE ANCLADA: con el ragdoll ya construido, la mancha tiene que colgar de
	# un hueso fisico para caer con el cuerpo, no quedarse flotando en el aire.
	_check(enemy._blood_spot.get_parent() is PhysicalBone3D,
		"%s: la mancha cuelga del hueso golpeado (no flota)" % zona)

	# CAIDA COMPLETA: ~2 s despues del impacto la cadera tiene que estar
	# POSADA en el suelo (0,0 a 0,8 m) y casi quieta. Un cadaver que se cae
	# al vacio deja un enemigo invisible y sangre flotando: es exactamente lo
	# que se vio en `captures/shot/kill` y lo que este check impide que vuelva.
	for _i in range(90):
		await get_tree().physics_frame
	var settled := _bone_physics(enemy, "Hips")
	var hip_y: float = settled.global_position.y if settled != null else 99.0
	var hip_v: float = settled.linear_velocity.length() if settled != null else 99.0
	print("  %s: cadaver posado: cadera %.2f m, deriva %.2f m/s" % [zona, hip_y, hip_v])
	_check(settled != null and hip_y > -0.40 and hip_y < 0.80,
		"%s: el cadaver descansa en el suelo (cadera %.2f m)" % [zona, hip_y])
	_check(hip_v < 1.5, "%s: la caida termina en reposo (%.2f m/s)" % [zona, hip_v])

	player.queue_free()
	enemy.queue_free()
	await get_tree().process_frame


func _bone_local(enemy: Enemy, name: String) -> Vector3:
	# En espacio del ENEMIGO, no del Skeleton3D: el glTF trae la malla a escala
	# 0,01 dentro del rig y `skeleton.to_local` devuelve centimetros. El punto de
	# impacto que usa `Enemy.hit` sale de `point - global_position`, o sea que la
	# misma unidad que aqui.
	var world := _bone_world(enemy, name)
	return enemy.to_local(world)


func _bone_world(enemy: Enemy, name: String) -> Vector3:
	for i in enemy.skeleton.get_bone_count():
		if enemy.skeleton.get_bone_name(i) == name:
			return enemy.skeleton.to_global(enemy.skeleton.get_bone_global_pose(i).origin)
	return Vector3(0, 1.0, 0)


## Los huesos fisicos del simulador. No hay `get_bones()` en Godot 4.7
## (comprobado con ClassDB): son nodos hijos, y se cuentan como nodos.
func _bones(enemy: Enemy) -> Array:
	if enemy.ragdoll == null:
		return []
	return enemy.ragdoll.find_children("*", "PhysicalBone3D", true, false)


func _bone_physics(enemy: Enemy, name: String) -> PhysicalBone3D:
	for node in _bones(enemy):
		var pb := node as PhysicalBone3D
		if pb.bone_name == name:
			return pb
	return null


func _finish() -> void:
	if _fallos == 0:
		print("CHECK enemy: OK (1 impacto mata, 3 zonas, ragdoll con impulso real)")
	else:
		print("CHECK enemy: %d FALLOS" % _fallos)
	get_tree().quit(1 if _fallos > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fallos += 1
		print("  FALLO: " + message)
