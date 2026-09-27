"""Genera el mapa de combate de FlowFire en Blender: búnker derruido de 5 estancias.

Uso:
    blender --background --python tools/build_combat_map.py

Diseño:
    5 estancias interconectadas inspiradas en el video de referencia:
    1. Entrada / brecha exterior (Z: 8 a 4)
    2. Pasillo de estrangulamiento con esquinas irregulares (Z: 4 a 0)
    3. Búnker interior oscuro con aspillera (Z: 0 a -5, izquierda)
    4. Puesto de guardia fortificado con madera/metal (Z: 0 a -5, derecha)
    5. Sala de brecha trasera con escombros (Z: -5 a -9)

Materiales compartidos con el repo, UVs en espacio de mundo con texel density real.
Mallas unidas por material para mantener draw calls por debajo de 8.
"""

from __future__ import annotations
from pathlib import Path
import bpy
import bmesh
from mathutils import Vector, Matrix
import math

REPO = Path(__file__).resolve().parents[1]
MODELS = REPO / "assets" / "models"
TEXTURES = REPO / "assets" / "textures" / "real"

METROS_POR_TILE = {
    "concrete": 2.4,
    "wood": 1.2,
    "metal": 1.6,
    "plaster": 2.0,
}


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for datablocks in (
        bpy.data.meshes,
        bpy.data.curves,
        bpy.data.materials,
        bpy.data.cameras,
        bpy.data.lights,
        bpy.data.images,
    ):
        for datablock in list(datablocks):
            if datablock.users == 0:
                datablocks.remove(datablock)


def image(path: Path, non_color: bool = False):
    img = bpy.data.images.load(str(path), check_existing=True)
    if non_color:
        img.colorspace_settings.name = "Non-Color"
    return img


def create_material(name: str, albedo: Path, rough: Path, norm: Path, scale: float):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    output = nodes.new("ShaderNodeOutputMaterial")
    shader = nodes.new("ShaderNodeBsdfPrincipled")
    shader.inputs["Roughness"].default_value = 0.8
    links.new(shader.outputs["BSDF"], output.inputs["Surface"])

    def tiled(img_path: Path, non_color: bool):
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = image(img_path, non_color)
        mapping = nodes.new("ShaderNodeMapping")
        mapping.inputs["Scale"].default_value = (1.0 / scale, 1.0 / scale, 1.0 / scale)
        coords = nodes.new("ShaderNodeTexCoord")
        links.new(coords.outputs["UV"], mapping.inputs["Vector"])
        links.new(mapping.outputs["Vector"], tex.inputs["Vector"])
        return tex

    links.new(tiled(albedo, False).outputs["Color"], shader.inputs["Base Color"])
    links.new(tiled(rough, True).outputs["Color"], shader.inputs["Roughness"])
    normal_node = nodes.new("ShaderNodeNormalMap")
    normal_node.inputs["Strength"].default_value = 0.75
    links.new(tiled(norm, True).outputs["Color"], normal_node.inputs["Color"])
    links.new(normal_node.outputs["Normal"], shader.inputs["Normal"])
    return mat


def cube_project(obj, scale: float) -> None:
    matrix = obj.matrix_world
    mesh = obj.data
    bm = bmesh.new()
    bm.from_mesh(mesh)
    uv = bm.loops.layers.uv.verify()
    for face in bm.faces:
        world_normal = (matrix.to_3x3() @ face.normal)
        axis = max(range(3), key=lambda i: abs(world_normal[i]))
        for loop in face.loops:
            co = matrix @ loop.vert.co
            if axis == 0:
                u, v = co.y, co.z
            elif axis == 1:
                u, v = co.x, co.z
            else:
                u, v = co.x, co.y
            loop[uv].uv = (u / scale, v / scale)
    bm.to_mesh(mesh)
    bm.free()


def add_box(collection, name, center, size, mat, bevel=0.03):
    mesh = bpy.data.meshes.new(name)
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)

    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x = v.co.x * size.x + center.x
        v.co.y = v.co.y * size.y + center.y
        v.co.z = v.co.z * size.z + center.z
    if bevel > 0.001 and min(size.x, size.y, size.z) > bevel * 2.5:
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bevel, segments=1, profile=0.5)
    bm.to_mesh(mesh)
    bm.free()

    obj.data.materials.append(mat)
    return obj


def add_rubble_pile(collection, center: Vector, count: int, mat):
    import random
    rng = random.Random(42)
    objs = []
    for i in range(count):
        rx = center.x + rng.uniform(-0.8, 0.8)
        rz = center.z + rng.uniform(-0.8, 0.8)
        ry = center.y + rng.uniform(0.04, 0.16)
        sx = rng.uniform(0.18, 0.45)
        sy = rng.uniform(0.08, 0.22)
        sz = rng.uniform(0.18, 0.45)
        b = add_box(collection, f"Rubble_{i}", Vector((rx, ry, rz)), Vector((sx, sy, sz)), mat, bevel=0.02)
        b.rotation_euler = (rng.uniform(-0.3, 0.3), rng.uniform(-0.8, 0.8), rng.uniform(-0.3, 0.3))
        objs.append(b)
    return objs


def build_bunker():
    reset_scene()
    col = bpy.context.scene.collection

    # Materiales
    mat_concrete = create_material(
        "Mat_Concrete",
        TEXTURES / "concrete_concrete_diff.jpg",
        TEXTURES / "concrete_concrete_rough.jpg",
        TEXTURES / "concrete_concrete_nor_gl.jpg",
        METROS_POR_TILE["concrete"],
    )
    mat_wood = create_material(
        "Mat_Wood",
        TEXTURES / "wood_oak_wood_planks_diff.jpg",
        TEXTURES / "wood_oak_wood_planks_rough.jpg",
        TEXTURES / "wood_oak_wood_planks_nor_gl.jpg",
        METROS_POR_TILE["wood"],
    )
    mat_metal = create_material(
        "Mat_Metal",
        TEXTURES / "metal_metal_plate_diff.jpg",
        TEXTURES / "metal_metal_plate_rough.jpg",
        TEXTURES / "metal_metal_plate_nor_gl.jpg",
        METROS_POR_TILE["metal"],
    )

    concrete_objs = []
    wood_objs = []
    metal_objs = []

    # 1. SUELO Y TECHO
    # Suelo principal dividido por estancias con ligeros desniveles
    concrete_objs.append(add_box(col, "Floor_Entry", Vector((0.0, -0.1, 6.0)), Vector((7.0, 0.2, 5.0)), mat_concrete))
    concrete_objs.append(add_box(col, "Floor_Choke", Vector((0.0, -0.08, 2.0)), Vector((5.0, 0.24, 4.0)), mat_concrete))
    concrete_objs.append(add_box(col, "Floor_Vault", Vector((-3.0, -0.06, -2.5)), Vector((6.0, 0.28, 5.5)), mat_concrete))
    concrete_objs.append(add_box(col, "Floor_Guard", Vector((3.0, -0.06, -2.5)), Vector((6.0, 0.28, 5.5)), mat_concrete))
    concrete_objs.append(add_box(col, "Floor_Exit", Vector((0.0, -0.1, -7.0)), Vector((7.0, 0.2, 4.0)), mat_concrete))

    # Techo con aberturas estratégicas para iluminación natural y siluetas
    concrete_objs.append(add_box(col, "Ceiling_Entry", Vector((0.0, 3.2, 6.0)), Vector((7.0, 0.3, 5.0)), mat_concrete))
    concrete_objs.append(add_box(col, "Ceiling_Choke", Vector((0.0, 3.1, 2.0)), Vector((5.0, 0.3, 4.0)), mat_concrete))
    # Búnker interior oscuro con abertura de claraboya en Vault
    concrete_objs.append(add_box(col, "Ceiling_Vault_L", Vector((-4.2, 3.1, -2.5)), Vector((3.6, 0.3, 5.5)), mat_concrete))
    concrete_objs.append(add_box(col, "Ceiling_Vault_R", Vector((-1.0, 3.1, -2.5)), Vector((1.8, 0.3, 5.5)), mat_concrete))
    concrete_objs.append(add_box(col, "Ceiling_Guard", Vector((3.0, 3.1, -2.5)), Vector((6.0, 0.3, 5.5)), mat_concrete))
    concrete_objs.append(add_box(col, "Ceiling_Exit", Vector((0.0, 3.2, -7.0)), Vector((7.0, 0.3, 4.0)), mat_concrete))

    # 2. MUROS PERIMETRALES EXTERIORES
    # Muros Este y Oeste
    concrete_objs.append(add_box(col, "Wall_West_Entry", Vector((-3.5, 1.5, 6.0)), Vector((0.4, 3.2, 5.0)), mat_concrete))
    concrete_objs.append(add_box(col, "Wall_East_Entry", Vector((3.5, 1.5, 6.0)), Vector((0.4, 3.2, 5.0)), mat_concrete))
    concrete_objs.append(add_box(col, "Wall_West_Mid", Vector((-6.0, 1.5, -2.5)), Vector((0.4, 3.2, 5.5)), mat_concrete))
    concrete_objs.append(add_box(col, "Wall_East_Mid", Vector((6.0, 1.5, -2.5)), Vector((0.4, 3.2, 5.5)), mat_concrete))
    concrete_objs.append(add_box(col, "Wall_West_Exit", Vector((-3.5, 1.5, -7.0)), Vector((0.4, 3.2, 4.0)), mat_concrete))
    concrete_objs.append(add_box(col, "Wall_East_Exit", Vector((3.5, 1.5, -7.0)), Vector((0.4, 3.2, 4.0)), mat_concrete))

    # Muro Sur (detrás del spawn, entrada con brecha)
    concrete_objs.append(add_box(col, "Wall_South_L", Vector((-2.2, 1.5, 8.4)), Vector((3.0, 3.2, 0.4)), mat_concrete))
    concrete_objs.append(add_box(col, "Wall_South_R", Vector((2.2, 1.5, 8.4)), Vector((3.0, 3.2, 0.4)), mat_concrete))
    concrete_objs.append(add_box(col, "Wall_South_Top", Vector((0.0, 2.7, 8.4)), Vector((1.8, 0.8, 0.4)), mat_concrete))

    # Muro Norte (final con ventana/aspillera de luz exterior)
    concrete_objs.append(add_box(col, "Wall_North_L", Vector((-2.4, 1.5, -8.9)), Vector((2.6, 3.2, 0.4)), mat_concrete))
    concrete_objs.append(add_box(col, "Wall_North_R", Vector((2.4, 1.5, -8.9)), Vector((2.6, 3.2, 0.4)), mat_concrete))
    concrete_objs.append(add_box(col, "Wall_North_Bottom", Vector((0.0, 0.5, -8.9)), Vector((2.4, 1.0, 0.4)), mat_concrete))
    concrete_objs.append(add_box(col, "Wall_North_Top", Vector((0.0, 2.7, -8.9)), Vector((2.4, 0.8, 0.4)), mat_concrete))

    # 3. DIVISIONES INTERIORES, ESQUINAS Y COBERTURA (5 ESTANCIAS)
    # Partición entre Entrada y Pasillo de estrangulamiento (Z = 4.0)
    concrete_objs.append(add_box(col, "Part_Entry_L", Vector((-2.2, 1.5, 4.0)), Vector((3.0, 3.2, 0.35)), mat_concrete))
    concrete_objs.append(add_box(col, "Part_Entry_R", Vector((2.2, 1.5, 4.0)), Vector((3.0, 3.2, 0.35)), mat_concrete))
    concrete_objs.append(add_box(col, "Part_Entry_Lintel", Vector((0.0, 2.65, 4.0)), Vector((1.8, 0.7, 0.35)), mat_concrete))
    # Marco de viga de madera en la puerta de entrada
    wood_objs.append(add_box(col, "Frame_Entry_L", Vector((-0.85, 1.15, 4.0)), Vector((0.15, 2.3, 0.42)), mat_wood))
    wood_objs.append(add_box(col, "Frame_Entry_R", Vector((0.85, 1.15, 4.0)), Vector((0.15, 2.3, 0.42)), mat_wood))
    wood_objs.append(add_box(col, "Frame_Entry_Top", Vector((0.0, 2.25, 4.0)), Vector((1.7, 0.15, 0.42)), mat_wood))

    # Esquina táctica de estrangulamiento (Choke Z = 2.0 a 0.0)
    concrete_objs.append(add_box(col, "Choke_Pillar", Vector((-1.1, 1.5, 1.8)), Vector((0.6, 3.0, 0.6)), mat_concrete))
    concrete_objs.append(add_box(col, "Choke_Barrier", Vector((1.2, 0.55, 1.2)), Vector((1.8, 1.1, 0.35)), mat_concrete))

    # Muro divisor central entre Sala Oscura (Vault) y Puesto de Guardia (Z: 0 a -5, X = 0)
    concrete_objs.append(add_box(col, "Mid_Wall_North", Vector((0.0, 1.5, -4.0)), Vector((0.35, 3.0, 2.4)), mat_concrete))
    concrete_objs.append(add_box(col, "Mid_Wall_South", Vector((0.0, 1.5, -1.0)), Vector((0.35, 3.0, 2.2)), mat_concrete))
    # Paso entre bóveda y guardia (puerta Z = -2.4)
    concrete_objs.append(add_box(col, "Mid_Lintel", Vector((0.0, 2.65, -2.4)), Vector((0.35, 0.7, 1.4)), mat_concrete))

    # Muro entre Pasillo y Bóveda/Guardia (Z = 0.0)
    concrete_objs.append(add_box(col, "Wall_Trans_L", Vector((-3.8, 1.5, 0.0)), Vector((4.6, 3.0, 0.35)), mat_concrete))
    concrete_objs.append(add_box(col, "Wall_Trans_R", Vector((3.8, 1.5, 0.0)), Vector((4.6, 3.0, 0.35)), mat_concrete))
    concrete_objs.append(add_box(col, "Wall_Trans_Lintel", Vector((0.0, 2.7, 0.0)), Vector((1.8, 0.6, 0.35)), mat_concrete))

    # Muro divisorio hacia la Sala de Escape trasera (Z = -5.0)
    concrete_objs.append(add_box(col, "Wall_Exit_L", Vector((-3.4, 1.5, -5.0)), Vector((4.0, 3.0, 0.35)), mat_concrete))
    concrete_objs.append(add_box(col, "Wall_Exit_R", Vector((3.4, 1.5, -5.0)), Vector((4.0, 3.0, 0.35)), mat_concrete))
    concrete_objs.append(add_box(col, "Wall_Exit_Lintel", Vector((0.0, 2.65, -5.0)), Vector((2.8, 0.7, 0.35)), mat_concrete))

    # 4. ELEMENTOS DE COBERTURA, MADERA Y METAL (BARRICADAS Y VIGAS)
    # Refuerzos de vigas de metal en techo
    metal_objs.append(add_box(col, "Beam_Roof_1", Vector((0.0, 2.95, 4.0)), Vector((6.8, 0.22, 0.22)), mat_metal))
    metal_objs.append(add_box(col, "Beam_Roof_2", Vector((0.0, 2.95, 0.0)), Vector((11.6, 0.22, 0.22)), mat_metal))
    metal_objs.append(add_box(col, "Beam_Roof_3", Vector((0.0, 2.95, -5.0)), Vector((11.6, 0.22, 0.22)), mat_metal))

    # Barricada de metal y madera en Puesto de Guardia
    metal_objs.append(add_box(col, "Barricade_Metal_1", Vector((2.6, 0.55, -1.8)), Vector((1.4, 1.1, 0.06)), mat_metal))
    wood_objs.append(add_box(col, "Wood_Crate_1", Vector((4.2, 0.45, -3.8)), Vector((0.9, 0.9, 0.9)), mat_wood))
    wood_objs.append(add_box(col, "Wood_Crate_2", Vector((4.0, 1.2, -3.7)), Vector((0.7, 0.6, 0.7)), mat_wood))
    wood_objs.append(add_box(col, "Wood_Plank_Wall", Vector((-2.8, 0.6, -4.8)), Vector((1.8, 1.2, 0.08)), mat_wood))

    # Escombros y bloques derruidos
    concrete_objs.extend(add_rubble_pile(col, Vector((-1.8, 0.0, 3.6)), 5, mat_concrete))
    concrete_objs.extend(add_rubble_pile(col, Vector((1.4, 0.0, -0.6)), 6, mat_concrete))
    concrete_objs.extend(add_rubble_pile(col, Vector((-2.2, 0.0, -3.2)), 7, mat_concrete))
    concrete_objs.extend(add_rubble_pile(col, Vector((0.0, 0.0, -6.8)), 8, mat_concrete))

    # 5. UNION POR MATERIAL Y UV MAPPING
    bpy.context.view_layer.update()

    def merge_group(objs, name, mat, scale):
        if not objs:
            return None
        bpy.ops.object.select_all(action='DESELECT')
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        bpy.ops.object.join()
        merged = bpy.context.active_object
        merged.name = name
        merged.data.materials.clear()
        merged.data.materials.append(mat)
        cube_project(merged, scale)
        return merged

    mesh_concrete = merge_group(concrete_objs, "Bunker_Concrete", mat_concrete, METROS_POR_TILE["concrete"])
    mesh_wood = merge_group(wood_objs, "Bunker_Wood", mat_wood, METROS_POR_TILE["wood"])
    mesh_metal = merge_group(metal_objs, "Bunker_Metal", mat_metal, METROS_POR_TILE["metal"])

    # Exportacion a glTF/GLB
    MODELS.mkdir(parents=True, exist_ok=True)
    out_path = MODELS / "combat_bunker.glb"
    bpy.ops.object.select_all(action='DESELECT')
    for o in [mesh_concrete, mesh_wood, mesh_metal]:
        if o:
            o.select_set(True)

    bpy.ops.export_scene.gltf(
        filepath=str(out_path),
        use_selection=True,
        export_format="GLB",
        export_materials="EXPORT",
        export_yup=True,
    )
    print(f"BUNKER EXPORTADO CON EXITO: {out_path} ({out_path.stat().st_size / 1024:.1f} KB)")


if __name__ == "__main__":
    build_bunker()
