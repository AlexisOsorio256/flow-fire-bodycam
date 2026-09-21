extends Node
## Verify del BLOQUEO DE CORREDERA: tiene que ser VISIBLE, no solo correcto.
##
## El estado interno puede estar bien y el usuario no ver nada. Aqui se
## comprueba las dos cosas: que la corredera se queda atras 39 mm, y que el
## hueco de la ventana de expulsión es el que corresponde (que es lo que el ojo
## usa para leer "esta bloqueada").
##
##   godot4 --path . --headless tools/check_slide_lock.tscn

var _fallos := 0


func _ready() -> void:
	var glock: Node3D = load("res://scripts/Glock.gd").new()
	glock.name = "Glock"
	add_child(glock)
	await get_tree().process_frame
	await get_tree().process_frame

	var travel: float = glock.get("_travel")
	var viewmodel = glock.get("viewmodel")
	_check(viewmodel != null and viewmodel.weapon != null, "el arma monto")
	var weapon = viewmodel.weapon

	# ULTIMO disparo: recamara llena, cargador a cero.
	glock.set("mag", 0)
	glock.set("chamber", 1)
	glock.set("slide_locked", false)
	glock.set("slide_pos", 0.0)
	glock.set("slide_vel", 0.0)
	glock.call("force_fire_once")
	_check(glock.get("chamber") == 0, "el ultimo disparo vacia la recamara")

	# Dejar correr la mecanica hasta que se asiente (la corredera tarda ~70 ms).
	for i in range(180):
		glock.call("_update_slide", 1.0 / 120.0)
		glock.call("_process", 1.0 / 120.0)

	var locked: bool = glock.get("slide_locked")
	var pos: float = glock.get("slide_pos")
	_check(locked, "la corredera queda BLOQUEADA (slide_locked=true)")
	_check(absf(pos - travel) < 0.0005,
		"la corredera esta a fondo: %.1f mm de %.1f mm" % [pos * 1000.0, travel * 1000.0])

	# VISIBLE: la corredera tiene que estar desplazada de verdad en el arma.
	var slide_offset: Vector3 = weapon.slide.position - Vector3.ZERO
	# El recorrido se mide contra el reposo que guarda el arma.
	var rest: Vector3 = weapon.get("_slide_rest")
	var moved: float = (weapon.slide.position - rest).length()
	_check(moved > 0.0385,
		"la corredera esta DIBUJADA a %.1f mm de su reposo (debe ser ~39)"
		% (moved * 1000.0))

	# El cañon cae con la corredera: la boca no puede quedarse a la misma altura.
	var barrel_drop: float = absf(weapon.barrel.rotation.x)
	_check(barrel_drop > 0.01,
		"el canon cae al abrir (giro %.2f grados)" % rad_to_deg(barrel_drop))

	# Y NO vuelve a bateria: otro ciclo completo no debe cambiarla.
	for i in range(240):
		glock.call("_update_slide", 1.0 / 120.0)
	_check(glock.get("slide_locked") and absf(float(glock.get("slide_pos")) - travel) < 0.0005,
		"no vuelve a bateria sin cargador")

	# REGRESION: inspeccionar una pistola que YA esta bloqueada por vacio no puede
	# soltar la corredera. Antes Inspect tenia un RELEASE incondicional a 1,20 s y
	# cerraba sola aunque siguiera sin cargador ni cartucho.
	glock.call("inspect_weapon")
	for i in range(270):
		glock.call("_process", 1.0 / 120.0)
	_check(not bool(glock.get("inspecting")), "la inspeccion termina")
	_check(bool(glock.get("slide_locked")),
		"Inspect conserva el bloqueo previo cuando el arma sigue vacia")
	_check(absf(float(glock.get("slide_pos")) - travel) < 0.0005,
		"Inspect deja la corredera visualmente a fondo si ya estaba retenida")

	# Al soltar el gatillo con la corredera bloqueada, el mecanismo debe quedar
	# listo para que el siguiente intento en vacio produzca el click seco. Antes
	# este reset exigia slide_pos ~= 0 y por eso, precisamente bloqueada atras, la
	# Glock quedaba muda para siempre.
	glock.call("release_trigger")
	for i in range(30):
		glock.call("_update_trigger", 1.0 / 120.0)
	_check(bool(glock.get("trigger_ready")),
		"el gatillo resetea aunque la corredera este bloqueada")
	var voices_before := GameAudio.get_child_count()
	glock.call("press_trigger")
	glock.call("_update_trigger", 1.0 / 60.0)
	_check(GameAudio.get_child_count() > voices_before,
		"presionar vacia y bloqueada emite el click de dry-fire")
	glock.call("release_trigger")

	# DT DE JUEGO, no de laboratorio: a 120 Hz el bloqueo enganchaba pero en
	# partida (dt grande e irregular) la corredera pasaba de largo y volvia a
	# bateria sin bloquear. Se repite el ultimo tiro con dt 1/15 + tirones de
	# 1/8: debe bloquear igual.
	glock.set("mag", 0)
	glock.set("chamber", 1)
	glock.set("slide_locked", false)
	glock.set("slide_pos", 0.0)
	glock.set("slide_vel", 0.0)
	glock.set("slide_open", false)
	glock.set("slide_extracted", false)
	glock.call("force_fire_once")
	for i in range(60):
		var h := 1.0 / 15.0 if i % 3 else 1.0 / 8.0
		glock.call("_update_slide", h)
		glock.call("_process", h)
	_check(bool(glock.get("slide_locked")),
		"bloquea tambien con dt de juego (1/15 + tirones)")
	_check(absf(float(glock.get("slide_pos")) - travel) < 0.0005,
		"a fondo con dt de juego: %.1f mm" % [float(glock.get("slide_pos")) * 1000.0])
	_check((weapon.slide.position - rest).length() > 0.0385,
		"DIBUJADA a fondo con dt de juego")

	print("CHECK slide_lock: %s (recorrido=%.1f mm, bloqueada=%s)"
		% ["OK" if _fallos == 0 else "%d FALLOS" % _fallos, pos * 1000.0, locked])
	get_tree().quit(1 if _fallos > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fallos += 1
		print("  FALLO: " + message)
