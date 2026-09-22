extends Node3D
## RangeShell: la arquitectura del rango es GEOMETRIA y solo geometria.
##
## El .glb NO lleva texturas dentro. `tools/build_range_shell.py` exporta la
## malla con UV a densidad fisica (una vuelta de textura cada N metros de
## mundo) y el nombre de material; aqui se enganchan los mapas PBR que ya viven
## en `assets/textures/real/`, que son la UNICA fuente de esas imagenes.
##
## Por que asi: antes el .glb pesaba 9,77 MB porque embebia 12 imagenes, seis de
## ellas copias byte a byte de las del repo. Ahora el .glb son 2,8 MB de
## geometria pura y no hay ni un byte de textura duplicado.
##
## El material de cada grupo trae escrita la escala con la que se construyo su
## UV (`metros_por_tile`), asi que aqui no se recalibra nada: se sustituye el
## mapa y se deja el UV como vino.

## Nombre del MATERIAL del .glb -> mapas del repo. Las claves son exactamente
## los nombres que exporta `tools/build_range_shell.py`. Son dependencia de
## produccion: un nombre o textura que no resuelva aborta el arranque; no existe
## un color plano de reserva. Los tres canales son albedo / roughness / normal.
## La escala de UV NO se toca: viaja horneada en la malla.
const MAPS := {
    "Range_Concrete_Floor": {
        "albedo": "res://assets/textures/real/concrete_brushed_concrete_diff.jpg",
        "rough": "res://assets/textures/real/concrete_brushed_concrete_rough.jpg",
        "normal": "res://assets/textures/real/concrete_brushed_concrete_nor_gl.jpg",
        "color": Color(0.78, 0.78, 0.78),
        "metallic": 0.0,
        "roughness": 0.65,
        "normal_scale": 0.46,
    },
    "Range_Concrete_Brushed": {
        "albedo": "res://assets/textures/real/concrete_brushed_concrete_diff.jpg",
        "rough": "res://assets/textures/real/concrete_brushed_concrete_rough.jpg",
        "normal": "res://assets/textures/real/concrete_brushed_concrete_nor_gl.jpg",
        "color": Color(0.78, 0.77, 0.75),
        "metallic": 0.0,
        "roughness": 0.72,
        "normal_scale": 0.48,
    },
    "Range_Concrete_Wall": {
        "albedo": "res://assets/textures/real/concrete_concrete_diff.jpg",
        "rough": "res://assets/textures/real/concrete_concrete_rough.jpg",
        "normal": "res://assets/textures/real/concrete_concrete_nor_gl.jpg",
        "color": Color(0.76, 0.76, 0.78),
        "metallic": 0.0,
        "roughness": 0.78,
        "normal_scale": 0.52,
    },
    "Range_Painted_Metal": {
        "albedo": "res://assets/textures/real/metal_metal_plate_diff.jpg",
        "rough": "res://assets/textures/real/metal_metal_plate_rough.jpg",
        "normal": "res://assets/textures/real/metal_metal_plate_nor_gl.jpg",
        "color": Color(0.34, 0.36, 0.40),
        "metallic": 0.58,
        "roughness": 0.44,
        "normal_scale": 0.68,
    },
    "Range_Oak_Trim": {
        "albedo": "res://assets/textures/real/wood_oak_wood_planks_diff.jpg",
        "rough": "res://assets/textures/real/wood_oak_wood_planks_rough.jpg",
        "normal": "res://assets/textures/real/wood_oak_wood_planks_nor_gl.jpg",
        "color": Color(0.72, 0.58, 0.42),
        "metallic": 0.0,
        "roughness": 0.64,
        "normal_scale": 0.82,
    },
    "Range_Markings": {
        "albedo": "",
        "rough": "",
        "normal": "",
        "color": Color(0.88, 0.80, 0.50),
        "metallic": 0.0,
        "roughness": 0.55,
    },
}

## El difusor de las luminarias es la unica superficie emisiva del shell. Las
## luces reales viven en la escena (`Lighting`), que es quien decide cuantas
## hay y cuales proyectan sombra.
const LUMINAIRE_MATERIAL := "Range_Luminaire"

## Halo local de luminaria (aditivo, runtime, FUERA de Visual).
##
## Problema medido antes del cambio: el canto del difusor caia de 255 a 27 en
## <=5 px (gradiente max 177-243 px segun encuadre) = una pegatina plana sin
## derrame sobre la carcasa ni sobre el techo. El glow global esta descartado
## por coste (≈3 ms, ver 77907ef/be28ea3), asi que el derrame se dibuja como
## GEOMETRIA local: un quad aditivo por difusor, generado en runtime a partir
## de las propias cajas Range_Luminaire del GLB (autoridad unica =
## tools/build_range_shell.py; sin rebuild de Blender y sin tocar el bake de
## LightmapGI, que solo ve nodos del editor).
##
## Resultado A/B medido (preset lamp de tools/shot.gd, frames f_00050ms):
## arista max del difusor derecho 240 -> 198/px y del izquierdo 235 -> 129/px;
## la banda de carcasa pasa de 10-19 a 94-167 con caida suave; costillas
## intactas (px 204-206 en la cara: 303 -> 332); media +1,14% lamp / +1,41%
## downrange (guarda +/-2%) y >210 +1,15% / +2,00%.
##
## La textura es alfa 0 SOBRE la cara del difusor: si el halo tapara las
## costillas del prismatico, la lectura E3 (celda 255 vs costilla 205 = 50
## niveles) se lavaria (205 + add lineal -> 232 -> 23 niveles). Fuera de la
## cara: PEAK constante sobre el aro de carcasa (0,08/0,03 m) y caida smoothstep
## a 0 en el borde del quad.
##
## PEAK y GAP van calibrados contra el pipeline medido, no a ojo:
##  - tonemap ACES + tonemap_exposure 2.8 (Main.tscn): un add de 0,18 lineal
##    salia como +186 sRGB (carcasa 10 -> 196 = silhouette blanca, A/B medido);
##    0,08 pone el aro de carcasa en ~160 sin fundir la silueta.
##  - el quad cuelga solo 1,5 mm bajo el difusor (HALO_GAP): el cruce del rayo
##    que sale de la cara se desplaza ~4 mm, de modo que la zona alfa0 (que
##    protege las costillas) sigue el borde real de la cara casi al pixel. Con
##    10 mm el cruce se desplazaria ~3 cm y la banda de costillas del borde
##    caeria en PEAK. Planos paralelos separados no pelean z-buffer, asi que el
##    hueco puede ser minimo.
const HALO_PEAK := 0.08
const HALO_GAP := 0.0015
const HALO_TEX_SIZE := 64
## Geometria del accesorio (autoridad = tools/build_range_shell.py): difusor
## 1,74 x 0,24 y carcasa 1,90 x 0,30. Los umbrales de la textura se DERIVAN de
## estas medidas y del alcance, asi que no se desincronizan al cambiarlo.
const LUM_DIFF_LONG_HALF := 0.87
const LUM_DIFF_SHORT_HALF := 0.12
const LUM_HOUSE_LONG_HALF := 0.95
const LUM_HOUSE_SHORT_HALF := 0.15
## 0,50/0,34 y no 0,32/0,18: en A/B medido el quad se cortaba antes de las
## caras altas de las tapas de carcasa (el paralaje desplaza el cruce del rayo
## 0,31 m hacia la camara: la tapa exige 1,317 m de semialcance, que solo dan
## 0,50), dejando aristas de 236-240/px identicas a base. La caida gana
## anchura (0,42/0,31 m): derrame mas gradual, no mas alto (la guarda de
## media +/-2% y >210 se re-miden en cada A/B).
const HALO_REACH_LONG := 0.50   # 0,08 de cara de carcasa + 0,42 de caida
const HALO_REACH_SHORT := 0.34  # 0,03 de cara de carcasa + 0,31 de caida

var _cache: Dictionary = {}


func _ready() -> void:
    if not _rebind(find_children("*", "MeshInstance3D", true, false)):
        push_error("RangeShell no pudo enlazar todos sus materiales PBR obligatorios")
        get_tree().quit(1)
        return
    var lighting := get_node_or_null("Lighting")
    if lighting != null:
        for light in lighting.find_children("*", "Light3D", true, false):
            (light as Light3D).light_cull_mask = 4095
            # Son fuentes de AUTORIA del LightmapGI. Permanecen visibles en el
            # editor para poder rehornear, pero en juego el shell usa el bake:
            # volver a evaluarlas por pixel duplicaría la misma iluminación.
            if not Engine.is_editor_hint():
                (light as Light3D).visible = false
    _build_luminaire_halo()


func _rebind(nodes: Array) -> bool:
    var rebound := 0
    var valid := true
    for node in nodes:
        var mi := node as MeshInstance3D
        if mi == null or mi.mesh == null:
            push_error("RangeShell contiene un MeshInstance3D sin malla")
            valid = false
            continue
        var key := ""
        for surface in range(mi.mesh.get_surface_count()):
            var source := mi.mesh.surface_get_material(surface)
            if source != null and source.resource_name != "":
                key = source.resource_name
                break
        if key == "":
            push_error("RangeShell contiene una malla sin nombre de material")
            valid = false
            continue
        var mat := _material(key)
        if mat == null:
            push_error("RangeShell no reconoce o no puede cargar el material obligatorio: " + key)
            valid = false
            continue
        mi.material_override = mat
        rebound += 1
    print("RANGE shell: %d mallas con texturas externas del repo" % rebound)
    if rebound != nodes.size():
        valid = false
    return valid


func _material(group: String) -> Material:
    if _cache.has(group):
        return _cache[group]
    var mat: Material = null
    if group == LUMINAIRE_MATERIAL:
        mat = _luminaire()
    elif MAPS.has(group):
        mat = _pbr(MAPS[group])
    if mat != null:
        mat.resource_name = group
        _cache[group] = mat
    return mat


func _pbr(spec: Dictionary) -> StandardMaterial3D:
    var albedo: Texture2D = null
    var rough: Texture2D = null
    var normal: Texture2D = null
    if spec["albedo"] != "":
        albedo = load(spec["albedo"]) as Texture2D
        if albedo == null:
            push_error("RangeShell no pudo cargar albedo obligatorio: " + spec["albedo"])
            return null
    if spec["rough"] != "":
        rough = load(spec["rough"]) as Texture2D
        if rough == null:
            push_error("RangeShell no pudo cargar roughness obligatorio: " + spec["rough"])
            return null
    if spec["normal"] != "":
        normal = load(spec["normal"]) as Texture2D
        if normal == null:
            push_error("RangeShell no pudo cargar normal obligatorio: " + spec["normal"])
            return null

    var mat := StandardMaterial3D.new()
    mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    mat.albedo_color = spec["color"]
    mat.metallic = spec["metallic"]
    mat.roughness = spec["roughness"]
    if albedo != null:
        mat.albedo_texture = albedo
    if rough != null:
        mat.roughness_texture = rough
    if normal != null:
        mat.normal_enabled = true
        mat.normal_texture = normal
        mat.normal_scale = spec.get("normal_scale", 0.6)
    mat.uv1_scale = Vector3.ONE
    return mat


func _luminaire() -> StandardMaterial3D:
    ## Difusor prismatico: costillas sobre celda blanca en vez del rectangulo
    ## quemado SIN (255 std 0,16 = plano sin lectura). Evidencia de 9 probes +
    ## bisect E1/E2/E3:
    ##  - emission_energy_multiplier > 0 ROMPE el muestreo espacial del albedo
    ##    (probe8 gradiente+energy 0 = uv1 espacial correcto, span 1,0875 uv =
    ##    mundo/1,6 por caja; probe7 mismo gradiente+energy 0,64 = plano
    ##    t=0,56 constante). emission OFF: el brillo lo da albedo x lightmap
    ##    recortado; energy 0,64 queda documentado como el valor inerte.
    ##  - el PNG importado se muestrea LINEAL (t = byte/255): el pico del
    ##    hombro midio 220-225 = prediccion lineal (220), no la sRGB (192).
    ##  - irradiance L medida en los paneles: 0,773 (frio) a 1,084 (caliente).
    ##  - albedo_color es el unico boost y tiene techo: con (2.02,1.98,1.85)
    ##    un piso aditivo crece hasta empujar la costilla >=245 y el panel sale
    ##    UNIFORME (E2 = V2/V3 al pizarril: pct<245 = 4,7% = albedo puro con
    ##    cola de dips de L); con (1.19,1.17,1.10) = B1,3 las costillas salen
    ##    (E3: pct<245 = 38%, celdas 59% >=250, rib ~205, media 234,7):
    ##      celda      -> B1,3*1,004 = 1,17 -> 255 (recorte intacto)
    ##      celda fria -> 0,773*1,169 = 0,90 -> 246 (punch lejos)
    ##      costilla   -> ~205 (frio ~196) contra celda 255 = 50 niveles
    ##  - SIN mips (mipmaps/generate=false): los blobs decodificados del ctex
    ##    estan intactos (15x15 preserva {51,226,255}) pero el motor pide
    ##    mip4-5 en estos paneles (derivada uv anomala ~16-32 texel/px vs 0,38
    ##    calculados) y todo promedia a t=M (FIN/V2/V3 midieron min 138 = M,
    ##    95% >=250, sin costillas); probe9 sin mips dejo pct<245 = 48%. El
    ##    peor caso de minificacion real es ~4 texel/px (periodo 24 -> 7 px),
    ##    resoluble sin aliasing.
    ## Patron: assets/textures/real/diffuser_rib.png (procedural), uv1 =
    ## mundo/1,6, periodo 24 texels (5 por tile) = costilla cada 0,32 m,
    ## nucleo 8 texels (t=0,20) > bloque mip de 4, hombro 4 (t=0,769), celdas
    ## 12 (t=1). Resultado medido: media 234,7 vs SIN 254,97 por panel con
    ## std 31 (SIN 0,18) = lectura real donde antes no habia una.
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(1.19, 1.17, 1.10)
    mat.roughness = 0.28
    mat.emission_enabled = false
    mat.emission_energy_multiplier = 0.64
    mat.uv1_triplanar = false
    mat.uv1_scale = Vector3.ONE
    mat.uv1_offset = Vector3.ZERO
    mat.albedo_texture = preload("res://assets/textures/real/diffuser_rib.png")
    return mat


## Construye UNA malla con un quad aditivo por difusor del shell. Se ejecuta en
## _ready tras _rebind (asi el halo nunca pasa por la rebind obligatoria de PBR)
## y como nodo FUERA de Visual (el check de carcasas, el lightmap y el
## presupuesto de mallas solo miran dentro de Visual).
func _build_luminaire_halo() -> void:
    var pts := PackedVector3Array()
    for node in find_children("*", "MeshInstance3D", true, false):
        var mi := node as MeshInstance3D
        if mi == null or mi.mesh == null or mi.material_override == null:
            continue
        if mi.material_override.resource_name != LUMINAIRE_MATERIAL:
            continue
        for surface in mi.mesh.get_surface_count():
            var verts: PackedVector3Array = \
                mi.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
            for v in verts:
                pts.append(mi.to_global(v))
    if pts.is_empty():
        push_error("RangeShell: sin difusores Range_Luminaire de donde derivar el halo")
        return
    var boxes := _fixture_boxes(pts)
    if boxes.is_empty():
        push_error("RangeShell: los vertices de difusor no forman ninguna caja valida")
        return

    var verts := PackedVector3Array()
    var norms := PackedVector3Array()
    var uvs := PackedVector2Array()
    var idx := PackedInt32Array()
    for box in boxes:
        var c: Vector3 = box["center"]
        var s: Vector3 = box["size"]
        # HALO_GAP: el quad cuelga 1,5 mm bajo la cara (justificacion en la
        # cabecera); alfa 0 aqui dentro protege las costillas del prismatico.
        var y := c.y - s.y * 0.5 - HALO_GAP
        var long_x := s.x >= s.z
        var hl: float = (s.x if long_x else s.z) * 0.5 + HALO_REACH_LONG
        var hs: float = (s.z if long_x else s.x) * 0.5 + HALO_REACH_SHORT
        var base := verts.size()
        for corner: Vector2 in [
            Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0),
        ]:
            # u recorre el EJE LARGO de la caja (la textura esta dibujada asi);
            # el eje largo es X en world salvo exportaciones exoticas de glTF.
            var u := corner.x * 2.0 - 1.0
            var v := corner.y * 2.0 - 1.0
            var px: float = c.x + (u * hl if long_x else v * hs)
            var pz: float = c.z + (v * hs if long_x else u * hl)
            verts.append(Vector3(px, y, pz))
            norms.append(Vector3(0.0, -1.0, 0.0))
            uvs.append(corner)
        idx.append_array(PackedInt32Array([
            base, base + 1, base + 2, base, base + 2, base + 3,
        ]))

    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = verts
    arrays[Mesh.ARRAY_NORMAL] = norms
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_INDEX] = idx
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

    var halo := MeshInstance3D.new()
    halo.name = "LuminaireHalo"
    halo.mesh = mesh
    halo.material_override = _halo_material()
    halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    halo.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
    add_child(halo)
    print("RANGE shell: halo aditivo en %d luminarias" % boxes.size())


## Los difusores son cajas de 1,74 x 0,24 x 0,035 m separadas 3,6 m por vano
## (eje Z en world) y 9,06 m entre columnas (eje X): dos pases de orden con
## cortes en 1,0 m y 4,0 m separan cada caja sin asumir signos. Cualquier
## agrupado que no mida como una caja individual se descarta (no se dibuja).
func _fixture_boxes(pts: PackedVector3Array) -> Array:
    var list := Array()
    for p in pts:
        list.append(p)
    list.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.z < b.z)
    var rows: Array = []
    var row: Array = [list[0]]
    for i in range(1, list.size()):
        if (list[i] as Vector3).z - (row.back() as Vector3).z > 1.0:
            rows.append(row)
            row = []
        row.append(list[i])
    rows.append(row)
    var boxes: Array = []
    for r in rows:
        r.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.x < b.x)
        var group: Array = [r[0]]
        for i in range(1, r.size()):
            if (r[i] as Vector3).x - (group.back() as Vector3).x > 4.0:
                _append_fixture_box(boxes, group)
                group = []
            group.append(r[i])
        _append_fixture_box(boxes, group)
    return boxes


func _append_fixture_box(boxes: Array, group: Array) -> void:
    if group.is_empty():
        return
    var bb := AABB(group[0] as Vector3, Vector3.ZERO)
    for i in range(1, group.size()):
        bb = bb.expand(group[i] as Vector3)
    # Individual valida: 1,74 x 0,24 (o al reves). Una union erronea mediria
    # >=3,36 en un eje horizontal y un fragmento romperia la altura de caja.
    if bb.size.x > 2.2 or bb.size.z > 2.2 or bb.size.y > 0.2:
        return
    boxes.append({"center": bb.get_center(), "size": bb.size})


## Textura 64x64 procedural (sin PNG nuevo): alfa 0 sobre la cara del difusor,
## PEAK sobre el aro de carcasa, smoothstep a 0 en el borde del quad. Mips
## porque el patron es de baja frecuencia (no repite el caso del difusor, donde
## los mips lavaban las costillas).
func _halo_material() -> StandardMaterial3D:
    # Fronteras en unidades normalizadas del quad (medio quad = difusor/2 +
    # alcance): alfa0 hasta la cara del difusor; PEAK desde ahi hasta el aro de
    # carcasa; caida smoothstep a 0 en el borde del quad.
    var q_long := LUM_DIFF_LONG_HALF + HALO_REACH_LONG
    var q_short := LUM_DIFF_SHORT_HALF + HALO_REACH_SHORT
    var au_edge := LUM_DIFF_LONG_HALF / q_long
    var av_edge := LUM_DIFF_SHORT_HALF / q_short
    var tl_fall := (LUM_HOUSE_LONG_HALF / q_long - au_edge) / (1.0 - au_edge)
    var tv_fall := (LUM_HOUSE_SHORT_HALF / q_short - av_edge) / (1.0 - av_edge)
    var img := Image.create(HALO_TEX_SIZE, HALO_TEX_SIZE, false, Image.FORMAT_RGBA8)
    for y in HALO_TEX_SIZE:
        for x in HALO_TEX_SIZE:
            var au := absf(((x + 0.5) / HALO_TEX_SIZE) * 2.0 - 1.0)
            var av := absf(((y + 0.5) / HALO_TEX_SIZE) * 2.0 - 1.0)
            var a := 0.0
            if au > au_edge or av > av_edge:
                var tl := clampf((au - au_edge) / (1.0 - au_edge), 0.0, 1.0)
                var tv := clampf((av - av_edge) / (1.0 - av_edge), 0.0, 1.0)
                a = HALO_PEAK * (1.0 - maxf(
                    smoothstep(tl_fall, 1.0, tl), smoothstep(tv_fall, 1.0, tv)))
            img.set_pixel(x, y, Color(1.0, 0.97, 0.90, a))
    img.generate_mipmaps()
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    mat.albedo_texture = ImageTexture.create_from_image(img)
    mat.resource_name = "LuminaireHalo"
    return mat
