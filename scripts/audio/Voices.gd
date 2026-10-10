class_name Voices
extends RefCounted

const DIR := "res://assets/audio/voice/"
const RADIO_DB := -4.0
const SHOUT_DB := 4.0
const PAIN_DB := 0.0
const OWN_PAIN_DB := -7.0
const SHOUT_REACH := Vector2(7.0, 55.0)
const PAIN_REACH := Vector2(4.0, 35.0)
const RADIO_GAP := 1.4
const ACTOR_GAP := 4.0
const PAIN_GAP := 0.9
const GROAN_EVERY := Vector2(3.0, 6.5)
const GROAN_DB := -7.0

static var ally_team := 0
static var _cache := {}
static var _radio_free_at := 0.0
static var _radio_player: AudioStreamPlayer
static var _own_pain_at := 0.0
static var _groaning := {}
static var _actor_free_at := {}


static func say(actor: Node3D, line: String, chance := 1.0) -> void:
	if not is_instance_valid(actor) or randf() > chance or _now() < _actor_free_at.get(actor.get_instance_id(), 0.0):
		return
	if actor.team == ally_team:
		if radio(line):
			_actor_free_at[actor.get_instance_id()] = _now() + ACTOR_GAP
		return
	var list := _streams("shout_" + line)
	if list.is_empty():
		return
	var stream: AudioStream = list.pick_random()
	_actor_free_at[actor.get_instance_id()] = _now() + stream.get_length() + ACTOR_GAP
	GameAudio.stream_3d(stream, _mouth(actor), SHOUT_DB, SHOUT_REACH, GameAudio.BUS_WORLD, randf_range(0.97, 1.03))


static func radio(line: String, chance := 1.0, urgent := false) -> bool:
	if randf() > chance or (_now() < _radio_free_at and not urgent):
		return false
	if urgent and is_instance_valid(_radio_player):
		_radio_player.queue_free()
	var list := _streams("radio_" + line)
	if list.is_empty():
		return false
	var stream: AudioStream = list.pick_random()
	_radio_free_at = _now() + stream.get_length() + RADIO_GAP
	_radio_player = GameAudio.stream_2d(stream, RADIO_DB, GameAudio.BUS_MASTER, randf_range(0.98, 1.02))
	return true


static func hurt(actor: Node3D, region: String) -> void:
	if region == "head" or _now() < _actor_free_at.get(actor.get_instance_id(), 0.0):
		return
	pain(actor)
	_after(actor.get_tree(), 0.75, actor, "hit", 0.35)
	if region == "leg" and not _groaning.has(actor.get_instance_id()):
		_groaning[actor.get_instance_id()] = true
		_groan_later(actor)


static func on_down(actor: Node3D, region: String, killer: Node3D) -> void:
	if region != "head" and randf() < 0.7:
		dying(actor)
	var tree := actor.get_tree()
	if killer is Enemy and killer.team == ally_team:
		_after(tree, randf_range(0.4, 0.9), killer, "tango", 0.6)
	var mate := _nearest_mate(actor)
	if mate != null:
		_after(tree, randf_range(0.8, 1.5), mate, "down", 0.85)


static func pain(actor: Node3D, adjust_db := 0.0) -> void:
	_actor_free_at[actor.get_instance_id()] = _now() + PAIN_GAP
	GameAudio.stream_3d(_streams("pain").pick_random(), _mouth(actor), PAIN_DB + adjust_db, PAIN_REACH,
		GameAudio.BUS_WORLD, randf_range(0.82, 0.95) if adjust_db < 0.0 else randf_range(0.9, 1.08))


static func _groan_later(actor: Node3D) -> void:
	actor.get_tree().create_timer(randf_range(GROAN_EVERY.x, GROAN_EVERY.y), false).timeout.connect(func() -> void:
		if not is_instance_valid(actor) or not actor.is_alive():
			return
		if _now() >= _actor_free_at.get(actor.get_instance_id(), 0.0):
			pain(actor, GROAN_DB)
		_groan_later(actor))


static func dying(actor: Node3D) -> void:
	GameAudio.stream_3d(_streams("dying").pick_random(), _mouth(actor), PAIN_DB, PAIN_REACH, GameAudio.BUS_WORLD,
		randf_range(0.92, 1.05))


static func own_pain(dying_now: bool) -> void:
	if not dying_now and _now() < _own_pain_at:
		return
	_own_pain_at = _now() + PAIN_GAP
	GameAudio.stream_2d(_streams("dying" if dying_now else "pain").pick_random(), OWN_PAIN_DB, GameAudio.BUS_WEAPONS,
		randf_range(0.94, 1.02))


static func _after(tree: SceneTree, seconds: float, actor: Node3D, line: String, chance: float) -> void:
	tree.create_timer(seconds, false).timeout.connect(func() -> void: say(actor, line, chance))


static func _nearest_mate(actor: Node3D) -> Node3D:
	var best: Node3D = null
	var best_d := 30.0
	for other: Node3D in actor.get_tree().get_nodes_in_group("combatant"):
		if other == actor or other is Player or other.team != actor.team or not other.is_alive():
			continue
		var d := other.global_position.distance_to(actor.global_position)
		if d < best_d:
			best = other
			best_d = d
	return best


static func _mouth(actor: Node3D) -> Vector3:
	return actor.global_position + Vector3.UP * 1.6


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


static func _streams(prefix: String) -> Array:
	if not _cache.has(prefix):
		var found := []
		while ResourceLoader.exists("%s%s_%d.wav" % [DIR, prefix, found.size()]):
			found.append(load("%s%s_%d.wav" % [DIR, prefix, found.size()]))
		_cache[prefix] = found
	return _cache[prefix]
