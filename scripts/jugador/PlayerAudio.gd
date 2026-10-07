class_name PlayerAudio
extends Node

var _heart: AudioStreamPlayer
var _breath: AudioStreamPlayer


func _ready() -> void:
	_heart = GameAudio.loop("heart", -60.0)
	_breath = GameAudio.loop("breath", -60.0)


func update(danger: float, dead: bool, adrenaline: float, ring: float) -> void:
	GameAudio.muffle(maxf(danger * 0.35, ring) if not dead else 1.0)
	_heart.volume_db = GameAudio.LOOPS["heart"]["db"] + linear_to_db(maxf(danger, 0.0001)) - (40.0 if dead else 0.0)
	_heart.pitch_scale = 1.0 + adrenaline * 0.35
	var gasp := 0.0 if dead else maxf(danger, adrenaline * 0.55)
	_breath.volume_db = GameAudio.LOOPS["breath"]["db"] + linear_to_db(maxf(gasp, 0.0001))
	_breath.pitch_scale = 1.0 + adrenaline * 0.12


func hit(dying: bool) -> void:
	Voices.own_pain(dying)
	var tree := get_tree()
	if dying:
		tree.create_timer(1.1, false).timeout.connect(func() -> void: Voices.radio("down", 1.0, true))
	else:
		tree.create_timer(1.8, false).timeout.connect(func() -> void: Voices.radio("check", 0.3))


func _exit_tree() -> void:
	GameAudio.muffle(0.0)
	_heart.queue_free()
	_breath.queue_free()
