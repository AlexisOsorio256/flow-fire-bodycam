extends CanvasLayer

const FACE_MAX := 8
const FACE_RADIUS := 0.21
const PAD := 42.0
const COUNT_RED := Color(0.95, 0.12, 0.08, 0.95)
const LENS_CIRCLE := 1.97
const LENS_BARREL := 0.5
const RELINK := 0.45

var player: Player
var post_mat: ShaderMaterial
var clock_label: Label
var rec_label: Label
var rec_dot: ColorRect
var count_label: Label
var _clock_timer := 0.0
var _layout_size := Vector2.ZERO
var _fade := 0.0
var _dead_for := 0.0
var _relink := 0.0
var _touch: TouchControls
var _los := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	layer = 0
	process_mode = Node.PROCESS_MODE_ALWAYS
	var post := ColorRect.new()
	post.set_anchors_preset(Control.PRESET_FULL_RECT)
	post.color = Color.WHITE
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_mat = ShaderMaterial.new()
	post_mat.shader = preload("res://shaders/bodycam.gdshader")
	post_mat.set_shader_parameter("circle", LENS_CIRCLE)
	post_mat.set_shader_parameter("barrel", LENS_BARREL)
	post.material = post_mat
	add_child(post)
	rec_dot = ColorRect.new()
	rec_dot.color = Color(0.95, 0.15, 0.10, 0.9)
	rec_dot.size = Vector2(8, 8)
	rec_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rec_dot)
	rec_label = _label("REC", 14, Color(0.95, 0.2, 0.15, 0.9))
	clock_label = _label("", 12, Color(0.88, 0.9, 0.92, 0.75))
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label = _label("", 20, COUNT_RED)
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0, 0, 0, 0)
	frame.border_color = COUNT_RED
	frame.set_border_width_all(1)
	frame.set_content_margin_all(4)
	count_label.add_theme_stylebox_override("normal", frame)
	count_label.visible = false


func _label(text: String, font_size: int, tint: Color) -> Label:
	var label := UiStyle.label(text, font_size, tint, UiStyle.MONO)
	add_child(label)
	return label


func setup(actor: Player) -> void:
	player = actor
	if TouchControls.wanted():
		if _touch == null:
			_touch = TouchControls.new()
			add_child(_touch)
		_touch.player = actor
		actor.touch = _touch
	_relink = RELINK if _dead_for > 0.0 else 0.0
	_fade = 0.0
	_dead_for = 0.0
	post_mat.set_shader_parameter("fade", 0.0)
	post_mat.set_shader_parameter("signal_loss", 0.0)


func _process(delta: float) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size != _layout_size:
		_layout_size = viewport_size
		_layout(viewport_size)
	_clock_timer -= delta
	if _clock_timer <= 0.0:
		_clock_timer = 1.0
		var t := Time.get_datetime_dict_from_system()
		clock_label.text = "%04d-%02d-%02d  %02d:%02d:%02d" % [t["year"], t["month"], t["day"], t["hour"], t["minute"], t["second"]]
		rec_dot.visible = not rec_dot.visible or not is_instance_valid(player)
	if not is_instance_valid(player):
		return
	post_mat.set_shader_parameter("fov_v", player.camera.fov)
	if not get_tree().paused:
		_update_faces()
	_update_count()
	post_mat.set_shader_parameter("time_seed", float(Engine.get_process_frames() % 97))
	post_mat.set_shader_parameter("exposure_pulse", player.weapon.shot_pulse)
	post_mat.set_shader_parameter("hit_pulse", player.hit_flash)
	post_mat.set_shader_parameter("hurt", player.hurt())
	post_mat.set_shader_parameter("bleed", 0.0)
	post_mat.set_shader_parameter("suppress", player.under_fire)
	_dead_for = 0.0 if player.is_alive() else _dead_for + delta
	_fade = 0.0 if player.is_alive() else clampf((_dead_for - 2.0) / 0.6, 0.0, 1.0) * 0.85
	post_mat.set_shader_parameter("fade", _fade)
	_relink = maxf(0.0, _relink - delta)
	post_mat.set_shader_parameter("signal_loss", maxf(clampf((_dead_for - 1.3) / 0.9, 0.0, 1.0), _relink / RELINK * 0.8))


func _update_count() -> void:
	var weapon = player.weapon
	count_label.visible = weapon.inspecting and weapon.viewmodel.arms.mag_in_hand
	if not count_label.visible:
		return
	count_label.text = "%d/%d" % [weapon.mag, weapon.mag_size]
	var top: Vector3 = weapon.viewmodel.weapon.mag_round.global_position
	count_label.position = _through_lens(player.camera.unproject_position(top)) + Vector2(26, -48)


func _through_lens(source: Vector2) -> Vector2:
	var view := get_viewport().get_visible_rect().size
	var aspect := view.x / view.y
	var q := (source / view - Vector2(0.5, 0.5)) * Vector2(aspect, 1.0) * 2.0
	var target := q.length()
	if target < 0.00001:
		return source
	var tv := tan(deg_to_rad(player.camera.fov) * 0.5)
	var rc := Vector2(aspect, 1.0).length()
	var lo := 0.0
	var hi := rc
	for i in 24:
		var r := (lo + hi) * 0.5
		var r_fish := tan(minf(atan(rc * tv) * r / LENS_CIRCLE, 1.5)) / tv
		if lerpf(r * rc / LENS_CIRCLE, r_fish, LENS_BARREL) < target:
			lo = r
		else:
			hi = r
	var p := q * (lo / target)
	return (p / Vector2(aspect, 1.0) * 0.5 + Vector2(0.5, 0.5)) * view


func _update_faces() -> void:
	var cam: Camera3D = player.camera
	var view := get_viewport().get_visible_rect().size
	var space := cam.get_world_3d().direct_space_state
	var half_h := tan(deg_to_rad(cam.fov) * 0.5)
	var faces: Array[Vector4] = []
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if faces.size() >= FACE_MAX:
			break
		var p: Vector3 = enemy.face_point()
		if cam.is_position_behind(p):
			continue
		_los.from = cam.global_position
		_los.to = p
		_los.collision_mask = 1
		if not space.intersect_ray(_los).is_empty():
			continue
		var depth := -(cam.global_transform.affine_inverse() * p).z
		var r := FACE_RADIUS * 0.5 / (depth * half_h)
		var c := cam.unproject_position(p) / view
		faces.append(Vector4(c.x, c.y, r * view.y / view.x, r))
	post_mat.set_shader_parameter("faces", faces)
	post_mat.set_shader_parameter("face_count", faces.size())


func _layout(viewport_size: Vector2) -> void:
	clock_label.position = Vector2(viewport_size.x - 390 - PAD, 22)
	clock_label.size = Vector2(350, 20)
	rec_dot.position = Vector2(viewport_size.x - 32 - PAD, 27)
	rec_label.position = Vector2(viewport_size.x - 20 - PAD, 23)
