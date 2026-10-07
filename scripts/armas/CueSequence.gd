class_name CueSequence
extends RefCounted

var length := 0.0
var elapsed := 0.0
var _cues: Array = []
var _next := 0


func _init(cues: Array, total: float) -> void:
	_cues = cues.duplicate()
	_cues.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	length = total


func advance(delta: float) -> bool:
	elapsed += delta
	while _next < _cues.size() and elapsed >= _cues[_next][0]:
		(_cues[_next][1] as Callable).call()
		_next += 1
	return elapsed >= length
