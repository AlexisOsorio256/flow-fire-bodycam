class_name TouchControls
extends Control

const STICK_RADIUS := 110.0
const STICK_ZONE := 0.45
const SPRINT_PUSH := 0.92
const LOOK_SENS := 0.0042
const BUTTONS := {
	"fire": [Vector2(-0.11, -0.22), 92.0, "disparar"],
	"fire2": [Vector2(-0.89, -0.22), 92.0, "disparar"],
	"aim": [Vector2(-0.22, -0.13), 62.0, "apuntar"],
	"reload": [Vector2(-0.07, -0.47), 54.0, "recargar"],
	"crouch": [Vector2(-0.24, -0.34), 54.0, "agacharte"],
	"inspect": [Vector2(-0.16, -0.55), 44.0, "revisar el arma"],
	"pause": [Vector2(-0.965, -0.93), 34.0, "pausa"],
	"board": [Vector2(-0.915, -0.93), 34.0, "marcador"],
	"switch": [Vector2(-0.06, -0.66), 44.0, "cambiar de arma"],
}
const TINT := Color(0.92, 0.94, 0.96, 0.22)
const TINT_ON := Color(0.95, 0.2, 0.12, 0.42)
const PICK := Color(1.0, 0.82, 0.3, 0.9)

var player: Player
var assist: AimAssist
var editing := false
var picked := ""
var move := Vector2.ZERO
var crouch := false
var board := false
var _stick_finger := -1
var _stick_origin := Vector2.ZERO
var _look_fingers := {}
var _held := {}
var _drag_from := {}


static func wanted() -> bool:
	return OS.has_feature("mobile") or OS.get_cmdline_user_args().has("--touch")


static func spot(button: String) -> Array:
	var saved: Array = Settings.touch_layout.get(button, [])
	return saved if saved.size() == 2 else [BUTTONS[button][0], 1.0]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	assist = AimAssist.new()


func sprinting() -> bool:
	return _stick_finger >= 0 and move.y > SPRINT_PUSH


func _process(_delta: float) -> void:
	if is_instance_valid(player) and player.is_alive():
		assist.update(player)


func _input(event: InputEvent) -> void:
	if editing:
		_edit(event)
		return
	if not is_visible_in_tree() or not is_instance_valid(player) or not player.is_alive() or player.paused:
		return
	if event is InputEventScreenTouch:
		_touch(event)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		_drag(event)
		get_viewport().set_input_as_handled()


func _touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		var button := _button_at(event.position)
		if button != "":
			_held[event.index] = button
			_press(button, true)
			if button == "fire":
				_look_fingers[event.index] = true
		elif event.position.x < size.x * STICK_ZONE and _stick_finger < 0:
			_stick_finger = event.index
			_stick_origin = event.position
		else:
			_look_fingers[event.index] = true
	else:
		if _held.has(event.index):
			_press(_held[event.index], false)
			_held.erase(event.index)
		if event.index == _stick_finger:
			_stick_finger = -1
			move = Vector2.ZERO
		_look_fingers.erase(event.index)
	queue_redraw()


func _drag(event: InputEventScreenDrag) -> void:
	if event.index == _stick_finger:
		var offset := (event.position - _stick_origin).limit_length(STICK_RADIUS) / STICK_RADIUS
		move = Vector2(offset.x, -offset.y)
		queue_redraw()
	elif _look_fingers.has(event.index):
		var turn := event.relative * LOOK_SENS * Settings.sensitivity * assist.slow()
		player.yaw_target -= turn.x
		player.pitch_target = clampf(player.pitch_target - turn.y, -1.38, 1.38)
		player.look_delta = event.relative.clamp(Vector2(-12.0, -12.0), Vector2(12.0, 12.0))


func _press(button: String, down: bool) -> void:
	var weapon = player.weapon
	match button:
		"fire", "fire2":
			if down:
				weapon.press_trigger()
			else:
				weapon.release_trigger()
		"aim":
			if down:
				weapon.set_aim(not weapon.aim)
				if weapon.aim:
					assist.snap(player)
		"reload":
			if down:
				player.reload()
		"crouch":
			if down:
				crouch = not crouch
		"inspect":
			if down:
				weapon.inspect_weapon()
		"pause":
			if down:
				_release_all()
				player.release_mouse()
		"board":
			board = down
		"switch":
			if down:
				player.loadout.next()


func _release_all() -> void:
	for index in _held:
		_press(_held[index], false)
	_held.clear()
	_look_fingers.clear()
	_stick_finger = -1
	move = Vector2.ZERO


func _edit(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		var button := _button_at(event.position)
		if button != "":
			picked = button
			_drag_from[event.index] = button
			queue_redraw()
	elif event is InputEventScreenTouch:
		_drag_from.erase(event.index)
	elif event is InputEventScreenDrag and _drag_from.has(event.index):
		var button: String = _drag_from[event.index]
		var at: Array = spot(button)
		var rel: Vector2 = at[0] + event.relative / size
		rel = rel.clamp(Vector2(-0.98, -0.97), Vector2(-0.02, -0.03))
		Settings.touch_layout[button] = [rel, at[1]]
		queue_redraw()


func _button_at(p: Vector2) -> String:
	for button: String in BUTTONS:
		if p.distance_to(_center(button)) < _radius(button):
			return button
	return ""


func _center(button: String) -> Vector2:
	var rel: Vector2 = spot(button)[0]
	return Vector2(size.x + rel.x * size.x, size.y + rel.y * size.y)


func _radius(button: String) -> float:
	return BUTTONS[button][1] * float(spot(button)[1])


func _draw() -> void:
	var live := is_instance_valid(player) and player.is_alive() and not player.paused
	if not live and not editing:
		return
	var alpha := Settings.touch_opacity / 0.6
	if _stick_finger >= 0:
		draw_circle(_stick_origin, STICK_RADIUS, Color(TINT, 0.10 * alpha))
		draw_arc(_stick_origin, STICK_RADIUS, 0.0, TAU, 48, Color(TINT, TINT.a * alpha), 2.0)
		var knob := TINT_ON if sprinting() else TINT
		draw_circle(_stick_origin + Vector2(move.x, -move.y) * STICK_RADIUS, 38.0, Color(knob, knob.a * alpha))
	if editing:
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * STICK_ZONE, size.y)), Color(1, 1, 1, 0.04))
	var on := {"aim": live and player.weapon.aim, "crouch": crouch, "board": board}
	for button: String in BUTTONS:
		var c := _center(button)
		var r := _radius(button)
		var lit: bool = on.get(button, false) or _held.values().has(button)
		var tint := PICK if editing and button == picked else TINT_ON if lit else TINT
		draw_circle(c, r, Color(tint, 0.16 * alpha))
		draw_arc(c, r, 0.0, TAU, 48, Color(tint, minf(1.0, tint.a * alpha)), 2.5)
		TouchIcons.draw(self, button, c, r, Color(1, 1, 1, minf(1.0, 0.62 * alpha)))
