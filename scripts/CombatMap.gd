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
## MODELO DE COLOR, MEDIDO (y era el error de fondo de todo el mapa).
##
## El tinte de estos materiales NO se multiplica contra el valor LINEAL del
## mapa: se multiplica contra el valor sRGB tal cual sale del fichero. Probado
## con un experimento de UNA variable (cielo pintado de ROJO PURO y medida de la
## fachada): con el cielo rojo, la razon G/B de la fachada midio 0,69, que es la
## del producto `sRGB(textura) x tinte` (0,73) y NO la del producto
## `lineal(textura) x tinte` (1,06). Sin ese experimento no habia forma de
## saberlo: los tintes viejos estaban calibrados a ojo contra capturas y por eso
## el mismo cuadro salia naranja o azul segun la pasada.
##
## De ahi sale todo lo demas. El roble del repo mide (0,635/0,461/0,328) en
## sRGB, o sea R:B = 1,94, y para dejarlo en el gris blanquecino de la fachada
## de ref4 (0,495/0,482/0,466) el tinte tiene que ser (0,78/1,05/1,42). Los
## tintes de abajo son `objetivo_medido_en_la_referencia / media_sRGB_del_mapa`,
## y cada uno lleva escrito de que referencia sale.
const MAPS := {
	"House_Siding": {
		## ENTABLADO WEATHERED SIN TEXTURA NUEVA: la madera del repo existe y
		## una casa pintada y curtida por la intemperie es exactamente "el mismo
		## roble, tinte casi blanco, roughness arriba".
		##
		## MEDIDO, y esta es la correccion de color mas grande del mapa: el
		## roble del repo promedia (0,364/0,180/0,088) en lineal, o sea ROJO
		## DOBLE que azul. Con el tinte viejo (1,25/1,50/1,65) la fachada salia
		## a madera dorada (captura depot: R-B +0,234 de media en el cuadro)
		## cuando ref4/ref2 la piden GRIS BLANQUECINA desaturada (R-B -0,009 y
		## -0,053). El multiplicador tiene que CANCELAR el croma del roble, no
		## atenuarlo: 1,15/2,40/5,00 deja el entablado en (0,42/0,43/0,44)
		## lineal, que es pintura blanca sucia con la veta todavia legible.
		"albedo": "res://assets/textures/real/wood_oak_wood_planks_diff.jpg",
		"rough": "res://assets/textures/real/wood_oak_wood_planks_rough.jpg",
		"normal": "res://assets/textures/real/wood_oak_wood_planks_nor_gl.jpg",
		"color": Color(0.779, 1.046, 1.421),
		"metallic": 0.0,
		"roughness": 0.85,
		"normal_scale": 0.7,
	},
	"House_Tile": {
		"albedo": "res://assets/textures/real/concrete_brushed_concrete_diff.jpg",
		"rough": "res://assets/textures/real/concrete_brushed_concrete_rough.jpg",
		"normal": "res://assets/textures/real/concrete_brushed_concrete_nor_gl.jpg",
		## La losa de OBRA del mapa: acera, calle y bordillo. Gris NEUTRO: con el
		## tinte calido viejo (0,56/0,54/0,50) la calle aportaba al R-B del
		## cuadro exactamente lo que las referencias no tienen.
		"color": Color(0.958, 1.019, 1.128),
		"metallic": 0.0,
		"roughness": 0.72,
		"normal_scale": 0.5,
	},
	"House_Dirt": {
		## TIERRA DEL PATIO. Autoridad: ref4 (patio de tierra apisonada gris-marron
		## con rodadas, piedras y escombro) y ref2 (el mismo patio, mojado y
		## oscuro). El mapa NO tenia tierra: el patio era la misma losa de
		## hormigon cepillado que la acera, y eso es el defecto que el dueno
		## señalo. Grava CC0 (ambientCG, sin credito obligatorio: regla 11).
		##
		## El tinte va OSCURO y casi neutro. La tierra de las referencias no es
		## marron calido de desierto: es grava sucia gris, mas oscura que la
		## casa y que el cielo (por eso el cuadro de ref4 tiene el suelo a 0,2
		## y el cielo a 1,0).
		"albedo": "res://assets/textures/real/ground_gravel_diff.jpg",
		"rough": "res://assets/textures/real/ground_gravel_rough.jpg",
		"normal": "res://assets/textures/real/ground_gravel_nor_gl.jpg",
		"color": Color(0.792, 0.828, 0.933),
		"metallic": 0.0,
		"roughness": 0.95,
		"normal_scale": 1.1,
	},
	"House_Wood": {
		"albedo": "res://assets/textures/real/wood_oak_wood_planks_diff.jpg",
		"rough": "res://assets/textures/real/wood_oak_wood_planks_rough.jpg",
		"normal": "res://assets/textures/real/wood_oak_wood_planks_nor_gl.jpg",
		## El roble es de croma fuerte (media lineal 0,364/0,180/0,088): con el
		## sol encima se quemaba a ROSA (medido en el bunker). El verde y el azul
		## suben para dejarlo en madera curtida; aqui ademas mas oscuro porque
		## zancas y porche comparten el tono. MEDIDO en captura patio: con el
		## tinte viejo (0,85/0,88/0,72) el deck y las zancas salian a pino
		## dorado brillante, que es el material mas caliente del cuadro. Una
		## casa USA weathered tiene la madera expuesta GRIS MARRON.
		"color": Color(0.472, 0.629, 0.823),
		"metallic": 0.0,
		"roughness": 0.85,
		"normal_scale": 0.9,
	},
	"House_Gypsum": {
		"albedo": "res://assets/textures/real/plaster_painted_diff.jpg",
		"rough": "res://assets/textures/real/plaster_painted_rough.jpg",
		"normal": "res://assets/textures/real/plaster_painted_nor_gl.jpg",
		## PINTURA VIEJA (CC0 PaintedPlaster006, ambientCG; el dueño se encarga de
		## licencias). El `gypsum_diff` del repo era una mancha de media
		## frecuencia que a 2 m por tile hacia leer los muros interiores de
		## cemento sucio (captura `look`: grano áspero donde ref3 pide pintura
		## blanca pelada con la capa de abajo crema). La normal baja a 0,55 para
		## que las placas de pintura no descaigan los muros. El tinte va casi
		## neutro: el hue lo pone la textura y un tinte calido nuevo volveria a
		## pintar el interior naranja (el defecto que ya se arregló una vez).
		"color": Color(0.88, 0.96, 1.08),
		"uv_scale": Vector2(1.35, 1.35),
		"metallic": 0.0,
		"roughness": 0.92,
		"normal_scale": 0.55,
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
		## Campana de lampara: la pantalla NO es la luz. Con la emision vieja
		## (1,00/0,05/0,015 a 1,1) la campana entera era una mancha naranja plana
		## de 26 cm en el techo (medido en captura back) y el interior parecia
		## iluminado por dentro, que es el defecto que el dueno señalo. Una
		## pantalla de lampara se ve OPACA con el borde caliente: aqui manda el
		## albedo y la emision es un resto.
		"color": Color(0.52, 0.46, 0.38),
		"metallic": 0.0,
		"roughness": 0.70,
		"emission": Color(0.95, 0.80, 0.62),
		"emission_energy": 0.22,
	},
	"House_Bulb": {
		"albedo": "", "rough": "", "normal": "",
		## FOCO: la malla emisora bajo cada campana (build_house.py, 8 cm). Es el
		## UNICO punto calido de la lampara y va a nucleo casi blanco. La energia
		## baja de 2.20 a 1.60 (medido en captura `look`: el foco entero salia a
		## naranja quemado en el cuadro); el calido lo lleva el hue y la campana
		## se queda de CONCHA (0.52) para que el foco sea un chorrito, no un bloque.
		"color": Color(0.20, 0.12, 0.06),
		"metallic": 0.0,
		"roughness": 0.40,
		"emission": Color(1.00, 0.80, 0.55),
		"emission_energy": 1.60,
	},
	"House_Tarp": {
		"albedo": "", "rough": "", "normal": "",
		## LONA VERDE de la valla de obra que cierra la parcela (ref2: malla
		## plastica verde con graffiti). Color plano: a 1-8 m de camara una
		## textura de rejilla no se distingue, el color si. Verde OSCURO y
		## desaturado, porque la referencia es plastico sucio, no cesped.
		"color": Color(0.155, 0.285, 0.165),
		"metallic": 0.0,
		"roughness": 0.90,
	},
	"House_Bark": {
		"albedo": "", "rough": "", "normal": "",
		## CORTEZA del anillo de arboles de invierno (ref4/ref2: el fondo no es
		## cielo, es arboleda pelada). Gris oscuro casi neutro; sin textura,
		## porque a 30-140 m nadie distingue la corteza y una textura mas se
		## paga en memoria de VRAM en cada frame.
		## LAVADA A PROPOSITO: los arboles viven a 26-122 m y sin niebla una
		## corteza oscura seria una silueta negra y recortada contra el cielo
		## blanco. Este gris es la perspectiva aerea COCIDA en el material: lo
		## que la niebla daba por pixel, aqui se paga una vez.
		"color": Color(0.33, 0.33, 0.34),
		"metallic": 0.0,
		"roughness": 0.92,
	},
	"House_Graffiti": {
		## TAG de graffiti (spec REF4 "graffiti pared", REF5 "tag rojo en la
		## pared"). Textura CC0 recortada del atlas ambientCG GraffitiSet001.
		##
		## `scissor` y no alfa normal: un tag es pintura con un borde duro, el
		## alfa mezclado pagaria ordenacion de transparentes por cada quad y en
		## Mobile eso se nota. `cull_disabled` porque la lamina vive pegada a un
		## muro y el lado que mira a la camara depende de en que cara este.
		"albedo": "res://assets/textures/graffiti/tag_01.png",
		"rough": "", "normal": "",
		"color": Color(1.0, 1.0, 1.0),
		"metallic": 0.0,
		"roughness": 0.85,
		"scissor": 0.35,
		"cull_disabled": true,
	},
	"House_GraffitiB": {
		"albedo": "res://assets/textures/graffiti/tag_02.png",
		"rough": "", "normal": "",
		"color": Color(1.0, 1.0, 1.0),
		"metallic": 0.0,
		"roughness": 0.85,
		"scissor": 0.35,
		"cull_disabled": true,
	},
	"House_Scaffold": {
		"albedo": "", "rough": "", "normal": "",
		## TUBO GALVANIZADO del andamio (spec REF1: "andamio a la derecha", y en
		## ref4 es acero CLARO). Compartia `House_Metal`, que es chapa de acero
		## herrumbrosa casi negra: en captura el andamio salia negro y leia a
		## barandilla oxidada. Material plano: un tubo de 48 mm no paga textura.
		"color": Color(0.62, 0.64, 0.66),
		"metallic": 0.55,
		"roughness": 0.42,
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
## OSCURECER EL INTERIOR (defecto del dueno: "aun esta muy claro"). El dueno vio
## TODAVIA interior demasiado claro y los tres recortes anteriores no movieron
## la sensacion. Esta pasada baja las cuatro zonas a la vez y lleva el ambiente
## de relleno CON ellas: el yeso pasa a medio tono y la bombilla vuelve a ser
## la unica notion de "claridad" dentro, como en ref3/ref5. El patio y la calle
## NO se mueven: esos ya cuadraban medidos.
const ZONES := [
	{"rect": Rect2(1.9, -6.2, 4.4, 4.0), "exposure": 3.55, "ambient": 0.072, "sky": 1.00, "contrib": 0.18},
	{"rect": Rect2(-5.4, -6.2, 4.5, 10.56), "exposure": 3.30, "ambient": 0.125, "sky": 1.05, "contrib": 0.28},
	{"rect": Rect2(1.9, -2.2, 4.4, 7.44), "exposure": 3.25, "ambient": 0.125, "sky": 1.05, "contrib": 0.30},
	{"rect": Rect2(-0.9, -6.2, 2.8, 10.56), "exposure": 3.10, "ambient": 0.145, "sky": 1.10, "contrib": 0.34},
]
## Ambiente de relleno del interior. MEDIDO: el blanco calido viejo
## (0,74/0,65/0,51) teñia TODO el interior de naranja (capturas back/look: croma
## 0,18-0,25 y R-B +0,18..+0,25, cuando las cinco referencias miden croma
## 0,05-0,14 y R-B entre -0,06 y +0,01). Una casa pintada de yeso no rebota
## naranja: rebota el gris de la pintura. El calido lo pone la BOMBILLA (House_Bulb),
## que es lo unico que debe ser calido.
const AMBIENT_INDOOR := Color(0.64, 0.62, 0.60)
## El `Rect2` de arriba va en (x, z): esta plegado a mano cada vez que se
## pregunta, en una sola operacion.
const EXPOSURE_DEFAULT := {"exposure": 1.95, "ambient": 0.400, "sky": 1.50, "contrib": 1.00}
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


## PIEZAS QUE NO PROYECTAN SOMBRA. Medido con `tools/medir.sh perfil` (A/B
## interleaved, 1080p, combate): el pase de sombras costaba 21,7 ms de los 50,4
## del cuadro, y el culpable era el vestuario LEJANO entrando en el frustum de la
## sombra. El sol solo tiene 16 m de alcance de sombra (ver `_lights`), asi que
## estas piezas no pueden proyectar nada que alguien vea:
##
##   Fill_*    el relleno de 400 m. AABB de 800 m: siempre intersecta el frustum.
##   Nb        la manzana vecina, a 26-34 m.
##   Bark      la arboleda de invierno, a 26-122 m (una sola malla, mismo caso).
##
## El suelo del lote y la casa SI siguen proyectando: su sombra es la que dibuja
## el alero en el porche y el cerco del porche en la tierra.
const NO_SHADOW := ["Fill_", "Curb_", "Nb", "Bark"]

## CAPA EXTERIOR. Los mismos nombres que `NO_SHADOW` (menos `Curb_`, que es un
## bordillo de 30 cm: no merece un caso propio) se mudan a la capa 3, y las tres
## luces de RELLENO del interior dejan de mirarlas (`light_cull_mask = 1`). En
## Forward Mobile cada luz se paga por pixel de lo que alcanza su esfera, y las
## esferas del relleno se salian al patio: con esto, el suelo, la valla y los
## arboles dejan de evaluar tres omnis que no los iluminan.
## MEDIDO: los tres rellenos valian 6,1 ms del cuadro (49,9 -> 34,7 ms quitando
## niebla y rellenos). El SOL si las sigue viendo: su mascara se amplia.
const EXTERIOR_LAYER := 1 << 2
## `Dirt` entra en la lista: la malla `House_Dirt` es el suelo del lote, la
## superficie exterior MAS grande del cuadro desde el spawn, y estaba dentro del
## radio de la omni de planta baja.


func _load_house() -> void:
	house = HOUSE_SCENE.instantiate() as Node3D
	house.name = "House"
	add_child(house)
	var meshes := house.find_children("*", "MeshInstance3D", true, false)
	for node in meshes:
		var mi := node as MeshInstance3D
		if mi == null:
			continue
		for pre in NO_SHADOW:
			if mi.name.begins_with(pre):
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				break
		for pre in ["Fill_", "Nb", "Bark", "Dirt"]:
			if mi.name.begins_with(pre):
				mi.layers = EXTERIOR_LAYER
				break
	_rebind(meshes)
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
	## Alfa SCISSOR para las laminas con dibujo (los tags): borde duro, cero
	## ordenacion de transparentes y cero sobrecarga de mezcla. El alfa normal
	## solo se pagaria si el borde tuviera que ser suave, y un spray no lo es.
	if spec.has("scissor"):
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = spec["scissor"]
	if spec.get("cull_disabled", false):
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		## Densidad por material cuando el set lo pide: la pintura pelea con manchas
	## a 2 m por tile y en techo de sala entera se moneda; subir el tiling
	## (misma textura, manchas menores) mejora la lectura sin otra textura.
	var uv: Vector2 = spec.get("uv_scale", Vector2.ONE)
	mat.uv1_scale = Vector3(uv.x, uv.y, 1.0)
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
	sun.light_color = Color(0.98, 0.97, 0.95)
	sun.light_energy = 0.30
	## REFERENCIA DEL DUENO (docs/refs/ref1-5.jpg): el exterior es NUBLADO —
	## cielo plomizo, sombras suaves, cero quemados. `docs/REFS.md` §3 fija la
	## luz en `ref2` ("nublada, no la quemada"). Un sol de 2,40 pintaba sombras
	## de cuchilla y fachada clippada; con el cielo de `Main.tscn` ya BRILLANTE
	## (horizonte 0,86), 0,30 deja al sol como lo que es en un dia cubierto: un
	## gradiente direccional suave que todavia da volumen, no una lampara.
	## El tinte va FRIO (antes 1,00/0,95/0,86, calido): sumado al relleno calido
	## era la mitad del naranja medido en el cuadro.
	## SIN DISCO SOLAR en el cielo: el sol de la referencia es difuso, y un
	## disco duro en el ProceduralSkyMaterial dibujaba un foco de estudio.
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
	## 24 -> 16 MEDIDO: el pase de sombras es el 43 % del cuadro en esta HD520 y
	## su coste crece con lo que cae dentro del frustum, no con el mapa. El
	## combate se juega a menos de 12 m de la fachada y la casa mide 11,2 x 10:
	## 16 m mantienen el alero del porche, la baranda y el juego de sombras del
	## patio, y recortan un tercio mas de pase.
	sun.directional_shadow_max_distance = 12.0
	## El sol sigue iluminando el exterior aunque viva en su propia capa: la
	## mision de la capa 3 es quitarte las tres omnis de encima, no el sol.
	sun.light_cull_mask = 1 | EXTERIOR_LAYER
	add_child(sun)

	## COSTE LUZ MEDIDO (bench combat 1080p, HD520): los omnis valian 9.5 ms
	## del frame; en Mobile cada luz se paga por pixel de lo que alcance su
	## ESFERA, asi que la palanca es el radio. Rangos MINIMOS por cuarto.
	##
	## "EL SOL PARECE DENTRO DE LA CASA" (defecto del dueno). Causa medida:
	## `omni_attenuation` a 0.9 con radio 8 m desde 2,42 m de altura deja un
	## disco de luz CASI PLANO sobre todo el techo de la planta baja — en la
	## captura `back` el yeso tiene un degradado suave de borde a borde, que es
	## exactamente lo que hace la luz de un sol, no una bombilla. La
	## atenuacion sube a 2.0 (caida fisica, la luz se apaga a media esfera) y
	## la energia baja: el relleno deja de pintar el techo entero y pasa a ser
	## lo que es, un rebote local. El tinte va NEUTRO-CALIDO, no sodio: las
	## referencias miden R-B entre -0,06 y +0,01 y el juego salia a +0,18.
	## POSICION DE LAS FUENTES, CORREGIDA CONTRA LA GEOMETRIA (defecto del dueno:
	## "la iluminacion no esta correctamente posicionada"). Los rellenos habian
	## nacido en el aire del vestibulo y de la planta alta: OMNIS FLOTANDO A MEDIA
	## BOMBA sin lampara debajo. Medido con clustering de vertices de
	## `House_Bulb` en `assets/models/house.glb`, la casa tiene cinco bombillas
	## y CADA una sabe donde esta:
	##
	##   L1 (-2.60, 2.30, 0.60) sala oeste     L3 ( 3.50, 2.30, 1.80) cocina
	##   L4 (-3.00, 5.16, 0.80) dormitorio     L5 ( 3.50, 5.16, -1.20) estudio
	##
	## Cada omni vuelve a la bombilla que la justifica: el techo se queda OSCURO
	## lejos del foco (ref3: interiores con charcos de luz y rincones aislados,
	## no el techo entero liso) y nada flota.
	for spec in [
		{"name": "Fill_Sala", "pos": Vector3(-2.60, 2.15, 0.60), "color": Color(0.95, 0.90, 0.82), "energy": 0.42, "range": 3.0},
		{"name": "Fill_Dorm", "pos": Vector3(-3.00, 5.05, 0.80), "color": Color(0.95, 0.90, 0.82), "energy": 0.40, "range": 3.0},
		## La puerta trasera mira al patio norte (a la sombra del sol): sin esta
		## la francesa vidriada era un rectangulo negro en el fondo del cuadro
		## (defecto 6, medido). Bombilla calida corta y sin sombra: la mas
		## calida de las tres, se queda como acento.
	]:
		var fill := OmniLight3D.new()
		fill.name = spec["name"]
		fill.position = spec["pos"]
		fill.light_color = spec["color"]
		fill.light_energy = spec["energy"]
		fill.omni_range = spec["range"]
		fill.omni_attenuation = 2.0
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
	## AMPLIACION ESTE: la casa gano 1,00 m de casa hacia la calle este
	## (defecto del dueno: "no da a basto para varios enemigos en
	## posiciones"); los dos puestos nuevas viven en la banda nueva, el bano
	## esquina fierro y el escritorio del estudio, cada uno con su cobertura.
	{"name": "Bano", "pos": Vector3(5.6, 0.05, -4.0), "yaw": 0.9},
	{"name": "Estudio", "pos": Vector3(5.4, 3.00, -3.4), "yaw": 2.6},
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
	print("CASA enemigos: %d (3 planta baja, 3 planta alta)" % POSTS.size())
