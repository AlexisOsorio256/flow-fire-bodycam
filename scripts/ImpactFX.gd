extends Node3D

## Presentacion de impactos y penetracion. NO decide balistica: Ballistics.gd
## dice DONDE entra/sale y CONTRA QUE; aqui solo se representa el material roto.
##
## Un impacto legible tiene tres capas distintas:
##   1. cavidad oscura: pequena y hundida; es profundidad, no una pegatina negra
##   2. labio fracturado: material expuesto que SI recibe luz
##   3. eyeccion: polvo/astillas/chispas segun el material y si es entrada/salida
##
## Entrada y salida no son el mismo agujero escalado. La salida abre mas el
## material, tiene borde mas irregular y expulsa masa hacia fuera.
##
## EL AGUJERO ES UN `Decal` NATIVO, no una malla. Godot lo proyecta sobre lo que
## tenga debajo (funciona en el renderer Mobile), asi que el agujero se adapta a
## una pared, a un bidon curvado o a una lata sin fabricar geometria por impacto:
##
## DOS TRAMPAS DEL MOTOR QUE COSTARON SANGRE, no repetirlas:
##   1. La caja de proyeccion es [0,1]x[-1,1]x[0,1] en local y el shader
##      DESCARTA el fragmento que cae justo en el borde. Si la superficie
##      coincide con el limite de la caja, el agujero no sale (o sale a rayas):
##      de ahi `PROJECTION_MARGIN`.
##   2. Godot solo aplica OCHO decales por malla (`sc_decals(8)`), asi que dos
##      decales por agujero dejaban una pared con cuatro agujeros y el motor
##      elegia cuales. Un decal por agujero + `HOLES_PER_SURFACE` para que los
##      que se vean sean siempre los ultimos.
##
## Las particulas (polvo, astillas, chispas) siguen siendo `GPUParticles3D`.

const SOFT_TEXTURE: Texture2D = preload("res://assets/textures/particle_soft.png")
const SPARK_TEXTURE: Texture2D = preload("res://assets/textures/particle_spark.png")

## Tope de agujeros vivos en toda la escena. Tambien hay tope POR OBJETO: ver
## `HOLES_PER_SURFACE`.
const MAX_HOLES := 128
## El motor solo proyecta 8 decales por malla; de aqui para arriba el agujero
const HOLES_PER_SURFACE := 8
const HOLE_SIZE := {
    "concrete": 0.070,
    "gypsum": 0.064,
    "pine": 0.064,
    "steel": 0.048,
    "aluminum": 0.042,
    "paper": 0.040,
    ## Tierra: la bala se entierra. Agujero mas grande que el de la madera
    ## porque arranca un cuenco de tierra, no una astilla.
    "ground": 0.085,
}

## Color de la cavidad y del labio, por material. Se cuecen dentro de la
## silueta: el `Decal` va con `modulate` blanco para no gastar dos decales.
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
## Lado de la textura de silueta. 96 px sobra para un agujero de 5 cm.
const MASK_SIZE := 96
## Caja de proyeccion del decal: fondo suficiente para atravesar la chapa de una
## lata (0,12 mm) y quedarse corto para no manchar lo de mas atras.
const DECAL_DEPTH := 0.03
## Holgura entre la superficie y el borde de la caja de proyeccion. Godot
## descarta el fragmento que caiga EN el borde de la caja, asi que con la
## superficie justo en el limite el agujero no se dibuja (o sale a rayas).
const PROJECTION_MARGIN := 0.003

## Agujeros vivos: cada entrada lleva el nodo y la superficie (objeto) sobre la
## que esta proyectado. El objeto se guarda aqui y no en `meta` del nodo porque
## `set_meta` con valor nulo no guarda nada y luego `get_meta` suelta un error.
var _holes: Array[Dictionary] = []
var _masks := {}
## Proyectiles incrustados (solo pine): pool de 8 jackets a medio hundir.
## No es sistema universal: gypsum/concrete usan polvo/spall, steel splash,
## aluminum perfora, paper corta limpio. Solo donde clavarse es real.
const MAX_EMBEDDED := 8
var _embedded: Array[Node3D] = []
var _jacket_mat: StandardMaterial3D
## Recursos de humo compartidos. Antes cada disparo fabricaba dos curvas, dos
## texturas, un material y un QuadMesh nuevos sólo para una voluta de menos de
## un segundo. En ráfaga eso era trabajo/VRAM transitoria sin aportar un píxel.
var _muzzle_smoke_scale: CurveTexture
var _muzzle_smoke_fade: GradientTexture1D
var _muzzle_smoke_quad: QuadMesh
var _ejection_smoke_scale: CurveTexture
var _ejection_smoke_fade: GradientTexture1D
var _ejection_smoke_quad: QuadMesh
var _barrel_smoke_scale: CurveTexture
var _barrel_smoke_fade: GradientTexture1D
var _barrel_smoke_quad: QuadMesh


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    for surface in IMPACT_MATERIALS:
        _masks[surface] = _make_hole_texture(surface)
    _build_smoke_resources()


func _build_smoke_resources() -> void:
    var muzzle_curve := Curve.new()
    muzzle_curve.add_point(Vector2(0.0, 0.40))
    muzzle_curve.add_point(Vector2(0.28, 1.15))
    muzzle_curve.add_point(Vector2(1.0, 1.85))
    _muzzle_smoke_scale = CurveTexture.new()
    _muzzle_smoke_scale.curve = muzzle_curve
    var muzzle_grad := Gradient.new()
    muzzle_grad.set_color(0, Color(0.88, 0.87, 0.85, 0.88))
    muzzle_grad.add_point(0.25, Color(0.84, 0.83, 0.80, 0.72))
    muzzle_grad.add_point(0.60, Color(0.78, 0.77, 0.74, 0.35))
    muzzle_grad.set_color(1, Color(0.72, 0.72, 0.70, 0.0))
    _muzzle_smoke_fade = GradientTexture1D.new()
    _muzzle_smoke_fade.gradient = muzzle_grad
    _muzzle_smoke_quad = _particle_quad(
        SOFT_TEXTURE, Color(0.88, 0.87, 0.85, 0.95), false, Vector2(0.175, 0.175))

    var ejection_curve := Curve.new()
    ejection_curve.add_point(Vector2(0.0, 0.42))
    ejection_curve.add_point(Vector2(1.0, 1.20))
    _ejection_smoke_scale = CurveTexture.new()
    _ejection_smoke_scale.curve = ejection_curve
    var ejection_grad := Gradient.new()
    ejection_grad.set_color(0, Color(0.78, 0.78, 0.76, 0.55))
    ejection_grad.set_color(1, Color(0.72, 0.72, 0.70, 0.0))
    _ejection_smoke_fade = GradientTexture1D.new()
    _ejection_smoke_fade.gradient = ejection_grad
    _ejection_smoke_quad = _particle_quad(
        SOFT_TEXTURE, Color(0.80, 0.80, 0.78, 0.80), false, Vector2(0.055, 0.055))

    var barrel_curve := Curve.new()
    barrel_curve.add_point(Vector2(0.0, 0.25))
    barrel_curve.add_point(Vector2(0.40, 0.75))
    barrel_curve.add_point(Vector2(1.0, 1.40))
    _barrel_smoke_scale = CurveTexture.new()
    _barrel_smoke_scale.curve = barrel_curve
    var barrel_grad := Gradient.new()
    barrel_grad.set_color(0, Color(0.85, 0.85, 0.83, 0.45))
    barrel_grad.add_point(0.45, Color(0.80, 0.80, 0.78, 0.28))
    barrel_grad.set_color(1, Color(0.75, 0.75, 0.73, 0.0))
    _barrel_smoke_fade = GradientTexture1D.new()
    _barrel_smoke_fade.gradient = barrel_grad
    _barrel_smoke_quad = _particle_quad(
        SOFT_TEXTURE, Color(0.82, 0.82, 0.80, 0.65), false, Vector2(0.080, 0.080))


func spawn_impact(point: Vector3, normal: Vector3, collider: Object, surface: String, is_exit: bool = false) -> void:
    _spawn_decal(point, normal, collider, surface, is_exit)
    _spawn_particles(point, normal, surface, is_exit)
    if not is_exit:
        _spawn_light(point, surface)

    # En una lamina/tabla la entrada y la salida suceden con separacion de
    # milisegundos. Reproducir la misma muestra DOS veces hacia que una sola
    # penetracion sonara como dos impactos baratos. El evento acustico se oye
    # en la entrada; la salida se comunica con geometria y eyeccion.
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
            # Chapa fina de 0,12 mm, no bloque: menos cuerpo (-6 dB) y resonancia
            # mas aguda que el acero. Tiene su propio master, no un pitch hack.
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
            ## Tierra apisonada del patio (`House_Dirt`, `surface="ground"` en
            ## `build_house.terrain`). Suena a madera sorda -6 dB: no hay
            ## muestra de tierra y el suelo es el unico material sin cuerpo
            ## metalico ni cascara, asi que la madera es la mas cercana sin
            ## inventar un pitch hack.
            sound_name = "impact_wood"
            volume = -6.0
        _:
            push_error("ImpactFX sin perfil de audio para material: " + surface)
            return
    GameAudio.play_3d(sound_name, point, volume, pitch)


## Humo de boca: combustion breve -> gas -> voluta residual a la deriva.
## El fogonazo dura milisegundos; el humo persiste: deriva, expansion, fade y
## ligera turbulencia con variacion contenida. Sale del bore (misma direccion
## del proyectil), no de la camara.
## CALIBRADO DOS VECES, y la segunda con los brazos montados y captura delante.
## El alfa que se ve NO es el que se escribe: `vertex_color_use_as_albedo` hace
## que el alfa final sea el PRODUCTO del color de particula y el del quad.
##
##   - salia del punto del mundo donde estaba la boca en ESE frame (que con el
##     arma en movimiento ya no es donde el ojo vio el fogonazo), y
##   - no nacia del canon sino que "aparecia" entero de golpe, porque
##     `explosiveness = 0,97` escupe las 18 particulas en el mismo frame.
##
func spawn_muzzle_smoke(at: Node3D, direction: Vector3) -> void:
    if at == null or not is_instance_valid(at):
        return
    var pm := ParticleProcessMaterial.new()
    pm.direction = direction.normalized()
    pm.spread = 12.0
    pm.initial_velocity_min = 3.20
    pm.initial_velocity_max = 5.20
    pm.gravity = Vector3(0, 0.75, 0)
    pm.scale_min = 0.40
    pm.scale_max = 1.35
    pm.color = Color(0.86, 0.85, 0.82, 0.82)
    pm.damping_min = 3.80
    pm.damping_max = 5.20
    pm.scale_curve = _muzzle_smoke_scale
    pm.color_ramp = _muzzle_smoke_fade

    var particles := GPUParticles3D.new()
    particles.amount = 16
    particles.lifetime = 0.95
    particles.one_shot = true
    particles.explosiveness = 0.65
    particles.process_material = pm
    particles.draw_pass_1 = _muzzle_smoke_quad
    particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    at.add_child(particles)
    particles.position = Vector3.ZERO
    particles.local_coords = false
    get_tree().create_timer(1.35).timeout.connect(particles.queue_free)


## Voluta sutil de calor y humo residual que asciende del cañon o recamara abierta
## cuando el arma esta caliente, bloqueada en reten o durante inspeccion.
func spawn_barrel_smoke(at: Node3D) -> void:
    if at == null or not is_instance_valid(at):
        return
    var pm := ParticleProcessMaterial.new()
    pm.direction = Vector3.UP
    pm.spread = 18.0
    pm.initial_velocity_min = 0.12
    pm.initial_velocity_max = 0.28
    pm.gravity = Vector3(0, 0.45, 0)
    pm.scale_min = 0.35
    pm.scale_max = 0.95
    pm.color = Color(0.84, 0.84, 0.82, 0.45)
    pm.damping_min = 1.20
    pm.damping_max = 2.00
    pm.scale_curve = _barrel_smoke_scale
    pm.color_ramp = _barrel_smoke_fade

    var particles := GPUParticles3D.new()
    particles.amount = 10
    particles.lifetime = 1.40
    particles.one_shot = true
    particles.explosiveness = 0.15
    particles.process_material = pm
    particles.draw_pass_1 = _barrel_smoke_quad
    particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    at.add_child(particles)
    particles.position = Vector3.ZERO
    particles.local_coords = false
    get_tree().create_timer(1.80).timeout.connect(particles.queue_free)



## Humo de eyeccion: gas residual caliente que escapa por la ventana de expulsion
## cuando la corredera abre la recamara y el extractor saca la vaina.
## Mucho mas sutil (4 particulas de 0,04 m) y rapido (0,45 s) que el de boca.
func spawn_ejection_smoke(point: Vector3, direction: Vector3) -> void:
    var pm := ParticleProcessMaterial.new()
    pm.direction = direction.normalized()
    pm.spread = 30.0
    pm.initial_velocity_min = 0.30
    pm.initial_velocity_max = 0.70
    pm.gravity = Vector3(0, 0.36, 0)
    pm.scale_min = 0.42
    pm.scale_max = 1.15
    pm.color = Color(0.70, 0.70, 0.68, 0.40)
    pm.damping_min = 1.8
    pm.damping_max = 2.8
    pm.scale_curve = _ejection_smoke_scale
    pm.color_ramp = _ejection_smoke_fade

    var particles := GPUParticles3D.new()
    particles.amount = 4
    particles.lifetime = 0.45
    particles.one_shot = true
    particles.explosiveness = 0.95
    particles.process_material = pm
    particles.draw_pass_1 = _ejection_smoke_quad
    particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(particles)
    particles.global_position = point
    get_tree().create_timer(0.75).timeout.connect(particles.queue_free)


## SANGRE. La pone el enemigo, no la bala: aqui no se decide nada, solo se dibuja
## el charco. Reutiliza el `Decal` nativo de los agujeros y un unico nodo de
## charco POR enemigo, que se reutiliza en cada impacto: sin fluid simulation, sin
## manchas que crecen, sin capa de gore.
const BLOOD_SPOT_DEPTH := 0.05
const BLOOD_MARGIN := 0.004


## El charco queda en la superficie contra la que salio la bala. Se REAPROVECHA
## el nodo que ya tiene el enemigo: un charco por impacto seria un nodo por
## impacto, y en una pelea con tres cuerpos son basura que se acumula.
##
## `anchor` es opcional: si viene, el charco se cuelga de ese nodo (el hueso
## golpeado) en vez del mundo. Un cuerpo que se cae de la planta alta tiene que
## llevarse su sangre consigo; un charco clavado en el aire se queda flotando.
func spawn_blood_spot(point: Vector3, spot: Decal, dir: Vector3, anchor: Node3D = null) -> void:
    if spot == null:
        return
    ## El suelo es horizontal: el charco se apoya en el plano, no en la normal del
    ## impacto (que seria la del pecho y lo dejaria de canto en el aire).
    var basis := Basis(Vector3.UP, randf_range(0.0, TAU))
    ## CHARCO QUE CREE (dueno: "mas sangre"): nace pequeno y se abre 1.1 s
    ## hasta su tamano real, como una pool de verdad. Sin simulacion de
    ## fluidos: una interpolacion de `size` del propio Decal, un solo nodo,
    ## mismo coste por frame que el charco fijo de antes.
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


## Proyectil incrustado en pino: jacket cobriza a medio hundir, parentada al
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
    # Eje Y del cilindro sobre la direccion de llegada: la punta mira adentro.
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
    if collider is Node3D and collider.get_meta("dynamic_decal", false):
        holder.reparent(collider, true)
    _embedded.append(holder)
    while _embedded.size() > MAX_EMBEDDED:
        var old_node: Node3D = _embedded.pop_front()
        if is_instance_valid(old_node):
            old_node.queue_free()


## Agujero de bala: UN `Decal` anclado a la superficie, con la cavidad hundida
## y el labio de material roto en la misma silueta. El que proyecta es Godot;
## aqui solo se eligen tamano y colocacion de la caja de proyeccion.
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
    ## La caja de proyeccion tiene que CONTENER la superficie con holgura: se
    ## deja casi toda dentro del material y solo los 3 mm de fuera que evitan
    ## que el borde de la caja coincida con la cara (ver PROJECTION_MARGIN).
    var basis := _decal_basis(n).rotated(n, randf_range(0.0, TAU))
    decal.global_transform = Transform3D(basis,
        point - n * (DECAL_DEPTH * 0.5 - PROJECTION_MARGIN))

    if collider is Node3D and collider.get_meta("dynamic_decal", false):
        decal.reparent(collider, true)

    _holes.append({"holder": decal, "surface": collider})
    _evict(collider)


## Godot elige por su cuenta los 8 decales que aplica a una malla, y no siempre
## son los ultimos. Aqui se mantiene el cupo por objeto para que lo que se vea
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


## Base para proyectar sobre una superficie plana o curva.
func _decal_basis(n: Vector3) -> Basis:
    var up := Vector3.UP
    if absf(n.dot(up)) > 0.94:
        up = Vector3.RIGHT
    var x_axis := up.cross(n).normalized()
    if x_axis.length_squared() < 0.01:
        x_axis = Vector3.RIGHT
    var z_axis := x_axis.cross(n).normalized()
    return Basis(x_axis, n, z_axis)


## Silueta del agujero, generada UNA vez al arrancar por material: en el mismo
## RGBA va el hundimiento oscuro del centro, el labio de material roto pegado al
## canto y el color de cada zona ya cocido (el decal va sin `modulate`). Un solo
## decal por agujero porque el motor solo proyecta ocho por malla.
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
            ## Ruido atado al ANGULO: el borde se rompe, no se ensucia el centro.
            var noise := _fbm(cos(angle) * 3.1 + 5.0, sin(angle) * 3.1 + 5.0)
            ## Canto del agujero: corto (0,10 de radio). Con un desvanecido ancho
            ## el disco entero se apagaba y el impacto se leia como una mancha.
            var edge := 0.36 * (1.0 + 0.18 * (noise - 0.5))
            var hole := smoothstep(edge, edge - 0.10, r)
            ## El centro se hunde: casi negro en el fondo, color del material en
            ## el canto.
            var depth := 0.24 + 0.76 * smoothstep(0.0, maxf(edge, 0.01), r)
            ## Labio: pegado al canto y medio transparente, para que la textura
            ## de debajo (madera, metal) siga leyendose a traves del material
            ## arrancado. Sin anillo de pared limpia en medio.
            var outer := 0.62 * (1.0 + 0.16 * (noise - 0.5))
            var chipped := smoothstep(edge - 0.05, edge + 0.02, r) \
                * (1.0 - smoothstep(outer - 0.07, outer, r))
            var alpha := maxf(hole, chipped * 0.62)
            var color := (lip * (0.72 + 0.28 * noise)).lerp(cavity * depth, hole)
            img.set_pixel(x, y, Color(color.r, color.g, color.b, clampf(alpha, 0.0, 1.0)))
    return ImageTexture.create_from_image(img)


## Ruido de valor barato y DETERMINISTA: la silueta es la misma en cada partida,
## asi que dos agujeros del mismo material no salen distintos porque si.
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
        ## Tierra del patio: el suelo ABSORBE. Polvo abundante y lento, cero
        ## cascote (no hay cascara que romper) y la salida casi no arranca
        ## material porque una bala en tierra no hace crater de salida.
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
        # La salida no es "la entrada al 55%". Madera/yeso arrancan material
        # hacia fuera; hormigon/papel pierden menos masa visible.
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
    # El quad va NEUTRO a proposito. `vertex_color_use_as_albedo` multiplica
    # albedo x color de particula, asi que pasar `spec["color"]` en los dos
    # Con el quad blanco manda el color de la particula y lo escrito es lo que
    # sale. Las chispas no cambian de ALFA (ya iban a 1,0 y son aditivas), pero
    # su RGB si estaba al cuadrado: la chispa de acero (1,00/0,72/0,26) salia
    # (1,00/0,52/0,07), mas apagada y mas rojiza. Ahora sale la que se escribio.
    # OJO: el humo de boca y el de eyeccion NO se tocan. Ahi el producto si se
    # compensa a proposito (ver el comentario de `_build_smoke_resources`).
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
