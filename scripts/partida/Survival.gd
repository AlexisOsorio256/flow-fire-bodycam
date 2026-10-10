class_name Survival
extends TeamMatch

const FIRST_WAVE := 3
const MAX_WAVE_SIZE := 9
const BREAK := 7.0
const OPENING := 3.0
const SKILL_STEP := 0.06
const RECORD_PATH := "user://record.cfg"

var wave := 0
var record := 0
var _break := 0.0


func start() -> void:
	stop()
	time_left = 0.0
	wave = 0
	record = _saved_record()
	running = true
	_break = OPENING


func point(_team: int) -> void:
	pass


func player_down() -> void:
	if wave > record:
		record = wave
		var cfg := ConfigFile.new()
		cfg.set_value("survival", "wave", record)
		cfg.save(RECORD_PATH)
	_end(1)


func board() -> Dictionary:
	return {"left": ["OLEADA", wave], "right": ["RÉCORD", record], "note": "SIN REAPARICIÓN", "clock": time_left}


func result(_winner: int) -> Array:
	var line := "RÉCORD SUPERADO" if wave >= record and wave > 0 else "RÉCORD  OLEADA %d" % record
	return ["OLEADA %d" % wave, line, "lose"]


func _advance(delta: float) -> void:
	if _break > 0.0:
		_break -= delta
		if _break <= 0.0:
			_next_wave()
		return
	if _roster.is_empty():
		_break = BREAK
		Voices.radio("clear", 1.0, true)
		return
	super(delta)


func _wire(actor: Enemy, slot: Dictionary) -> void:
	super(actor, slot)
	actor.brain.skill = minf(0.95, Settings.RIVAL_SKILL[Settings.difficulty] + wave * SKILL_STEP)
	actor.brain.rush = randf() < EnemyBrain.rush_chance(actor.brain.skill)
	if actor.weapon_id == "glock" and randf() < mini(wave, 6) * 0.06:
		actor.set_weapon("rifle")


func _next_wave() -> void:
	wave += 1
	for i in mini(FIRST_WAVE + wave - 1, MAX_WAVE_SIZE):
		_roster.append({"team": 1, "actor": null, "wait": 0.3 + i * 0.5})
	if wave > 1:
		Voices.radio("wave", 1.0, true)


func _goal_for(_actor: Enemy) -> Vector3:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return Vector3.INF
	return player.global_position + Vector3(randf_range(-4, 4), 0.0, randf_range(-4, 4))


func _on_down(actor: Enemy, slot: Dictionary) -> void:
	super(actor, slot)
	_roster.erase(slot)


func _saved_record() -> int:
	var cfg := ConfigFile.new()
	return cfg.get_value("survival", "wave", 0) if cfg.load(RECORD_PATH) == OK else 0
