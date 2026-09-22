extends SceneTree
## Sonda headless: imprime los UV1/UV2 reales de la malla de luminarias
## del shell para comprobar el mapeo del difusor (span, orientacion, fase).


func _init() -> void:
    var packed := load("res://assets/models/range_shell.glb") as PackedScene
    if packed == null:
        print("UV_PROBE FALLO cargar glb")
        quit(1)
        return
    _walk(packed.instantiate())
    quit(0)


func _walk(node: Node) -> void:
    if node is MeshInstance3D and "luminaire" in node.name.to_lower():
        var mesh: Mesh = (node as MeshInstance3D).mesh
        for s in range(mesh.get_surface_count()):
            var mat_name := "(sin material)"
            var sm := mesh.surface_get_material(s)
            if sm != null:
                mat_name = sm.resource_name
            var arrays := mesh.surface_get_arrays(s)
            var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
            var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
            if uvs.is_empty():
                print("UV_PROBE %s surf=%d mat=%s SIN_UV1" % [node.name, s, mat_name])
                continue
            var mn := Vector2(1e18, 1e18)
            var mx := Vector2(-1e18, -1e18)
            for uv in uvs:
                mn = Vector2(minf(mn.x, uv.x), minf(mn.y, uv.y))
                mx = Vector2(maxf(mx.x, uv.x), maxf(mx.y, uv.y))
            var linea := "UV_PROBE %s surf=%d mat=%s n=%d u:[%.4f,%.4f] v:[%.4f,%.4f] span=(%.4f,%.4f)" % [
                node.name, s, mat_name, uvs.size(), mn.x, mx.x, mn.y, mx.y,
                mx.x - mn.x, mx.y - mn.y]
            if not uv2.is_empty():
                var mn2 := Vector2(1e18, 1e18)
                var mx2 := Vector2(-1e18, -1e18)
                for uv in uv2:
                    mn2 = Vector2(minf(mn2.x, uv.x), minf(mn2.y, uv.y))
                    mx2 = Vector2(maxf(mx2.x, uv.x), maxf(mx2.y, uv.y))
                linea += "  UV2 u:[%.4f,%.4f] v:[%.4f,%.4f]" % [mn2.x, mx2.x, mn2.y, mx2.y]
            print(linea)
    for c in node.get_children():
        _walk(c)
