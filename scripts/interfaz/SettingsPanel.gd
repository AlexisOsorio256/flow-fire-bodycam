class_name SettingsPanel
extends VBoxContainer

const ROWS := ["Rivales", "Luz del mapa", "Sensibilidad de la mira", "Volumen", "Calidad gráfica", "Pantalla"]

var selected := 0
var _values: Array[Label] = []
var _names: Array[Label] = []


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	resized.connect(queue_redraw)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiStyle.label("Ajustes", 34, UiStyle.WHITE))
	for i in _rows():
		var line := HBoxContainer.new()
		var name_label := UiStyle.label(ROWS[i], 24, UiStyle.DIM)
		name_label.custom_minimum_size = Vector2(300, 52)
		name_label.mouse_filter = Control.MOUSE_FILTER_STOP
		name_label.gui_input.connect(_click.bind(i))
		line.add_child(name_label)
		var value := UiStyle.label("", 24, UiStyle.WHITE)
		value.mouse_filter = Control.MOUSE_FILTER_STOP
		value.gui_input.connect(_click.bind(i))
		line.add_child(value)
		add_child(line)
		_names.append(name_label)
		_values.append(value)
	add_child(UiStyle.label("Toca un ajuste para cambiarlo" if TouchControls.wanted()
		else "Haz clic en un ajuste para cambiarlo, o usa W S y A D", 16, UiStyle.DIM))
	_refresh()


func _draw() -> void:
	draw_rect(Rect2(Vector2(-28, -20), size + Vector2(56, 40)), Color(0.01, 0.012, 0.016, 0.72))


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_W, KEY_UP:
			selected = wrapi(selected - 1, 0, _rows())
		KEY_S, KEY_DOWN:
			selected = wrapi(selected + 1, 0, _rows())
		KEY_A, KEY_LEFT:
			_change(-1)
		KEY_D, KEY_RIGHT, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_change(1)
		KEY_ESCAPE:
			visible = false
		_:
			return
	get_viewport().set_input_as_handled()
	GameAudio.play_2d("ui_hover")
	_refresh()


func _rows() -> int:
	return ROWS.size() - (1 if TouchControls.wanted() else 0)


func _click(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		selected = i
		_change(-1 if event.button_index == MOUSE_BUTTON_RIGHT else 1)
		GameAudio.play_2d("ui_hover")
		_refresh()


func _change(step: int) -> void:
	match selected:
		0:
			Settings.difficulty = wrapi(Settings.difficulty + step, 0, Settings.RIVAL_SKILL.size())
		1:
			Settings.blackout = not Settings.blackout
		2:
			Settings.sensitivity = clampf(snappedf(Settings.sensitivity + step * 0.1, 0.1), 0.3, 3.0)
		3:
			Settings.volume = clampf(snappedf(Settings.volume + step * 0.1, 0.1), 0.0, 1.0)
		4:
			Settings.quality = wrapi(Settings.quality + step, 0, Settings.QUALITY.size())
		5:
			Settings.fullscreen = not Settings.fullscreen
	Settings.apply(get_viewport())
	Settings.save()


func _refresh() -> void:
	var shown := [Settings.DIFFICULTY_NAMES[Settings.difficulty], "A oscuras" if Settings.blackout else "Encendida",
		"%.1f" % Settings.sensitivity, "%d %%" % roundi(Settings.volume * 100),
		Settings.QUALITY_NAMES[Settings.quality], "Completa" if Settings.fullscreen else "En ventana"]
	for i in _rows():
		var on := i == selected
		_values[i].text = ("◂ %s ▸" if on else "  %s  ") % shown[i]
		_names[i].add_theme_color_override("font_color", UiStyle.WHITE if on else UiStyle.DIM)
