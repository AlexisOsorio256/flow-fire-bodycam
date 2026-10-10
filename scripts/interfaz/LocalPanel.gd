class_name LocalPanel
extends VBoxContainer

const SIZE_NAMES := {1: "Uno contra uno", 2: "Dos contra dos", 4: "Cuatro contra cuatro"}
const RED := Color(0.95, 0.3, 0.22)

var _home: VBoxContainer
var _wait: VBoxContainer
var _group: VBoxContainer
var _found: VBoxContainer
var _notice: Label
var _wait_label: Label
var _title: Label
var _status: Label
var _teams: Array[VBoxContainer] = []
var _start: Button
var _maps_box: VBoxContainer
var _swap: Button
var _connecting := false
var _join_seen := false
var _poll := 0.0


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	add_child(UiStyle.label("Jugar con amigos", 34, UiStyle.WHITE))
	add_child(UiStyle.label("Tienen que estar conectados a la misma red.", 20, UiStyle.DIM))
	_home = _section()
	_wait = _section()
	_group = _section()
	_build_home()
	_build_wait()
	_build_group()
	_notice = UiStyle.label("", 20, RED)
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(_notice)
	Net.roster_changed.connect(_refresh)
	Net.closed.connect(_on_closed)
	minimum_size_changed.connect(queue_redraw)
	visibility_changed.connect(_on_shown)
	_refresh()


func _draw() -> void:
	draw_rect(Rect2(Vector2(-28, -20), Vector2(size.x + 56, get_combined_minimum_size().y + 40)), Color(0.01, 0.012, 0.016, 0.72))


func notice(text: String) -> void:
	if _connecting:
		return
	_notice.text = text
	_refresh()


func _section() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	return box


func _row(parent: Container) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	return row


func _field(placeholder: String, text: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	edit.text = text
	edit.custom_minimum_size = Vector2(320, 60)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.add_theme_font_override("font", UiStyle.TITLE)
	edit.add_theme_font_size_override("font_size", 24)
	return edit


func _build_home() -> void:
	var name_row := _row(_home)
	name_row.add_child(UiStyle.label("Tu nombre", 24, UiStyle.DIM))
	var name_edit := _field("Tu nombre", Settings.player_name)
	name_edit.max_length = 16
	name_edit.text_changed.connect(func(text: String) -> void:
		Settings.player_name = text.strip_edges() if text.strip_edges() != "" else Settings.player_name
		Settings.save())
	name_row.add_child(name_edit)
	_home.add_child(UiStyle.label("Crear una partida", 24, UiStyle.WHITE))
	var sizes := _row(_home)
	for size: int in Net.SIZES:
		var b := UiStyle.button(SIZE_NAMES[size], 24, 0)
		b.pressed.connect(_host.bind(size))
		sizes.add_child(b)
	var fill := CheckButton.new()
	fill.text = "Llenar los puestos libres con enemigos"
	fill.button_pressed = Settings.fill_bots
	fill.add_theme_font_override("font", UiStyle.TITLE)
	fill.add_theme_font_size_override("font_size", 22)
	fill.add_theme_color_override("font_color", UiStyle.WHITE)
	fill.toggled.connect(_set_fill)
	_home.add_child(fill)
	var goal_row := _row(_home)
	goal_row.add_child(UiStyle.label("Primero a %d puntos" % TeamMatch.TARGET, 24, UiStyle.DIM))
	_home.add_child(UiStyle.label("Entrar a la partida de un amigo", 24, UiStyle.WHITE))
	_found = VBoxContainer.new()
	_found.add_theme_constant_override("separation", 8)
	_home.add_child(_found)


func _build_wait() -> void:
	_wait_label = UiStyle.label("", 24, UiStyle.WHITE)
	_wait.add_child(_wait_label)
	var cancel := UiStyle.button("Cancelar", 24, 220)
	cancel.pressed.connect(func() -> void:
		Net.leave()
		_connecting = false
		_on_shown())
	_wait.add_child(cancel)


func _build_group() -> void:
	_title = UiStyle.label("", 28, UiStyle.WHITE)
	_group.add_child(_title)
	_status = UiStyle.label("", 22, UiStyle.DIM)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	_group.add_child(_status)
	var columns := _row(_group)
	columns.add_theme_constant_override("separation", 40)
	for i in 2:
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(260, 0)
		columns.add_child(col)
		_teams.append(col)
	_maps_box = VBoxContainer.new()
	_maps_box.add_theme_constant_override("separation", 10)
	_group.add_child(_maps_box)
	var previews := _row(_maps_box)
	previews.add_theme_constant_override("separation", 24)
	for i in MapCatalog.PREVIEWS.size():
		var card := VBoxContainer.new()
		var image := TextureRect.new()
		image.texture = load(MapCatalog.PREVIEWS[i])
		image.custom_minimum_size = Vector2(300, 169)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		card.add_child(image)
		card.add_child(UiStyle.label(MapCatalog.NAMES[i], 20, UiStyle.DIM))
		previews.add_child(card)
	_maps_box.add_child(UiStyle.label("Al empezar sale uno al azar", 20, UiStyle.DIM))
	var actions := _row(_group)
	_swap = UiStyle.button("Cambiar de equipo", 24, 0)
	_swap.pressed.connect(Net.switch_team)
	actions.add_child(_swap)
	_start = UiStyle.button("Iniciar partida", 24, 200)
	_start.pressed.connect(Net.start_match)
	actions.add_child(_start)
	var leave := UiStyle.button("Salir", 24, 140)
	leave.pressed.connect(func() -> void:
		Net.leave()
		_on_shown())
	actions.add_child(leave)


func _status_text() -> String:
	var creator := str(Net.roster.get(1, {}).get("name", ""))
	if Net.hosting and Settings.fill_bots:
		return "Puedes empezar cuando quieras: los puestos libres los llenan enemigos."
	if not Net.ready_to_start():
		return "Esperando a que entre alguien más…" if Net.hosting else "Esperando a que entre alguien en el otro equipo…"
	if Net.hosting:
		return "Ya hay jugadores en los dos equipos. Cuando quieras, inicia la partida."
	return "Esperando a que %s inicie la partida." % creator


func _host(size: int) -> void:
	_notice.text = "" if Net.host(size) == OK else "No se pudo crear la partida. Prueba otra vez."
	_refresh()


func _set_fill(on: bool) -> void:
	Settings.fill_bots = on
	Settings.save()
	_refresh()




func _join(ip: String, owner_name: String, target_port := Net.PORT) -> void:
	_notice.text = ""
	if int(Net.discovery.groups.get("%s:%d" % [ip, target_port], {}).get("proto", 0)) != Net.PROTOCOL:
		_notice.text = "Esa partida usa otra versión: actualiza el juego."
		_refresh()
		return
	_join_seen = true
	_connecting = Net.join(ip, target_port) == OK
	_wait_label.text = "Entrando a la partida de %s…" % owner_name
	if not _connecting:
		_notice.text = "No se pudo entrar a la partida."
	_refresh()


func _on_closed(_reason: String) -> void:
	if not _connecting:
		return
	_connecting = false
	if _join_seen:
		_notice.text = "Veo la partida pero no logro entrar. Pídele al que la creó que revise su wifi y vuelve a intentarlo."
	else:
		_notice.text = "No se pudo entrar a la partida."
	_join_seen = false
	Net.discovery.listen()
	_refresh()


func _on_shown() -> void:
	if visible and not Net.active():
		if not Net.discovery.listen():
			_notice.text = "No se pueden buscar partidas en esta red."
	_refresh()


func _process(delta: float) -> void:
	_poll -= delta
	if _poll > 0.0 or not visible:
		return
	_poll = 0.5
	if _home.visible:
		_list_groups()


func _list_groups() -> void:
	for child in _found.get_children():
		child.queue_free()
	if Net.discovery.groups.is_empty():
		_found.add_child(UiStyle.label("Buscando partidas de tus amigos…" if Net.discovery.listening() else "—", 22, UiStyle.DIM))
		if Net.discovery.listening():
			_found.add_child(UiStyle.label("Si no sale nada: en el aparato de tu amigo deja que el juego use la red cuando el sistema pregunta, y revisa que los dos estén conectados a la misma red.", 16, UiStyle.DIM))
		return
	for key: String in Net.discovery.groups:
		var info: Dictionary = Net.discovery.groups[key]
		var size := int(info.get("size", 1))
		var owner_name := str(info.get("name", "?"))
		var outdated := int(info.get("proto", 0)) != Net.PROTOCOL
		var b := UiStyle.button("Partida de %s  ·  actualiza el juego" % owner_name if outdated else "Partida de %s  ·  %s  ·  %d de %d" % [owner_name, SIZE_NAMES.get(size, "").to_lower(),
			int(info.get("count", 0)), size * 2], 22, 0)
		b.disabled = outdated or not info.get("open", false)
		b.pressed.connect(_join.bind(str(info.get("ip", "")), owner_name, int(info.get("port", Net.PORT))))
		_found.add_child(b)


func _refresh() -> void:
	var in_group := Net.active() and Net.roster.has(Net.me())
	if in_group:
		_connecting = false
		_join_seen = false
	_group.visible = in_group
	_wait.visible = _connecting and not in_group
	_home.visible = not _group.visible and not _wait.visible
	if not in_group:
		return
	_title.text = "%s  ·  %d puntos" % [SIZE_NAMES.get(Net.team_size, ""), TeamMatch.TARGET]
	_status.text = _status_text()
	for team in 2:
		var col := _teams[team]
		for child in col.get_children():
			child.queue_free()
		var members := Net.roster.keys().filter(func(id: int) -> bool: return Net.team_of(id) == team)
		var mine := team == Net.team_of(Net.me())
		col.add_child(UiStyle.label("Tu equipo" if mine else "Equipo rival", 24, Scoreboard.ALLY if mine else Scoreboard.RIVAL))
		for id: int in members:
			var who := str(Net.roster[id]["name"]) + (" (tú)" if id == Net.me() else "")
			col.add_child(UiStyle.label(who, 22, UiStyle.WHITE))
		for i in Net.team_size - members.size():
			col.add_child(UiStyle.label("Libre", 22, Color(UiStyle.DIM, 0.5)))
	_start.visible = Net.hosting
	_maps_box.visible = Net.hosting
	_start.disabled = not Net.can_start()
