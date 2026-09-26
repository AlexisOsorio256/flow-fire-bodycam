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
## LA LOCALIZACION DEL IMPACTO SOLO AFECTA A LA PRESENTACION, no a si muere:
## un tiro al cuello no hace mas dano que uno al pecho, lo que cambia es lo que
## se VE (reacción al cuello, sangre y caida) y eso se decide en `_die`, con el
## punto de impacto en espacio local.
##
## SIN NavigationAgent3D. El deposito son dos salas de 16x16 con un hueco: ir de
## frente y dejar que Jolt deslice (move_and_slide) basta, y un navmesh son
## otro horneado que mantener para un mapa que no lo necesita.

## DEPENDENCIA PENDIENTE. El asset es un personaje real con esqueleto; el que se
## probo era un soldado medieval y se descarto. La cadena de muerte, la
## localizacion por hueso, la sangre y el ragdoll ya estan escritas y verificadas
## (`tools/check_enemy.tscn`); lo que falta es el cuerpo. `CombatMap` no puebla
## enemigos mientras este archivo no exista, para que el juego arranque limpio.
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
const EYE_LEVEL := 1.58

# --- Disparo --------------------------------------------------------------
## Ráfaga de 3 con 0,28 s entre tiros: una Glock de servicio, no una ametralladora.
const BURST := 3
const SHOT_GAP := 0.28
const FIRST_SHOT := 0.35        ## reacción antes del primer tiro
const SHOT_SPREAD := 0.006      ## 1σ en radianes: mano tensa, no pulso de francotirador
const MUZZLE_SPEED := 340.0
const MUZZLE_HEIGHT := 1.42

# --- Muerte ---------------------------------------------------------------
## Segundos que dura la reacción visible ANTES de que la física tome el control.
## El clip Neck dura 0,90 s y entrega al cuerpo ya doblado: a los 0,50 s el
## tronco y la mano al cuello ya se han visto, y a partir de ahí manda Jolt.
const NECK_REACTION := 0.50
const BLOOD_AMOUNT := 14
const BLOOD_LIFE := 0.55
## Peso del cuerpo: 78 kg. Se reparte por hueso en `_bone_share`.
const BODY_MASS := 78.0

enum { IDLE, ALERT, ENGAGE }

## Rocas de la bledumbre: si el punto de impacto cae cerca de este hueso, la
## presentacion es la del cuello. Es una lista corta y FIJA, no un sistema de
## zonas: son los huesos que se leen desde fuera.
const NECK_BONES := ["Head", "Neck"]

var state := IDLE
var visual: Node3D
var skeleton: Skeleton3D
var anim: AnimationPlayer
var ragdoll: PhysicalBoneSimulator3D
var _player: Node3D
var _shot_timer := 0.0
var _burst_left := 0
var _dead := false


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
		# Dependencia pendiente, no un fallo de arranque: el juego sigue y el mapa
		# se puebla sin enemigos hasta que haya cuerpo.
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
	# La sangre se dibuja una vez y se reutiliza: un burst corto y un charco.
	_blood_nodes()
	anim.play(_clip(CLIP_IDLE))
	print("ENEMIGO montado: trims=%d huesos=%d clips=%s"
		% [_tris(), skeleton.get_bone_count(), anim.get_animation_list()])


## RAGDOLL. `PhysicalBoneSimulator3D` es el solver del motor y no se reescribe,
## pero sus `PhysicalBone3D` NO se crean solos fuera del editor: el importador de
## glTF no los produce y el plugin del editor es el que los soltaba al guardar la
## escena. En runtime hay que construirlos, y es lo unico que hay que construir.
##
## SE CONSTRUYEN AL MORIR, no al montar, y por dos razones que medí: un enemigo vivo
## se le caia entre los pies al aparecer en el mapa (`simulate_physics` ya no es
## asignable en 4.7 y `physical_bones_stop_simulation()` no frena un hueso que
## nunca se detuvo), y 19 cuerpos rigidos por enemigo son 57 cuerpos en un mapa con
## tres. Un cadaver los crea; un enemigo que anda, no los tiene.
##
## La masa se reparte por hueso y no por igual: un craneo y una tibia pesan lo
## mismo, y un torso de 19 huesos de 4 kg cada uno cae como un bloque de plomo.
## El total es 78 kg, que es lo que pesa una persona.
func _build_ragdoll() -> void:
	ragdoll = PhysicalBoneSimulator3D.new()
	ragdoll.name = "Ragdoll"
	skeleton.add_child(ragdoll)
	var count := skeleton.get_bone_count()
	for i in count:
		var bone_name := skeleton.get_bone_name(i)
		var pb := PhysicalBone3D.new()
		pb.name = "PB_" + bone_name
		pb.bone_name = bone_name
		pb.mass = BODY_MASS * _bone_share(bone_name)
		# El hueso RAIZ no tiene padre: sin union se caeria solo. El resto se une al
		# padre con una articulation cono-torsion, que es la que deja que el cuello
		# se doble y el hombro gire sin que el cuerpo se desmonte.
		if i > 0:
			pb.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
		ragdoll.add_child(pb)
	# Se arranca YA, porque `_ragdoll` solo llama a este cuando el cuerpo ya esta
	# doblado y quieto: la reaccion animada happened antes.
	ragdoll.physical_bones_start_simulation()


## Reparto de masa, en fraccion del cuerpo. Tronco y cabeza llevamos la parte
## grande; manos y pies, una fraccion. Los valores estan normalizados a 1.
func _bone_share(bone_name: String) -> float:
	if bone_name == "Hips":
		return 0.20
	if bone_name in ["Spine", "Chest"]:
		return 0.24
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
	var quad := QuadMesh.new()
	quad.size = Vector2(0.022, 0.022)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.34, 0.02, 0.015, 1.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = mat
	_blood = GPUParticles3D.new()
	_blood.name = "Blood"
	_blood.amount = BLOOD_AMOUNT
	_blood.lifetime = BLOOD_LIFE
	_blood.one_shot = true
	_blood.explosiveness = 1.0
	_blood.process_material = pm
	_blood.draw_pass_1 = quad
	_blood.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_blood.emitting = false
	add_child(_blood)

	# El charco: UN decal del mismo tipo que usa ImpactFX para los agujeros, con
	# una silueta propia de mancha. Se queda en el suelo y no se borra: un rastro
	# de por donde has pasado es informacion, no basura.
	_blood_spot = Decal.new()
	_blood_spot.texture_albedo = _blood_texture()
	_blood_spot.size = Vector3(0.42, 0.05, 0.42)
	_blood_spot.upper_fade = 0.0
	_blood_spot.lower_fade = 0.5
	_blood_spot.modulate = Color(1, 1, 1, 0.0)
	_blood_spot.visible = false
	add_child(_blood_spot)


var _blood: GPUParticles3D
var _blood_spot: Decal


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


func _tris() -> int:
	var total := 0
	for node in visual.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var verts: PackedVector3Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			total += verts.size() / 3
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
	if _dead:
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
func _region_at(local: Vector3) -> String:
	var best := ""
	var best_d := INF
	for i in skeleton.get_bone_count():
		var name := skeleton.get_bone_name(i)
		if not NECK_BONES.has(name):
			continue
		var d := skeleton.to_local(skeleton.get_bone_global_pose(i).origin).distance_to(local)
		if d < best_d:
			best_d = d
			best = name
	# 12 cm de margen: por debajo, el punto mas bajo que se puede tocar en el
	# cuello sigue siendo cuello, que es como lo lee el ojo en una captura.
	return best if best_d < 0.12 else "body"


func _die(region: String, local: Vector3, dir: Vector3, impulse: float) -> void:
	_dead = true
	set_physics_process(false)
	velocity = Vector3.ZERO
	# UN IMPACTO VALIDO MATA. No hay vida, ni escotilla, ni segundo golpe.
	_blood_at_burst(dir, impulse)
	if region == "neck":
		# La cadena que hace creible el cuello: la mano sube y se apoya (clip
		# de 0,90 s medido a 0-1 mm del cuello en Blender), y a los 0,50 s, con
		# el tronco ya doblado, la fisica toma el control.
		anim.play(_clip(CLIP_NECK))
		anim.speed_scale = 1.0
		var t := get_tree().create_timer(NECK_REACTION)
		t.timeout.connect(_to_ragdoll.bind(dir, impulse, local))
	else:
		_ragdoll(dir, impulse, local)


func _to_ragdoll(dir: Vector3, impulse: float, local: Vector3) -> void:
	if not is_instance_valid(self):
		return
	_ragdoll(dir, impulse, local)


func _ragdoll(dir: Vector3, impulse: float, local: Vector3) -> void:
	collision_layer = 0
	collision_mask = 0
	_build_ragdoll()
	_push(dir, impulse, local)


## El impulso de la bala a los DOS huesos mas cercanos al impacto, con el MISMO
## momento lineal que el resto del mundo (ver `Ballistics._push_body`): lo que la
## bala pierde se lo lleva el cuerpo, sin factores inventados.
##
## DOS huesos y no uno: un proyectil de 9 mm que entrega los 2,77 N.s enteros a
## un solo hueso hace que solo se mueva el cuello y el torso se quede deformaso
## en el aire. Repartido entre los dos mas cercanos, el impulso de la bala TIENE
## que entrar en el esqueleto, porque son huesos rigidbody: el cuerpo no tiene
## `apply_central_impulse` (eso es de `RigidBody3D`) y no se inventa un empujon
## de mas, se reparte el que hay entre los huesos que lo pueden recibir.
func _push(dir: Vector3, impulse: float, local: Vector3) -> void:
	if impulse <= 0.0:
		return
	var at := skeleton.global_position + local
	var ranked: Array = []
	for node in ragdoll.find_children("*", "PhysicalBone3D", true, false):
		var pb := node as PhysicalBone3D
		ranked.append([pb.global_position.distance_to(at), pb])
	ranked.sort_custom(func(a, b): return a[0] < b[0])
	var take: int = mini(2, ranked.size())
	for i in take:
		var pb: PhysicalBone3D = ranked[i][1]
		pb.apply_impulse(dir.normalized() * (impulse / float(take)), at)


func _blood_at(point: Vector3, dir: Vector3) -> void:
	_blood.global_position = point
	_blood.restart()
	_blood.emitting = true
	ImpactFX.spawn_blood_spot(point, _blood_spot, dir)


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
