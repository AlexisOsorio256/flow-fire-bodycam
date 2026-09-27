extends CanvasLayer

## LOBBY: FlowFire Bodycam / Campo de tiro / Combate / Salir.
##
## No es un "sistema de menu": son cuatro etiquetas sobre el MISMO post de
## bodycam que ya se paga en cada frame de juego. Cuesta el rect de fondo, que
## es el que habria que dibujar igual, y ni un nodo mas.
##
## Teclado: W/S o flechas eligen, Enter/Espacio confirman, Esc sale.

signal mode_chosen(mode: String)

const MENU := [
	{"id": "range", "label": "CAMPO DE TIRO"},
	{"id": "combat", "label": "COMBATE"},
	{"id": "quit", "label": "SALIR"},
]

var selected := 0
var _rows: Array[Label] = []


func _ready() -> void:
	layer = 1
	# FONDO: una captura REAL del juego (el corredor del bunker), desenfocada y
	# oscurecida OFFLINE en el propio JPG. Cero blur en runtime: el desenfoque es
	# un archivo de 38 KB, no un pase por frame. Encima va el MISMO post de
	# bodycam que ya se paga en juego, asi que el menu se lee como una grabacion.
	var bg := TextureRect.new()
	bg.name = "Backdrop"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.texture = preload("res://assets/textures/lobby_bg.jpg")
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var post_rect := ColorRect.new()
	post_rect.name = "Post"
	post_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	post_rect.color = Color(0.035, 0.038, 0.045)
	var post := ShaderMaterial.new()
	post.shader = preload("res://shaders/bodycam.gdshader")
	post_rect.material = post
	post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(post_rect)

	# El centrado lo hace un `CenterContainer` a pantalla completa, no un preset
	# sobre el VBox. Un preset mide el contenido ANTES de que el contenedor tenga
	# tamano, asi que el VBox crece hacia la derecha desde el ancla y el menu
	# aparecia en 1185 px de 1920 en vez de 960 (medido en captura, dos
	# capturas: `set_anchors_preset(PRESET_CENTER)` y su variante MINSIZE fallan
	# igual). `CenterContainer` centra a su hijo en su tamano minimo, ya calculado.
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(col)

	var title := _label("FLOWFIRE BODYCAM", 34, Color(0.93, 0.95, 0.98, 0.92))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 26)
	col.add_child(gap)

	for entry in MENU:
		var row := _label(entry["label"], 22, Color(0.80, 0.83, 0.88, 0.75))
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.custom_minimum_size = Vector2(420, 30)
		col.add_child(row)
		_rows.append(row)
	var foot := _label("W / S  ELEGIR      ENTER  CONFIRMAR      ESC  SALIR", 12,
		Color(0.55, 0.58, 0.63, 0.45))
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(foot)
	_refresh()


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_W, KEY_UP:
				_move(-1)
			KEY_S, KEY_DOWN:
				_move(1)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_confirm()
			KEY_ESCAPE, KEY_Q:
				mode_chosen.emit("quit")


func _move(step: int) -> void:
	selected = wrapi(selected + step, 0, MENU.size())
	_refresh()


func _confirm() -> void:
	mode_chosen.emit(MENU[selected]["id"])


## La eleccion se lee por la flecha, no solo por el color.
func _refresh() -> void:
	for i in _rows.size():
		var on := i == selected
		_rows[i].text = ("> " if on else "   ") + MENU[i]["label"]
		_rows[i].add_theme_color_override("font_color",
			Color(0.97, 0.86, 0.55, 0.95) if on else Color(0.80, 0.83, 0.88, 0.55))
