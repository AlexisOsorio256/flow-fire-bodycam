extends CanvasLayer

var player
var post: ColorRect
var post_mat: ShaderMaterial
var clock_label: Label
var rec_label: Label
var rec_dot: ColorRect
var clock_timer := 0.0
var _layout_size := Vector2.ZERO
var _last_pulse := -1.0
var _fade := 0.0


func _ready() -> void:
    layer = 0
    _build_post()
    _build_hud()
    process_mode = Node.PROCESS_MODE_ALWAYS


func setup(p) -> void:
    player = p


func _build_post() -> void:
    post = ColorRect.new()
    post.name = "Post"
    post.set_anchors_preset(Control.PRESET_FULL_RECT)
    post.color = Color.WHITE
    post.mouse_filter = Control.MOUSE_FILTER_IGNORE
    post_mat = ShaderMaterial.new()
    post_mat.shader = preload("res://shaders/bodycam.gdshader")
    post.material = post_mat
    add_child(post)


func _build_hud() -> void:
    rec_dot = ColorRect.new()
    rec_dot.color = Color(0.95, 0.15, 0.10, 0.90)
    rec_dot.size = Vector2(8, 8)
    rec_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(rec_dot)

    rec_label = _make_label("REC", 14, Color(0.95, 0.20, 0.15, 0.90))
    add_child(rec_label)

    clock_label = _make_label("--:--:--", 12, Color(0.88, 0.90, 0.92, 0.75))
    clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    add_child(clock_label)


func _make_label(text: String, size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
    label.add_theme_constant_override("shadow_offset_x", 1)
    label.add_theme_constant_override("shadow_offset_y", 1)
    return label


func _process(delta: float) -> void:
    var viewport_size := get_viewport().get_visible_rect().size
    if viewport_size != _layout_size:
        _layout_size = viewport_size
        _layout(viewport_size)

    clock_timer -= delta
    if clock_timer <= 0.0:
        clock_timer = 1.0
        var t := Time.get_datetime_dict_from_system()
        clock_label.text = "%04d-%02d-%02d  %02d:%02d:%02d" % [
            t["year"], t["month"], t["day"], t["hour"], t["minute"], t["second"]
        ]

    if player == null:
        return
    post_mat.set_shader_parameter("fov_v", player.camera.fov)
    post_mat.set_shader_parameter("time_seed", float(Engine.get_process_frames() % 97))
    var shot_pulse = player.weapon.shot_pulse
    if shot_pulse != _last_pulse:
        _last_pulse = shot_pulse
        post_mat.set_shader_parameter("exposure_pulse", shot_pulse)
    if not player.is_alive():
        _fade = minf(0.92, _fade + delta * 0.45)
        post_mat.set_shader_parameter("fade", _fade)


func _layout(viewport_size: Vector2) -> void:
    var pad := 42.0
    clock_label.position = Vector2(viewport_size.x - 390 - pad, 22)
    clock_label.size = Vector2(350, 20)
    rec_dot.position = Vector2(viewport_size.x - 32 - pad, 27)
    rec_label.position = Vector2(viewport_size.x - 20 - pad, 23)
