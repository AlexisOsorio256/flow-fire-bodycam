class_name BloodSplats
extends Node3D

const POOL := 24
const REACH := 3.2
const SIZE := 96
const DEPTH := 0.3
const COLOR := Color(0.44, 0.02, 0.016, 0.95)

var _decals: Array[Decal] = []
var _textures: Array[ImageTexture] = []
var _next := 0


func _ready() -> void:
	for s in [11, 29, 47]:
		_textures.append(_splat(s))
	for i in POOL:
		var d := Decal.new()
		d.upper_fade = 0.2
		d.lower_fade = 0.2
		d.visible = false
		d.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(d)
		_decals.append(d)


func clear() -> void:
	for d in _decals:
		d.visible = false


func splash(point: Vector3, dir: Vector3) -> void:
	var space := get_world_3d().direct_space_state
	var back := space.intersect_ray(PhysicsRayQueryParameters3D.create(point + dir * 0.25, point + dir * REACH, 1))
	if not back.is_empty():
		var travel: float = point.distance_to(back.position)
		_place(back.position, back.normal, lerpf(0.30, 0.62, clampf(travel / REACH, 0.0, 1.0)))
	var drop := point + dir * randf_range(0.3, 0.9)
	var floor := space.intersect_ray(PhysicsRayQueryParameters3D.create(drop, drop + Vector3.DOWN * 2.5, 1))
	if not floor.is_empty():
		_place(floor.position, floor.normal, randf_range(0.22, 0.42))


func _place(at: Vector3, normal: Vector3, size: float) -> void:
	var d := _decals[_next]
	_next = (_next + 1) % _decals.size()
	var n := normal.normalized()
	var side := n.cross(Vector3.FORWARD if absf(n.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var basis := Basis(side, n, side.cross(n)).rotated(n, randf_range(0.0, TAU))
	d.global_transform = Transform3D(basis, at)
	d.size = Vector3(size, DEPTH, size * randf_range(0.7, 1.0))
	d.texture_albedo = _textures[randi() % _textures.size()]
	d.modulate = Color(1, 1, 1, randf_range(0.65, 0.9))
	d.visible = true


func _splat(seed: int) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var blobs := []
	for k in 14:
		var ang := rng.randf() * TAU
		var r := pow(rng.randf(), 1.6) * 0.75
		blobs.append([Vector2(cos(ang), sin(ang)) * r, lerpf(0.22, 0.05, r / 0.75)])
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var p := Vector2((x + 0.5) / SIZE * 2.0 - 1.0, (y + 0.5) / SIZE * 2.0 - 1.0)
			var a := smoothstep(0.55, 0.22, p.length())
			for b in blobs:
				a = maxf(a, smoothstep(b[1], b[1] * 0.4, p.distance_to(b[0])))
			img.set_pixel(x, y, Color(COLOR.r, COLOR.g, COLOR.b, COLOR.a * a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
