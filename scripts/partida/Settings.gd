class_name Settings
extends RefCounted

const PATH := "user://settings.cfg"
const TIERS_VERSION := 2
const TIERS := [
	{"name": "Muy alta", "scale": 1.0, "msaa": Viewport.MSAA_2X, "aa": Viewport.SCREEN_SPACE_AA_SMAA,
		"bias": -0.35, "deband": true, "aniso": true},
	{"name": "Alta", "scale": 1.0},
	{"name": "Media", "scale": 0.85},
	{"name": "Baja", "scale": 0.7},
]
const RIVAL_SKILL := [0.35, 0.60, 0.85]
const DIFFICULTY_NAMES := ["Fáciles", "Normales", "Difíciles"]
const FPS_MOBILE := 60
const FPS_DESKTOP := 30
const FPS_CHOICES := [30, 60, 120]
const RESOLUTION_NAMES := ["Igual que la pantalla", "1920 × 1080", "1600 × 900", "1280 × 720"]
const RESOLUTION_SIZES := [Vector2i.ZERO, Vector2i(1920, 1080), Vector2i(1600, 900), Vector2i(1280, 720)]

static var sensitivity := 1.0
static var aim_sensitivity := 0.7
static var touch_sensitivity := 1.0
static var fps_cap := FPS_MOBILE if OS.has_feature("mobile") else FPS_DESKTOP
static var volume := 0.8
static var quality := 1
static var resolution := 0
static var difficulty := 1
static var player_name := "Jugador %d" % (randi() % 90 + 10)
static var touch_layout := {}
static var touch_opacity := 0.6
static var aim_assist := true
static var fill_bots := true


static func _valid_fps(value: int) -> int:
	return value if value in FPS_CHOICES else (FPS_MOBILE if OS.has_feature("mobile") else FPS_DESKTOP)


static func _valid_quality(value: int) -> int:
	return value if value >= 0 and value < TIERS.size() else 1


static func load_saved() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		sensitivity = cfg.get_value("input", "sensitivity", sensitivity)
		aim_sensitivity = cfg.get_value("input", "aim_sensitivity", aim_sensitivity)
		touch_sensitivity = cfg.get_value("input", "touch_sensitivity", touch_sensitivity)
		fps_cap = _valid_fps(cfg.get_value("video", "fps_cap", fps_cap))
		volume = cfg.get_value("audio", "volume", volume)
		quality = cfg.get_value("video", "quality", quality)
		if int(cfg.get_value("video", "tiers", 1)) < TIERS_VERSION:
			quality += 1
		quality = _valid_quality(quality)
		resolution = cfg.get_value("video", "resolution", resolution)
		difficulty = cfg.get_value("game", "difficulty", difficulty)
		player_name = cfg.get_value("game", "name", player_name)
		touch_layout = cfg.get_value("touch", "layout", touch_layout)
		touch_opacity = cfg.get_value("touch", "opacity", touch_opacity)
		aim_assist = cfg.get_value("touch", "assist", aim_assist)
		fill_bots = cfg.get_value("game", "fill_bots", fill_bots)


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("input", "sensitivity", sensitivity)
	cfg.set_value("input", "aim_sensitivity", aim_sensitivity)
	cfg.set_value("input", "touch_sensitivity", touch_sensitivity)
	cfg.set_value("video", "fps_cap", fps_cap)
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("video", "quality", quality)
	cfg.set_value("video", "tiers", TIERS_VERSION)
	cfg.set_value("video", "resolution", resolution)
	cfg.set_value("game", "difficulty", difficulty)
	cfg.set_value("game", "name", player_name)
	cfg.set_value("touch", "layout", touch_layout)
	cfg.set_value("touch", "opacity", touch_opacity)
	cfg.set_value("touch", "assist", aim_assist)
	cfg.set_value("game", "fill_bots", fill_bots)
	cfg.save(PATH)


static func apply(viewport: Viewport) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	var tier: Dictionary = TIERS[_valid_quality(quality)]
	viewport.scaling_3d_scale = tier["scale"]
	viewport.msaa_3d = tier.get("msaa", Viewport.MSAA_DISABLED)
	viewport.screen_space_aa = tier.get("aa", Viewport.SCREEN_SPACE_AA_DISABLED)
	viewport.texture_mipmap_bias = tier.get("bias", 0.0)
	viewport.use_debanding = tier.get("deband", false)
	Engine.max_fps = fps_cap
	if OS.has_feature("mobile"):
		return
	if OS.has_feature("editor"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		return
	var size: Vector2i = RESOLUTION_SIZES[resolution]
	if size == Vector2i.ZERO and OS.has_feature("template"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	var window := Vector2i(1920, 1080) if size == Vector2i.ZERO else size
	var screen := DisplayServer.screen_get_size()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(mini(window.x, screen.x), mini(window.y, screen.y)))


static func dress(host: Node3D) -> void:
	var filter: int = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC \
		if TIERS[_valid_quality(quality)].get("aniso", false) else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var done := {}
	Nodes.each(host, func(n: Node) -> void:
		if not n is MeshInstance3D:
			return
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(i) as BaseMaterial3D
			if mat == null or done.has(mat.get_instance_id()):
				continue
			done[mat.get_instance_id()] = true
			mat.texture_filter = filter)
