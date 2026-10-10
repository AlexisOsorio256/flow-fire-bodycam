class_name Player
extends CharacterBody3D

signal died

const LAYER := 1 << 1
const MOUSE_SENS := 0.00175
const WALK_SPEED := 4.0
const SPRINT_SPEED := 6.3
const CROUCH_SPEED := 2.0
const GRAVITY := 9.8
const FALL_GRAVITY := 15.0
const FALL_TERMINAL := 55.0
const JUMP_SPEED := 4.5
const CROUCH_JUMP := 0.85
const AIR_CONTROL := 0.35
const COYOTE := 0.12
const LAND_REF := 7.0
const STEP_LENGTH := 1.45
const BOB_SIDE := 0.0042
const BOB_RISE := 0.0062
const WEAPON_RIG_POS := Vector3(-0.070, -0.150, -0.265)
const HP := 100.0
const PITCH_LIMIT := 1.38
const HEAD_FROM := 0.15
const CHEST_FROM := 0.55
const BELLY_FROM := 0.95
const DAMAGE := {"head": 100.0, "chest": 55.0, "belly": 50.0, "arm": 20.0, "legs": 20.0}
const LETHAL_ZONES := ["head", "chest"]
const PUNCH_REF := 2.5
const ADRENALINE_CUT := 0.1
const ADRENALINE_FADE := 4.0
const REGEN_DELAY := 3.0
const REGEN_RATE := 28.0

var _collider: CollisionShape3D
var camera: Camera3D
var cam := BodyCam.new()
var weapon
var loadout: Loadout
var team := 0
var protection := 1.5
var health := HP
var mouse_captured := false
var paused := false

var yaw := 0.0
var pitch := 0.0
var yaw_target := 0.0
var pitch_target := 0.0
var look_delta := Vector2.ZERO
var sprinting := false
var crouching := false
var airborne := false
var jump_held := false
var current_speed := 0.0

var _coyote := 0.0
var _fall := 0.0

var _strafe_input := 0.0
var _local_move := Vector2.ZERO
var since_hit := 0.0
var hit_flash := 0.0
var under_fire := 0.0
var _hobble := 0.0
var _adrenaline := 0.0
var _audio: PlayerAudio
var touch: TouchControls
var _ring := 0.0
var _tinnitus_player: AudioStreamPlayer
var _dead := false
var last_zone := ""
var last_dir := Vector3.FORWARD

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	collision_layer = LAYER
	collision_mask = 1 | Enemy.ACTOR_LAYER
	add_to_group("player")
	add_to_group("combatant")
	var shape := CapsuleShape3D.new()
	shape.radius = 0.34
	shape.height = 1.7
	_collider = CollisionShape3D.new()
	_collider.shape = shape
	_collider.position = Vector3(0, 0.85, 0)
	add_child(_collider)
	_build_camera()
	_build_weapon()
	_audio = PlayerAudio.new()
	add_child(_audio)

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.position = Vector3(0, BodyCam.STAND_Y, 0)
	camera.fov = BodyCam.FOV
	camera.near = 0.05
	camera.far = 150.0
	camera.current = true
	camera.top_level = true
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(camera)

func _build_weapon() -> void:
	loadout = Loadout.new()
	loadout.name = "WeaponRig"
	loadout.position = WEAPON_RIG_POS
	camera.add_child(loadout)
	loadout.build(self, camera)
	weapon = loadout.weapons[loadout.current]
	loadout.fired.connect(func():
		protection = 0.0
		cam.kick_shot(weapon.aim_blend, weapon.spec.cam_kick))

func _input(event: InputEvent) -> void:
	if _dead or paused:
		return
	if mouse_captured and event.is_action_pressed("pause"):
		release_mouse()
		get_viewport().set_input_as_handled()
	elif mouse_captured and event.is_action_pressed("reload"):
		reload()
	elif mouse_captured and event.is_action_pressed("inspect"):
		weapon.inspect_weapon()
	elif event.is_action("fire"):
		if not mouse_captured:
			if event.is_pressed():
				capture_mouse()
		elif event.is_pressed():
			weapon.press_trigger()
		else:
			weapon.release_trigger()
	elif mouse_captured and event.is_action("aim"):
		weapon.set_aim(event.is_pressed())
	if event is InputEventMouseMotion and mouse_captured:
		var sens := MOUSE_SENS * Settings.sensitivity * (Settings.aim_sensitivity if weapon.aim else 1.0)
		yaw_target -= event.relative.x * sens
		pitch_target = clampf(pitch_target - event.relative.y * sens, -PITCH_LIMIT, PITCH_LIMIT)
		look_delta = event.relative.clamp(Vector2(-12.0, -12.0), Vector2(12.0, 12.0))

func reload() -> void:
	weapon.start_reload(weapon.mag_size)


func capture_mouse() -> void:
	get_tree().paused = false
	paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	mouse_captured = true

func release_mouse() -> void:
	get_tree().paused = not Net.active()
	paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	mouse_captured = false
	weapon.release_trigger()
	weapon.set_aim(false)

func _physics_process(delta: float) -> void:
	if _dead or get_tree().paused:
		return
	var height := cam.cam_y + 0.08
	if absf((_collider.shape as CapsuleShape3D).height - height) > 0.001:
		(_collider.shape as CapsuleShape3D).height = height
		_collider.position.y = height * 0.5
	var stick := touch.move if touch != null else Vector2.ZERO
	var input_x := clampf(Input.get_axis("move_left", "move_right") + stick.x, -1.0, 1.0)
	var input_z := clampf(Input.get_axis("move_back", "move_forward") + stick.y, -1.0, 1.0)
	_strafe_input = input_x
	crouching = Input.is_action_pressed("crouch") or (touch != null and touch.crouch)
	sprinting = (Input.is_action_pressed("sprint") or (touch != null and touch.sprinting())) and input_z > 0.0 and not crouching
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var wish := right * input_x + forward * input_z
	if wish.length_squared() > 1.0:
		wish = wish.normalized()
	var speed := (CROUCH_SPEED if crouching else SPRINT_SPEED if sprinting else WALK_SPEED) * (1.0 - _hobble * 0.55)
	speed *= weapon.spec.move_mult
	if input_z < 0.0:
		speed *= 0.78
	elif input_x != 0.0:
		speed *= 0.9
	var target := wish * speed
	var ground := is_on_floor()
	var accel := (18.0 if wish.length_squared() > 0.01 else 22.0) * (1.0 if ground else AIR_CONTROL)
	var blend := 1.0 - exp(-accel * delta)
	velocity.x = lerpf(velocity.x, target.x, blend)
	velocity.z = lerpf(velocity.z, target.z, blend)
	_coyote = COYOTE if ground else maxf(0.0, _coyote - delta)
	var wants_jump := jump_held or Input.is_action_pressed("jump")
	if wants_jump and _coyote > 0.0:
		velocity.y = JUMP_SPEED * (CROUCH_JUMP if crouching else 1.0)
		_coyote = 0.0
		_fall = 0.0
		GameAudio.play_2d("cloth", -5.0, randf_range(0.92, 1.05))
	elif ground:
		velocity.y = -0.5
	else:
		velocity.y = maxf(velocity.y - (FALL_GRAVITY if velocity.y < 0.0 else GRAVITY) * delta, -FALL_TERMINAL)
	move_and_slide()
	airborne = not is_on_floor()
	if airborne:
		_fall = maxf(_fall, -velocity.y)
	elif not ground:
		_land()
	weapon.player_velocity = velocity
	current_speed = Vector2(velocity.x, velocity.z).length()
	_local_move = Vector2(velocity.dot(right), velocity.dot(forward)) / WALK_SPEED
	_audio.footsteps(self, delta)

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	since_hit += delta
	hit_flash = maxf(0.0, hit_flash - delta * 2.4)
	under_fire = maxf(0.0, under_fire - delta * 1.1)
	protection = maxf(0.0, protection - delta)
	_hobble = maxf(0.0, _hobble - delta * 0.8)
	_adrenaline = maxf(0.0, _adrenaline - delta / ADRENALINE_FADE)
	_ring = maxf(0.0, _ring - delta * 0.5)
	var hurt := 1.0 - health / HP
	var danger := 1.0 if _dead else clampf((hurt - 0.35) / 0.5, 0.0, 1.0)
	_audio.update(danger, _dead, _adrenaline, _ring)
	if not _dead and since_hit > REGEN_DELAY and health < HP:
		health = minf(HP, health + REGEN_RATE * delta)
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		mouse_captured = false
	var follow := 1.0 - exp(-26.0 * delta)
	yaw += (yaw_target - yaw) * follow
	pitch = clampf(pitch + (pitch_target - pitch) * follow, -1.45, 1.45)
	look_delta = look_delta.lerp(Vector2.ZERO, 1.0 - exp(-20.0 * delta))
	if _dead:
		return
	camera.fov = lerpf(camera.fov, cam.fov_for(weapon.aim_blend, sprinting, weapon.spec.aim_fov), 1.0 - exp(-7.0 * delta))
	camera.global_transform = cam.update(delta, get_global_transform_interpolated().origin, velocity,
		Vector2(yaw, pitch), _strafe_input, yaw_target - yaw, crouching, weapon.aim_blend, _audio.bob, airborne)
	weapon.set_motion(current_speed, _local_move, look_delta, _audio.step_phase, velocity.y)
	weapon.set_sprint(sprinting)


func _land() -> void:
	var punch := clampf(_fall / LAND_REF, 0.0, 1.4)
	_fall = 0.0
	if punch < 0.12:
		return
	cam.kick_land(punch)
	weapon.recoil.kick_land(punch)
	GameAudio.footstep(global_position, get_world_3d(), 2.0, false)
	get_tree().call_group("enemy", "hear_step", global_position, self, 9.0 * punch)
	_hobble = maxf(_hobble, 0.18 * punch)

func is_alive() -> bool:
	return not _dead


func hurt() -> float:
	return clampf((1.0 - health / HP - 0.25) / 0.55, 0.0, 1.0)


func suppress(strength := 1.0) -> void:
	if _dead:
		return
	under_fire = maxf(under_fire, strength)
	cam.kick_suppress()

func aim_point() -> Vector3:
	return global_position + Vector3(0.0, cam.cam_y - 0.45, 0.0)

func hit(point: Vector3, dir: Vector3, impulse: float, _shooter: Node3D = null) -> void:
	if is_instance_valid(_shooter) and _shooter.team == team:
		return
	var h := point.y - global_position.y
	var scale := cam.cam_y / BodyCam.STAND_Y
	var zone := "head" if h > cam.cam_y - HEAD_FROM else "chest" if h > cam.cam_y - CHEST_FROM * scale \
		else "belly" if h > BELLY_FROM * scale else "legs"
	take(zone, dir, impulse)


func take(zone: String, dir: Vector3, impulse: float) -> void:
	if _dead or protection > 0.0:
		return
	var dmg: float = DAMAGE.get(zone, DAMAGE["chest"]) * (1.0 if zone == "head" else 1.0 - ADRENALINE_CUT * _adrenaline) * EnemyWounds.power(impulse)
	if Impulse.lethal(impulse) and zone in LETHAL_ZONES:
		dmg = HP
	health -= dmg
	last_zone = zone
	last_dir = dir
	_adrenaline = 1.0
	since_hit = 0.0
	var punch := Impulse.scale(impulse, PUNCH_REF, 0.5, 1.4)
	var side := (camera.global_basis.inverse() * dir.normalized()).x
	cam.kick_hit(zone if zone == "head" or zone == "legs" else "torso", side, punch)
	weapon.recoil.kick_hit(side, punch)
	_hobble = maxf(_hobble, 1.0 if zone == "legs" else 0.45)
	hit_flash = clampf(0.55 + 0.45 * punch, 0.0, 1.0)
	GameAudio.play_2d("flesh", 2.0, randf_range(0.9, 1.05))
	GameAudio.play_2d("hit_thump", 0.0, randf_range(0.9, 1.1))
	if zone == "head" or zone == "chest":
		_ring = 0.8
		_stop_tinnitus()
		_tinnitus_player = GameAudio.play_2d("tinnitus", 0.0, randf_range(0.97, 1.03))
	_audio.hit(health <= 0.0)
	if health <= 0.0:
		_die(zone, dir)

func _die(zone: String, dir: Vector3) -> void:
	_dead = true
	last_zone = zone
	last_dir = dir
	health = 0.0
	collision_layer = 0
	collision_mask = 0
	remove_from_group("player")
	remove_from_group("combatant")
	_stop_tinnitus()
	if _audio != null:
		_audio.stop()
	weapon.release_trigger()
	weapon.set_aim(false)
	PlayerDeath.drop_gun(self, weapon, dir)
	PlayerDeath.fall(self, camera, zone, dir)
	died.emit()

func _stop_tinnitus() -> void:
	if is_instance_valid(_tinnitus_player):
		_tinnitus_player.stop()
		_tinnitus_player.queue_free()
	_tinnitus_player = null

func _exit_tree() -> void:
	_stop_tinnitus()
	if _audio != null:
		_audio.stop()
