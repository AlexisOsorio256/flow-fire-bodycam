class_name EnemyBlood
extends Node3D

const DROP_TEXTURE: Texture2D = preload("res://assets/textures/particle_soft.png")
const MIST_TEXTURE: Texture2D = preload("res://assets/textures/muzzle_puff.png")
const DROP_COLOR := Color(0.46, 0.022, 0.018, 1.0)

static var _stain: ImageTexture
static var _spray_pm: ParticleProcessMaterial
static var _spray_quad: QuadMesh
static var _mist_pm: ParticleProcessMaterial
static var _mist_quad: QuadMesh

var _spray: GPUParticles3D
var _mist: GPUParticles3D
var _spot: Decal
var _pool: Decal
var _wound := Vector3.ZERO


func _ready() -> void:
	_spray = _build_spray()
	add_child(_spray)
	_mist = _build_mist()
	_spray.add_child(_mist)
	var stain := _stain_texture()
	_spot = Decal.new()
	_spot.texture_albedo = stain
	_spot.upper_fade = 0.0
	_spot.lower_fade = 0.5
	_spot.visible = false
	add_child(_spot)
	_pool = Decal.new()
	_pool.texture_albedo = stain
	_pool.upper_fade = 0.3
	_pool.lower_fade = 0.3
	_pool.visible = false
	_pool.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_pool)


func wound(point: Vector3, dir: Vector3, bones: Array) -> void:
	_wound = point
	_spray.global_position = point
	_spray.global_basis = Basis.looking_at(dir.normalized(), Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT)
	_spray.amount_ratio = 0.45
	_spray.restart()
	_mist.restart()
	ImpactFX.spawn_blood_spot(point, _spot, dir)
	ImpactFX.spawn_blood_splash(point, dir)
	anchor(bones)


func burst() -> void:
	_spray.amount_ratio = 1.0
	_spray.restart()
	_mist.restart()


func anchor(bones: Array) -> void:
	if not _spot.visible:
		return
	var best: Node3D = null
	var best_d := INF
	for bone: Node3D in bones:
		var d := bone.global_position.distance_to(_wound)
		if d < best_d:
			best_d = d
			best = bone
	if best != null and _spot.get_parent() != best:
		_spot.reparent(best, true)


func pool_under(chest: Vector3) -> void:
	var q := PhysicsRayQueryParameters3D.create(chest, chest + Vector3.DOWN * 1.5, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	_pool.top_level = true
	_pool.global_transform = Transform3D(Basis(Vector3.UP, randf() * TAU), hit.position)
	_pool.size = Vector3(0.2, 0.2, 0.2)
	_pool.modulate = Color(1, 1, 1, 0.0)
	_pool.visible = true
	var grow := _pool.create_tween()
	grow.tween_property(_pool, "size", Vector3(randf_range(0.8, 1.1), 0.3, randf_range(0.7, 1.0)), 9.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	grow.parallel().tween_property(_pool, "modulate:a", 0.95, 1.5)


func _build_spray() -> GPUParticles3D:
	if _spray_pm == null:
		_spray_pm = ParticleProcessMaterial.new()
		_spray_pm.direction = Vector3(0, 0, -1)
		_spray_pm.spread = 35.0
		_spray_pm.initial_velocity_min = 0.8
		_spray_pm.initial_velocity_max = 3.2
		_spray_pm.gravity = Vector3(0, -9.0, 0)
		_spray_pm.scale_min = 0.5
		_spray_pm.scale_max = 1.6
		_spray_pm.color = DROP_COLOR
		_spray_pm.damping_min = 0.6
		_spray_pm.damping_max = 1.6
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = DROP_TEXTURE
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.vertex_color_use_as_albedo = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_spray_quad = QuadMesh.new()
		_spray_quad.size = Vector2(0.045, 0.045)
		_spray_quad.material = mat
	var spray := GPUParticles3D.new()
	spray.name = "Spray"
	spray.amount = 24
	spray.lifetime = 0.9
	spray.one_shot = true
	spray.explosiveness = 1.0
	spray.local_coords = false
	spray.process_material = _spray_pm
	spray.draw_pass_1 = _spray_quad
	spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spray.emitting = false
	spray.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	return spray


func _build_mist() -> GPUParticles3D:
	if _mist_pm == null:
		_mist_pm = ParticleProcessMaterial.new()
		_mist_pm.direction = Vector3(0, 0, 1)
		_mist_pm.spread = 75.0
		_mist_pm.initial_velocity_min = 0.25
		_mist_pm.initial_velocity_max = 0.9
		_mist_pm.gravity = Vector3(0, -0.6, 0)
		_mist_pm.damping_min = 1.5
		_mist_pm.damping_max = 2.5
		_mist_pm.scale_min = 0.7
		_mist_pm.scale_max = 1.3
		var grow := Curve.new()
		grow.add_point(Vector2(0.0, 0.35))
		grow.add_point(Vector2(1.0, 1.0))
		var grow_tex := CurveTexture.new()
		grow_tex.curve = grow
		_mist_pm.scale_curve = grow_tex
		var fade := Gradient.new()
		fade.set_color(0, Color(0.78, 0.04, 0.035, 0.9))
		fade.set_color(1, Color(0.40, 0.02, 0.02, 0.0))
		var fade_tex := GradientTexture1D.new()
		fade_tex.gradient = fade
		_mist_pm.color_ramp = fade_tex
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = MIST_TEXTURE
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.vertex_color_use_as_albedo = true
		_mist_quad = QuadMesh.new()
		_mist_quad.size = Vector2(0.34, 0.34)
		_mist_quad.material = mat
	var mist := GPUParticles3D.new()
	mist.name = "Mist"
	mist.amount = 14
	mist.lifetime = 0.38
	mist.one_shot = true
	mist.explosiveness = 1.0
	mist.local_coords = false
	mist.process_material = _mist_pm
	mist.draw_pass_1 = _mist_quad
	mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mist.emitting = false
	mist.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	return mist


static func _stain_texture() -> ImageTexture:
	if _stain != null:
		return _stain
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var u := (float(x) + 0.5) / 32.0 - 1.0
			var v := (float(y) + 0.5) / 32.0 - 1.0
			var ang := atan2(v, u)
			var n := 0.5 + 0.5 * sin(ang * 5.0 + sin(ang * 3.0) * 2.0)
			var r := sqrt(u * u + v * v) * (1.0 + 0.22 * (n - 0.5))
			img.set_pixel(x, y, Color(0.22, 0.010, 0.008, 0.9 * smoothstep(0.95, 0.30, r)))
	img.generate_mipmaps()
	_stain = ImageTexture.create_from_image(img)
	return _stain
