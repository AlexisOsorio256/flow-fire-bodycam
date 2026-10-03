extends CanvasLayer
signal mode_chosen(mode: String)


const MENU := [
	{"id": "play", "label": "JUGAR"},
	{"id": "quit", "label": "SALIR"},
]
const PATH_A := Vector3(-11.4, 1.58, -9.0)
const PATH_B := Vector3(11.4, 1.58, -9.0)
const PATH_SPEED := 0.32
const FOV := 100.0

var selected := 0
var _rows: Array[Label] = []
var _camera: Camera3D
var _post: ShaderMaterial
var _t := 0.0
var _clock: Label


func _ready() -> void:
	layer = 1
	_camera = Camera3D.new()
	_camera.name = "LobbyCamera"
	_camera.fov = FOV
	_camera.near = 0.12
	_camera.far = 150.0
	_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_camera)
	_camera.make_current()
	_t = randf() * 60.0

	var post_rect := ColorRect.new()
	post_rect.name = "Post"
	post_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post = ShaderMaterial.new()
	_post.shader = preload("res://shaders/bodycam.gdshader")
	_post.set_shader_parameter("fov_v", FOV)
	post_rect.material = _post
	add_child(post_rect)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grad := GradientTexture2D.new()
	grad.gradient = Gradient.new()
	grad.gradient.set_color(0, Color(0, 0, 0, 0.72))
	grad.gradient.set_color(1, Color(0, 0, 0, 0.0))
	grad.fill_to = Vector2(0.62, 0.0)
	var shade_tex := TextureRect.new()
	shade_tex.texture = grad
	shade_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade_tex.stretch_mode = TextureRect.STRETCH_SCALE
	shade_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade_tex)

	var col := VBoxContainer.new()
	col.anchor_left = 0.075
	col.anchor_top = 0.5
	col.anchor_right = 0.6
	col.anchor_bottom = 0.92
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)

	var title := _label("FLOWFIRE", 64, Color(0.95, 0.96, 0.97, 0.96))
	col.add_child(title)
	var sub := _label("BODYCAM", 20, Color(0.80, 0.82, 0.85, 0.70))
	sub.add_theme_constant_override("outline_size", 0)
	col.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 40)
	col.add_child(gap)

	for i in MENU.size():
		var row := _label(MENU[i]["label"], 34, Color(0.82, 0.84, 0.88, 0.7))
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.mouse_entered.connect(_hover.bind(i))
		row.gui_input.connect(_click.bind(i))
		col.add_child(row)
		_rows.append(row)
	var foot := _label("W / S  ELEGIR      ENTER  CONFIRMAR      ESC  SALIR", 13,
		Color(0.60, 0.63, 0.67, 0.55))
	foot.anchor_left = 0.075
	foot.anchor_top = 0.95
	foot.anchor_right = 0.9
	foot.anchor_bottom = 0.98
	add_child(foot)

	_clock = _label("", 13, Color(0.88, 0.90, 0.92, 0.75))
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clock.anchor_left = 0.6
	_clock.anchor_right = 0.965
	_clock.anchor_top = 0.03
	_clock.anchor_bottom = 0.06
	add_child(_clock)
	_refresh()


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_W, KEY_UP:
				_move(-1)
			KEY_S, KEY_DOWN:
				_move(1)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_confirm()
			KEY_ESCAPE, KEY_Q:
				mode_chosen.emit("quit")


func _hover(i: int) -> void:
	selected = i
	_refresh()


func _click(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected = i
		_confirm()


func _move(step: int) -> void:
	selected = wrapi(selected + step, 0, MENU.size())
	_refresh()


func _confirm() -> void:
	mode_chosen.emit(MENU[selected]["id"])


func _process(delta: float) -> void:
	_t += delta
	var span := PATH_A.distance_to(PATH_B)
	var u := fmod(_t * PATH_SPEED, span * 2.0) / span
	var pos := PATH_A.lerp(PATH_B, smoothstep(0.0, 1.0, pingpong(u, 1.0)))
	pos.y += sin(_t * 1.9) * 0.012 + sin(_t * 0.37) * 0.02
	pos.x += sin(_t * 0.95) * 0.015
	var w := u if u >= 0.07 else u + 2.0
	var turn := smoothstep(0.93, 1.07, w) if w < 1.5 else 1.0 - smoothstep(1.93, 2.07, w)
	var yaw := lerpf(-PI * 0.5, PI * 0.5, turn)
	yaw += sin(_t * 0.23) * 0.35 + sin(_t * 0.61) * 0.05
	var pitch := 0.06 + sin(_t * 0.17) * 0.08
	_camera.global_transform = Transform3D(
		Basis.from_euler(Vector3(pitch, yaw, sin(_t * 0.95) * 0.012)), pos)
	_post.set_shader_parameter("time_seed", float(Engine.get_process_frames() % 97))
	var d := Time.get_datetime_dict_from_system()
	_clock.text = "%04d-%02d-%02d  %02d:%02d:%02d" % [d["year"], d["month"], d["day"],
		d["hour"], d["minute"], d["second"]]
	var on := _rows[selected]
	on.modulate.a = 0.85 + 0.15 * sin(_t * 3.7)


func _refresh() -> void:
	for i in _rows.size():
		var on := i == selected
		_rows[i].text = ("▸ " if on else "   ") + MENU[i]["label"]
		_rows[i].add_theme_color_override("font_color",
			Color(1.0, 1.0, 1.0, 0.98) if on else Color(0.78, 0.80, 0.84, 0.55))
		_rows[i].modulate.a = 1.0
