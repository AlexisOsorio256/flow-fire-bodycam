class_name Shell
extends RigidBody3D

## Vaina 9x19 expulsada: cuerpo fisico real con su presentacion.
##
## El asset no trae cartucho suelto aprovechable (sus balas van soldadas al
## cargador en la malla), asi que el casquillo se construye aqui y no depende
## de ningun arma concreta: `spawn` lo fabrica entero (malla, colision,
## fisica, velocidad de eyeccion) y Glock solo dice CUANDO nace.

var life := 0.0
var last_ping := 0.0
var _still := 0.0
var _settled := false

## 9x19 real: 19,15 mm de largo x 4,9 mm de radio de culote. Malla y colision
## leen los mismos numeros; no hay una medida visual y otra fisica.
const CASING_LEN := 0.01915
const CASING_RAD := 0.0049

## Asentamiento: por debajo de estas velocidades y durante este rato, la vaina
## esta quieta. Solo entonces se apaga el CCD y el monitor de contactos.
const SETTLE_LIN := 0.06    # m/s
const SETTLE_ANG := 0.6     # rad/s
const SETTLE_S := 0.35      # s seguidos de quieta

## UNA sola malla, material, forma y fisica para TODAS las vainas: son
## identicas y nadie las toca. Antes cada disparo fabricaba los cuatro y subia
## una malla nueva a la GPU; en una tanda de 120 disparos eran 120 RIDs de
## malla + 120 de material + 120 de forma sin ningun motivo, y esa churn
## aparece justo en los picos de p95/p99 del camino de disparo.
static var _casing_mesh: CylinderMesh
static var _casing_shape: CylinderShape3D
static var _casing_physics: PhysicsMaterial


static func _resources() -> void:
    if _casing_mesh != null:
        return
    _casing_mesh = CylinderMesh.new()
    _casing_mesh.top_radius = CASING_RAD
    _casing_mesh.bottom_radius = CASING_RAD
    _casing_mesh.height = CASING_LEN
    _casing_mesh.radial_segments = 12
    _casing_mesh.rings = 1
    var brass := StandardMaterial3D.new()
    brass.albedo_color = Color(0.72, 0.53, 0.18)
    brass.metallic = 0.95
    brass.roughness = 0.28
    _casing_mesh.material = brass
    _casing_shape = CylinderShape3D.new()
    _casing_shape.height = CASING_LEN
    _casing_shape.radius = CASING_RAD
    _casing_physics = PhysicsMaterial.new()
    _casing_physics.bounce = 0.52
    _casing_physics.friction = 0.45


## Fabrica una vaina en el puerto de eyeccion y la devuelve anadida a `scene`.
## `slide_vel` es la velocidad real de la corredera (el extractor empuja hacia
## atras con parte de ella); `player_vel` se hereda parcial (la vaina sale de
## un arma en movimiento).
static func spawn(scene: Node, port: Transform3D, slide_vel: float, player_vel: Vector3) -> Shell:
    _resources()
    var shell := Shell.new()
    shell.mass = 0.0039   # casquillo 9x19 vacio: ~3,9 g de laton
    shell.collision_layer = 2
    shell.collision_mask = 1
    shell.continuous_cd = true

    var casing_inst := MeshInstance3D.new()
    casing_inst.name = "CasingMesh"
    casing_inst.mesh = _casing_mesh
    casing_inst.rotation.x = deg_to_rad(90.0)
    shell.add_child(casing_inst)

    # La colisión no necesita seguir la malla: un cilindro del tamaño medido de
    # la vaina es más barato y más estable que un convex hull de 432 vértices.
    var collider := CollisionShape3D.new()
    collider.shape = _casing_shape
    # El cilindro nace con el eje en Y y la vaina va tumbada a lo largo del
    # cañón, que en el marco del arma es Z.
    collider.rotation.x = deg_to_rad(-90.0)
    shell.add_child(collider)

    shell.physics_material_override = _casing_physics
    # Rozamiento del aire sobre una vaina de 3,9 g: frena en vuelo en vez de
    # cruzar la pantalla de lado a lado en 90 ms (que es lo que hacía).
    shell.linear_damp = 0.9
    shell.angular_damp = 0.5

    scene.add_child(shell)
    shell.global_transform = port
    # El puerto está en la cara derecha del arma: el casquillo sale a la derecha
    # (+X), arriba (+Y) y algo hacia atrás (+Z, que es la cola del arma).
    # La vaina sale empujada por el extractor: hacia atrás hereda parte de la
    # velocidad real de la corredera, y el expulsor la tira a la derecha y
    # arriba. El giro es rápido (una vaina recién expulsada voltea).
    var local_vel := Vector3(1.5 + randf() * 0.7, 1.3 + randf() * 0.6, maxf(0.6, slide_vel * 0.35))
    shell.linear_velocity = port.basis * local_vel + player_vel * 0.8
    shell.angular_velocity = Vector3(randf_range(-34.0, 34.0), randf_range(-34.0, 34.0), randf_range(-34.0, 34.0))
    return shell


func _ready() -> void:
    contact_monitor = true
    max_contacts_reported = 4
    body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
    life += delta
    if life > 14.0:
        queue_free()
        return
    if _settled:
        return
    # Reposo real: lineal Y angular por debajo del umbral durante SETTLE_S.
    # En ese punto el CCD ya no barrido nada y el monitor de contactos solo
    # costaba manifiuestos para señales que nadie necesita de una vaina quieta;
    # nada la volvera a despertar andando (las balas enmascaran contra la capa
    # 2 de esta vaina y el jugador tampoco la toca).
    if linear_velocity.length() < SETTLE_LIN and angular_velocity.length() < SETTLE_ANG:
        _still += delta
        if _still >= SETTLE_S:
            _settled = true
            continuous_cd = false
            contact_monitor = false
    else:
        _still = 0.0


func _on_body_entered(_body: Node) -> void:
    if life < 0.06 or life - last_ping < 0.12:
        return
    var speed := linear_velocity.length()
    if speed > 0.65:
        last_ping = life
        GameAudio.play_3d("shell_drop", global_position, 0.0, randf_range(0.92, 1.12))
