extends Node
## BenchRender: mide el RENDER real del juego.
##
## Mide el DELTA REAL entre frames con vsync apagado y max_fps=0: si la GPU
## tarda mas, el delta sube. (La sonda vieja `check_fps.gd`, ya retirada, medía
## TIME_PROCESS de script y por eso no decía nada de la GPU.)
##
## DOS MODOS, Y NO VALEN LO MISMO
## ------------------------------
##   --view=WxH   El juego se dibuja en un SubViewport OFFSCREEN de ese tamano.
##                Mide coste de render puro. OJO: si se corre sobre un display
##                virtual (Xvfb) la "GPU" es llvmpipe y los FPS absolutos NO son
##                los del usuario; solo vale para comparar configuraciones.
##   sin --view   Se dibuja en la ventana. En el display REAL da el numero
##                honesto de esa GPU, pero abre ventana.
##
## La ventana se encoge a 64x64 (el minimo de Godot) y se manda fuera de
## pantalla. Eso NO cambia la resolucion de render cuando se usa --view: la
## confusion entre "ventana pequena" y "render pequeno" ya produjo numeros
## falsos en esta pasada, asi que queda escrito.
##
## Uso:
##   godot4 --path . --resolution 64x64 tools/bench_render.tscn -- \
##     --view=1920x1080 --warmup=40 --frames=120 --tag=base

var warmup := 40
var frames := 120
var tag := "bench"
var out_path := ""
var view_size := Vector2i.ZERO
var scale_3d := 1.0
var scale_mode := Viewport.SCALING_3D_MODE_BILINEAR
var msaa_override := -1
## `--skin=0` apaga la PIEL del viewmodel (los brazos) sin tocar nada mas. Es la
## unica forma de atribuirle un coste a los brazos: dos pasadas del mismo build,
## misma escena, misma luz, mismo mundo. Comparar contra un numero de otra
## maquina no atribuye nada.
var skin := true
## `--stress-fire=1` mide el caso que importa para los tirones: la Glock
## disparando a su cadencia real mientras el render sigue a 1080p. No es otro
## harness; usa la misma escena, el mismo benchmark y la ruta de produccion del
## arma. `force_fire_once()` solo salta el dedo/trigger visual: corredera,
## animacion, balistica, humo, casquillo, impactos y audio siguen siendo reales.
var stress_fire := false
var stress_fire_every := 5
## Cortes de PERFILADO. Viven aquí, no en Main.gd: producción no necesita
## conocer las preguntas que hace el benchmark. `medir.sh perfil` conserva su
## interfaz, pero las variantes se aplican después de instanciar la escena.
var profile_no_shadows := false
var profile_no_lights := false
var profile_no_fog := false
var profile_no_glow := false
var profile_no_world := false
var profile_no_hud := false

var _samples: Array[float] = []
var _frame := 0
var _game: Node = null
var _stress_weapon: Node = null
var _stress_shots := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := (a as String).split("=")
		if kv.size() != 2:
			continue
		match kv[0]:
			"--warmup":
				warmup = int(kv[1])
			"--frames":
				frames = int(kv[1])
			"--tag":
				tag = kv[1]
			"--out":
				out_path = kv[1]
			"--view":
				var parts := kv[1].split("x")
				view_size = Vector2i(int(parts[0]), int(parts[1]))
			"--scale":
				scale_3d = clampf(float(kv[1]), 0.1, 2.0)
			"--scale-mode":
				scale_mode = Viewport.SCALING_3D_MODE_FSR if kv[1].to_lower() == "fsr" \
					else Viewport.SCALING_3D_MODE_BILINEAR
			"--msaa":
				match int(kv[1]):
					0: msaa_override = Viewport.MSAA_DISABLED
					2: msaa_override = Viewport.MSAA_2X
					4: msaa_override = Viewport.MSAA_4X
					8: msaa_override = Viewport.MSAA_8X
			"--skin":
				skin = kv[1] != "0"
			"--stress-fire":
				stress_fire = kv[1] == "1"
			"--fire-every":
				stress_fire_every = maxi(5, int(kv[1]))
			"--no-shadows":
				profile_no_shadows = kv[1] == "1"
			"--no-lights":
				profile_no_lights = kv[1] == "1"
			"--no-fog":
				profile_no_fog = kv[1] == "1"
			"--no-glow":
				profile_no_glow = kv[1] == "1"
			"--no-world":
				profile_no_world = kv[1] == "1"
			"--no-hud":
				profile_no_hud = kv[1] == "1"
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_size(Vector2i(64, 64))
	DisplayServer.window_set_position(Vector2i(-6000, -6000))

	_game = load("res://scenes/Main.tscn").instantiate()
	if view_size != Vector2i.ZERO:
		var container := SubViewport.new()
		container.size = view_size
		container.scaling_3d_scale = scale_3d
		container.scaling_3d_mode = scale_mode
		if msaa_override >= 0:
			container.msaa_3d = msaa_override as Viewport.MSAA
		else:
			# Un SubViewport no hereda el MSAA del proyecto. Si no se fuerza una
			# variante A/B, medir exactamente el ajuste de producción.
			msaa_override = int(ProjectSettings.get_setting(
				"rendering/anti_aliasing/quality/msaa_3d", Viewport.MSAA_DISABLED
			))
			container.msaa_3d = msaa_override as Viewport.MSAA
		container.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		container.audio_listener_enable_3d = true
		container.own_world_3d = true
		add_child(container)
		container.add_child(_game)
	else:
		add_child(_game)
	await get_tree().process_frame
	_apply_profile_overrides()
	if not skin:
		_set_skin_visible(_game, false)
	if stress_fire:
		var player := _game.get_node_or_null("Player")
		if player != null:
			_stress_weapon = player.get("weapon")
			# Blanco fijo de acero usado también por shot.gd. Así cada ejecución
			# produce la misma familia de impacto y no depende de qué objeto agarre
			# el retroceso desde el spawn general del rango.
			(player as Node3D).global_position = Vector3(0.0, 0.05, -24.0)
			player.set("yaw", 0.0)
			player.set("yaw_target", 0.0)
			player.set("pitch", -0.02)
			player.set("pitch_target", -0.02)
		if _stress_weapon == null:
			push_error("BENCH stress-fire sin Glock")
			get_tree().quit(1)
			return
		# En modo offscreen el juego vive dentro del SubViewport. Los autoloads 3D
		# viven normalmente junto a Main en el viewport raiz; para este stress deben
		# entrar en el MISMO viewport/world o la balistica no ve la camara y los FX
		# no forman parte del render medido. La referencia global del singleton sigue
		# siendo la misma; solo cambia su padre durante este proceso de benchmark.
		if view_size != Vector2i.ZERO:
			var stress_view := _game.get_parent()
			for autoload_name in ["Ballistics", "ImpactFX"]:
				var singleton := get_node_or_null("/root/" + autoload_name)
				if singleton != null:
					singleton.reparent(stress_view)
		# El benchmark dura mas que un cargador. La mesa/inventario no forma parte
		# de esta medicion; se amplia solo la reserva interna para poder repetir el
		# mismo disparo mecanico durante toda la ventana sin meter una recarga.
		_stress_weapon.set("mag", 1000)
		if _stress_weapon.has_signal("shot_fired"):
			_stress_weapon.shot_fired.connect(_on_stress_shot)


func _apply_profile_overrides() -> void:
	if profile_no_world:
		var world := _game.get_node_or_null("World")
		if world != null:
			world.visible = false
			world.process_mode = Node.PROCESS_MODE_DISABLED
	if profile_no_hud:
		var hud := _game.get_node_or_null("HUD")
		if hud != null:
			hud.visible = false
	if profile_no_lights:
		for node in _game.find_children("*", "Light3D", true, false):
			(node as Light3D).visible = false
	elif profile_no_shadows:
		for node in _game.find_children("*", "Light3D", true, false):
			(node as Light3D).shadow_enabled = false
	if profile_no_fog or profile_no_glow:
		var env_node := _game.get_node_or_null("WorldEnvironment") as WorldEnvironment
		if env_node != null and env_node.environment != null:
			if profile_no_fog:
				env_node.environment.fog_enabled = false
			if profile_no_glow:
				env_node.environment.glow_enabled = false


## Apaga SOLO las mallas que cuelgan del esqueleto de los brazos. Se busca por
## tipo de nodo, no por nombre de escena: si el asset se reexporta con otro
## nombre, la medicion sigue valiendo.
func _set_skin_visible(root: Node, visible: bool) -> void:
	var stack: Array = [root]
	var hidden := 0
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D and (node as MeshInstance3D).skin != null:
			(node as MeshInstance3D).visible = visible
			hidden += 1
		for child in node.get_children():
			stack.append(child)
	print("BENCH skin=%s mallas_apagadas=%d" % [str(visible), hidden])


func _process(delta: float) -> void:
	_frame += 1
	if _frame <= warmup:
		return
	if _samples.size() >= frames:
		_report()
		return
	if stress_fire and _stress_weapon != null:
		# El patrón depende del índice de muestra, no del tiempo de una ejecución.
		# Así un build lento no recibe más disparos simplemente porque sus 120
		# frames tardaron más en pasar. Cinco frames son >120 ms en esta iGPU y
		# dejan cerrar la Glock antes del siguiente intento.
		if _samples.size() % stress_fire_every == 0:
			_stress_weapon.call("force_fire_once")
	# Delta real entre frames. Con vsync off esto ES el frame time: la CPU espera
	# a que la GPU termine, asi que el coste de render entra aqui.
	_samples.append(delta * 1000.0)


func _on_stress_shot() -> void:
	_stress_shots += 1


func _stat(values: Array[float]) -> Dictionary:
	var sorted := values.duplicate()
	sorted.sort()
	var n := sorted.size()
	if n == 0:
		return {"mean": 0.0, "p50": 0.0, "p95": 0.0, "p99": 0.0}
	var sum := 0.0
	for v in sorted:
		sum += v
	return {
		"mean": sum / float(n),
		"p50": sorted[int(n * 0.50)],
		"p95": sorted[int(min(n - 1, n * 0.95))],
		"p99": sorted[int(min(n - 1, n * 0.99))],
	}


func _report() -> void:
	var s := _stat(_samples)
	var prims := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("BENCH tag=%s frames=%d view=%dx%d scale=%.3f mode=%d msaa=%d | frame mean_ms=%.2f p50=%.2f p95=%.2f p99=%.2f | fps_mean=%.1f fps_p95=%.1f | draws=%d prims=%d" % [
		tag, _samples.size(), view_size.x, view_size.y,
		scale_3d, scale_mode, msaa_override,
		s["mean"], s["p50"], s["p95"], s["p99"],
		1000.0 / maxf(s["mean"], 0.0001), 1000.0 / maxf(s["p95"], 0.0001),
		draws, prims,
	])
	if stress_fire:
		print("BENCH stress_fire shots=%d every_frames=%d" % [_stress_shots, stress_fire_every])
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f != null:
			var merged := s.duplicate()
			merged["tag"] = tag
			merged["frames"] = _samples.size()
			merged["samples_ms"] = _samples
			f.store_string(JSON.stringify(merged))
	get_tree().quit()
