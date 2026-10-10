class_name PlayerAudio
extends Node

var _heart: AudioStreamPlayer
var _breath: AudioStreamPlayer
var step_phase := 0.0
var bob := Vector2.ZERO
var _step_accum := 0.0


func update(danger: float, dead: bool, adrenaline: float, ring: float) -> void:
	if dead:
		stop()
		GameAudio.muffle(1.0)
		return
	if danger <= 0.02 and ring <= 0.02:
		GameAudio.muffle(0.0)
		stop()
		return
	if _heart == null or not is_instance_valid(_heart):
		_heart = GameAudio.loop("heart", -60.0)
	if _breath == null or not is_instance_valid(_breath):
		_breath = GameAudio.loop("breath", -60.0)
	GameAudio.muffle(maxf(danger * 0.35, ring))
	_heart.volume_db = GameAudio.LOOPS["heart"]["db"] + linear_to_db(maxf(danger, 0.0001))
	_heart.pitch_scale = 1.0 + adrenaline * 0.35
	var gasp := maxf(danger, adrenaline * 0.55)
	_breath.volume_db = GameAudio.LOOPS["breath"]["db"] + linear_to_db(maxf(gasp, 0.0001))
	_breath.pitch_scale = 1.0 + adrenaline * 0.12


func stop() -> void:
	if is_instance_valid(_heart):
		_heart.stop()
		_heart.queue_free()
		_heart = null
	if is_instance_valid(_breath):
		_breath.stop()
		_breath.queue_free()
		_breath = null


func hit(dying: bool) -> void:
	Voices.own_pain(dying)
	var tree := get_tree()
	if dying:
		tree.create_timer(1.1, false).timeout.connect(func() -> void: Voices.radio("down", 1.0, true))
	else:
		tree.create_timer(1.8, false).timeout.connect(func() -> void: Voices.radio("check", 0.3))


func footsteps(body: Player, delta: float) -> void:
	if body.airborne:
		_step_accum = 0.0
		bob = Vector2.ZERO
		return
	var speed := body.current_speed
	if speed > 0.22:
		step_phase += delta * (1.8 + speed * 1.45)
		_step_accum += speed * delta
		if _step_accum > Player.STEP_LENGTH:
			_step_accum -= Player.STEP_LENGTH
			GameAudio.footstep(body.global_position, body.get_world_3d(),
				3.0 if body.sprinting else -6.0 if body.crouching else 0.0, false)
			if not body.crouching:
				body.get_tree().call_group("enemy", "hear_step", body.global_position, body,
					10.0 if body.sprinting else 6.0)
			if body.sprinting and randf() < 0.5:
				GameAudio.play_2d("cloth", 0.0, randf_range(0.9, 1.1))
	else:
		_step_accum = 0.0
	var move_norm := clampf(speed / Player.WALK_SPEED, 0.0, 1.0)
	bob = Vector2(cos(step_phase) * Player.BOB_SIDE, sin(step_phase * 2.0) * Player.BOB_RISE) * move_norm


func _exit_tree() -> void:
	GameAudio.muffle(0.0)
	stop()
