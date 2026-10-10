extends Node3D

const HEAT_DECAY := 4.0
const BARREL_FOLLOW := 2.4
const LIGHT_POOL := 4
const MAX_EMBEDDED := 8
const BLOOD_SPOT_DEPTH := 0.05
const BLOOD_MARGIN := 0.004

var holes: BulletHoles
var pools: FxPools
var splats: BloodSplats

var _embedded: Array[Node3D] = []
var _jacket_mat: StandardMaterial3D
var _heat := {}
var _follow: Array = []
var _lights: Array[OmniLight3D] = []
var _next_light := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	holes = BulletHoles.new()
	holes.name = "Holes"
	add_child(holes)
	pools = FxPools.new()
	pools.name = "Pools"
	add_child(pools)
	splats = BloodSplats.new()
	splats.name = "BloodSplats"
	add_child(splats)
	for i in LIGHT_POOL:
		var light := OmniLight3D.new()
		light.omni_range = 0.85
		light.light_color = Color(1.0, 0.72, 0.34)
		light.shadow_enabled = false
		light.visible = false
		add_child(light)
		_lights.append(light)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec() * 0.001
	for i in range(_follow.size() - 1, -1, -1):
		var entry: Array = _follow[i]
		var host = entry[1]
		if now > entry[2] or not is_instance_valid(host):
			_follow.remove_at(i)
			continue
		(entry[0] as GPUParticles3D).global_position = host.global_position


func clear() -> void:
	holes.clear()
	splats.clear()
	for node in _embedded:
		if is_instance_valid(node):
			node.queue_free()
	_embedded.clear()
	_follow.clear()
	_heat.clear()
	pools.stop_all()


func spawn_impact(point: Vector3, normal: Vector3, collider: Object, surface: String, is_exit: bool = false) -> void:
	if not ImpactProfiles.SURFACES.has(surface):
		push_error("ImpactFX sin perfil para material: " + surface)
		return
	var profile: Dictionary = ImpactProfiles.SURFACES[surface]
	var n := normal.normalized()
	var basis := _surface_basis(n)
	holes.punch(point, basis, collider, surface, is_exit)
	if _in_view(point + n * 0.02):
		for key in ["dust", "debris"]:
			if profile.has(key):
				pools.emit(surface + "/" + key, point + n * 0.006, basis, 0.75 if is_exit else 1.0)
		if not is_exit and profile.get("flash", false):
			_flash(point + n * 0.10)
	if is_exit:
		return
	GameAudio.play_3d(profile["sound"], point, profile["volume"], randf_range(0.92, 1.08))


func spawn_muzzle_smoke(at: Node3D, direction: Vector3) -> void:
	if at == null or not is_instance_valid(at):
		return
	var now := Time.get_ticks_msec() * 0.001
	var id := at.get_instance_id()
	var state: Vector2 = _heat.get(id, Vector2(0.0, now))
	var heat := state.x * exp(-(now - state.y) / HEAT_DECAY) + 1.0
	_heat[id] = Vector2(heat, now)
	var amount := clampf(0.5 + (heat - 1.0) / 4.0, 0.0, 1.0) * randf_range(0.7, 1.0)
	if amount >= 0.12 and _in_view(at.global_position):
		pools.emit("muzzle", at.global_position, _facing(direction.normalized()), amount)


func spawn_barrel_smoke(at: Node3D) -> void:
	if at == null or not is_instance_valid(at):
		return
	var p := pools.emit("barrel", at.global_position, _facing(Vector3.UP))
	_follow.append([p, at, Time.get_ticks_msec() * 0.001 + BARREL_FOLLOW])


func spawn_ejection_smoke(point: Vector3, direction: Vector3) -> void:
	if randf() < 0.3:
		pools.emit("ejection", point, _facing(direction.normalized()), randf_range(0.3, 0.7))


func spawn_blood_splash(point: Vector3, dir: Vector3) -> void:
	splats.splash(point, dir.normalized())


func spawn_blood_spot(point: Vector3, spot: Decal, dir: Vector3) -> void:
	if spot == null:
		return
	var basis := _surface_basis(dir).rotated(dir, randf_range(0.0, TAU))
	var size := Vector3(randf_range(0.34, 0.52), BLOOD_SPOT_DEPTH, randf_range(0.34, 0.52))
	var at := point - dir * (BLOOD_SPOT_DEPTH * 0.5 - BLOOD_MARGIN)
	spot.size = Vector3(0.09, BLOOD_SPOT_DEPTH, 0.09)
	spot.modulate = Color(1, 1, 1, 0.0)
	spot.visible = true
	spot.global_transform = Transform3D(basis, at)
	var grow := spot.create_tween()
	grow.tween_property(spot, "size", size, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	grow.parallel().tween_property(spot, "modulate:a", 0.92, 0.30)


func spawn_embedded(point: Vector3, direction: Vector3) -> void:
	if _jacket_mat == null:
		_jacket_mat = StandardMaterial3D.new()
		_jacket_mat.albedo_color = Color(0.55, 0.32, 0.18)
		_jacket_mat.metallic = 0.9
		_jacket_mat.roughness = 0.4
	var holder := Node3D.new()
	holder.name = "EmbeddedRound"
	add_child(holder)
	var dir := direction.normalized()
	var up := Vector3.RIGHT if absf(dir.dot(Vector3.UP)) > 0.94 else Vector3.UP
	var x_axis := up.cross(dir).normalized()
	holder.global_transform = Transform3D(Basis(x_axis, dir, x_axis.cross(dir).normalized()), point - dir * 0.004)
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0028
	cm.bottom_radius = 0.0045
	cm.height = 0.009
	cm.radial_segments = 10
	cm.material = _jacket_mat
	var nose := MeshInstance3D.new()
	nose.mesh = cm
	nose.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(nose)
	_embedded.append(holder)
	while _embedded.size() > MAX_EMBEDDED:
		var old_node: Node3D = _embedded.pop_front()
		if is_instance_valid(old_node):
			old_node.queue_free()


func _flash(at: Vector3) -> void:
	var light := _lights[_next_light]
	_next_light = (_next_light + 1) % _lights.size()
	light.global_position = at
	light.light_energy = 0.35
	light.visible = true
	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.045)
	tween.tween_callback(light.hide)


func _facing(dir: Vector3) -> Basis:
	return Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT)


func _surface_basis(n: Vector3) -> Basis:
	var up := Vector3.RIGHT if absf(n.dot(Vector3.UP)) > 0.94 else Vector3.UP
	var x_axis := up.cross(n).normalized()
	if x_axis.length_squared() < 0.01:
		x_axis = Vector3.RIGHT
	return Basis(x_axis, n, x_axis.cross(n).normalized())


func _in_view(point: Vector3) -> bool:
	var camera := get_viewport().get_camera_3d()
	return camera != null and camera.is_position_in_frustum(point) \
			and EnemySenses.clear(camera, camera.global_position, point)
