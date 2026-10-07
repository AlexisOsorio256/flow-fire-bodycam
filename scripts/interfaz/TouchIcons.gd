class_name TouchIcons
extends RefCounted


static func draw(canvas: CanvasItem, button: String, c: Vector2, r: float, ink: Color) -> void:
	var u := r * 0.62
	var w := maxf(2.0, r * 0.06)
	match button:
		"fire", "fire2":
			_cartridge(canvas, c, u, ink)
		"aim":
			_sights(canvas, c, u, ink, w)
		"reload":
			_magazine(canvas, c, u, ink, w)
		"crouch":
			_stance(canvas, c, u, ink, w)
		"inspect":
			_eye(canvas, c, u, ink, w)
		"pause":
			canvas.draw_rect(Rect2(c + Vector2(-0.5, -0.6) * u, Vector2(0.32, 1.2) * u), ink)
			canvas.draw_rect(Rect2(c + Vector2(0.18, -0.6) * u, Vector2(0.32, 1.2) * u), ink)
		"switch":
			_rifle(canvas, c, u, ink, w)
		"board":
			for i in 3:
				var y := (i - 1) * 0.45 * u
				canvas.draw_line(c + Vector2(-0.6 * u, y), c + Vector2((0.6 - i * 0.25) * u, y), ink, w * 1.4)


static func _rifle(canvas: CanvasItem, c: Vector2, u: float, ink: Color, w: float) -> void:
	canvas.draw_rect(Rect2(c + Vector2(-0.85, -0.18) * u, Vector2(1.25, 0.26) * u), ink)
	canvas.draw_line(c + Vector2(0.4, -0.06) * u, c + Vector2(0.9, -0.06) * u, ink, w * 1.4)
	canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.1, 0.08) * u, c + Vector2(0.08, 0.08) * u,
		c + Vector2(0.12, 0.55) * u, c + Vector2(-0.04, 0.58) * u]), ink)
	canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.5, 0.08) * u, c + Vector2(-0.36, 0.08) * u,
		c + Vector2(-0.44, 0.42) * u, c + Vector2(-0.58, 0.4) * u]), ink)
	canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.85, -0.18) * u, c + Vector2(-1.0, -0.12) * u,
		c + Vector2(-1.0, 0.25) * u, c + Vector2(-0.85, 0.08) * u]), ink)


static func _cartridge(canvas: CanvasItem, c: Vector2, u: float, ink: Color) -> void:
	var body := Rect2(c + Vector2(-0.3, -0.1) * u, Vector2(0.6, 0.85) * u)
	canvas.draw_rect(body, ink)
	canvas.draw_rect(Rect2(c + Vector2(-0.36, 0.62) * u, Vector2(0.72, 0.16) * u), ink)
	var tip := PackedVector2Array([c + Vector2(-0.3, -0.16) * u, c + Vector2(-0.22, -0.55) * u, c + Vector2(0.0, -0.8) * u,
		c + Vector2(0.22, -0.55) * u, c + Vector2(0.3, -0.16) * u])
	canvas.draw_colored_polygon(tip, ink)


static func _sights(canvas: CanvasItem, c: Vector2, u: float, ink: Color, w: float) -> void:
	canvas.draw_rect(Rect2(c + Vector2(-0.85, 0.1) * u, Vector2(0.55, 0.55) * u), ink)
	canvas.draw_rect(Rect2(c + Vector2(0.3, 0.1) * u, Vector2(0.55, 0.55) * u), ink)
	canvas.draw_rect(Rect2(c + Vector2(-0.12, -0.2) * u, Vector2(0.24, 0.85) * u), ink)
	canvas.draw_circle(c + Vector2(0.0, -0.32) * u, 0.13 * u, ink)
	canvas.draw_line(c + Vector2(-0.85, 0.65) * u, c + Vector2(0.85, 0.65) * u, ink, w)


static func _magazine(canvas: CanvasItem, c: Vector2, u: float, ink: Color, w: float) -> void:
	var tilt := Transform2D(0.18, c)
	var shell := PackedVector2Array([Vector2(-0.3, -0.7), Vector2(0.3, -0.7), Vector2(0.38, 0.55), Vector2(-0.22, 0.55)])
	var outline := PackedVector2Array()
	for p in shell:
		outline.append(tilt * (p * u))
	outline.append(outline[0])
	canvas.draw_polyline(outline, ink, w * 1.3)
	canvas.draw_rect(Rect2(tilt * (Vector2(-0.3, 0.55) * u), Vector2(0.75, 0.18) * u), ink)
	canvas.draw_circle(tilt * (Vector2(0.0, -0.82) * u), 0.14 * u, ink)


static func _stance(canvas: CanvasItem, c: Vector2, u: float, ink: Color, w: float) -> void:
	for i in 2:
		var y := (-0.55 + i * 0.42) * u
		canvas.draw_polyline(PackedVector2Array([c + Vector2(-0.5 * u, y), c + Vector2(0.0, y + 0.35 * u),
			c + Vector2(0.5 * u, y)]), ink, w * 1.4)
	canvas.draw_line(c + Vector2(-0.75, 0.65) * u, c + Vector2(0.75, 0.65) * u, ink, w * 1.4)


static func _eye(canvas: CanvasItem, c: Vector2, u: float, ink: Color, w: float) -> void:
	var lid := PackedVector2Array()
	for i in 17:
		var t := float(i) / 16.0
		lid.append(c + Vector2(lerpf(-0.85, 0.85, t), -sin(t * PI) * 0.5) * u)
	for i in 17:
		var t := 1.0 - float(i) / 16.0
		lid.append(c + Vector2(lerpf(-0.85, 0.85, t), sin(t * PI) * 0.5) * u)
	canvas.draw_polyline(lid, ink, w * 1.2)
	canvas.draw_circle(c, 0.26 * u, ink)
