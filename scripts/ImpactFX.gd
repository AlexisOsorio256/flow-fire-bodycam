extends Node3D

## Impactos: agujero (cavidad + labio) por decal, particulas por material,
## proyectil incrustado y humo de boca y expulsion.

const SOFT_TEXTURE: Texture2D = preload("res://assets/textures/particle_soft.png")
const SPARK_TEXTURE: Texture2D = preload("res://assets/textures/particle_spark.png")

const MAX_HOLES := 128
const HOLES_PER_SURFACE := 8
const HOLE_SIZE := {
    "concrete": 0.070,
    "gypsum": 0.064,
    "pine": 0.064,
    "steel": 0.048,
    "aluminum": 0.042,
    "paper": 0.040,
    "ground": 0.085,
}

const CAVITY_TINT := {
    "concrete": Color(0.024, 0.024, 0.022),
    "gypsum": Color(0.085, 0.080, 0.072),
    "pine": Color(0.050, 0.031, 0.015),
    "steel": Color(0.035, 0.038, 0.045),
    "aluminum": Color(0.62, 0.63, 0.65),
    "paper": Color(0.075, 0.066, 0.055),
    "ground": Color(0.055, 0.046, 0.036),
}
const LIP_TINT := {
    "concrete": Color(0.38, 0.37, 0.34),
    "gypsum": Color(0.74, 0.71, 0.65),
    "pine": Color(0.46, 0.30, 0.14),
    "steel": Color(0.24, 0.26, 0.30),
    "aluminum": Color(0.78, 0.79, 0.81),
    "paper": Color(0.70, 0.66, 0.56),
    "ground": Color(0.34, 0.29, 0.22),
}
const MASK_SIZE := 96
const DECAL_DEPTH := 0.03
const PROJECTION_MARGIN := 0.003

var _holes: Array[Dictionary] = []
var _masks := {}
const MAX_EMBEDDED := 8
var _embedded: Array[Node3D] = []
var _jacket_mat: StandardMaterial3D
## Humo: hoja 2x2 de bocanadas, iluminado por la escena, rotando y con
## turbulencia. Cada perfil se construye una vez.
const SMOKE_TEXTURE: Texture2D = preload("res://assets/textures/smoke.png")
const SMOKE := {
    "muzzle": {"amount": 14, "life": 2.4, "burst": 0.9, "vel": Vector2(2.2, 4.2), "spread": 9.0,
        "damp": Vector2(4.5, 6.5), "rise": 0.30, "size": 0.08, "grow": 3.2, "alpha": 0.24},
    "barrel": {"amount": 10, "life": 2.6, "burst": 0.05, "vel": Vector2(0.06, 0.18), "spread": 14.0,
        "damp": Vector2(0.8, 1.4), "rise": 0.22, "size": 0.045, "grow": 3.0, "alpha": 0.20},
    "ejection": {"amount": 5, "life": 1.2, "burst": 0.9, "vel": Vector2(0.3, 0.7), "spread": 30.0,
        "damp": Vector2(2.0, 3.0), "rise": 0.25, "size": 0.04, "grow": 2.6, "alpha": 0.24},
}
var _smoke := {}


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    for surface in IMPACT_MATERIALS:
        _masks[surface] = _make_hole_texture(surface)


func _smoke_profile(kind: String) -> Array:
    if _smoke.has(kind):
        return _smoke[kind]
    var spec: Dictionary = SMOKE[kind]
    var pm := ParticleProcessMaterial.new()
    pm.direction = Vector3(0, 0, -1)
    pm.spread = spec["spread"]
    pm.initial_velocity_min = spec["vel"].x
    pm.initial_velocity_max = spec["vel"].y
    pm.damping_min = spec["damp"].x
    pm.damping_max = spec["damp"].y
    pm.gravity = Vector3(0, spec["rise"], 0)
    pm.angle_min = -180.0
    pm.angle_max = 180.0
    pm.angular_velocity_min = -25.0
    pm.angular_velocity_max = 25.0
    pm.anim_offset_max = 1.0
    pm.scale_min = 0.7
    pm.scale_max = 1.3
    pm.turbulence_enabled = true
    pm.turbulence_noise_strength = 0.6
    pm.turbulence_noise_scale = 2.5
    pm.turbulence_influence_min = 0.02
    pm.turbulence_influence_max = 0.06
    var grow := Curve.new()
    grow.add_point(Vector2(0.0, 1.0 / spec["grow"]))
    grow.add_point(Vector2(0.25, 0.55))
    grow.add_point(Vector2(1.0, 1.0))
    pm.scale_curve = CurveTexture.new()
    pm.scale_curve.curve = grow
    pm.scale_curve.texture_mode = CurveTexture.TEXTURE_MODE_RED
    var fade := Gradient.new()
    fade.set_color(0, Color(1, 1, 1, 0.0))
    fade.add_point(0.04, Color(1, 1, 1, 1.0))
    fade.add_point(0.35, Color(1, 1, 1, 0.55))
    fade.set_color(1, Color(1, 1, 1, 0.0))
    pm.color_ramp = GradientTexture1D.new()
    pm.color_ramp.gradient = fade
    var mat := StandardMaterial3D.new()
    mat.albedo_texture = SMOKE_TEXTURE
    mat.albedo_color = Color(0.82, 0.82, 0.80, spec["alpha"])
    mat.vertex_color_use_as_albedo = true
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    mat.particles_anim_h_frames = 2
    mat.particles_anim_v_frames = 2
    mat.roughness = 1.0
    mat.metallic_specular = 0.0
    mat.proximity_fade_enabled = true
    mat.proximity_fade_distance = 0.15
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    var quad := QuadMesh.new()
    quad.size = Vector2.ONE * spec["size"] * spec["grow"]
    quad.material = mat
    _smoke[kind] = [pm, quad]
    return _smoke[kind]


func _emit_smoke(kind: String, parent: Node, at: Vector3, dir: Vector3) -> void:
    var spec: Dictionary = SMOKE[kind]
    var profile := _smoke_profile(kind)
    var particles := GPUParticles3D.new()
    particles.amount = spec["amount"]
    particles.lifetime = spec["life"]
    particles.one_shot = true
    particles.explosiveness = spec["burst"]
    particles.process_material = profile[0]
    particles.draw_pass_1 = profile[1]
    particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    particles.local_coords = false
    parent.add_child(particles)
    particles.global_position = at
    particles.global_basis = Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT)
    particles.emitting = true
    get_tree().create_timer(spec["life"] + 0.3).timeout.connect(particles.queue_free)


func spawn_impact(point: Vector3, normal: Vector3, collider: Object, surface: String, is_exit: bool = false) -> void:
    _spawn_decal(point, normal, collider, surface, is_exit)
    _spawn_particles(point, normal, surface, is_exit)
    if not is_exit:
        _spawn_light(point, surface)

    if is_exit:
        return

    var sound_name := ""
    var volume := 0.0
    var pitch := randf_range(0.92, 1.08)
    match surface:
        "concrete":
            sound_name = "impact_concrete"
        "steel":
            sound_name = "impact_metal"
        "aluminum":
            sound_name = "impact_aluminum"
            volume = 0.0
            pitch = randf_range(0.96, 1.08)
        "pine":
            sound_name = "impact_wood"
        "paper":
            sound_name = "impact_wood"
            volume = -10.0
        "gypsum":
            sound_name = "impact_drywall"
            volume = -5.0
        "ground":
            sound_name = "impact_wood"
            volume = -6.0
        _:
            push_error("ImpactFX sin perfil de audio para material: " + surface)
            return
    GameAudio.play_3d(sound_name, point, volume, pitch)


func spawn_muzzle_smoke(at: Node3D, direction: Vector3) -> void:
    if at != null and is_instance_valid(at):
        _emit_smoke("muzzle", self, at.global_position, direction.normalized())


func spawn_barrel_smoke(at: Node3D) -> void:
    if at != null and is_instance_valid(at):
        _emit_smoke("barrel", self, at.global_position, Vector3.UP)


func spawn_ejection_smoke(point: Vector3, direction: Vector3) -> void:
    _emit_smoke("ejection", self, point, direction.normalized())


const BLOOD_SPOT_DEPTH := 0.05
const BLOOD_MARGIN := 0.004


func spawn_blood_spot(point: Vector3, spot: Decal, dir: Vector3, anchor: Node3D = null) -> void:
    if spot == null:
        return
    var basis := Basis(Vector3.UP, randf_range(0.0, TAU))
    var sx := randf_range(0.34, 0.52)
    var sz := randf_range(0.34, 0.52)
    spot.size = Vector3(0.09, BLOOD_SPOT_DEPTH, 0.09)
    spot.modulate = Color(1, 1, 1, 0.0)
    spot.visible = true
    if anchor != null and is_instance_valid(anchor):
        if spot.get_parent() != anchor:
            spot.reparent(anchor, true)
        spot.transform = Transform3D(basis, anchor.to_local(
            point - Vector3.UP * (BLOOD_SPOT_DEPTH * 0.5 - BLOOD_MARGIN)))
    else:
        spot.global_transform = Transform3D(basis, point - Vector3.UP * (BLOOD_SPOT_DEPTH * 0.5 - BLOOD_MARGIN))
    var grow := spot.create_tween()
    grow.tween_property(spot, "size", Vector3(sx, BLOOD_SPOT_DEPTH, sz), 1.1) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    grow.parallel().tween_property(spot, "modulate:a", 0.92, 0.30)


func spawn_embedded(point: Vector3, direction: Vector3, collider: Object) -> void:
    if _jacket_mat == null:
        _jacket_mat = StandardMaterial3D.new()
        _jacket_mat.albedo_color = Color(0.55, 0.32, 0.18)
        _jacket_mat.metallic = 0.9
        _jacket_mat.roughness = 0.4
    var holder := Node3D.new()
    holder.name = "EmbeddedRound"
    add_child(holder)
    var dir := direction.normalized()
    var up := Vector3.UP
    if absf(dir.dot(up)) > 0.94:
        up = Vector3.RIGHT
    var x_axis := up.cross(dir).normalized()
    var z_axis := x_axis.cross(dir).normalized()
    holder.global_transform = Transform3D(Basis(x_axis, dir, z_axis), point - dir * 0.004)
    var nose := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = 0.0028
    cm.bottom_radius = 0.0045
    cm.height = 0.009
    cm.radial_segments = 10
    cm.material = _jacket_mat
    nose.mesh = cm
    nose.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    holder.add_child(nose)
    _embedded.append(holder)
    while _embedded.size() > MAX_EMBEDDED:
        var old_node: Node3D = _embedded.pop_front()
        if is_instance_valid(old_node):
            old_node.queue_free()


func _spawn_decal(point: Vector3, normal: Vector3, collider: Object, surface: String, is_exit: bool) -> void:
    if not IMPACT_MATERIALS.has(surface) or not HOLE_SIZE.has(surface) \
            or not CAVITY_TINT.has(surface) or not LIP_TINT.has(surface) \
            or not _masks.has(surface):
        push_error("ImpactFX sin perfil completo para material: " + surface)
        return
    var profile: Dictionary = IMPACT_MATERIALS[surface]
    var size := float(HOLE_SIZE[surface])
    if is_exit:
        size *= float(profile.get("exit_scale", 1.35))

    var n := normal.normalized()
    if n.length_squared() < 0.01:
        push_error("ImpactFX recibio una normal invalida para " + surface)
        return

    var decal := Decal.new()
    decal.name = "BulletExit" if is_exit else "BulletEntry"
    decal.texture_albedo = _masks[surface]
    decal.size = Vector3(size, DECAL_DEPTH, size)
    decal.upper_fade = 0.0
    decal.lower_fade = 0.35
    decal.normal_fade = 0.45
    add_child(decal)
    var basis := _decal_basis(n).rotated(n, randf_range(0.0, TAU))
    decal.global_transform = Transform3D(basis,
        point - n * (DECAL_DEPTH * 0.5 - PROJECTION_MARGIN))

    _holes.append({"holder": decal, "surface": collider})
    _evict(collider)


func _evict(collider: Object) -> void:
    var same: Array[Dictionary] = []
    for hole in _holes:
        if is_instance_valid(hole["holder"]) and hole["surface"] == collider:
            same.append(hole)
    while same.size() > HOLES_PER_SURFACE:
        _drop(same.pop_front())
    while _holes.size() > MAX_HOLES:
        _drop(_holes.pop_front())


func _drop(hole: Dictionary) -> void:
    _holes.erase(hole)
    var node: Node = hole["holder"]
    if is_instance_valid(node):
        node.queue_free()


func _decal_basis(n: Vector3) -> Basis:
    var up := Vector3.UP
    if absf(n.dot(up)) > 0.94:
        up = Vector3.RIGHT
    var x_axis := up.cross(n).normalized()
    if x_axis.length_squared() < 0.01:
        x_axis = Vector3.RIGHT
    var z_axis := x_axis.cross(n).normalized()
    return Basis(x_axis, n, z_axis)


func _make_hole_texture(surface: String) -> ImageTexture:
    var cavity: Color = CAVITY_TINT[surface]
    var lip: Color = LIP_TINT[surface]
    var img := Image.create(MASK_SIZE, MASK_SIZE, false, Image.FORMAT_RGBA8)
    for y in range(MASK_SIZE):
        for x in range(MASK_SIZE):
            var u := (float(x) + 0.5) / float(MASK_SIZE) * 2.0 - 1.0
            var v := (float(y) + 0.5) / float(MASK_SIZE) * 2.0 - 1.0
            var r := sqrt(u * u + v * v)
            var angle := atan2(v, u)
            var noise := _fbm(cos(angle) * 3.1 + 5.0, sin(angle) * 3.1 + 5.0)
            var edge := 0.36 * (1.0 + 0.18 * (noise - 0.5))
            var hole := smoothstep(edge, edge - 0.10, r)
            var depth := 0.24 + 0.76 * smoothstep(0.0, maxf(edge, 0.01), r)
            var outer := 0.62 * (1.0 + 0.16 * (noise - 0.5))
            var chipped := smoothstep(edge - 0.05, edge + 0.02, r) \
                * (1.0 - smoothstep(outer - 0.07, outer, r))
            var alpha := maxf(hole, chipped * 0.62)
            var color := (lip * (0.72 + 0.28 * noise)).lerp(cavity * depth, hole)
            img.set_pixel(x, y, Color(color.r, color.g, color.b, clampf(alpha, 0.0, 1.0)))
    return ImageTexture.create_from_image(img)


static func _fbm(x: float, y: float) -> float:
    return _value_noise(x, y) * 0.65 + _value_noise(x * 2.7 + 11.3, y * 2.7 + 7.1) * 0.35


static func _value_noise(x: float, y: float) -> float:
    var xi := floori(x)
    var yi := floori(y)
    var xf := x - float(xi)
    var yf := y - float(yi)
    var sx := xf * xf * (3.0 - 2.0 * xf)
    var sy := yf * yf * (3.0 - 2.0 * yf)
    var a := _hash01(xi, yi)
    var b := _hash01(xi + 1, yi)
    var c := _hash01(xi, yi + 1)
    var d := _hash01(xi + 1, yi + 1)
    return lerpf(lerpf(a, b, sx), lerpf(c, d, sx), sy)


static func _hash01(a: int, b: int) -> float:
    var h := (a * 374761393 + b * 668265263) ^ 0x5BF03635
    h = (h ^ (h >> 13)) * 1274126177
    h = h ^ (h >> 16)
    return float(h & 0xFFFFFF) / float(0xFFFFFF)


const IMPACT_MATERIALS := {
    "concrete": {
        "dust": {"amount": 9, "color": Color(0.56, 0.55, 0.52, 0.60), "vel": [0.4, 1.6], "gravity": -2.0, "scale": [0.6, 2.4], "life": 0.85, "size": 0.050, "spread": 62.0},
        "debris": {"amount": 6, "color": Color(0.34, 0.33, 0.31, 0.95), "vel": [2.6, 6.5], "gravity": -13.0, "scale": [0.18, 0.50], "life": 0.50, "size": 0.018, "spread": 70.0},
        "exit_scale": 1.25,
    },
    "gypsum": {
        "dust": {"amount": 18, "color": Color(0.78, 0.76, 0.71, 0.52), "vel": [0.5, 2.0], "gravity": -1.4, "scale": [1.0, 3.6], "life": 1.05, "size": 0.070, "spread": 74.0},
        "debris": {"amount": 4, "color": Color(0.72, 0.70, 0.64, 0.90), "vel": [1.8, 4.4], "gravity": -8.0, "scale": [0.30, 0.80], "life": 0.60, "size": 0.026, "spread": 66.0},
        "exit_scale": 1.80,
    },
    "pine": {
        "dust": {"amount": 7, "color": Color(0.46, 0.33, 0.18, 0.62), "vel": [0.5, 2.0], "gravity": -2.6, "scale": [0.5, 1.8], "life": 0.70, "size": 0.044, "spread": 60.0},
        "debris": {"amount": 8, "color": Color(0.35, 0.22, 0.10, 0.98), "vel": [3.4, 8.0], "gravity": -12.0, "scale": [0.30, 0.85], "life": 0.60, "size": 0.030, "spread": 52.0, "stretch": 4.0},
        "exit_scale": 1.50,
    },
    "steel": {
        "debris": {"amount": 22, "color": Color(1.0, 0.72, 0.26, 1.0), "vel": [3.4, 9.0], "gravity": -12.0, "scale": [0.30, 1.20], "life": 0.42, "size": 0.026, "spread": 56.0, "spark": true, "stretch": 5.5},
        "dust": {"amount": 3, "color": Color(0.38, 0.39, 0.42, 0.28), "vel": [0.3, 1.0], "gravity": -2.0, "scale": [0.35, 0.95], "life": 0.34, "size": 0.026, "spread": 48.0},
        "exit_scale": 1.10,
    },
    "aluminum": {
        "debris": {"amount": 4, "color": Color(1.0, 0.80, 0.40, 1.0), "vel": [2.0, 5.0], "gravity": -11.0, "scale": [0.30, 0.90], "life": 0.22, "size": 0.012, "spread": 50.0, "spark": true},
        "dust": {"amount": 3, "color": Color(0.70, 0.71, 0.72, 0.30), "vel": [0.3, 1.0], "gravity": -2.0, "scale": [0.30, 0.90], "life": 0.30, "size": 0.022, "spread": 44.0},
        "exit_scale": 1.25,
    },
    "paper": {
        "dust": {"amount": 4, "color": Color(0.84, 0.81, 0.74, 0.50), "vel": [0.2, 0.8], "gravity": -1.0, "scale": [0.30, 0.90], "life": 0.35, "size": 0.020, "spread": 44.0},
        "exit_scale": 1.60,
    },
    "ground": {
        "dust": {"amount": 12, "color": Color(0.44, 0.38, 0.31, 0.62), "vel": [0.3, 1.4], "gravity": -1.8, "scale": [0.9, 3.0], "life": 0.95, "size": 0.058, "spread": 68.0},
        "debris": {"amount": 5, "color": Color(0.30, 0.26, 0.21, 0.95), "vel": [1.6, 4.0], "gravity": -11.0, "scale": [0.20, 0.55], "life": 0.45, "size": 0.020, "spread": 58.0},
        "exit_scale": 1.15,
    },
}


func _spawn_particles(point: Vector3, normal: Vector3, surface: String, is_exit: bool) -> void:
    if not IMPACT_MATERIALS.has(surface):
        push_error("ImpactFX sin perfil de particulas para material: " + surface)
        return
    var profile: Dictionary = IMPACT_MATERIALS[surface]
    var n := normal.normalized()
    var strength := 1.0
    if is_exit:
        match surface:
            "gypsum":
                strength = 1.35
            "pine":
                strength = 1.15
            "paper":
                strength = 0.75
            "concrete":
                strength = 0.78
            "ground":
                strength = 0.60
            _:
                strength = 0.65
    for key in ["dust", "debris"]:
        if profile.has(key):
            _burst(point + n * 0.006, n, profile[key], strength)


func _burst(point: Vector3, normal: Vector3, spec: Dictionary, strength: float) -> void:
    var spark: bool = spec.get("spark", false)
    var pm := ParticleProcessMaterial.new()
    pm.direction = normal
    pm.spread = float(spec["spread"])
    pm.gravity = Vector3(0, float(spec["gravity"]), 0)
    pm.initial_velocity_min = float(spec["vel"][0]) * strength
    pm.initial_velocity_max = float(spec["vel"][1]) * strength
    pm.scale_min = float(spec["scale"][0])
    pm.scale_max = float(spec["scale"][1])
    pm.color = spec["color"]
    if spark:
        pm.damping_min = 0.4
        pm.damping_max = 0.9
    else:
        pm.damping_min = 0.9
        pm.damping_max = 2.0

    var particles := GPUParticles3D.new()
    var amount := float(spec["amount"])
    particles.amount = maxi(1, int(round(amount * (1.0 if strength >= 1.0 else 0.72 + 0.28 * strength))))
    particles.lifetime = float(spec["life"])
    particles.one_shot = true
    particles.explosiveness = 1.0
    particles.process_material = pm
    var stretch := float(spec.get("stretch", 1.0))
    var size := float(spec["size"])
    particles.draw_pass_1 = _particle_quad(
        SPARK_TEXTURE if spark else SOFT_TEXTURE,
        Color(1.0, 1.0, 1.0, 1.0), spark, Vector2(size * stretch, size / maxf(stretch, 1.0)))
    particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(particles)
    particles.global_position = point
    get_tree().create_timer(particles.lifetime + 0.5).timeout.connect(particles.queue_free)


func _spawn_light(point: Vector3, surface: String) -> void:
    if surface != "steel" and surface != "aluminum":
        return
    var light := OmniLight3D.new()
    light.omni_range = 0.85
    light.light_energy = 0.35
    light.light_color = Color(1.0, 0.72, 0.34)
    light.shadow_enabled = false
    add_child(light)
    light.global_position = point + Vector3.UP * 0.10
    var tween := create_tween()
    tween.tween_property(light, "light_energy", 0.0, 0.045)
    tween.finished.connect(light.queue_free)


func _particle_quad(texture: Texture2D, color: Color, additive: bool, size: Vector2) -> QuadMesh:
    var quad := QuadMesh.new()
    quad.size = size
    var mat := StandardMaterial3D.new()
    mat.albedo_texture = texture
    mat.albedo_color = color
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    mat.billboard_keep_scale = true
    mat.vertex_color_use_as_albedo = true
    mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    quad.material = mat
    return quad
