class_name EnemyTrigger
extends RefCounted

const REACTION := Vector2(0.35, 0.65)
const BURST := Vector2i(2, 3)
const BURST_RIFLE := Vector2i(3, 5)
const SHOT_GAP := Vector2(0.22, 0.30)
const BURST_PAUSE := Vector2(0.8, 1.3)
const SPREAD_START := 0.085
const SPREAD_SETTLED := 0.009
const SETTLE := Vector2(2.6, 1.6)
const DODGE := 0.15
const WOUNDED_SPREAD := 2.5
const WOUNDED_PAUSE := 1.7
const FRIEND_WAIT := 0.2

var timer := 0.0
var _burst_left := 0


func react(skill: float) -> void:
	timer = randf_range(REACTION.x, REACTION.y) * lerpf(1.35, 0.75, skill)
	_burst_left = 0


func hold(seconds: float) -> void:
	timer = maxf(timer, seconds)
	_burst_left = 0


func busy() -> bool:
	return _burst_left > 0 or timer < 0.35


func pull(body: Enemy, target: Node3D, delta: float, seen_for: float, skill: float, aim_bad: float) -> void:
	timer -= delta
	if timer > 0.0:
		return
	if EnemySenses.friend_in_line(body, EnemySenses.chest_of(target)):
		timer = FRIEND_WAIT
		return
	var hurt := body.wounds.wounded()
	if _burst_left <= 0:
		_burst_left = 1 if hurt else (randi_range(BURST_RIFLE.x, BURST_RIFLE.y) if body.weapon_id == "rifle" else randi_range(BURST.x, BURST.y))
	_burst_left -= 1
	timer = randf_range(SHOT_GAP.x, SHOT_GAP.y) if _burst_left > 0 \
		else randf_range(BURST_PAUSE.x, BURST_PAUSE.y) * (WOUNDED_PAUSE if hurt else 1.0)
	var settle := clampf(seen_for / lerpf(SETTLE.x, SETTLE.y, skill), 0.0, 1.0)
	var spread := lerpf(SPREAD_START, SPREAD_SETTLED, settle) * (1.0 + 2.5 * aim_bad) \
		* lerpf(1.3, 0.8, skill) * (1.0 + DODGE * _lateral(body, target)) * (WOUNDED_SPREAD if hurt else 1.0)
	body.fire_at(EnemySenses.chest_of(target), spread)


func _lateral(body: Enemy, target: Node3D) -> float:
	var v: Vector3 = target.get("velocity")
	var los := (target.global_position - body.global_position).normalized()
	return (v - los * v.dot(los)).length()
