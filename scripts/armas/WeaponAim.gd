class_name WeaponAim
extends RefCounted

const RANGE := 80.0
const HIP_SPREAD := 0.016
const AIM_SPREAD := 0.0025
const MOVE_SPREAD := 0.014
const BLOOM_PER_SHOT := 0.007
const BLOOM_MAX := 0.028
const BLOOM_RECOVER := 0.045

var bloom := 0.0
var hip_scale := 1.0


func update(delta: float) -> void:
	bloom = maxf(0.0, bloom - BLOOM_RECOVER * delta)


func aim_point(camera: Camera3D) -> Vector3:
	var from := camera.global_position
	var forward := -camera.global_basis.z
	var query := PhysicsRayQueryParameters3D.create(from, from + forward * RANGE, 1 | Enemy.HITBOX_LAYER)
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position if not hit.is_empty() else from + forward * RANGE


func origin_of(camera: Camera3D, muzzle: Vector3) -> Vector3:
	var tip := muzzle + (muzzle - camera.global_position).normalized() * 0.05
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, tip, 1)
	var behind_cover := not camera.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
	return camera.global_position if behind_cover else muzzle


func bore(target: Vector3, origin: Vector3, aim_blend: float, speed: float) -> Vector3:
	var dir := (target - origin).normalized()
	var moving := clampf(speed / Player.WALK_SPEED, 0.0, 1.5) * (1.0 - 0.6 * aim_blend)
	var sigma := lerpf(HIP_SPREAD * hip_scale, AIM_SPREAD, aim_blend) + (MOVE_SPREAD * moving + bloom) * lerpf(hip_scale, 1.0, aim_blend)
	bloom = minf(BLOOM_MAX, bloom + BLOOM_PER_SHOT)
	var side := dir.cross(Vector3.UP).normalized()
	var up := side.cross(dir).normalized()
	return (dir + side * randfn(0.0, sigma) + up * randfn(0.0, sigma)).normalized()
