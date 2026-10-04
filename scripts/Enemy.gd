class_name Enemy
extends CharacterBody3D

const ASSET := "res://assets/models/enemy.glb"
const CLIP_IDLE := "Idle"
const CLIP_WALK := "Walk"
const CLIP_AIM := "Aim"
const CLIP_HIT := "Hit"
const CLIP_DEATH := "Death"
const CLIP_READY := "Ready"
const CLIP_SNEAK := "Sneak"
const CLIP_RUN := "Run"
const CLIP_CROUCH_AIM := "CrouchAim"
const LOOPING := [CLIP_IDLE, CLIP_WALK, CLIP_AIM, CLIP_READY, CLIP_SNEAK, CLIP_RUN, CLIP_CROUCH_AIM]
const LOD_RANGES := {"": Vector2(0.0, 9.0), "LOD1": Vector2(9.0, 22.0), "LOD2": Vector2(22.0, 0.0)}
const FEAR_TIME := 2.5
const FEAR_RANGE := 9.0

const ACTOR_LAYER := 16
const HITBOX_LAYER := 8

const EYE_HEIGHT := 1.60
const THINK_HZ := 8.0

const SIGHT := 26.0
const FOV_COS := -0.10
const NOTICE_CALM := 0.7
const NOTICE_PER_M := 0.05
const NOTICE_ALERT := 0.12
const HEAR_SHOT := 34.0
const INVESTIGATE := 18.0
const PANIC := 10.0
const MEMORY := 6.0

const WALK_SPEED := 1.9
const RUN_SPEED := 3.4
const TURN_RATE := 6.0
const NAV_RADIUS := 0.34

const REACTION := Vector2(0.35, 0.65)
const BURST := Vector2i(2, 4)
const SHOT_GAP := Vector2(0.15, 0.24)
const BURST_PAUSE := Vector2(0.35, 0.85)
const SPREAD_START := 0.06
const SPREAD_SETTLED := 0.009
const VS_SOLDIER := 1.6
const MUZZLE_SPEED := 340.0

const HP := 100.0
const ZONES := {
	"Head": ["head", 200.0], "Neck": ["head", 200.0],
	"Chest.001": ["chest", 55.0], "Chest": ["chest", 55.0],
	"Spine": ["belly", 50.0], "Hips": ["hips", 40.0],
	"UpperArm_L": ["arm", 25.0], "UpperArm_R": ["arm", 25.0],
	"ForeArm_L": ["arm", 20.0], "ForeArm_R": ["arm", 20.0],
	"Hand_L": ["arm", 15.0], "Hand_R": ["arm", 15.0],
	"Thigh_L": ["leg", 34.0], "Thigh_R": ["leg", 34.0],
	"Shin_L": ["leg", 25.0], "Shin_R": ["leg", 25.0],
}
const KICK := {"head": 30.0, "chest": 22.0, "belly": 20.0, "hips": 16.0, "arm": 26.0, "leg": 22.0}

const RAGDOLL := {
	"Hips": ["Spine", 0.14, 0.15, 0.0, 0.0],
	"Spine": ["Chest", 0.14, 0.10, 20.0, 15.0],
	"Chest": ["Chest.001", 0.16, 0.10, 20.0, 15.0],
	"Chest.001": ["Neck", 0.17, 0.10, 15.0, 10.0],
	"Neck": ["Head", 0.06, 0.02, 25.0, 30.0],
	"Head": ["", 0.11, 0.06, 40.0, 50.0],
	"UpperArm_L": ["ForeArm_L", 0.06, 0.03, 80.0, 40.0],
	"UpperArm_R": ["ForeArm_R", 0.06, 0.03, 80.0, 40.0],
	"ForeArm_L": ["Hand_L", 0.05, 0.02, 75.0, 20.0],
	"ForeArm_R": ["Hand_R", 0.05, 0.02, 75.0, 20.0],
	"Hand_L": ["", 0.045, 0.01, 40.0, 20.0],
	"Hand_R": ["", 0.045, 0.01, 40.0, 20.0],
	"Thigh_L": ["Shin_L", 0.09, 0.10, 60.0, 20.0],
	"Thigh_R": ["Shin_R", 0.09, 0.10, 60.0, 20.0],
	"Shin_L": ["Foot_L", 0.065, 0.06, 70.0, 10.0],
	"Shin_R": ["Foot_R", 0.065, 0.06, 70.0, 10.0],
}
const BODY_MASS := 78.0
const DEATH_PUSH := Vector2(7.0, 15.0)
const RAGDOLL_GRAVITY := 1.7
const DEATH_SLUMP := 0.9
const GUN_KG := 0.67
const FACE_LIFT := Vector3(0.0, 0.09, 0.0)
const REACT_BONES := ["Hips", "Spine", "Chest", "Chest.001", "Neck", "Head",
	"UpperArm_L", "UpperArm_R", "ForeArm_L", "ForeArm_R", "Thigh_L", "Thigh_R", "Shin_L", "Shin_R"]

const BLOOD_TEXTURE: Texture2D = preload("res://assets/textures/particle_soft.png")

enum { HOLD, ENGAGE, COVER, SEARCH }

var hitbox_rids: Array[RID] = []
var state := HOLD
var visual: Node3D
signal killed(enemy: Node3D)

var skeleton: Skeleton3D
var anim: AnimationPlayer
var ragdoll: PhysicalBoneSimulator3D
var react: HitReact
var nav: NavigationAgent3D
var nav_map: RID
var fx: WeaponFX
var muzzle: Node3D

var _hp := HP
var _dead := false
var _limp := 0.0
var _aim_bad := 0.0
var _hit_vel := Vector3.ZERO
var _hit_clip := 0.0
var _fear := 0.0

var _target: Node3D
var _target_visible := false
var _target_pos := Vector3.ZERO
var _target_time := 0.0
var _lost := 0.0
var _attacker: Node3D
var _hostile_all := false
var _notice := {}
var _think := 0.0
var _goal := Vector3.INF
var _post := Vector3.ZERO
var _post_yaw := 0.0
var _look_yaw := 0.0
var _scan := 0.0
var _cover_wait := 0.0
var _engage_time := 0.0

var _shot_timer := 0.0
var _burst_left := 0
var _bones := {}
var _clips := {}
var _blood: GPUParticles3D
var _blood_spot: Decal
var _pool: Decal
var _wound := Vector3.ZERO


func _ready() -> void:
	collision_layer = ACTOR_LAYER
	collision_mask = 1 | ACTOR_LAYER | Player.LAYER
	add_to_group("enemy")
	_build_body()
	if not _build_visual():
		return
	_build_nav()
	_post = global_position
	_post_yaw = _yaw()
	_look_yaw = _post_yaw
	_think = randf() / THINK_HZ


func is_alive() -> bool:
	return not _dead


func _build_body() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.28
	shape.height = 1.78
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0, 0.89, 0)
	add_child(col)


func _build_visual() -> bool:
	var packed := load(ASSET) as PackedScene
	if packed == null:
		push_error("Enemy: falta " + ASSET)
		queue_free()
		return false
	visual = packed.instantiate() as Node3D
	visual.name = "Visual"
	add_child(visual)
	skeleton = visual.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	anim = visual.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for clip in LOOPING + [CLIP_HIT, CLIP_DEATH]:
		_clips[clip] = _clip(clip)
		if _clips[clip] == "":
			push_error("Enemy: falta el clip " + clip)
			queue_free()
			return false
	for clip in LOOPING:
		anim.get_animation(_clip(clip)).loop_mode = Animation.LOOP_LINEAR
	for clip in [CLIP_HIT, CLIP_DEATH]:
		anim.get_animation(_clip(clip)).loop_mode = Animation.LOOP_NONE
	for i in skeleton.get_bone_count():
		_bones[skeleton.get_bone_name(i)] = i
	_build_lods()
	react = HitReact.new()
	react.name = "HitReact"
	skeleton.add_child(react)
	react.setup(REACT_BONES)
	_build_ragdoll()
	_build_blood()
	muzzle = Node3D.new()
	muzzle.name = "Muzzle"
	add_child(muzzle)
	fx = WeaponFX.new()
	fx.name = "WeaponFX"
	muzzle.add_child(fx)
	fx.build()
	var notifier := VisibleOnScreenNotifier3D.new()
	notifier.aabb = AABB(Vector3(-0.6, 0.0, -0.6), Vector3(1.2, 2.0, 1.2))
	notifier.screen_entered.connect(_on_screen.bind(true))
	notifier.screen_exited.connect(_on_screen.bind(false))
	add_child(notifier)
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	anim.play(_clip(CLIP_IDLE))
	anim.seek(randf() * 2.0, true)
	return true


var _anim_step := 0.0
var _on_view := false


func _on_screen(seen: bool) -> void:
	_on_view = seen
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE if seen \
		else AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL


func _process(delta: float) -> void:
	if _on_view or _dead:
		return
	_anim_step += delta
	if _anim_step >= 0.1:
		anim.advance(_anim_step)
		_anim_step = 0.0


func face_point() -> Vector3:
	return skeleton.global_transform * skeleton.get_bone_global_pose(_bones["Head"]) * FACE_LIFT


func _bone_world(name: String) -> Vector3:
	return skeleton.global_transform * skeleton.get_bone_global_pose(_bones.get(name, 0)).origin


func _build_lods() -> void:
	for node in visual.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or not mi.name.begins_with("Enemy_Mesh"):
			continue
		var lod: String = mi.name.get_slice("_", 2) if mi.name.count("_") >= 2 else ""
		var range: Vector2 = LOD_RANGES.get(lod, LOD_RANGES[""])
		mi.visibility_range_begin = range.x
		mi.visibility_range_end = range.y
		mi.visibility_range_begin_margin = 1.0 if range.x > 0.0 else 0.0
		mi.visibility_range_end_margin = 1.0 if range.y > 0.0 else 0.0
		if lod == "LOD2":
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_ragdoll() -> void:
	ragdoll = PhysicalBoneSimulator3D.new()
	ragdoll.name = "Ragdoll"
	skeleton.add_child(ragdoll)
	for bone_name in RAGDOLL:
		var i: int = _bones.get(bone_name, -1)
		if i < 0:
			continue
		var spec: Array = RAGDOLL[bone_name]
		var length := 0.12
		var child: int = _bones.get(spec[0], -1)
		if child >= 0:
			length = skeleton.get_bone_global_rest(child).origin.distance_to(
				skeleton.get_bone_global_rest(i).origin)
		var radius: float = spec[1]
		var pb := PhysicalBone3D.new()
		pb.name = "PB_" + bone_name
		pb.bone_name = bone_name
		pb.mass = BODY_MASS * spec[2]
		pb.linear_damp = 0.2
		pb.angular_damp = 3.2
		pb.gravity_scale = RAGDOLL_GRAVITY
		pb.friction = 1.0
		pb.bounce = 0.0
		pb.collision_layer = HITBOX_LAYER
		pb.collision_mask = 1
		pb.set_meta("actor", self)
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
		hitbox_rids.append(pb.get_rid())


func _build_blood() -> void:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, -1)
	pm.spread = 35.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 3.2
	pm.gravity = Vector3(0, -9.0, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.6
	pm.color = Color(0.30, 0.015, 0.012, 1.0)
	pm.damping_min = 0.6
	pm.damping_max = 1.6
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = BLOOD_TEXTURE
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var quad := QuadMesh.new()
	quad.size = Vector2(0.045, 0.045)
	quad.material = mat
	_blood = GPUParticles3D.new()
	_blood.name = "Blood"
	_blood.amount = 24
	_blood.lifetime = 0.9
	_blood.one_shot = true
	_blood.explosiveness = 1.0
	_blood.local_coords = false
	_blood.process_material = pm
	_blood.draw_pass_1 = quad
	_blood.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_blood.emitting = false
	_blood.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_blood)

	var stain := _blood_texture()
	_blood_spot = Decal.new()
	_blood_spot.texture_albedo = stain
	_blood_spot.upper_fade = 0.0
	_blood_spot.lower_fade = 0.5
	_blood_spot.visible = false
	add_child(_blood_spot)
	_pool = Decal.new()
	_pool.texture_albedo = stain
	_pool.upper_fade = 0.3
	_pool.lower_fade = 0.3
	_pool.visible = false
	_pool.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_pool)


static var _stain: ImageTexture


static func _blood_texture() -> ImageTexture:
	if _stain != null:
		return _stain
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var u := (float(x) + 0.5) / 32.0 - 1.0
			var v := (float(y) + 0.5) / 32.0 - 1.0
			var ang := atan2(v, u)
			var n := 0.5 + 0.5 * sin(ang * 5.0 + sin(ang * 3.0) * 2.0)
			var r := sqrt(u * u + v * v) * (1.0 + 0.22 * (n - 0.5))
			img.set_pixel(x, y, Color(0.22, 0.010, 0.008, 0.9 * smoothstep(0.95, 0.30, r)))
	img.generate_mipmaps()
	_stain = ImageTexture.create_from_image(img)
	return _stain


func _build_nav() -> void:
	nav = NavigationAgent3D.new()
	nav.name = "Nav"
	nav.radius = NAV_RADIUS
	nav.height = 1.80
	nav.path_desired_distance = 0.35
	nav.target_desired_distance = 0.45
	nav.avoidance_enabled = false
	add_child(nav)


func _connect_nav() -> void:
	if nav != null and nav_map.is_valid():
		nav.set_navigation_map(nav_map)


func _clip(name: String) -> String:
	for c in anim.get_animation_list():
		var s := String(c)
		if s == name or s.ends_with("/" + name) or s.ends_with("|" + name) or s.ends_with("_" + name):
			return s
	return ""


func _eye() -> Vector3:
	return global_position + Vector3(0, EYE_HEIGHT, 0)


func aim_point() -> Vector3:
	return _bone_world("Chest.001")


static func chest_of(actor: Node3D) -> Vector3:
	return actor.call("aim_point")


func _alive(actor: Node3D) -> bool:
	if actor == null or not is_instance_valid(actor):
		return false
	return actor.call("is_alive")


func _hostiles() -> Array:
	var out := []
	var player := get_tree().get_first_node_in_group("player")
	if _alive(player):
		out.append(player)
	if _hostile_all:
		for e in get_tree().get_nodes_in_group("enemy"):
			if e != self and _alive(e):
				out.append(e)
	return out


func _clear(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _perceive(dt: float) -> void:
	var eye := _eye()
	var fwd := _forward()
	var best: Node3D = null
	var best_score := INF
	var seen := {}
	for actor: Node3D in _hostiles():
		var aim := chest_of(actor)
		var to := aim - eye
		var d := to.length()
		if d > SIGHT:
			continue
		var known := actor == _target or actor == _attacker
		if fwd.dot(to / d) < (-0.55 if known or state != HOLD else FOV_COS):
			continue
		if not _clear(eye, aim):
			continue
		seen[actor] = true
		var need := NOTICE_ALERT if state != HOLD else NOTICE_CALM + d * NOTICE_PER_M
		_notice[actor] = float(_notice.get(actor, 0.0)) + dt
		if _notice[actor] < need and not known:
			continue
		var score := d - (10.0 if actor == _attacker else 0.0) - (5.0 if actor == _target else 0.0)
		if score < best_score:
			best_score = score
			best = actor
	for actor in _notice.keys():
		if not seen.has(actor):
			_notice.erase(actor)
	if best != null:
		if best != _target:
			_target = best
			_target_time = 0.0
			_shot_timer = randf_range(REACTION.x, REACTION.y) * (VS_SOLDIER if best is Enemy else 1.0)
			_burst_left = 0
		_target_visible = true
		_target_pos = best.global_position
		_lost = 0.0
		if state == HOLD or state == SEARCH:
			state = ENGAGE
	else:
		_target_visible = false
		if not _alive(_target):
			_target = null


func hear(at: Vector3, shooter: Node3D) -> void:
	if _dead or shooter == self:
		return
	var d := global_position.distance_to(at)
	if d < FEAR_RANGE:
		_fear = FEAR_TIME
	if d < PANIC:
		_hostile_all = true
	if d > HEAR_SHOT or _target_visible:
		return
	_look_yaw = _yaw_to(at)
	if d < INVESTIGATE and state == HOLD:
		state = SEARCH
		_go(at.lerp(global_position, clampf(5.0 / maxf(d, 0.1), 0.0, 1.0)))
		_lost = 0.0


func _physics_process(delta: float) -> void:
	if _dead:
		return
	fx.update(delta)
	_think -= delta
	if _think <= 0.0:
		_think += 1.0 / THINK_HZ
		_perceive(1.0 / THINK_HZ)
	_aim_bad = maxf(0.0, _aim_bad - delta * 0.08)
	_hit_clip = maxf(0.0, _hit_clip - delta)
	_fear = maxf(0.0, _fear - delta)
	if _target != null:
		_target_time += delta

	var want := Vector3.ZERO
	var face := _look_yaw
	match state:
		HOLD:
			_scan -= delta
			if _scan <= 0.0:
				_scan = randf_range(2.5, 5.0)
				_look_yaw = _yaw_to(_post) if global_position.distance_to(_post) > 1.5 \
					else _post_yaw + randf_range(-0.7, 0.7)
			if global_position.distance_to(_post) > 1.0:
				want = _step(_post, WALK_SPEED)
				face = _yaw_of(want)
		ENGAGE:
			want = _engage(delta)
			face = _yaw_to(_target_pos)
		COVER:
			want = _step(_goal, RUN_SPEED)
			face = _yaw_to(_target_pos) if _target_visible else _yaw_of(want)
			if want == Vector3.ZERO:
				_cover_wait -= delta
				if _cover_wait <= 0.0:
					state = ENGAGE if _target != null else SEARCH
					_go(_target_pos)
		SEARCH:
			want = _step(_goal, WALK_SPEED)
			face = _yaw_of(want) if want != Vector3.ZERO else _look_yaw
			_lost += delta
			if want == Vector3.ZERO and _lost > 3.0:
				state = HOLD
				_post = global_position
				_post_yaw = _look_yaw

	_turn(face, delta)
	velocity = want * (1.0 - 0.45 * _limp)
	if _hit_vel.length_squared() > 0.0001:
		velocity += _hit_vel
		_hit_vel = _hit_vel.lerp(Vector3.ZERO, 1.0 - exp(-7.0 * delta))
	velocity.y = 0.0 if is_on_floor() else velocity.y - 9.8 * delta
	move_and_slide()
	_animate(velocity.length())


func _engage(delta: float) -> Vector3:
	if not _alive(_target):
		_target = null
		state = SEARCH
		_go(_target_pos)
		return Vector3.ZERO
	if not _target_visible:
		_lost += delta
		_shot_timer = maxf(_shot_timer, randf_range(REACTION.x, REACTION.y) * 0.6)
		if _lost > 1.2:
			state = SEARCH
			_go(_target_pos)
		return Vector3.ZERO
	_engage_time += delta
	if _engage_time > 3.0 and randf() < delta * 0.5:
		_engage_time = 0.0
		if _seek_cover(_target):
			return Vector3.ZERO
	var aligned := absf(angle_difference(_yaw(), _yaw_to(_target_pos))) < 0.25
	if aligned:
		_shoot(delta)
	return Vector3.ZERO


func _seek_cover(threat: Node3D) -> bool:
	if threat == null or not nav_map.is_valid():
		return false
	var eye: Vector3 = chest_of(threat) + Vector3(0, 0.25, 0)
	var best := Vector3.INF
	var best_d := INF
	for k in 10:
		var ang := TAU * k / 10.0 + randf() * 0.3
		var r := randf_range(1.6, 4.5)
		var p := global_position + Vector3(cos(ang), 0, sin(ang)) * r
		p = NavigationServer3D.map_get_closest_point(nav_map, p)
		if p.distance_to(threat.global_position) < 3.0:
			continue
		if _clear(eye, p + Vector3(0, 1.3, 0)):
			continue
		var d := p.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = p
	if best == Vector3.INF:
		return false
	state = COVER
	_cover_wait = randf_range(1.0, 2.6)
	_go(best)
	return true


func _go(to: Vector3) -> void:
	if _goal.distance_to(to) > 0.4:
		_goal = to
		nav.target_position = to


func _step(to: Vector3, speed: float) -> Vector3:
	_go(to)
	if nav.is_navigation_finished():
		return Vector3.ZERO
	var next := nav.get_next_path_position()
	var dir := Vector3(next.x - global_position.x, 0.0, next.z - global_position.z)
	if dir.length() < 0.02:
		return Vector3.ZERO
	return dir.normalized() * speed


func _forward() -> Vector3:
	return Vector3(global_basis.z.x, 0.0, global_basis.z.z).normalized()


func _yaw() -> float:
	return atan2(global_basis.z.x, global_basis.z.z)


func _yaw_to(p: Vector3) -> float:
	return atan2(p.x - global_position.x, p.z - global_position.z)


func _yaw_of(v: Vector3) -> float:
	return _look_yaw if v.length_squared() < 0.0001 else atan2(v.x, v.z)


func _turn(want: float, delta: float) -> void:
	var step := clampf(angle_difference(_yaw(), want), -TURN_RATE * delta, TURN_RATE * delta)
	rotate_y(step)


func _animate(speed: float) -> void:
	if _hit_clip > 0.0:
		return
	var clip := CLIP_READY
	var scale := 1.0
	var engaged := state == ENGAGE or (state == COVER and _target_visible)
	if speed > 0.3:
		if speed > WALK_SPEED * 1.4:
			clip = CLIP_RUN
			scale = clampf(speed / RUN_SPEED, 0.8, 1.3)
		else:
			clip = CLIP_SNEAK
			scale = clampf(speed / WALK_SPEED, 0.7, 1.4)
	elif engaged:
		clip = CLIP_CROUCH_AIM if _fear > 0.0 else CLIP_AIM
	anim.speed_scale = scale
	var name: String = _clips[clip]
	if anim.current_animation != name:
		anim.play(name, 0.25)


func _shoot(delta: float) -> void:
	_shot_timer -= delta
	if _shot_timer > 0.0:
		return
	if _burst_left <= 0:
		_burst_left = randi_range(BURST.x, BURST.y)
	_burst_left -= 1
	_shot_timer = randf_range(SHOT_GAP.x, SHOT_GAP.y) if _burst_left > 0 \
		else randf_range(BURST_PAUSE.x, BURST_PAUSE.y)
	var from := _muzzle_world()
	var to := chest_of(_target)
	var aim := (to - from).normalized()
	var side := aim.cross(Vector3.UP).normalized()
	var up := side.cross(aim).normalized()
	var settle := clampf(_target_time / 1.2, 0.0, 1.0)
	var spread := lerpf(SPREAD_START, SPREAD_SETTLED, settle) * (1.0 + 2.5 * _aim_bad) \
		* (VS_SOLDIER if _target is Enemy else 1.0)
	var dir := (aim + side * randfn(0.0, spread) + up * randfn(0.0, spread)).normalized()
	Ballistics.fire(from, dir, MUZZLE_SPEED, self)
	muzzle.global_position = from
	muzzle.basis = Basis.looking_at(dir, Vector3.UP)
	fx.fire(muzzle, from, dir)
	GameAudio.play_3d("shot_enemy", from, -6.0, randf_range(0.94, 1.06))


func _muzzle_world() -> Vector3:
	var hand := _bone_world("Hand_R")
	var bore := chest_of(_target) - hand
	return hand + bore.normalized() * 0.22


func hit(point: Vector3, dir: Vector3, impulse: float, bone: String, shooter: Node3D = null) -> void:
	if _dead:
		return
	var zone: Array = ZONES.get(bone, ["chest", 40.0])
	var region: String = zone[0]
	_hp -= zone[1]
	_blood_at(point, dir, bone)
	_hostile_all = true
	_fear = FEAR_TIME
	if shooter != null and shooter != self and _alive(shooter):
		_attacker = shooter
		_look_yaw = _yaw_to(shooter.global_position)
		if not _target_visible:
			_target = shooter
			_target_pos = shooter.global_position
	react.kick(bone, point, dir, KICK.get(region, 20.0) * clampf(impulse / 2.6, 0.6, 1.4))
	if _hp <= 0.0:
		_die(bone, point, dir, impulse)
		return
	var b := global_basis.inverse() * dir.normalized()
	_hit_vel += Vector3(dir.x, 0.0, dir.z).normalized() * (0.9 if region == "chest" or region == "belly" else 0.4)
	match region:
		"leg":
			_limp = 1.0
		"arm":
			_aim_bad = 1.0
		"chest", "belly", "hips":
			anim.play(_clips[CLIP_HIT], 0.08)
			anim.seek(0.0, true)
			_hit_clip = 0.45
	_shot_timer = maxf(_shot_timer, 0.35 + absf(b.z) * 0.3)
	_burst_left = 0
	_target_time *= 0.4
	if state != COVER and randf() < 0.45:
		_seek_cover(shooter if shooter != null else _target)


func _die(bone: String, point: Vector3, dir: Vector3, impulse: float) -> void:
	_dead = true
	set_physics_process(false)
	var momentum := Vector3(velocity.x, 0.0, velocity.z) + _hit_vel
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	fx.timer = 0.0
	fx.update(0.0)
	_blood.amount_ratio = 1.0
	_blood.restart()
	react.active = false
	anim.pause()
	ragdoll.physical_bones_start_simulation()
	for pb: PhysicalBone3D in ragdoll.get_children():
		pb.linear_velocity = momentum + Vector3.DOWN * DEATH_SLUMP
	var push := dir.normalized() * clampf(impulse * 5.0, DEATH_PUSH.x, DEATH_PUSH.y)
	for pb: PhysicalBone3D in ragdoll.get_children():
		if pb.bone_name == bone:
			pb.apply_impulse(push, point - pb.global_position)
		elif pb.bone_name == "Hips":
			pb.apply_central_impulse(push * 0.55)
	_drop_gun(momentum + push * 0.04)
	_anchor_spot()
	get_tree().create_timer(1.4).timeout.connect(_bleed_out)
	killed.emit(self)


func _drop_gun(throw: Vector3) -> void:
	var gun := visual.find_child("Gun", true, false) as Node3D
	if gun == null or not gun.visible:
		return
	var spin := Vector3(randf_range(-9.0, 9.0), randf_range(-6.0, 6.0), randf_range(-9.0, 9.0))
	DroppedProp.spawn(get_tree().current_scene, gun, GUN_KG, throw + Vector3(0, 0.6, 0), spin, "mag_drop")
	gun.visible = false


func shove(point: Vector3, dir: Vector3, impulse: float, bone: String) -> void:
	for pb: PhysicalBone3D in ragdoll.get_children():
		if pb.bone_name == bone:
			pb.apply_impulse(dir.normalized() * clampf(impulse * 3.0, 2.0, 8.0), point - pb.global_position)


func _blood_at(point: Vector3, dir: Vector3, bone: String) -> void:
	_wound = point
	_blood.global_position = point
	_blood.global_basis = Basis.looking_at(dir.normalized(), Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT)
	_blood.amount_ratio = 0.45
	_blood.restart()
	ImpactFX.spawn_blood_spot(point, _blood_spot, dir)
	_anchor_spot()


func _anchor_spot() -> void:
	if not _blood_spot.visible:
		return
	var best: PhysicalBone3D = null
	var bd := INF
	for pb: PhysicalBone3D in ragdoll.get_children():
		var d := pb.global_position.distance_to(_wound)
		if d < bd:
			bd = d
			best = pb
	if best != null and _blood_spot.get_parent() != best:
		_blood_spot.reparent(best, true)


func _bleed_out() -> void:
	if not is_instance_valid(self):
		return
	var chest := _bone_world("Chest")
	var q := PhysicsRayQueryParameters3D.create(chest, chest + Vector3.DOWN * 1.5, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	_pool.top_level = true
	_pool.global_transform = Transform3D(Basis(Vector3.UP, randf() * TAU), hit.position)
	_pool.size = Vector3(0.2, 0.2, 0.2)
	_pool.modulate = Color(1, 1, 1, 0.0)
	_pool.visible = true
	var grow := _pool.create_tween()
	grow.tween_property(_pool, "size", Vector3(randf_range(0.8, 1.1), 0.3, randf_range(0.7, 1.0)), 9.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	grow.parallel().tween_property(_pool, "modulate:a", 0.95, 1.5)
