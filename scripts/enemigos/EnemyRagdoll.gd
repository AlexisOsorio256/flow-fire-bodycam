class_name EnemyRagdoll
extends RefCounted

const BODY_MASS := 78.0
const GRAVITY := 1.7
const TOPPLE_PUSH := 5.0
const PUSH := Vector2(12.0, 24.0)
const SLUMP := 0.2
const SETTLE_DELAY := 0.6
const SETTLE_TIME := 0.8
const SETTLE_DAMP := Vector2(25.0, 4.0)
const REST_AFTER := 2.2
const DAMP := Vector2(4.0, 0.4)
const THUD_POLL := 0.04
const FALLS := {
	"head": [0.15, 0.0, 0.0], "chest": [0.5, 0.3, -1.2], "belly": [0.5, 0.3, -0.8],
	"hips": [0.5, 0.4, -0.2], "arm": [0.2, 0.4, -0.5], "leg": [0.2, -0.5, 0.45],
}
const SPECS := {
	"Hips": ["Spine", 0.14, 0.15, 0.0, 0.0],
	"Spine": ["Chest", 0.14, 0.10, 20.0, 15.0],
	"Chest": ["Chest.001", 0.16, 0.10, 20.0, 15.0],
	"Chest.001": ["Neck", 0.17, 0.10, 15.0, 10.0],
	"Neck": ["Head", 0.06, 0.02, 25.0, 30.0],
	"Head": ["", 0.11, 0.06, 40.0, 50.0],
	"UpperArm_L": ["ForeArm_L", 0.06, 0.03, 80.0, 40.0],
	"UpperArm_R": ["ForeArm_R", 0.06, 0.03, 80.0, 40.0],
	"ForeArm_L": ["Hand_L", 0.05, 0.02, 75.0, 20.0],
	"ForeArm_R": ["Hand_R", 0.05, 0.02, 75.0, 20.0],
	"Hand_L": ["", 0.045, 0.01, 40.0, 20.0],
	"Hand_R": ["", 0.045, 0.01, 40.0, 20.0],
	"Thigh_L": ["Shin_L", 0.09, 0.10, 60.0, 20.0],
	"Thigh_R": ["Shin_R", 0.09, 0.10, 60.0, 20.0],
	"Shin_L": ["Foot_L", 0.065, 0.06, 70.0, 10.0],
	"Shin_R": ["Foot_R", 0.065, 0.06, 70.0, 10.0],
}


static func build(skeleton: Skeleton3D, actor: Node, layer: int) -> PhysicalBoneSimulator3D:
	var sim := PhysicalBoneSimulator3D.new()
	sim.name = "Ragdoll"
	skeleton.add_child(sim)
	for bone_name: String in SPECS:
		var i := skeleton.find_bone(bone_name)
		if i < 0:
			continue
		var spec: Array = SPECS[bone_name]
		var length := 0.12
		var child := skeleton.find_bone(spec[0]) if spec[0] != "" else -1
		if child >= 0:
			length = skeleton.get_bone_global_rest(child).origin.distance_to(skeleton.get_bone_global_rest(i).origin)
		sim.add_child(_bone(bone_name, spec, length, actor, layer))
	return sim


static func topple(sim: PhysicalBoneSimulator3D, bone: String, region: String, point: Vector3, dir: Vector3,
		impulse: float, momentum: Vector3) -> Vector3:
	var push := dir.normalized() * Impulse.push(impulse, TOPPLE_PUSH, PUSH.x, PUSH.y)
	var flat := Vector3(push.x, 0.0, push.z)
	var fall: Array = FALLS.get(region, FALLS["chest"])
	for pb: PhysicalBone3D in sim.get_children():
		pb.linear_velocity = momentum + Vector3.DOWN * SLUMP
		if pb.bone_name == bone:
			pb.apply_impulse(push, point - pb.global_position)
		elif pb.bone_name == "Hips":
			pb.apply_central_impulse(push * fall[0])
		elif pb.bone_name.begins_with("Shin"):
			pb.apply_central_impulse(-flat * fall[1] + Vector3.UP * maxf(0.0, -fall[1]) * flat.length() * 0.4)
		elif pb.bone_name == "Chest.001" or pb.bone_name == "Chest":
			pb.apply_central_impulse(-flat * fall[2])
	_settle(sim)
	return push


static func thud_on_landing(sim: PhysicalBoneSimulator3D, fell := false, left := 2.0) -> void:
	var hips: PhysicalBone3D = null
	for pb: PhysicalBone3D in sim.get_children():
		if pb.bone_name == "Hips":
			hips = pb
	if hips == null or left <= 0.0:
		return
	var vy := hips.linear_velocity.y
	if fell and vy > -0.3:
		GameAudio.play_3d("body_fall", hips.global_position, 0.0, randf_range(0.9, 1.05))
		return
	sim.get_tree().create_timer(THUD_POLL, false).timeout.connect(
		func() -> void: thud_on_landing(sim, fell or vy < -1.0, left - THUD_POLL) if is_instance_valid(sim) else null)


static func rest(sim: PhysicalBoneSimulator3D) -> void:
	for pb: PhysicalBone3D in sim.get_children():
		PhysicsServer3D.body_set_mode(pb.get_rid(), PhysicsServer3D.BODY_MODE_STATIC)


static func wake(sim: PhysicalBoneSimulator3D) -> void:
	for pb: PhysicalBone3D in sim.get_children():
		PhysicsServer3D.body_set_mode(pb.get_rid(), PhysicsServer3D.BODY_MODE_RIGID)
		pb.angular_damp = DAMP.x
		pb.linear_damp = DAMP.y
	_settle(sim)


static func _settle(sim: PhysicalBoneSimulator3D) -> void:
	var settle := sim.create_tween().set_parallel()
	for pb: PhysicalBone3D in sim.get_children():
		settle.tween_property(pb, "angular_damp", SETTLE_DAMP.x, SETTLE_TIME).set_delay(SETTLE_DELAY)
		settle.tween_property(pb, "linear_damp", SETTLE_DAMP.y, SETTLE_TIME).set_delay(SETTLE_DELAY)


static func _bone(bone_name: String, spec: Array, length: float, actor: Node, layer: int) -> PhysicalBone3D:
	var radius: float = spec[1]
	var pb := PhysicalBone3D.new()
	pb.name = "PB_" + bone_name
	pb.bone_name = bone_name
	pb.mass = BODY_MASS * spec[2]
	pb.angular_damp = DAMP.x
	pb.linear_damp = DAMP.y
	pb.gravity_scale = GRAVITY
	pb.friction = 1.0
	pb.bounce = 0.0
	pb.collision_layer = layer
	pb.collision_mask = 1
	pb.set_meta("actor", actor)
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = maxf(length + radius * 0.6, radius * 2.0 + 0.01)
	col.shape = cap
	col.position = Vector3(0, length * 0.5, 0)
	pb.add_child(col)
	if bone_name != "Hips":
		pb.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
		pb.set("joint_constraints/swing_span", spec[3])
		pb.set("joint_constraints/twist_span", spec[4])
		pb.set("joint_constraints/softness", 0.8)
		pb.set("joint_constraints/relaxation", 1.0)
	return pb
