extends Node3D

## MODO COMBATE: BUNKER DERRIUIDO.
##
## Asset modelado y optimizado en Blender (tools/build_combat_map.py -> assets/models/combat_bunker.glb).
## Blender es la autoridad de geometria, UVs y silueta arquitectonica.
##
## Rendimiento:
## - 3 draw calls de geometria (unidas por material).
## - 1 SpotLight3D con sombra (1 solo pase de sombra, en vez de 6 caras de OmniLight cubemap).
## - Auto-exposicion cinematica: adaptacion real al entrar a zonas oscuras y quemado de brechas exteriores.

const BUNKER_ASSET := "res://assets/models/combat_bunker.glb"
const ENEMY_SCRIPT := preload("res://scripts/Enemy.gd")
const ENEMY_ASSET := "res://assets/models/enemy.glb"

var ammo: AmmoTable
var bunker_instance: Node3D


func build() -> void:
	_environment()
	_load_bunker()
	_lights()
	_spawn_enemies()
	ammo = AmmoTable.new()
	ammo.name = "AmmoTable"
	ammo.position = Vector3(1.8, 0.0, 5.5)
	add_child(ammo)


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.015, 0.020)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.12, 0.14, 0.18)
	env.ambient_light_energy = 0.45
	env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 2.4
	# Comportamiento de camara: auto-adaptacion de exposicion al cruzar entre oscuridad y luz exterior
	env.auto_exposure_enabled = true
	env.auto_exposure_scale = 0.38
	env.auto_exposure_speed = 2.2
	var we := WorldEnvironment.new()
	we.name = "Environment"
	we.environment = env
	add_child(we)


func _load_bunker() -> void:
	if not ResourceLoader.exists(BUNKER_ASSET):
		push_error("CombatMap: falta el asset " + BUNKER_ASSET)
		return
	var scene := load(BUNKER_ASSET) as PackedScene
	bunker_instance = scene.instantiate() as Node3D
	bunker_instance.name = "Bunker"
	add_child(bunker_instance)
	_build_collisions(bunker_instance)


func _build_collisions(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and child.mesh != null:
			child.create_trimesh_collision()
		_build_collisions(child)


func _lights() -> void:
	# UNICA luz con sombra: SpotLight3D cenital que baña el pasillo de estrangulamiento
	# y genera contacto en el suelo. Cuesta 1 solo pase de sombra (frente a 6 de un Omni).
	var key := SpotLight3D.new()
	key.name = "Key"
	key.position = Vector3(0.0, 2.95, 3.2)
	key.rotation_degrees = Vector3(-65, 180, 0)
	key.light_color = Color(1.0, 0.94, 0.86)
	key.light_energy = 4.2
	key.spot_range = 12.0
	key.spot_angle = 55.0
	key.spot_attenuation = 1.2
	key.shadow_enabled = true
	key.shadow_bias = 0.05
	key.light_cull_mask = 1
	add_child(key)

	# Foco secundario sin sombra en el interior del búnker oscuro
	var fill := SpotLight3D.new()
	fill.name = "VaultFill"
	fill.position = Vector3(-2.8, 2.85, -2.2)
	fill.rotation_degrees = Vector3(-75, 0, 0)
	fill.light_color = Color(0.85, 0.90, 1.0)
	fill.light_energy = 1.4
	fill.spot_range = 8.0
	fill.spot_angle = 60.0
	fill.shadow_enabled = false
	fill.light_cull_mask = 1
	add_child(fill)

	# Luz direccional tenue que entra por la brecha trasera (exterior nublado sobrexpuesto)
	var sun := DirectionalLight3D.new()
	sun.name = "BreachSun"
	sun.rotation_degrees = Vector3(-25, 15, 0)
	sun.light_color = Color(0.92, 0.95, 1.0)
	sun.light_energy = 0.65
	sun.shadow_enabled = false
	add_child(sun)


func _spawn_enemies() -> void:
	if not ResourceLoader.exists(ENEMY_ASSET):
		print("COMBATE: sin enemigo (falta %s); el mapa se juega vacio" % ENEMY_ASSET)
		return
	var posts := [Vector3(-2.2, 0.05, -3.2), Vector3(2.5, 0.05, -3.0), Vector3(0.0, 0.05, -6.5)]
	for i in range(posts.size()):
		var enemy := ENEMY_SCRIPT.new()
		enemy.name = "Enemy%d" % (i + 1)
		add_child(enemy)
		enemy.global_position = posts[i]
