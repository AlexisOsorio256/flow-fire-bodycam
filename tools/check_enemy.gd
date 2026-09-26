extends Node
## Check del ENEMIGO. Cuatro preguntas MATERIALES, no cobertura:
##
##   1. ¿El asset de Blender monta con el rig y los tres clips que el juego exige?
##   2. ¿UN impacto valido MATA? (y el segundo no hace nada: no hay vida)
##   3. ¿El ragdoll recibe de verdad el impulso del proyectil?
##   4. ¿El enemigo deja de procesar IA y colisiones despues de morir?
##
## La distincion de zona (cuello vs cuerpo) NO se comprueba aqui a proposito: es
## una pregunta de IMAGEN, y se responde en `tools/shot.tscn` mirando el frame.
##
##   godot4 --path . --headless tools/check_enemy.tscn


var _fallos := 0


func _ready() -> void:
	# El jugador DE VERDAD, no un maniqui: el enemigo lo busca por el grupo
	# "player" y la balistica necesita su camara para el silbido de paso. Con un
	# CharacterBody3D vacio el check Hairia cosas que en partida no pasan.
	var player := preload("res://scripts/Player.gd").new()
	player.name = "Player"
	add_child(player)
	player.global_position = Vector3(0, 0.05, 6.0)

	var enemy := Enemy.new()
	enemy.name = "Enemy"
	add_child(enemy)
	enemy.global_position = Vector3(0, 0, 0)
	await get_tree().process_frame
	await get_tree().process_frame

	# --- 1. Asset, rig y clips.
	if enemy.visual == null or enemy.skeleton == null:
		_fallos += 1
		print("  FALLO: el enemigo no monto (asset o rig)")
		_finish()
		return
	_check(enemy.skeleton.get_bone_count() >= 12,
		"huesos >= 12 para el ragdoll (tiene %d)" % enemy.skeleton.get_bone_count())
	# VIVO no carga rigid bodies: 19 por enemigo son 57 en un mapa con tres, y
	# ademas se le caian entre los pies al aparecer. Se comprueba en la SECCION 4,
	# ya muerto, que hay uno por hueso.
	_check(enemy.ragdoll == null,
		"vivo sin rigid bodies: el ragdoll se construye al morir")

	# --- 2. UN impacto valido mata.
	var neck_local := Vector3(0.05, 1.47, 0.0)
	var world: Vector3 = enemy.global_position + neck_local
	_check(enemy.is_target(), "vivo: el enemigo es objetivo valido")
	enemy.hit(world, Vector3(0, 0, 1), 2.77)
	_check(not enemy.is_target(), "tras el impacto ya no es objetivo: no hay vida")
	_check(not enemy.is_physics_processing(),
		"tras morir deja de procesar IA (physics_process off)")

	# El segundo impacto no debe reanimarlo ni re-empezar la reaccion.
	var before: int = _bones(enemy).size()
	enemy.hit(world, Vector3(0, 0, 1), 2.77)
	_check(_bones(enemy).size() == before, "el segundo impacto no hace nada")

	# --- 3. El ragdoll recibe el impulso REAL de la bala.
	for _i in range(60):
		await get_tree().physics_frame
	_check(enemy.ragdoll.is_simulating_physics(),
		"el simulador toma el control tras la reaccion")
	# Se mide elestado del CUERPO FISICO, no `Skeleton3D.get_bone_global_pose()`:
	# ese getter devuelve la pose de ANIMACION, no la final tras los modificadores
	# (documentado en Skeleton3D: "the final global pose can get overridden by
	# modifiers in the deferred process"). Leyendolo ahi, un ragdoll que funciona
	# se ve como si no se moviera: asi se perdio una hora.
	var hip := _hip_bone(enemy)
	_check(hip != null, "el hueso de la cadera tiene cuerpo fisico")
	var rest: Vector3 = hip.global_position
	var speed := 0.0
	for _i in range(30):
		await get_tree().physics_frame
		speed = maxf(speed, hip.linear_velocity.length())
	_check(hip.global_position.distance_to(rest) > 0.02,
		"la cadera se desplaza: el cuerpo cae")
	_check(speed > 0.05,
		"el impulso de la bala llego al cuerpo (pico %.2f m/s)" % speed)

	_check(_bones(enemy).size() == enemy.skeleton.get_bone_count(),
		"muerto: un PhysicalBone3D por hueso (%d/%d)"
		% [_bones(enemy).size(), enemy.skeleton.get_bone_count()])

	# --- 4. Colisiones: un cadaver no frena balas.
	_check(enemy.collision_layer == 0 and enemy.collision_mask == 0,
		"el cadaver no esta en ninguna capa de colision")

	_finish()


## Los huesos fisicos del simulador. No hay `get_bones()` en Godot 4.7 (comprobado
## con ClassDB): son nodos hijos, y se cuentan como nodos.
func _bones(enemy: Enemy) -> Array:
	if enemy.ragdoll == null:
		return []
	return enemy.ragdoll.find_children("*", "PhysicalBone3D", true, false)


## El cuerpo fisico de la cadera: el hueso raiz, el que lleva el peso de todo el
## cuerpo y el primero al que hay que mirar para saber si la simulacion corre.
func _hip_bone(enemy: Enemy) -> PhysicalBone3D:
	if enemy.ragdoll == null:
		return null
	for node in _bones(enemy):
		var pb := node as PhysicalBone3D
		if pb.bone_name == "Hips":
			return pb
	return null


func _finish() -> void:
	if _fallos == 0:
		print("CHECK enemy: OK (1 impacto mata, ragdoll con impulso real, IA fuera)")
	else:
		print("CHECK enemy: %d FALLOS" % _fallos)
	get_tree().quit(1 if _fallos > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fallos += 1
		print("  FALLO: " + message)
