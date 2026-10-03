class_name WeaponFX
extends Node3D

const FLASH_TIME := 0.050
const CORE_DECAY := 4.0
const GAS_DECAY := 1.4
const GAS_GAIN := 1.55
const CORE_GAIN := 2.40

var muzzle_light: OmniLight3D
var world_flash: OmniLight3D
var flash_mesh: MeshInstance3D
var core_mesh: MeshInstance3D
var timer := 0.0
var _fresh_flash := false
var _muzzle_light_peak := 0.9
var _world_light_peak := 1.9

var _gas_mat: StandardMaterial3D
var _core_mat: StandardMaterial3D
var _gas_tint := Color(1.0, 0.62, 0.30)
var _core_tint := Color(1.0, 0.90, 0.72)


func build() -> void:
	muzzle_light = OmniLight3D.new()
	muzzle_light.light_color = Color(1.0, 0.97, 0.92)
	muzzle_light.light_energy = 0.0
	muzzle_light.visible = false
	muzzle_light.omni_range = 1.6
	muzzle_light.shadow_enabled = false
	muzzle_light.light_cull_mask = GlockViewmodel.VIEWMODEL_LAYER_BIT
	add_child(muzzle_light)
	world_flash = OmniLight3D.new()
	world_flash.light_color = Color(1.0, 0.75, 0.45)
	world_flash.light_energy = 0.0
	world_flash.visible = false
	world_flash.omni_range = 4.2
	world_flash.omni_attenuation = 1.1
	world_flash.shadow_enabled = false
	world_flash.light_cull_mask = 1
	add_child(world_flash)

	var flash_tex := _flash_texture()
	_gas_mat = _flash_material(flash_tex, _gas_tint)
	flash_mesh = MeshInstance3D.new()
	flash_mesh.name = "FlashGas"
	flash_mesh.mesh = _flash_quad(0.085, 0.085)
	flash_mesh.material_override = _gas_mat
	flash_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash_mesh.position = Vector3(0.0, 0.008, -0.014)
	flash_mesh.visible = false
	add_child(flash_mesh)

	_core_mat = _flash_material(flash_tex, _core_tint)
	core_mesh = MeshInstance3D.new()
	core_mesh.name = "FlashCore"
	core_mesh.mesh = _flash_quad(0.052, 0.052)
	core_mesh.material_override = _core_mat
	core_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core_mesh.position = Vector3(0.0, 0.008, -0.004)
	core_mesh.visible = false
	add_child(core_mesh)

	print("WEAPONFX fogonazo nucleo+gas en la boca del canon (-Z)")


func update(delta: float) -> void:
	if _fresh_flash:
		_fresh_flash = false
	else:
		timer = maxf(0.0, timer - delta)
	var lit := timer > 0.0
	if flash_mesh.visible != lit:
		flash_mesh.visible = lit
		core_mesh.visible = lit
	if muzzle_light != null and muzzle_light.visible != lit:
		muzzle_light.visible = lit
	if world_flash != null and world_flash.visible != lit:
		world_flash.visible = lit
	if not lit:
		if muzzle_light != null:
			muzzle_light.light_energy = 0.0
		if world_flash != null:
			world_flash.light_energy = 0.0
		return
	var f := timer / FLASH_TIME
	_gas_mat.albedo_color = _gas_tint * (GAS_GAIN * pow(f, GAS_DECAY))
	_core_mat.albedo_color = _core_tint * (CORE_GAIN * pow(f, CORE_DECAY))
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
	_world_light_peak = randf_range(1.7, 2.15)
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
	flash_mesh.visible = true
	core_mesh.visible = true


func _flash_texture() -> ImageTexture:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (x + 0.5) / float(n) * 2.0 - 1.0
			var v := (y + 0.5) / float(n) * 2.0 - 1.0
			var r := sqrt(u * u + v * v)
			var a := clampf(1.0 - r, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)
			a = pow(a, 1.25)
			var bar_x := clampf(1.0 - absf(v) * 11.0, 0.0, 1.0) * clampf(1.0 - absf(u) * 0.85, 0.0, 1.0)
			var bar_y := clampf(1.0 - absf(u) * 11.0, 0.0, 1.0) * clampf(1.0 - absf(v) * 0.85, 0.0, 1.0)
			a = minf(1.0, a + 0.30 * (bar_x + bar_y) * clampf(1.0 - r, 0.0, 1.0))
			a = minf(1.0, a + 0.10 * clampf(1.0 - r * 1.6, 0.0, 1.0))
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)


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
	return m


func _flash_quad(w: float, h: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	return q
