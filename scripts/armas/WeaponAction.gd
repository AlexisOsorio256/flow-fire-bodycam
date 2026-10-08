class_name WeaponAction
extends RefCounted

signal extracted
signal reached_rear
signal batteried
signal fed
signal locked_open

const K := 4000.0
const C := 80.0
const IMPULSE := 6.50
const RESTITUTION := 0.25
const EJECT_AT := 0.77
const OPEN_AT := 0.51
const BATTERY_AT := 0.10
const CLOSED_AT := 0.026
const LOCK_AT := 0.87
const RELEASE_SPEED := -4.2
const SUBSTEP := 0.0025
const AT_REST := 0.0025
const TRAVEL_REF := 0.039

var travel := TRAVEL_REF
var pos := 0.0
var vel := 0.0
var locked := false

var _extracted := true
var _open := false
var _rear_heard := true
var _battery_done := true


func at_rest() -> bool:
	return absf(pos) < AT_REST


func cycle() -> void:
	vel += IMPULSE * travel / TRAVEL_REF
	_extracted = false
	_open = false
	_rear_heard = false
	_battery_done = false


func lock_open() -> void:
	locked = true
	pos = travel
	vel = 0.0
	_open = true


func release() -> void:
	locked = false
	pos = travel
	vel = RELEASE_SPEED
	_battery_done = false


func step(delta: float, eject: bool, can_feed: bool, can_lock: bool) -> void:
	if locked:
		pos = travel
		vel = 0.0
		return
	var span := minf(delta, SUBSTEP * 64.0)
	var steps := maxi(1, ceili(span / SUBSTEP))
	var h := span / float(steps)
	for _i in steps:
		var s := Springs.step(pos, vel, 0.0, K, C, h)
		pos = s.x
		vel = s.y
		if pos < 0.0:
			pos = 0.0
			vel = maxf(0.0, vel)
		if pos > travel:
			pos = travel
			vel = -vel * RESTITUTION
			_hit_rear()
		if eject and not _extracted and pos > travel * EJECT_AT:
			_extracted = true
			extracted.emit()
		if pos > travel * OPEN_AT:
			_open = true
		if _open and not _battery_done and pos <= travel * BATTERY_AT and vel <= 0.0:
			_battery_done = true
			batteried.emit()
		if _open and can_feed and pos <= travel * CLOSED_AT:
			_open = false
			can_feed = false
			fed.emit()
		if can_lock and pos > travel * LOCK_AT:
			lock_open()
			_hit_rear()
			locked_open.emit()
			return


func _hit_rear() -> void:
	if _rear_heard:
		return
	_rear_heard = true
	reached_rear.emit()
