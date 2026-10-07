class_name TouchEditor
extends CanvasLayer

signal closed

const SCALES := Vector2(0.6, 1.8)

var _pad: TouchControls
var _info: Label
var _assist: Button


func _ready() -> void:
	layer = 5
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.035, 0.04, 0.9)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_pad = TouchControls.new()
	_pad.editing = true
	add_child(_pad)
	var top := VBoxContainer.new()
	top.anchor_left = 0.2
	top.anchor_right = 0.8
	top.anchor_top = 0.04
	top.add_theme_constant_override("separation", 10)
	add_child(top)
	_info = UiStyle.label("", 24, UiStyle.WHITE)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_info)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	top.add_child(row)
	_add(row, "Más pequeño", _resize.bind(-0.1))
	_add(row, "Más grande", _resize.bind(0.1))
	_add(row, "Más transparente", _fade.bind(-0.1))
	_add(row, "Más visible", _fade.bind(0.1))
	var row2 := HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.add_theme_constant_override("separation", 10)
	top.add_child(row2)
	_assist = _add(row2, "", _toggle_assist)
	_add(row2, "Dejar como al principio", _reset)
	_add(row2, "Listo", _done)
	_refresh()


func _add(row: HBoxContainer, text: String, action: Callable) -> Button:
	var b := UiStyle.button(text, 22, 150)
	b.pressed.connect(action)
	row.add_child(b)
	return b


func _resize(step: float) -> void:
	if _pad.picked == "":
		return
	var at := TouchControls.spot(_pad.picked)
	Settings.touch_layout[_pad.picked] = [at[0], clampf(snappedf(at[1] + step, 0.1), SCALES.x, SCALES.y)]
	_refresh()


func _fade(step: float) -> void:
	Settings.touch_opacity = clampf(snappedf(Settings.touch_opacity + step, 0.1), 0.2, 1.0)
	_refresh()


func _toggle_assist() -> void:
	Settings.aim_assist = not Settings.aim_assist
	_refresh()


func _reset() -> void:
	Settings.touch_layout = {}
	Settings.touch_opacity = 0.6
	_refresh()


func _done() -> void:
	Settings.save()
	closed.emit()
	queue_free()


func _refresh() -> void:
	_info.text = "Toca un botón y arrástralo a donde te quede cómodo" if _pad.picked == "" \
		else "Botón de %s: tamaño %d %%" % [TouchControls.BUTTONS[_pad.picked][2], roundi(TouchControls.spot(_pad.picked)[1] * 100)]
	_assist.text = "Ayuda al apuntar: %s" % ("sí" if Settings.aim_assist else "no")
	_pad.queue_redraw()


func _process(_delta: float) -> void:
	if _pad.picked != "" and not _info.text.contains(TouchControls.BUTTONS[_pad.picked][2]):
		_refresh()
