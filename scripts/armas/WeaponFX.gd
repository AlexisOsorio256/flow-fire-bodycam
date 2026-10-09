class_name WeaponFX
extends Node3D

const FLASH_ATLAS: Texture2D = preload("res://assets/textures/muzzle_flash.png")
const FLASH_VARIANTS := 4
const FLASH_TIME := 0.062
const CORE_DECAY := 4.0
const GAS_DECAY := 1.4
const GAS_GAIN := 3.4
const CORE_GAIN := 4.2
const GLOW_GAIN := 3.0
const GLOW_SIZE := 0.5
const SPARKS := 12

var muzzle_light: OmniLight3D
var world_flash: OmniLight3D
var flash_mesh: MeshInstance3D
var core_mesh: MeshInstance3D
var glow_mesh: MeshInstance3D
var sparks: CPUParticles3D
var world_lighting := true
var timer := 0.0
var _fresh_flash := false
var _muzzle_light_peak := 0.9
var _world_light_peak := 2.4

var _gas_mat: StandardMaterial3D
var _core_mat: StandardMaterial3D
var _glow_mat: StandardMaterial3D
var _gas_tint := Color(1.0, 0.85, 0.66)
var _core_tint := Color(1.0, 0.90, 0.72)


func build() -> void:
	muzzle_light = OmniLight3D.new()
	muzzle_light.light_color = Color(1.0, 0.97, 0.92)
	muzzle_light.light_energy = 0.0
	muzzle_light.visible = false
	muzzle_light.omni_range = 1.6
	muzzle_light.shadow_enabled = false
	muzzle_light.light_cull_mask = Viewmodel.VIEWMODEL_LAYER_BIT
	add_child(muzzle_light)
	world_flash = OmniLight3D.new()
	world_flash.light_color = Color(1.0, 0.75, 0.45)
	world_flash.light_energy = 0.0
	world_flash.visible = false
	world_flash.omni_range = 6.0
	world_flash.omni_attenuation = 1.1
	world_flash.shadow_enabled = false
	world_flash.light_cull_mask = 1 | EnemyModel.LAYER_BIT
	add_child(world_flash)

	var flash_tex: Texture2D = FLASH_ATLAS
	_gas_mat = _flash_material(flash_tex, _gas_tint)
	flash_mesh = MeshInstance3D.new()
	flash_mesh.name = "FlashGas"
	flash_mesh.mesh = _flash_quad(0.18, 0.18)
	flash_mesh.material_override = _gas_mat
	flash_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash_mesh.position = Vector3(0.0, 0.008, -0.014)
	flash_mesh.visible = false
	add_child(flash_mesh)

	_core_mat = _flash_material(flash_tex, _core_tint)
	core_mesh = MeshInstance3D.new()
	core_mesh.name = "FlashCore"
	core_mesh.mesh = _flash_quad(0.12, 0.12)
	core_mesh.material_override = _core_mat
	core_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core_mesh.position = Vector3(0.0, 0.008, -0.004)
	core_mesh.visible = false
	add_child(core_mesh)

	_glow_mat = _flash_material(_radial(), Color(1.0, 0.86, 0.62))
	_glow_mat.uv1_scale = Vector3.ONE
	glow_mesh = MeshInstance3D.new()
	glow_mesh.name = "FlashGlow"
	glow_mesh.mesh = _flash_quad(GLOW_SIZE, GLOW_SIZE)
	glow_mesh.material_override = _glow_mat
	glow_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow_mesh.position = Vector3(0.0, 0.0, -0.03)
	glow_mesh.visible = false
	add_child(glow_mesh)
	sparks = _build_sparks()
	add_child(sparks)


func update(delta: float) -> void:
	if _fresh_flash:
		_fresh_flash = false
	else:
		timer = maxf(0.0, timer - delta)
	var lit := timer > 0.0
	if flash_mesh.visible != lit:
		flash_mesh.visible = lit
		core_mesh.visible = lit
		glow_mesh.visible = lit
	if muzzle_light != null and muzzle_light.visible != lit:
		muzzle_light.visible = lit
	if world_flash != null and world_flash.visible != (lit and world_lighting):
		world_flash.visible = lit and world_lighting
	if not lit:
		if muzzle_light != null:
			muzzle_light.light_energy = 0.0
		if world_flash != null:
			world_flash.light_energy = 0.0
		return
	var f := timer / FLASH_TIME
	_gas_mat.albedo_color = _gas_tint * (GAS_GAIN * pow(f, GAS_DECAY))
	_core_mat.albedo_color = _core_tint * (CORE_GAIN * pow(f, CORE_DECAY))
	_glow_mat.albedo_color = Color(1.0, 0.86, 0.62) * (GLOW_GAIN * pow(f, 2.6))
	if muzzle_light != null:
		muzzle_light.light_energy = _muzzle_light_peak * f
	if world_flash != null:
		world_flash.light_energy = _world_light_peak * f * f


func fire(muzzle: Node3D, origin: Vector3, bore_dir: Vector3) -> void:
	pop_flash()
	ImpactFX.spawn_muzzle_smoke(muzzle, bore_dir)


func pop_flash() -> void:
	if flash_mesh == null:
		return
	timer = FLASH_TIME
	_fresh_flash = true
	_muzzle_light_peak = randf_range(0.78, 1.02)
	_world_light_peak = randf_range(2.8, 3.2)
	var variant := randi() % FLASH_VARIANTS
	_gas_mat.uv1_offset.x = float(variant) / FLASH_VARIANTS
	_core_mat.uv1_offset.x = float((variant + 1 + randi() % (FLASH_VARIANTS - 1)) % FLASH_VARIANTS) / FLASH_VARIANTS
	var roll := randf_range(-0.32, 0.32)
	flash_mesh.rotation = Vector3(0.0, 0.0, roll)
	core_mesh.rotation = Vector3(0.0, 0.0, roll)
	var sx := randf_range(1.6, 2.1)
	var sy := sx * randf_range(0.86, 1.18)
	flash_mesh.scale = Vector3(sx, sy, 1.0)
	flash_mesh.position = Vector3(randf_range(-0.004, 0.004), 0.008,
		-0.014 - randf_range(0.0, 0.008))
	core_mesh.scale = Vector3.ONE * randf_range(1.25, 1.55)
	_gas_mat.albedo_color = _gas_tint * GAS_GAIN
	_core_mat.albedo_color = _core_tint * CORE_GAIN
	_glow_mat.albedo_color = Color(1.0, 0.86, 0.62) * GLOW_GAIN
	glow_mesh.scale = Vector3(randf_range(0.8, 1.1), randf_range(1.1, 1.5), 1.0)
	glow_mesh.rotation = Vector3(0.0, 0.0, roll)
	flash_mesh.visible = true
	core_mesh.visible = true
	glow_mesh.visible = true
	sparks.restart()


func _flash_material(tex: Texture2D, tint: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = tex
	m.albedo_color = tint
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	m.uv1_scale = Vector3(1.0 / FLASH_VARIANTS, 1.0, 1.0)
	return m


func _build_sparks() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Sparks"
	p.emitting = false
	p.one_shot = true
	p.amount = SPARKS
	p.lifetime = 0.14
	p.explosiveness = 1.0
	p.randomness = 0.6
	p.local_coords = false
	p.direction = Vector3(0.0, 0.0, -1.0)
	p.spread = 24.0
	p.initial_velocity_min = 12.0
	p.initial_velocity_max = 26.0
	p.damping_min = 30.0
	p.damping_max = 60.0
	p.gravity = Vector3(0.0, -4.0, 0.0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	p.particle_flag_align_y = true
	var streak := BoxMesh.new()
	streak.size = Vector3(0.0035, 0.09, 0.0035)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, 0.72, 0.38) * 7.0
	m.disable_receive_shadows = true
	streak.material = m
	p.mesh = streak
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _radial() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.1, Color(1, 1, 1, 0.45))
	g.add_point(0.25, Color(1, 1, 1, 0.12))
	g.add_point(0.5, Color(1, 1, 1, 0.03))
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC
	var t := GradientTexture2D.new()
	t.use_hdr = true
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 256
	t.height = 256
	return t


func _flash_quad(w: float, h: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	return q
