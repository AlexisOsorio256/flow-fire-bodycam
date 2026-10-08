class_name Scoreboard
extends CanvasLayer

const ALLY := Color(0.62, 0.70, 0.42)
const RIVAL := Color(0.86, 0.36, 0.30)
const PANEL := Color(0.02, 0.025, 0.03, 0.78)

var director: TeamMatch
var player: Player
var kills := 0
var deaths := 0

var _root: Control
var _time: Label
var _ally: Label
var _rival: Label
var _stats: Label
var _left_title: Label
var _right_title: Label
var _note: Label


func _ready() -> void:
	layer = 2
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = CenterContainer.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = PANEL
	box.border_color = Color(1, 1, 1, 0.08)
	box.set_border_width_all(1)
	box.set_content_margin_all(28)
	box.content_margin_left = 56
	box.content_margin_right = 56
	panel.add_theme_stylebox_override("panel", box)
	_root.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	_time = _centered(col, "", 22, UiStyle.DIM, UiStyle.MONO)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	_ally = _team(row, ALLY)
	_left_title = _ally.get_parent().get_child(0)
	row.add_child(UiStyle.label("—", 64, UiStyle.DIM))
	_rival = _team(row, RIVAL)
	_right_title = _rival.get_parent().get_child(0)
	var rule := ColorRect.new()
	rule.color = Color(1, 1, 1, 0.12)
	rule.custom_minimum_size = Vector2(0, 1)
	col.add_child(rule)
	_note = _centered(col, "", 18, UiStyle.DIM, UiStyle.MONO)
	_stats = _centered(col, "", 22, UiStyle.WHITE, UiStyle.MONO)
	_root.visible = false


func _centered(col: VBoxContainer, text: String, size: int, tint: Color, font: Font) -> Label:
	var label := UiStyle.label(text, size, tint, font)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(label)
	return label


func _team(row: HBoxContainer, tint: Color) -> Label:
	var col := VBoxContainer.new()
	row.add_child(col)
	var name_label := UiStyle.label("", 24, tint)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name_label)
	var score := UiStyle.label("0", 84, UiStyle.WHITE)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score.custom_minimum_size = Vector2(150, 0)
	col.add_child(score)
	return score


func _process(_delta: float) -> void:
	var held := Input.is_key_pressed(KEY_TAB) or is_instance_valid(player) and player.touch != null and player.touch.board
	_root.visible = held and director != null and director.running
	if not _root.visible:
		return
	var info := director.board()
	var seconds := ceili(info["clock"]) if info["clock"] > 0.0 else ceili(director.elapsed())
	_time.text = "%02d:%02d" % [seconds / 60, seconds % 60]
	_left_title.text = info["left"][0]
	_ally.text = str(info["left"][1])
	_right_title.text = info["right"][0]
	_rival.text = str(info["right"][1])
	_note.text = info["note"]
	_stats.text = "Tú: eliminaste a %d y caíste %d %s" % [kills, deaths, "vez" if deaths == 1 else "veces"]
