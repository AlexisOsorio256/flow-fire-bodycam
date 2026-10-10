class_name DeathScreen
extends CanvasLayer

signal chosen(action: String)

const PAD := 42.0
const RED := Color(0.95, 0.16, 0.1, 0.95)

var _root: Control
var _count: Label
var _armed := false
var _can_retry := true


func _build() -> Control:
	layer = 3
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.012, 0.016, 0.0)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)
	return _root


func _add(text: String, size: int, tint: Color, at: Vector2, font: Font = UiStyle.MONO) -> Label:
	var label := UiStyle.label(text, size, tint, font)
	label.position = at
	_root.add_child(label)
	return label


func _blink(label: Label) -> void:
	var tw := label.create_tween().set_loops()
	tw.tween_property(label, "modulate:a", 0.15, 0.0).set_delay(0.5)
	tw.tween_property(label, "modulate:a", 1.0, 0.0).set_delay(0.35)


func show_respawn() -> void:
	_build()
	_blink(_add("●  SEÑAL PERDIDA", 20, RED, Vector2(PAD, 24)))
	_count = _add("", 14, UiStyle.DIM, Vector2(PAD, 52))
	GameAudio.play_2d("radio", -4.0, 0.8)


func countdown(seconds: float) -> void:
	if _count != null:
		var left := maxi(1, ceili(seconds))
		_count.text = "Vuelves en 1 segundo" if left == 1 else "Vuelves en %d segundos" % left


func show_result(title: String, line: String, kills: int, deaths: int, seconds: float, can_retry := true) -> void:
	var root := _build()
	var shade := root.get_child(0) as ColorRect
	root.create_tween().tween_property(shade, "color:a", 0.62, 1.2)
	var bottom := get_viewport().get_visible_rect().size.y
	_add("■  FIN DE GRABACIÓN", 16, RED, Vector2(PAD, bottom - 318))
	_add(title, 72, UiStyle.WHITE, Vector2(PAD - 3, bottom - 298), UiStyle.TITLE)
	_add(line, 26, UiStyle.WHITE, Vector2(PAD, bottom - 208))
	_add("Eliminaste a %d  ·  Caíste %d %s  ·  Duró %d:%02d" % [kills, deaths, "vez" if deaths == 1 else "veces",
		int(seconds) / 60, int(seconds) % 60], 22, UiStyle.DIM, Vector2(PAD, bottom - 170), UiStyle.TITLE)
	var row := HBoxContainer.new()
	row.position = Vector2(PAD, bottom - 96)
	row.add_theme_constant_override("separation", 20)
	_root.add_child(row)
	var retry := UiStyle.button("Jugar otra vez" if can_retry else "Esperando a quien creó la partida", 28, 300)
	retry.disabled = not can_retry
	retry.pressed.connect(_choose.bind("retry"))
	row.add_child(retry)
	var lobby := UiStyle.button("Volver al menú", 28, 300)
	lobby.pressed.connect(_choose.bind("lobby"))
	row.add_child(lobby)
	_can_retry = can_retry
	if not TouchControls.wanted():
		_add("Enter para jugar otra vez, Esc para volver al menú", 18, UiStyle.DIM, Vector2(PAD, bottom - 34), UiStyle.TITLE)
	root.modulate.a = 0.0
	var tw := root.create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(root, "modulate:a", 1.0, 0.5)
	tw.tween_callback(func(): _armed = true)


func _choose(action: String) -> void:
	if not _armed or action == "retry" and not _can_retry:
		return
	_armed = action == "retry" and Net.active()
	chosen.emit(action)


func _unhandled_input(event: InputEvent) -> void:
	if not _armed:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_choose("lobby")
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("retry"):
		get_viewport().set_input_as_handled()
		_choose("retry")
