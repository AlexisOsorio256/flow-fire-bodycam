class_name WeaponModel
extends Node3D

const MUZZLE_AXIS := Vector3(0.0, 0.0, -1.0)
const MAGAZINE_OUT_AXIS := Vector3(0.0, -1.0, 0.0)

var slide_offset := 0.0
var capacity := 0
var muzzle_axis := MUZZLE_AXIS
var model_scale := 1.0
var by_hand := false

var frame: Node3D
var slide: Node3D
var trigger: Node3D
var magazine: Node3D
var muzzle: Node3D
var ejection_port: Node3D
var sight_rear: Node3D
var sight_front: Node3D
var grip: Node3D
var magwell: Node3D
var mag_round: Node3D
var magazine_rest := Vector3.ZERO
var _magazine_rest_basis := Basis()


func build() -> bool:
	return false


func set_slide(_t: float) -> void:
	pass


func set_trigger(_t: float) -> void:
	pass


func set_chamber_visible(_v: bool) -> void:
	pass


func grip_pivot() -> Vector3:
	return (global_transform.affine_inverse() * grip.global_position) * model_scale


func set_magazine_attached(attached: bool) -> void:
	magazine.visible = attached


func seat_magazine() -> void:
	magazine.position = magazine_rest
	magazine.transform.basis = _magazine_rest_basis


func magazine_out_axis() -> Vector3:
	return (global_transform.basis * MAGAZINE_OUT_AXIS).normalized()


func _remember_magazine() -> void:
	magazine_rest = magazine.position
	_magazine_rest_basis = magazine.transform.basis


func _find_child(root: Node, node_name: String) -> Node3D:
	if root.name == node_name and root is Node3D:
		return root as Node3D
	for c in root.get_children():
		var r := _find_child(c, node_name)
		if r != null:
			return r
	return null
