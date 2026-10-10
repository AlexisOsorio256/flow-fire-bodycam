class_name UiStyle
extends RefCounted

const TITLE := preload("res://assets/fonts/BarlowCondensed-SemiBold.ttf")
const MONO := preload("res://assets/fonts/ShareTechMono-Regular.ttf")
const WHITE := Color(0.93, 0.94, 0.96)
const DIM := Color(0.66, 0.68, 0.72)


static func gap(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func label(text: String, size: int, color: Color, font: Font = TITLE) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


static func button(text: String, size := 30, min_width := 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(min_width, size * 2.1)
	b.add_theme_font_override("font", TITLE)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", WHITE)
	b.add_theme_color_override("font_hover_color", WHITE)
	b.add_theme_color_override("font_pressed_color", WHITE)
	b.add_theme_color_override("font_disabled_color", Color(DIM, 0.45))
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = {"normal": Color(1, 1, 1, 0.07), "hover": Color(1, 1, 1, 0.16),
			"pressed": Color(0.95, 0.16, 0.1, 0.55), "disabled": Color(1, 1, 1, 0.03)}[state]
		box.border_color = Color(1, 1, 1, 0.22 if state != "disabled" else 0.08)
		box.set_border_width_all(1)
		box.content_margin_left = 22
		box.content_margin_right = 22
		b.add_theme_stylebox_override(state, box)
	return b
