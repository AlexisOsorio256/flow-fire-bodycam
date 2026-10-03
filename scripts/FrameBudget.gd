extends Node

const LEVELS := [0.87, 0.93, 1.0]
const START := 2
const HIGH_MS := 26.0
const LOW_MS := 18.0
const VENTANA := 1.5

var _level := START
var _sum := 0.0
var _n := 0
var _t := 0.0
var _calm := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_apply()


func _process(delta: float) -> void:
	var gpu := RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
	if gpu <= 0.0:
		return
	_sum += gpu
	_n += 1
	_t += delta
	if _t < VENTANA:
		return
	var avg := _sum / _n
	_sum = 0.0
	_n = 0
	_t = 0.0
	if avg > HIGH_MS and _level > 0:
		_level -= 1
		_calm = 0
		_apply()
	elif avg < LOW_MS and _level < LEVELS.size() - 1:
		_calm += 1
		if _calm >= 3:
			_calm = 0
			_level += 1
			_apply()
	else:
		_calm = 0


func _apply() -> void:
	get_viewport().scaling_3d_scale = LEVELS[_level]
