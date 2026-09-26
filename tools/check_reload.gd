extends Node
## Verify de la MESA de cargadores: validacion antes de consumir y regeneracion.
##
## Pregunta material: un `start_reload` RECHAZADO (cargador lleno, o recarga ya
## en curso) no puede llevarse un cargador de la mesa. Antes de existir
## `can_take`, se restaba primero y se devolvian las balas despues, asi que una
## recarga rechazada costs municion sin recargar nada.
##
##   godot4 --path . --headless tools/check_reload.tscn

var _fallos := 0


func _ready() -> void:
	var table := AmmoTable.new()
	add_child(table)
	var glock: Node3D = load("res://scripts/Glock.gd").new()
	glock.name = "Glock"
	add_child(glock)
	await get_tree().process_frame
	var pos: Vector3 = table.global_position

	# --- 1. Cargador lleno: el arma NO acepta recarga -> no se consume nada.
	var antes: int = table.mags
	glock.set("mag", 15)
	glock.set("chamber", 1)
	_check(not glock.call("can_reload"), "lleno: el arma no debe aceptar recarga")
	_check(table.mags == antes,
		"lleno: la mesa no debe perder cargador (antes=%d ahora=%d)" % [antes, table.mags])

	# --- 2. Recarga ya en curso: tampoco se consume.
	glock.set("mag", 5)
	glock.set("chamber", 0)
	glock.set("reloading", true)
	_check(not glock.call("can_reload"), "recargando: no debe aceptar otra recarga")
	_check(table.mags == antes, "recargando: la mesa no pierde cargador")
	glock.set("reloading", false)

	# --- 3. Recarga valida: se consume EXACTAMENTE uno.
	_check(glock.call("can_reload"), "vacio: el arma debe aceptar recarga")
	_check(table.can_take(pos), "al lado: hay cargador")
	var rounds: int = table.consume()
	_check(rounds == AmmoTable.MAG_ROUNDS,
		"consume devuelve %d (dio %d)" % [AmmoTable.MAG_ROUNDS, rounds])
	_check(table.mags == antes - 1,
		"valida: la mesa baja a %d (tiene %d)" % [antes - 1, table.mags])

	# --- 4. Se agota y se regenera sola, uno a uno.
	while table.mags > 0:
		table.consume()
	_check(table.mags == 0, "la mesa se puede agotar")
	_check(not table.can_take(pos), "mesa vacia: no se puede tomar")
	for i in range(5):
		table._process(AmmoTable.REGEN_S + 0.01)
	_check(table.mags == AmmoTable.MAX_MAGS,
		"la mesa se rellena sola hasta %d (tiene %d)" % [AmmoTable.MAX_MAGS, table.mags])

	# --- 5. Lejos de la mesa no se puede tomar.
	_check(not table.can_take(pos + Vector3(10, 0, 0)), "lejos: no se puede tomar cargador")

	if _fallos == 0:
		print("CHECK reload: OK (validacion antes de consumir + mesa que se rellena)")
	else:
		print("CHECK reload: %d FALLOS" % _fallos)
	get_tree().quit(1 if _fallos > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fallos += 1
		print("  FALLO: " + message)
