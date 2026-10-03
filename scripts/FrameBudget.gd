extends Node

## Presupuesto de cuadro: el juego va a 30 FPS fijos (application/run/max_fps)
## y la resolucion 3D se ajusta al tiempo real de GPU. Por encima del suelo
## de 30 el margen se invierte en resolucion, dejando holgura para los picos
## (humo, varios fogonazos); si la GPU se acerca al limite baja un escalon
## antes de perder el ritmo. Cambia como mucho cada VENTANA segundos:
## reasignar los buffers cuesta un cuadro.

const LEVELS := [0.67, 0.73, 0.8, 0.87, 0.93, 1.0]
const START := 2                 # 0,80: la configuracion de referencia
const HIGH_MS := 26.0            # por encima, baja un escalon
const LOW_MS := 18.0             # por debajo tres ventanas seguidas, sube uno
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
