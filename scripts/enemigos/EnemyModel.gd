class_name EnemyModel
extends Node3D

const LAYER_BIT := 1 << 2
const ASSET := "res://assets/models/enemy.glb"
const IDLE := "Idle"
const LOOPING := ["Idle", "Walk", "AimWalk", "Aim", "Ready", "Run", "CrouchAim"]
const ONCE := ["HitChest", "HitGut", "HitBack", "HitArmL", "HitArmR", "HitLegL", "HitLegR"]
const LOD_RANGES := {"": Vector2(0.0, 9.0), "LOD1": Vector2(9.0, 22.0), "LOD2": Vector2(22.0, 0.0)}
const OFFSCREEN_STEP := 0.1
const ALLY_DYES := {"Soldier_body1": Color(1.55, 1.65, 1.2), "texture": Color(2.3, 2.45, 1.85)}

static var _ally_materials := {}

var skeleton: Skeleton3D
var anim: AnimationPlayer
var clips := {}
var bones := {}

var _on_view := false
var _step := 0.0


func load_asset() -> bool:
	var packed := load(ASSET) as PackedScene
	if packed == null:
		push_error("Enemy: falta " + ASSET)
		return false
	var scene := packed.instantiate() as Node3D
	add_child(scene)
	skeleton = scene.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	anim = scene.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	if not _bind_clips():
		return false
	for i in skeleton.get_bone_count():
		bones[skeleton.get_bone_name(i)] = i
	_set_lods(scene)
	var notifier := VisibleOnScreenNotifier3D.new()
	notifier.aabb = AABB(Vector3(-0.6, 0.0, -0.6), Vector3(1.2, 2.0, 1.2))
	notifier.screen_entered.connect(_on_screen.bind(true))
	notifier.screen_exited.connect(_on_screen.bind(false))
	add_child(notifier)
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	anim.play(clips[IDLE])
	anim.seek(randf() * 2.0, true)
	return true


func dress(team: int) -> void:
	if team != 0:
		return
	for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var source := mi.get_active_material(i) as BaseMaterial3D
			var dye := _dye_of(source)
			if dye == Color.WHITE:
				continue
			if not _ally_materials.has(source):
				var dyed := source.duplicate() as BaseMaterial3D
				dyed.albedo_color = dye
				_ally_materials[source] = dyed
			mi.set_surface_override_material(i, _ally_materials[source])


func _dye_of(material: BaseMaterial3D) -> Color:
	if material == null:
		return Color.WHITE
	for key: String in ALLY_DYES:
		if material.resource_name.begins_with(key):
			return ALLY_DYES[key]
	return Color.WHITE


func bone_world(bone: String) -> Vector3:
	return skeleton.global_transform * skeleton.get_bone_global_pose(bones.get(bone, 0)).origin


func bone_point(bone: String, offset: Vector3) -> Vector3:
	return skeleton.global_transform * skeleton.get_bone_global_pose(bones[bone]) * offset


func play(clip: String, blend: float, scale := 1.0) -> void:
	anim.speed_scale = scale
	if anim.current_animation != clips[clip]:
		anim.play(clips[clip], blend)


func restart(clip: String, blend: float) -> float:
	anim.speed_scale = 1.0
	anim.play(clips[clip], blend)
	anim.seek(0.0, true)
	return anim.get_animation(clips[clip]).length


func _process(delta: float) -> void:
	if _on_view or not anim.is_playing():
		return
	_step += delta
	if _step >= OFFSCREEN_STEP:
		anim.advance(_step)
		_step = 0.0


func _on_screen(seen: bool) -> void:
	_on_view = seen
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE if seen \
		else AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL


func _bind_clips() -> bool:
	for clip: String in LOOPING + ONCE:
		var found := Clips.find(anim, clip)
		if found == "":
			push_error("Enemy: falta el clip " + clip)
			return false
		clips[clip] = found
		anim.get_animation(found).loop_mode = Animation.LOOP_LINEAR if clip in LOOPING else Animation.LOOP_NONE
	return true


func _set_lods(scene: Node3D) -> void:
	Nodes.each(scene, func(node: Node) -> void:
		if not node is MeshInstance3D:
			return
		var mi := node as MeshInstance3D
		mi.layers = LAYER_BIT
		if mi.mesh == null or not mi.name.begins_with("Enemy_Mesh"):
			return
		var lod: String = mi.name.get_slice("_", 2) if mi.name.count("_") >= 2 else ""
		var range: Vector2 = LOD_RANGES.get(lod, LOD_RANGES[""])
		mi.visibility_range_begin = range.x
		mi.visibility_range_end = range.y
		mi.visibility_range_begin_margin = 1.0 if range.x > 0.0 else 0.0
		mi.visibility_range_end_margin = 1.0 if range.y > 0.0 else 0.0
		if lod == "LOD2":
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
