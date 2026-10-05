@tool
extends EditorScenePostImport

const SURFACES := {
	"pine": {"surface": "pine", "penetrable": true, "thin_shell": true, "wall_thickness": 0.12},
	"wood": {"surface": "pine", "penetrable": true},
	"paper": {"surface": "paper", "penetrable": true},
	"barrel": {"surface": "steel", "penetrable": true, "thin_shell": true, "wall_thickness": 0.0012},
	"rack": {"surface": "steel", "penetrable": true, "thin_shell": true, "wall_thickness": 0.002},
	"steel": {"surface": "steel"},
	"concrete": {"surface": "concrete"},
	"deck": {"surface": "pine", "step": "wood"},
}
const EMITTERS := ["sky_", "lamp_"]


func _post_import(scene: Node) -> Object:
	for body: StaticBody3D in scene.find_children("*", "StaticBody3D", true, false):
		var spec: Dictionary = SURFACES.get(String(body.name).get_slice("_", 0), {})
		if spec.is_empty():
			push_error("Colisionador sin superficie conocida: " + body.name)
		for key in spec:
			body.set_meta(key, spec[key])
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i) as BaseMaterial3D
			if mat != null:
				mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		for prefix in EMITTERS:
			if String(mi.name).begins_with(prefix):
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_occluders(scene)
	return scene


func _occluders(scene: Node) -> void:
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	for body: StaticBody3D in scene.find_children("pine_*", "StaticBody3D", true, false):
		for cs: CollisionShape3D in body.find_children("*", "CollisionShape3D", false, false):
			var hull := cs.shape as ConvexPolygonShape3D
			if hull == null:
				continue
			var xf := (body.transform * cs.transform)
			var box := AABB(hull.points[0], Vector3.ZERO)
			for p in hull.points:
				box = box.expand(p)
			var thin := 0 if box.size.x < box.size.z else 2
			var c := box.get_center()
			var u := Vector3.ZERO
			u[2 - thin] = box.size[2 - thin] * 0.5
			var v := Vector3(0, box.size.y * 0.5, 0)
			var i := verts.size()
			for corner in [c - u - v, c + u - v, c + u + v, c - u + v]:
				verts.append(xf * corner)
			idx.append_array([i, i + 1, i + 2, i, i + 2, i + 3, i, i + 2, i + 1, i, i + 3, i + 2])
	var occ := ArrayOccluder3D.new()
	occ.set_arrays(verts, idx)
	var inst := OccluderInstance3D.new()
	inst.name = "Occluders"
	inst.occluder = occ
	scene.add_child(inst)
	inst.owner = scene
