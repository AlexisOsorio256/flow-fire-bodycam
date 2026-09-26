extends Node3D

## Mesa de cargadores del banco. La consume `Player`; es el MISMO `AmmoTable`
## que usa el mapa de combate, no una copia.
var ammo: AmmoTable
const TABLE_POS := Vector3(1.8, 0.0, -1.4)
var _contact_blobs := ContactBlob.new()

const WOOD_ALBEDO: Texture2D = preload("res://assets/textures/real/wood_oak_wood_planks_diff.jpg")
const WOOD_NORMAL: Texture2D = preload("res://assets/textures/real/wood_oak_wood_planks_nor_gl.jpg")
const WOOD_ROUGHNESS: Texture2D = preload("res://assets/textures/real/wood_oak_wood_planks_rough.jpg")
const METAL_NORMAL: Texture2D = preload("res://assets/textures/real/metal_metal_plate_nor_gl.jpg")
const METAL_ROUGHNESS: Texture2D = preload("res://assets/textures/real/metal_metal_plate_rough.jpg")

var wood_mat: StandardMaterial3D
var drum_mat: StandardMaterial3D
var stand_mat: StandardMaterial3D
var drywall_mat: StandardMaterial3D
var can_mat: StandardMaterial3D
func build() -> void:
    _materials()
    _build_props()
    _build_targets()
    ammo = AmmoTable.new()
    ammo.name = "AmmoTable"
    ammo.position = TABLE_POS
    add_child(ammo)
    var blobs := _contact_blobs.build()
    if blobs != null:
        add_child(blobs)


func _materials() -> void:
    wood_mat = StandardMaterial3D.new()
    wood_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    wood_mat.albedo_texture = WOOD_ALBEDO
    wood_mat.roughness_texture = WOOD_ROUGHNESS
    wood_mat.normal_enabled = true
    wood_mat.normal_texture = WOOD_NORMAL
    wood_mat.normal_scale = 1.0
    wood_mat.uv1_scale = Vector3(1.5, 1, 1.5)
    wood_mat.roughness = 0.8

    # Bidon de acero PINTADO, no chapa desnuda: sigue siendo dielectrico, pero
    # no negro puro. En las capturas reales el valor anterior 0,16 desaparecia
    # contra el fondo aunque la sala estuviera bien expuesta.
    drum_mat = StandardMaterial3D.new()
    drum_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    # La textura diffuse de chapa es demasiado oscura para pintura: se conserva
    # su normal/roughness pero la capa pintada usa color base propio.
    # Grano de PINTURA derivado del mismo difuso (solo grano k=0,20, sin
    # relieve de diamante: la pintura es lisa y la chapa de diamante quedaria
    # mal en bidon), media 0,7456 verificada en roundtrip -> color x1,341
    # devuelve 0,30/0,33/0,37 intacto: la puerta solo nota el contraste. Era
    # el ultimo material plano del audit (tesela std<3, luma 107 en los dos
    # bidones); la normal y la roughness no pintan sin luz direccional.
    drum_mat.albedo_texture = preload("res://assets/textures/real/metal_paint_grain.jpg")
    drum_mat.albedo_color = Color(0.402, 0.443, 0.496)
    drum_mat.roughness_texture = METAL_ROUGHNESS
    drum_mat.normal_enabled = true
    drum_mat.normal_texture = METAL_NORMAL
    drum_mat.normal_scale = 0.8
    drum_mat.metallic = 0.0
    drum_mat.roughness = 0.68
    drum_mat.uv1_scale = Vector3(2, 2, 2)

    stand_mat = StandardMaterial3D.new()
    stand_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    # Soporte de acero apagado, no black chrome: debe separar placa y suelo sin
    # pedir otra luz de mundo ni lavar los negros de toda la escena.
    # Grano + relieve de diamante derivado offline (difuso de chapa del mismo
    # set + su normal estirada): la sala solo da ambiente y la normal por si
    # sola no pinta nada (soporte plano medido, std 1,3). Media del archivo
    # 0,5964 -> color x1,677 devuelve la media original (0,42/0,44/0,48): la
    # puerta de imagen solo nota el contraste, no la media. Coste = 1 fetch de
    # albedo solo en pixeles de acero, ya se muestreaba normal+roughness.
    stand_mat.albedo_texture = preload("res://assets/textures/real/metal_plate_grain.jpg")
    stand_mat.albedo_color = Color(0.704, 0.738, 0.805)
    stand_mat.metallic = 0.45
    stand_mat.roughness = 0.62
    stand_mat.normal_enabled = true
    stand_mat.normal_texture = METAL_NORMAL
    stand_mat.normal_scale = 0.35
    stand_mat.uv1_scale = Vector3(1.0, 3.0, 1.0)

    # Lata de aluminio: metal claro, casi sin espesor. La balistica no la trata
    # como un cilindro macizo (ver `_make_can`).
    can_mat = StandardMaterial3D.new()
    # Mismo grano de pintura que el bidon (archivo ya en repo, media 0,7456
    # -> color original /0,7456): sin textura la lata era un cilindro pastel
    # liso de plastico en el zoom del encuadre `can` (lo ultimo plano del
    # rango; medido std 0,41 identico entre frames). El grano la lee como
    # aluminio cepillado. Media conservada -> puertas intactas por
    # construccion; coste = 1 fetch solo en pixeles de lata.
    can_mat.albedo_texture = preload("res://assets/textures/real/metal_paint_grain.jpg")
    can_mat.albedo_color = Color(1.046, 1.073, 1.127)
    can_mat.metallic = 0.85
    can_mat.roughness = 0.32

    drywall_mat = StandardMaterial3D.new()
    drywall_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    # SET DE ESCAYOLA PINTADA (gypsum_*): derivado del hormigon cepillado
    # (Poly Haven CC0, mismo credito) y calibrado para NO mover la luz: el
    # albedo es gris neutro de media 99,9 -> L de salida 0,5393 frente al
    # 0,5396 del color plano 0,55 (tinte x1,40 intacto), con std 9,5 = grano
    # de pintura fino: 4,5 medidos en pantalla, entre la tarjeta lisa 1,3 y
    # el hormigon 9,5; la roughness de media 224 con scalar 1,0 da rugosidad
    # efectiva 0,878 ~ la 0,88 anterior, con +-3% de variacion micro. Normal
    # del mismo origen cepillado, suavizado a 0,25 (papel de escayola, no
    # llana de hormigon).
    drywall_mat.albedo_texture = preload("res://assets/textures/real/gypsum_diff.jpg")
    drywall_mat.albedo_color = Color(1.403, 1.378, 1.301)
    drywall_mat.roughness = 1.0
    drywall_mat.roughness_texture = preload("res://assets/textures/real/gypsum_rough.jpg")
    drywall_mat.normal_enabled = true
    drywall_mat.normal_texture = preload("res://assets/textures/real/concrete_brushed_concrete_nor_gl.jpg")
    drywall_mat.normal_scale = 0.25
    drywall_mat.uv1_scale = Vector3(3, 3, 3)


func _build_props() -> void:
    # LAS PLANCHAS DE ACERO YA NO ESTAN, y es una decision del dueño del repo,
    # no una perdida: eran cinco mamparas atravesadas en los carriles que
    # bloqueaban el paso y la linea de tiro ("no quiero que esten los fierros,
    # debe estar sin eso [para] moverme por donde yo quiero en todo el mapa").
    # El rango es un instrumento de medida: se camina por el y se dispara a lo
    # que hay, sin escondites de por medio. `_make_barrier` se va con ellas.

    _make_plank_wall(-2.5, -12.0, deg_to_rad(15.0))
    # Torre de 4: el tiro de pie (~1.37 m a 2.5 m) da al cajon alto. Una 9 mm
    # que lo atraviesa le deja ~0,2 N.s a 4,2 kg: tiembla, no vuelca (medido:
    # 0,04 m/s de pico). El vuelco seria inventar momento; la caja responde
    # con agujeros que viajan con ella. El sencillo queda para tiro picado.
    _make_crate(Vector3(4.8, 0.0, -9.5), 0.35)
    _make_crate(Vector3(4.8, 0.35, -9.5), 0.35)
    _make_crate(Vector3(4.8, 0.70, -9.5), 0.35)
    _make_crate(Vector3(4.8, 1.05, -9.5), 0.35)
    _make_crate(Vector3(-7.2, 0.0, -20.5), 0.35)

    _make_drum(6.6, -11.0)
    _make_drum(-6.8, -25.0)
    _make_drum(7.2, -27.0)

    # ---------------------------------------------------- QUE HAYA QUE DISPARAR
    # Peticion del dueño: "no le puedo disparar a nada porque no hay nada".
    # Tenia razon y era literal: lo mas cercano estaba a 8 m y TODA la mitad de
    # atras del rango (z > 0, 66 m de pasillo) estaba vacia, asi que caminar
    # hacia atras era caminar por una nave en obra. Esto no son "estaciones de
    # medida" -- esas siguen siendo las de `_build_targets` -- es material para
    # tener algo delante a cualquier distancia y en cualquier direccion.
    # Todo reutiliza los constructores que ya existen, con su material real
    # (lata = thin_shell de aluminio, caja = pino hueco, bidon = acero).
    # Fila de latas a 2 m del puesto: lo primero que se ve al levantar el arma.
    for i in range(5):
        _make_can(Vector3(-3.2 + i * 1.6, 0.061, -5.6))
    # Y blancos GRANDES a 6 y 8 m, que es lo que se echa en falta de verdad:
    # una lata a 6 m son 14 px y no se ve. Tres de acero (chispa y suena) y dos
    # de papel (agujero limpio) delante de las narices, sin tener que ir a
    # buscarlos a 18 m.
    for i in range(3):
        _make_steel_target(-2.0 + i * 2.0, -6.0)
    for i in range(2):
        _make_paper_target(-1.0 + i * 2.0, -8.0)
    # Otra fila a 7 m, esta vez sobre una tabla baja: obliga a apuntar.
    _make_plank_wall(5.6, -7.2, deg_to_rad(0.0))
    for i in range(3):
        _make_can(Vector3(5.0 + i * 0.6, 0.061, -7.4))
    # NADA DETRAS DE LA LINEA DE TIRO. El dueño lo dijo sin rodeos: "no tiene
    # sentido que se pongan esas cosas asi, es hacia atras". Tenia razon: el
    # rango se dispara hacia -Z y poner material a la espalda del tirador no es
    # un rango, es almacen. Todo lo que hay para disparar esta DELANTE.

    # ------------------------------------------------- EL PASILLO, LLENO
    # Peticion del dueño: "todo lo bueno para tirarle -- madera, latas, botes,
    # paredes para traspasar -- va en el pasillo grande y bien iluminado, para
    # divertirme". Va TODO delante de la linea de tiro, de 3 m a 55 m, para que
    # se pueda caminar hacia el fondo disparando sin quedarse sin nada. La otra
    # mitad del rango se queda vacia (lo pidio asi) pero con luz.
    # Nada de geometria nueva: se reutilizan los constructores que ya existen.
    _make_plank_wall(4.6, -10.5, deg_to_rad(-9.0))
    _make_plank_wall(-5.2, -17.0, deg_to_rad(12.0))
    _make_plank_wall(5.4, -30.0, deg_to_rad(-7.0))
    _make_plank_wall(-5.0, -42.0, deg_to_rad(6.0))
    _make_drywall_panel(Vector3(-8.6, 0.0, -14.0), Vector2(2.6, 2.4), deg_to_rad(0.0))
    _make_drywall_panel(Vector3(8.6, 0.0, -18.0), Vector2(2.6, 2.4), deg_to_rad(0.0))
    _make_drywall_panel(Vector3(-8.0, 0.0, -33.0), Vector2(2.6, 2.4), deg_to_rad(0.0))
    _make_drywall_panel(Vector3(8.0, 0.0, -44.0), Vector2(2.6, 2.4), deg_to_rad(0.0))
    # Bidones de acero repartidos por todo el pasillo: son los que suenan.
    for z in [-8.6, -16.0, -21.0, -29.0, -38.0, -47.0]:
        _make_drum(-6.6 if int(z) % 2 == 0 else 6.6, z)
    # Torres de cajas de pino (huecas, se atraviesan): a varias distancias.
    for z in [-7.0, -19.0, -26.0, -34.0, -45.0]:
        for level in range(2):
            _make_crate(Vector3(3.4, 0.35 * level, z), 0.35)
    # Latas: el caso de prueba de `thin_shell`. Sueltas por el suelo y de pie
    # sobre los bidones, de cerca a lejos.
    for i in range(6):
        _make_can(Vector3(-4.4 + i * 0.55, 0.061, -3.7))
    for z in [-9.0, -13.0, -20.0, -23.0, -31.0, -36.0, -40.0, -48.0, -53.0]:
        _make_can(Vector3(-1.2 + float(z) * 0.05, 0.061, z))

    # Latas: cascara fina penetrable sobre el bidon de x=6.6 y en el suelo. Son
    # el caso de prueba de `thin_shell`: la bala las atraviesa perdiendo casi
    # nada y Jolt las tira y las hace rodar.
    _make_can(Vector3(6.52, 0.98, -10.92))
    _make_can(Vector3(6.68, 0.98, -11.04))
    _make_can(Vector3(6.60, 0.98, -11.16))
    _make_can(Vector3(-1.60, 0.061, -13.60))
    _make_can(Vector3(-1.40, 0.061, -13.72))


func _build_targets() -> void:
    # Estaciones de medicion: 18 m papel, 27 m acero/angulos, 35 m agrupacion,
    # 50 m caida/zero. Cada cosa responde una pregunta concreta.
    for i in range(5):
        _make_paper_target(-4.0 + i * 2.0, -18.0)
    for i in range(3):
        _make_steel_target(-3.0 + i * 3.0, -27.0)
    for i in range(3):
        _make_paper_target(-2.0 + i * 2.0, -35.0)
    _make_steel_target(0.0, -50.0)


func _static_box(parent: Node3D, node_name: String, size: Vector3, pos: Vector3, mat: Material) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.name = node_name
    body.position = pos
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


func _make_plank_wall(x: float, z: float, rot_y: float) -> void:
    var root := Node3D.new()
    root.name = "PlankWall"
    root.position = Vector3(x, 0, z)
    root.rotation.y = rot_y
    add_child(root)
    for i in range(5):
        var plank := _static_box(root, "Plank", Vector3(0.22, 1.9, 0.045), Vector3((i - 2) * 0.25, 0.95, 0), wood_mat)
        plank.set_meta("surface", "pine")
        plank.set_meta("penetrable", true)
    for rail_y in [0.5, 1.5]:
        var rail := _static_box(root, "PlankRail", Vector3(1.3, 0.09, 0.03), Vector3(0, rail_y, -0.05), wood_mat)
        rail.set_meta("surface", "pine")
        rail.set_meta("penetrable", true)
    _contact_blobs.add(x, z, 0.61, 0.05, rot_y)


## Caja HUECA honesta: 6 paneles de pino de 12 mm, no bloque macizo; la bala
## atraviesa dos paredes (24 mm), no 350 mm de madera. Con pino 7/m el 9 mm
## sale a ~320 m/s y transmite ~0,2 N·s: la caja recibe el agujero y apenas
## se inmuta (delta-v ~0,05 m/s = milimetros con friccion). Dos cajas seguidas
## tampoco la detienen (~298 m/s de salida). Fisica honesta: una pistola no
## voltea cajones. Los agujeros viajan con la caja, y el empuje del golpe se
## lee donde la fisica lo da: acero colgado (oscilacion medida 0,54 rad/s),
## latas y papel.
func _make_crate(base: Vector3, size: float) -> void:
    var box := RigidBody3D.new()
    box.name = "WoodCrate"
    box.mass = 4.2
    box.collision_layer = 1
    box.collision_mask = 1
    box.continuous_cd = true
    box.linear_damp = 0.3
    box.angular_damp = 0.5
    box.set_meta("dynamic_decal", true)
    box.set_meta("surface", "pine")
    box.set_meta("penetrable", true)
    box.set_meta("thin_shell", true)
    box.set_meta("wall_thickness", 0.012)
    box.position = base + Vector3(0, size * 0.5, 0)
    add_child(box)
    # Ancla SOLO del cajon que toca el suelo: recibe el agujero y se mueve
    # milimetros (friccion), asi que el disco sigue cubriendolo. Los de
    # arriba quedarian flotando en el aire.
    if base.y < 0.01:
        _contact_blobs.add(base.x, base.z, size * 0.5, size * 0.5)
    var t := 0.012
    var panels := [
        [Vector3(size, t, size), Vector3(0, -size * 0.5 + t * 0.5, 0)],
        [Vector3(size, t, size), Vector3(0, size * 0.5 - t * 0.5, 0)],
        [Vector3(size, size, t), Vector3(0, 0, -size * 0.5 + t * 0.5)],
        [Vector3(size, size, t), Vector3(0, 0, size * 0.5 - t * 0.5)],
        [Vector3(t, size, size), Vector3(-size * 0.5 + t * 0.5, 0, 0)],
        [Vector3(t, size, size), Vector3(size * 0.5 - t * 0.5, 0, 0)],
    ]
    for panel in panels:
        var psize: Vector3 = panel[0] as Vector3
        var ppos: Vector3 = panel[1] as Vector3
        var mi := MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = psize
        bm.material = wood_mat
        mi.mesh = bm
        mi.position = ppos
        box.add_child(mi)
        var cs := CollisionShape3D.new()
        var bs := BoxShape3D.new()
        bs.size = psize
        cs.shape = bs
        cs.position = ppos
        box.add_child(cs)


func _make_drywall_panel(base: Vector3, panel_size: Vector2, rot_y: float) -> void:
    var root := Node3D.new()
    root.name = "DrywallPanel"
    root.position = base
    root.rotation.y = rot_y
    add_child(root)
    var body := _static_box(root, "DrywallSheet", Vector3(panel_size.x, panel_size.y, 0.0127), Vector3(0.0, panel_size.y * 0.5, 0.0), drywall_mat)
    body.set_meta("surface", "gypsum")
    body.set_meta("penetrable", true)
    _contact_blobs.add(base.x, base.z, panel_size.x * 0.5, 0.01, rot_y)
    # Hoja honesta de 1/2" (12,7 mm): la tabla balistica se resuelve en
    # Ballistics.MATERIALS y este cuerpo solo declara material + geometria.


func _make_drum(x: float, z: float) -> void:
    var body := StaticBody3D.new()
    body.name = "SteelDrum"
    body.position = Vector3(x, 0.46, z)
    add_child(body)

    var mesh_instance := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.height = 0.92
    mesh.top_radius = 0.29
    mesh.bottom_radius = 0.29
    mesh.radial_segments = 40
    mesh.material = drum_mat
    mesh_instance.mesh = mesh
    body.add_child(mesh_instance)

    var shape := CollisionShape3D.new()
    var cyl := CylinderShape3D.new()
    cyl.height = 0.92
    cyl.radius = 0.29
    shape.shape = cyl
    body.add_child(shape)
    body.set_meta("surface", "steel")
    body.set_meta("penetrable", true)
    body.set_meta("thin_shell", true)
    body.set_meta("wall_thickness", 0.0012)
    _contact_blobs.add(x, z, 0.29, 0.29)


## Lata de aluminio vacia. Jolt la mueve (rueda, rebota, se voltea) con una
## CylinderShape3D, pero la balistica NO la trata como un cilindro macizo de
## aluminio: es una cascara de 0,12 mm, asi que declara `thin_shell` y la bala
## pierde energia en DOS paredes finas, no en 66 mm de metal. El aire de dentro
## no frena nada.
func _make_can(base: Vector3) -> void:
    var body := RigidBody3D.new()
    body.name = "Can"
    body.mass = 0.014
    body.collision_layer = 1
    body.collision_mask = 1
    body.continuous_cd = true
    body.linear_damp = 0.12
    body.angular_damp = 0.18
    body.position = base
    add_child(body)

    var mesh_instance := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.height = 0.122
    mesh.top_radius = 0.033
    mesh.bottom_radius = 0.033
    mesh.radial_segments = 32
    mesh.material = can_mat
    mesh_instance.mesh = mesh
    body.add_child(mesh_instance)

    var shape := CollisionShape3D.new()
    var cyl := CylinderShape3D.new()
    cyl.height = 0.122
    cyl.radius = 0.033
    shape.shape = cyl
    body.add_child(shape)

    var mat := PhysicsMaterial.new()
    mat.bounce = 0.28
    mat.friction = 0.5
    body.physics_material_override = mat

    body.set_meta("dynamic_decal", true)
    body.set_meta("surface", "aluminum")
    body.set_meta("penetrable", true)
    body.set_meta("thin_shell", true)
    body.set_meta("wall_thickness", 0.00012)
    # Aluminio: la tabla balistica lo mantiene separado del acero.


func _make_paper_target(x: float, z: float) -> void:
    var frame := StaticBody3D.new()
    frame.name = "PaperTargetFrame"
    frame.position = Vector3(x, 0, z)
    add_child(frame)

    for post_x in [-0.42, 0.42]:
        var post := _static_box(frame, "Post", Vector3(0.05, 1.78, 0.05), Vector3(post_x, 0.89, -0.12), stand_mat)
        post.set_meta("surface", "steel")
    var base := _static_box(frame, "Base", Vector3(1.1, 0.06, 0.5), Vector3(0, 0.03, -0.12), stand_mat)
    base.set_meta("surface", "steel")
    _contact_blobs.add(x, z - 0.12, 0.55, 0.25)

    var target := Target.new()
    target.kind = "paper"
    target.name = "PaperTarget"
    add_child(target)
    target.global_position = Vector3(x, 1.35, z)

    _make_joint(frame, target, Vector3(x, 1.80, z))


func _make_steel_target(x: float, z: float) -> void:
    var frame := StaticBody3D.new()
    frame.name = "SteelTargetFrame"
    frame.position = Vector3(x, 0, z)
    add_child(frame)

    var post := _static_box(frame, "SteelPost", Vector3(0.07, 1.62, 0.07), Vector3(0, 0.81, -0.10), stand_mat)
    post.set_meta("surface", "steel")
    var base := _static_box(frame, "SteelBase", Vector3(0.7, 0.06, 0.5), Vector3(0, 0.03, -0.10), stand_mat)
    base.set_meta("surface", "steel")
    _contact_blobs.add(x, z - 0.10, 0.35, 0.25)

    var target := Target.new()
    target.kind = "steel"
    target.name = "SteelTarget"
    add_child(target)
    target.global_position = Vector3(x, 1.35, z)

    _make_joint(frame, target, Vector3(x, 1.66, z))


func _make_joint(frame: StaticBody3D, target: RigidBody3D, pivot: Vector3) -> void:
    var joint := PinJoint3D.new()
    frame.add_child(joint)
    joint.node_a = frame.get_path()
    joint.node_b = target.get_path()
    joint.global_position = pivot
