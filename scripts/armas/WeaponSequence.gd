class_name WeaponSequence
extends RefCounted

var host: Firearm
var _runtime: CueSequence


func _init(weapon: Firearm) -> void:
	host = weapon


func step(delta: float) -> void:
	if _runtime != null and _runtime.advance(delta):
		end()


func cancel() -> void:
	_runtime = null
	host.reloading = false
	host.inspecting = false
	host.drawing = false
	host.aim = false
	host.trigger_held = false
	host.viewmodel.arms.set_magazine_in_hand(false)
	host.viewmodel.set_magazine_visible(true)


func cancel_inspect() -> void:
	if not host.inspecting:
		return
	_runtime = null
	host.inspecting = false
	host.viewmodel.arms.set_magazine_in_hand(false)


func start_reload(incoming_rounds: int) -> bool:
	if not host.can_reload() or incoming_rounds <= 0:
		return false
	host.pending_mag_rounds = incoming_rounds
	host.reloading = true
	host.aim = false
	host.trigger_held = false
	var empty := host.chamber <= 0
	var clip := FpArms.CLIP_RELOAD_EMPTY if empty else FpArms.CLIP_RELOAD
	var t: Dictionary = host.viewmodel.arms.timing[clip]
	var cues: Array = shell_cues() if host.spec.shells else magazine_cues(t, empty)
	if host.spec.shells:
		host.viewmodel.set_magazine_visible(false)
	else:
		host.viewmodel.set_magazine_visible(true)
		host.viewmodel.arms.set_magazine_in_hand(false)
	_runtime = CueSequence.new(cues, t["length"])
	host.viewmodel.arms.play_clip(clip, true)
	return true


func magazine_cues(t: Dictionary, empty: bool) -> Array:
	var cues := [
		[t["mag_out"], mag_out],
		[host.spec.times["mag_in"], mag_to_hand],
		[host.spec.times["mag_touch"], touch_magwell],
		[t["mag_seat"] - host.spec.times["magin_lead"], say.bind("mag_in", 0.0, 0.96, 1.03)],
		[t["mag_seat"], seat_mag],
	]
	if empty:
		cues.append([host.spec.times["action_release"], release_slide])
	return cues


func shell_cues() -> Array:
	var empty := host.chamber <= 0
	var times: Array = host.spec.times["shells_empty" if empty else "shells"]
	var cues: Array = []
	for at: float in times:
		cues.append([at, insert_shell])
	cues.append([host.spec.times["seat"], seat_shells])
	if empty:
		cues.append([host.spec.times["action_release"], release_slide])
	return cues


func start_inspect() -> void:
	if host.reloading or host.inspecting or host.drawing:
		return
	host.inspecting = true
	host.aim = false
	var t: Dictionary = host.viewmodel.arms.timing[FpArms.CLIP_INSPECT]
	var cues: Array = []
	if host.spec.shells:
		if not host.slide.locked and t.has("slide_back"):
			cues.append([t["slide_back"], say.bind("action_rear", -1.0, 1.02, 1.08)])
			cues.append([t["slide_home"], say.bind("action_release", -1.0, 1.0, 1.05)])
	else:
		cues = [
			[host.spec.times["inspect_grab"], host.viewmodel.arms.set_magazine_in_hand.bind(true)],
			[t["mag_out"], say.bind("mag_out", 0.0, 0.98, 1.04)],
			[host.spec.times["inspect_touch"], touch_magwell],
			[t["mag_seat"] - host.spec.times["magin_lead"], say.bind("mag_in", 0.0, 0.98, 1.03)],
			[t["mag_seat"], host.viewmodel.arms.set_magazine_in_hand.bind(false)],
		]
		if not host.slide.locked and t.has("slide_back"):
			cues.append([t["slide_back"], say.bind("action_rear", -1.0, 1.02, 1.08)])
			cues.append([t["slide_home"], say.bind("action_release", -1.0, 1.0, 1.05)])
	_runtime = CueSequence.new(cues, t["length"])
	host.viewmodel.arms.play_clip(FpArms.CLIP_INSPECT, true)


func equip() -> void:
	cancel()
	host.drawing = true
	var t: Dictionary = host.viewmodel.arms.timing[FpArms.CLIP_EQUIP]
	var cues := [[host.spec.times.get("raise_at", 0.05), say.bind("raise", -2.0, 0.95, 1.05)]]
	if t.has("slide_back"):
		cues = [[t["slide_back"], say.bind("action_rear", -3.0, 0.98, 1.05)],
			[t["slide_home"], say.bind("action_release", 0.0, 0.98, 1.03)]]
	_runtime = CueSequence.new(cues, t["length"])
	host.viewmodel.arms.play_clip(FpArms.CLIP_EQUIP, true)


func end() -> void:
	_runtime = null
	host.drawing = false
	if host.reloading:
		if host.chamber <= 0:
			push_error("Recarga en seco: la corredera no alimento")
		host.reloading = false
		host.viewmodel.set_magazine_visible(true)
	host.inspecting = false
	host.viewmodel.arms.set_magazine_in_hand(false)
	host.viewmodel.arms.play_clip(FpArms.CLIP_IDLE, true)


func mag_out() -> void:
	say("mag_out", 0.0, 0.96, 1.03)
	host.viewmodel.set_magazine_visible(false)
	var spin := Vector3(randf_range(-7.0, -3.0), randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))
	DroppedProp.spawn(host.get_tree().current_scene, host.viewmodel.weapon.magazine,
		host.spec.mag_empty_kg + host.mag * host.spec.round_kg,
		host.viewmodel.weapon.magazine_out_axis() * Firearm.MAG_FALL_SPEED + host.player_velocity * 0.5,
		spin, "mag_drop", Firearm.MAG_LIFETIME)


func mag_to_hand() -> void:
	host.viewmodel.set_magazine_visible(true)
	host.viewmodel.arms.set_magazine_in_hand(true)
	say("mag_grab", 0.0, 0.97, 1.04)


func touch_magwell() -> void:
	say("mag_touch", -9.0, 1.08, 1.18)
	host.recoil.kick_mag_touch()


func insert_shell() -> void:
	say("mag_in", 0.0, 0.97, 1.06)
	host.recoil.kick_mag_touch()


func seat_mag() -> void:
	host.viewmodel.arms.set_magazine_in_hand(false)
	host.mag = mini(host.mag_size, host.pending_mag_rounds)
	host.pending_mag_rounds = 0
	host.recoil.kick_mag_seat()
	host.mag_seated.emit()
	if host.spec.times.has("tap"):
		host.get_tree().create_timer(host.spec.times["tap"], false).timeout.connect(say.bind("tap", 0.0, 0.97, 1.03))


func seat_shells() -> void:
	host.mag = mini(host.mag_size, host.pending_mag_rounds)
	host.pending_mag_rounds = 0
	host.mag_seated.emit()


func release_slide() -> void:
	say("action_release", 0.0, 0.98, 1.03)
	host.slide.release()


func say(role: String, adjust_db: float, pitch_low: float, pitch_high: float) -> void:
	var sound: String = host.spec.sounds.get(role, "")
	if sound != "":
		GameAudio.play_2d(sound, adjust_db, randf_range(pitch_low, pitch_high))
