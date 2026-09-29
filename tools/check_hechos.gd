extends Node

## CHECK DE HECHOS. Existe por una razon concreta y medida: la ficha
## `docs/HOUSE_DESIGN.md` llego a afirmar 158 colisores donde habia 299, cuatro
## puestos donde habia ocho y una tabla de zonas de exposicion dos versiones
## vieja. Ninguna de esas frases la caza un test, porque no son codigo: son
## numeros en prosa. Y una IA que abre el repo sin la sesion anterior no puede
## distinguir un dato medido de un dato recordado.
##
## Aqui NO se prueba el juego: eso lo hacen los otros checks. Aqui se comprueba
## que cada numero que la ficha publica SIGUE SIENDO VERDAD, leyendo el dato
## vivo (escena, script, asset) y buscando su cifra en el doc. Si el codigo
## cambia y el doc no, esto se pone rojo: el doc deja de poder mentir en
## silencio.
##
##   godot4 --path . --headless tools/check_hechos.tscn

const HOUSE := "res://scenes/House.tscn"
const MAIN := "res://scenes/Main.tscn"
const COMBAT := "res://scripts/CombatMap.gd"
const ENEMY := "res://scripts/Enemy.gd"
const DESIGN := "res://docs/HOUSE_DESIGN.md"
const PROJECT := "res://project.godot"
const REFS := "res://docs/REFS.md"
const CICLO := "res://docs/CICLO.md"
const VERIFICAR := "res://tools/verificar.sh"

var _fallos := 0
var _comprobados := 0


func _ready() -> void:
	var doc := FileAccess.get_file_as_string(DESIGN)
	if doc.is_empty():
		push_error("FACT: no se puede leer " + DESIGN)
		_fallo("no se puede leer la ficha")
		_salir()
		return

	_hechos_casa(doc)
	_hechos_mapa(doc)
	_hechos_enemigo(doc)
	_hechos_render(doc)
	_hechos_renderer(doc)
	_hechos_protocolo()

	_salir()


# ---------------------------------------------------------------------------
# Lo que la ficha dice de la casa.
# ---------------------------------------------------------------------------
func _hechos_casa(doc: String) -> void:
	var house := (load(HOUSE) as PackedScene).instantiate()
	var cuerpos := 0
	var formas := {}
	for node in house.find_children("*", "StaticBody3D", true, false):
		cuerpos += 1
		for hijo in node.get_children():
			if hijo is CollisionShape3D:
				var s := (hijo as CollisionShape3D).shape
				if s is BoxShape3D:
					formas["BoxShape3D"] = int(formas.get("BoxShape3D", 0)) + 1
				elif s is CylinderShape3D:
					formas["CylinderShape3D"] = int(formas.get("CylinderShape3D", 0)) + 1
	var ocultadores := house.find_children("*", "OccluderInstance3D", true, false).size()
	## El conteo de SURFACIES es el que usa Ballistics: se lee del metadata, que
	## es la misma fuente que el runtime.
	var por_superficie := {}
	for node in house.find_children("*", "StaticBody3D", true, false):
		var s: String = node.get_meta("surface", "")
		por_superficie[s] = int(por_superficie.get(s, 0)) + 1
	house.free()

	_publica(doc, "%d `StaticBody3D`" % cuerpos, "cuerpos con colision de la casa")
	_publica(doc, "%d ocultadores" % ocultadores, "ocultadores de oclusion")
	## Las formas se publican como suma ("190 formas unicas: 186 Box + 4 Cyl"), no
	## una por una con su nombre de clase: se comprueban sus CIFRAS.
	var cajas := int(formas.get("BoxShape3D", 0))
	var cils := int(formas.get("CylinderShape3D", 0))
	_publica(doc, "%d `BoxShape3D`" % cajas, "formas de caja")
	_publica(doc, "%d `CylinderShape3D`" % cils, "formas de cilindro")
	if cajas + cils != cuerpos:
		_fallo("hay %d cuerpos y %d formas de colision: sobran o faltan" % [cuerpos, cajas + cils])
	else:
		_ok("cada cuerpo tiene exactamente una forma de colision")
	## La tabla del apartado 1 desglosa los cuerpos por superficie: si el desglose
	## no suma el total, la ficha se contradice a si misma.
	var suma := 0
	for k in por_superficie:
		suma += int(por_superficie[k])
	if suma != cuerpos:
		_fallo("el desglose por superficie suma %d y hay %d cuerpos" % [suma, cuerpos])
	else:
		_ok("los %d cuerpos estan todos clasificados por superficie" % cuerpos)


# ---------------------------------------------------------------------------
# Lo que la ficha dice del mapa: puestos, materiales y zonas de exposicion.
# ---------------------------------------------------------------------------
func _hechos_mapa(doc: String) -> void:
	var script := load(COMBAT) as GDScript
	var posts: Array = script.get_script_constant_map()["POSTS"]
	_publica(doc, "%d puestos" % posts.size(), "puestos enemigos de CombatMap.POSTS")

	var maps: Dictionary = script.get_script_constant_map()["MAPS"]
	_publica(doc, "%d materiales" % maps.size(), "materiales que reengancha el mapa")

	## Las zonas de exposicion: el doc publica una tabla. Se comprueba que cada
	## numero de la tabla existe en la constante, no que la tabla este ordenada.
	var zonas: Array = script.get_script_constant_map()["ZONES"]
	var faltan := []
	for z in zonas:
		var zz: Dictionary = z
		for clave in ["exposure", "ambient", "sky", "contrib"]:
			## El doc escribe con coma decimal, como el resto de la ficha.
			var txt := ("%.3f" % float(zz[clave])).rstrip("0").rstrip(".")
			var es := txt.replace(".", ",")
			if not doc.contains(es):
				faltan.append("%s=%s" % [clave, es])
	if faltan.is_empty():
		_ok("las %d zonas de exposicion publican los valores vivos" % zonas.size())
	else:
		_fallo("la tabla de zonas no publica: " + ", ".join(faltan))

	## Los rellenos: la ficha publica sus alcances. La autoridad es esta tabla,
	## no lo que haya montado en la escena (el mapa se construye en runtime).
	var luces: Array = script.get_script_constant_map()["LIGHTS"]
	if luces.is_empty():
		_fallo("CombatMap.LIGHTS no declara ningun relleno")
	else:
		var faltan_luz := []
		for l in luces:
			var t := ("%.1f" % float((l as Dictionary)["range"])).replace(".", ",")
			if not doc.contains(t):
				faltan_luz.append(t + " m")
		if faltan_luz.is_empty():
			_ok("los %d alcances de relleno estan publicados" % luces.size())
		else:
			_fallo("la ficha no publica estos alcances de relleno: " + ", ".join(faltan_luz))

	var defecto: Dictionary = script.get_script_constant_map()["EXPOSURE_DEFAULT"]
	var falta_def := []
	for clave in ["exposure", "ambient", "sky", "contrib"]:
		var txt := ("%.3f" % float(defecto[clave])).rstrip("0").rstrip(".")
		var es := txt.replace(".", ",")
		if not doc.contains(es):
			falta_def.append("%s=%s" % [clave, es])
	if falta_def.is_empty():
		_ok("la exposicion por defecto (fuera) tambien esta publicada")
	else:
		_fallo("la exposicion por defecto no publica: " + ", ".join(falta_def))


# ---------------------------------------------------------------------------
# Lo que la ficha dice del enemigo.
# ---------------------------------------------------------------------------
func _hechos_enemigo(doc: String) -> void:
	var enemy := load(ENEMY) as GDScript
	var alto: float = enemy.get_script_constant_map()["BODY_HEIGHT"]
	var txt := ("%.2f" % alto).replace(".", ",")
	if doc.contains(txt):
		_ok("el alto del enemigo (%s m) esta publicado" % txt)
	else:
		_fallo("la ficha no publica el alto vivo del enemigo (%s m)" % txt)

	## Los clips que el glb exporta de verdad: si el asset cambia, la ficha
	## tampoco puede seguir diciendo otro numero.
	var glb := "res://assets/models/enemy.glb"
	var bytes := FileAccess.get_file_as_bytes(glb)
	if bytes.size() < 20:
		_fallo("no se puede leer " + glb)
		return
	var json_len := bytes.decode_u32(12)
	var json: Variant = JSON.parse_string(bytes.slice(20, 20 + json_len).get_string_from_utf8())
	var clips: Array = (json as Dictionary).get("animations", [])
	_publica(doc, "%d clips" % clips.size(), "clips que exporta enemy.glb")


# ---------------------------------------------------------------------------
# Lo que la ficha dice del render.
# ---------------------------------------------------------------------------
func _hechos_render(doc: String) -> void:
	var main := (load(MAIN) as PackedScene).instantiate()
	var env := main.find_children("*", "WorldEnvironment", true, false)
	if env.is_empty():
		_fallo("Main.tscn no tiene WorldEnvironment")
		main.free()
		return
	var e: Environment = (env[0] as WorldEnvironment).environment
	## El cielo: los tres colores que la ficha publica.
	var sky: Sky = e.sky
	var mat := sky.sky_material as ProceduralSkyMaterial
	if mat == null:
		_fallo("el cielo de Main.tscn no es ProceduralSkyMaterial")
	else:
		_color_publicado(doc, mat.sky_top_color, "sky_top")
		_color_publicado(doc, mat.sky_horizon_color, "sky_horizon")

	## Niebla y glow: la ficha afirma que estan apagados y por que. Si alguien
	## los enciende, el parrafo de rendimiento se vuelve mentira.
	if not e.fog_enabled:
		_ok("la niebla esta apagada, como dice la ficha")
	else:
		_fallo("la ficha dice que la niebla esta apagada y Main.tscn la tiene encendida")
	if not e.glow_enabled:
		_ok("el glow esta apagado, como dice la ficha")
	else:
		_fallo("la ficha dice que el glow esta apagado y Main.tscn lo tiene encendido")

	main.free()


# ---------------------------------------------------------------------------
# Lo que la ficha dice del renderer. Aqui vivio el error mas caro de la ficha:
# publicaba FSR1 y el proyecto corre Mobile, donde FSR no existe.
# ---------------------------------------------------------------------------
func _hechos_renderer(doc: String) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PROJECT) != OK:
		_fallo("no se puede leer project.godot")
		return
	var metodo: String = cfg.get_value("rendering", "renderer/rendering_method", "")
	if metodo != "mobile":
		_ok("el renderer es '%s': la ficha puede hablar de Forward+" % metodo)
		return
	## Es Mobile: la ficha NO puede prometer FSR ni auto-exposicion.
	for palabra in ["FSR1", "FSR2"]:
		if doc.contains(palabra):
			_fallo("la ficha cita %s y el renderer es Mobile (no existe ahi)" % palabra)
	_ok("el renderer Mobile y la ficha no prometen FSR")

	var modo: int = cfg.get_value("rendering", "scaling_3d/mode", 0)
	if modo == 0:
		_ok("la escala 3D esta en bilinear explicito (mode=0)")
	else:
		_fallo("scaling_3d/mode=%d: en Mobile solo el bilinear (0) es real" % modo)

	var escala: float = cfg.get_value("rendering", "scaling_3d/scale", 1.0)
	var t := ("%s" % escala).replace(".", ",")
	if doc.contains(t) or doc.contains(("%.1f" % escala).replace(".", ",")):
		_ok("la escala 3D (%.2f) esta publicada" % escala)
	else:
		_fallo("la ficha no publica la escala 3D viva (%.2f)" % escala)


# ---------------------------------------------------------------------------
# Utilidades.
# ---------------------------------------------------------------------------
## Un color del doc se escribe "0,50 / 0,525 / 0,575": tres cifras con coma.
func _color(c: Color) -> String:
	var partes := []
	for v in [c.r, c.g, c.b]:
		partes.append(("%.3f" % v).rstrip("0").rstrip(".").replace(".", ","))
	return " / ".join(partes)


## Un color del doc se escribe "0,50 / 0,50 / 0,50" y cada cifra puede venir con
## uno o dos decimales. Se comprueba CADA canal por su valor redondeado, que es
## lo que el lector del doc compara a ojo.
# ---------------------------------------------------------------------------
# Lo que el PROTOCOLO promete. `docs/CICLO.md` manda a los agentes a
# `verificar.sh` y cuenta sus checks: si alguien anade o quita un check y no
# toca el protocolo, el protocolo empieza a mentir. Se comprueba contra el
# script real, no contra una copia.
# ---------------------------------------------------------------------------
func _hechos_protocolo() -> void:
	var sh := FileAccess.get_file_as_string(VERIFICAR)
	if sh.is_empty():
		_fallo("no se puede leer " + VERIFICAR)
		return
	var m := RegEx.new()
	m.compile("for t in ([a-z_ ]+); do")
	var r := m.search(sh)
	if r == null:
		_fallo("verificar.sh no declara su lista de checks")
		return
	var checks := r.get_string(1).split(" ", false)
	_ok("verificar.sh declara %d checks" % checks.size())

	var ciclo := FileAccess.get_file_as_string(CICLO)
	if ciclo.is_empty():
		_fallo("no se puede leer " + CICLO)
		return
	## El protocolo publica el numero de checks: TODAS sus apariciones tienen que
	## ser el real. Buscar una sola (`_publica`) era un falso verde: el documento
	## dice "7 checks" en dos sitios, y al corregir uno solo el otro tapaba el
	## error. Aqui se recorren todas y se exige que cuadren.
	var cuantas := 0
	var malas := 0
	var mnum := RegEx.new()
	mnum.compile("(\\d+) checks")
	for r2 in mnum.search_all(ciclo):
		cuantas += 1
		if int(r2.get_string(1)) != checks.size():
			malas += 1
			_fallo("docs/CICLO.md dice \"%s\" y verificar.sh tiene %d checks"
				% [r2.get_string(0), checks.size()])
	if cuantas == 0:
		_fallo("docs/CICLO.md no publica el numero de checks")
	else:
		_ok("docs/CICLO.md publica %d veces el numero de checks, todas correctas"
			% cuantas) if malas == 0 else null
	## Y los NOMBRES: un protocolo que nombra un check que ya no existe manda al
	## agente a un comando roto.
	for t in checks:
		if not ciclo.contains("`%s`" % t):
			_fallo("docs/CICLO.md no nombra el check `%s`" % t)
	## El protocolo cita ficheros: todos tienen que existir hoy.
	for ruta in ["docs/HOUSE_DESIGN.md", "docs/REFS.md", "docs/refs",
			"tools/verificar.sh", "tools/check_hechos.gd", "tools/check_walk.gd",
			"tools/medir.sh", "scenes/House.tscn", "assets/models/house.glb"]:
		var ruta_abs: String = "res://" + ruta
		if not FileAccess.file_exists(ruta_abs) \
				and not DirAccess.dir_exists_absolute(ruta_abs):
			_fallo("docs/CICLO.md cita `%s` y no existe" % ruta)
	## Y las referencias del dueño no se tocan desde un ciclo: si desaparecen,
	## el protocolo esta mandando a un agente a un sitio vacio.
	var refs := FileAccess.get_file_as_string(REFS)
	if refs.is_empty():
		_fallo("no se puede leer " + REFS)
	else:
		var dir := DirAccess.open("res://docs/refs")
		if dir == null:
			_fallo("no existe docs/refs/")
		else:
			## CADA referencia tiene que estar NOMBRADA en REFS.md. No basta con
			## contar: el 2026-09-28 entraron ref6 y ref7 y el documento siguio
			## hablando de "las cinco" durante un dia entero, con los tamanos y
			## dimensiones mal. Se comprueba por NOMBRE, que es lo que faltaba.
			var imagenes := 0
			var bytes_totales := 0
			for f in dir.get_files():
				if not (f.ends_with(".jpg") or f.ends_with(".jpeg")):
					continue
				imagenes += 1
				bytes_totales += FileAccess.get_file_as_bytes(
					"res://docs/refs/" + f).size()
				if not refs.contains(f):
					_fallo("docs/refs/%s no esta documentada en docs/REFS.md" % f)
			_ok("docs/refs/: %d referencias, todas nombradas en REFS.md"
				% imagenes)
			if imagenes == 0:
				_fallo("docs/refs/ sin referencias: el contrato visual queda vacio")
			## Y la SUMA de bytes, que es el numero que mas facil se queda viejo.
			_publica(refs, "%s B" % _millares(bytes_totales),
				"bytes totales de docs/refs/")


## Formatea un entero con punto de millar (1461187 -> "1.461.187"), que es como
## se publica en la ficha. Se escribe a mano porque `String.num_int64` no agrupa.
func _millares(n: int) -> String:
	var s := str(n)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "." + out
	return out


func _color_publicado(doc: String, c: Color, que: String) -> void:
	var faltan := []
	for v in [c.r, c.g, c.b]:
		var dos := ("%.2f" % v).replace(".", ",")
		var tres := ("%.3f" % v).rstrip("0").rstrip(".").replace(".", ",")
		if not doc.contains(dos) and not doc.contains(tres):
			faltan.append(dos)
	if faltan.is_empty():
		_ok("%s: publicado" % que)
	else:
		_fallo("la ficha no publica el canal %s de %s" % [", ".join(faltan), que])


## El hecho se publica SOLO si la cadena exacta aparece en el doc.
func _publica(doc: String, aguja: String, que: String) -> void:
	if doc.contains(aguja):
		_ok("%s: %s" % [que, aguja])
	else:
		_fallo("la ficha no publica %s (el dato vivo es '%s')" % [que, aguja])


func _ok(_que: String) -> void:
	_comprobados += 1


func _fallo(que: String) -> void:
	_fallos += 1
	print("  FALLO: ", que)


func _salir() -> void:
	print("FACT: %d hechos comprobados, %d fallos" % [_comprobados, _fallos])
	if _fallos > 0:
		print("FACT: la ficha miente en %d sitios" % _fallos)
	get_tree().quit(1 if _fallos > 0 else 0)
