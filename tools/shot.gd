extends Node
## Shot: captura el juego REAL a frames PNG.
##
## Lo que no sale en una captura no existe.
##
## Uso (lo orquesta tools/captura.sh):
##   godot4 --path . --resolution 1920x1080 tools/shot.tscn -- \
##     --action=ads --out=captures/shot/ads --warmup=30 --total=8
##
## OJO: los argumentos van en forma --clave=valor. Godot parte
## `OS.get_cmdline_user_args()` por espacios, asi que "--out X" llega como dos
## elementos y el parser lo ignora EN SILENCIO (paso, y las capturas acabaron
## todas en el directorio por defecto sin avisar).

var action := "idle"
## Modo de juego que se captura. Solo existe `combat`: el banco de tiro y sus
var mode := "combat"
var out_dir := "/tmp/shot"
var warmup := 30
var total := 8
var time_scale := 1.0
var frame_stride := 1
## Frames de mecanica a simular ANTES de la accion.
var advance := 0

var _frame := 0
## Tiempo de JUEGO acumulado (ms) y el instante de la accion. Las capturas se
## nombran por su offset real desde la accion, no por su indice: con camara lenta
## `Engine.time_scale` cambia cuanto juego cabe en un frame, y el indice miente.
var _game_ms := 0.0
var _action_ms := -1.0
var _game: Node = null
var _player: Node = null
var _weapon: Node = null
var _view: Viewport = null
var _shots := 0
var _hero_step := 0
var _hero_timer := 0.0
## Capa 1 = mundo de la casa (muros, suelo, mobiliario con colisor). Las
## consultas de encuadre (sitio libre y linea de vista) solo la ven: un enemigo
## u otro cuerpo dinamico jamas bloquea una colocacion de camara.
const CAPA_MUNDO := 1


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := (a as String).split("=")
		if kv.size() != 2:
			continue
		match kv[0]:
			"--action":
				action = kv[1]
			"--out":
				out_dir = kv[1]
			"--warmup":
				warmup = int(kv[1])
			"--total":
				total = int(kv[1])
			"--time-scale":
				time_scale = float(kv[1])
			"--stride":
				frame_stride = int(kv[1])
			"--advance":
				advance = int(kv[1])
	# El juego arranca en el lobby; para mirar un modo hay que entrar en el. Es el
	# mismo `--mode` que lee `Main.gd`, no un atajo del capturador.
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with("--mode="):
			mode = (a as String).split("=")[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	Engine.time_scale = time_scale
	_game = load("res://scenes/Main.tscn").instantiate()
	add_child(_game)
	_view = get_viewport()
	await get_tree().process_frame
	_player = _game.get_node_or_null("Player")
	if _player != null:
		_weapon = _player.get("weapon")
	# TODOS los enemigos quietos EN SU POSTE: la IA ve al jugador en el patio por
	# la puerta y camina hacia el durante el warmup, y un encuadre calibrado
	# contra un poste queda apuntando al hueco que dejo el enemigo al irse. La
	# colocacion de look/kill vuelve a congelar al suyo.
	#
	# El mapa (y con el los enemigos) puede entrar varios frames despues de este
	# harness: se espera al grupo con tope antes de colocar, porque colocar sobre
	# un grupo vacio mandaba la camara al spawn sin decir nada. Solo lo esperan
	# las acciones que necesitan cuerpo: en range no hay enemigos y la espera
	# seria un retardo fijo en cada captura del banco.
	var espera := 0
	if action in ["look", "enemy", "neck", "kill", "enemy_fire", "corpse"]:
		while espera < 240 and get_tree().get_nodes_in_group("enemy").is_empty():
			await get_tree().process_frame
			espera += 1
		# enemy_fire necesita al enemigo VIVO: congelarlo es para los encuadres
		# estaticos, no para el disparo que se quiere mirar.
		if action != "enemy_fire":
			for e in get_tree().get_nodes_in_group("enemy"):
				_freeze(e)
		## La navegacion ya funciona: el resto de puestos cruza el vano y se
		## planta al lado de la camara. Para mirar un cadaver hay que dejar el
		## escenario quieto o la captura sale con un cuerpo vivo de fondo.
		else:
			for e in get_tree().get_nodes_in_group("enemy"):
				if e != _first_enemy():
					_freeze(e)
	_place()
	if (action == "enemy" or action == "neck" or action == "kill" \
			or action == "corpse") and _weapon != null:
		_weapon.set_aim(true)
	if action.begins_with("ads") and _weapon != null:
		_weapon.set_aim(true)


## Encuadres: cada accion lleva al jugador donde esa accion se ve.
## La variable `p` solo existe AQUI. Meter ramas de encuadre en `_trigger()` (que
## no tiene jugador) fue un error de sintaxis que dejo el juego sin arrancar.
func _place() -> void:
	if _player == null:
		return
	if mode == "combat":
		_place_combat()
		return
	## Cualquier otro modo es el LOBBY (`Main.SPAWN` no lo conoce): no hay
	push_error("SHOT modo desconocido: " + mode + " (solo existe `combat`)")


## Encuadres del mapa (docs/MAP.md). look/kill/enemy/neck se colocan relativos
## AL POSTE del enemigo mas cercano (_colocar_frente_a): jugador en el mismo
## cuarto y con linea de vista libre. El resto se apoya en el pasillo central,
## que es el eje del mapa y el encuadre de juego real.
func _place_combat() -> void:
	var p := _player as Node3D
	var enemy := _first_enemy()
	match action:
		"hero_normal", "hero_slow":
			# PATIO NORTE: el punto de aparicion real (Main.SPAWN) mirando a la
			# fachada. Es el encuadre que ensena el mapa entero.
			p.global_position = Vector3(0.0, 0.05, 12.20)
			_aim(0.0, -0.015)
		"depot", "idle", \
		"fire", "ads_fire", "empty", "reload", "reload_empty", "inspect", \
		"downrange", "ads", "pen", "crate":
			# PASILLO CENTRAL de norte a sur, a media altura: el encuadre de juego.
			p.global_position = Vector3(0.0, 0.05, 5.60)
			_aim(0.0, -0.03)
		"patio":
			# FACHADA EN OBLICUO desde el patio noroeste, para ver el canto del
			# alero y los vanos, que de frente no se leen.
			p.global_position = Vector3(-4.60, 0.05, 11.00)
			_aim(-0.72, -0.05)
		"back":
			# CUARTO OESTE mirando al fondo: el encuadre que decide si el cuarto
			# cierra o si se ve el vacio detras.
			p.global_position = Vector3(-1.40, 0.05, 4.66)
			_aim(-1.5708, -0.03)
		"wall", "drywall":
			# MURO DE TABLERO a 3,7 m, con el impacto en el centro del cuadro: es
			# el encuadre que hace falta para MIRAR un decal.
			p.global_position = Vector3(-1.40, 0.05, 4.66)
			_aim(-1.5708, -0.03)
		"steel":
			# CELOSIA: el pasillo mirando arriba a la cercha, que es el acero.
			p.global_position = Vector3(0.0, 0.05, 2.00)
			_aim(0.0, 0.62)
		"wood":
			# TABLERO DEL SUELO a 2,5 m por delante: la superficie `pine`.
			p.global_position = Vector3(0.0, 0.05, 4.00)
			_aim(0.0, -0.55)
		"look":
			# A 3,2 m del enemigo, a la altura del pecho. Es el encuadre que
			# decide si el asset es una persona o un muneco roto: sin disparar.
			if enemy == null:
				p.global_position = Vector3(0.0, 0.05, 5.60)
				_aim(0.0, -0.03)
				return
			_freeze(enemy)
			_colocar_frente_a(enemy, 3.2, 1.15)
		"corpse":
			# EL CADAVER, ya en el suelo: el encuadre que decide si el ragdoll
			# esta posado o si el cuerpo desaparece. Mira al PECHO (1,25): bajar
			# la mira antes del tiro mete la bala en el suelo y no hay cadaver.
			if enemy == null:
				p.global_position = Vector3(0.0, 0.05, 5.60)
				_aim(0.0, -0.03)
				return
			_colocar_frente_a(enemy, 3.4, 1.25)
		"enemy", "neck", "kill":
			# A 4,5 m del enemigo, de frente a la altura del cuello.
			if enemy == null:
				p.global_position = Vector3(0.0, 0.05, 5.60)
				_aim(0.0, -0.03)
				return
			_freeze(enemy)
			_colocar_frente_a(enemy, 4.5, 1.45)
		"enemy_fire":
			# ENEMIGO DISPARANDO: el jugador se planta a 6,5 m (dentro de ARRIVE,
			# 7 m) y el enemigo vive. Se le despierta con `hear` del propio
			# enemigo porque el gate FOV de IDLE no deja ver a quien lo mira:
			# despierto, gira, se planta, apunta y dispara a la captura.
			if enemy == null:
				p.global_position = Vector3(0.0, 0.05, 5.60)
				_aim(0.0, -0.03)
				return
			_colocar_frente_a(enemy, 6.5, 1.25)
			enemy.hear((p as Node3D).global_position)
		_:
			p.global_position = Vector3(0.0, 0.05, 5.60)
			_aim(0.0, -0.02)


## Deja al enemigo DE PIE y quieto para que el encuadre sea el mismo cada vez.
## Sin esto la captura persigue al enemigo: lo ve, se gira y camina, asi que
## colocarse a "3,2 m de donde estaba" encuadra el suelo. Se apaga solo su IA
## (`physics_process`); la cadena de muerte no lo necesita, asi que el tiro al
## cuello sigue siendo real.
func _freeze(enemy: Node3D) -> void:
	enemy.set_physics_process(false)
	if enemy is Enemy:
		(enemy as Enemy).velocity = Vector3.ZERO


## Coloca al jugador a `dist` m del poste del enemigo, DENTRO de la casa y con
## linea de vista libre al punto de altura `altura_mira` (pecho para look,
## cuello para kill/enemy/neck). Recorre 48 direcciones alrededor del poste y
## queda con la mas FRONTAL al facing del enemigo (se ve la cara, no la espalda).
## Sin sitio libre a esa distancia (recinto lleno), avisa y deja el spawn: meter
## al jugador dentro de un muro no es un encuadre, es un error silencioso.
func _colocar_frente_a(enemy: Node3D, dist: float, altura_mira: float) -> void:
	var ep := enemy.global_position
	var piso := 3.0 if ep.y > 1.5 else 0.0
	var py := piso + 0.05
	var space := enemy.get_world_3d().direct_space_state
	var chest := ep + Vector3(0.0, altura_mira, 0.0)
	# Los enemigos se EXCLUYEN de las dos consultas: el pecho es el punto objetivo
	# y cae dentro de la capsula del propio enemigo, asi que un rayo sin exclusion
	# lo golpea siempre y no queda ningun sitio valido. La oclusion que decide es
	# la de la casa (muros y mobiliario, capa 1).
	var cuerpos: Array[RID] = []
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is CollisionObject3D:
			cuerpos.append((e as CollisionObject3D).get_rid())
	var facing := -enemy.global_transform.basis.z
	facing.y = 0.0
	facing = facing.normalized() if facing.length() > 0.01 else Vector3(0.0, 0.0, -1.0)
	var mejor := Vector3.ZERO
	var mejor_score := -1e9
	for i in range(48):
		var ang := TAU * float(i) / 48.0
		var cand := ep + Vector3(cos(ang), 0.0, sin(ang)) * dist
		cand.y = py
		if not _sitio_libre(space, cand, piso, cuerpos):
			continue
		var eye := cand + Vector3(0.0, 1.55, 0.0)
		var ray := PhysicsRayQueryParameters3D.create(eye, chest, CAPA_MUNDO)
		ray.exclude = cuerpos
		if not space.intersect_ray(ray).is_empty():
			continue
		var score := facing.dot(Vector3(cand.x - ep.x, 0.0, cand.z - ep.z).normalized())
		if score > mejor_score:
			mejor_score = score
			mejor = cand
	if mejor_score <= -1e8:
		push_warning("SHOT: sin sitio libre a %.1f m del poste %s" % [dist, enemy.name])
		return
	(_player as Node3D).global_position = mejor
	var d := chest - (mejor + Vector3(0.0, 1.62, 0.0))
	_aim(atan2(-d.x, -d.z), asin(clampf(d.y / maxf(d.length(), 0.001), -1.0, 1.0)))
	print("SHOT encuadre: %s poste en %s -> jugador %s (dist %.2f m, piso %.2f)" % [
		enemy.name, ep, mejor, (mejor - ep).length(), piso])


## El jugador cabe en este punto: dentro de la planta del mapa (muros en
## x ±5,12 / z ±7,12 con margen) y sin muro en el volumen del torso. La esfera va a la
## altura del pecho con el suelo 5 cm por debajo: no toca el piso y si toca algo
## es porque ahi no se puede estar de pie. Solo capa 1 (mundo): enemigos y
## viewmodel nunca bloquean un encuadre.
func _sitio_libre(space: PhysicsDirectSpaceState3D, cand: Vector3, piso: float,
		excluir: Array[RID]) -> bool:
	if absf(cand.x) > 6.30 or absf(cand.z) > 8.30:
		return false
	var forma := SphereShape3D.new()
	forma.radius = 0.35
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = forma
	q.transform = Transform3D(Basis.IDENTITY, cand + Vector3(0.0, 0.35, 0.0))
	q.collision_mask = CAPA_MUNDO
	q.exclude = excluir
	return space.intersect_shape(q, 1).is_empty()


func _first_enemy() -> Node3D:
	var list := get_tree().get_nodes_in_group("enemy")
	if list.is_empty():
		return null
	# El mas cercano al jugador: el combat map los reparte y asi el encuadre no
	# depende del orden de creacion.
	var best: Node3D = list[0]
	var bd := 1e9
	for n in list:
		var d: float = (n as Node3D).global_position.distance_to((_player as Node3D).global_position)
		if d < bd:
			bd = d
			best = n as Node3D
	return best


func _aim(yaw: float, pitch: float) -> void:
	_player.set("yaw", yaw)
	_player.set("yaw_target", yaw)
	_player.set("pitch", pitch)
	_player.set("pitch_target", pitch)


func _process(delta: float) -> void:
	if action == "hero_normal":
		_process_hero_normal(delta)
		return
	if action == "hero_slow":
		_process_hero_slow(delta)
		return
	_frame += 1
	_game_ms += delta * 1000.0
	if _frame == warmup - 2:
		if advance > 0 and _weapon != null:
			for _i in range(advance):
				_weapon.call("_update_slide", 1.0 / 60.0)
		_trigger()
	if _frame >= warmup and _frame < warmup + total:
		if (_frame - warmup) % frame_stride == 0:
			var offset := _game_ms - (_action_ms if _action_ms >= 0.0 else _game_ms)
			_view.get_texture().get_image().save_png(
				"%s/f_%05dms.png" % [out_dir, int(round(offset))])
	elif _frame >= warmup + total:
		var shot_count := _shots
		print("SHOT action=%s frames=%d disparos=%d dir=%s" % [action, total, shot_count, out_dir])
		get_tree().quit()


func _process_hero_normal(delta: float) -> void:
	_hero_timer += delta
	match _hero_step:
		0:
			# 2.0s Vista general del frente / patio con ligero escaneo de cámara
			if _player != null:
				var t := _hero_timer
				if t < 0.8:
					_player.set("yaw_target", lerpf(0.0, -0.14, t / 0.8))
				elif t < 1.4:
					_player.set("yaw_target", lerpf(-0.14, 0.16, (t - 0.8) / 0.6))
				else:
					_player.set("yaw_target", lerpf(0.16, 0.0, (t - 1.4) / 0.6))
			if _hero_timer >= 2.0:
				if _player != null:
					_player.set("yaw_target", 0.0)
				_hero_step = 1
				_hero_timer = 0.0
		1:
			# Caminar por el frente / asfalto 2.0s hacia el porche (de z=12.20 a z=8.20)
			if _player != null:
				var fwd := Vector3(-sin(_player.get("yaw")), 0.0, -cos(_player.get("yaw")))
				_player.set("velocity", fwd * 2.0)
			if _hero_timer >= 2.0:
				if _player != null:
					_player.set("velocity", Vector3.ZERO)
				_hero_step = 2
				_hero_timer = 0.0
		2:
			# Pausa post-movimiento 0.5s
			if _hero_timer >= 0.5:
				_hero_step = 3
				_hero_timer = 0.0
				if _weapon != null:
					_weapon.set_aim(true)
		3:
			# ADS asentado 0.8s
			if _hero_timer >= 0.8:
				_hero_step = 4
				_hero_timer = 0.0
				if _weapon != null:
					_weapon.press_trigger()
		4:
			# ADS Tiro 1
			if _hero_timer >= 0.08 and _weapon != null:
				_weapon.release_trigger()
			if _hero_timer >= 0.5:
				_hero_step = 5
				_hero_timer = 0.0
				if _weapon != null:
					_weapon.press_trigger()
		5:
			# ADS Tiro 2
			if _hero_timer >= 0.08 and _weapon != null:
				_weapon.release_trigger()
			if _hero_timer >= 0.5:
				_hero_step = 6
				_hero_timer = 0.0
				if _weapon != null:
					_weapon.press_trigger()
		6:
			# ADS Tiro 3
			if _hero_timer >= 0.08 and _weapon != null:
				_weapon.release_trigger()
			if _hero_timer >= 0.6:
				_hero_step = 7
				_hero_timer = 0.0
				if _weapon != null:
					_weapon.set_aim(false)
		7:
			# Volver a Hip 0.6s
			if _hero_timer >= 0.6:
				_hero_step = 8
				_hero_timer = 0.0
		8:
			# Disparar continuo hasta ultimo cartucho y slide lock
			if _weapon == null:
				_hero_step = 9
				return
			var locked: bool = _weapon.get("slide_locked")
			var ch: int = _weapon.get("chamber")
			var mg: int = _weapon.get("mag")
			if locked or (ch <= 0 and mg <= 0):
				_weapon.release_trigger()
				_hero_step = 9
				_hero_timer = 0.0
			else:
				var cycle := fmod(_hero_timer, 0.16)
				if cycle < 0.08:
					_weapon.press_trigger()
				else:
					_weapon.release_trigger()
		9:
			# Slide lock visible e inequivoco: pausa 1.2s
			if _hero_timer >= 1.2:
				_hero_step = 10
				_hero_timer = 0.0
				if _weapon != null:
					_weapon.start_reload(15)
		10:
			# Esperar ReloadEmpty
			var reloading: bool = _weapon.get("reloading") if _weapon != null else false
			if not reloading and _hero_timer >= 2.4:
				_hero_step = 11
				_hero_timer = 0.0
		11:
			# Pausa en bateria 0.8s
			if _hero_timer >= 0.8:
				_hero_step = 12
				_hero_timer = 0.0
				if _weapon != null:
					_weapon.press_trigger()
		12:
			# Tiro post-recarga
			if _hero_timer >= 0.08 and _weapon != null:
				_weapon.release_trigger()
			if _hero_timer >= 0.6:
				_hero_step = 13
				_hero_timer = 0.0
				if _weapon != null:
					_weapon.inspect_weapon()
		13:
			# Inspect
			var inspecting: bool = _weapon.get("inspecting") if _weapon != null else false
			if not inspecting and _hero_timer >= 2.1:
				_hero_step = 14
				_hero_timer = 0.0
		14:
			# Pausa final 1.0s
			if _hero_timer >= 1.0:
				print("HERO_NORMAL finalizado con exito")
				get_tree().quit()


func _process_hero_slow(delta: float) -> void:
	_hero_timer += delta
	match _hero_step:
		0:
			# Warmup en hip (0.08s en game time = ~1s real)
			if _hero_timer >= 0.08:
				_hero_step = 1
				_hero_timer = 0.0
				if _weapon != null:
					_weapon.force_fire_once()
		1:
			# Esperar disparo normal (recoil, fogonazo, gas, corredera 39mm, cañon, casquillo)
			# 0.35s game time = ~4.4s real a 0.08x
			if _hero_timer >= 0.35:
				_hero_step = 2
				_hero_timer = 0.0
				if _weapon != null:
					_weapon.set("mag", 0)
					_weapon.set("chamber", 1)
					_weapon.set("slide_locked", false)
					_weapon.force_fire_once()
		2:
			# Segundo disparo en seco -> slide lock visible y bloqueo atras
			# 0.40s game time = ~5s real
			if _hero_timer >= 0.40:
				print("HERO_SLOW finalizado con exito")
				get_tree().quit()


func _trigger() -> void:
	if _weapon == null:
		return
	_action_ms = _game_ms
	match action:
		"fire", "ads_fire", "steel", "wood", "drywall", "wall", "aluminum", "can", "crate", "pen":
			if action.begins_with("ads"):
				_weapon.set_aim(true)
			_weapon.force_fire_once()
			_shots += 1
		"ads":
			_weapon.set_aim(true)
		"empty":
			# ULTIMO disparo: recamara llena y cargador a cero. La mecanica real
			# hace el resto (la corredera no vuelve a bateria porque no hay
			# cartucho que alimentar).
			_weapon.set("mag", 0)
			_weapon.set("chamber", 1)
			_weapon.set("slide_locked", false)
			_weapon.set("slide_pos", 0.0)
			_weapon.set("slide_vel", 0.0)
			_weapon.force_fire_once()
			_shots += 1
		"reload":
			_weapon.set("mag", 10)
			_weapon.start_reload(15)
		"reload_empty":
			_weapon.set("mag", 0)
			_weapon.set("chamber", 0)
			_weapon.set("slide_locked", true)
			_weapon.set("slide_pos", 0.039)
			_weapon.start_reload(15)
		"inspect":
			_weapon.inspect_weapon()
		"corpse":
			# Un tiro al pecho y a mirar donde cae.
			_weapon.force_fire_once()
			_shots += 1
		"enemy", "neck", "kill":
			# Un tiro al cuello. El enemigo decide donde le ha dado (comparando el
			# punto contra los huesos), asi que aqui no se dice "cuello": se apunta y
			# se dispara, y lo que salga en la captura es lo que hay.
			_weapon.force_fire_once()
			_shots += 1
		"table":
			_player.call("try_reload_from_table")
		"hall":
			pass
		"enemy_fire":
			# El arma del jugador no interviene: dispara el enemigo, solo.
			pass
		_:
			pass
