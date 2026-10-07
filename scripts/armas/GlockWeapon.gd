class_name GlockWeapon
extends WeaponModel

const MODEL := "res://assets/models/g19_pistol.glb"
const MAP_BASE_COLOR := "res://assets/models/g19_pistol_Image_3.png"
const MAP_ORM := "res://assets/models/g19_pistol_Image_4.png"
const MAP_NORMAL := "res://assets/models/g19_pistol_Image_6.png"
const ASSET_LENGTH_M := 0.174
const SLIDE_TRAVEL := 0.039
const MAG_CAPACITY := 15
const TRIGGER_TRAVEL := 0.0125
const BARREL_DROP := 0.026
const BARREL_LOCK_TRAVEL := 0.004
const SIDE_AXIS := Vector3(1.0, 0.0, 0.0)

var barrel: Node3D

var _slide_rest := Vector3.ZERO
var _barrel_rest := Vector3.ZERO
var cartridge: Node3D
var _trigger_rest_basis := Basis.IDENTITY
var _trigger_lever := 0.0
var _barrel_rest_basis := Basis.IDENTITY
var _slide_travel := 0.0


func build() -> bool:
	var packed := load(MODEL) as PackedScene
	if packed == null:
		push_error("No se pudo cargar el GLB canonico: " + MODEL)
		return false
	var root := packed.instantiate()
	add_child(root)

	frame = _find_child(root, "Frame")
	slide = _find_child(root, "Slide")
	magazine = _find_child(root, "Magazine")
	trigger = _find_child(root, "Trigger")
	barrel = _find_child(root, "Barrel")
	muzzle = _find_child(root, "Muzzle")
	ejection_port = _find_child(root, "EjectionPort")
	sight_rear = _find_child(root, "SightRear")
	sight_front = _find_child(root, "SightFront")
	grip = _find_child(root, "Grip")
	magwell = _find_child(root, "Magwell")
	var missing: Array[String] = []
	for pair in [["Frame", frame], ["Slide", slide], ["Barrel", barrel], ["Trigger", trigger],
			["Magazine", magazine], ["Muzzle", muzzle], ["EjectionPort", ejection_port],
			["SightRear", sight_rear], ["SightFront", sight_front], ["Grip", grip], ["Magwell", magwell]]:
		if pair[1] == null:
			missing.append(pair[0])
	if not missing.is_empty():
		push_error("GLB de Glock roto: faltan piezas obligatorias " + ", ".join(missing))
		return false
	if muzzle.get_parent() != barrel:
		push_error("GLB de Glock roto: Muzzle debe colgar de Barrel")
		return false
	if grip.get_parent() != frame or magwell.get_parent() != frame:
		push_error("GLB de Glock roto: Grip y Magwell deben colgar de Frame")
		return false
	if ejection_port.get_parent() != slide or sight_rear.get_parent() != slide or sight_front.get_parent() != slide:
		push_error("GLB de Glock roto: puerto y miras deben colgar de Slide")
		return false

	slide_offset = SLIDE_TRAVEL
	capacity = MAG_CAPACITY
	_slide_rest = slide.position
	_barrel_rest = barrel.position
	_remember_magazine()
	_trigger_rest_basis = trigger.transform.basis
	_barrel_rest_basis = barrel.transform.basis

	var measured_length := _model_length(root)
	if measured_length <= 0.0:
		push_error("GLB de Glock roto: no contiene geometria medible")
		return false
	if absf(measured_length - ASSET_LENGTH_M) > 0.003:
		push_error("GLB de Glock fuera de contrato: largo %.1f mm, esperado %.1f mm" % [measured_length * 1000.0, ASSET_LENGTH_M * 1000.0])
		return false
	model_scale = 1.0
	scale = Vector3.ONE
	_trigger_lever = _lever(trigger)
	if _trigger_lever <= 0.0:
		push_error("GLB de Glock roto: Trigger no tiene brazo de palanca medible")
		return false
	_slide_travel = SLIDE_TRAVEL / model_scale
	_bind_materials(root)
	if not _build_mag_round():
		return false
	if not _build_cartridge():
		return false

	print("ARMA Glock 19 escala=", snappedf(model_scale, 0.0001),
		" largo_modelo_m=", snappedf(measured_length, 0.001),
		" corredera=", snappedf(SLIDE_TRAVEL * 1000.0, 0.1), "mm",
		" gatillo=", snappedf(TRIGGER_TRAVEL / _trigger_lever * 57.2958, 0.1), "grados",
		" piezas=Frame/Slide/Barrel/Trigger/Magazine + 6 sockets")
	return true


func _build_cartridge() -> bool:
	assert(barrel != null and muzzle != null)
	cartridge = Node3D.new()
	cartridge.name = "Cartridge"
	barrel.add_child(cartridge)
	var bore := (muzzle.basis * muzzle_axis).normalized()
	var right: Vector3 = bore.cross(Vector3.UP)
	if right.length() < 0.01:
		push_error("GLB de Glock roto: el eje del anima no permite construir el cartucho")
		return false
	right = right.normalized()
	cartridge.basis = Basis(right, bore, right.cross(bore))
	var breech_face = RoundMesh.breech_face(barrel, bore, muzzle.position, cartridge)
	if breech_face == null:
		return false
	cartridge.position = breech_face
	RoundMesh.build(cartridge, "9mm")
	cartridge.visible = false
	return true


func _build_mag_round() -> bool:
	assert(magazine != null)
	mag_round = Node3D.new()
	mag_round.name = "MagRound"
	magazine.add_child(mag_round)
	var nose := Vector3(0.0, 0.0, -1.0)
	var right := nose.cross(Vector3.UP)
	mag_round.basis = Basis(right, nose, right.cross(nose))
	mag_round.position = Vector3(-0.020, -0.010, 0.030)
	RoundMesh.build(mag_round, "9mm")
	return true


func set_chamber_visible(v: bool) -> void:
	assert(cartridge != null, "Glock requiere cartucho construido")
	cartridge.visible = v


func _bind_materials(root: Node) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(MAP_BASE_COLOR)
	mat.roughness_texture = load(MAP_ORM)
	mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	mat.metallic_texture = load(MAP_ORM)
	mat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	mat.metallic = 0.5
	mat.rim_enabled = true
	mat.rim = 0.25
	mat.rim_tint = 0.4
	mat.normal_enabled = true
	mat.normal_texture = load(MAP_NORMAL)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	for node in root.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = mat


func _model_length(root: Node) -> float:
	var box := _mesh_aabb(root)
	return maxf(box.size.x, maxf(box.size.y, box.size.z))


func _mesh_aabb(root: Node) -> AABB:
	var box := AABB()
	var first := true
	var inverse := (root as Node3D).global_transform.affine_inverse()
	var stack: Array = [root]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			var local_box: AABB = (inverse * (n as Node3D).global_transform) * (n as MeshInstance3D).mesh.get_aabb()
			box = local_box if first else box.merge(local_box)
			first = false
		for c in n.get_children():
			stack.append(c)
	return box


func set_slide(t: float) -> void:
	assert(slide != null, "Glock requiere Slide")
	var amount := clampf(t, 0.0, 1.0)
	slide.position = _slide_rest - muzzle_axis * (_slide_travel * amount)
	var slide_m := SLIDE_TRAVEL * amount
	var joint_m := minf(slide_m, BARREL_LOCK_TRAVEL)
	barrel.position = _barrel_rest - muzzle_axis * (joint_m / model_scale)
	var unlock := clampf((slide_m - BARREL_LOCK_TRAVEL) / (SLIDE_TRAVEL - BARREL_LOCK_TRAVEL), 0.0, 1.0)
	barrel.transform.basis = Basis(Quaternion(SIDE_AXIS, -BARREL_DROP * unlock)) * _barrel_rest_basis


func _lever(part: Node3D) -> float:
	var radius := 0.0
	var pivot: Vector3 = part.global_transform.origin
	var stack: Array = [part]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			var mesh_instance: MeshInstance3D = n as MeshInstance3D
			var mesh: Mesh = mesh_instance.mesh
			for s in range(mesh.get_surface_count()):
				var vertices: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
				for v: Vector3 in vertices:
					var rel: Vector3 = (mesh_instance.global_transform * v) - pivot
					var perp := Vector2(rel.y, rel.z).length()
					radius = maxf(radius, perp)
		for c in n.get_children():
			stack.append(c)
	return radius


func set_trigger(t: float) -> void:
	assert(trigger != null, "Glock requiere Trigger")
	var angle := -(TRIGGER_TRAVEL / _trigger_lever) * clampf(t, 0.0, 1.0)
	trigger.transform.basis = Basis(Quaternion(SIDE_AXIS, angle)) * _trigger_rest_basis
