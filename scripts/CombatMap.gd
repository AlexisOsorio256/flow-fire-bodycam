extends Node3D

## MODO COMBATE: el DEPOSITO. Un solo espacio pequeño para poder medir
## movimiento, angulos, puertas y cobertura, distancias cortas, disparo,
## enemigos, ragdoll, sangre, audio e iluminacion.
##
## NO es el banco de calibracion vestido de otra cosa. El banco es un pasillo
## recto de 66 m para medir balistica a 50 m; aqui no hay blancos, ni lanes, ni
## nada a mas de 14 m porque la distancia que importa es la de un tiro al
## pecho. La identidad es otra: nave de servicio de dos alturas con una puerta
## de paso al fondo, blockers de hormigon en diagonal y taquillas de acero.
##
## Se construye en codigo con las MISMAS texturas del repo (`assets/textures/
## real/`), sin asset nuevo y sin bake: el banco ilumina con LightmapGI horneado
## y esto se ilumina en vivo, asi que el numero de luces es el presupuesto.
##
## Reutiliza `AmmoTable` y `Ballistics`: la recarga y la bala son las mismas en
## los dos modos, sin copia.

const WALL := 3.2           ## altura libre
const PARTITION_Z := -1.0   ## tabique que parte la nave
const DOOR_X := -3.0        ## hueco de paso (1,2 m)
const DOOR_W := 1.2
const DOOR_H := 2.1
const BACK_Z := -7.5
const FRONT_Z := 8.0
const HALF_X := 7.5

const ENEMY_SCRIPT := preload("res://scripts/Enemy.gd")
## Tres enemigos y ya: el mapa es pequeno y el objetivo es que UNO sea bueno.
const ENEMY_COUNT := 3
## Sin cuerpo no se pueban. Ver la cabecera de `Enemy.gd`: es una dependencia
## declarada, no un fallo. Con enemigos dentro el mapa cuesta mas, asi que el
## frame time que se mida sin ellos es el del mapa vacio.
const ENEMY_ASSET := "res://assets/models/enemy.glb"

var ammo: AmmoTable
var _mats := {}


func build() -> void:
	_environment()
	_shell()
	_cover()
	_lights()
	_spawn_enemies()
	ammo = AmmoTable.new()
	ammo.name = "AmmoTable"
	ammo.position = Vector3(4.6, 0.0, 4.2)
	add_child(ammo)


## AMBIENTE PROPIO, y no es adorno. El banco esta horneado con LightmapGI, asi que
## el ambiente de `Main.tscn` (energia 1,4) apenas le hace sombra: casi toda la luz
## que ve viene del bake. Aqui no hay bake, ese mismo ambiente ES la luz, y dejaba
## el hormigon en papel blanco (medido en captura: sin detalle en el techo).
##
## Solo se cambia el ambiente. El TONEMAP es el mismo que el del banco, byte a byte,
## para que los dos modos se lean como la misma camara.
func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.014, 0.018)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.40, 0.44, 0.52)
	env.ambient_light_energy = 0.30
	env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 2.8
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.0
	env.adjustment_saturation = 1.03
	var we := WorldEnvironment.new()
	we.name = "Environment"
	we.environment = env
	add_child(we)


# ---------------------------------------------------------------------------
# Geometria. Cajas: es lo que ya es el rango (props en codigo) y lo que aguanta
# el presupuesto. Lo organico lo lleva el enemigo, que si es de Blender.
# ---------------------------------------------------------------------------
func _box(parent: Node3D, node_name: String, size: Vector3, pos: Vector3,
		mat: Material, surface := "concrete", penetrable := true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	body.set_meta("surface", surface)
	body.set_meta("penetrable", penetrable)
	parent.add_child(body)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = mat
	mesh.mesh = box
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	return body


func _shell() -> void:
	var conc := _concrete()
	var paint := _painted()
	var blobs := ContactBlob.new()

	_box(self, "Floor", Vector3(HALF_X * 2.0, 0.3, FRONT_Z - BACK_Z),
		Vector3(0, -0.15, (FRONT_Z + BACK_Z) * 0.5), conc)
	_box(self, "Ceiling", Vector3(HALF_X * 2.0, 0.2, FRONT_Z - BACK_Z),
		Vector3(0, WALL + 0.1, (FRONT_Z + BACK_Z) * 0.5), conc)
	for side in [-1.0, 1.0]:
		_box(self, "SideWall", Vector3(0.3, WALL, FRONT_Z - BACK_Z),
			Vector3(side * (HALF_X + 0.15), WALL * 0.5, (FRONT_Z + BACK_Z) * 0.5), conc)
	_box(self, "FrontWall", Vector3(HALF_X * 2.0, WALL, 0.3),
		Vector3(0, WALL * 0.5, FRONT_Z + 0.15), conc)
	_box(self, "BackWall", Vector3(HALF_X * 2.0, WALL, 0.3),
		Vector3(0, WALL * 0.5, BACK_Z - 0.15), conc)

	# Tabique con hueco de paso. Tres cajas y un dintel: el hueco es REAL, se ve
	# y se dispara por el, no un adorno pintado.
	var half_w := (DOOR_X - DOOR_W * 0.5 + HALF_X) * 0.5
	var cx := (DOOR_X + DOOR_W * 0.5 + HALF_X) * 0.5
	_box(self, "PartitionW", Vector3(half_w * 2.0, WALL, 0.25),
		Vector3(DOOR_X - DOOR_W * 0.5 - half_w, WALL * 0.5, PARTITION_Z), conc)
	_box(self, "PartitionE", Vector3(half_w * 2.0, WALL, 0.25),
		Vector3(DOOR_X + DOOR_W * 0.5 + half_w, WALL * 0.5, PARTITION_Z), conc)
	_box(self, "DoorLintel", Vector3(DOOR_W, WALL - DOOR_H, 0.25),
		Vector3(DOOR_X, DOOR_H + (WALL - DOOR_H) * 0.5, PARTITION_Z), conc)
	# Marco de la puerta en acero pintado: es lo que da identidad al sitio.
	for s in [-1.0, 1.0]:
		_box(self, "DoorJamb", Vector3(0.10, DOOR_H, 0.32),
			Vector3(DOOR_X + s * (DOOR_W * 0.5 + 0.05), DOOR_H * 0.5, PARTITION_Z),
			paint, "steel")
	_box(self, "DoorHead", Vector3(DOOR_W + 0.2, 0.10, 0.32),
		Vector3(DOOR_X, DOOR_H + 0.05, PARTITION_Z), paint, "steel")
	blobs.add(DOOR_X - DOOR_W * 0.5 - half_w, PARTITION_Z, half_w, 0.01)
	blobs.add(DOOR_X + DOOR_W * 0.5 + half_w, PARTITION_Z, half_w, 0.01)

	var blob_mesh := blobs.build()
	if blob_mesh != null:
		add_child(blob_mesh)


## Cobertura en diagonal: obliga a moverse de lado en vez de avanzar en linea.
func _cover() -> void:
	var conc := _concrete()
	var paint := _painted()
	var wood := _wood()
	var blobs := ContactBlob.new()

	# Tres blockers de hormigon de 1,1 m: cobertura de pecho, no escondites.
	for blocker in [Vector3(-2.2, 0, 1.4), Vector3(1.9, 0, -0.2), Vector3(-1.0, 0, -4.3)]:
		_box(self, "Blocker", Vector3(1.9, 1.1, 0.55), blocker + Vector3(0, 0.55, 0), conc)
		blobs.add(blocker.x, blocker.z, 0.95, 0.28, 0.0)
	# Taquillas de acero en la pared del fondo: planchas, suenan y detienen.
	for i in range(3):
		var x := 2.0 + i * 0.95
		_box(self, "Locker", Vector3(0.90, 1.85, 0.45), Vector3(x, 0.925, BACK_Z + 0.4), paint, "steel", false)
		blobs.add(x, BACK_Z + 0.4, 0.45, 0.22)
	# Dos cajas de pino huecas al otro lado del tabique: se atraviesan.
	for box_base in [Vector3(-6.0, 0.0, -5.2), Vector3(-5.2, 0.0, -6.0)]:
		_crate(box_base, wood, blobs)

	var blob_mesh := blobs.build()
	if blob_mesh != null:
		add_child(blob_mesh)


## Caja HUECA de 6 paneles de pino de 12 mm: la bala atraviesa 24 mm, no
## 350 mm de madera. Es la misma verdad que las del banco.
func _crate(base: Vector3, wood: Material, blobs: ContactBlob) -> void:
	var size := 0.35
	var body := StaticBody3D.new()
	body.name = "Crate"
	body.position = base + Vector3(0, size * 0.5, 0)
	body.set_meta("surface", "pine")
	body.set_meta("penetrable", true)
	add_child(body)
	var t := 0.012
	for panel in [
		[Vector3(size, t, size), Vector3(0, -size * 0.5 + t * 0.5, 0)],
		[Vector3(size, t, size), Vector3(0, size * 0.5 - t * 0.5, 0)],
		[Vector3(size, size, t), Vector3(0, 0, -size * 0.5 + t * 0.5)],
		[Vector3(size, size, t), Vector3(0, 0, size * 0.5 - t * 0.5)],
		[Vector3(t, size, size), Vector3(-size * 0.5 + t * 0.5, 0, 0)],
		[Vector3(t, size, size), Vector3(size * 0.5 - t * 0.5, 0, 0)],
	]:
		var psize: Vector3 = panel[0]
		var ppos: Vector3 = panel[1]
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = psize
		bm.material = wood
		mi.mesh = bm
		mi.position = ppos
		body.add_child(mi)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = psize
		cs.shape = bs
		cs.position = ppos
		body.add_child(cs)
	blobs.add(base.x, base.z, size * 0.5, size * 0.5)


# ---------------------------------------------------------------------------
# Luz. El banco la hornea (LightmapGI) y por eso no evalua nada por pixel; aqui
# no hay bake, asi que la iluminacion ES real y cada luz cuesta. Presupuesto:
## cuatro fuentes sin sombra + dos que si la proyectan en el tabique y el
## suelo, que es donde se lee el cuerpo del enemigo al caer.
# ---------------------------------------------------------------------------
func _lights() -> void:
	var holder := Node3D.new()
	holder.name = "Lighting"
	add_child(holder)
	for spec in [
		{"pos": Vector3(-3.4, 2.85, 3.4), "energy": 2.4, "range": 8.5, "color": Color(1.0, 0.95, 0.88)},
		{"pos": Vector3(3.4, 2.85, 0.2), "energy": 2.4, "range": 8.5, "color": Color(1.0, 0.95, 0.88)},
		{"pos": Vector3(-1.0, 2.85, -4.6), "energy": 2.0, "range": 8.0, "color": Color(0.90, 0.94, 1.0)},
	]:
		_omni(holder, spec)
	# El unico con sombra: cae sobre el suelo del pasillo y da contacto al
	# enemigo cuando se acerca. Si el enemigo cae, su sombra es la que dice que
	# hay un cuerpo en el suelo.
	var key := OmniLight3D.new()
	key.name = "Key"
	key.position = Vector3(0.0, 3.0, 2.2)
	key.light_color = Color(1.0, 0.94, 0.86)
	key.light_energy = 4.6
	key.omni_range = 9.5
	key.shadow_enabled = true
	key.light_cull_mask = 1
	holder.add_child(key)
	# Baliza de la puerta: separa las dos mitades en la imagen y marca el paso.
	var door := OmniLight3D.new()
	door.name = "DoorGlow"
	door.position = Vector3(DOOR_X, DOOR_H + 0.25, PARTITION_Z)
	door.light_color = Color(1.0, 0.72, 0.40)
	door.light_energy = 2.2
	door.omni_range = 4.2
	door.shadow_enabled = false
	holder.add_child(door)
	# Difusor de las luminarias: MISMA idea que el halo del banco pero aqui sin
	# quad aditivo, porque glow global esta descartado por coste y este mapa ya
	# gasta luces. Un plano emisivo y blanco quemado es lo que se ve.
	for fixture in [Vector3(-3.4, 2.95, 3.4), Vector3(3.4, 2.95, 0.2), Vector3(-1.0, 2.95, -4.6)]:
		var panel := MeshInstance3D.new()
		panel.name = "Fixture"
		var quad := QuadMesh.new()
		quad.size = Vector2(1.2, 0.26)
		quad.material = _emissive()
		panel.mesh = quad
		panel.rotation_degrees = Vector3(-90, 0, 0)
		panel.position = fixture
		panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(panel)


func _omni(parent: Node3D, spec: Dictionary) -> void:
	var l := OmniLight3D.new()
	l.name = "Fill"
	l.position = spec["pos"]
	l.light_color = spec["color"]
	l.light_energy = spec["energy"]
	l.omni_range = spec["range"]
	l.shadow_enabled = false
	l.light_cull_mask = 1
	parent.add_child(l)


# ---------------------------------------------------------------------------
# Materiales. Los mismos archivos que el banco: no hay textura nueva, y el coste
# de VRAM es el mismo que ya se paga.
# ---------------------------------------------------------------------------
func _concrete() -> StandardMaterial3D:
	if _mats.has("concrete"):
		return _mats["concrete"]
	var m := StandardMaterial3D.new()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.albedo_texture = preload("res://assets/textures/real/concrete_brushed_concrete_diff.jpg")
	m.albedo_color = Color(0.46, 0.47, 0.49)
	m.roughness_texture = preload("res://assets/textures/real/concrete_brushed_concrete_rough.jpg")
	m.roughness = 0.78
	m.normal_enabled = true
	m.normal_texture = preload("res://assets/textures/real/concrete_brushed_concrete_nor_gl.jpg")
	m.normal_scale = 0.45
	m.uv1_scale = Vector3(2, 2, 2)
	_mats["concrete"] = m
	return m


func _painted() -> StandardMaterial3D:
	if _mats.has("painted"):
		return _mats["painted"]
	var m := StandardMaterial3D.new()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.albedo_texture = preload("res://assets/textures/real/metal_paint_grain.jpg")
	m.albedo_color = Color(0.27, 0.30, 0.33)
	m.metallic = 0.35
	m.roughness = 0.60
	m.normal_enabled = true
	m.normal_texture = preload("res://assets/textures/real/metal_metal_plate_nor_gl.jpg")
	m.normal_scale = 0.35
	m.uv1_scale = Vector3(1.0, 1.6, 1.0)
	_mats["painted"] = m
	return m


func _wood() -> StandardMaterial3D:
	if _mats.has("wood"):
		return _mats["wood"]
	var m := StandardMaterial3D.new()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.albedo_texture = preload("res://assets/textures/real/wood_oak_wood_planks_diff.jpg")
	m.albedo_color = Color(0.42, 0.36, 0.28)
	m.roughness_texture = preload("res://assets/textures/real/wood_oak_wood_planks_rough.jpg")
	m.roughness = 0.82
	m.normal_enabled = true
	m.normal_texture = preload("res://assets/textures/real/wood_oak_wood_planks_nor_gl.jpg")
	m.normal_scale = 0.7
	m.uv1_scale = Vector3(1.5, 1.0, 1.5)
	_mats["wood"] = m
	return m


func _emissive() -> StandardMaterial3D:
	if _mats.has("emissive"):
		return _mats["emissive"]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.92, 0.88, 0.80)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats["emissive"] = m
	return m


func _spawn_enemies() -> void:
	if not ResourceLoader.exists(ENEMY_ASSET):
		print("COMBATE: sin enemigo (falta %s); el mapa se juega vacio" % ENEMY_ASSET)
		return
	var posts := [Vector3(-5.0, 0.05, -5.6), Vector3(4.4, 0.05, -6.2), Vector3(0.2, 0.05, -3.2)]
	for i in range(mini(ENEMY_COUNT, posts.size())):
		var enemy := ENEMY_SCRIPT.new()
		enemy.name = "Enemy%d" % (i + 1)
		add_child(enemy)
		enemy.global_position = posts[i]
