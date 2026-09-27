extends Node3D

## MODO COMBATE: CASA USA DE MADERA, DOS PISOS.
##
## Correccion del dueno: la primera casa leio a bunker de hormigon y sale del
## arbol; entra madera: entablado blanco, porche con techo y barandal,
## francesas vidriadas, pisos de roble y patio con deck. Asset modelado en Blender
## (`tools/build_house.py` -> `assets/models/house.glb`) y su colision autorada
## en `scenes/House.tscn`, del MISMO dato que la geometria: 240 cajas, cilindros
## y UNA rampa girada -35,8 grados (la escalera), con `surface`, `penetrable`
## (y `thin_shell` / `wall_thickness` en lo que es cascara: vidrios de 3,5 mm,
## tabiques de doble placa, radiadores, espejos, sillas). No hay
## `create_trimesh_collision`: ni se construye nada en carga, ni la fisica
## resuelve mallas, y `Ballistics` saca la cara de salida hasta de la rampa
## porque `_exit_of_shape` recorre la caja en el espacio local de su transform.
##
## El archivo SE LLAMA `CombatMap.gd` y no `HouseMap.gd` por una razon dura:
## `Main.gd` (intocable por orden) prelua esta ruta exacta. El nombre describe
## el ROL (el mapa del modo combate), no el asset. API estable: `build()` y
## `ammo`.
##
## EL .glb NO lleva texturas dentro: el nombre de material que exporta el
## builder se reengancha aqui a los mapas del repo (`assets/textures/real/`).
## Una textura se paga una vez. Los tres materiales sin textura (vidrio,
## espejo, tela) se pagan con dos numeros.
##
## LUZ Y EXPOSICION
## ----------------
## El mapa NO crea su propio `WorldEnvironment`: esta medido con una sonda que
## el environment activo en los dos modos es el de `Main.tscn` (un segundo
## WorldEnvironment en el mapa es inerte). Asi que aqui se escribe sobre el
## environment ACTIVO y se devuelve a su valor de origen al salir.
##
## La auto-exposicion de Godot es Forward+; en Mobile no existe. El efecto del
## video (interior bajo -> calle quemada -> adaptacion) se resuelve con CUATRO
## zonas rectangulares y una interpolacion exponencial asimetrica: el ojo
## cierra rapido al salir a la luz y abre despacio al entrar en la oscuridad.
## Las zonas van en (x, z) y no distinguen planta: dormitorio y sala comparten
## columna y nivel de luz; esta medido que la diferencia real entre plantas es
## de media exposicion y el ambiente lo pone la bombilla de la galeria. Cero
## framework: una lista, una resta y dos tasas.

const HOUSE_SCENE := preload("res://scenes/House.tscn")
const ENEMY_SCRIPT := "res://scripts/Enemy.gd"
const ENEMY_ASSET := "res://assets/models/enemy.glb"
## Mobiliario: `tools/build_props.py` lo exporta TODO dentro del .glb (geometria
## + nombre de material + colision en `extras`). El enganche lo hace
## `_props()`, que es "quien monta la casa" segun el contrato de ese builder.
const PROPS_ASSET := "res://assets/models/props.glb"

## Nombre de MATERIAL del .glb -> mapas del repo. Las claves son exactamente las
## que exporta `tools/build_house.py`; son dependencia de produccion, asi que un
## nombre que no resuelva aborta el enganche en vez de dejar un color plano de
## reserva. La escala de UV no se toca: viaja horneada en la malla.
const MAPS := {
	"House_Siding": {
		## ENTABLADO BLANCO SIN TEXTURA NUEVA: la madera del repo existe y una
		## mano de pintura es exactamente "el mismo roble, tinte casi blanco,
		## roughness arriba y normal abajo". La veta queda; el color no grita.
		"albedo": "res://assets/textures/real/wood_oak_wood_planks_diff.jpg",
		"rough": "res://assets/textures/real/wood_oak_wood_planks_rough.jpg",
		"normal": "res://assets/textures/real/wood_oak_wood_planks_nor_gl.jpg",
		## IMPORTANTE (medido en captura): albedo_color MULTIPLICA la textura en
		## lineal, y el roble del repo promedia (0.365,0.181,0.089). Con un tinte
		## <=1 la fachada NUNCA pasa de madera oscura: la pintura blanca necesita
		## un multiplicador HDR que cancele el croma, no que lo atenue. 2.1/3.6/6.5
		## deja el entablado en blanco roto con la veta leible.
		"color": Color(1.25, 1.50, 1.65),
		"metallic": 0.0,
		"roughness": 0.80,
		"normal_scale": 0.7,
	},
	"House_Tile": {
		"albedo": "res://assets/textures/real/concrete_brushed_concrete_diff.jpg",
		"rough": "res://assets/textures/real/concrete_brushed_concrete_rough.jpg",
		"normal": "res://assets/textures/real/concrete_brushed_concrete_nor_gl.jpg",
		## La UNICA losa de obra del mapa: el PATIO (la casa es de madera; el
		## patio es losa, como en toda casa USA). Gris CALIDO: cero hormigon visto.
		"color": Color(0.56, 0.54, 0.50),
		"metallic": 0.0,
		"roughness": 0.70,
		"normal_scale": 0.5,
	},
	"House_Wood": {
		"albedo": "res://assets/textures/real/wood_oak_wood_planks_diff.jpg",
		"rough": "res://assets/textures/real/wood_oak_wood_planks_rough.jpg",
		"normal": "res://assets/textures/real/wood_oak_wood_planks_nor_gl.jpg",
		## El roble es de croma fuerte (media lineal 0,365/0,181/0,089): con el
		## sol encima se quemaba a ROSA (medido en el bunker). El verde y el azul
		## suben para dejarlo en madera curtida; aqui ademas mas oscuro porque
		## zancas y porche comparten el tono: madera curtida, casa NO colorida.
		"color": Color(0.85, 0.88, 0.72),
		"metallic": 0.0,
		"roughness": 0.80,
		"normal_scale": 0.9,
	},
	"House_Gypsum": {
		"albedo": "res://assets/textures/real/gypsum_diff.jpg",
		"rough": "res://assets/textures/real/gypsum_rough.jpg",
		"normal": "",
		## MEDIDO (capturas back/look frescas, HEAD f6d62a5): con el tinte
		## HDR viejo el techo y las paredes CLIPPABAN — 61,7 % y 47,2 % del
		## cuadro con lum>250, el yeso salia a blanco quemado (cocina casi
		## al 100 %). La media real de gypsum_diff es gris neutro 0,126
		## lineal (el viejo comentario de estuco ocre era de otra version).
		## SEGUNDA MEDICION (muestreo de píxeles): con el tinte calido las
		## paredes salian R-B=106-141 = barro/paja, y ref3 pide crema
		## R-B=12-40. El tinte va NEUTRO y la pintura a media altura: el
		## calido lo pone la luz (abajo), no la pared. 1,33/1,31/1,28 deja
		## la superficie en ~0,24 lineal: crema con grano, sin clip.
		"color": Color(1.33, 1.31, 1.28),
		"metallic": 0.0,
		"roughness": 0.90,
	},
	"House_Metal": {
		"albedo": "res://assets/textures/real/metal_metal_plate_diff.jpg",
		"rough": "res://assets/textures/real/metal_metal_plate_rough.jpg",
		"normal": "res://assets/textures/real/metal_metal_plate_nor_gl.jpg",
		## La chapa del repo es casi negra y caliente (medido): sin boost el
		## acero se leia como un agujero. Electrodomesticos y radiadores: mas
		## metalico que la chapa sucia del bunker.
		"color": Color(1.00, 1.06, 1.18),
		"metallic": 0.55,
		"roughness": 0.40,
		"normal_scale": 0.75,
	},
	"House_Glass": {
		"albedo": "", "rough": "", "normal": "",
		## Vidrio LECHOSO BARATO (defecto 1, medido en depot): el negro pulido
		## era un agujero al vacio por la ventana. Gris-leche + roughness 0,30:
		## devuelve sol y cielo como reflejo suave y NO deja ver el atras.
		## Cero textura y cero alpha: mismo coste de antes, sin transparency.
		"color": Color(0.55, 0.58, 0.60),
		"metallic": 0.5,
		"roughness": 0.30,
	},
	"House_Mirror": {
		"albedo": "", "rough": "", "normal": "",
		## Espejo BARATO: laminilla. Metallic 0,95 y roughness 0,05: sin SSR en
		## Mobile devuelve el sol y los rellenos como un destello plano, que es
		## exactamente el aspecto de un espejo de bano de 20 euros.
		"color": Color(0.80, 0.84, 0.88),
		"metallic": 0.95,
		"roughness": 0.05,
	},
	"House_Lamp": {
		"albedo": "", "rough": "", "normal": "",
		## Campana de lampara con emision (el acento calido a traves de la
		## puerta de calle, defecto 6). MEDIDO: el ambar viejo (1,00/0,62/0,28)
		## x2,0 blanqueaba (nucleo 255,247,185 = crema, no ambar), y el albedo
		## crema se iluminaba MAS que la propia emision. Campana a albedo OSCURO
		## para que mande la emision, y ambar SATURADO en la fuente: a
		## exposicion x4,9 el ACES satura los canales, con G/B bajos desde
		## aqui el nucleo mide (255,~180,~90).
		"color": Color(0.22, 0.11, 0.05),
		"metallic": 0.0,
		"roughness": 0.60,
		"emission": Color(1.00, 0.05, 0.015),
		"emission_energy": 1.1,
	},
	"House_Bulb": {
		"albedo": "", "rough": "", "normal": "",
		## FOCO: la malla emisora bajo cada campana (build_house.py, 12 cm
		## colgando). Las varillas negras solas no leian bombilla encendida
		## (medido: fixtures sin emision). La masa propia es oscura: TODO el
		## pixel lo pone la emision, que es un punto mas caliente que la
		## campana y se lee como luz PUESTA con blob R-B>80.
		"color": Color(0.15, 0.07, 0.03),
		"metallic": 0.0,
		"roughness": 0.40,
		"emission": Color(1.00, 0.05, 0.015),
		"emission_energy": 1.3,
	},
	"House_Fabric": {
		"albedo": "", "rough": "", "normal": "",
		## TELA de sofa, colchon y alfombra: gris azulado mate. No es
		## superficial: tres piezas del mapa pedian color plano y aqui esta.
		"color": Color(0.30, 0.32, 0.36),
		"metallic": 0.0,
		"roughness": 0.95,
	},
}

## ZONAS DE EXPOSICION. `exposure` es el valor de tonemap adaptado a esa luz y
## `ambient` la energia del ambiente del cielo (que en Mobile ES la luz de
## relleno: no hay GI). Se recorren en orden y manda la primera que contiene la
## camara. El bano es el rincON mas oscuro de la casa (una ventana esmerilada
## alta y a medias); el vestibulo es el mas claro del interior (dos puertas
## acristaladas en eje).
const ZONES := [
	{"rect": Rect2(1.9, -5.4, 3.5, 3.2), "exposure": 4.40, "ambient": 0.086, "sky": 1.00, "contrib": 0.22},
	{"rect": Rect2(-5.4, -5.4, 4.5, 9.8), "exposure": 4.10, "ambient": 0.156, "sky": 1.05, "contrib": 0.34},
	{"rect": Rect2(1.9, -2.2, 3.5, 6.6), "exposure": 4.05, "ambient": 0.156, "sky": 1.05, "contrib": 0.36},
	{"rect": Rect2(-0.9, -5.4, 2.8, 9.8), "exposure": 3.85, "ambient": 0.180, "sky": 1.10, "contrib": 0.42},
]
## Ambiente de relleno del interior: blanco calido de escayola, no el azul del
## cielo. Una casa pintada no rebota azul.
const AMBIENT_INDOOR := Color(0.74, 0.65, 0.51)
## El `Rect2` de arriba va en (x, z): esta plegado a mano cada vez que se
## pregunta, en una sola operacion.
const EXPOSURE_DEFAULT := {"exposure": 1.60, "ambient": 0.400, "sky": 1.50, "contrib": 1.00}
## Tasas de adaptacion. Salir a la luz ciega (rapido: 90 % en 1,1 s); entrar en
## la oscuridad abre despacio (90 % en 2,9 s), que es como se comporta el ojo.
const ADAPT_TO_LIGHT := 2.0
const ADAPT_TO_DARK := 0.8

var ammo: AmmoTable
var house: Node3D

var _env: Environment
var _env_origin := {}
var _exposure := 0.0
var _ambient := 0.0
var _sky := 0.0
var _contrib := 1.0
var _zone := -1
var _mats := {}


func build() -> void:
	_environment()
	## OCULSION DE INSTANCIA: `Viewport.use_occlusion_culling` nace a false y
	## nada lo encendia; sin este interruptor los BoxOccluder3D que escribe
	## build_house.py en House.tscn son mobiliario y los draw calls de detras
	## del muro salen igual. Aqui el mapa ya esta colgado de su viewport (el
	## SubViewport offscreen cuando el bench es quien mide).
	get_viewport().use_occlusion_culling = true
	_load_house()
	_lights()
	_spawn_enemies()
	ammo = AmmoTable.new()
	ammo.name = "AmmoTable"
	## En el vestibulo, a un paso de la puerta de calle y fuera de la linea de
	## caminata que mide `tools/check_walk.gd` (el jugador entra en x=0 recto).
	ammo.position = Vector3(1.3, 0.0, 3.0)
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


func _load_house() -> void:
	house = HOUSE_SCENE.instantiate() as Node3D
	house.name = "House"
	add_child(house)
	_rebind(house.find_children("*", "MeshInstance3D", true, false))
	_props()
	## DESPUES de _props(): el recorrido de StaticBody3D tiene que ver ya los
	## colisores del mobiliario, que son los que traen el `contact`.
	_contact_shadows(house.find_children("*", "StaticBody3D", true, false))


## MOBILIARIO (contrato de `tools/build_props.py`): el .glb se instancia en
## runtime y NADIE escribe `scenes/House.tscn` a mano (lo regenera su builder;
## un enganche a mano se evaporaria en la siguiente pasada). Las piezas vienen
## en coordenadas de mundo ya cotizadas contra los colisores de la casa, asi
## que el nodo viaja al origen y aqui se recorre la descendencia, se lee
## `metadata/extras` y se levanta el StaticBody3D.
##
## MERGE POR MATERIAL: las 22 piezas traen 43 superficies y cada una pagaba su
## draw call (una butaca es tela y madera en la misma malla). Aqui se funden en
## UNA malla por material con los vertices horneados a la posicion y el yaw de
## cada pieza: misma imagen, 43 draws -> 5, y el material del repo se pega en
## la fundicion por nombre, como antes por superficie (un `material_override`
## de nodo tintaria la pieza entera de un solo color). El colisor NO se funde:
## se salta a `Props` con la transform de su pieza, que es el mismo mundo de
## antes, y `col_size` sigue siendo el AABB local que midio el builder para
## `Ballistics._exit_of_shape`. El `contact` solo se copia en las piezas de
## planta baja: `ContactBlob` pinta el disco sobre la losa de y=0 y un mueble
## de la alta mancharia el techo de abajo. Un nombre de material fuera de MAPS
## aborta el enganche de la pieza, como en la casa: es dependencia de
## produccion, no color de reserva.
func _props() -> void:
	var packed := load(PROPS_ASSET) as PackedScene
	if packed == null:
		push_error("CombatMap: no se pudo cargar " + PROPS_ASSET)
		return
	var props := packed.instantiate() as Node3D
	props.name = "Props"
	house.add_child(props)
	var tintes := {}
	var bodies := 0
	var piezas := 0
	var sueltas: Array = []
	var grupos := {}
	for node in props.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			push_error("Props: malla vacia en " + mi.name)
			continue
		sueltas.append(mi)
		piezas += 1
		var xf := mi.transform
		for surface in range(mi.mesh.get_surface_count()):
			var source := mi.mesh.surface_get_material(surface)
			var key := source.resource_name if source != null else ""
			var mat := _material(key)
			if mat == null:
				push_error("CombatMap no reconoce el material de props: " + key)
				continue
			tintes[key] = int(tintes.get(key, 0)) + 1
			# La pieza viaja al origen: su posicion y su yaw entran en los
			# vertices ANTES de agrupar por material.
			var arr := mi.mesh.surface_get_arrays(surface)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			for i in range(vs.size()):
				vs[i] = xf * vs[i]
			for i in range(ns.size()):
				ns[i] = (xf.basis * ns[i]).normalized()
			arr[Mesh.ARRAY_VERTEX] = vs
			arr[Mesh.ARRAY_NORMAL] = ns
			if not grupos.has(key):
				grupos[key] = {"mat": mat, "sup": []}
			grupos[key]["sup"].append(arr)
		if not mi.has_meta("extras"):
			continue
		var ex: Dictionary = mi.get_meta("extras")
		var shape: Shape3D = null
		match String(ex.get("col_shape", "")):
			"":
				continue  # alfombras, cuadros y la lampara: decorativos, cero colision
			"box":
				var box := BoxShape3D.new()
				box.size = Vector3(ex["col_size"][0], ex["col_size"][1], ex["col_size"][2])
				shape = box
			"cylinder":
				var cyl := CylinderShape3D.new()
				cyl.radius = float(ex["col_radius"])
				cyl.height = float(ex["col_height"])
				shape = cyl
			_:
				push_error("Props: col_shape desconocido en " + mi.name)
				continue
		var cshape := CollisionShape3D.new()
		cshape.position = Vector3(ex["col_center"][0], ex["col_center"][1], ex["col_center"][2])
		cshape.shape = shape
		var body := StaticBody3D.new()
		body.name = "Body_" + mi.name
		body.collision_layer = 1
		body.collision_mask = 1
		body.set_meta("surface", String(ex.get("surface", "")))
		body.set_meta("penetrable", bool(ex.get("penetrable", false)))
		if ex.has("contact") and mi.position.y < 1.5:
			body.set_meta("contact", Vector2(ex["contact"][0], ex["contact"][1]))
		body.add_child(cshape)
		# El colisor vivia DENTRO de la pieza; al fundirla se va a `Props` con
		# la transform de la pieza: mismo mundo, misma caja, mismo recorrido
		# de `Ballistics._exit_of_shape` que antes.
		body.transform = mi.transform
		props.add_child(body)
		bodies += 1
	# FUSION: una malla por material (43 superficies -> 5) y las piezas
	# sueltas fuera. Mismos vertices, mismo material de MAPS, menos draws.
	for key in grupos:
		var vs := PackedVector3Array()
		var ns := PackedVector3Array()
		var us := PackedVector2Array()
		var ids := PackedInt32Array()
		for arr in grupos[key]["sup"]:
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var u: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			var base := vs.size()
			vs.append_array(v)
			ns.append_array(n)
			us.append_array(u)
			if idx.is_empty():
				for i in range(v.size()):
					ids.append(base + i)
			else:
				for i in range(idx.size()):
					ids.append(base + idx[i])
		var malla := ArrayMesh.new()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vs
		arrays[Mesh.ARRAY_NORMAL] = ns
		arrays[Mesh.ARRAY_TEX_UV] = us
		arrays[Mesh.ARRAY_INDEX] = ids
		malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		malla.surface_set_material(0, grupos[key]["mat"])
		var fundido := MeshInstance3D.new()
		fundido.name = "Props_" + key
		fundido.mesh = malla
		props.add_child(fundido)
	for mi in sueltas:
		mi.queue_free()
	print("PROPS: %d piezas -> %d mallas, %d colisores, tintes %s"
		% [piezas, grupos.size(), bodies, tintes.keys()])


## Sustituye el material del .glb por el PBR del repo, por NOMBRE. El mapa del
## .glb no trae textura (el builder exporta solo el nombre), asi que sin este
## enganche la casa se veria gris plano. UN material por clave: las claves de
## MAPS quedan cacheadas en `_mats` y las comparte todo el mapa (carcasa y
## mobiliario): una textura se paga una vez. Aqui solo nodos de UN tinte; lo
## que trae varios (un mueble) se engancha superficie a superficie en `_props`.
func _rebind(nodes: Array) -> void:
	var counts := {}
	for node in nodes:
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			push_error("House contiene un MeshInstance3D sin malla")
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
	print("CASA materiales: ", counts)


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
	mat.uv1_scale = Vector3.ONE
	_mats[group] = mat
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


## LUZ. El sol es la unica fuente con sombra: entra por la puerta de calle
## acristalada, por las dos ventanas de la sala y por la ventana alta de la
## galeria, y dibuja el rectangulo de luz en el gres del vestibulo (la sena de
## identidad de la casa). Las tres de relleno van sin sombra y con cull mask 1
## para no tocar el viewmodel, que tiene su propia luz pegada a camara. Una por
## zona de planta: la casa tiene dos pisos y la de arriba es la pequena.
func _lights() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-46, -20, 0)
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.light_energy = 0.45
	## REFERENCIA DEL DUENO (docs/refs/ref1-5.jpg, vista antes de este cambio):
	## el exterior es NUBLADO — cielo plomizo, sombras suaves, cero quemados.
	## El sol duro de 2.40 pintaba sombras de cuchilla y fachada clippada; 0.70
	## lo deja como acento minimo y el relleno del cielo manda (ambient arriba).
	## SIN DISCO SOLAR en el cielo: el sol de la referencia es difuso, y un
	## disco duro en el ProceduralSkyMaterial de `Main.tscn` (que no se toca)
	## dibujaba un foco de estudio en el encuadre.
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	## 42 media re-renderizar en el pase de sombras toda la manzana (relleno
	## hasta 40 m) para sombras que nadie ve desde el juego: el combate se juega
	## a menos de 24 m de la fachada. 24 mantiene intactas las sombras del
	## patio, el porche y el interior y recorta el pase a la mitad.
	## MEDIDO y descartado: pasar a 1 split ortogonal (los 4 splits del default
	## renderizaban ~117k prims de sombra) salio MAS CARO en esta HD520
	## (46.2 vs 42.7 ms): los 4 pases paralelos saturan mejor el rasterizador.
	sun.directional_shadow_max_distance = 24.0
	sun.light_cull_mask = 1
	add_child(sun)

	## COSTE LUZ MEDIDO (bench combat 1080p, HD520): los omnis valian 9.5 ms
	## del frame; en Mobile cada luz se paga por pixel de lo que alcance su
	## ESFERA, asi que la palanca es el radio. Rangos MINIMOS por cuarto: solo
	## lo que tarda el relleno en llegar a la esquina mas lejana de SU cuarto
	## (antes 7.5 se salia a la calle atravesando los muros: luz gratis para
	## nadie). Energias abajo para el nublado de refs; el interior se
	## compensa en ZONES (exposicion x1.28, ambiente x0.78) y no en luz.
	## VARIANTE B (eq-definicion): 5 luces -> 3 fusionando cuartos vecinos.
	## Una bombilla por planta baja, una por alta y la de la puerta trasera.
	## Los radios deben cruzar los dos cuartos que cubren (mas area que antes)
	## pero son 2 evaluaciones menos por pixel: el coste de luz cae aunque la
	## esfera crezca (201 vs 346 light-pixels en planta baja).
	## Colores: MEDIDO sobre captura interior (muestreo de píxeles), el relleno
	## sodio (B/R 0,66) teñia TODO el cuadro de barro: paredes R-B 106-141
	## frente a ref3 (12-40). Energias y rangos NO se tocan (calibrados por el
	## frente de luces): solo el tinte baja de sodio a tungsteno crema, que es
	## el "calido en la luz" de ref3 — charcos calidos, no un baño naranja.
	for spec in [
		{"name": "FillPB", "pos": Vector3(0.45, 2.42, 0.3), "color": Color(0.93, 0.85, 0.74), "energy": 0.95, "range": 8.0},
		{"name": "FillAlta", "pos": Vector3(-1.2, 5.25, 0.8), "color": Color(0.94, 0.87, 0.76), "energy": 0.72, "range": 7.3},
		## La puerta trasera mira al patio norte (a la sombra del sol): sin esta
		## la francesa vidriada era un rectangulo negro en el fondo del cuadro
		## (defecto 6, medido). Bombilla calida corta y sin sombra: la mas
		## calida de las tres, se queda como acento.
		{"name": "FillBack", "pos": Vector3(0.0, 1.85, -4.60), "color": Color(1.00, 0.79, 0.60), "energy": 0.72, "range": 3.2},
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


## CUATRO puestos, dos por piso: los dos de la planta baja flanquean la galeria,
## y los dos de arriba dominan desde la altura y CAEN al patio cuando mueren,
## que es la mitad del valor del ragdoll (un cuerpo que cae tres metros se lee
## sin ningun adorno). Sin `enemy.glb` no se puebla nada (dependencia declarada,
## no un fallo): el mapa se juega vacio y se dice en consola.
const POSTS := [
	{"name": "Sofa", "pos": Vector3(-4.6, 0.05, 0.3), "yaw": 0.6},
	{"name": "Cocina", "pos": Vector3(2.65, 0.05, 3.60), "yaw": 0.3},
	{"name": "TechoA", "pos": Vector3(-2.9, 3.00, 1.4), "yaw": -2.0},
	{"name": "TechoB", "pos": Vector3(3.0, 3.00, -1.4), "yaw": -2.9},
]


func _spawn_enemies() -> void:
	if not ResourceLoader.exists(ENEMY_ASSET):
		print("CASA: sin enemigo (falta %s); el mapa se juega vacio" % ENEMY_ASSET)
		return
	## El script del enemigo se carga por RUTA y con fallo EXPLICITO: `preload`
	## de un script que aun no existe aborta la carga del proyecto entero.
	var script := load(ENEMY_SCRIPT) as GDScript
	if script == null:
		push_error("CombatMap: no se pudo cargar " + ENEMY_SCRIPT)
		return
	for i in POSTS.size():
		var post: Dictionary = POSTS[i]
		var enemy: Node3D = script.new()
		enemy.name = "Enemy%d_%s" % [i + 1, post["name"]]
		add_child(enemy)
		enemy.global_position = post["pos"]
		enemy.rotation.y = post["yaw"]
	print("CASA enemigos: %d (2 planta baja, 2 planta alta)" % POSTS.size())
