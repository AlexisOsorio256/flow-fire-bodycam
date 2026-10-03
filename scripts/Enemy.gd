class_name Enemy
extends CharacterBody3D

## Enemigo: percibe (vista, oido, memoria), navega, busca linea de tiro y
## dispara. Sin vida: el impacto se clasifica por hueso y la zona decide si
## mata, hiere, cojea o dispara peor.

const ASSET := "res://assets/models/enemy.glb"
const CLIP_IDLE := "Idle"
const CLIP_WALK := "Walk"
const CLIP_NECK := "Neck"
const CLIP_AIM := "Aim"
const CLIP_HIT := "Hit"
const CLIP_DEATH := "Death"

const LAYER := 8

const SIGHT := 22.0
const FOV_COS := -0.25          # semivista ~104 grados: periferia real, no 360
const HEAR := 26.0              ## un disparo cercano le avisa aunque no vea
const EYE_HEIGHT := 1.60
const PLAYER_AIM := Vector3(0.0, 1.25, 0.0)   ## punto que apunta al tirador
const CONTACT_MEMORY := 7.0
const HEAR_STEPS := 9.0

const WALK_SPEED := 1.9
const TURN_RATE := 5.0          ## rad/s de giro: no es instantáneo, se le ve venir
const ARRIVE := 4.0
const BACK_OFF := 2.0
const NAV_RADIUS := 0.34

const BURST := 3
const SHOT_GAP := 0.28
const FIRST_SHOT := 0.35        ## reacción antes del primer tiro
const SHOT_SPREAD := 0.006      ## 1σ en radianes: mano tensa, no pulso de francotirador
const MUZZLE_SPEED := 340.0
const MUZZLE_HEIGHT := 1.42
const MUZZLE_REACH := 0.55

const FALL_REACTION := 0.90
const PUSH_REACTION := 0.12
const BODY_MASS := 78.0
const BLOOD_AMOUNT := 28
const BLOOD_LIFE := 0.90
const BLOOD_TEXTURE: Texture2D = preload("res://assets/textures/particle_soft.png")

enum { IDLE, ALERT, ENGAGE }

const HEAD_BONES := ["Head", "Neck"]
const LEG_BONES := ["Shin_L", "Shin_R", "Foot_L", "Foot_R", "Thigh_L", "Thigh_R"]
const TORSO_BONES := ["Chest", "Chest.001", "Spine", "Hips"]
const ARM_BONES := ["UpperArm_L", "UpperArm_R", "ForeArm_L", "ForeArm_R",
	"Hand_L", "Hand_R"]

var state := IDLE
var _last_seen := Vector3.ZERO
var _contact := 0.0
var visual: Node3D
var skeleton: Skeleton3D
var anim: AnimationPlayer
var ragdoll: PhysicalBoneSimulator3D
var nav: NavigationAgent3D
var nav_map: RID
var _player: Node3D
var _shot_timer := 0.0
var _burst_left := 0
var _dead := false
var _wound := Vector3.ZERO
var _hit_vel := Vector3.ZERO
var _hit_recover := 0.0
var _limp := 0.0
var _aim_bad := 0.0
var _limp_leg := ""
var _hits := 0
var _hit_pitch := 0.0
var _hit_roll := 0.0
var _material: StandardMaterial3D
var _blood_mat: StandardMaterial3D
var fx: WeaponFX
var muzzle: Node3D
var _aiming := false


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 1 | LAYER
	_build_body()
	_build_visual()
	_build_nav()
	_player = get_tree().get_first_node_in_group("player")


func _build_nav() -> void:
	nav = NavigationAgent3D.new()
	nav.name = "Nav"
	nav.radius = NAV_RADIUS
	nav.height = 1.80
	nav.path_desired_distance = 0.25
	nav.target_desired_distance = 0.30
	nav.avoidance_enabled = false
	add_child(nav)


func _connect_nav() -> void:
	if nav == null or is_queued_for_deletion():
		return
	if nav_map.is_valid():
		nav.set_navigation_map(nav_map)


func _build_body() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.26
	shape.height = 1.78
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0, 0.89, 0)
	add_child(col)
	add_to_group("enemy")


func _build_visual() -> void:
	if not ResourceLoader.exists(ASSET):
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
	for name in [CLIP_IDLE, CLIP_WALK, CLIP_NECK, CLIP_AIM, CLIP_HIT, CLIP_DEATH]:
		if _clip(name) == "":
			push_error("Enemy: falta el clip " + name)
			queue_free()
			return
	for name in [CLIP_IDLE, CLIP_WALK, CLIP_AIM]:
		var a := anim.get_animation(_clip(name))
		if a != null:
			a.loop_mode = Animation.LOOP_LINEAR
	for name in [CLIP_HIT, CLIP_DEATH]:
		var r := anim.get_animation(_clip(name))
		if r != null:
			r.loop_mode = Animation.LOOP_NONE
	var neck := anim.get_animation(_clip(CLIP_NECK))
	if neck != null:
		neck.loop_mode = Animation.LOOP_NONE
	_normalize_rig()
	_build_material()
	_blood_nodes()
	muzzle = Node3D.new()
	muzzle.name = "Muzzle"
	add_child(muzzle)
	fx = WeaponFX.new()
	fx.name = "WeaponFX"
	muzzle.add_child(fx)
	fx.build()
	anim.play(_clip(CLIP_IDLE))
	print("ENEMIGO montado: trims=%d huesos=%d clips=%s alto=%.2f m"
		% [_tris(), skeleton.get_bone_count(), anim.get_animation_list(), _rig_height()])


const BODY_HEIGHT := 1.78


func _normalize_rig() -> void:
	var alto := _rig_height()
	if alto < 0.5:
		return
	var k := BODY_HEIGHT / alto
	visual.scale = Vector3(k, k, k)
	visual.position.y = -_bone_world_y("Foot_L") * k


func _rig_height() -> float:
	return _bone_world_y("Head") - _bone_world_y("Foot_L")


func _bone_world_y(name: String) -> float:
	for i in skeleton.get_bone_count():
		if skeleton.get_bone_name(i) == name:
			return skeleton.to_global(skeleton.get_bone_global_pose(i).origin).y
	return 0.0


const TEX_FABRIC := "res://assets/textures/enemy/fabric_%s.jpg"


func _tex(path: String) -> Texture2D:
	return load(path) as Texture2D


func _pbr(albedo: String, normal: String, rough: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex(albedo)
	m.albedo_color = Color(0.42, 0.38, 0.34)
	m.normal_enabled = true
	m.normal_texture = _tex(normal)
	m.roughness_texture = _tex(rough)
	m.roughness = 1.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


func _build_material() -> void:
	_material = _pbr(TEX_FABRIC % "diff", TEX_FABRIC % "nor_gl", TEX_FABRIC % "rough")
	_material.albedo_color = Color(0.12, 0.12, 0.12)
	var fabric := _pbr(TEX_FABRIC % "diff", TEX_FABRIC % "nor_gl", TEX_FABRIC % "rough")
	fabric.albedo_color = Color(0.065, 0.065, 0.065)
	for node in visual.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		mi.mesh.surface_set_material(0, _material)
		mi.mesh.surface_set_material(1, fabric)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


## Ragdoll de 15 cuerpos (los huesos que cargan masa): capsula del hueso a su
## hijo, articulacion de cono con limites por zona y masa por segmento. Dedos,
## hombros y punteras siguen al padre sin fisica.
const RAGDOLL := {
	# hueso: [hijo, radio m, fraccion de masa, giro max (grados), torsion max]
	"Hips": ["Spine", 0.13, 0.15, 0.0, 0.0],
	"Spine": ["Chest", 0.13, 0.10, 20.0, 15.0],
	"Chest": ["Chest.001", 0.14, 0.10, 20.0, 15.0],
	"Chest.001": ["Neck", 0.15, 0.10, 15.0, 10.0],
	"Head": ["", 0.10, 0.08, 45.0, 50.0],
	"UpperArm_L": ["ForeArm_L", 0.055, 0.03, 80.0, 40.0],
	"UpperArm_R": ["ForeArm_R", 0.055, 0.03, 80.0, 40.0],
	"ForeArm_L": ["Hand_L", 0.045, 0.02, 75.0, 20.0],
	"ForeArm_R": ["Hand_R", 0.045, 0.02, 75.0, 20.0],
	"Hand_L": ["", 0.04, 0.01, 40.0, 20.0],
	"Hand_R": ["", 0.04, 0.01, 40.0, 20.0],
	"Thigh_L": ["Shin_L", 0.085, 0.10, 60.0, 20.0],
	"Thigh_R": ["Shin_R", 0.085, 0.10, 60.0, 20.0],
	"Shin_L": ["Foot_L", 0.06, 0.045, 70.0, 10.0],
	"Shin_R": ["Foot_R", 0.06, 0.045, 70.0, 10.0],
}
## La bala de verdad apenas mueve 80 kg: el empuje visible se escala.
const HIT_PUSH := 14.0


func _build_ragdoll() -> void:
	ragdoll = PhysicalBoneSimulator3D.new()
	ragdoll.name = "Ragdoll"
	skeleton.add_child(ragdoll)
	var scale := visual.scale.x if visual != null else 1.0
	for bone_name in RAGDOLL:
		var i := skeleton.find_bone(bone_name)
		if i < 0:
			continue
		var spec: Array = RAGDOLL[bone_name]
		var length := 0.10 / scale
		var child := skeleton.find_bone(spec[0])
		if child >= 0:
			length = skeleton.get_bone_global_rest(child).origin.distance_to(
				skeleton.get_bone_global_rest(i).origin)
		var radius: float = spec[1] / scale
		var pb := PhysicalBone3D.new()
		pb.name = "PB_" + bone_name
		pb.bone_name = bone_name
		pb.mass = BODY_MASS * spec[2]
		pb.linear_damp = 0.15
		pb.angular_damp = 1.2
		pb.friction = 0.9
		pb.collision_layer = 4
		pb.collision_mask = 1
		var col := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = radius
		cap.height = maxf(length + radius * 0.6, radius * 2.0 + 0.01)
		col.shape = cap
		col.position = Vector3(0, length * 0.5, 0)
		pb.add_child(col)
		if bone_name != "Hips":
			pb.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
			pb.set("joint_constraints/swing_span", spec[3])
			pb.set("joint_constraints/twist_span", spec[4])
			pb.set("joint_constraints/softness", 0.8)
			pb.set("joint_constraints/relaxation", 1.0)
		ragdoll.add_child(pb)
	ragdoll.physical_bones_start_simulation()


func _blood_nodes() -> void:
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
	_blood_mat.albedo_texture = BLOOD_TEXTURE
	_blood_mat.albedo_color = Color(0.34, 0.02, 0.015, 1.0)
	_blood_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_blood_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_blood_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_blood_mat.vertex_color_use_as_albedo = true
	_blood_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
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
			var arrays := mi.mesh.surface_get_arrays(s)
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if idx.is_empty():
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				total += verts.size() / 3
			else:
				total += idx.size() / 3
	return total


func _see_player() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	var eye := global_position + Vector3(0, EYE_HEIGHT, 0)
	var target: Vector3 = _player.global_position + PLAYER_AIM
	var to := target - eye
	var dist := to.length()
	if dist > SIGHT:
		return false
	if state == IDLE and _enemy_forward().dot(to.normalized()) < FOV_COS:
		return false
	var q := PhysicsRayQueryParameters3D.create(eye, target, 1)
	q.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _enemy_forward() -> Vector3:
	return Vector3(-global_basis.z.x, 0.0, -global_basis.z.z).normalized()


func _perceive(delta: float) -> bool:
	if _see_player():
		_contact = CONTACT_MEMORY
		_last_seen = _player.global_position
		return true
	_contact = maxf(0.0, _contact - delta)
	if _contact > 0.0:
		return true
	if _player is CharacterBody3D and (_player as CharacterBody3D).velocity.length() > 0.6:
		if global_position.distance_to(_player.global_position) <= HEAR_STEPS:
			_contact = CONTACT_MEMORY * 0.5
			_last_seen = _player.global_position
			return true
	return false


func _player_forward() -> Vector3:
	if _player == null:
		return Vector3.FORWARD
	var yaw: float = _player.get("yaw")
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func hear(noise_at: Vector3) -> void:
	if _dead or state != IDLE:
		return
	if global_position.distance_to(noise_at) <= HEAR:
		state = ALERT
		_shot_timer = FIRST_SHOT


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if fx != null:
		fx.update(delta)
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if not is_instance_valid(_player):
			velocity = Vector3.ZERO
			return
	var tiene := _perceive(delta)
	_aiming = false
	if state == IDLE and not tiene:
		velocity = Vector3.ZERO
		_mix_walk(delta, 0.0)
		return
	if state == IDLE:
		state = ALERT
		_shot_timer = FIRST_SHOT
	var ve := _see_player()
	var objetivo := _player.global_position if ve else _last_seen
	var aim := objetivo + PLAYER_AIM - (global_position + Vector3(0, MUZZLE_HEIGHT, 0))
	var flat := Vector3(aim.x, 0.0, aim.z)
	var want := atan2(-flat.x, -flat.z)
	_turn(want, delta)
	if state == ALERT:
		if flat.length() > ARRIVE:
			velocity = _step_toward(objetivo)
		else:
			velocity = Vector3.ZERO
		if absf(angle_difference(_yaw(), want)) < 0.35:
			state = ENGAGE
	else:
		var dist := flat.length()
		_aiming = ve and dist <= ARRIVE
		if dist > ARRIVE and (ve or _contact <= 0.0):
			velocity = _step_toward(objetivo)
		elif dist < BACK_OFF and ve:
			velocity = -flat.normalized() * WALK_SPEED
		else:
			velocity = Vector3.ZERO
		if _aiming:
			_shoot(delta)
		else:
			_shot_timer = FIRST_SHOT
	if _hit_vel.length_squared() > 0.00001:
		velocity += _hit_vel
		_hit_vel = _hit_vel.lerp(Vector3.ZERO, 1.0 - exp(-7.0 * delta))
	move_and_slide()
	_mix_walk(delta, velocity.length() / WALK_SPEED)
	if _hit_recover > 0.0:
		_hit_recover = maxf(0.0, _hit_recover - delta)
		var k := _hit_recover / 0.45
		visual.rotation.x = _hit_pitch * k
		visual.rotation.z = _hit_roll * k
	elif not _dead:
		visual.rotation.x = 0.0
		visual.rotation.z = 0.0


func _step_toward(target: Vector3) -> Vector3:
	var speed := WALK_SPEED * (1.0 - 0.45 * _limp)
	var straight := Vector3(-sin(_yaw()), 0.0, -cos(_yaw())) * speed
	if nav == null:
		return straight
	nav.target_position = target
	if nav.is_navigation_finished():
		return straight
	var next := nav.get_next_path_position()
	var dir := Vector3(next.x - global_position.x, 0.0, next.z - global_position.z)
	if dir.length() > 0.02:
		return dir.normalized() * speed
	return straight


func _yaw() -> float:
	return atan2(-global_basis.z.x, -global_basis.z.z)


func _turn(want: float, delta: float) -> void:
	var y := _yaw()
	var step := clampf(angle_difference(y, want), -TURN_RATE * delta, TURN_RATE * delta)
	rotate_y(step)


func _mix_walk(_delta: float, want: float) -> void:
	var target := _clip(CLIP_WALK) if want > 0.5 else _clip(CLIP_IDLE)
	if _aiming:
		target = _clip(CLIP_AIM)
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
	var from := _muzzle_world()
	if from == Vector3.ZERO:
		from = global_position + Vector3(0, MUZZLE_HEIGHT, 0) - global_basis.z * 0.45
	var to := _player.global_position + PLAYER_AIM
	var aim := (to - from).normalized()
	var side := aim.cross(Vector3.UP).normalized()
	var up := side.cross(aim).normalized()
	var spread := SHOT_SPREAD * (1.0 + 2.4 * _aim_bad)
	var dir := (aim
		+ side * randfn(0.0, spread) + up * randfn(0.0, spread)).normalized()
	Ballistics.fire(from, dir, MUZZLE_SPEED, false)
	_fogonazo(from, dir)


func _muzzle_world() -> Vector3:
	var h := skeleton.find_bone("Hand_R")
	var f := skeleton.find_bone("ForeArm_R")
	if h < 0 or f < 0:
		return Vector3.ZERO
	var mano := skeleton.to_global(skeleton.get_bone_global_pose(h).origin)
	var codo := skeleton.to_global(skeleton.get_bone_global_pose(f).origin)
	var bore := mano - codo
	return mano + (bore.normalized() if bore.length() > 0.01 else -global_basis.z) * MUZZLE_REACH


func _fogonazo(from: Vector3, dir: Vector3) -> void:
	muzzle.global_position = from
	muzzle.basis = Basis.looking_at(dir, Vector3.UP)
	fx.fire(muzzle, from, dir)
	GameAudio.play_3d("shot_enemy", from, -8.0, randf_range(0.94, 1.06))

func hit(point: Vector3, dir: Vector3, impulse: float) -> void:
	if _dead:
		return
	var local := point - global_position
	var region := _region_at(local)
	var bone := _nearest_bone(local, _bones_of(region))
	_blood_at(point, dir)
	if _is_vital(region, bone):
		_die(region, local, dir, impulse, bone)
	else:
		_take_wound(region, bone, local, dir, impulse)


func _region_at(local: Vector3) -> String:
	var best := ""
	var best_d := INF
	var best_group := "body"
	var world := global_transform * local
	for i in skeleton.get_bone_count():
		var name := skeleton.get_bone_name(i)
		var group := _group_of(name)
		if group == "":
			continue
		var bone_world := skeleton.to_global(skeleton.get_bone_global_pose(i).origin)
		var d := Vector2(bone_world.x - world.x, bone_world.z - world.z).length() \
			+ absf(bone_world.y - world.y) * 0.35
		if d < best_d:
			best_d = d
			best = name
			best_group = group
	return best_group


func _group_of(bone_name: String) -> String:
	if HEAD_BONES.has(bone_name):
		return "head"
	if ARM_BONES.has(bone_name):
		return "arm"
	if LEG_BONES.has(bone_name):
		return "leg"
	if TORSO_BONES.has(bone_name):
		return "torso"
	return ""


func _is_vital(region: String, bone: String) -> bool:
	if region == "head":
		return true
	if region == "torso":
		return bone != "Hips"
	if region == "leg":
		return bone.begins_with("Thigh")   ## femoral: se desangra en pie
	return false


func _bones_of(region: String) -> Array:
	match region:
		"head":
			return HEAD_BONES
		"leg":
			return LEG_BONES
		"torso":
			return TORSO_BONES
		"arm":
			return ARM_BONES
	return []


func _take_wound(region: String, bone: String, local: Vector3, dir: Vector3,
		impulse: float) -> void:
	var punch := clampf(impulse / 2.77, 0.4, 1.4)
	var b := global_transform.basis.inverse() * dir.normalized()
	_hit_vel += Vector3(b.x * 0.9, 0.0, b.z * 0.9) * punch
	_hit_pitch = clampf(b.z * 0.24, -0.24, 0.24) * punch
	_hit_roll = clampf(-b.x * 0.18, -0.18, 0.18) * punch
	if region == "leg":
		_limp = 1.0
		_limp_leg = bone
		_mix_walk(0.0, 1.0)
		_anim_play(_clip(CLIP_HIT))
		if anim.current_animation == _clip(CLIP_HIT):
			anim.seek(0.0, true)
		_shot_timer = maxf(_shot_timer, 0.55)   ## le cuesta reaccionar
	elif region == "torso":
		_anim_play(_clip(CLIP_HIT))
		if anim.current_animation == _clip(CLIP_HIT):
			anim.seek(0.0, true)
		_shot_timer = maxf(_shot_timer, 0.75)
	elif region == "arm":
		_anim_play(_clip(CLIP_HIT))
		if anim.current_animation == _clip(CLIP_HIT):
			anim.seek(0.0, true)
		_shot_timer = maxf(_shot_timer, 0.95)
		_aim_bad = 1.0
	_hit_recover = maxf(_hit_recover, 0.45)
	_hits += 1


func _die(region: String, local: Vector3, dir: Vector3, impulse: float,
		bone: String) -> void:
	_dead = true
	set_physics_process(false)
	velocity = Vector3.ZERO
	_blood_at_burst(dir, impulse)
	match region:
		"head":
			_ragdoll(dir, impulse, local, "Head")
		"torso":
			_anim_play(_clip(CLIP_HIT))
			var t := get_tree().create_timer(PUSH_REACTION)
			t.timeout.connect(_to_ragdoll.bind(dir, impulse, local, bone))
		_:
			_anim_play(_clip(CLIP_DEATH))
			anim.seek(randf_range(0.0, 0.30), true)
			var t := get_tree().create_timer(FALL_REACTION * 0.55)
			t.timeout.connect(_to_ragdoll.bind(dir, impulse, local, bone))


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


func _push(dir: Vector3, impulse: float, local: Vector3, bone: String) -> void:
	if impulse <= 0.0 and bone == "":
		return
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
	var amount := dir.normalized() * (maxf(impulse, 1.0) * HIT_PUSH / float(chosen.size()))
	for pb: PhysicalBone3D in chosen:
		pb.apply_impulse(amount, at)


func _blood_at(point: Vector3, dir: Vector3) -> void:
	_wound = point
	_blood.global_position = point
	ImpactFX.spawn_blood_spot(point, _blood_spot, dir)


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


func is_target() -> bool:
	return not _dead
