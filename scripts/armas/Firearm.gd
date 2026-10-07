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
var _sequence: CueSequence

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
	slide.travel = viewmodel.weapon.slide_offset
	slide.extracted.connect(_spawn_shell)
	slide.reached_rear.connect(_say.bind("action_rear", 0.0, 0.98, 1.06))
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
	if _sequence != null and _sequence.advance(delta):
		_end_sequence()
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

func force_fire_once() -> void:
	if _can_fire():
		_fire()

func can_reload() -> bool:
	return not reloading and not inspecting and not drawing and (chamber <= 0 or mag < mag_size)

func start_reload(incoming_rounds: int = 0) -> bool:
	if not can_reload() or incoming_rounds <= 0:
		return false
	pending_mag_rounds = incoming_rounds
	reloading = true
	aim = false
	trigger_held = false
	var clip := FpArms.CLIP_RELOAD_EMPTY if chamber <= 0 else FpArms.CLIP_RELOAD
	var t: Dictionary = viewmodel.arms.timing[clip]
	var cues := [
		[t["mag_out"], _mag_out],
		[spec.times["mag_in"], _mag_to_hand],
		[spec.times["mag_touch"], _touch_magwell],
		[t["mag_seat"] - spec.times["magin_lead"], _say.bind("mag_in", 0.0, 0.96, 1.03)],
		[t["mag_seat"], _seat_mag],
	]
	if chamber <= 0:
		cues.append([spec.times["action_release"], _release_slide])
	_sequence = CueSequence.new(cues, t["length"])
	viewmodel.arms.play_clip(clip, true)
	viewmodel.set_magazine_visible(true)
	viewmodel.arms.set_magazine_in_hand(false)
	return true

func inspect_weapon() -> void:
	if reloading or inspecting or drawing:
		return
	inspecting = true
	aim = false
	var t: Dictionary = viewmodel.arms.timing[FpArms.CLIP_INSPECT]
	var cues := [
		[spec.times["inspect_grab"], viewmodel.arms.set_magazine_in_hand.bind(true)],
		[t["mag_out"], _say.bind("mag_out", 0.0, 0.98, 1.04)],
		[spec.times["inspect_touch"], _touch_magwell],
		[t["mag_seat"] - spec.times["magin_lead"], _say.bind("mag_in", 0.0, 0.98, 1.03)],
		[t["mag_seat"], viewmodel.arms.set_magazine_in_hand.bind(false)],
	]
	if not slide.locked and t.has("slide_back"):
		cues.append([t["slide_back"], _say.bind("action_rear", -1.0, 1.02, 1.08)])
		cues.append([t["slide_home"], _say.bind("action_release", -1.0, 1.0, 1.05)])
	_sequence = CueSequence.new(cues, t["length"])
	viewmodel.arms.play_clip(FpArms.CLIP_INSPECT, true)

func equip() -> void:
	_sequence = null
	reloading = false
	inspecting = false
	aim = false
	trigger_held = false
	viewmodel.arms.set_magazine_in_hand(false)
	viewmodel.set_magazine_visible(true)
	drawing = true
	var t: Dictionary = viewmodel.arms.timing[FpArms.CLIP_EQUIP]
	var cues := [[spec.times.get("raise_at", 0.05), _say.bind("raise", -2.0, 0.95, 1.05)]]
	if t.has("slide_back"):
		cues = [[t["slide_back"], _say.bind("action_rear", -3.0, 0.98, 1.05)],
			[t["slide_home"], _say.bind("action_release", 0.0, 0.98, 1.03)]]
	_sequence = CueSequence.new(cues, t["length"])
	viewmodel.arms.play_clip(FpArms.CLIP_EQUIP, true)

func _end_sequence() -> void:
	_sequence = null
	drawing = false
	if reloading:
		if chamber <= 0:
			push_error("Recarga en seco: la corredera no alimento")
		reloading = false
		viewmodel.set_magazine_visible(true)
	inspecting = false
	viewmodel.arms.set_magazine_in_hand(false)
	viewmodel.arms.play_clip(FpArms.CLIP_IDLE, true)

func _can_fire() -> bool:
	return not reloading and not drawing and chamber > 0 and slide.at_rest() and _shot_delay <= 0.0

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
		_sequence = null
		inspecting = false
		viewmodel.arms.set_magazine_in_hand(false)
	chamber -= 1
	trigger_ready = false
	_trigger_buffer = 0.0
	_shot_delay = spec.fire_delay
	slide.cycle()
	viewmodel.arms.play_clip(FpArms.CLIP_FIRE, true)
	shot_pulse = 1.0
	recoil.kick_shot()
	GameAudio.play_shot(spec.shot_streams)
	var origin := viewmodel.muzzle.global_position
	var bore := aimer.shot(camera, origin, aim_blend, player_speed)
	Ballistics.fire(origin, bore, spec.muzzle_speed, shooter)
	fx.fire(viewmodel.muzzle, origin, bore)
	shot_fired.emit()

func _on_battery() -> void:
	recoil.kick_slide_battery()
	slide_batteried.emit()
	_say("action_battery", 0.0, 0.97, 1.03)

func _on_fed() -> void:
	mag -= 1
	chamber = 1

func _on_locked_open() -> void:
	recoil.kick_slide_lock()
	ImpactFX.spawn_barrel_smoke(viewmodel.ejection_port)
	ImpactFX.spawn_barrel_smoke(viewmodel.muzzle)

func _mag_out() -> void:
	_say("mag_out", 0.0, 0.96, 1.03)
	viewmodel.set_magazine_visible(false)
	var spin := Vector3(randf_range(-7.0, -3.0), randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))
	DroppedProp.spawn(get_tree().current_scene, viewmodel.weapon.magazine, spec.mag_empty_kg + mag * spec.round_kg,
		viewmodel.weapon.magazine_out_axis() * MAG_FALL_SPEED + player_velocity * 0.5, spin, "mag_drop", MAG_LIFETIME)

func _mag_to_hand() -> void:
	viewmodel.set_magazine_visible(true)
	viewmodel.arms.set_magazine_in_hand(true)
	_say("mag_grab", 0.0, 0.97, 1.04)

func _touch_magwell() -> void:
	_say("mag_touch", -9.0, 1.08, 1.18)
	recoil.kick_mag_touch()

func _say(role: String, adjust_db: float, pitch_low: float, pitch_high: float) -> void:
	var sound: String = spec.sounds.get(role, "")
	if sound != "":
		GameAudio.play_2d(sound, adjust_db, randf_range(pitch_low, pitch_high))


func _seat_mag() -> void:
	viewmodel.arms.set_magazine_in_hand(false)
	mag = mini(mag_size, pending_mag_rounds)
	pending_mag_rounds = 0
	recoil.kick_mag_seat()
	mag_seated.emit()
	if spec.times.has("tap"):
		get_tree().create_timer(spec.times["tap"], false).timeout.connect(_say.bind("tap", 0.0, 0.97, 1.03))

func _release_slide() -> void:
	_say("action_release", 0.0, 0.98, 1.03)
	slide.release()

func _spawn_shell() -> void:
	var port_tf: Transform3D = viewmodel.ejection_port.global_transform
	Shell.spawn(get_tree().current_scene, port_tf, slide.vel, player_velocity, spec.caliber)
	var vent_dir: Vector3 = (port_tf.basis.x * 0.8 + port_tf.basis.y * 0.4 - port_tf.basis.z * 0.1).normalized()
	ImpactFX.spawn_ejection_smoke(port_tf.origin, vent_dir)
