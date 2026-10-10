class_name Enemy
extends CharacterBody3D

signal killed(enemy: Node3D)
signal fired(from: Vector3, dir: Vector3)

const ACTOR_LAYER := 16
const HITBOX_LAYER := 8
const EYE_HEIGHT := 1.60
const NAV_RADIUS := 0.34
const TURN_RATE := 6.0
const MUZZLE_SPEED := 340.0
const WALK_CLIP_SPEED := 0.85
const RUN_CLIP_SPEED := 5.0
const WALK_STEP := 0.56
const RUN_STEP := 2.4
const RUN_FROM := 2.2
const SHOVE_PUSH := 3.0
const REACTION_BLEND_OUT := 0.25

const FACE_LIFT := Vector3(0.0, 0.09, 0.0)
const REACT_BONES := ["Hips", "Spine", "Chest", "Chest.001", "Neck", "Head",
	"UpperArm_L", "UpperArm_R", "ForeArm_L", "ForeArm_R", "Thigh_L", "Thigh_R", "Shin_L", "Shin_R"]

var hitbox_rids: Array[RID] = []
var nav_map: RID
var model: EnemyModel
var ragdoll: PhysicalBoneSimulator3D
var react: HitReact
var brain: EnemyBrain
var blood: EnemyBlood
var fx: WeaponFX
var muzzle: Node3D

var team := 1
var weapon_id := "glock"
var rifle: RifleWeapon = null
var protection := 1.0
var last_region := ""
var last_by_player := false
var wounds := EnemyWounds.new()
var _dead := false
var _wakes := 0
var _last_hit := {}
var _hit_vel := Vector3.ZERO
var _hit_clip := 0.0
var _stride := 0.0
var _contact: MeshInstance3D


func _ready() -> void:
	if not _assemble(1 | ACTOR_LAYER | Player.LAYER, team):
		return
	brain = EnemyBrain.new()
	brain.name = "Brain"
	brain.nav_map = nav_map
	add_child(brain)
	brain.setup(self)


func _assemble(mask: int, dress_team: int) -> bool:
	collision_layer = ACTOR_LAYER
	collision_mask = mask
	add_to_group("enemy")
	add_to_group("combatant")
	_build_body()
	if not _build_visual():
		return false
	model.dress(dress_team)
	var contact := ContactBlob.new()
	contact.add(0.0, 0.0, 0.22, 0.18)
	_contact = contact.build()
	add_child(_contact)
	set_weapon(weapon_id)
	return true


func set_weapon(id: String) -> void:
	EnemyRifle.set_weapon(self, id)


func connect_nav() -> void:
	if brain != null:
		brain.nav_map = nav_map
		brain.connect_nav()


func is_alive() -> bool:
	return not _dead


func face_point() -> Vector3:
	if _dead:
		var head := ragdoll.get_node_or_null("PB_Head") as Node3D
		if head != null:
			return head.global_transform * FACE_LIFT
	return model.bone_point("Head", FACE_LIFT)


func aim_point() -> Vector3:
	return model.bone_world("Chest.001")


func eye() -> Vector3:
	return global_position + Vector3(0, EYE_HEIGHT, 0)


func forward() -> Vector3:
	return Vector3(global_basis.z.x, 0.0, global_basis.z.z).normalized()


func yaw() -> float:
	return atan2(global_basis.z.x, global_basis.z.z)


func hear(at: Vector3, shooter: Node3D) -> void:
	if not _dead and brain != null:
		brain.hear(at, shooter)


func hear_step(at: Vector3, source: Player, reach: float) -> void:
	if _dead or brain == null or source.team == team or brain.engaged():
		return
	var audible := reach * (1.5 if brain.alerted() else 1.0) * (1.0 if EnemySenses.clear(self, eye(), at + Vector3.UP) else 0.7)
	if global_position.distance_to(at) < audible:
		brain.hunt(at)


func fire_at(target: Vector3, spread: float) -> void:
	protection = 0.0
	var hand := model.bone_world("Hand_R")
	var from := hand + (target - hand).normalized() * 0.22
	if not EnemySenses.clear(self, eye(), from + (from - eye()).normalized() * 0.05):
		from = eye()
	var aim := (target - from).normalized()
	var side := aim.cross(Vector3.UP).normalized()
	var up := side.cross(aim).normalized()
	var dir := (aim + side * randfn(0.0, spread) + up * randfn(0.0, spread)).normalized()
	fired.emit(from, dir)
	var camera := get_viewport().get_camera_3d()
	fx.world_lighting = camera != null and (camera.global_position.distance_to(from) < 14.0 \
			or camera.is_position_in_frustum(from) and EnemySenses.clear(self, camera.global_position, from))
	shoot(from, dir, EnemyRifle.SPEED if weapon_id == "rifle" else MUZZLE_SPEED)


func shoot(from: Vector3, dir: Vector3, speed: float, harmless := false) -> void:
	Ballistics.fire(from, dir, speed, self, harmless)
	muzzle.global_position = from
	muzzle.basis = Basis.looking_at(dir, Vector3.UP)
	fx.fire(muzzle, dir)
	GameAudio.enemy_shot(from)


func hit(point: Vector3, dir: Vector3, impulse: float, bone: String, shooter: Node3D = null) -> void:
	if _dead or protection > 0.0 or (is_instance_valid(shooter) and shooter.team == team):
		return
	var region := wounds.take(bone, impulse)
	last_region = region
	last_by_player = shooter is Player
	_flesh(point, dir, bone, region, impulse)
	brain.alarm(shooter)
	if wounds.dead():
		_die(bone, point, dir, impulse)
		return
	_last_hit = {"bone": bone, "point": point, "dir": dir, "imp": impulse}
	_hit_vel += Vector3(dir.x, 0.0, dir.z).normalized() * (0.4 if region == "arm" else 1.1)
	var behind := (global_basis.inverse() * dir.normalized()).z > 0.3
	if region != "head":
		_hit_clip = model.restart(wounds.reaction(bone, behind), 0.06) - REACTION_BLEND_OUT
		wounds.stagger = maxf(wounds.stagger, _hit_clip)
	brain.flinch(region, absf((global_basis.inverse() * dir.normalized()).z), shooter)


func _flesh(point: Vector3, dir: Vector3, bone: String, region: String, impulse: float) -> void:
	GameAudio.play_3d("flesh", point, 0.0, randf_range(0.9, 1.08))
	blood.wound(point, dir, ragdoll.get_children())
	react.kick(bone, point, dir, EnemyWounds.kick_for(region, impulse))


func shove(point: Vector3, dir: Vector3, impulse: float, bone: String) -> void:
	if _dead:
		EnemyRagdoll.wake(ragdoll)
		_rest_later()
	for pb: PhysicalBone3D in ragdoll.get_children():
		if pb.bone_name == bone:
			pb.apply_impulse(dir.normalized() * Impulse.push(impulse, SHOVE_PUSH, 2.0, 8.0), point - pb.global_position)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	protection = maxf(0.0, protection - delta)
	fx.update(delta)
	_hit_clip = maxf(0.0, _hit_clip - delta)
	wounds.tick(delta)
	if wounds.dead():
		_die(_last_hit["bone"], _last_hit["point"], _last_hit["dir"], _last_hit["imp"])
		return
	brain.tick(delta)
	var step := clampf(angle_difference(yaw(), brain.face), -TURN_RATE * delta, TURN_RATE * delta)
	rotate_y(step)
	velocity = brain.want * wounds.pace()
	if _hit_vel.length_squared() > 0.0001:
		velocity += _hit_vel
		_hit_vel = _hit_vel.lerp(Vector3.ZERO, 1.0 - exp(-7.0 * delta))
	velocity.y = 0.0 if is_on_floor() else velocity.y - 9.8 * delta
	move_and_slide()
	var ground := Vector2(velocity.x, velocity.z).length()
	_strides(delta, ground)
	_animate(velocity.length())


func _strides(delta: float, ground: float) -> void:
	_stride += ground * delta
	if _stride <= (RUN_STEP if ground > RUN_FROM else WALK_STEP):
		return
	_stride = 0.0
	GameAudio.footstep(global_position, get_world_3d(), 2.0 if ground > RUN_FROM else -3.0, true)


func _animate(speed: float) -> void:
	if _hit_clip > 0.0:
		return
	if speed > RUN_FROM:
		model.play("Run", 0.25, speed / RUN_CLIP_SPEED)
	elif speed > 0.3:
		model.play("AimWalk" if brain.alerted() else "Walk", 0.25, minf(speed / WALK_CLIP_SPEED, 1.8))
	elif wounds.wounded() or brain.engaged() and brain.fear > 0.0:
		model.play("CrouchAim", 0.25)
	elif brain.alerted():
		model.play("Aim", 0.25)
	else:
		model.play("Ready", 0.3)


func _die(bone: String, point: Vector3, dir: Vector3, impulse: float) -> void:
	_dead = true
	set_physics_process(false)
	var momentum := Vector3(velocity.x, 0.0, velocity.z) + _hit_vel
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	fx.timer = 0.0
	fx.update(0.0)
	blood.burst()
	react.active = false
	model.anim.pause()
	ragdoll.physical_bones_start_simulation()
	var push := EnemyRagdoll.topple(ragdoll, bone, last_region, point, dir, impulse, momentum)
	EnemyRagdoll.thud_on_landing(ragdoll)
	EnemyRifle.drop(self, momentum + push * 0.04)
	blood.anchor(ragdoll.get_children())
	get_tree().create_timer(1.4).timeout.connect(_bleed_out)
	_rest_later()
	killed.emit(self)


func _rest_later() -> void:
	_wakes += 1
	var wake := _wakes
	get_tree().create_timer(EnemyRagdoll.REST_AFTER).timeout.connect(func() -> void:
		if wake == _wakes:
			EnemyRagdoll.rest(ragdoll))


func _bleed_out() -> void:
	blood.pool_under(model.bone_world("Chest"))


func _build_body() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.28
	shape.height = 1.78
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0, 0.89, 0)
	add_child(col)


func _build_visual() -> bool:
	model = EnemyModel.new()
	model.name = "Visual"
	add_child(model)
	if not model.load_asset():
		queue_free()
		return false
	react = HitReact.new()
	react.name = "HitReact"
	model.skeleton.add_child(react)
	react.setup(REACT_BONES)
	ragdoll = EnemyRagdoll.build(model.skeleton, self, HITBOX_LAYER)
	for pb: PhysicalBone3D in ragdoll.get_children():
		hitbox_rids.append(pb.get_rid())
	blood = EnemyBlood.new()
	blood.name = "Blood"
	add_child(blood)
	muzzle = Node3D.new()
	muzzle.name = "Muzzle"
	add_child(muzzle)
	fx = WeaponFX.new()
	fx.name = "WeaponFX"
	muzzle.add_child(fx)
	fx.build(true)
	fx.world_flash.omni_range = 4.5
	return true
