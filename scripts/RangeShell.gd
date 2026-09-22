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
