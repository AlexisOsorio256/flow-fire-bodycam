extends Node3D

const WOOD_ALBEDO: Texture2D = preload("res://assets/textures/real/wood_oak_wood_planks_diff.jpg")
const WOOD_NORMAL: Texture2D = preload("res://assets/textures/real/wood_oak_wood_planks_nor_gl.jpg")
const WOOD_ROUGHNESS: Texture2D = preload("res://assets/textures/real/wood_oak_wood_planks_rough.jpg")
const METAL_ALBEDO: Texture2D = preload("res://assets/textures/real/metal_metal_plate_diff.jpg")
const METAL_NORMAL: Texture2D = preload("res://assets/textures/real/metal_metal_plate_nor_gl.jpg")
const METAL_ROUGHNESS: Texture2D = preload("res://assets/textures/real/metal_metal_plate_rough.jpg")

var wood_mat: StandardMaterial3D
var drum_mat: StandardMaterial3D
var stand_mat: StandardMaterial3D
var drywall_mat: StandardMaterial3D
var can_mat: StandardMaterial3D
var table_mat: StandardMaterial3D
var mag_prop_mat: StandardMaterial3D
## Municion de LABORATORIO: 4 cargadores de 15 sobre la mesa y se regeneran.
## El arma no tiene `reserve`; la recarga consume uno de aqui al acercarse.
##
## La mesa es un BANCO DE PRUEBAS, no un inventario: el objetivo es poder probar
## la Glock indefinidamente. Por eso los cargadores vuelven solos tras
## TABLE_REGEN_S sin haber usado la mesa. No hay economia, ni compra, ni
## contador global: un reloj y cuatro posiciones.
const TABLE_MAGS_MAX := 4
const TABLE_MAG_ROUNDS := 15
const TABLE_POS := Vector3(1.8, 0.0, -1.4)
const TABLE_REACH := 1.6
## Segundos sin tocar la mesa hasta que vuelve a estar llena. Uno a uno, no de
## golpe: se ve reaparecer el que falta, que es mas honesto que un salto.
const TABLE_REGEN_S := 6.0
var table_mags := TABLE_MAGS_MAX
var _mag_multimeshes: Array[MultiMesh] = []
var _regen_clock := 0.0
# Sombras de contacto: TODOS los discos de la escena en UN solo mesh.
var _blob_pts := PackedVector3Array()
var _blob_uv := PackedVector2Array()
var _blob_idx := PackedInt32Array()


func build() -> void:
    _materials()
    _build_props()
    _build_targets()
    _build_mag_table()
    _flush_blobs()


## Ancla de contacto para props ESTATICOS. Las 13 luces del bake estan
## ocultas en runtime y los probes del LightmapGI no llevan oclusion: el
## suelo no recibe sombra alguna bajo los postes y los props "flotan".
## Disco de 16 segmentos a y +1,5 mm con degradado por COLOR DE VERTICE
## (alfa 0,45 al centro -> 0 en el borde): sin textura, sin luz (unshaded),
## sin cambios en el bake ni en las luces -> coste ~0 (+1 draw). Solo props
## quietos: latas (Jolt las tira y las hace rodar) dejarian fantasma.
func _blob(x: float, z: float, fx: float, fz: float, rot_y: float = 0.0) -> void:
    var y := 0.006
    var cos_r := cos(rot_y)
    var sin_r := sin(rot_y)
    # fx/fz = media del prop: el anillo INTERNO (UV radio 0,62 = alfa 0,68
    # plano de la textura) va en su borde, que es lo unico visible (debajo
    # esta la propia pieza); el EXTERNO (+17 cm, UV radio 1 = alfa 0) cierra.
    var ci := _blob_pts.size()
    _blob_pts.append(Vector3(x, y, z))
    _blob_uv.append(Vector2(0.5, 0.5))
    for s in range(16):
        var a := TAU * float(s) / 16.0
        var px := cos(a) * fx
        var pz := sin(a) * fz
        _blob_pts.append(Vector3(x + px * cos_r + pz * sin_r, y, z - px * sin_r + pz * cos_r))
        _blob_uv.append(Vector2(0.5 + cos(a) * 0.31, 0.5 + sin(a) * 0.31))
    for s in range(16):
        var a := TAU * float(s) / 16.0
        var px := cos(a) * (fx + 0.17)
        var pz := sin(a) * (fz + 0.17)
        _blob_pts.append(Vector3(x + px * cos_r + pz * sin_r, y, z - px * sin_r + pz * cos_r))
        _blob_uv.append(Vector2(0.5 + cos(a) * 0.5, 0.5 + sin(a) * 0.5))
    # abanico centro -> anillo interno
    for s in range(16):
        _blob_idx.append(ci)
        _blob_idx.append(ci + 1 + ((s + 1) % 16))
        _blob_idx.append(ci + 1 + s)
    # cinta anillo interno -> externo
    for s in range(16):
        var i0 := ci + 1 + s
        var i1 := ci + 1 + ((s + 1) % 16)
        var o0 := ci + 17 + s
        var o1 := ci + 17 + ((s + 1) % 16)
        _blob_idx.append(i0)
        _blob_idx.append(i1)
        _blob_idx.append(o1)
        _blob_idx.append(i0)
        _blob_idx.append(o1)
        _blob_idx.append(o0)


## Un solo MeshInstance3D con TODOS los discos: una submission, sin sombras
## propias ni depth-write (transparente), depth-test contra el suelo.
func _flush_blobs() -> void:
    if _blob_idx.is_empty():
        return
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = _blob_pts
    arrays[Mesh.ARRAY_TEX_UV] = _blob_uv
    arrays[Mesh.ARRAY_INDEX] = _blob_idx
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    # Textura radial COMPARTIDA (mismo camino alpha que los decals de
    # ImpactFX, que funcionan): alfa 0,68 plano hasta d=0,62 -> 0 en d=1.
    var img := Image.create(64, 64, true, Image.FORMAT_RGBA8)
    for yy in range(64):
        for xx in range(64):
            var d := Vector2(float(xx) - 31.5, float(yy) - 31.5).length() / 31.5
            var a := 0.0
            if d <= 0.62:
                a = 0.68
            elif d < 1.0:
                a = 0.68 * (1.0 - (d - 0.62) / 0.38)
            img.set_pixel(xx, yy, Color(0.0, 0.0, 0.0, a))
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.albedo_texture = ImageTexture.create_from_image(img)
    mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    var mi := MeshInstance3D.new()
    mi.name = "ContactBlobs"
    mi.mesh = mesh
    mi.material_override = mat
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mi)


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
    can_mat.albedo_color = Color(0.78, 0.80, 0.84)
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

    table_mat = StandardMaterial3D.new()
    table_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    table_mat.albedo_texture = WOOD_ALBEDO
    table_mat.albedo_color = Color(0.48, 0.44, 0.40)
    table_mat.roughness_texture = WOOD_ROUGHNESS
    table_mat.normal_enabled = true
    table_mat.normal_texture = WOOD_NORMAL
    table_mat.normal_scale = 0.6
    table_mat.roughness = 0.75
    table_mat.uv1_scale = Vector3(1.5, 1.0, 1.5)

    mag_prop_mat = StandardMaterial3D.new()
    mag_prop_mat.albedo_color = Color(0.12, 0.12, 0.14)
    mag_prop_mat.metallic = 0.6
    mag_prop_mat.roughness = 0.45

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
    _blob(x, z, 0.61, 0.05, rot_y)


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
        _blob(base.x, base.z, size * 0.5, size * 0.5)
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
    _blob(base.x, base.z, panel_size.x * 0.5, 0.01, rot_y)
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
    _blob(x, z, 0.29, 0.29)


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
    _blob(x, z - 0.12, 0.55, 0.25)

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
    _blob(x, z - 0.10, 0.35, 0.25)

    var target := Target.new()
    target.kind = "steel"
    target.name = "SteelTarget"
    add_child(target)
    target.global_position = Vector3(x, 1.35, z)

    _make_joint(frame, target, Vector3(x, 1.66, z))


## Mesa de cargadores: la fuente fisica de municion. Sin inventario ni manager:
## 4 cuerpos sobre la mesa, cada uno 15. Acercarse + R consume uno.
func _process(delta: float) -> void:
    # Regeneracion de la mesa: un cargador cada TABLE_REGEN_S, solo si falta
    # alguno. Determinista y visible: reaparece donde estaba.
    if table_mags < TABLE_MAGS_MAX:
        _regen_clock += delta
        if _regen_clock >= TABLE_REGEN_S:
            _regen_clock = 0.0
            table_mags += 1
            _update_table_mag_visibility()
    else:
        _regen_clock = 0.0


func _build_mag_table() -> void:
    var table := StaticBody3D.new()
    table.name = "MagTable"
    table.position = TABLE_POS
    add_child(table)
    table.set_meta("surface", "pine")
    var top := MeshInstance3D.new()
    var top_mesh := BoxMesh.new()
    top_mesh.size = Vector3(0.7, 0.05, 0.5)
    top_mesh.material = table_mat
    top.mesh = top_mesh
    top.position = Vector3(0, 0.75, 0)
    table.add_child(top)
    var top_col := CollisionShape3D.new()
    var top_shape := BoxShape3D.new()
    top_shape.size = Vector3(0.7, 0.05, 0.5)
    top_col.shape = top_shape
    top_col.position = Vector3(0, 0.75, 0)
    table.add_child(top_col)
    # Las cuatro patas son sólo visuales y comparten malla/material: una sola
    # submission con MultiMesh conserva exactamente la geometría anterior.
    var leg_mesh := BoxMesh.new()
    leg_mesh.size = Vector3(0.05, 0.75, 0.05)
    leg_mesh.material = table_mat
    var legs_multimesh := MultiMesh.new()
    legs_multimesh.transform_format = MultiMesh.TRANSFORM_3D
    legs_multimesh.mesh = leg_mesh
    legs_multimesh.instance_count = 4
    var leg_index := 0
    for leg_x in [-0.3, 0.3]:
        for leg_z in [-0.2, 0.2]:
            legs_multimesh.set_instance_transform(
                leg_index,
                Transform3D(Basis.IDENTITY, Vector3(leg_x, 0.375, leg_z))
            )
            leg_index += 1
            # Punto de contacto de CADA pata (la mesa es hueca por debajo:
            # un disco unico debajo se leeria como alfombra).
            _blob(TABLE_POS.x + leg_x, TABLE_POS.z + leg_z, 0.025, 0.025)
    var legs_instance := MultiMeshInstance3D.new()
    legs_instance.multimesh = legs_multimesh
    table.add_child(legs_instance)
    # Cuatro cargadores x tres piezas eran 12 draw calls para una silueta que no
    # tiene colisión propia. Tres MultiMesh conservan exactamente cuerpo/base/
    # labios y dejan el coste en 3 draws; visible_instance_count mantiene la
    # mecánica física de consumir/regenerar cargadores sin nodos decorativos.
    _mag_multimeshes.clear()
    var pieces := [
        [Vector3(0.026, 0.098, 0.037), Vector3(0.0, 0.0, 0.0)],
        [Vector3(0.030, 0.012, 0.044), Vector3(0.0, -0.053, 0.002)],
        [Vector3(0.022, 0.012, 0.032), Vector3(0.0, 0.053, -0.004)],
    ]
    for piece in pieces:
        var box := BoxMesh.new()
        box.size = piece[0] as Vector3
        box.material = mag_prop_mat

        var multimesh := MultiMesh.new()
        multimesh.transform_format = MultiMesh.TRANSFORM_3D
        multimesh.mesh = box
        multimesh.instance_count = TABLE_MAGS_MAX
        multimesh.visible_instance_count = table_mags

        for i in range(TABLE_MAGS_MAX):
            var mag_basis := Basis(Vector3(0, 0, 1), deg_to_rad(-8.0))
            var mag_transform := Transform3D(mag_basis, Vector3(-0.21 + i * 0.14, 0.845, 0.0))
            var piece_transform := Transform3D(Basis.IDENTITY, piece[1] as Vector3)
            multimesh.set_instance_transform(i, mag_transform * piece_transform)

        var instance := MultiMeshInstance3D.new()
        instance.multimesh = multimesh
        table.add_child(instance)
        _mag_multimeshes.append(multimesh)


## Se PUEDE tomar un cargador? No consume nada: es la pregunta que hay que
## hacer ANTES de tocar el inventario. Antes solo existia `try_take_mag`, que
## restaba primero y devolvia las balas despues, asi que `start_reload` podia
## fallar (recarga en curso, cargador lleno) con el cargador YA gastado: se
## perdia municion sin recargar. Ahora se valida y luego se consume.
func can_take_mag(player_pos: Vector3) -> bool:
    return table_mags > 0 and player_pos.distance_to(TABLE_POS) <= TABLE_REACH


## Consume un cargador de la mesa y devuelve sus cartuchos. SOLO se llama
## despues de `can_take_mag` y de que el arma haya aceptado la recarga.
func consume_mag() -> int:
    if table_mags <= 0:
        return 0
    table_mags -= 1
    _regen_clock = 0.0
    _update_table_mag_visibility()
    return TABLE_MAG_ROUNDS


func _update_table_mag_visibility() -> void:
    for multimesh in _mag_multimeshes:
        multimesh.visible_instance_count = table_mags


func table_near(player_pos: Vector3) -> bool:
    return player_pos.distance_to(TABLE_POS) <= TABLE_REACH


func _make_joint(frame: StaticBody3D, target: RigidBody3D, pivot: Vector3) -> void:
    var joint := PinJoint3D.new()
    frame.add_child(joint)
    joint.node_a = frame.get_path()
    joint.node_b = target.get_path()
    joint.global_position = pivot
