extends Node3D

## MODO COMBATE: BUNKER ROTO.
##
## Asset modelado y optimizado en Blender (`tools/build_combat_map.py` ->
## `assets/models/combat_bunker.glb`) y su colision autorada en
## `scenes/CombatBunker.tscn`, del MISMO dato que la geometria: 102 cajas y
## cilindros con `surface`, `penetrable` (y `thin_shell` / `wall_thickness` en lo
## que es cascara). No hay `create_trimesh_collision`: ni se construye nada en
## carga, ni la fisica resuelve mallas, y `Ballistics` puede sacar la cara de
## salida porque todas las formas son caja o cilindro.
##
## EL .glb NO lleva texturas dentro (6,19 MB de copias byte a byte de
## `assets/textures/real/` medidos por md5). Igual que `RangeShell`, el nombre
## de material que exporta el builder se reengancha aqui a los mapas del repo:
## una textura se paga una vez.
##
## LUZ Y EXPOSICION
## ----------------
## El mapa NO crea su propio `WorldEnvironment`: esta medido con una sonda que
## el environment activo en los dos modos es el de `Main.tscn` (un segundo
## WorldEnvironment en el mapa es inerte). Asi que aqui se escribe sobre el
## environment ACTIVO y se devuelve a su valor de origen al salir.
##
## La auto-exposicion de Godot es Forward+; en Mobile no existe. El efecto del
## video (interior oscuro -> exterior quemado -> adaptacion) se resuelve con
## CINCO zonas rectangulares y una interpolacion exponencial asimetrica: el ojo
## cierra rapido al salir a la luz y abre despacio al entrar en la oscuridad.
## Cero framework: una lista, una resta y dos tasas.

const BUNKER_SCENE := preload("res://scenes/CombatBunker.tscn")
const ENEMY_SCRIPT := preload("res://scripts/Enemy.gd")
const ENEMY_ASSET := "res://assets/models/enemy.glb"

## Nombre de MATERIAL del .glb -> mapas del repo. Las claves son exactamente las
## que exporta `tools/build_combat_map.py`; son dependencia de produccion, asi
## que un nombre que no resuelva aborta el arranque en vez de dejar un color
## plano de reserva. La escala de UV no se toca: viaja horneada en la malla.
const MAPS := {
	"Bunker_Concrete": {
		"albedo": "res://assets/textures/real/concrete_concrete_diff.jpg",
		"rough": "res://assets/textures/real/concrete_concrete_rough.jpg",
		"normal": "res://assets/textures/real/concrete_concrete_nor_gl.jpg",
		"color": Color(0.60, 0.60, 0.61),
		"metallic": 0.0,
		"roughness": 0.84,
		"normal_scale": 0.9,
	},
	"Bunker_Wood": {
		"albedo": "res://assets/textures/real/wood_oak_wood_planks_diff.jpg",
		"rough": "res://assets/textures/real/wood_oak_wood_planks_rough.jpg",
		"normal": "res://assets/textures/real/wood_oak_wood_planks_nor_gl.jpg",
		## El roble es de croma fuerte (media lineal 0,365/0,181/0,089): con el sol
		## encima se quemaba a ROSA porque el croma sobrevive a la exposicion. El
		## verde y el azul suben para dejarlo en madera curtida, no en teja.
		"color": Color(0.30, 0.42, 0.62),
		"metallic": 0.0,
		"roughness": 0.80,
		"normal_scale": 0.9,
	},
	"Bunker_Metal": {
		"albedo": "res://assets/textures/real/metal_metal_plate_diff.jpg",
		"rough": "res://assets/textures/real/metal_metal_plate_rough.jpg",
		"normal": "res://assets/textures/real/metal_metal_plate_nor_gl.jpg",
		## La chapa del repo es casi negra y caliente (0,049/0,034/0,012): sin boost
		## el acero se leia como un agujero. Con 0,35 de metalico y el reflejo del
		## cielo, la chapa sucia vuelve a leerse como acero.
		"color": Color(1.00, 1.06, 1.18),
		"metallic": 0.35,
		"roughness": 0.45,
		"normal_scale": 0.75,
	},
	"Bunker_Gypsum": {
		"albedo": "res://assets/textures/real/gypsum_diff.jpg",
		"rough": "res://assets/textures/real/gypsum_rough.jpg",
		"normal": "",
		"color": Color(0.72, 0.70, 0.66),
		"metallic": 0.0,
		"roughness": 0.88,
	},
	"Bunker_Floor": {
		"albedo": "res://assets/textures/real/concrete_brushed_concrete_diff.jpg",
		"rough": "res://assets/textures/real/concrete_brushed_concrete_rough.jpg",
		"normal": "res://assets/textures/real/concrete_brushed_concrete_nor_gl.jpg",
		"color": Color(0.54, 0.54, 0.55),
		"metallic": 0.0,
		"roughness": 0.70,
		"normal_scale": 0.5,
	},
	"Bunker_Roof": {
		"albedo": "res://assets/textures/real/concrete_concrete_diff.jpg",
		"rough": "res://assets/textures/real/concrete_concrete_rough.jpg",
		"normal": "res://assets/textures/real/concrete_concrete_nor_gl.jpg",
		"color": Color(0.42, 0.42, 0.43),
		"metallic": 0.0,
		"roughness": 0.88,
		"normal_scale": 0.9,
	},
}

## ZONAS DE EXPOSICION. `exposure` es el valor de tonemap adaptado a esa luz y
## `ambient` la energia del ambiente del cielo (que en Mobile ES la luz de
## relleno: no hay GI). Se recorren en orden y manda la primera que contiene la
## camara. El ambiente del patio es el ALTO a proposito: dentro se baja, y lo
## que se ve por un boquete es cielo quemado contra pared negra.
const ZONES := [
	{"rect": Rect2(-6.6, -3.8, 6.4, 4.4), "exposure": 4.30, "ambient": 0.075, "sky": 1.05, "contrib": 0.20},
	{"rect": Rect2(0.2, -3.8, 6.4, 4.4), "exposure": 4.05, "ambient": 0.105, "sky": 1.05, "contrib": 0.25},
	{"rect": Rect2(-4.8, -8.6, 9.6, 4.8), "exposure": 3.55, "ambient": 0.250, "sky": 1.35, "contrib": 0.55},
	{"rect": Rect2(-2.4, 0.6, 4.8, 4.0), "exposure": 3.30, "ambient": 0.300, "sky": 1.30, "contrib": 0.45},
	{"rect": Rect2(-5.2, 0.6, 10.4, 9.8), "exposure": 2.50, "ambient": 0.340, "sky": 1.25, "contrib": 1.00},
]
## Ambiente de relleno del interior: gris calido de polvo, no el azul del cielo.
## Un bunker no tiene GI en Mobile, pero si tiene polvo y rebote calido.
const AMBIENT_INDOOR := Color(0.62, 0.58, 0.52)
## El `Rect2` de arriba va en (x, z): esta plegado a mano cada vez que se
## pregunta, en una sola operacion.
const EXPOSURE_DEFAULT := {"exposure": 2.50, "ambient": 0.340, "sky": 1.25, "contrib": 1.00}
## Tasas de adaptacion. Salir a la luz ciega (rapido: 90 % en 1,1 s); entrar en
## la oscuridad abre despacio (90 % en 2,9 s), que es como se comporta el ojo y
## como se siente el tunel del video.
const ADAPT_TO_LIGHT := 2.0
const ADAPT_TO_DARK := 0.8

var ammo: AmmoTable
var bunker: Node3D

var _env: Environment
var _env_origin := {}
var _exposure := 0.0
var _ambient := 0.0
var _sky := 0.0
var _contrib := 1.0
var _zone := -1


func build() -> void:
	_environment()
	_load_bunker()
	_lights()
	_spawn_enemies()
	ammo = AmmoTable.new()
	ammo.name = "AmmoTable"
	## MEDIDO en captura: 1,8 m por delante y a la derecha de la brecha de
	## entrada, fuera del paso y a un paso del spawn (0, 0.05, 7.4) de Main.gd.
	ammo.position = Vector3(1.8, 0.0, 5.5)
	add_child(ammo)


## El environment es el de `Main.tscn`, compartido por lobby, banco y combate.
## Aqui no se sustituye: se escribe encima y se devuelve tal cual al salir, que
## es lo unico que mantiene las tres calibraciones iguales.
func _environment() -> void:
	var world := get_viewport().find_world_3d()
	_env = world.environment if world != null else null
	if _env == null:
		push_error("CombatMap: sin environment activo que adaptar")
		return
	_env_origin = {
		"exposure": _env.tonemap_exposure,
		"ambient": _env.ambient_light_energy,
		"sky": _env.background_energy_multiplier,
		"contrib": _env.ambient_light_sky_contribution,
		"color": _env.ambient_light_color,
	}
	_exposure = _env.tonemap_exposure
	_ambient = _env.ambient_light_energy
	_sky = _env.background_energy_multiplier
	_env.ambient_light_color = AMBIENT_INDOOR


func _exit_tree() -> void:
	if _env == null or _env_origin.is_empty():
		return
	_env.tonemap_exposure = _env_origin["exposure"]
	_env.ambient_light_energy = _env_origin["ambient"]
	_env.background_energy_multiplier = _env_origin["sky"]
	_env.ambient_light_sky_contribution = _env_origin["contrib"]
	_env.ambient_light_color = _env_origin["color"]


func _load_bunker() -> void:
	bunker = BUNKER_SCENE.instantiate() as Node3D
	bunker.name = "Bunker"
	add_child(bunker)
	_rebind(bunker.find_children("*", "MeshInstance3D", true, false))
	_contact_shadows(bunker.find_children("*", "StaticBody3D", true, false))


## Sustituye el material del .glb por el PBR del repo, por NOMBRE. El mapa del
## .glb no trae textura (el builder exporta solo el nombre), asi que sin este
## enganche el bunker se veria gris plano.
func _rebind(nodes: Array) -> void:
	var counts := {}
	for node in nodes:
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			push_error("CombatBunker contiene un MeshInstance3D sin malla")
			continue
		var key := ""
		for surface in range(mi.mesh.get_surface_count()):
			var source := mi.mesh.surface_get_material(surface)
			if source != null and source.resource_name != "":
				key = source.resource_name
				break
		var mat := _material(key)
		if mat == null:
			push_error("CombatMap no reconoce el material obligatorio: " + key)
			continue
		mi.material_override = mat
		counts[key] = int(counts.get(key, 0)) + 1
	print("COMBATE materiales: ", counts)


func _material(group: String) -> Material:
	if not MAPS.has(group):
		return null
	var spec: Dictionary = MAPS[group]
	var mat := StandardMaterial3D.new()
	mat.resource_name = group
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.albedo_color = spec["color"]
	mat.metallic = spec["metallic"]
	mat.roughness = spec["roughness"]
	for key in ["albedo", "rough", "normal"]:
		var path: String = spec[key]
		if path == "":
			continue
		var tex := load(path) as Texture2D
		if tex == null:
			push_error("CombatMap no pudo cargar " + key + " obligatorio: " + path)
			return null
		match key:
			"albedo":
				mat.albedo_texture = tex
			"rough":
				mat.roughness_texture = tex
			"normal":
				mat.normal_enabled = true
				mat.normal_texture = tex
				mat.normal_scale = spec.get("normal_scale", 0.8)
	mat.uv1_scale = Vector3.ONE
	return mat


## Sombra de contacto de los props que la piden DESDE EL ASSET
## (`metadata/contact` = semiejes x/z). El dato viaja con la pieza que lo
## justifica, no en una lista paralela que se quede vieja al mover el prop.
func _contact_shadows(bodies: Array) -> void:
	var blobs := ContactBlob.new()
	for node in bodies:
		var body := node as Node3D
		if not body.has_meta("contact"):
			continue
		var ext := body.get_meta("contact") as Vector2
		blobs.add(body.global_position.x, body.global_position.z, ext.x, ext.y)
	var mesh := blobs.build()
	if mesh != null:
		add_child(mesh)


## LUZ. El sol es la unica fuente con sombra: entra por la brecha y por los dos
## boquetes de techo y da el unico contacto que este mapa necesita (el suelo del
## patio y el haz del corredor). Las tres de relleno van sin sombra y con cull
## mask 1 para no tocar el viewmodel, que tiene su propia luz pegada a camara.
func _lights() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-46, 168, 0)
	sun.light_color = Color(1.0, 0.97, 0.92)
	sun.light_energy = 1.25
	## SIN DISCO SOLAR en el cielo: el sol de la referencia es difuso, y un
	## disco duro en el ProceduralSkyMaterial de `Main.tscn` (que no se toca)
	## dibujaba un foco de estudio en el techo del encuadre.
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.directional_shadow_max_distance = 42.0
	sun.light_cull_mask = 1
	add_child(sun)

	## DOS rellenos, no tres, y con alcance corto: en Mobile cada luz se evalua
	## por pixel de todo lo que caiga dentro de su radio, y el perfil A/B midio
	## ~10 ms para el juego de luces completo. El puesto no lleva ninguna: su
	## aspillera y el haz del sol ya le dan gradiente, y el ambiente de su zona
	## es de los mas altos. El relleno no pinta el material, solo saca el volumen
	## del negro, y para eso basta con que llegue al suelo de cada recinto.
	for spec in [
		{"name": "FillVault", "pos": Vector3(-4.2, 2.55, -1.6), "color": Color(0.70, 0.72, 0.78), "energy": 0.60, "range": 6.5},
		{"name": "FillBack", "pos": Vector3(0.0, 2.6, -6.2), "color": Color(0.80, 0.82, 0.88), "energy": 0.75, "range": 7.5},
	]:
		var fill := OmniLight3D.new()
		fill.name = spec["name"]
		fill.position = spec["pos"]
		fill.light_color = spec["color"]
		fill.light_energy = spec["energy"]
		fill.omni_range = spec["range"]
		fill.omni_attenuation = 0.9
		fill.shadow_enabled = false
		fill.light_cull_mask = 1
		add_child(fill)


func _process(delta: float) -> void:
	if _env == null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var target := _zone_at(camera.global_position)
	var rate := ADAPT_TO_LIGHT if target["exposure"] < _exposure else ADAPT_TO_DARK
	var blend := 1.0 - exp(-rate * delta)
	_exposure = lerpf(_exposure, target["exposure"], blend)
	_ambient = lerpf(_ambient, target["ambient"], blend)
	_sky = lerpf(_sky, target["sky"], blend)
	_contrib = lerpf(_contrib, target["contrib"], blend)
	_env.tonemap_exposure = _exposure
	_env.ambient_light_energy = _ambient
	_env.background_energy_multiplier = _sky
	_env.ambient_light_sky_contribution = _contrib


func _zone_at(point: Vector3) -> Dictionary:
	for i in ZONES.size():
		var rect: Rect2 = ZONES[i]["rect"]
		if point.x >= rect.position.x and point.x <= rect.position.x + rect.size.x \
				and point.z >= rect.position.y and point.z <= rect.position.y + rect.size.y:
			if i != _zone:
				_zone = i
			return ZONES[i]
	_zone = -1
	return EXPOSURE_DEFAULT


## Tres puestos, uno por recinto. Sin `enemy.glb` no se puebla nada (dependencia
## declarada, no un fallo): el mapa se juega vacio y se dice en consola.
func _spawn_enemies() -> void:
	if not ResourceLoader.exists(ENEMY_ASSET):
		print("COMBATE: sin enemigo (falta %s); el mapa se juega vacio" % ENEMY_ASSET)
		return
	var posts := [Vector3(-3.6, 0.05, -2.6), Vector3(3.8, 0.05, -2.9), Vector3(0.8, 0.05, -6.4)]
	for i in range(posts.size()):
		var enemy := ENEMY_SCRIPT.new()
		enemy.name = "Enemy%d" % (i + 1)
		add_child(enemy)
		enemy.global_position = posts[i]
