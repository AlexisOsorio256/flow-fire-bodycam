extends Node3D

const PLAN := [
	"................#...........",
	"......####......#..###......",
	"..C......................B..",
	"...##w###,###,##w####w##....",
	"...#,,,#,,,,#,#,,,,#,,,#....",
	".#.#,E,,,,,,#,,,E,,#,T,w..#.",
	".#.w,,,#,E,,,,#,,,,,,E,#..#.",
	".#.#,,,#,,,,#,#,,,,#,,,#..#.",
	"...##,####,##,##,####,##....",
	"...,,,E,,,,,,,,,,,,,,,,,....",
	"...##,####,##,##,####,##....",
	"...w,,,,#,,,#,#,,,#,,,,#....",
	".#.#,C,,#,E,#,,,,,#,,E,#.#..",
	".#.#,,,,,,,,,,#,E,,,,,,w.#..",
	".#.#,,,,#,,,#,#,,,#,,,,#.#..",
	".#.##,###,,,#,#,,,###,##.#..",
	"...#,,,,#,,,#,#,,,#,,,,#....",
	"...#,E,,,,T,,,#E,,,,,E,w....",
	"...w,,,,#,,,#,,,,,#,,B,#....",
	"...#,,,,#,,,#,#,,,#,,,,#....",
	"...##,####w##,##,###w###....",
	"............................",
	"............................",
	"..####...#.........#..####..",
	".........#...###...#........",
	".........#.........#......C.",
	"..B......................B..",
	"....####........###.........",
	"...........#..........#.....",
	"...........#..........#.....",
	".......##...................",
	".C.............A............",
	".............P..............",
	"............................",
]

const CELL := 1.2
const RESPAWN_DELAY := 12.0
const RELIEF_MIN := 9.0
const WALL_H := 2.44
const STUD := Vector2(0.038, 0.089)
const OSB_T := 0.011
const STUD_STEP := 0.406
const DOOR_H := 2.03
const SILL_H := 0.95
const SHEET_W := 1.22
const MARGIN := 2.4
const EAVE := 6.4
const RIDGE := 8.4
const BAY := 6.0
const CHUNK := 7.2

const MATS := {
	"osb": {"tex": "map/osb", "color": Color(1.0, 0.9, 0.78), "rough": 0.88, "tile": 1.22, "normal": 0.8, "matte": true},
	"deck": {"tex": "map/osb", "color": Color(1.0, 0.9, 0.78), "rough": 0.88, "tile": 1.22, "normal": 0.8, "matte": true, "flat": true},
	"stud": {"tex": "map/osb", "color": Color(1.0, 0.92, 0.78), "rough": 0.8, "tile": 3.0, "normal": 0.3, "matte": true},
	"floor": {"tex": "real/concrete_brushed_concrete", "color": Color(0.96, 0.92, 0.86), "rough": 0.9, "tile": 3.0, "normal": 0.5, "matte": true, "flat": true},
	"wall": {"tex": "real/concrete_brushed_concrete", "color": Color(0.88, 0.87, 0.85), "rough": 0.9, "tile": 2.5, "normal": 0.35, "matte": true},
	"clad": {"tex": "map/roof_steel", "color": Color(0.80, 0.82, 0.84), "rough": 0.6, "metal": 0.4, "tile": 2.0, "normal": 0.6},
	"roof": {"tex": "map/roof_steel", "color": Color(0.36, 0.37, 0.39), "rough": 0.7, "metal": 0.2, "tile": 2.0, "normal": 0.0},
	"rust": {"tex": "map/roof_steel", "color": Color(0.46, 0.19, 0.12), "rough": 0.7, "metal": 0.0, "tile": 1.5, "normal": 0.4},
	"steel": {"tex": "map/roof_steel", "color": Color(0.30, 0.31, 0.33), "rough": 0.5, "metal": 0.6, "tile": 1.5, "normal": 0.3},
	"tarp": {"tex": "enemy/fabric", "color": Color(0.12, 0.12, 0.13), "rough": 0.95, "tile": 0.8, "normal": 1.0},
	"joint": {"tex": "", "color": Color(0.20, 0.19, 0.18), "rough": 1.0, "tile": 1.0, "flat": true},
	"light": {"tex": "", "color": Color(1, 1, 1), "rough": 0.4, "tile": 1.0, "emit": Color(1.0, 0.98, 0.94), "energy": 6.0},
	"sky": {"tex": "", "color": Color(1, 1, 1), "rough": 0.4, "tile": 1.0, "emit": Color(0.92, 0.96, 1.0), "energy": 9.0},
}
const ENV := {"exposure": 3.3, "ambient": 0.45, "sky": 1.4, "contrib": 0.5, "color": Color(0.92, 0.84, 0.74)}
const POOL_BASE := 0.72
const POOL_RADIUS := 5.0

var ammo: AmmoTable
var _spawn := {"pos": Vector3.ZERO, "yaw": 0.0}
var _posts: Array[Vector3] = []
var _wave := 0
var _size := Vector2.ZERO
var _st := {}
var _mats := {}
var _occluder_verts := PackedVector3Array()
var _occluder_idx := PackedInt32Array()
var _walls: Array = []
var _env: Environment
var _env_origin := {}
var _rng := RandomNumberGenerator.new()
var _fixtures: Array[Vector2] = []


func spawn_point() -> Dictionary:
	return _spawn


func build() -> void:
	_rng.seed = 8
	_size = Vector2(PLAN[0].length(), PLAN.size()) * CELL
	_environment()
	_place_fixtures()
	_read_plan()
	_hall()
	_floor()
	_commit_meshes()
	_occluders()
	_nav_region = _navigation()
	_lights()
	get_viewport().use_occlusion_culling = true


var _nav_region: NavigationRegion3D


func _cell_pos(r: int, c: int) -> Vector3:
	return Vector3((c - (PLAN[0].length() - 1) * 0.5) * CELL, 0.0, (r - (PLAN.size() - 1) * 0.5) * CELL)


func _at(r: int, c: int) -> String:
	if r < 0 or r >= PLAN.size() or c < 0 or c >= PLAN[0].length():
		return ""
	return PLAN[r][c]


func _read_plan() -> void:
	for r in PLAN.size():
		for c in PLAN[r].length():
			var ch: String = PLAN[r][c]
			var p := _cell_pos(r, c)
			match ch:
				",", "E", "T", "B", "C", "#", "w":
					if _osb_floor(r, c):
						_osb_tile(p, r, c)
			match ch:
				"P":
					_spawn = {"pos": p + Vector3(0, 0.05, 0), "yaw": 0.0}
				"E":
					_posts.append(p)
				"A":
					ammo = AmmoTable.new()
					ammo.name = "AmmoTable"
					ammo.position = p
					add_child(ammo)
				"B":
					_barrel(p)
				"C":
					_pallets(p)
				"T":
					_box("tarp", Transform3D(Basis(Vector3.UP, _rng.randf_range(-0.3, 0.3)), p + Vector3(0, 0.035, 0)),
						Vector3(1.9, 0.05, 1.0), true)
	for r in PLAN.size():
		var c := 0
		while c < PLAN[r].length():
			if _at(r, c) != "#":
				c += 1
				continue
			var c1 := c
			while _at(r, c1 + 1) == "#":
				c1 += 1
			var alone := c1 == c and _at(r - 1, c) != "#" and _at(r + 1, c) != "#"
			if c1 > c or alone:
				_wall(_cell_pos(r, c), _cell_pos(r, c1), alone, r, _free(r, c, r, c1))
			c = c1 + 1
	for c in PLAN[0].length():
		var r := 0
		while r < PLAN.size():
			if _at(r, c) != "#":
				r += 1
				continue
			var r1 := r
			while _at(r1 + 1, c) == "#":
				r1 += 1
			if r1 > r:
				_wall(_cell_pos(r, c), _cell_pos(r1, c), false, c, _free(r, c, r1, c))
			r = r1 + 1
	for r in PLAN.size():
		for c in PLAN[r].length():
			if _at(r, c) == "#":
				continue
			var win: bool = PLAN[r][c] == "w"
			if _at(r, c - 1) == "#" and _at(r, c + 1) == "#" and _at(r - 1, c) != "#":
				_opening(_cell_pos(r, c - 1), _cell_pos(r, c + 1), r, win)
			elif _at(r - 1, c) == "#" and _at(r + 1, c) == "#" and _at(r, c - 1) != "#":
				_opening(_cell_pos(r - 1, c), _cell_pos(r + 1, c), c, win)


func _free(r0: int, c0: int, r1: int, c1: int) -> bool:
	for r in range(r0 - 1, r1 + 2):
		for c in range(c0 - 1, c1 + 2):
			if _at(r, c) == ",":
				return false
	return true


func _osb_floor(r: int, c: int) -> bool:
	return PLAN[r][c] != "." and (PLAN[r][c] == "," or _at(r, c - 1) == "," or _at(r, c + 1) == "," \
		or _at(r - 1, c) == "," or _at(r + 1, c) == ",")


func _osb_tile(p: Vector3, r: int, c: int) -> void:
	var xf := Transform3D(Basis.IDENTITY, p + Vector3(0, 0.009, 0))
	var tint := 0.62 + 0.03 * float((r * 7 + c * 13) % 5) / 4.0
	_box("deck", xf, Vector3(CELL - 0.004, 0.018, CELL - 0.004), false, Color(tint, tint, tint))


func _wall(a: Vector3, b: Vector3, alone: bool, line: int, free: bool) -> void:
	var along := (b - a).normalized() if a.distance_to(b) > 0.01 else Vector3.RIGHT
	var length := CELL if alone else a.distance_to(b) + STUD.y + 0.01
	_panel((a + b) * 0.5, along, length, 0.0, WALL_H, line, true)
	if free:
		var side := 1.0 if line % 2 == 0 else -1.0
		var out := along.cross(Vector3.UP) * -side
		var u := -length * 0.5 + 0.3
		while u < length * 0.5:
			var top := (a + b) * 0.5 + along * u + out * 0.06 + Vector3(0, 1.7, 0)
			var foot := top + out * 1.0 - Vector3(0, 1.7, 0)
			var dir := (foot - top).normalized()
			var bb := Basis(dir, along.cross(dir).normalized(), along)
			_box("stud", Transform3D(bb.orthonormalized(), (top + foot) * 0.5), Vector3(top.distance_to(foot), STUD.y, STUD.x), true)
			_box("stud", Transform3D(Basis(along, Vector3.UP, along.cross(Vector3.UP)), foot + Vector3(0, STUD.x * 0.5, 0) - out * 0.15),
				Vector3(STUD.x, STUD.x, 0.45), true)
			u += 1.2
	var ext := along * (length - a.distance_to(b)) * 0.5
	_walls.append([Vector2(a.x - ext.x, a.z - ext.z), Vector2(b.x + ext.x, b.z + ext.z)])


func _panel(mid: Vector3, along: Vector3, length: float, y0: float, y1: float, line: int, top: bool) -> void:
	var basis := Basis(along, Vector3.UP, along.cross(Vector3.UP))
	var side := 1.0 if line % 2 == 0 else -1.0
	var xf := Transform3D(basis, mid)
	var back := Vector3(0, 0, -side * OSB_T * 0.5)
	var plates := [y0 + STUD.x * 0.5]
	if top:
		plates.append_array([y1 - STUD.x * 1.5, y1 - STUD.x * 0.5])
	else:
		plates.append(y1 - STUD.x * 0.5)
	for y in plates:
		_box("stud", xf * Transform3D(Basis.IDENTITY, back + Vector3(0, y, 0)), Vector3(length, STUD.x, STUD.y), true)
	var h := y1 - y0 - STUD.x * plates.size()
	var yc := y0 + STUD.x + h * 0.5
	var us := []
	var n := int(ceil((length - STUD.x) / STUD_STEP))
	for i in n + 1:
		us.append(-length * 0.5 + STUD.x * 0.5 + minf(i * STUD_STEP, length - STUD.x))
	if length > 0.5:
		us.append_array([-length * 0.5 + STUD.x * 1.5, length * 0.5 - STUD.x * 1.5])
	for u in us:
		_box("stud", xf * Transform3D(Basis.IDENTITY, back + Vector3(u, yc, 0)),
			Vector3(STUD.x, h, STUD.y), true, Color.WHITE, true)
	var u0 := -length * 0.5
	while u0 < length * 0.5 - 0.01:
		var w := minf(SHEET_W, length * 0.5 - u0)
		var shade := _rng.randf_range(0.86, 1.0)
		_box("osb", xf * Transform3D(Basis.IDENTITY, Vector3(u0 + w * 0.5, (y0 + y1) * 0.5, side * STUD.y * 0.5)),
			Vector3(w - 0.003, y1 - y0, OSB_T), true, Color(shade, shade * 0.98, shade * 0.95))
		u0 += SHEET_W
	var box := Transform3D(basis, mid + Vector3(0, (y0 + y1) * 0.5, 0))
	_collider(box, Vector3(length, y1 - y0, STUD.y + OSB_T), "pine",
		{"penetrable": true, "thin_shell": true, "wall_thickness": 0.12})
	_occluder_quad(box, Vector2(length, y1 - y0))


func _opening(a: Vector3, b: Vector3, line: int, window: bool) -> void:
	var along := (b - a).normalized()
	var mid := (a + b) * 0.5
	var span := a.distance_to(b) - STUD.y
	var w := 0.95
	var stub := (span - w) * 0.5
	for s in [-1.0, 1.0]:
		_panel(mid + along * s * (w + stub) * 0.5, along, stub, 0.0, WALL_H, line, true)
	_panel(mid, along, w, DOOR_H, WALL_H, line, true)
	var basis := Basis(along, Vector3.UP, along.cross(Vector3.UP))
	_box("stud", Transform3D(basis, mid + Vector3(0, DOOR_H - 0.09, 0)), Vector3(w + STUD.x * 2.0, 0.18, STUD.y), true)
	if window:
		_panel(mid, along, w, 0.0, SILL_H, line, false)


func _hall() -> void:
	var hx := _size.x * 0.5 + MARGIN
	var hz := _size.y * 0.5 + MARGIN
	var slope := atan2(RIDGE - EAVE, hx)
	for s in [-1.0, 1.0]:
		for axis in [0, 1]:
			var half := hz if axis == 0 else hx
			var off := hx if axis == 0 else hz
			var basis := Basis(Vector3(0, 0, 1), Vector3.UP, Vector3(-1, 0, 0)) if axis == 0 else Basis.IDENTITY
			var origin := Vector3(s * (off + 0.1), 0, 0) if axis == 0 else Vector3(0, 0, s * (off + 0.1))
			var xf := Transform3D(basis, origin)
			_box("wall", xf * Transform3D(Basis.IDENTITY, Vector3(0, 0.6, 0)), Vector3(half * 2.0 + 0.4, 1.2, 0.2), true)
			_box("clad", xf * Transform3D(Basis.IDENTITY, Vector3(0, 2.4, 0)), Vector3(half * 2.0 + 0.4, 2.4, 0.06), false, Color.WHITE, true)
			_box("sky", xf * Transform3D(Basis.IDENTITY, Vector3(0, 4.3, 0.02)), Vector3(half * 2.0, 1.4, 0.02), false)
			_box("clad", xf * Transform3D(Basis.IDENTITY, Vector3(0, (5.0 + EAVE) * 0.5 + 0.5, 0)), Vector3(half * 2.0 + 0.4, EAVE - 4.0, 0.06), false, Color.WHITE, true)
			var u := -half
			while u <= half + 0.01:
				_box("steel", xf * Transform3D(Basis.IDENTITY, Vector3(u, 4.3, -0.03)), Vector3(0.06, 1.45, 0.06), false)
				u += CELL
			for y in [3.6, 5.0]:
				_box("steel", xf * Transform3D(Basis.IDENTITY, Vector3(0, y, -0.06)), Vector3(half * 2.0, 0.08, 0.1), false)
			_collider(Transform3D(basis, origin + Vector3(0, EAVE * 0.5, 0)), Vector3(half * 2.0 + 0.4, EAVE, 0.2), "steel", {})
	for s in [-1.0, 1.0]:
		for i in 6:
			var x0 := -hx + i * hx / 3.0
			var x1 := x0 + hx / 3.0
			var yc := EAVE + (RIDGE - EAVE) * (1.0 - absf((x0 + x1) * 0.5) / hx)
			_box("clad", Transform3D(Basis.IDENTITY, Vector3((x0 + x1) * 0.5, (EAVE + yc) * 0.5, s * (hz + 0.1))),
				Vector3(x1 - x0, yc - EAVE + 0.2, 0.06), false, Color.WHITE, true)
	var run := hx / cos(slope)
	for s in [-1.0, 1.0]:
		var basis := Basis(Vector3(0, 0, 1), -s * slope)
		var bands := 6
		for z0 in range(int(-hz / BAY) - 1, int(hz / BAY) + 1):
			var zc := (z0 + 0.5) * BAY
			if absf(zc) > hz + BAY * 0.5:
				continue
			for k in bands:
				var d := (k + 0.5) / bands * run
				var center := Vector3(s * (d * cos(slope)), RIDGE - d * sin(slope) + 0.08, zc)
				var xf := Transform3D(basis, center)
				var sky := k % 2 == 1
				if sky:
					_box("roof", xf * Transform3D(Basis.IDENTITY, Vector3(0, 0, -BAY * 0.35)), Vector3(run / bands, 0.04, BAY * 0.3), false)
					_box("roof", xf * Transform3D(Basis.IDENTITY, Vector3(0, 0, BAY * 0.35)), Vector3(run / bands, 0.04, BAY * 0.3), false)
					_box("sky", xf * Transform3D(Basis.IDENTITY, Vector3(0, 0.03, 0)), Vector3(run / bands, 0.01, BAY * 0.4), false)
				else:
					_box("roof", xf, Vector3(run / bands + 0.02, 0.04, BAY), false)
		for k in 9:
			var d := (k + 0.5) / 9.0 * run
			_box("rust", Transform3D(basis, Vector3(s * d * cos(slope), RIDGE - d * sin(slope) - 0.1, 0)),
				Vector3(0.08, 0.16, hz * 2.0), false)
	var z := -hz + BAY * 0.5
	while z < hz:
		_truss(z, hx, slope)
		for s in [-1.0, 1.0]:
			_box("rust", Transform3D(Basis.IDENTITY, Vector3(s * (hx - 0.15), EAVE * 0.5, z)), Vector3(0.22, EAVE, 0.3), false)
		z += BAY
	_collider(Transform3D(Basis.IDENTITY, Vector3(0, -0.25, 0)), Vector3(hx * 2.0, 0.5, hz * 2.0), "concrete", {})


func _truss(z: float, hx: float, slope: float) -> void:
	var low := EAVE - 0.1
	_bar(Vector3(-hx, low, z), Vector3(hx, low, z), 0.14)
	_bar(Vector3(-hx, EAVE + 0.05, z), Vector3(0, RIDGE - 0.2, z), 0.16)
	_bar(Vector3(hx, EAVE + 0.05, z), Vector3(0, RIDGE - 0.2, z), 0.16)
	var panels := 16
	for i in panels + 1:
		var x := -hx + 2.0 * hx * i / panels
		var top := EAVE + 0.05 + (RIDGE - 0.2 - EAVE - 0.05) * (1.0 - absf(x) / hx)
		_bar(Vector3(x, low, z), Vector3(x, top, z), 0.06)
		if i < panels:
			var xn := -hx + 2.0 * hx * (i + 1) / panels
			var topn := EAVE + 0.05 + (RIDGE - 0.2 - EAVE - 0.05) * (1.0 - absf(xn) / hx)
			if (i < panels / 2) == (i % 2 == 0):
				_bar(Vector3(x, low, z), Vector3(xn, topn, z), 0.05)
			else:
				_bar(Vector3(x, top, z), Vector3(xn, low, z), 0.05)
	for x in [-hx * 0.62, -hx * 0.2, hx * 0.2, hx * 0.62]:
		_box("steel", Transform3D(Basis.IDENTITY, Vector3(x, low - 0.12, z + 0.9)), Vector3(0.3, 0.06, 1.3), false)
		_box("light", Transform3D(Basis.IDENTITY, Vector3(x, low - 0.16, z + 0.9)), Vector3(0.18, 0.03, 1.2), false)


func _bar(a: Vector3, b: Vector3, w: float) -> void:
	var dir := (b - a).normalized()
	var side := Vector3(0, 0, 1)
	var basis := Basis(dir, side.cross(dir).normalized(), side)
	_box("rust", Transform3D(basis, (a + b) * 0.5), Vector3(a.distance_to(b), w, w * 0.8), false)


func _barrel(p: Vector3) -> void:
	for i in 2:
		var q := p + Vector3(0.32 * (i * 2 - 1), 0, 0)
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.29
		mesh.bottom_radius = 0.29
		mesh.height = 0.88
		mesh.radial_segments = 14
		mesh.rings = 1
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = _material("rust" if i == 0 else "steel")
		mi.position = q + Vector3(0, 0.44, 0)
		add_child(mi)
		var shape := CylinderShape3D.new()
		shape.radius = 0.29
		shape.height = 0.88
		_collider(Transform3D(Basis.IDENTITY, q + Vector3(0, 0.44, 0)), Vector3.ZERO, "steel",
			{"penetrable": true, "thin_shell": true, "wall_thickness": 0.0012}, shape)


func _pallets(p: Vector3) -> void:
	var layers := _rng.randi_range(3, 6)
	var rot := Basis(Vector3.UP, _rng.randf_range(-0.2, 0.2))
	for l in layers:
		var y := l * 0.145
		for k in 5:
			_box("stud", Transform3D(rot, p + rot * Vector3(-0.5 + k * 0.25, y + 0.13, 0)), Vector3(0.1, 0.02, 1.2), false)
		for k in 3:
			_box("stud", Transform3D(rot, p + rot * Vector3(0, y + 0.06, -0.5 + k * 0.5)), Vector3(1.0, 0.1, 0.09), true)
	_collider(Transform3D(rot, p + Vector3(0, layers * 0.0725, 0)), Vector3(1.0, layers * 0.145, 1.2), "pine",
		{"penetrable": true})


func _floor() -> void:
	var hx := _size.x * 0.5 + MARGIN
	var hz := _size.y * 0.5 + MARGIN
	var step := 0.6
	var nx := int(ceil(hx * 2.0 / step))
	var nz := int(ceil(hz * 2.0 / step))
	var ao := PackedFloat32Array()
	ao.resize((nx + 1) * (nz + 1))
	for j in nz + 1:
		for i in nx + 1:
			var q := Vector2(-hx + i * step, -hz + j * step)
			var d := minf(minf(q.x + hx, hx - q.x), minf(q.y + hz, hz - q.y))
			for w in _walls:
				d = minf(d, Geometry2D.get_closest_point_to_segment(q, w[0], w[1]).distance_to(q))
			ao[j * (nx + 1) + i] = _pool(q.x, q.y) * (1.0 - 0.42 * exp(-maxf(d - 0.05, 0.0) / 0.35))
	for j in nz:
		for i in nx:
			var x0 := -hx + i * step
			var z0 := -hz + j * step
			var st := _surface("floor", Vector3(x0, 0.0, z0))
			var a := ao[j * (nx + 1) + i]
			var b := ao[j * (nx + 1) + i + 1]
			var c := ao[(j + 1) * (nx + 1) + i + 1]
			var d2 := ao[(j + 1) * (nx + 1) + i]
			_quad(st, "floor", [Vector3(x0, 0, z0), Vector3(x0 + step, 0, z0),
				Vector3(x0 + step, 0, z0 + step), Vector3(x0, 0, z0 + step)], Vector3.UP,
				[Color(a, a, a), Color(b, b, b), Color(c, c, c), Color(d2, d2, d2)])
	var z := -hz + BAY
	while z < hz:
		_box("joint", Transform3D(Basis.IDENTITY, Vector3(0, 0.001, z)), Vector3(hx * 2.0, 0.002, 0.012), false)
		z += BAY
	var x := -hx + BAY
	while x < hx:
		_box("joint", Transform3D(Basis.IDENTITY, Vector3(x, 0.001, 0)), Vector3(0.012, 0.002, hz * 2.0), false)
		x += BAY


func _surface(mat: String, at: Vector3) -> SurfaceTool:
	var key := "%s|%d|%d" % [mat, floori(at.x / CHUNK), floori(at.z / CHUNK)]
	if not _st.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_st[key] = st
	return _st[key]


func _place_fixtures() -> void:
	var hx := _size.x * 0.5 + MARGIN
	var z := -_size.y * 0.5 - MARGIN + BAY * 0.5
	while z < _size.y * 0.5 + MARGIN:
		for x in [-hx * 0.62, -hx * 0.2, hx * 0.2, hx * 0.62]:
			_fixtures.append(Vector2(x, z + 0.9))
		z += BAY


func _pool(x: float, z: float) -> float:
	var sum := 0.0
	for f in _fixtures:
		var d2 := (f.x - x) * (f.x - x) + (f.y - z) * (f.y - z)
		sum += 1.0 / (1.0 + d2 / (POOL_RADIUS * POOL_RADIUS))
	return lerpf(POOL_BASE, 1.0, clampf(sum - 0.6, 0.0, 1.0))


func _box(mat: String, xf: Transform3D, size: Vector3, ao: bool, tint := Color.WHITE, rot := false) -> void:
	var st := _surface(mat, xf.origin)
	var h := size * 0.5
	var pool := _pool(xf.origin.x, xf.origin.z) if ao else 1.0
	for axis in 3:
		for s in [-1.0, 1.0]:
			var n := Vector3.ZERO
			n[axis] = s
			var u := Vector3.ZERO
			u[(axis + 1) % 3] = 1.0
			var v := Vector3.ZERO
			v[(axis + 2) % 3] = 1.0
			var c := n * h[axis]
			var du := u * h[(axis + 1) % 3]
			var dv := v * h[(axis + 2) % 3]
			var pts := [xf * (c - du - dv), xf * (c + du - dv), xf * (c + du + dv), xf * (c - du + dv)]
			var cols := []
			for p in pts:
				var k := pool * (1.0 - 0.5 * (1.0 - smoothstep(0.0, 0.7, p.y))) if ao else 1.0
				cols.append(Color(tint.r * k, tint.g * k, tint.b * k))
			_quad(st, mat, pts, (xf.basis * n).normalized(), cols, rot)


func _quad(st: SurfaceTool, mat: String, pts: Array, n: Vector3, cols: Array, rot := false) -> void:
	var tile: float = MATS[mat]["tile"]
	var order := [0, 1, 2, 0, 2, 3]
	if ((pts[1] - pts[0]).cross(pts[2] - pts[0])).dot(n) > 0.0:
		order = [0, 2, 1, 0, 3, 2]
	for i in order:
		var p: Vector3 = pts[i]
		var uv: Vector2
		if absf(n.y) >= absf(n.x) and absf(n.y) >= absf(n.z):
			uv = Vector2(p.x, p.z)
		elif absf(n.x) >= absf(n.z):
			uv = Vector2(p.z, -p.y)
		else:
			uv = Vector2(p.x, -p.y)
		if rot:
			uv = Vector2(uv.y, uv.x)
		st.set_color(cols[i])
		st.set_normal(n)
		st.set_uv(uv / tile)
		st.add_vertex(p)


func _commit_meshes() -> void:
	for key: String in _st:
		var mat := key.get_slice("|", 0)
		var st: SurfaceTool = _st[key]
		if MATS[mat].get("normal", 0.0) > 0.0:
			st.generate_tangents()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = _material(mat)
		if MATS[mat].has("emit") or MATS[mat].get("flat", false):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	_st.clear()


func _material(key: String) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var spec: Dictionary = MATS[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = spec["color"]
	mat.roughness = spec["rough"]
	mat.metallic = spec.get("metal", 0.0)
	mat.metallic_specular = 0.5 if mat.metallic > 0.0 else 0.25
	mat.vertex_color_use_as_albedo = true
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if spec.get("matte", false):
		mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if spec["tex"] != "":
		var base := "res://assets/textures/%s_" % spec["tex"]
		mat.albedo_texture = load(base + "diff.jpg")
		mat.roughness_texture = load(base + "rough.jpg")
		if spec.get("normal", 0.0) > 0.0:
			mat.normal_enabled = true
			mat.normal_texture = load(base + "nor_gl.jpg")
			mat.normal_scale = spec["normal"]
	if spec.has("emit"):
		mat.emission_enabled = true
		mat.emission = spec["emit"]
		mat.emission_energy_multiplier = spec["energy"]
	_mats[key] = mat
	return mat


func _collider(xf: Transform3D, size: Vector3, surface: String, meta: Dictionary, shape: Shape3D = null) -> void:
	var body := StaticBody3D.new()
	body.set_meta("surface", surface)
	for k in meta:
		body.set_meta(k, meta[k])
	var cs := CollisionShape3D.new()
	if shape == null:
		var box := BoxShape3D.new()
		box.size = size
		shape = box
	cs.shape = shape
	cs.transform = xf
	body.add_child(cs)
	add_child(body)


func _occluder_quad(xf: Transform3D, size: Vector2) -> void:
	var i := _occluder_verts.size()
	for p in [Vector3(-1, -1, 0), Vector3(1, -1, 0), Vector3(1, 1, 0), Vector3(-1, 1, 0)]:
		_occluder_verts.append(xf * Vector3(p.x * size.x * 0.5, p.y * size.y * 0.5, 0))
	_occluder_idx.append_array([i, i + 1, i + 2, i, i + 2, i + 3, i, i + 2, i + 1, i, i + 3, i + 2])


func _occluders() -> void:
	var occ := ArrayOccluder3D.new()
	occ.set_arrays(_occluder_verts, _occluder_idx)
	var inst := OccluderInstance3D.new()
	inst.occluder = occ
	add_child(inst)


func _navigation() -> NavigationRegion3D:
	var region := NavigationRegion3D.new()
	var nav := NavigationMesh.new()
	nav.agent_radius = Enemy.NAV_RADIUS
	nav.agent_height = 1.8
	nav.agent_max_climb = 0.35
	nav.cell_size = 0.15
	nav.cell_height = 0.15
	nav.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav.geometry_collision_mask = 1
	nav.filter_baking_aabb = AABB(Vector3(-60, -1, -60), Vector3(120, 3, 120))
	region.navigation_mesh = nav
	add_child(region)
	NavigationServer3D.map_set_cell_size(get_world_3d().navigation_map, nav.cell_size)
	NavigationServer3D.map_set_cell_height(get_world_3d().navigation_map, nav.cell_height)
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nav, src, self)
	NavigationServer3D.bake_from_source_geometry_data(nav, src)
	return region


func _lights() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -32, 0)
	sun.light_color = Color(1.0, 0.94, 0.84)
	sun.light_energy = 2.6
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	sun.shadow_enabled = true
	sun.shadow_bias = 0.06
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 24.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)


func _environment() -> void:
	var world := get_viewport().find_world_3d()
	_env = world.environment if world != null else null
	if _env == null:
		return
	_env_origin = {"exposure": _env.tonemap_exposure, "ambient": _env.ambient_light_energy,
		"sky": _env.background_energy_multiplier, "contrib": _env.ambient_light_sky_contribution,
		"color": _env.ambient_light_color, "reflect": _env.reflected_light_source}
	_env.tonemap_exposure = ENV["exposure"]
	_env.ambient_light_energy = ENV["ambient"]
	_env.background_energy_multiplier = ENV["sky"]
	_env.ambient_light_sky_contribution = ENV["contrib"]
	_env.ambient_light_color = ENV["color"]
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED


func _exit_tree() -> void:
	if _env == null:
		return
	_env.tonemap_exposure = _env_origin["exposure"]
	_env.ambient_light_energy = _env_origin["ambient"]
	_env.background_energy_multiplier = _env_origin["sky"]
	_env.ambient_light_sky_contribution = _env_origin["contrib"]
	_env.ambient_light_color = _env_origin["color"]
	_env.reflected_light_source = _env_origin["reflect"]


func clear() -> void:
	_wave += 1
	for e in get_tree().get_nodes_in_group("enemy"):
		e.remove_from_group("enemy")
		e.queue_free()
	if ammo != null:
		ammo.refill()


func populate() -> void:
	for i in _posts.size():
		_spawn_enemy(i + 1, _posts[i])


func _spawn_enemy(index: int, p: Vector3) -> void:
	var target: Vector3 = _spawn["pos"]
	var enemy := Enemy.new()
	enemy.name = "Enemy%d" % index
	enemy.position = p
	enemy.rotation.y = atan2(target.x - p.x, target.z - p.z) + _rng.randf_range(-0.6, 0.6)
	enemy.nav_map = _nav_region.get_navigation_map()
	add_child(enemy)
	enemy.call_deferred("_connect_nav")
	enemy.killed.connect(_on_enemy_killed.bind(index))


func _on_enemy_killed(corpse: Node3D, index: int) -> void:
	var wave := _wave
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	if wave != _wave:
		return
	_spawn_enemy(index, _relief_post())
	if is_instance_valid(corpse):
		corpse.queue_free()


func _relief_post() -> Vector3:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return _posts[_rng.randi() % _posts.size()]
	var eye := player.global_position + Vector3.UP * 1.5
	var best := _posts[0]
	var best_score := -INF
	for p in _posts:
		var d := p.distance_to(player.global_position)
		var seen := get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(eye, p + Vector3.UP * 1.5, 1)).is_empty()
		var score := d - (100.0 if seen else 0.0) + _rng.randf() * 2.0
		if d < RELIEF_MIN:
			score -= 200.0
		if score > best_score:
			best_score = score
			best = p
	return best
