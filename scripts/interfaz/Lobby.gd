extends CanvasLayer
signal mode_chosen(mode: String)

const MENU := [
	{"id": "duel", "label": "Jugar en equipo"},
	{"id": "survival", "label": "Aguantar oleadas"},
	{"id": "local", "label": "Jugar con amigos"},
	{"id": "settings", "label": "Ajustes"},
	{"id": "controls", "label": "Controles"},
	{"id": "quit", "label": "Salir"},
]
const CONTROLS := [
	["Movimiento", [["W A S D", "Caminar"], ["Shift", "Correr"], ["C", "Agacharse"], ["Espacio", "Saltar"]]],
	["Tu arma", [["Clic izquierdo", "Disparar"], ["Clic derecho", "Apuntar con la mira"], ["R", "Recargar"], ["1 a 5 o Q", "Cambiar de arma"],
		["F", "Revisar el arma y las balas"]]],
	["La partida", [["Tab", "Ver el marcador"], ["Esc", "Pausar; otra vez para volver al menú"]]],
]
const EYE := BodyCam.STAND_Y
const WALK := 0.5
const FOV := BodyCam.FOV
const FADE := 0.7

var selected := 0
var _rows: Array[Label] = []
var _camera: Camera3D
var _post: ShaderMaterial
var _t := 0.0
var _heading := -PI * 0.5
var _clock: Label
var _controls: Control
var _settings: SettingsPanel
var _local: LocalPanel
var _editor: TouchEditor
var _curtain: ColorRect
var _leaving := false
var _loops: Array[AudioStreamPlayer] = []


func _ready() -> void:
	layer = 1
	_loops = [GameAudio.loop("lobby"), GameAudio.loop("ambiente", -4.0)]
	_t = randf() * 60.0
	_build_camera()
	_build_overlay()
	_build_menu()
	_build_controls()
	_build_settings()
	_build_local()
	if not TouchControls.wanted():
		var hint := UiStyle.label("Elige con el ratón o con W y S, entra con Enter y vuelve con Esc", 16, UiStyle.DIM)
		hint.anchor_left = 0.075
		hint.anchor_top = 0.95
		add_child(hint)
	_curtain = ColorRect.new()
	_curtain.color = Color.BLACK
	_curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_curtain)
	create_tween().tween_property(_curtain, "color:a", 0.0, 1.2)
	_refresh()


func _exit_tree() -> void:
	for p in _loops:
		p.queue_free()


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.fov = FOV
	_camera.near = 0.12
	_camera.far = 150.0
	_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_camera)
	_camera.make_current()
	var post_rect := ColorRect.new()
	post_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post = ShaderMaterial.new()
	_post.shader = preload("res://shaders/bodycam.gdshader")
	_post.set_shader_parameter("fov_v", FOV)
	post_rect.material = _post
	add_child(post_rect)


func _build_overlay() -> void:
	var grad := GradientTexture2D.new()
	grad.gradient = Gradient.new()
	grad.gradient.set_color(0, Color(0, 0, 0, 0.78))
	grad.gradient.set_color(1, Color(0, 0, 0, 0.0))
	grad.fill_to = Vector2(0.55, 0.0)
	var shade := TextureRect.new()
	shade.texture = grad
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_clock = UiStyle.label("", 16, Color(0.9, 0.92, 0.94, 0.85), UiStyle.MONO)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clock.anchor_left = 0.5
	_clock.anchor_right = 0.955
	_clock.anchor_top = 0.04
	add_child(_clock)


func _build_menu() -> void:
	var col := VBoxContainer.new()
	col.anchor_left = 0.075
	col.anchor_top = 0.22
	col.anchor_right = 0.46
	col.anchor_bottom = 0.95
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	col.add_child(UiStyle.label("FLOWFIRE", 112, UiStyle.WHITE))
	col.add_child(UiStyle.label("B O D Y C A M", 18, UiStyle.DIM, UiStyle.MONO))
	col.add_child(UiStyle.gap(22))
	for i in MENU.size():
		var row := UiStyle.label(MENU[i]["label"], 40, UiStyle.DIM)
		row.custom_minimum_size = Vector2(0, 62)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.mouse_entered.connect(_hover.bind(i))
		row.gui_input.connect(_click.bind(i))
		col.add_child(row)
		_rows.append(row)


func _build_controls() -> void:
	_controls = VBoxContainer.new()
	_controls.anchor_left = 0.52
	_controls.anchor_right = 0.95
	_controls.anchor_top = 0.22
	_controls.anchor_bottom = 0.9
	_controls.add_theme_constant_override("separation", 8)
	_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_controls.visible = false
	add_child(_controls)
	_controls.draw.connect(func() -> void:
		_controls.draw_rect(Rect2(Vector2(-28, -20), Vector2(_controls.size.x + 56, _controls.get_combined_minimum_size().y + 40)),
			Color(0.01, 0.012, 0.016, 0.72)))
	_controls.add_child(UiStyle.label("Controles", 34, UiStyle.WHITE))
	for group in CONTROLS:
		_controls.add_child(UiStyle.gap(6))
		_controls.add_child(UiStyle.label(group[0], 24, UiStyle.DIM))
		for pair in group[1]:
			var line := HBoxContainer.new()
			var key := UiStyle.label(pair[0], 22, UiStyle.DIM)
			key.custom_minimum_size = Vector2(230, 0)
			line.add_child(key)
			line.add_child(UiStyle.label(pair[1], 22, UiStyle.WHITE))
			_controls.add_child(line)


func _build_settings() -> void:
	_settings = SettingsPanel.new()
	_settings.anchor_left = 0.52
	_settings.anchor_right = 0.95
	_settings.anchor_top = 0.2
	_settings.anchor_bottom = 0.94
	_settings.visible = false
	add_child(_settings)


func _build_local() -> void:
	_local = LocalPanel.new()
	_local.anchor_left = 0.52
	_local.anchor_right = 0.95
	_local.anchor_top = 0.22
	_local.anchor_bottom = 0.95
	_local.visible = false
	add_child(_local)


func notice(text: String) -> void:
	_show("local")
	_local.notice(text)


func show_panel(id: String) -> void:
	_show(id)


func back() -> void:
	if _editor != null:
		return
	if _controls.visible or _settings.visible or _local.visible:
		_show("")


func _show(id: String) -> void:
	if id == "controls" and TouchControls.wanted():
		if _editor == null:
			_editor = TouchEditor.new()
			_editor.closed.connect(func() -> void: _editor = null)
			add_child(_editor)
		return
	_controls.visible = id == "controls"
	_settings.visible = id == "settings"
	_local.visible = id == "local"
	if not _local.visible and not Net.active():
		Net.discovery.quiet()


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if event.is_action_pressed("ui_up"):
		_move(-1)
	elif event.is_action_pressed("ui_down"):
		_move(1)
	elif event.is_action_pressed("ui_accept"):
		_confirm()
	elif event.is_action_pressed("ui_cancel"):
		if _controls.visible or _settings.visible or _local.visible:
			_show("")
		else:
			mode_chosen.emit("quit")


func _hover(i: int) -> void:
	if i != selected:
		GameAudio.play_2d("ui_hover")
	selected = i
	_refresh()


func _click(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected = i
		_confirm()


func _move(step: int) -> void:
	selected = wrapi(selected + step, 0, MENU.size())
	GameAudio.play_2d("ui_hover")
	_refresh()


func _confirm() -> void:
	if _leaving:
		return
	GameAudio.play_2d("ui_confirm")
	var id: String = MENU[selected]["id"]
	if id == "controls" or id == "settings" or id == "local":
		var open := {"controls": _controls, "settings": _settings, "local": _local}[id] as Control
		_show("" if open.visible else id)
		return
	if id == "quit":
		mode_chosen.emit(id)
		return
	_leaving = true
	GameAudio.play_2d("radio")
	var tw := create_tween()
	tw.tween_property(_curtain, "color:a", 1.0, FADE)
	tw.tween_callback(mode_chosen.emit.bind(id))


func _process(delta: float) -> void:
	_t += delta
	var route: Vector2 = MapCatalog.MAPS[MapCatalog.choice]["route"]
	var span := route.y * 2.0
	var phase := fmod(_t * WALK / span, 2.0)
	var u := phase if phase < 1.0 else 2.0 - phase
	var x := lerpf(-route.y, route.y, smoothstep(0.0, 1.0, u))
	_heading = lerp_angle(_heading, -PI * 0.5 if phase < 1.0 else PI * 0.5, 1.0 - exp(-1.2 * delta))
	var step := _t * 1.9
	var pos := Vector3(x, EYE + absf(sin(step)) * 0.012 + sin(_t * 0.37) * 0.012, route.x + sin(step * 0.5) * 0.02)
	var yaw := _heading + sin(_t * 0.23) * 0.35 + sin(_t * 0.61) * 0.05
	var pitch := 0.07 + sin(_t * 0.15) * 0.06
	_camera.global_transform = Transform3D(Basis.from_euler(Vector3(pitch, yaw, sin(step * 0.5) * 0.01)), pos)
	_post.set_shader_parameter("time_seed", float(Engine.get_process_frames() % 97))
	var d := Time.get_datetime_dict_from_system()
	_clock.text = "FF-BODYCAM 019     %04d-%02d-%02d  %02d:%02d:%02d     ● REC" % [d["year"], d["month"], d["day"],
		d["hour"], d["minute"], d["second"]]
	_rows[selected].modulate.a = 0.85 + 0.15 * sin(_t * 3.7)


func _refresh() -> void:
	for i in _rows.size():
		var on := i == selected
		_rows[i].text = ("▸  " if on else "    ") + MENU[i]["label"]
		_rows[i].add_theme_color_override("font_color", UiStyle.WHITE if on else Color(0.72, 0.74, 0.78, 0.6))
		_rows[i].modulate.a = 1.0
