class_name SettingsPanel
extends VBoxContainer

const GROUPS := [
	{"name": "Imagen", "rows": [["Resolución", "resolution"], ["Calidad de imagen", "quality"],
		["Imágenes por segundo", "fps"]]},
	{"name": "Controles", "rows": [["Sensibilidad general", "sensitivity"], ["Sensibilidad al apuntar", "aim"],
		["Sensibilidad al girar (móvil)", "touch"], ["Ayuda para apuntar (móvil)", "assist"],
		["Botones en pantalla (móvil)", "opacity"]]},
	{"name": "Sonido", "rows": [["Volumen", "volume"]]},
	{"name": "Partida", "rows": [["Dificultad de los rivales", "difficulty"]]},
]
const TOUCH_ROWS := ["touch", "assist", "opacity"]
const DESKTOP_ROWS := ["resolution"]
const FPS_NAMES := ["Automático", "30", "60", "120"]
const NOTES := {
	"resolution": "Igual que la pantalla usa todo el monitor. Otros tamaños dibujan una ventana más pequeña y van más ligeros.",
	"quality": "Alta se ve más nítida. Baja dibuja la imagen más pequeña: va más rápido en equipos lentos.",
	"fps": "Más imágenes por segundo dan un movimiento más suave, pero exigen más al equipo. Automático: 30 en el ordenador y 60 en el móvil.",
	"sensitivity": "Cuánto gira la vista al mover el ratón o deslizar el dedo. Si la subes, giras más con menos movimiento.",
	"aim": "Cuánto se mueve la vista cuando apuntas con la mira. Si la bajas, apuntas con más precisión.",
	"touch": "En el móvil, cuánto gira la vista al deslizar el dedo para girar.",
	"assist": "En el móvil, la vista se frena y se pega un poco al enemigo cuando lo tienes cerca de la mira.",
	"opacity": "En el móvil, qué tan visibles son los botones. Si los bajas, estorban menos la vista.",
	"volume": "Sube o baja todo el sonido del juego.",
	"difficulty": "Qué tan buenos son los rivales. En Difíciles, más rivales llevan fusil y reaccionan más rápido.",
}

var selected := 0
var _rows: Array[PanelContainer] = []
var _names: Array[Label] = []
var _values: Array[Label] = []
var _kinds: Array[String] = []
var _note: Label
var _on_box: StyleBoxFlat
var _off_box: StyleBoxFlat


func _ready() -> void:
	add_theme_constant_override("separation", 4)
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	resized.connect(queue_redraw)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_on_box = _box(Color(1, 1, 1, 0.07), Color(1, 1, 1, 0.22))
	_off_box = _box(Color(1, 1, 1, 0), Color(1, 1, 1, 0))
	add_child(UiStyle.label("Ajustes", 34, UiStyle.WHITE))
	for group in GROUPS:
		var rows := _visible(group["rows"])
		if rows.is_empty():
			continue
		if not _kinds.is_empty():
			add_child(_gap(12))
		add_child(UiStyle.label(group["name"], 22, UiStyle.DIM))
		for row in rows:
			_add_row(row[0], row[1])
	_note = UiStyle.label("", 18, UiStyle.DIM)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(0, 56)
	add_child(_note)
	var hint := UiStyle.label(_hint_text(), 16, UiStyle.DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)
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


func _gap(height: float) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, height)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


func _hint_text() -> String:
	if TouchControls.wanted():
		return "Toca un ajuste para cambiarlo."
	return "Haz clic en un ajuste para cambiarlo. Con el teclado: flechas arriba y abajo para elegir, izquierda y derecha para cambiar."


func _visible(rows: Array) -> Array:
	var shown := []
	for row in rows:
		if row[1] in TOUCH_ROWS and not TouchControls.wanted():
			continue
		if row[1] in DESKTOP_ROWS and TouchControls.wanted():
			continue
		shown.append(row)
	return shown


func _box(color: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	return box


func _add_row(title: String, kind: String) -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var line := HBoxContainer.new()
	var name_label := UiStyle.label(title, 22, UiStyle.DIM)
	name_label.custom_minimum_size = Vector2(330, 36)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var value := UiStyle.label("", 22, UiStyle.WHITE)
	value.custom_minimum_size = Vector2(0, 36)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(name_label)
	line.add_child(value)
	panel.add_child(line)
	var index := _kinds.size()
	panel.gui_input.connect(_click.bind(index))
	add_child(panel)
	_rows.append(panel)
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
		"resolution":
			Settings.resolution = wrapi(Settings.resolution + step, 0, Settings.RESOLUTION_SIZES.size())
		"quality":
			Settings.quality = wrapi(Settings.quality + step, 0, Settings.QUALITY.size())
		"fps":
			Settings.fps_cap = [0, 30, 60, 120][wrapi([0, 30, 60, 120].find(Settings.fps_cap) + step, 0, 4)]
		"volume":
			Settings.volume = clampf(snappedf(Settings.volume + step * 0.1, 0.1), 0.0, 1.0)
	Settings.apply(get_viewport())
	Settings.save()


func _refresh() -> void:
	for i in _kinds.size():
		var on := i == selected
		_rows[i].add_theme_stylebox_override("panel", _on_box if on else _off_box)
		_values[i].text = ("◂ %s ▸" if on else "%s") % _value_text(_kinds[i])
		_names[i].add_theme_color_override("font_color", UiStyle.WHITE if on else UiStyle.DIM)
	_note.text = NOTES[_kinds[selected]]


func _value_text(kind: String) -> String:
	match kind:
		"resolution":
			return Settings.RESOLUTION_NAMES[Settings.resolution]
		"quality":
			return Settings.QUALITY_NAMES[Settings.quality]
		"fps":
			return FPS_NAMES[[0, 30, 60, 120].find(Settings.fps_cap)]
		"sensitivity":
			return "%.1f" % Settings.sensitivity
		"aim":
			return "%.2f" % Settings.aim_sensitivity
		"touch":
			return "%.1f" % Settings.touch_sensitivity
		"assist":
			return "Activada" if Settings.aim_assist else "Desactivada"
		"opacity":
			return "%d %%" % roundi(Settings.touch_opacity * 100)
		"difficulty":
			return Settings.DIFFICULTY_NAMES[Settings.difficulty]
		"volume":
			return "%d %%" % roundi(Settings.volume * 100)
	return ""
