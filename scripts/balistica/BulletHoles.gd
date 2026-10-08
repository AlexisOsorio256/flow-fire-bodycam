class_name BulletHoles
extends Node3D

const MAX_HOLES := 192
const PER_SURFACE := 32
const MASK_SIZE := 96
const LIFT := 0.003

var _pool: Array[MeshInstance3D] = []
var _live: Array[Dictionary] = []
var _mats := {}
var _next := 0
static var _shape := PackedFloat32Array()


func _ready() -> void:
	for surface: String in ImpactProfiles.SURFACES:
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = _mask(ImpactProfiles.SURFACES[surface])
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 1.0
		mat.metallic_specular = 0.1
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_mats[surface] = mat
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE
	quad.material = _mats.values()[0]
	for i in MAX_HOLES:
		var hole := MeshInstance3D.new()
		hole.mesh = quad
		hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hole.visible = false
		add_child(hole)
		_pool.append(hole)


func clear() -> void:
	for hole in _pool:
		hole.visible = false
	_live.clear()


func punch(point: Vector3, basis: Basis, collider: Object, surface: String, is_exit: bool) -> void:
	var profile: Dictionary = ImpactProfiles.SURFACES[surface]
	var size: float = profile["hole"] * (profile["exit_scale"] if is_exit else 1.0)
	var hole := _pool[_next]
	_next = (_next + 1) % _pool.size()
	_live = _live.filter(func(h: Dictionary) -> bool: return h["hole"] != hole)
	hole.material_override = _mats[surface]
	hole.global_transform = Transform3D(basis.rotated(basis.y, randf_range(0.0, TAU)).scaled_local(Vector3(size, 1.0, size)),
		point + basis.y * LIFT)
	hole.visible = true
	_live.append({"hole": hole, "surface": collider})
	var count := 0
	for i in range(_live.size() - 1, -1, -1):
		if _live[i]["surface"] == collider:
			count += 1
			if count > PER_SURFACE:
				(_live[i]["hole"] as MeshInstance3D).visible = false
				_live.remove_at(i)


func _mask(profile: Dictionary) -> ImageTexture:
	var cavity: Color = profile["cavity"]
	var lip: Color = profile["lip"]
	var shape := _shape_table()
	var bytes := PackedByteArray()
	bytes.resize(MASK_SIZE * MASK_SIZE * 4)
	var i := 0
	for b in range(0, bytes.size(), 4):
		var color := (lip * shape[i]).lerp(cavity * shape[i + 2], shape[i + 1])
		bytes[b] = int(clampf(color.r, 0.0, 1.0) * 255.0)
		bytes[b + 1] = int(clampf(color.g, 0.0, 1.0) * 255.0)
		bytes[b + 2] = int(clampf(color.b, 0.0, 1.0) * 255.0)
		bytes[b + 3] = int(shape[i + 3] * 255.0)
		i += 4
	return ImageTexture.create_from_image(Image.create_from_data(MASK_SIZE, MASK_SIZE, false, Image.FORMAT_RGBA8, bytes))


static func _shape_table() -> PackedFloat32Array:
	if _shape.is_empty():
		_shape.resize(MASK_SIZE * MASK_SIZE * 4)
		var i := 0
		for y in MASK_SIZE:
			for x in MASK_SIZE:
				var u := (float(x) + 0.5) / float(MASK_SIZE) * 2.0 - 1.0
				var v := (float(y) + 0.5) / float(MASK_SIZE) * 2.0 - 1.0
				var r := sqrt(u * u + v * v)
				var angle := atan2(v, u)
				var noise := _fbm(cos(angle) * 3.1 + 5.0, sin(angle) * 3.1 + 5.0)
				var edge := 0.36 * (1.0 + 0.18 * (noise - 0.5))
				var hole := smoothstep(edge, edge - 0.10, r)
				var depth := 0.24 + 0.76 * smoothstep(0.0, maxf(edge, 0.01), r)
				var outer := 0.62 * (1.0 + 0.16 * (noise - 0.5))
				var chipped := smoothstep(edge - 0.05, edge + 0.02, r) * (1.0 - smoothstep(outer - 0.07, outer, r))
				_shape[i] = 0.72 + 0.28 * noise
				_shape[i + 1] = hole
				_shape[i + 2] = depth
				_shape[i + 3] = clampf(maxf(hole, chipped * 0.62), 0.0, 1.0)
				i += 4
	return _shape


static func _fbm(x: float, y: float) -> float:
	return _value_noise(x, y) * 0.65 + _value_noise(x * 2.7 + 11.3, y * 2.7 + 7.1) * 0.35


static func _value_noise(x: float, y: float) -> float:
	var xi := floori(x)
	var yi := floori(y)
	var xf := x - float(xi)
	var yf := y - float(yi)
	var sx := xf * xf * (3.0 - 2.0 * xf)
	var sy := yf * yf * (3.0 - 2.0 * yf)
	var a := _hash01(xi, yi)
	var b := _hash01(xi + 1, yi)
	var c := _hash01(xi, yi + 1)
	var d := _hash01(xi + 1, yi + 1)
	return lerpf(lerpf(a, b, sx), lerpf(c, d, sx), sy)


static func _hash01(a: int, b: int) -> float:
	var h := (a * 374761393 + b * 668265263) ^ 0x5BF03635
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFFFF) / float(0xFFFFFF)
