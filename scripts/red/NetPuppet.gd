class_name NetPuppet
extends Enemy

const FOLLOW := 14.0
const SNAP := 3.0
const ZONE_OF := {"head": "head", "chest": "chest", "belly": "belly", "hips": "belly", "arm": "arm", "leg": "legs"}
const BONE_OF := {"head": "Head", "chest": "Chest.001", "belly": "Spine", "arm": "UpperArm_R", "legs": "Thigh_L"}
const REGION_OF := {"head": "head", "chest": "chest", "belly": "belly", "arm": "arm", "legs": "leg"}
const RIFLE_SPEED := 900.0

var peer := 0
var ally := false
var weapon_id := "glock"
var _goal := Vector3.ZERO
var _goal_yaw := 0.0
var _crouch := false
var _speed := 0.0
var _last_at := 0.0
var _rifle: RifleWeapon = null


func _ready() -> void:
	collision_layer = ACTOR_LAYER
	collision_mask = 0
	add_to_group("enemy")
	add_to_group("combatant")
	_build_body()
	if not _build_visual():
		return
	model.dress(0 if ally else 1)
	protection = 0.0
	_goal = global_position
	_goal_yaw = rotation.y
	var contact := ContactBlob.new()
	contact.add(0.0, 0.0, 0.22, 0.18)
	_contact = contact.build()
	add_child(_contact)
	set_weapon(weapon_id)


func set_weapon(id: String) -> void:
	weapon_id = id
	if model == null:
		return
	var pistol := model.find_child("Gun", true, false) as Node3D
	if id == "rifle":
		if pistol != null:
			pistol.visible = false
		if _rifle == null:
			var w := RifleWeapon.new()
			w.name = "Rifle3P"
			if not w.build():
				w.queue_free()
				if pistol != null:
					pistol.visible = true
				weapon_id = "glock"
				return
			var parent := pistol.get_parent() if pistol != null else model
			parent.add_child(w)
			if pistol != null:
				w.transform = pistol.transform
			for mi in w.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).layers = EnemyModel.LAYER_BIT
			_rifle = w
		if _rifle != null:
			_rifle.visible = true
	else:
		if pistol != null:
			pistol.visible = true
		if _rifle != null:
			_rifle.visible = false


func follow(pos: Vector3, player_yaw: float, crouch: bool) -> void:
	var now := Time.get_ticks_msec() * 0.001
	var gap := now - _last_at
	if gap > 0.0 and gap < 0.5:
		_speed = lerpf(_speed, Vector2(pos.x - _goal.x, pos.z - _goal.z).length() / maxf(gap, 0.02), 0.5)
	_last_at = now
	if pos.distance_to(global_position) > SNAP:
		global_position = pos
	_goal = pos
	_goal_yaw = player_yaw + PI
	_crouch = crouch


func hear(_at: Vector3, _shooter: Node3D) -> void:
	pass


func hear_step(_at: Vector3, _source: Player, _reach: float) -> void:
	pass


func hit(point: Vector3, dir: Vector3, impulse: float, bone: String, shooter: Node3D = null) -> void:
	if _dead or not shooter is Player:
		return
	var region: String = EnemyWounds.ZONES.get(bone, ["chest", 0.0])[0]
	GameAudio.play_3d("flesh", point, 0.0, randf_range(0.9, 1.08))
	blood.wound(point, dir, ragdoll.get_children())
	react.kick(bone, point, dir, EnemyWounds.KICK.get(region, 20.0))
	Net.send_hit(peer, ZONE_OF.get(region, "chest"), dir, impulse)


func show_shot(dir: Vector3) -> void:
	if _dead:
		return
	var from := model.bone_world("Hand_R") + dir * 0.22
	var speed := MUZZLE_SPEED
	if weapon_id == "rifle" and _rifle != null and is_instance_valid(_rifle.muzzle):
		from = _rifle.muzzle.global_position
		speed = RIFLE_SPEED
	Ballistics.fire(from, dir, speed, self, true)
	fx.world_lighting = true
	muzzle.global_position = from
	muzzle.basis = Basis.looking_at(dir, Vector3.UP)
	fx.fire(muzzle, from, dir)
	GameAudio.enemy_shot(from)


func fall(zone: String, dir: Vector3) -> void:
	if _dead:
		return
	var bone: String = BONE_OF.get(zone, "Chest.001")
	last_region = REGION_OF.get(zone, "chest")
	_die(bone, model.bone_world(bone), dir.normalized(), 2.6)


func _drop_gun(throw: Vector3) -> void:
	if weapon_id == "rifle" and _rifle != null and _rifle.visible:
		var spin := Vector3(randf_range(-9.0, 9.0), randf_range(-6.0, 6.0), randf_range(-9.0, 9.0))
		DroppedProp.spawn(get_tree().current_scene, _rifle, 3.2, throw + Vector3(0, 0.6, 0), spin, "mag_drop", 24.0)
		_rifle.visible = false
		var pistol := model.find_child("Gun", true, false) as Node3D
		if pistol != null:
			pistol.visible = false
		return
	super(throw)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	fx.update(delta)
	var blend := 1.0 - exp(-FOLLOW * delta)
	global_position = global_position.lerp(_goal, blend)
	rotation.y = lerp_angle(rotation.y, _goal_yaw, blend)
	_stride += _speed * delta
	if _stride > (RUN_STEP if _speed > RUN_FROM else WALK_STEP):
		_stride = 0.0
		GameAudio.footstep(global_position, get_world_3d(), 2.0 if _speed > RUN_FROM else -3.0, true)
	if _crouch:
		model.play("CrouchAim", 0.25)
	elif _speed > RUN_FROM:
		model.play("Run", 0.25, _speed / RUN_CLIP_SPEED)
	elif _speed > 0.3:
		model.play("AimWalk", 0.25, minf(_speed / WALK_CLIP_SPEED, 1.8))
	else:
		model.play("Aim", 0.25)
