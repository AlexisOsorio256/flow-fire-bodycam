class_name FxPools
extends Node3D

const SOFT_TEXTURE: Texture2D = preload("res://assets/textures/particle_soft.png")
const SPARK_TEXTURE: Texture2D = preload("res://assets/textures/particle_spark.png")
const PUFF_TEXTURE: Texture2D = preload("res://assets/textures/muzzle_puff.png")
const PUFF_FRAMES := Vector2i(8, 4)
const BURST_POOL := 6

var _pools := {}


func _ready() -> void:
	for surface: String in ImpactProfiles.SURFACES:
		for key in ["dust", "debris"]:
			if ImpactProfiles.SURFACES[surface].has(key):
				_burst(surface + "/" + key, ImpactProfiles.SURFACES[surface][key])
	for kind: String in ImpactProfiles.SMOKE:
		_smoke(kind, ImpactProfiles.SMOKE[kind])


func emit(key: String, at: Vector3, basis: Basis, ratio := 1.0) -> GPUParticles3D:
	var pool: Dictionary = _pools[key]
	var p: GPUParticles3D = pool["nodes"][pool["next"]]
	pool["next"] = (int(pool["next"]) + 1) % (pool["nodes"] as Array).size()
	p.global_transform = Transform3D(basis, at)
	p.amount_ratio = ratio
	p.restart()
	p.emitting = true
	return p


func stop_all() -> void:
	for key in _pools:
		for p: GPUParticles3D in _pools[key]["nodes"]:
			p.emitting = false
			p.restart()


func _add(key: String, size: int, pm: ParticleProcessMaterial, draw: Mesh, amount: int, life: float, burst: float) -> void:
	var nodes: Array[GPUParticles3D] = []
	for i in size:
		var p := GPUParticles3D.new()
		p.amount = amount
		p.lifetime = life
		p.one_shot = true
		p.explosiveness = burst
		p.local_coords = false
		p.emitting = false
		p.process_material = pm
		p.draw_pass_1 = draw
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.visibility_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
		add_child(p)
		nodes.append(p)
	_pools[key] = {"nodes": nodes, "next": 0}


func _smoke(kind: String, spec: Dictionary) -> void:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, -1)
	pm.spread = spec["spread"]
	pm.initial_velocity_min = spec["vel"].x
	pm.initial_velocity_max = spec["vel"].y
	pm.damping_min = spec["damp"].x
	pm.damping_max = spec["damp"].y
	pm.gravity = Vector3(0, spec["rise"], 0)
	pm.angle_min = -10.0
	pm.angle_max = 10.0
	pm.anim_speed_min = 1.0
	pm.anim_speed_max = 1.0
	pm.scale_min = 0.8
	pm.scale_max = 1.25
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.0))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	fade.add_point(0.04, Color(1, 1, 1, 1.0))
	fade.add_point(0.85, Color(1, 1, 1, 0.8))
	pm.color_ramp = GradientTexture1D.new()
	pm.color_ramp.gradient = fade
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = PUFF_TEXTURE
	mat.albedo_color = Color(0.9, 0.9, 0.9, spec["alpha"])
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.particles_anim_h_frames = PUFF_FRAMES.x
	mat.particles_anim_v_frames = PUFF_FRAMES.y
	mat.particles_anim_loop = false
	mat.roughness = 1.0
	mat.metallic_specular = 0.0
	mat.disable_receive_shadows = true
	mat.proximity_fade_enabled = true
	mat.proximity_fade_distance = 0.15
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * spec["size"]
	quad.material = mat
	_add(kind, spec["pool"], pm, quad, spec["amount"], spec["life"], spec["burst"])


func _burst(key: String, spec: Dictionary) -> void:
	var spark: bool = spec.get("spark", false)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = float(spec["spread"])
	pm.gravity = Vector3(0, float(spec["gravity"]), 0)
	pm.initial_velocity_min = float(spec["vel"][0])
	pm.initial_velocity_max = float(spec["vel"][1])
	pm.scale_min = float(spec["scale"][0])
	pm.scale_max = float(spec["scale"][1])
	pm.color = spec["color"]
	pm.damping_min = 0.4 if spark else 0.9
	pm.damping_max = 0.9 if spark else 2.0
	var stretch := float(spec.get("stretch", 1.0))
	var size := float(spec["size"])
	var quad := QuadMesh.new()
	quad.size = Vector2(size * stretch, size / maxf(stretch, 1.0))
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = SPARK_TEXTURE if spark else SOFT_TEXTURE
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.vertex_color_use_as_albedo = true
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if spark else BaseMaterial3D.BLEND_MODE_MIX
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = mat
	_add(key, BURST_POOL, pm, quad, int(spec["amount"]), float(spec["life"]), 1.0)
