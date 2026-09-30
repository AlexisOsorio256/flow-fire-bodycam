class_name WeaponFX
extends Node3D

## Presentación del fogonazo: núcleo caliente + gases de boca + luz + humo.
##
## NO tiene autoridad mecánica: no conoce munición, cadencia, corredera ni
## recarga. La autoridad es `Glock.gd`, que avisa cuando se dispara (`fire()`) y
## este módulo anima el evento visual. El humo lo sigue haciendo `ImpactFX`.
##
##
## Dos volúmenes, dos trabajos:
##   FlashCore  ~10 mm emisivos sobre el eje del cañón. Es el fogonazo: cae a
##              plomo en pocos milisegundos y es lo único que brilla (glow).
##   FlashGas   nube irregular de ~26 mm alrededor de la boca con blend aditivo.
##              Sus colores por vértice SON su opacidad: la cola casi negra no
##              aporta nada, así que la silueta se apaga sola y no hay borde de
##              polígono.
##
##
## Ahora son DOS planos de cara a camara con una textura radial generada en
## codigo (nucleo, halo y estrella de 4 puntas coci das en el alfa). El borde no
## existe: la caida es continua hasta cero, que es como se apaga un fogonazo de
## verdad en un sensor. Dos y no uno porque el grande da el volumen y el pequeño,
## mas cerca de la boca y mas blanco, da el nucleo; un solo plano lee a pegatina.
##
## Se sigue pagando lo mismo o menos: 4 triangulos contra 22, una textura de
## 128x128 generada UNA vez, y ninguna lectura extra por pixel.

## Duración visible del evento. 50 ms: extremadamente corto, no una llama que se
## pueda mirar. A 40 ms el fogonazo no caia en ningun frame de revision
## (30 ms de juego por frame) y en sala luminosa no se percibia; 50 ms sigue
## siendo milisegundos y cae en 1-2 frames.
const FLASH_TIME := 0.050
## Apagado relativo. El núcleo es un fogonazo de milisegundos (cae a plomo); los
## gases son lo único que sobrevive hasta el final del evento.
const CORE_DECAY := 4.0
const GAS_DECAY := 1.4
## Ganancia del plano de gas y del nucleo. Con blend aditivo, 1,0 de alfa en el
## centro del plano ya suma el tinte ENTERO sobre el fondo: por encima de 1 el
## nucleo satura a blanco, que es lo que hace un fogonazo en un sensor.
const GAS_GAIN := 1.55
const CORE_GAIN := 2.40

var muzzle_light: OmniLight3D
var world_flash: OmniLight3D
var flash_mesh: MeshInstance3D  # gases (aditivo)
var core_mesh: MeshInstance3D   # núcleo caliente (emisivo)
var timer := 0.0
## `fire()` ocurre dentro de Glock._process antes de `update()`. Si se descuenta
## delta en ese mismo frame, a 20 FPS 50 ms -> 0 y el fogonazo nunca llega al
## render; a 16 FPS era literalmente invisible. Este latch garantiza UN frame
## completo sin alargar la vida real del efecto en los frames siguientes.
var _fresh_flash := false
var _muzzle_light_peak := 0.9
var _world_light_peak := 1.9

var _gas_mat: StandardMaterial3D
var _core_mat: StandardMaterial3D
var _gas_tint := Color(1.0, 0.62, 0.30)
var _core_tint := Color(1.0, 0.90, 0.72)


func build() -> void:
	muzzle_light = OmniLight3D.new()
	# La luz de flash sólo aclara el volumen cercano. Una fuente cálida grande
	# convertía la tela negra en cuero dorado durante el disparo.
	muzzle_light.light_color = Color(1.0, 0.97, 0.92)
	muzzle_light.light_energy = 0.0
	muzzle_light.visible = false
	muzzle_light.omni_range = 1.6
	muzzle_light.shadow_enabled = false
	# Ilumina el viewmodel, que es de quien es la luz: ni siquiera el fogonazo
	# puede alumbrar el mundo, o al disparar pegado a una pared el pulso se ve
	# como una linterna encendida. El fogonazo se ve por sus MALLAS, que están
	# en la capa del mundo delante de la boca; la luz solo define el arma.
	muzzle_light.light_cull_mask = GlockViewmodel.VIEWMODEL_LAYER_BIT
	add_child(muzzle_light)
	world_flash = OmniLight3D.new()
	world_flash.light_color = Color(1.0, 0.75, 0.45)
	world_flash.light_energy = 0.0
	world_flash.visible = false
	# El pulso ya está garantizado al menos un frame; no necesita una esfera de
	# seis metros para hacerse notar. Menos alcance = menos mallas afectadas en
	# Forward Mobile, conservando el rebote cálido justo alrededor de la boca.
	world_flash.omni_range = 4.2
	world_flash.omni_attenuation = 1.1
	world_flash.shadow_enabled = false
	world_flash.light_cull_mask = 1
	add_child(world_flash)

	var flash_tex := _flash_texture()
	_gas_mat = _flash_material(flash_tex, _gas_tint)
	flash_mesh = MeshInstance3D.new()
	flash_mesh.name = "FlashGas"
	flash_mesh.mesh = _flash_quad(0.085, 0.085)
	flash_mesh.material_override = _gas_mat
	flash_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash_mesh.position = Vector3(0.0, 0.008, -0.014)
	flash_mesh.visible = false
	add_child(flash_mesh)

	_core_mat = _flash_material(flash_tex, _core_tint)
	core_mesh = MeshInstance3D.new()
	core_mesh.name = "FlashCore"
	core_mesh.mesh = _flash_quad(0.052, 0.052)
	core_mesh.material_override = _core_mat
	core_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core_mesh.position = Vector3(0.0, 0.008, -0.004)
	core_mesh.visible = false
	add_child(core_mesh)

	print("WEAPONFX fogonazo nucleo+gas en la boca del canon (-Z)")


func update(delta: float) -> void:
	if _fresh_flash:
		_fresh_flash = false
	else:
		timer = maxf(0.0, timer - delta)
	var lit := timer > 0.0
	if flash_mesh.visible != lit:
		flash_mesh.visible = lit
		core_mesh.visible = lit
	if muzzle_light != null and muzzle_light.visible != lit:
		muzzle_light.visible = lit
	if world_flash != null and world_flash.visible != lit:
		world_flash.visible = lit
	if not lit:
		if muzzle_light != null:
			muzzle_light.light_energy = 0.0
		if world_flash != null:
			world_flash.light_energy = 0.0
		return
	var f := timer / FLASH_TIME
	# Los dos planos se apagan a ritmos distintos: el nucleo con pow alto
	# (desaparece en el primer frame o dos) y el gas con una caida suave. El
	# tinte base se guarda al montar: el fogonazo es naranja y el nucleo blanco,
	# y lo unico que cambia por frame es la INTENSIDAD.
	_gas_mat.albedo_color = _gas_tint * (GAS_GAIN * pow(f, GAS_DECAY))
	_core_mat.albedo_color = _core_tint * (CORE_GAIN * pow(f, CORE_DECAY))
	if muzzle_light != null:
		muzzle_light.light_energy = _muzzle_light_peak * f
	if world_flash != null:
		# Más pico y menos tiempo: el interior recibe un golpe de luz claro sin
		# mantener otra fuente cara encendida ni convertirla en linterna. El random
		# se toma UNA vez por tiro para que el pulso decaiga, no parpadee por frame.
		world_flash.light_energy = _world_light_peak * f * f


## Evento de disparo completo: fogonazo + humo de boca.
##
## `muzzle` es el NODO de la boca, no un punto del mundo: el humo se cuelga de
## el para nacer en el canon y viajar con el arma. Antes se le pasaba
## `origin` (la posicion de la boca YA convertida a mundo), y ese punto deja de
func fire(muzzle: Node3D, origin: Vector3, bore_dir: Vector3) -> void:
	pop_flash()
	ImpactFX.spawn_muzzle_smoke(muzzle, bore_dir)


## Muestra el fogonazo con tamaño y desviación leves irregulares. Un roll de
## 360° metía la llama de nuevo detrás de la corredera en algunos disparos de
## ADS, así que el giro es corto y los dos volúmenes lo comparten.
func pop_flash() -> void:
	if flash_mesh == null:
		return
	timer = FLASH_TIME
	_fresh_flash = true
	_muzzle_light_peak = randf_range(0.78, 1.02)
	# PICO REMEDIDO: con 2,45-3,05 el fogonazo lavaba la plancha de pladur a
	# ~1,5 m (clip 31,9% del panel en +13 ms); 1,7-2,15 baja el clip a 13,7%
	# con la media casi igual (176,8 vs 177,9), asi el rebote cerca de la boca
	# sigue leyendose pero la textura de la superficie sobrevive. Los blancos
	# lejanos no lo ven: el alcance es 4,2 m y su luz es la de ImpactFX.
	_world_light_peak = randf_range(1.7, 2.15)
	var roll := randf_range(-0.32, 0.32)
	flash_mesh.rotation = Vector3(0.0, 0.0, roll)
	core_mesh.rotation = Vector3(0.0, 0.0, roll)
	# TAMANO: un fogonazo real de 9 mm en interior mide 100-200 mm de gas con el
	# nucleo dentro. El plano de gas mide 85 mm, asi que 1,6-2,1 lo deja en
	# 136-179 mm. El nucleo, 52 mm x 1,25-1,55 = 65-81 mm.
	#
	# La aleatoriedad es de GESTO (tamano, proporcion y posicion), no de forma:
	# el borde ya no puede cambiar porque no hay borde.
	var sx := randf_range(1.6, 2.1)
	var sy := sx * randf_range(0.86, 1.18)
	flash_mesh.scale = Vector3(sx, sy, 1.0)
	flash_mesh.position = Vector3(randf_range(-0.004, 0.004), 0.008,
		-0.014 - randf_range(0.0, 0.008))
	core_mesh.scale = Vector3.ONE * randf_range(1.25, 1.55)
	_gas_mat.albedo_color = _gas_tint * GAS_GAIN
	_core_mat.albedo_color = _core_tint * CORE_GAIN
	flash_mesh.visible = true
	core_mesh.visible = true


## TEXTURA DEL FOGONAZO, generada UNA vez al montar. Tres cosas coci das en el
## ALFA (el RGB se queda blanco: con blend aditivo el color lo pone el tinte del
## material, asi la misma textura sirve al gas naranja y al nucleo blanco):
##
##   1. nucleo: caida radial suave hasta CERO en el borde. Es lo que elimina el
##
## 128x128 y no 64: a 0,40 m del ojo el plano grande mide ~380 px de pantalla,
## asi que con 64 se veria la interpolacion. Con 128 el gradiente es continuo y
## sigue siendo una textura de 64 KB que se sube una vez (ni un byte en disco).
func _flash_texture() -> ImageTexture:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (x + 0.5) / float(n) * 2.0 - 1.0
			var v := (y + 0.5) / float(n) * 2.0 - 1.0
			var r := sqrt(u * u + v * v)
			var a := clampf(1.0 - r, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)          # smoothstep: sin canto
			a = pow(a, 1.25)
			# Estrella: dos barras finas cruzadas, mas cortas que el halo.
			var bar_x := clampf(1.0 - absf(v) * 11.0, 0.0, 1.0) * clampf(1.0 - absf(u) * 0.85, 0.0, 1.0)
			var bar_y := clampf(1.0 - absf(u) * 11.0, 0.0, 1.0) * clampf(1.0 - absf(v) * 0.85, 0.0, 1.0)
			a = minf(1.0, a + 0.30 * (bar_x + bar_y) * clampf(1.0 - r, 0.0, 1.0))
			# Velo ancho: el gas que queda tras el fogonazo.
			a = minf(1.0, a + 0.10 * clampf(1.0 - r * 1.6, 0.0, 1.0))
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)


## Material de fogonazo: plano de cara a camara, sin sombra, aditivo. El tinte
## va en `albedo_color` y la intensidad la mueve `update()`.
func _flash_material(tex: Texture2D, tint: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = tex
	m.albedo_color = tint
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	return m


func _flash_quad(w: float, h: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	return q


