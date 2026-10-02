extends Node3D

## MODO COMBATE: casa de tiro de tablero (ref8). Una planta, pasillo central y
## seis cuartos, muros de tablero OSB con rastreles vistos, techo de chapa con
## celosia de acero y tubos fluorescentes encendidos.
##
## EL MAPA ES UN DATO. Las cotas, los tubos, los puestos de enemigo y el punto
## de municion viven en `scenes/Map.tscn`, que escribe `tools/build_map.py`.
## Aqui no se repite ni una coordenada: se leen los marcadores de la escena. El
## nombre del fichero describe el ROL (el mapa del modo combate); la API es
## estable: `build()` y `ammo`.
##
## EL .glb NO lleva texturas dentro: el nombre de material que exporta el
## builder se reengancha aqui a los mapas del repo. Una textura se paga una vez.
##
## LUZ Y EXPOSICION. El mapa NO crea su propio `WorldEnvironment`: el activo es
## el de `Main.tscn` (el unico de la escena; un segundo con mas prioridad ganaria
## y seria una segunda autoridad de cielo y exposicion sobre el mismo cuadro).
## Aqui se escribe sobre el activo y se devuelve a su valor al salir.

const MAP_SCENE := preload("res://scenes/Map.tscn")
const ENEMY_SCRIPT := "res://scripts/Enemy.gd"
const ENEMY_ASSET := "res://assets/models/enemy.glb"

## Nombre de MATERIAL del .glb -> mapas del repo. Las claves son exactamente las
## que exporta `tools/build_map.py`; un nombre que no resuelva aborta el
## enganche en vez de dejar un color plano de reserva. La escala de UV no se
## toca: viaja horneada en la malla, en metros por vuelta de textura.
##
## El tinte se multiplica contra el valor sRGB que sale del fichero, que es como
## se mide el color de un material en este proyecto.
const MAPS := {
	"Map_Osb": {
		"albedo": "res://assets/textures/map/osb_diff.jpg",
		"rough": "res://assets/textures/map/osb_rough.jpg",
		"normal": "res://assets/textures/map/osb_nor_gl.jpg",
		"color": Color(0.93, 0.91, 0.88),
		"metallic": 0.0,
		"roughness": 0.86,
		"normal_scale": 0.9,
	},
	"Map_Floor": {
		## Mismo tablero que el muro, mas oscuro y con la veta mas abierta: el
		## suelo se pisa y el muro no.
		"albedo": "res://assets/textures/map/osb_diff.jpg",
		"rough": "res://assets/textures/map/osb_rough.jpg",
		"normal": "res://assets/textures/map/osb_nor_gl.jpg",
		"color": Color(0.60, 0.54, 0.46),
		"metallic": 0.0,
		"roughness": 0.92,
		"normal_scale": 0.7,
		"uv_scale": Vector2(0.73, 0.73),
	},
	"Map_Stud": {
		## Rastrel de pino: la madera clara que enmarca cada panel.
		"albedo": "res://assets/textures/real/wood_oak_wood_planks_diff.jpg",
		"rough": "res://assets/textures/real/wood_oak_wood_planks_rough.jpg",
		"normal": "res://assets/textures/real/wood_oak_wood_planks_nor_gl.jpg",
		"color": Color(0.88, 0.80, 0.68),
		"metallic": 0.0,
		"roughness": 0.80,
		"normal_scale": 0.6,
	},
	"Map_Roof": {
		"albedo": "res://assets/textures/map/roof_steel_diff.jpg",
		"rough": "res://assets/textures/map/roof_steel_rough.jpg",
		"normal": "res://assets/textures/map/roof_steel_nor_gl.jpg",
		"color": Color(0.70, 0.65, 0.59),
		"metallic": 0.10,
		"roughness": 0.82,
		"normal_scale": 0.5,
	},
	"Map_Steel": {
		"albedo": "res://assets/textures/map/roof_steel_diff.jpg",
		"rough": "res://assets/textures/map/roof_steel_rough.jpg",
		"normal": "res://assets/textures/map/roof_steel_nor_gl.jpg",
		"color": Color(0.85, 0.62, 0.44),
		"metallic": 0.30,
		"roughness": 0.65,
		"normal_scale": 0.5,
	},
	"Map_Tube": {
		## El tubo es la UNICA fuente de luz interior y se ve a si mismo: el
		## emisivo lo dibuja encendido sin post-proceso.
		"albedo": "", "rough": "", "normal": "",
		"color": Color(0.94, 0.95, 0.97),
		"metallic": 0.0,
		"roughness": 0.35,
		"emission": Color(1.00, 0.97, 0.92),
		"emission_energy": 2.4,
	},
	"Map_Tarp": {
		## Lona oscura del cuarto noreste, tejido militar curtido.
		"albedo": "res://assets/textures/enemy/fabric_color.jpg",
		"rough": "res://assets/textures/enemy/fabric_rough.jpg",
		"normal": "res://assets/textures/enemy/fabric_normal.jpg",
		"color": Color(0.20, 0.20, 0.22),
		"metallic": 0.0,
		"roughness": 0.90,
		"normal_scale": 1.1,
		"uv_scale": Vector2(1.5, 1.5),
	},
	"Map_Wall": {
		## Chapa grecada de la NAVE: el material que separa el dentro del fuera.
		## Sin el, los muros de la nave repetian el tablero de la casa y todo el
		## mapa se leia como una caja de OSB.
		"albedo": "res://assets/textures/real/concrete_brushed_concrete_diff.jpg",
		"rough": "res://assets/textures/real/concrete_brushed_concrete_rough.jpg",
		"normal": "res://assets/textures/real/concrete_brushed_concrete_nor_gl.jpg",
		"color": Color(0.52, 0.52, 0.51),
		"metallic": 0.0,
		"roughness": 0.93,
		"normal_scale": 0.5,
	},
	"Map_Frame": {
		## Acero de taller de la nave: girts, cerchas y tirantes. El oxido del
		## techo es de la casa; la estructura de la nave es gris de fabrica.
		"albedo": "res://assets/textures/map/roof_steel_diff.jpg",
		"rough": "res://assets/textures/map/roof_steel_rough.jpg",
		"normal": "res://assets/textures/map/roof_steel_nor_gl.jpg",
		"color": Color(0.28, 0.29, 0.31),
		"metallic": 0.55,
		"roughness": 0.55,
		"normal_scale": 0.4,
	},
	"Map_Concrete": {
		## Losa de taller del anillo: hormigon cepillado, no tablero pisado.
		"albedo": "res://assets/textures/real/concrete_brushed_concrete_diff.jpg",
		"rough": "res://assets/textures/real/concrete_brushed_concrete_rough.jpg",
		"normal": "res://assets/textures/real/concrete_brushed_concrete_nor_gl.jpg",
		"color": Color(0.46, 0.46, 0.45),
		"metallic": 0.0,
		"roughness": 0.95,
		"normal_scale": 0.9,
	},
}

## EXPOSICION. El interior es UN volumen: una planta, tablero claro y tubos
## encendidos, sin la variacion de cuarto a cuarto que tenia la casa. Manda la
## primera zona que contiene la camara; fuera, el cielo.
## El INTERIOR ya no es solo la casa: es la nave entera, y el anillo de hormigon
## con tubos altos devuelve la luz de otra manera que el tablero. La exposicion
## se calibra por zona: la casa (tablero claro, tubos a 2,7 m) y el anillo
## (hormigon, tubos a 4,7 m), con el mismo techo de noche.
const ZONE_INTERIOR := {"exposure": 4.30, "ambient": 0.420, "sky": 1.15, "contrib": 0.42}
## El anillo es hormigon (albedo 0,5) bajo tubos ALTOS: con la exposicion de la
## casa el taller se leia a un tercio de brillo que el tablero claro. Necesita
## MAS exposicion, no menos, y mas ambiente porque las omnis estan a 4,70 m.
const ZONE_NAVE := {"exposure": 4.60, "ambient": 0.560, "sky": 1.15, "contrib": 0.42}
const EXPOSURE_DEFAULT := {"exposure": 1.95, "ambient": 0.470, "sky": 1.55, "contrib": 1.00}
const AMBIENT_INDOOR := Color(0.64, 0.62, 0.60)
## Salir a la luz ciega rapido (90 % en 1,15 s); entrar en la oscuridad abre
## despacio (90 % en 2,88 s), que es como se comporta el ojo. Los segundos salen
## de la tasa (`-ln(0,1)/tasa`), no de un reparto a mano.
const ADAPT_TO_LIGHT := 2.0
const ADAPT_TO_DARK := 0.8

## LUZ DE LOS TUBOS: una omni por marcador `Tubo*`, pegada al tubo que la
## justifica. La casa cuelga bajo un techo de 2,80: alcance corto. El anillo de
## la nave tiene 5,20 de altura y el doble de superficie: su tubo necesita mas
## alcance o el suelo se queda negro.
const TUBE := {"color": Color(0.95, 0.93, 0.88), "energy": 0.60, "range": 3.0}
const TUBE_NAVE := {"color": Color(0.94, 0.94, 0.92), "energy": 1.30, "range": 7.5}
## Los tubos 14+ son del anillo (ver `build_map.py`).
const NAVE_TUBE_FROM := 14

var ammo: AmmoTable
var shell: Node3D
## Region de navegacion del modo: se hornea una vez y se les da a los enemigos.
var _nav: NavigationRegion3D

var _env: Environment
var _env_origin := {}
var _exposure := 0.0
var _ambient := 0.0
var _sky := 0.0
var _contrib := 1.0
var _inside := Rect2()
var _hill := Rect2()
var _mats := {}


func build() -> void:
	_environment()
	## OCULSION DE INSTANCIA: `Viewport.use_occlusion_culling` nace a false y
	## nada lo encendia; sin este interruptor los BoxOccluder3D que escribe
	## `build_map.py` en Map.tscn no hacen nada.
	get_viewport().use_occlusion_culling = true
	_load_map()
	_nav = _navigation()
	_lights()
	_spawn_enemies()
	ammo = AmmoTable.new()
	ammo.name = "AmmoTable"
	ammo.position = _marker("Municion", Vector3(1.6, 0.0, 4.4))
	add_child(ammo)


## NAVEGACION DEL MAPA. Un solo horneado, UNA vez por carga, desde los mismos
## colisores que ya usa la fisica (`StaticBody3D` de la escena): la geometria del
## mapa ya es un dato, no hace falta exportar otro fichero. Sin esto el enemigo
## camina de frente contra la fachada de la casa y no entra nunca; con esto los
## puestos cruzan el vano y pelean dentro. Es la unica capa nueva del runtime y
## sustituye al rodeo a mano que no funcionaba.
func _navigation() -> NavigationRegion3D:
	var region := NavigationRegion3D.new()
	region.name = "Nav"
	var nav := NavigationMesh.new()
	nav.agent_radius = Enemy.NAV_RADIUS
	nav.agent_height = 1.80
	nav.agent_max_climb = 0.35
	nav.agent_max_slope = 45.0
	nav.cell_size = 0.15
	nav.cell_height = 0.15
	nav.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav.geometry_collision_mask = 1
	region.navigation_mesh = nav
	add_child(region)
	## El horneado se hace por la API explicita: `bake_navigation_mesh` da 0
	## vertices con la geometria montada en el mismo frame.
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nav, src, self)
	NavigationServer3D.bake_from_source_geometry_data(nav, src)
	print("MAPA navegacion: %d vertices" % nav.get_vertices().size())
	return region


## El environment es el de `Main.tscn`, compartido por lobby y combate. Aqui no
## se sustituye: se escribe encima y se devuelve tal cual al salir, que es lo
## unico que mantiene las dos calibraciones iguales.
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


# ---------------------------------------------------------------------------
# Montaje del mapa. El dato manda: la escena trae malla, colision y marcadores.
# ---------------------------------------------------------------------------
func _load_map() -> void:
	var packed := load(MAP_SCENE.resource_path) as PackedScene
	if packed == null:
		push_error("CombatMap: no se pudo cargar " + MAP_SCENE.resource_path)
		return
	shell = packed.instantiate() as Node3D
	shell.name = "Map"
	add_child(shell)
	var interior := shell.get_node_or_null("Interior") as Marker3D
	if interior != null:
		var tam := interior.get_meta("tamano", Vector3.ZERO) as Vector3
		_inside = Rect2(interior.position.x - tam.x / 2, interior.position.z - tam.z / 2,
				tam.x, tam.z)
	else:
		push_error("Map.tscn sin marcador Interior: la exposicion de dentro no existe")
	## La CASA: su planta la declara el builder en el marcador `Casa`. El anillo
	## es la nave menos esa caja. Sin ella, el anillo de hormigon y la casa de
	## tablero compartirian una sola exposicion y uno de los dos sale quemado.
	var casa := shell.get_node_or_null("Casa") as Marker3D
	if casa != null:
		var tc := casa.get_meta("tamano", Vector3.ZERO) as Vector3
		_hill = Rect2(casa.position.x - tc.x / 2, casa.position.z - tc.z / 2,
				tc.x, tc.z)
	else:
		_hill = Rect2(Vector2(-1, -1), Vector2(0, 0))
	_rebind(shell.find_children("*", "MeshInstance3D", true, false))


## Sustituye el material del .glb por el PBR del repo, por NOMBRE. El .glb no
## trae textura (el builder exporta solo el nombre), asi que sin este enganche el
## mapa se veria gris plano. UN material por clave: las claves de MAPS quedan
## cacheadas en `_mats` y las comparte todo el mapa, asi que una textura se paga
## una vez.
func _rebind(nodes: Array) -> void:
	var counts := {}
	for node in nodes:
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			push_error("Map contiene un MeshInstance3D sin malla")
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
	print("MAPA materiales: ", counts)


func _material(group: String) -> Material:
	if _mats.has(group):
		return _mats[group]
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
	if spec.has("emission"):
		mat.emission_enabled = true
		mat.emission = spec["emission"]
		mat.emission_energy_multiplier = spec.get("emission_energy", 1.0)
	var uv: Vector2 = spec.get("uv_scale", Vector2.ONE)
	mat.uv1_scale = Vector3(uv.x, uv.y, 1.0)
	_mats[group] = mat
	return mat


# ---------------------------------------------------------------------------
# Marcadores: la escena es la unica autoridad de donde va cada cosa.
# ---------------------------------------------------------------------------
func _markers(prefix: String) -> Array:
	var out: Array = []
	if shell == null:
		return out
	for node in shell.get_children():
		if node is Marker3D and (node as Marker3D).name.begins_with(prefix):
			out.append(node)
	out.sort_custom(func(a, b): return String(a.name) < String(b.name))
	return out


func _marker(name: String, fallback: Vector3) -> Vector3:
	if shell == null:
		return fallback
	var node := shell.get_node_or_null(name) as Marker3D
	if node == null:
		push_error("Map.tscn sin marcador obligatorio: " + name)
		return fallback
	return node.position


## LUZ. El sol alumbra el exterior y las sombras que se ven por los vanos; dentro
## no entra: lo tapa el techo. La luz de dentro son el ambiente y los tubos.
## Ninguna omni proyecta sombra: en Mobile la sombra es la partida mas cara del
## cuadro y aqui no hace falta.
func _lights() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-58, -25, 0)
	sun.light_color = Color(0.98, 0.97, 0.95)
	sun.light_energy = 1.15
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	sun.shadow_enabled = true
	sun.shadow_bias = 0.08
	sun.shadow_blur = 1.8
	sun.directional_shadow_max_distance = 20.0
	sun.light_cull_mask = 1
	add_child(sun)
	for node in _markers("Tubo"):
		var tubo := node as Marker3D
		var es_nave := int(String(tubo.name).substr(4)) >= NAVE_TUBE_FROM
		var spec: Dictionary = TUBE_NAVE if es_nave else TUBE
		var lamp := OmniLight3D.new()
		lamp.name = "Luz_" + String(tubo.name)
		lamp.position = tubo.position
		lamp.light_color = spec["color"]
		lamp.light_energy = spec["energy"]
		lamp.omni_range = spec["range"]
		lamp.omni_attenuation = 1.6 if es_nave else 2.0
		lamp.shadow_enabled = false
		lamp.light_cull_mask = 1
		add_child(lamp)


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
	if point.x >= _inside.position.x and point.x <= _inside.position.x + _inside.size.x \
			and point.z >= _inside.position.y and point.z <= _inside.position.y + _inside.size.y:
		if point.x >= _hill.position.x and point.x <= _hill.position.x + _hill.size.x \
				and point.z >= _hill.position.y and point.z <= _hill.position.y + _hill.size.y \
				and _hill.size.x > 0.01:
			return ZONE_INTERIOR
		return ZONE_NAVE
	return EXPOSURE_DEFAULT


## Sin `enemy.glb` no se puebla nada (dependencia declarada, no un fallo): el
## mapa se juega vacio y se dice en consola. El script se carga por RUTA y con
## fallo EXPLICITO: `preload` de un script que aun no existe aborta la carga del
## proyecto entero.
func _spawn_enemies() -> void:
	if not ResourceLoader.exists(ENEMY_ASSET):
		print("MAPA: sin enemigo (falta %s); el mapa se juega vacio" % ENEMY_ASSET)
		return
	var script := load(ENEMY_SCRIPT) as GDScript
	if script == null:
		push_error("CombatMap: no se pudo cargar " + ENEMY_SCRIPT)
		return
	var posts := _markers("Puesto")
	for i in posts.size():
		var post := posts[i] as Marker3D
		var enemy: Node3D = script.new()
		enemy.name = "Enemy%d" % [i + 1]
		add_child(enemy)
		enemy.global_position = post.position
		enemy.rotation.y = float(post.get_meta("rumbo", 0.0))
		## El navmesh es del MAPA y el enemigo no lo busca: se le da.
		if _nav != null:
			enemy.set("nav_map", _nav.get_navigation_map())
			enemy.call_deferred("_connect_nav")
	print("MAPA enemigos: %d puestos" % posts.size())
