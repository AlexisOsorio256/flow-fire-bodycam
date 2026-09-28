class_name Enemy
extends CharacterBody3D

## ENEMIGO UNICO. Sin clases, sin arbol de comportamiento, sin framework.
##
## Lo unico que hace es lo minimo para que se pueda jugar contra el:
## PERCIBE (vista o disparo), se ORIENTA, se MUEVE, busca LINEA DE TIRO y
## DISPARA. Cuatro estados en un `match`; no hay mas maquina.
##
## UN IMPACTO VALIDO MATA. No hay vida, ni barra, ni esponja, ni multiplicador.
## El punto del combate es la tension del bodycam, no el DPS.
##
## LA LOCALIZACION DEL IMPACTO NO DECIDE SI MUERE (siempre muere): decide COMO
## CAE. Tres zonas, tres fisicas medibles en el ragdoll:
##
##   PIE   (pantorrilla/empeine): no hay derribo instantaneo. El pie golpeado
##         pierde su muelle -- se le da un empujon lateral pequeno y una
##         ventana de cojera de 0,9 s antes de que la fisica tome el cuerpo.  [^]
##   PECHO (tronco): retroceso. El impulso real de la bala entra en el hueso mas
##         cercano con el brazo de palanca del punto de impacto: el torso gira
##         hacia atras y el cuerpo se desploma encima de las piernas.
##   CABEZA: muerte instantanea. El cuello recibe el impulso, la cabeza cae
##         primero y el resto del cuerpo la sigue. Cero reaccion animada: la
##         fisica habla desde el primer frame.
##
## SIN NavigationAgent3D. El bunker son recintos pequenos: ir de frente y dejar
## que Jolt deslice (move_and_slide) basta, y un navmesh son otro horneado que
## mantener para un mapa que no lo necesita.
##
## SIN HITMARKER Y SIN HUD DE DANO. El jugador no sabe si ha dado hasta que el
## cuerpo cae. Es una decision de diseno, no un olvido: el audio del impacto y
## la sangre visible son todo el feedback, y este archivo no imprime nada por
## impacto.

const ASSET := "res://assets/models/enemy.glb"
const CLIP_IDLE := "Idle"
const CLIP_WALK := "Walk"
const CLIP_NECK := "Neck"

# --- Percepcion -----------------------------------------------------------
const SIGHT := 22.0
const FOV_COS := -0.25          # semivista ~104 grados: periferia real, no 360
const HEAR := 26.0              ## un disparo cercano le avisa aunque no vea
const EYE_HEIGHT := 1.60
const PLAYER_AIM := Vector3(0.0, 1.25, 0.0)   ## punto que apunta al tirador

# --- Movimiento -----------------------------------------------------------
const WALK_SPEED := 1.9
const TURN_RATE := 5.0          ## rad/s de giro: no es instantáneo, se le ve venir
const ARRIVE := 7.0             ## a esta distancia se para y afina la puntería

# --- Disparo --------------------------------------------------------------
## Ráfaga de 3 con 0,28 s entre tiros: una Glock de servicio, no una ametralladora.
const BURST := 3
const SHOT_GAP := 0.28
const FIRST_SHOT := 0.35        ## reacción antes del primer tiro
const SHOT_SPREAD := 0.006      ## 1σ en radianes: mano tensa, no pulso de francotirador
const MUZZLE_SPEED := 340.0
const MUZZLE_HEIGHT := 1.42

# --- Muerte ---------------------------------------------------------------
## Segundos que dura la reaccion visible ANTES de que la fisica tome el control.
## Solo la usa la zona PIE: las otras dos sueltan el ragdoll en el mismo frame
## (cabeza) o tras un golpe de tronco de 0,12 s (pecho).
const FALL_REACTION := 0.90
## TAMBALEO DE PIERNA (dueno: "dispara en la pierna se cae y se tambalea").
## Un tiro en la pantorrilla NO derriba: el hombre pierde el pie, se va de lado
## y aguanta 0,90 s antes de que la fisica tome el cuerpo. Lo que habia era un
## empujon lateral en el momento del ragdoll, o sea el cuerpo ya en el suelo:
## el tambaleo no se veia porque no existia.
## Ahora el que tropieza se INCLINA hacia el lado de la pierna golpeada, AVANZA
## de lado con `move_and_slide` (choca con lo que haya en vez de atravesarlo) y
## FRENA. A los 0,90 s el ragdoll recoge el cuerpo YA INCLINADO, que es lo que
## hace que la caida se lea como consecuencia del tropiezo.
const STAGGER_SPEED := 1.70     ## m/s de deriva lateral al perder el pie
const STAGGER_TILT := 0.40      ## rad de alabeo en el momento de la caida
const STAGGER_PITCH := 0.17     ## rad de vencimiento del tronco hacia delante
const PUSH_REACTION := 0.12
## Peso del cuerpo: 78 kg. Se reparte por hueso en `_bone_share`.
const BODY_MASS := 78.0
## MEDIDO EN CAPTURA `kill` (jugador a 4,5 m): con 14 gotas de 2,2 cm y 0,55 s de
## vida no se veia NI UNA. La sangre es el unico feedback que hay (no hay
## hitmarker), asi que si no se lee a distancia de juego no existe. Veinte gotas
## de 5 cm y 0,9 s de vida se leen a 4,5 m sin cambiar el coste de forma (sigue
## es UN GPUParticles3D one-shot por enemigo, no un sistema). PASADA 'MAS
## SANGRE': 28 gotas (el charco ahora CREE 1.1 s, ver ImpactFX) y el chorro se
## lee a 6 m; el coste sigue en forma + 3 ms de burst one-shot.
const BLOOD_AMOUNT := 28
const BLOOD_LIFE := 0.90

enum { IDLE, ALERT, ENGAGE }

## Zona leida desde el hueso mas cercano al impacto. Lista corta y FIJA: no es
## un sistema de zonas, son los huesos que se leen desde fuera.
const HEAD_BONES := ["Head", "Neck"]
const LEG_BONES := ["Shin_L", "Shin_R", "Foot_L", "Foot_R", "Thigh_L", "Thigh_R"]
const TORSO_BONES := ["Chest", "Chest.001", "Spine", "Hips"]

var state := IDLE
var visual: Node3D
var skeleton: Skeleton3D
var anim: AnimationPlayer
var ragdoll: PhysicalBoneSimulator3D
var _player: Node3D
var _shot_timer := 0.0
var _burst_left := 0
var _dead := false
var _hit_leg := ""
var _staggering := false
var _stagger_t := 0.0
var _stagger_dir := Vector3.ZERO
var _stagger_roll := 0.0
var _wound := Vector3.ZERO
var _material: StandardMaterial3D
var _blood_mat: StandardMaterial3D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	_build_body()
	_build_visual()
	_player = get_tree().get_first_node_in_group("player")


func _build_body() -> void:
	# UNA capsula para el cuerpo entero. La localizacion del impacto NO sale de
	# ella: sale de comparar el punto local contra los huesos del esqueleto, que
	# es donde esta la verdad de donde te han dado.
	var shape := CapsuleShape3D.new()
	shape.radius = 0.26
	shape.height = 1.78
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0, 0.89, 0)
	add_child(col)
	# El enemigo pertenece al grupo que Ballistics busca ANTES de la tabla de
	# materiales: la carne no esta en `Ballistics.MATERIALS` y no debe estar.
	add_to_group("enemy")


func _build_visual() -> void:
	if not ResourceLoader.exists(ASSET):
		# Dependencia declarada, no un fallo de arranque: el juego sigue y el
		# mapa se puebla sin enemigos hasta que haya cuerpo.
		print("ENEMY: sin asset (%s); el combate sale sin enemigos" % ASSET)
		set_physics_process(false)
		queue_free()
		return
	var packed := load(ASSET) as PackedScene
	visual = packed.instantiate() as Node3D
	visual.name = "Visual"
	add_child(visual)
	skeleton = _find(visual, "Skeleton3D") as Skeleton3D
	anim = _find(visual, "AnimationPlayer") as AnimationPlayer
	if skeleton == null or anim == null:
		push_error("Enemy: el asset no trae Skeleton3D + AnimationPlayer")
		queue_free()
		return
	for name in [CLIP_IDLE, CLIP_WALK, CLIP_NECK]:
		if _clip(name) == "":
			push_error("Enemy: falta el clip " + name)
			queue_free()
			return
	for name in [CLIP_IDLE, CLIP_WALK]:
		var a := anim.get_animation(_clip(name))
		if a != null:
			a.loop_mode = Animation.LOOP_LINEAR
	# El clip Neck de la fuente es de un fotograma: se reproduce SIN bucle y a
	# velocidad nominal porque `_die` lo corta a los 0,12 s (PUSH_REACTION). El
	# tropiezo de la pierna dura 0,90 s pero con Idle, no con Neck.
	var neck := anim.get_animation(_clip(CLIP_NECK))
	if neck != null:
		neck.loop_mode = Animation.LOOP_NONE
	_normalize_rig()
	_build_material()
	# La sangre se dibuja una vez y se reutiliza: un burst corto y un charco.
	_blood_nodes()
	anim.play(_clip(CLIP_IDLE))
	print("ENEMIGO montado: trims=%d huesos=%d clips=%s alto=%.2f m"
		% [_tris(), skeleton.get_bone_count(), anim.get_animation_list(), _rig_height()])


## EL RIG VIENE A ESCALA DEL DONANTE, NO A LA DEL JUEGO. Medido con
## `check_enemy` sobre el asset actual: hueso `Head` a 4,41 m y `Foot_L` a 0,20
## para una persona que debe medir 1,78, o sea un cuerpo 2,4x mas alto.
##
## Lo que se veia en la captura `kill` (a 4,5 m, banda visible -0,33..3,57 m)
## era SOLO piernas y cadera, y los dos blobs sueltos a los lados eran las
## MANOS (Hand_L a 2,49 m): el torso y la cabeza quedaban por encima del
## encuadre. No era el shader (apagandolo el torso aparecia entero en su sitio),
## ni el skinning (la malla sigue a los huesos), ni sobreexposicion: era el
## tamano. Se normaliza el VISUAL con la verdad del propio rig -- alto real
## Head-Foot -- y se apoyan los pies en el suelo del enemigo.
##
## Se escala el nodo `visual` entero, asi que huesos y malla viajan juntos y el
## ragdoll, `_region_at` y `_nearest_bone` (que leen `skeleton.to_global`)
## siguen correctos sin tocar nada mas. La capsula de 1,78 del cuerpo ya era la
## buena: ahora el mesh coincide con ella.
const BODY_HEIGHT := 1.78


func _normalize_rig() -> void:
	var alto := _rig_height()
	if alto < 0.5:
		return
	var k := BODY_HEIGHT / alto
	visual.scale = Vector3(k, k, k)
	visual.position.y = -_bone_world_y("Foot_L") * k


## Alto real del rig: de la cabeza al pie, leido de la pose de hueso.
func _rig_height() -> float:
	return _bone_world_y("Head") - _bone_world_y("Foot_L")


func _bone_world_y(name: String) -> float:
	for i in skeleton.get_bone_count():
		if skeleton.get_bone_name(i) == name:
			return skeleton.to_global(skeleton.get_bone_global_pose(i).origin).y
	return 0.0


## MATERIAL: tela CC0 real (Fabric019, ambientCG) sobre los dos slots que trae
## el GLB. El equipo y el uniforme van en el MISMO material base y el slot 1
## (equipo) baja el albedo: el contraste interno da la silueta militar sin
## pagar una tercera textura. `surface_set_material` sobrescribe cada slot sin
## tocar el otro.
const TEX_FABRIC := "res://assets/textures/enemy/fabric_%s.jpg"


func _tex(path: String) -> Texture2D:
	return load(path) as Texture2D


func _pbr(albedo: String, normal: String, rough: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex(albedo)
	# La cocina es yeso crema + luz fuerte: sin atenuar el albedo la piel clara
	# y la tela queman a blanco plano (captura kill: enemigo 240+ en todo el
	# cuerpo). 0,50/0,45/0,40 deja la textura leible sin quemarla.
	m.albedo_color = Color(0.50, 0.45, 0.40)
	m.normal_enabled = true
	m.normal_texture = _tex(normal)
	m.roughness_texture = _tex(rough)
	m.roughness = 1.0
	return m


func _build_material() -> void:
	# UNIFORME OSCURO EN TODO EL CUERPO (ref3: gris/verde, nada de piel al
	# aire -- el donante Quaternius es cuerpo desnudo y la piel naranja se leia
	# como carne colgando). Slot 0 = tela gris/verde medio, slot 1 = tela mas
	# oscura para el equipo; el contraste interno da la silueta militar.
	_material = _pbr(TEX_FABRIC % "color", TEX_FABRIC % "normal", TEX_FABRIC % "rough")
	_material.albedo_color = Color(0.30, 0.30, 0.26)
	var fabric := _pbr(TEX_FABRIC % "color", TEX_FABRIC % "normal", TEX_FABRIC % "rough")
	fabric.albedo_color = Color(0.20, 0.20, 0.18)
	for node in visual.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		mi.mesh.surface_set_material(0, _material)
		mi.mesh.surface_set_material(1, fabric)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


## RAGDOLL. `PhysicalBoneSimulator3D` es el solver del motor y no se reescribe,
## pero sus `PhysicalBone3D` NO se crean solos fuera del editor: el importador de
## glTF no los produce y el plugin del editor es el que los soltaba al guardar la
## escena. En runtime hay que construirlos, y es lo unico que hay que construir.
##
## SE CONSTRUYEN AL MORIR, no al montar, y por dos razones que medi: un enemigo vivo
## se le caia entre los pies al aparecer en el mapa (`simulate_physics` ya no es
## asignable en 4.7 y `physical_bones_stop_simulation()` no frena un hueso que
## nunca se detuvo), y 48 cuerpos rigidos por enemigo son 192 cuerpos en un mapa
## con cuatro. Un cadaver los crea; un enemigo que anda, no los tiene.
##
## La masa se reparte por hueso y no por igual: un craneo y una tibia pesan lo
## mismo, y un torso de 48 huesos de 1,6 kg cada uno cae como un bloque de plomo.
## El total es 78 kg, que es lo que pesa una persona.
func _build_ragdoll() -> void:
	ragdoll = PhysicalBoneSimulator3D.new()
	ragdoll.name = "Ragdoll"
	skeleton.add_child(ragdoll)
	var count := skeleton.get_bone_count()
	# Longitudes de reposo por hueso: hasta sus hijos directos; un hueso sin
	# hijos (dedos, pies) mide lo que lo separa de su padre. Con eso sale la
	# esfera de cada cuerpo: el grueso de un miembro, no su longitud.
	var rest := {}
	var kids_len := {}
	var kids_n := {}
	for i in count:
		rest[i] = skeleton.get_bone_rest(i).origin
	for i in count:
		var p := skeleton.get_bone_parent(i)
		if p >= 0:
			kids_len[p] = float(kids_len.get(p, 0.0)) \
				+ skeleton.get_bone_rest(i).origin.distance_to(rest[p])
			kids_n[p] = int(kids_n.get(p, 0)) + 1
	for i in count:
		var bone_name := skeleton.get_bone_name(i)
		var pb := PhysicalBone3D.new()
		pb.name = "PB_" + bone_name
		pb.bone_name = bone_name
		pb.mass = BODY_MASS * _bone_share(bone_name)
		# SIN FORMA NO HAY CADAVAR: medido con `check_enemy`, un PhysicalBone3D
		# sin colision se cae AL VACIO a traves del suelo (cadera a -31 m en
		# 2 s) y en partida el cuerpo desaparece y solo queda la sangre
		# flotando -- el fallo que se vio en `captures/shot/kill`. Una esfera
		# por hueso, barata y suficiente: nadie mira la seccion transversal de
		# un cadaver, y 48 esferas no son un sistema de colision, son el minimo.
		var len := 0.06
		if int(kids_n.get(i, 0)) > 0:
			len = float(kids_len[i]) / int(kids_n[i])
		elif skeleton.get_bone_parent(i) >= 0:
			len = rest[i].distance_to(rest[skeleton.get_bone_parent(i)])
		var col := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = clampf(len * 0.18, 0.02, 0.07)
		col.shape = sph
		pb.add_child(col)
		# Capa 4 (cadaveres) con mask 1 (el mundo): los huesos se posan en el
		# suelo y contra los muebles, PERO no se tocan entre si -- un contacto
		# hermano-padre en la propia articulacion revienta el solver. Y el
		# mundo no ve la capa 4: un cadaver no bloquea balas ni piernas.
		pb.collision_layer = 4
		pb.collision_mask = 1
		# El hueso RAIZ no tiene padre: sin union se caeria solo. El resto se une al
		# padre con una articulation cono-torsion, que es la que deja que el cuello
		# se doble y el hombro gire sin que el cuerpo se desmonte.
		if i > 0:
			pb.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
		ragdoll.add_child(pb)
	# Se arranca YA, porque `_ragdoll` solo llama a este cuando el cuerpo ya esta
	# doblado y quieto: la reaccion animada happened antes.
	ragdoll.physical_bones_start_simulation()


## Reparto de masa, en fraccion del cuerpo. Tronco y cabeza llevan la parte
## grande; manos y pies, una fraccion. Los valores estan normalizados a 1.
## Los dedos de la fuente (48 huesos) caen en la rama por defecto: son 0,01 cada
## uno y el total sigue siendo 1.
func _bone_share(bone_name: String) -> float:
	if bone_name == "Hips":
		return 0.20
	if bone_name in ["Spine", "Chest", "Chest.001"]:
		return 0.20
	if bone_name == "Neck":
		return 0.02
	if bone_name == "Head":
		return 0.08
	if bone_name.begins_with("Shoulder") or bone_name.begins_with("UpperArm"):
		return 0.05
	if bone_name.begins_with("ForeArm"):
		return 0.03
	if bone_name.begins_with("Hand"):
		return 0.01
	if bone_name.begins_with("Thigh"):
		return 0.10
	if bone_name.begins_with("Shin"):
		return 0.05
	return 0.01


func _blood_nodes() -> void:
	# Un solo sistema y un solo material para toda la sangre del juego. Sin
	# simulacion de fluidos, sin cientos de particulas, sin charco que crece.
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 55.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 2.6
	pm.gravity = Vector3(0, -9.0, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.5
	pm.color = Color(0.34, 0.02, 0.015, 1.0)
	pm.damping_min = 0.6
	pm.damping_max = 1.6
	_blood_mat = StandardMaterial3D.new()
	_blood_mat.albedo_color = Color(0.34, 0.02, 0.015, 1.0)
	_blood_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_blood_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_blood_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_blood_mat.vertex_color_use_as_albedo = true
	_blood_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# La sangre SE MUEVE con el cuerpo: el sistema es hijo del nodo, asi que al
	# morir el chorro sale del punto de impacto y se queda con el cadaver que cae.
	_blood = GPUParticles3D.new()
	_blood.name = "Blood"
	_blood.amount = BLOOD_AMOUNT
	_blood.lifetime = BLOOD_LIFE
	_blood.one_shot = true
	_blood.explosiveness = 1.0
	_blood.local_coords = false
	_blood.process_material = pm
	_blood.draw_pass_1 = _blood_quad()
	_blood.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_blood.emitting = false
	add_child(_blood)

	# El charco: UN decal del mismo tipo que usa ImpactFX para los agujeros, con
	# una silueta propia de mancha. Se queda en el suelo y no se borra: un rastro
	# de por donde has pasado es informacion, no basura.
	_blood_spot = Decal.new()
	_blood_spot.texture_albedo = _blood_texture()
	_blood_spot.size = Vector3(0.55, 0.05, 0.55)
	_blood_spot.upper_fade = 0.0
	_blood_spot.lower_fade = 0.5
	_blood_spot.modulate = Color(1, 1, 1, 0.0)
	_blood_spot.visible = false
	add_child(_blood_spot)


var _blood: GPUParticles3D
var _blood_spot: Decal


func _blood_quad() -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	quad.material = _blood_mat
	return quad


func _blood_texture() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in range(32):
		for x in range(32):
			var u := (float(x) + 0.5) / 32.0 * 2.0 - 1.0
			var v := (float(y) + 0.5) / 32.0 * 2.0 - 1.0
			# Mancha irregular: el angulo rompe el borde, como en los agujeros.
			var ang := atan2(v, u)
			var n := 0.5 + 0.5 * sin(ang * 5.0 + sin(ang * 3.0) * 2.0)
			var r := sqrt(u * u + v * v) * (1.0 + 0.22 * (n - 0.5))
			img.set_pixel(x, y, Color(0.30, 0.015, 0.01, 0.85 * smoothstep(0.95, 0.25, r)))
	return ImageTexture.create_from_image(img)


func _find(root: Node, cls: String) -> Node:
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.is_class(cls):
			return n
		for c in n.get_children():
			stack.append(c)
	return null


func _clip(name: String) -> String:
	for c in anim.get_animation_list():
		var s := String(c)
		if s == name or s.ends_with("/" + name) or s.ends_with("|" + name) or s.ends_with("_" + name):
			return s
	return ""


## TRIANGULOS DE VERDAD. La version anterior sumaba `vertices / 3`, que en una
## malla INDEXADA no son triangulos: el cuerpo de 16.419 tris se imprimia como
## 3.879 y el numero mentia en el unico sitio donde se lee. Se cuentan los
## indices, que es lo que dibuja la GPU.
func _tris() -> int:
	var total := 0
	for node in visual.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(s)
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if idx.is_empty():
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				total += verts.size() / 3
			else:
				total += idx.size() / 3
	return total


# ---------------------------------------------------------------------------
# Percepcion. Cuatro preguntas, sin mas.
# ---------------------------------------------------------------------------
func _see_player() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	var eye := global_position + Vector3(0, EYE_HEIGHT, 0)
	var target: Vector3 = _player.global_position + PLAYER_AIM
	var to := target - eye
	var dist := to.length()
	if dist > SIGHT:
		return false
	if state == IDLE and _player_forward().dot(to.normalized()) < FOV_COS:
		return false
	var q := PhysicsRayQueryParameters3D.create(eye, target, 1)
	q.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _player_forward() -> Vector3:
	if _player == null:
		return Vector3.FORWARD
	var yaw: float = _player.get("yaw")
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


## Un disparo cerca le avisa. Es la unica forma de que reaccione a algo que no
## sea ver al jugador, y es lo que hace que disparar revele tu posicion.
func hear(noise_at: Vector3) -> void:
	if _dead or state != IDLE:
		return
	if global_position.distance_to(noise_at) <= HEAR:
		state = ALERT
		_shot_timer = FIRST_SHOT


# ---------------------------------------------------------------------------
# Bucle. Tres estados, un `match`.
# ---------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if _staggering:
		_stagger(delta)
		return
	if _dead:
		return
	# El jugador NO existe cuando el mapa se puebla: `Main` construye el mapa (y
	# `CombatMap` mete los enemigos) ANTES de `_enter`, que es quien anade al
	# `Player`. Resolverlo una sola vez en `_ready` dejaba `_player` nulo para
	# siempre y el enemigo muerto en IDLE. Se re-resuelve SOLO mientras falte
	# (por evento, no cada frame ya resuelto): un `get_first_node_in_group` es
	# barato y evita el arbol de referencias cruzadas que habria que mantener.
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if not is_instance_valid(_player):
			velocity = Vector3.ZERO
			return
	if state == IDLE and not _see_player():
		velocity = Vector3.ZERO
		_mix_walk(delta, 0.0)
		return
	if state == IDLE:
		state = ALERT
		_shot_timer = FIRST_SHOT
	var aim := _player.global_position + PLAYER_AIM - (global_position + Vector3(0, MUZZLE_HEIGHT, 0))
	var flat := Vector3(aim.x, 0.0, aim.z)
	var want := 0.0
	if state == ALERT:
		want = atan2(-flat.x, -flat.z)
		_turn(want, delta)
		velocity = Vector3.ZERO
		if absf(angle_difference(_yaw(), want)) < 0.35:
			state = ENGAGE
	else:
		want = atan2(-flat.x, -flat.z)
		_turn(want, delta)
		# Se acerca hasta poner distancia de tiro y entonces se planta: eso es
		# pelear, no correr en circulos. A menos de 2,5 m retrocede, que es lo
		# que hace un hombre cuando le ha entrado una bala en el cuello.
		var dist := flat.length()
		var dir := flat.normalized()
		if dist > ARRIVE:
			velocity = dir * WALK_SPEED
		elif dist < 2.5:
			velocity = -dir * WALK_SPEED
		else:
			velocity = Vector3.ZERO
		_shoot(delta)
	move_and_slide()
	_mix_walk(delta, velocity.length() / WALK_SPEED)


## EL TAMBALEO, cuadro a cuadro. Tres cosas a la vez y las tres se miden:
##   1. el pie golpeado deja de sostener -> el tronco se ALABEA hacia ese lado y
##      se vence hacia delante (rotacion del nodo `visual`, no de la capsula: una
##      capsula girada dejaria de representar al cuerpo);
##   2. el cuerpo AVANZA de lado con `move_and_slide`, asi que tropieza con lo
##      que haya -- un marco de puerta, un mueble -- en vez de atravesarlo;
##   3. la deriva DECAE: el que tropieza frena, no acelera.
## El alabeo va sobre `visual` y por eso el ragdoll lo hereda: los
## `PhysicalBone3D` se crean leyendo la pose actual del esqueleto.
func _stagger(delta: float) -> void:
	_stagger_t = minf(1.0, _stagger_t + delta / FALL_REACTION)
	var e := _stagger_t * _stagger_t          # frena: e=1 al final del tropiezo
	var push := STAGGER_SPEED * (1.0 - e)
	velocity.x = _stagger_dir.x * push
	velocity.z = _stagger_dir.z * push
	velocity.y = -0.5 if is_on_floor() else velocity.y - 9.8 * delta
	move_and_slide()
	visual.rotation.z = _stagger_roll * e
	visual.rotation.x = -STAGGER_PITCH * e
	visual.position.x = _stagger_dir.x * 0.12 * e
	## La zancada se queda a un tercio: son pasos cortos de alguien que no
	## controla la pierna, no una caminata.
	_mix_walk(delta, 0.34 * (1.0 - e))


func _yaw() -> float:
	return atan2(-global_basis.z.x, -global_basis.z.z)


func _turn(want: float, delta: float) -> void:
	var y := _yaw()
	var step := clampf(angle_difference(y, want), -TURN_RATE * delta, TURN_RATE * delta)
	rotate_y(step)


## Parado o caminando. El cruce lo hace el propio `AnimationPlayer` con su
## `custom_blend`; no hace falta un AnimationTree ni mezclar pesos a mano.
func _mix_walk(_delta: float, want: float) -> void:
	var target := _clip(CLIP_WALK) if want > 0.5 else _clip(CLIP_IDLE)
	if anim.current_animation == target:
		return
	if anim.current_animation == _clip(CLIP_NECK):
		return
	anim.play(target, 0.20)


func _shoot(delta: float) -> void:
	_shot_timer -= delta
	if _shot_timer > 0.0:
		return
	if _burst_left <= 0:
		_burst_left = BURST
		_shot_timer = SHOT_GAP
		_burst_left -= 1
		return
	_burst_left -= 1
	_shot_timer = SHOT_GAP
	if not _see_player():
		_burst_left = 0
		return
	## La boca va 45 cm por delante del pecho, FUERA de la propia capsula (radio
	## 0,26). Dentro, la bala impacta contra el propio cuerpo desde dentro y el
	## rebote sale con una normal invalida.
	var from := global_position + Vector3(0, MUZZLE_HEIGHT, 0) - global_basis.z * 0.45
	var to := _player.global_position + PLAYER_AIM
	# El mismo patron de dispersion mecanica que usa el arma del jugador: no
	# punteria perfecta, sino una mano que sostiene mal el temblor.
	var aim := (to - from).normalized()
	var side := aim.cross(Vector3.UP).normalized()
	var up := side.cross(aim).normalized()
	var dir := (aim
		+ side * randfn(0.0, SHOT_SPREAD) + up * randfn(0.0, SHOT_SPREAD)).normalized()
	Ballistics.fire(from, dir, MUZZLE_SPEED)
	GameAudio.play_3d("footstep", global_position, -8.0, 2.4)


# ---------------------------------------------------------------------------
# Impacto y muerte. Aqui es donde la localizacion se convierte en presentacion.
# ---------------------------------------------------------------------------
## Lo llama `Ballistics` cuando una bala entra en este cuerpo. `impulse` es el
## delta-p real de la bala: el ragdoll recibe el impacto de verdad, no un empujon
## inventado.
func hit(point: Vector3, dir: Vector3, impulse: float) -> void:
	if _dead:
		return
	var local := point - global_position
	var region := _region_at(local)
	_blood_at(point, dir)
	_die(region, local, dir, impulse)


## Que parte del cuerpo te han dado. No es un mapa de zonas: es el hueso del
## esqueleto mas cercano al impacto, que es la misma verdad que mueve la malla.
## La lista de huesos que se miran es CORTA y fija: no hay puntuacion por area.
func _region_at(local: Vector3) -> String:
	var best := ""
	var best_d := INF
	var best_group := "body"
	# La pose de hueso se lee en el MISMO marco que `local` (el del enemigo). El
	# esqueleto del glTF trae la malla a escala 0,01 dentro del rig, asi que
	# `get_bone_global_pose().origin` NO sirve tal cual: se pasa por
	# `to_global` y se compara contra el punto de impacto ya en mundo, que es lo
	# unico que no mezcla dos escalas.
	var world := global_transform * local
	for i in skeleton.get_bone_count():
		var name := skeleton.get_bone_name(i)
		var group := _group_of(name)
		if group == "":
			continue
		var bone_world := skeleton.to_global(skeleton.get_bone_global_pose(i).origin)
		var d := bone_world.distance_to(world)
		if d < best_d:
			best_d = d
			best = name
			best_group = group
	# 18 cm de margen: por debajo, el punto mas bajo que se puede tocar en el
	# cuello sigue siendo cuello, que es como lo lee el ojo en una captura.
	return best_group if best_d < 0.18 else "body"


func _group_of(bone_name: String) -> String:
	if HEAD_BONES.has(bone_name):
		return "head"
	if LEG_BONES.has(bone_name):
		return "leg"
	if TORSO_BONES.has(bone_name):
		return "torso"
	return ""


func _die(region: String, local: Vector3, dir: Vector3, impulse: float) -> void:
	_dead = true
	set_physics_process(false)
	velocity = Vector3.ZERO
	# UN IMPACTO VALIDO MATA. No hay vida, ni escotilla, ni segundo golpe.
	# El chorro grande sale SIEMPRE: la sangre es el unico feedback que hay.
	_blood_at_burst(dir, impulse)
	match region:
		"head":
			# MUERTE INSTANTANEA. La cabeza recibe el impulso de la bala y el
			# cuello la sigue: cero reaccion animada, la fisica habla ya.
			_ragdoll(dir, impulse, local, "Head")
		"leg":
			# TROPIEZO. Un tiro en la pantorrilla no derriba: el hombre pierde el
			# pie, la rodilla cede y el cuerpo cae hacia ese lado. El empujon al
			# hueso golpeado es PEQUENO -- no el de la bala, que a 9 mm es un
			# alfilerazo -- y el que manda es el tambaleo de los 0,90 s.
			_hit_leg = _nearest_bone(local, LEG_BONES)
			## El lado por el que se cae es el de la pierna golpeada: si le dan
			## en la izquierda, la izquierda deja de sostener.
			var side := 1.0 if _hit_leg.ends_with("_L") else -1.0
			_stagger_dir = (global_transform.basis
				* Vector3(side, 0.0, -0.55)).normalized()
			_stagger_roll = -side * STAGGER_TILT
			_stagger_t = 0.0
			_staggering = true
			## La capsula SIGUE respondiendo: el tambaleo se mueve por el mundo.
			set_physics_process(true)
			_anim_play(_clip(CLIP_IDLE))
			var t := get_tree().create_timer(FALL_REACTION)
			t.timeout.connect(_to_ragdoll.bind(dir, impulse, local, ""))
		"torso":
			# RETROCESO y COLAPSO. El pecho se va hacia atras con el momento real
			# de la bala y las piernas no le siguen: el cuerpo se dobla por la
			# cintura y cae encima de si mismo.
			_anim_play(_clip(CLIP_NECK))
			var t := get_tree().create_timer(PUSH_REACTION)
			t.timeout.connect(_to_ragdoll.bind(dir, impulse, local, "Chest"))
		_:
			# Sin zona: caida generica, el impulso al hueso mas cercano.
			_ragdoll(dir, impulse, local, "")


func _to_ragdoll(dir: Vector3, impulse: float, local: Vector3, bone: String) -> void:
	if not is_instance_valid(self):
		return
	_ragdoll(dir, impulse, local, bone)


func _ragdoll(dir: Vector3, impulse: float, local: Vector3, bone: String) -> void:
	collision_layer = 0
	collision_mask = 0
	_build_ragdoll()
	_anchor_blood()
	_push(dir, impulse, local, bone)
	if _hit_leg != "":
		_push_leg(dir)


func _anim_play(clip: String) -> void:
	if clip == "":
		return
	if anim.current_animation == clip:
		return
	anim.play(clip)


func _nearest_bone(local: Vector3, names: Array) -> String:
	var best := ""
	var best_d := INF
	var world := global_transform * local
	for i in skeleton.get_bone_count():
		var name := skeleton.get_bone_name(i)
		if not names.has(name):
			continue
		var bone_world := skeleton.to_global(skeleton.get_bone_global_pose(i).origin)
		var d := bone_world.distance_to(world)
		if d < best_d:
			best_d = d
			best = name
	return best


## El impulso de la bala a los DOS huesos mas cercanos al impacto, con el MISMO
## momento lineal que el resto del mundo (ver `Ballistics._push_body`): lo que la
## bala pierde se lo lleva el cuerpo, sin factores inventados.
##
## DOS huesos y no uno: un proyectil de 9 mm que entrega los 2,77 N.s enteros a
## un solo hueso hace que solo se mueva el cuello y el torso se quede deformado
## en el aire. Repartido entre los dos mas cercanos, el impulso de la bala TIENE
## que entrar en el esqueleto, porque son huesos rigidbody: el cuerpo no tiene
## `apply_central_impulse` (eso es de `RigidBody3D`) y no se inventa un empujon
## de mas, se reparte el que hay entre los huesos que lo pueden recibir.
##
## `bone` es la zona que manda: en cabeza y pecho el primer hueso es el nombrado
## (Head / Chest) y no el mas cercano, porque ahi la direccion de la caida es la
## decision de diseno, no el azar de una distancia.
func _push(dir: Vector3, impulse: float, local: Vector3, bone: String) -> void:
	if impulse <= 0.0 and bone == "":
		return
	# `local` nacio como `point - global_position` en `hit`: el marco que lo
	# devuelve a mundo es el del ENEMIGO, no el del `skeleton`, cuyo origen
	# `_normalize_rig` desplaza en Y para apoyar los pies. Sumar al hueso y
	# torcer con el brazo de palanca del punto REAL del impacto.
	var at := global_position + local
	var ranked: Array = []
	for node in ragdoll.find_children("*", "PhysicalBone3D", true, false):
		var pb := node as PhysicalBone3D
		ranked.append([pb.global_position.distance_to(at), pb])
	ranked.sort_custom(func(a, b): return a[0] < b[0])
	var chosen: Array = []
	if bone != "":
		for entry in ranked:
			if (entry[1] as PhysicalBone3D).bone_name == bone:
				chosen.append(entry[1])
				break
	for entry in ranked:
		if chosen.size() >= 2:
			break
		if not chosen.has(entry[1]):
			chosen.append(entry[1])
	var amount := dir.normalized() * (impulse / float(chosen.size()))
	for pb: PhysicalBone3D in chosen:
		pb.apply_impulse(amount, at)


## El empujon del tropiezo: la pierna golpeada se va hacia el lado y el cuerpo
## cae encima. Momento PEQUENO (0,9 N.s, ~1/3 de una bala) a proposito: es el
## peso del hombre el que lo tumba, no el proyectil.
func _push_leg(dir: Vector3) -> void:
	var leg: PhysicalBone3D = null
	for node in ragdoll.find_children("*", "PhysicalBone3D", true, false):
		var pb := node as PhysicalBone3D
		if pb.bone_name == _hit_leg:
			leg = pb
			break
	if leg == null:
		return
	var side := dir.cross(Vector3.UP).normalized()
	var push := (side + Vector3.DOWN * 0.35).normalized() * 0.9
	leg.apply_impulse(push, leg.global_position + Vector3(0, -0.15, 0))


func _blood_at(point: Vector3, dir: Vector3) -> void:
	_wound = point
	_blood.global_position = point
	# El chorro NO se dispara aqui: `_die` llama a `_blood_at_burst` en el mismo
	# frame y con la cantidad definitiva. Reiniciar dos veces por muerte era
	# tirar un burst entero a la GPU.
	# La mancha nace en el mundo (el ragdoll todavia no existe: en cabeza se
	# construye despues, en pecho y pie tras su retardo) y `_anchor_blood` la
	# cuelga del hueso golpeado en cuanto hay cuerpo fisico.
	ImpactFX.spawn_blood_spot(point, _blood_spot, dir)


## La mancha va ADHERIDA a la herida. Nace antes de que exista el `ragdoll`, asi
## que se reengancha aqui, cuando los huesos fisicos ya estan: el charco viaja
## con el cadaver que cae (y acaba proyectandose en el suelo bajo el cuerpo) en
## vez de quedarse flotando en el aire donde entro la bala.
func _anchor_blood() -> void:
	if _blood_spot == null or not _blood_spot.visible or ragdoll == null:
		return
	var best: PhysicalBone3D = null
	var bd := INF
	for node in ragdoll.find_children("*", "PhysicalBone3D", true, false):
		var pb := node as PhysicalBone3D
		var d := pb.global_position.distance_to(_wound)
		if d < bd:
			bd = d
			best = pb
	if best != null:
		_blood_spot.reparent(best, true)


func _blood_at_burst(dir: Vector3, impulse: float) -> void:
	_blood.amount = BLOOD_AMOUNT + int(clampf(impulse * 4.0, 0.0, 16.0))
	_blood.restart()
	_blood.emitting = true


# ---------------------------------------------------------------------------
# Lo que la bala tiene que preguntar antes de mirar la tabla de materiales.
# ---------------------------------------------------------------------------
## El grupo que Ballistics mira. No hay `surface` de carne ni entrada en
## `Ballistics.MATERIALS`: la carne no se penetra, se mata.
func is_target() -> bool:
	return not _dead
