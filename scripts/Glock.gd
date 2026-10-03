extends Node3D
signal shot_fired
signal ammo_changed(mag: int, chamber: int, reloading: bool)
signal mag_seated
signal slide_batteried


var MAG_SIZE := 15
var _travel: float = GlockWeapon.SLIDE_TRAVEL
const SLIDE_K := 4000.0
const SLIDE_C := 80.0
const SLIDE_IMPULSE := 6.50
const SLIDE_RESTITUTION := 0.25
const SLIDE_EJECT_AT := 0.77
const SLIDE_OPEN_AT := 0.51
const SLIDE_BATTERY_AT := 0.10
const SLIDE_CLOSED_AT := 0.026
const MUZZLE_SPEED := 372.0
const SHOT_DISPERSION_SIGMA := 0.0016

const RELOAD_TOTAL := 2.55
const RELOAD_EMPTY_TOTAL := 3.10
const RELOAD_MAG_OUT_T := 0.28
const RELOAD_MAG_IN_T := 0.66
const RELOAD_MAG_TOUCH_T := 1.28
const RELOAD_MAG_SEAT_T := 1.74
const MAG_FALL_SPEED := 2.6
const MAGIN_SOUND_LEAD := 0.06
const RELOAD_SLIDE_T := 2.31
const SLIDE_RELEASE_LEAD := 0.05
const INSPECT_TOTAL := 3.60
const INSPECT_GRAB_T := 0.42
const INSPECT_MAG_OUT_T := 0.62
const INSPECT_TOUCH_T := 2.44
const INSPECT_MAG_SEAT_T := 2.90

var camera: Camera3D
var shooter: Node3D
var viewmodel: GlockViewmodel
var recoil: GlockRecoil
var fx: WeaponFX

var mag := 15
var chamber := 1
var pending_mag_rounds := 0
var trigger_held := false
var trigger_ready := true
var trigger_latched := false

var slide_pos := 0.0
var slide_vel := 0.0
var slide_locked := false
var slide_extracted := true
var slide_open := false
var slide_rear_sound_emitted := true
var slide_battery_emitted := true
var trigger_visual := 0.0

var reloading := false
var reload_elapsed := 0.0
var reload_total := 0.0
var reload_empty := false
var reload_slide_released := false
var reload_mag_seated := false

var inspecting := false
var inspect_elapsed := 0.0
var inspect_mag_grabbed := false
var inspect_mag_sounded := false
var inspect_mag_seated := false
var inspect_mag_touched := false

var aim := false
var sprinting := false
var aim_blend := 0.0
var sprint_blend := 0.0
var player_speed := 0.0
var step_phase := 0.0
var look_delta := Vector2.ZERO
var player_velocity := Vector3.ZERO
var _last_local_move := Vector2.ZERO

var shot_pulse := 0.0

var _mag_left := false
var _mag_touched := false
var _magin_sounded := false
var _mag_entered := false
var _slide_release_sounded := false


func _ready() -> void:
	recoil = GlockRecoil.new()
	viewmodel = GlockViewmodel.new()
	viewmodel.name = "Viewmodel"
	viewmodel.recoil = recoil
	add_child(viewmodel)
	if not viewmodel.mount():
		push_error("Glock no puede arrancar sin sus assets canonicos")
		process_mode = Node.PROCESS_MODE_DISABLED
		get_tree().quit(1)
		return
	if viewmodel.weapon != null:
		MAG_SIZE = viewmodel.weapon.capacity
		_travel = viewmodel.weapon.slide_offset
		mag = MAG_SIZE
	if viewmodel.muzzle != null:
		fx = WeaponFX.new()
		fx.name = "WeaponFX"
		viewmodel.muzzle.add_child(fx)
		fx.build()
	if camera != null and viewmodel.weapon != null and not viewmodel.ads_solved:
		camera.force_update_transform()
		viewmodel.solve_ads()
	_emit_ammo()


func setup(cam: Camera3D) -> void:
	camera = cam
	viewmodel.setup(cam)


func _update_aim(delta: float) -> void:
	var target_sprint := 1.0 if sprinting else 0.0
	sprint_blend += (target_sprint - sprint_blend) * (1.0 - exp(-5.5 * delta))
	var target_aim := (1.0 if aim else 0.0) * (1.0 - sprint_blend)
	aim_blend += (target_aim - aim_blend) * (1.0 - exp(-6.5 * delta))


func _process(delta: float) -> void:
	_update_aim(delta)
	_update_trigger(delta)
	_update_slide(delta)
	_update_reload(delta)
	_update_inspect(delta)
	recoil.update(delta)
	viewmodel.set_pose_inputs(aim_blend, sprint_blend, player_speed, look_delta,
		_last_local_move, step_phase)
	viewmodel.update(delta)
	if viewmodel.weapon != null:
		viewmodel.weapon.set_slide(slide_pos / maxf(_travel, 0.0001))
		viewmodel.weapon.set_trigger(trigger_visual)
		viewmodel.weapon.set_chamber_visible(chamber > 0 and slide_pos > _travel * 0.15)

	shot_pulse = maxf(0.0, shot_pulse - delta * 8.0)
	if fx != null:
		fx.update(delta)


func set_aim(value: bool) -> void:
	aim = value


func set_sprint(value: bool) -> void:
	sprinting = value


func set_motion(speed: float, local_move: Vector2, look: Vector2, phase := 0.0) -> void:
	player_speed = speed
	look_delta = look
	_last_local_move = local_move
	step_phase = phase


func press_trigger() -> void:
	trigger_held = true


func release_trigger() -> void:
	trigger_held = false


func force_fire_once() -> void:
	if _can_fire():
		_fire()


func can_reload() -> bool:
	if reloading or inspecting:
		return false
	if chamber > 0 and mag >= MAG_SIZE:
		return false
	return true


func start_reload(incoming_rounds: int = 0) -> bool:
	if not can_reload() or incoming_rounds <= 0:
		return false
	pending_mag_rounds = incoming_rounds
	reloading = true
	inspecting = false
	reload_elapsed = 0.0
	reload_empty = chamber <= 0
	reload_total = RELOAD_EMPTY_TOTAL if reload_empty else RELOAD_TOTAL
	reload_slide_released = false
	reload_mag_seated = false
	_mag_touched = false
	_mag_left = false
	_magin_sounded = false
	_mag_entered = false
	_slide_release_sounded = false
	aim = false
	trigger_held = false
	viewmodel.play_clip(GlockViewmodel.CLIP_RELOAD_EMPTY if reload_empty
		else GlockViewmodel.CLIP_RELOAD, true)
	viewmodel.set_magazine_visible(true)
	viewmodel.set_magazine_in_hand(false)
	_emit_ammo()
	return true


func _can_fire() -> bool:
	return not reloading and not inspecting and chamber > 0 and absf(slide_pos) < 0.0025


func _update_trigger(delta: float) -> void:
	trigger_visual += ((1.0 if trigger_held else 0.0) - trigger_visual) * (1.0 - exp(-28.0 * delta))
	if trigger_held and trigger_ready and trigger_visual > 0.6 and _can_fire():
		_fire()
		return
	if trigger_held and trigger_ready and not reloading and chamber <= 0:
		trigger_ready = false
		trigger_latched = true
		GameAudio.play_2d("empty")
	if not trigger_held:
		if trigger_latched:
			if trigger_visual < 0.35 and (absf(slide_pos) < 0.0025 or slide_locked):
				trigger_ready = true
				trigger_latched = false
				GameAudio.play_2d("trigger_reset", 0.0, randf_range(0.97, 1.05))
		else:
			trigger_ready = true


func _fire() -> void:
	chamber -= 1
	inspecting = false
	trigger_ready = false
	trigger_latched = true
	slide_extracted = false
	slide_open = false
	slide_rear_sound_emitted = false
	slide_battery_emitted = false
	slide_vel += SLIDE_IMPULSE
	viewmodel.play_clip(GlockViewmodel.CLIP_FIRE, true)
	shot_pulse = 1.0
	recoil.kick_shot()
	GameAudio.play_shot()

	var origin := viewmodel.muzzle.global_position
	var bore: Vector3 = (-viewmodel.muzzle.global_transform.basis.z).normalized()
	bore = _apply_dispersion(bore)
	Ballistics.fire(origin, bore, MUZZLE_SPEED, shooter)
	fx.fire(viewmodel.muzzle, origin, bore)
	emit_signal("shot_fired")
	_emit_ammo()


func _apply_dispersion(bore: Vector3) -> Vector3:
	var side := bore.cross(Vector3.UP)
	assert(side.length() >= 0.001, "El anima de la Glock no puede ser paralelo a UP")
	side = side.normalized()
	var up := side.cross(bore).normalized()
	var cone := side * randfn(0.0, SHOT_DISPERSION_SIGMA) + up * randfn(0.0, SHOT_DISPERSION_SIGMA)
	return (bore + cone).normalized()


func _update_slide(delta: float) -> void:
	if slide_locked:
		slide_pos = _travel
		slide_vel = 0.0
	else:
		const SUBSTEP := 0.0025
		var span := minf(delta, SUBSTEP * 64.0)
		var steps := maxi(1, ceili(span / SUBSTEP))
		var h := span / float(steps)
		for _i in range(steps):
			slide_vel += (-SLIDE_K * slide_pos - SLIDE_C * slide_vel) * h
			slide_pos += slide_vel * h
			if slide_pos < 0.0:
				slide_pos = 0.0
				slide_vel = maxf(0.0, slide_vel)
			if slide_pos > _travel:
				slide_pos = _travel
				slide_vel = -slide_vel * SLIDE_RESTITUTION
				_emit_slide_rear_event()
			if not inspecting and not slide_extracted and slide_pos > _travel * SLIDE_EJECT_AT:
				slide_extracted = true
				_spawn_shell()
			if slide_pos > _travel * SLIDE_OPEN_AT:
				slide_open = true
			if slide_open and not slide_battery_emitted and slide_pos <= _travel * SLIDE_BATTERY_AT and slide_vel <= 0.0:
				slide_battery_emitted = true
				if recoil != null:
					recoil.kick_slide_battery()
				slide_batteried.emit()
				GameAudio.play_2d("slide_battery", 0.0, randf_range(0.97, 1.03))
			if slide_open and slide_pos <= _travel * SLIDE_CLOSED_AT and chamber <= 0 and mag > 0:
				slide_open = false
				mag -= 1
				chamber = 1
				_emit_ammo()
			if slide_pos > _travel * 0.87 and mag <= 0 and chamber <= 0 and not reloading:
				slide_locked = true
				slide_pos = _travel
				slide_vel = 0.0
				slide_open = true
				_emit_slide_rear_event()
				if recoil != null:
					recoil.kick_slide_lock()
				if viewmodel != null and viewmodel.ejection_port != null:
					ImpactFX.spawn_barrel_smoke(viewmodel.ejection_port)
				if viewmodel != null and viewmodel.muzzle != null:
					ImpactFX.spawn_barrel_smoke(viewmodel.muzzle)
				break


func _emit_slide_rear_event() -> void:
	if slide_rear_sound_emitted:
		return
	slide_rear_sound_emitted = true
	GameAudio.play_2d("slide_rear", 0.0, randf_range(0.98, 1.06))


func _update_reload(delta: float) -> void:
	if not reloading:
		return
	reload_elapsed += delta

	if not _mag_left and reload_elapsed >= RELOAD_MAG_OUT_T:
		_mag_left = true
		GameAudio.play_2d("magout", 0.0, randf_range(0.96, 1.03))
		viewmodel.set_magazine_visible(false)
		_drop_empty_magazine()
	if not _mag_entered and reload_elapsed >= RELOAD_MAG_IN_T:
		_mag_entered = true
		viewmodel.set_magazine_visible(true)
		viewmodel.set_magazine_in_hand(true)
		GameAudio.play_2d("mag_insert", 0.0, randf_range(0.97, 1.04))
	if not _mag_touched and reload_elapsed >= RELOAD_MAG_TOUCH_T:
		_mag_touched = true
		_touch_magwell()
	if not _magin_sounded and reload_elapsed >= RELOAD_MAG_SEAT_T - MAGIN_SOUND_LEAD:
		_magin_sounded = true
		GameAudio.play_2d("magin", 0.0, randf_range(0.96, 1.03))

	if reload_empty and not _slide_release_sounded \
			and reload_elapsed >= RELOAD_SLIDE_T - SLIDE_RELEASE_LEAD:
		_slide_release_sounded = true
		GameAudio.play_2d("slide_release", 0.0, randf_range(0.98, 1.03))

	if not reload_mag_seated and reload_elapsed >= RELOAD_MAG_SEAT_T:
		viewmodel.set_magazine_in_hand(false)
		_seat_reload_mag()
		recoil.kick_mag_seat()
		mag_seated.emit()

	if reload_empty and not reload_slide_released and reload_elapsed >= RELOAD_SLIDE_T:
		reload_slide_released = true
		slide_locked = false
		slide_pos = _travel
		slide_vel = -4.2
		slide_battery_emitted = false
	if reload_elapsed >= reload_total:
		_finish_reload()


func _drop_empty_magazine() -> void:
	var scene := get_tree().current_scene
	if scene == null or viewmodel.weapon == null or viewmodel.weapon.magazine == null:
		return
	var down: Vector3 = viewmodel.weapon.magazine_out_axis()
	var spin := Vector3(randf_range(-7.0, -3.0), randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))
	var dropped_rounds := mag
	MagazineDrop.spawn(scene, viewmodel.weapon.magazine,
		down * MAG_FALL_SPEED + player_velocity * 0.5, spin, dropped_rounds)


func inspect_weapon() -> void:
	if reloading or inspecting:
		return
	inspecting = true
	inspect_elapsed = 0.0
	inspect_mag_grabbed = false
	inspect_mag_sounded = false
	inspect_mag_seated = false
	inspect_mag_touched = false
	viewmodel.play_clip(GlockViewmodel.CLIP_INSPECT, true)


func _update_inspect(delta: float) -> void:
	if not inspecting:
		if inspect_mag_grabbed and not inspect_mag_seated:
			inspect_mag_seated = true
			viewmodel.set_magazine_in_hand(false)
		return
	inspect_elapsed += delta
	if not inspect_mag_grabbed and inspect_elapsed >= INSPECT_GRAB_T:
		inspect_mag_grabbed = true
		viewmodel.set_magazine_in_hand(true)
	if not inspect_mag_sounded and inspect_elapsed >= INSPECT_MAG_OUT_T:
		inspect_mag_sounded = true
		GameAudio.play_2d("magout", 0.0, randf_range(0.98, 1.04))
	if not inspect_mag_touched and inspect_elapsed >= INSPECT_TOUCH_T:
		inspect_mag_touched = true
		_touch_magwell()
	if not inspect_mag_seated and inspect_elapsed >= INSPECT_MAG_SEAT_T:
		inspect_mag_seated = true
		viewmodel.set_magazine_in_hand(false)
		GameAudio.play_2d("magin", 0.0, randf_range(0.98, 1.03))
	if inspect_elapsed >= INSPECT_TOTAL:
		inspecting = false
		viewmodel.play_clip(GlockViewmodel.CLIP_IDLE, true)


func _touch_magwell() -> void:
	GameAudio.play_2d("mag_insert", -9.0, randf_range(1.08, 1.18))
	recoil.kick_mag_touch()


func _seat_reload_mag() -> void:
	if reload_mag_seated:
		return
	reload_mag_seated = true
	mag = mini(MAG_SIZE, pending_mag_rounds)
	pending_mag_rounds = 0
	_emit_ammo()


func _finish_reload() -> void:
	if not reload_mag_seated:
		push_error("Recarga: el asiento no ocurrio en su hito")
	if reload_empty and chamber <= 0:
		push_error("Recarga en seco: la corredera no alimento")
	reloading = false
	viewmodel.set_magazine_in_hand(false)
	viewmodel.set_magazine_visible(true)
	viewmodel.play_clip(GlockViewmodel.CLIP_IDLE, true)
	_emit_ammo()


func _spawn_shell() -> void:
	if not is_instance_valid(get_tree().current_scene):
		return
	var port_tf: Transform3D = viewmodel.ejection_port.global_transform
	Shell.spawn(get_tree().current_scene, port_tf, slide_vel, player_velocity)
	var vent_dir: Vector3 = (port_tf.basis.x * 0.8 + port_tf.basis.y * 0.4 - port_tf.basis.z * 0.1).normalized()
	ImpactFX.spawn_ejection_smoke(port_tf.origin, vent_dir)


func _emit_ammo() -> void:
	ammo_changed.emit(mag, chamber, reloading)
