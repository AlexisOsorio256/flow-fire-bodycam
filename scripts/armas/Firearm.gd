class_name Firearm
extends Node3D
signal shot_fired
signal mag_seated
signal slide_batteried

const MAG_FALL_SPEED := 2.6
const MAG_LIFETIME := 20.0

var spec := WeaponSpec.glock()

var camera: Camera3D
var shooter: Node3D
var viewmodel: Viewmodel
var recoil: WeaponRecoil
var fx: WeaponFX
var slide := WeaponAction.new()
var aimer := WeaponAim.new()
var sequences: WeaponSequence

var mag_size := 15
var mag := 15
var chamber := 1
var pending_mag_rounds := 0
var trigger_held := false
var trigger_ready := true
var _trigger_buffer := 0.0
var _shot_delay := 0.0
var trigger_visual := 0.0

var reloading := false
var inspecting := false
var drawing := false

var aim := false
var sprinting := false
var aim_blend := 0.0
var sprint_blend := 0.0
var player_speed := 0.0
var step_phase := 0.0
var look_delta := Vector2.ZERO
var player_velocity := Vector3.ZERO
var shot_pulse := 0.0
var _last_local_move := Vector2.ZERO

func _ready() -> void:
	recoil = WeaponRecoil.new()
	viewmodel = Viewmodel.new()
	viewmodel.name = "Viewmodel"
	viewmodel.recoil = recoil
	add_child(viewmodel)
	if not viewmodel.mount(spec):
		push_error("Glock no puede arrancar sin sus assets canonicos")
		process_mode = Node.PROCESS_MODE_DISABLED
		get_tree().quit(1)
		return
	mag_size = viewmodel.weapon.capacity
	mag = mag_size
	sequences = WeaponSequence.new(self)
	slide.travel = viewmodel.weapon.slide_offset
	slide.extracted.connect(_spawn_shell)
	slide.reached_rear.connect(sequences.say.bind("action_rear", 0.0, 0.98, 1.06))
	recoil.configure(spec.recoil)
	slide.batteried.connect(_on_battery)
	slide.fed.connect(_on_fed)
	slide.locked_open.connect(_on_locked_open)
	viewmodel.arms.skeleton.skeleton_updated.connect(_sync_parts)
	fx = WeaponFX.new()
	fx.name = "WeaponFX"
	viewmodel.muzzle.add_child(fx)
	fx.build()
	aimer.hip_scale = spec.hip_spread
	equip()

func _sync_parts() -> void:
	var by_hand := (inspecting or drawing) and not slide.locked
	var shown := viewmodel.arms.animated_slide() if by_hand else slide.pos
	viewmodel.weapon.by_hand = by_hand
	viewmodel.weapon.set_slide(shown / maxf(slide.travel, 0.0001))
	viewmodel.weapon.set_trigger(trigger_visual)
	viewmodel.weapon.set_chamber_visible(chamber > 0 and shown > slide.travel * 0.15)
	viewmodel.weapon.mag_round.visible = mag > 0 or (pending_mag_rounds > 0 and viewmodel.arms.mag_in_hand)

func setup(cam: Camera3D) -> void:
	camera = cam
	viewmodel.setup(cam)

func _process(delta: float) -> void:
	sprint_blend += ((1.0 if sprinting else 0.0) - sprint_blend) * (1.0 - exp(-5.5 * delta))
	aim_blend += ((1.0 if aim else 0.0) * (1.0 - sprint_blend) - aim_blend) * (1.0 - exp(-10.5 * delta))
	_update_trigger(delta)
	slide.step(delta, not inspecting, chamber <= 0 and mag > 0, mag <= 0 and chamber <= 0 and not reloading)
	sequences.step(delta)
	recoil.update(delta)
	aimer.update(delta)
	viewmodel.set_pose_inputs(aim_blend, sprint_blend, player_speed, look_delta, _last_local_move, step_phase)
	viewmodel.update(delta)
	viewmodel.arms.trigger_pose.influence = trigger_visual
	shot_pulse = maxf(0.0, shot_pulse - delta * 8.0)
	fx.update(delta)

func set_aim(value: bool) -> void:
	aim = value and not reloading and not inspecting and not drawing

func set_sprint(value: bool) -> void:
	sprinting = value

func set_motion(speed: float, local_move: Vector2, look: Vector2, phase := 0.0) -> void:
	player_speed = speed
	look_delta = look
	_last_local_move = local_move
	step_phase = phase

func press_trigger() -> void:
	if not trigger_held:
		_trigger_buffer = 0.16
	trigger_held = true

func release_trigger() -> void:
	if trigger_held and not trigger_ready:
		GameAudio.play_2d("trigger_reset", 0.0, randf_range(0.97, 1.05))
	trigger_held = false
	trigger_ready = true

func can_reload() -> bool:
	return not reloading and not inspecting and not drawing and (chamber <= 0 or mag < mag_size)

func start_reload(incoming_rounds: int = 0) -> bool:
	return sequences.start_reload(incoming_rounds)

func inspect_weapon() -> void:
	sequences.start_inspect()

func equip() -> void:
	sequences.equip()

func _can_fire() -> bool:
	return (not reloading or _can_interrupt()) and not drawing and chamber > 0 and slide.at_rest() and _shot_delay <= 0.0


func _can_interrupt() -> bool:
	return spec.shells and reloading and chamber > 0

func _update_trigger(delta: float) -> void:
	trigger_visual += ((1.0 if trigger_held else 0.0) - trigger_visual) * (1.0 - exp(-28.0 * delta))
	_shot_delay = maxf(0.0, _shot_delay - delta)
	if _trigger_buffer <= 0.0:
		return
	_trigger_buffer = maxf(0.0, _trigger_buffer - delta)
	if _can_fire():
		_fire()
	elif not reloading and not drawing and chamber <= 0:
		_trigger_buffer = 0.0
		trigger_ready = false
		GameAudio.play_2d("empty")

func _fire() -> void:
	if inspecting:
		sequences.cancel_inspect()
	if reloading:
		sequences.cancel_reload()
	chamber -= 1
	trigger_ready = false
	_trigger_buffer = 0.0
	_shot_delay = spec.fire_delay
	slide.cycle()
	viewmodel.arms.play_clip(FpArms.CLIP_FIRE, true)
	shot_pulse = 1.0
	recoil.kick_shot()
	GameAudio.play_shot(spec.shot_streams)
	var origin := aimer.origin_of(camera, viewmodel.muzzle.global_position)
	var target := aimer.aim_point(camera)
	for i in spec.pellets:
		var bore := aimer.bore(target, origin, aim_blend, player_speed)
		Ballistics.fire(origin, bore, spec.muzzle_speed, shooter, false, i == 0)
		if i == 0:
			fx.fire(viewmodel.muzzle, origin, bore)
	shot_fired.emit()

func _on_battery() -> void:
	recoil.kick_slide_battery()
	slide_batteried.emit()
	sequences.say("action_battery", 0.0, 0.97, 1.03)

func _on_fed() -> void:
	mag -= 1
	chamber = 1

func _on_locked_open() -> void:
	recoil.kick_slide_lock()
	ImpactFX.spawn_barrel_smoke(viewmodel.ejection_port)
	ImpactFX.spawn_barrel_smoke(viewmodel.muzzle)

func _spawn_shell() -> void:
	var port_tf: Transform3D = viewmodel.ejection_port.global_transform
	Shell.spawn(get_tree().current_scene, port_tf, slide.vel, player_velocity, spec.caliber)
	var vent_dir: Vector3 = (port_tf.basis.x * 0.8 + port_tf.basis.y * 0.4 - port_tf.basis.z * 0.1).normalized()
	ImpactFX.spawn_ejection_smoke(port_tf.origin, vent_dir)
