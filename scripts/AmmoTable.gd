class_name AmmoTable
extends Node3D

const MAX_MAGS := 4
const MAG_ROUNDS := 15
const REGEN_S := 6.0
const TOP := Vector3(0.7, 0.05, 0.5)
const TOP_Y := 0.75
const LEG := Vector3(0.05, 0.75, 0.05)
const REACH := 1.6

var mags := MAX_MAGS
var _regen := 0.0
var _multimeshes: Array[MultiMesh] = []
var _wired := false


func _ready() -> void:
	var wood := StandardMaterial3D.new()
	wood.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	wood.albedo_texture = preload("res://assets/textures/map/osb_diff.jpg")
	wood.albedo_color = Color(0.48, 0.44, 0.40)
	wood.roughness_texture = preload("res://assets/textures/map/osb_rough.jpg")
	wood.normal_enabled = true
	wood.normal_texture = preload("res://assets/textures/map/osb_nor_gl.jpg")
	wood.normal_scale = 0.6
	wood.roughness = 0.75
	wood.uv1_scale = Vector3(1.5, 1.0, 1.5)

	var body := StaticBody3D.new()
	body.name = "Table"
	body.set_meta("surface", "pine")
	add_child(body)
	var top := MeshInstance3D.new()
	var top_mesh := BoxMesh.new()
	top_mesh.size = TOP
	top_mesh.material = wood
	top.mesh = top_mesh
	top.position = Vector3(0, TOP_Y, 0)
	body.add_child(top)
	var top_col := CollisionShape3D.new()
	var top_shape := BoxShape3D.new()
	top_shape.size = TOP
	top_col.shape = top_shape
	top_col.position = Vector3(0, TOP_Y, 0)
	body.add_child(top_col)

	var legs := MultiMesh.new()
	legs.transform_format = MultiMesh.TRANSFORM_3D
	var leg_mesh := BoxMesh.new()
	leg_mesh.size = LEG
	leg_mesh.material = wood
	legs.mesh = leg_mesh
	legs.instance_count = 4
	var blobs := ContactBlob.new()
	var i := 0
	for leg_x in [-0.3, 0.3]:
		for leg_z in [-0.2, 0.2]:
			legs.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(leg_x, LEG.y * 0.5, leg_z)))
			blobs.add(leg_x, leg_z, 0.025, 0.025)
			i += 1
	var leg_inst := MultiMeshInstance3D.new()
	leg_inst.multimesh = legs
	body.add_child(leg_inst)
	var blob_mesh := blobs.build()
	if blob_mesh != null:
		add_child(blob_mesh)

	var mag_mat := StandardMaterial3D.new()
	mag_mat.albedo_color = Color(0.12, 0.12, 0.14)
	mag_mat.metallic = 0.6
	mag_mat.roughness = 0.45
	for piece in [
		[Vector3(0.026, 0.098, 0.037), Vector3.ZERO],
		[Vector3(0.030, 0.012, 0.044), Vector3(0.0, -0.053, 0.002)],
		[Vector3(0.022, 0.012, 0.032), Vector3(0.0, 0.053, -0.004)],
	]:
		var box := BoxMesh.new()
		box.size = piece[0] as Vector3
		box.material = mag_mat
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = box
		mm.instance_count = MAX_MAGS
		mm.visible_instance_count = mags
		for k in MAX_MAGS:
			var mag_xf := Transform3D(Basis(Vector3(0, 0, 1), deg_to_rad(-8.0)),
				Vector3(-0.21 + k * 0.14, TOP_Y + 0.095, 0.0))
			mm.set_instance_transform(k, mag_xf * Transform3D(Basis.IDENTITY, piece[1] as Vector3))
		var inst := MultiMeshInstance3D.new()
		inst.multimesh = mm
		add_child(inst)
		_multimeshes.append(mm)


func _process(delta: float) -> void:
	if not _wired:
		var player := get_tree().get_first_node_in_group("player")
		if player != null:
			if player.get("ammo") == null:
				player.set("ammo", self)
			_wired = true
	if mags >= MAX_MAGS:
		_regen = 0.0
		return
	_regen += delta
	if _regen >= REGEN_S:
		_regen = 0.0
		mags += 1
		_refresh()


func refill() -> void:
	mags = MAX_MAGS
	_regen = 0.0
	_refresh()


func can_take(from: Vector3) -> bool:
	return mags > 0 and from.distance_to(global_position) <= REACH


func consume() -> int:
	if mags <= 0:
		return 0
	mags -= 1
	_regen = 0.0
	_refresh()
	return MAG_ROUNDS


func _refresh() -> void:
	for mm in _multimeshes:
		mm.visible_instance_count = mags
