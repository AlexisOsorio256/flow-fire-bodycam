class_name BodyCamExposure
extends RefCounted

const EXPOSURE_SUN := 1.4
const EXPOSURE_SHADE := 2.05
const ADAPT_SPEED := 0.15
const SAMPLE := 0.2
const SPREAD := 0.62
const REACH := 8.0

var exposure := EXPOSURE_SUN

var _env: Environment
var _space: PhysicsDirectSpaceState3D
var _query := PhysicsRayQueryParameters3D.new()
var _rays: Array[Vector3] = []
var _open := 1.0
var _clock := SAMPLE


func setup(camera: Camera3D) -> void:
	var world := camera.get_world_3d()
	_env = world.environment
	_space = world.direct_space_state
	_query.collision_mask = 1
	_query.hit_back_faces = false
	_rays.append(Vector3.UP)
	for i in 8:
		var angle := TAU * float(i) / 8.0
		_rays.append(Vector3(cos(angle) * SPREAD, 1.0, sin(angle) * SPREAD).normalized())


func update(delta: float, camera: Camera3D) -> void:
	if _env == null or _space == null:
		return
	_clock += delta
	if _clock >= SAMPLE:
		_clock = 0.0
		_measure(camera.global_position)
	var goal := lerpf(EXPOSURE_SHADE, EXPOSURE_SUN, _open)
	exposure += (goal - exposure) * (1.0 - exp(-delta / ADAPT_SPEED))
	_env.tonemap_exposure = exposure


func _measure(from: Vector3) -> void:
	var open := 0
	_query.from = from
	for ray in _rays:
		_query.to = from + ray * REACH
		if _space.intersect_ray(_query).is_empty():
			open += 1
	_open = float(open) / float(_rays.size())
