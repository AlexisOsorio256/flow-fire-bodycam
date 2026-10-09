class_name PauseMenu
extends CanvasLayer

var main: Node
var player: Player
var _root: Control


func _ready() -> void:
	layer = 4
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.012, 0.016, 0.66)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER)
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.grow_vertical = Control.GROW_DIRECTION_BOTH
	col.add_theme_constant_override("separation", 18)
	_root.add_child(col)
	var title := UiStyle.label("Pausa", 64, UiStyle.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var resume := UiStyle.button("Seguir jugando", 34, 420)
	resume.pressed.connect(func() -> void: player.capture_mouse())
	col.add_child(resume)
	var leave := UiStyle.button("Volver al menú", 34, 420)
	leave.pressed.connect(func() -> void: main.leave_match())
	col.add_child(leave)
	if not TouchControls.wanted():
		var hint := UiStyle.label("Haz clic para seguir, o pulsa Esc para volver al menú", 20, UiStyle.DIM)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(hint)
	_root.visible = false


func _process(_delta: float) -> void:
	_root.visible = is_instance_valid(player) and player.is_alive() and player.paused \
		and not main.finished()
