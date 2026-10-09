class_name SettingsPanel
extends VBoxContainer

const GROUPS := [
	{"name": "La partida", "rows": [["Rivales", "difficulty"]]},
	{"name": "El control", "rows": [["Sensibilidad", "sensitivity"], ["Sensibilidad al apuntar", "aim"],
		["Sensibilidad al girar", "touch"], ["Ayuda al apuntar", "assist"], ["Botones en pantalla", "opacity"]]},
	{"name": "La imagen", "rows": [["Resolución", "resolution"], ["Calidad gráfica", "quality"],
		["Cuadros por segundo", "fps"]]},
	{"name": "El sonido", "rows": [["Volumen", "volume"]]},
]
const TOUCH_ROWS := ["touch", "assist", "opacity"]
const DESKTOP_ROWS := ["resolution"]
const FPS_NAMES := ["Auto", "30", "60", "120"]

var selected := 0
var _values: Array[Label] = []
var _names: Array[Label] = []
var _kinds: Array[String] = []


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	resized.connect(queue_redraw)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiStyle.label("Ajustes", 34, UiStyle.WHITE))
	for group in GROUPS:
		var rows := _visible(group["rows"])
		if rows.is_empty():
			continue
		add_child(UiStyle.label(group["name"], 20, UiStyle.DIM))
		for row in rows:
			_add_row(row[0], row[1])
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
			selected = wrapi(selected - 1, 0, _kinds.size())
		KEY_S, KEY_DOWN:
			selected = wrapi(selected + 1, 0, _kinds.size())
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


func _visible(rows: Array) -> Array:
	var shown := []
	for row in rows:
		if row[1] in TOUCH_ROWS and not TouchControls.wanted():
			continue
		if row[1] in DESKTOP_ROWS and TouchControls.wanted():
			continue
		shown.append(row)
	return shown


func _add_row(title: String, kind: String) -> void:
	var line := HBoxContainer.new()
	var name_label := UiStyle.label(title, 24, UiStyle.DIM)
	name_label.custom_minimum_size = Vector2(300, 52)
	name_label.mouse_filter = Control.MOUSE_FILTER_STOP
	var index := _kinds.size()
	name_label.gui_input.connect(_click.bind(index))
	line.add_child(name_label)
	var value := UiStyle.label("", 24, UiStyle.WHITE)
	value.mouse_filter = Control.MOUSE_FILTER_STOP
	value.gui_input.connect(_click.bind(index))
	line.add_child(value)
	add_child(line)
	_names.append(name_label)
	_values.append(value)
	_kinds.append(kind)


func _click(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		selected = i
		_change(-1 if event.button_index == MOUSE_BUTTON_RIGHT else 1)
		GameAudio.play_2d("ui_hover")
		_refresh()


func _change(step: int) -> void:
	match _kinds[selected]:
		"difficulty":
			Settings.difficulty = wrapi(Settings.difficulty + step, 0, Settings.RIVAL_SKILL.size())
		"sensitivity":
			Settings.sensitivity = clampf(snappedf(Settings.sensitivity + step * 0.1, 0.1), 0.3, 3.0)
		"aim":
			Settings.aim_sensitivity = clampf(snappedf(Settings.aim_sensitivity + step * 0.05, 0.05), 0.3, 2.0)
		"touch":
			Settings.touch_sensitivity = clampf(snappedf(Settings.touch_sensitivity + step * 0.1, 0.1), 0.5, 3.0)
		"assist":
			Settings.aim_assist = not Settings.aim_assist
		"opacity":
			Settings.touch_opacity = clampf(snappedf(Settings.touch_opacity + step * 0.1, 0.1), 0.2, 1.0)
		"quality":
			Settings.quality = wrapi(Settings.quality + step, 0, Settings.QUALITY.size())
		"fps":
			Settings.fps_cap = [0, 30, 60, 120][wrapi([0, 30, 60, 120].find(Settings.fps_cap) + step, 0, 4)]
		"resolution":
			Settings.resolution = wrapi(Settings.resolution + step, 0, Settings.RESOLUTION_SIZES.size())
		"volume":
			Settings.volume = clampf(snappedf(Settings.volume + step * 0.1, 0.1), 0.0, 1.0)
	Settings.apply(get_viewport())
	Settings.save()


func _refresh() -> void:
	for i in _kinds.size():
		var on := i == selected
		_values[i].text = ("◂ %s ▸" if on else "  %s  ") % _value_text(_kinds[i])
		_names[i].add_theme_color_override("font_color", UiStyle.WHITE if on else UiStyle.DIM)


func _value_text(kind: String) -> String:
	match kind:
		"difficulty":
			return Settings.DIFFICULTY_NAMES[Settings.difficulty]
		"sensitivity":
			return "%.1f" % Settings.sensitivity
		"aim":
			return "%.2f" % Settings.aim_sensitivity
		"touch":
			return "%.1f" % Settings.touch_sensitivity
		"assist":
			return "Puesta" if Settings.aim_assist else "Quitada"
		"opacity":
			return "%d %%" % roundi(Settings.touch_opacity * 100)
		"quality":
			return Settings.QUALITY_NAMES[Settings.quality]
		"fps":
			return FPS_NAMES[[0, 30, 60, 120].find(Settings.fps_cap)]
		"resolution":
			return Settings.RESOLUTION_NAMES[Settings.resolution]
		"volume":
			return "%d %%" % roundi(Settings.volume * 100)
	return ""
