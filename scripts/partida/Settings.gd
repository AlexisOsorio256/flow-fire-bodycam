class_name Settings
extends RefCounted

const PATH := "user://settings.cfg"
const QUALITY := [1.0, 0.85, 0.7]
const QUALITY_NAMES := ["Alta", "Media", "Baja"]
const RIVAL_SKILL := [0.1, 0.4, 0.8]
const DIFFICULTY_NAMES := ["Fáciles", "Normales", "Difíciles"]
const FPS_MOBILE := 60
const FPS_DESKTOP := 30

static var sensitivity := 1.0
static var volume := 0.8
static var quality := 0
static var fullscreen := true
static var difficulty := 1
static var blackout := OS.get_cmdline_user_args().has("--dark")
static var player_name := "Jugador %d" % (randi() % 90 + 10)
static var touch_layout := {}
static var touch_opacity := 0.6
static var aim_assist := true


static func load_saved() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		sensitivity = cfg.get_value("input", "sensitivity", sensitivity)
		volume = cfg.get_value("audio", "volume", volume)
		quality = cfg.get_value("video", "quality", quality)
		fullscreen = cfg.get_value("video", "fullscreen", fullscreen)
		difficulty = cfg.get_value("game", "difficulty", difficulty)
		blackout = cfg.get_value("game", "blackout", blackout)
		player_name = cfg.get_value("game", "name", player_name)
		touch_layout = cfg.get_value("touch", "layout", touch_layout)
		touch_opacity = cfg.get_value("touch", "opacity", touch_opacity)
		aim_assist = cfg.get_value("touch", "assist", aim_assist)


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("input", "sensitivity", sensitivity)
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("video", "quality", quality)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("game", "difficulty", difficulty)
	cfg.set_value("game", "blackout", blackout)
	cfg.set_value("game", "name", player_name)
	cfg.set_value("touch", "layout", touch_layout)
	cfg.set_value("touch", "opacity", touch_opacity)
	cfg.set_value("touch", "assist", aim_assist)
	cfg.save(PATH)


static func apply(viewport: Viewport) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	viewport.scaling_3d_scale = QUALITY[quality]
	Engine.max_fps = FPS_MOBILE if OS.has_feature("mobile") else FPS_DESKTOP
	if OS.has_feature("template"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
