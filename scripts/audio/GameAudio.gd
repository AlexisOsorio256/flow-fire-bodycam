extends Node

const BUS_WEAPONS := "Weapons"
const BUS_WORLD := "World"
const BUS_OCCLUDED := "Occluded"
const BUS_ROOM := "Range"
const BUS_MASTER := "Master"
const BUS_AMBIENCE := "Ambience"
const MUFFLE_OPEN := 20500.0
const MUFFLE_SHUT := 650.0
const SPEED_OF_SOUND := 343.0
const NEAR_SHOT_REACH := 10.0

const SOUNDS := {
	"empty": {"stream": preload("res://assets/audio/empty_b.wav"), "db": -8.0, "bus": BUS_ROOM},
	"slide_rear": {"stream": preload("res://assets/audio/slide_rear.wav"), "db": -9.0, "bus": BUS_ROOM},
	"slide_battery": {"stream": preload("res://assets/audio/slide_battery.wav"), "db": -8.0, "bus": BUS_ROOM},
	"trigger_reset": {"stream": preload("res://assets/audio/trigger_reset.wav"), "db": -14.0, "bus": BUS_ROOM},
	"magin": {"stream": preload("res://assets/audio/magin.wav"), "db": -2.0, "bus": BUS_ROOM},
	"magout": {"stream": preload("res://assets/audio/magout.wav"), "db": -4.0, "bus": BUS_ROOM},
	"slide_release": {"stream": preload("res://assets/audio/slide_release.wav"), "db": 1.0, "bus": BUS_ROOM},
	"mag_drop": {"stream": preload("res://assets/audio/mag_drop.wav"), "db": -8.0, "bus": BUS_WORLD},
	"mag_insert": {"stream": preload("res://assets/audio/mag_insert.wav"), "db": -1.0, "bus": BUS_ROOM},
	"rifle_magout": {"stream": preload("res://assets/audio/rifle_magout.wav"), "db": -2.0, "bus": BUS_ROOM},
	"rifle_magin": {"stream": preload("res://assets/audio/rifle_magin.wav"), "db": 0.0, "bus": BUS_ROOM},
	"rifle_tap": {"stream": preload("res://assets/audio/rifle_tap.wav"), "db": -3.0, "bus": BUS_ROOM},
	"rifle_charge": {"stream": preload("res://assets/audio/rifle_charge.wav"), "db": 0.0, "bus": BUS_ROOM},
	"rifle_bolt": {"stream": preload("res://assets/audio/rifle_bolt.wav"), "db": 1.0, "bus": BUS_ROOM},
	"rifle_shoulder": {"stream": preload("res://assets/audio/rifle_shoulder.wav"), "db": -4.0, "bus": BUS_ROOM},
	"shotgun_pump": {"stream": preload("res://assets/audio/shotgun_pump.wav"), "db": 0.0, "bus": BUS_ROOM},
	"shotgun_pump_fwd": {"stream": preload("res://assets/audio/shotgun_pump_fwd.wav"), "db": 0.0, "bus": BUS_ROOM},
	"shotgun_shell": {"stream": preload("res://assets/audio/shotgun_shell.wav"), "db": -2.0, "bus": BUS_ROOM},
	"cloth": {"streams": [preload("res://assets/audio/cloth_1.ogg"), preload("res://assets/audio/cloth_2.ogg"),
		preload("res://assets/audio/cloth_3.ogg"), preload("res://assets/audio/cloth_4.ogg")], "db": -14.0, "bus": BUS_WEAPONS},
	"step_concrete": {"reach": Vector2(5.0, 24.0), "streams": [preload("res://assets/audio/step_concrete_0.ogg"), preload("res://assets/audio/step_concrete_1.ogg"),
		preload("res://assets/audio/step_concrete_2.ogg"), preload("res://assets/audio/step_concrete_3.ogg"),
		preload("res://assets/audio/step_concrete_4.ogg")], "db": -9.0, "bus": BUS_WORLD},
	"step_wood": {"reach": Vector2(5.0, 24.0), "streams": [preload("res://assets/audio/step_wood_0.ogg"), preload("res://assets/audio/step_wood_1.ogg"),
		preload("res://assets/audio/step_wood_2.ogg"), preload("res://assets/audio/step_wood_3.ogg"),
		preload("res://assets/audio/step_wood_4.ogg")], "db": -8.0, "bus": BUS_WORLD},
	"body_fall": {"streams": [preload("res://assets/audio/body_fall_0.ogg"), preload("res://assets/audio/body_fall_1.ogg"),
		preload("res://assets/audio/body_fall_2.ogg")], "db": 0.0, "bus": BUS_WORLD},
	"gun_drop": {"streams": [preload("res://assets/audio/gun_drop_0.ogg"), preload("res://assets/audio/gun_drop_1.ogg"),
		preload("res://assets/audio/gun_drop_2.ogg")], "db": -4.0, "bus": BUS_WORLD},
	"flesh": {"streams": [preload("res://assets/audio/flesh_0.ogg"), preload("res://assets/audio/flesh_1.ogg"),
		preload("res://assets/audio/flesh_2.ogg")], "db": -3.0, "bus": BUS_WORLD},
	"impact_concrete": {"stream": preload("res://assets/audio/impact_concrete.wav"), "db": -17.0, "bus": BUS_WORLD},
	"impact_drywall": {"stream": preload("res://assets/audio/impact_drywall.wav"), "db": -17.0, "bus": BUS_WORLD},
	"impact_metal": {"stream": preload("res://assets/audio/impact_metal.wav"), "db": -18.5, "bus": BUS_WORLD},
	"impact_aluminum": {"stream": preload("res://assets/audio/impact_aluminum.wav"), "db": -19.0, "bus": BUS_WORLD},
	"impact_wood": {"stream": preload("res://assets/audio/impact_wood.wav"), "db": -15.0, "bus": BUS_WORLD},
	"ricochet": {"stream": preload("res://assets/audio/ricochet.wav"), "db": -10.5, "bus": BUS_WORLD},
	"bullet_flyby": {"stream": preload("res://assets/audio/bullet_flyby.wav"), "db": -12.0, "bus": BUS_WORLD},
	"shot_enemy": {"streams": [preload("res://assets/audio/shot_far_0.ogg"), preload("res://assets/audio/shot_far_1.ogg"),
		preload("res://assets/audio/shot_far_2.ogg")], "db": -4.0, "bus": BUS_WORLD},
	"shot_near": {"streams": [preload("res://assets/audio/shot_1.ogg"), preload("res://assets/audio/shot_2.ogg"),
		preload("res://assets/audio/shot_3.ogg"), preload("res://assets/audio/shot_4.ogg")], "db": -5.0, "bus": BUS_WORLD,
		"reach": Vector2(3.5, 32.0)},
	"shell_drop": {"stream": preload("res://assets/audio/shell_drop.wav"), "db": -20.0, "bus": BUS_WORLD},
	"hit_thump": {"stream": preload("res://assets/audio/hit_thump.wav"), "db": -2.0, "bus": BUS_WEAPONS},
	"tinnitus": {"stream": preload("res://assets/audio/tinnitus.wav"), "db": -16.0, "bus": BUS_MASTER},
	"radio": {"stream": preload("res://assets/audio/radio_squelch.wav"), "db": -12.0, "bus": BUS_MASTER},
	"ui_hover": {"stream": preload("res://assets/audio/ui_hover.ogg"), "db": -14.0, "bus": BUS_MASTER},
	"ui_confirm": {"stream": preload("res://assets/audio/ui_confirm.ogg"), "db": -8.0, "bus": BUS_MASTER},
}
const LOOPS := {
	"factory": {"stream": preload("res://assets/audio/amb_factory.ogg"), "db": -14.0, "bus": BUS_AMBIENCE},
	"lobby": {"stream": preload("res://assets/audio/amb_lobby.ogg"), "db": -8.0, "bus": BUS_AMBIENCE},
	"heart": {"stream": preload("res://assets/audio/heartbeat.wav"), "db": -4.0, "bus": BUS_WEAPONS},
	"breath": {"stream": preload("res://assets/audio/breath_scared.ogg"), "db": -5.0, "bus": BUS_WEAPONS},
}

const SHOT_STREAMS: Array[AudioStream] = [
	preload("res://assets/audio/shot_1.ogg"),
	preload("res://assets/audio/shot_2.ogg"),
	preload("res://assets/audio/shot_3.ogg"),
	preload("res://assets/audio/shot_4.ogg"),
	preload("res://assets/audio/shot_5.ogg"),
]
const RIFLE_STREAMS: Array[AudioStream] = [
	preload("res://assets/audio/rifle_1.ogg"),
	preload("res://assets/audio/rifle_2.ogg"),
	preload("res://assets/audio/rifle_3.ogg"),
	preload("res://assets/audio/rifle_4.ogg"),
	preload("res://assets/audio/rifle_5.ogg"),
]
const SHOTGUN_STREAMS: Array[AudioStream] = [
	preload("res://assets/audio/shotgun_1.ogg"),
	preload("res://assets/audio/shotgun_2.ogg"),
	preload("res://assets/audio/shotgun_3.ogg"),
]
const SHOT_DB := -3.5
const SHOTGUN_DB := 3.0
const VOICES_3D := 64
const SHOT_VOICES := 6

var _muffle: AudioEffectLowPassFilter
var _voices3d: Array[AudioStreamPlayer3D] = []
var _voice_root: Node
var _voice_next := 0
var _shot_voices: Array[AudioStreamPlayer] = []
var _shot_next := 0
var _occlusion := PhysicsRayQueryParameters3D.new()
var _step_query := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var master := AudioServer.get_bus_index(BUS_MASTER)
	for i in AudioServer.get_bus_effect_count(master):
		if AudioServer.get_bus_effect(master, i) is AudioEffectLowPassFilter:
			_muffle = AudioServer.get_bus_effect(master, i)
			break


func muffle(amount: float) -> void:
	if _muffle != null:
		_muffle.cutoff_hz = lerpf(MUFFLE_OPEN, MUFFLE_SHUT, clampf(amount, 0.0, 1.0))


func play_shot(kind := "pistol") -> void:
	var streams := SHOTGUN_STREAMS if kind == "shotgun" else RIFLE_STREAMS if kind == "rifle" else SHOT_STREAMS
	var stream: AudioStream = streams[randi() % streams.size()]
	var p := _shot_voice()
	p.stream = stream
	p.volume_db = SHOT_DB + (SHOTGUN_DB if kind == "shotgun" else 0.0)
	p.pitch_scale = randf_range(0.97, 1.03)
	p.bus = BUS_ROOM
	p.play()


func _shot_voice() -> AudioStreamPlayer:
	if _shot_voices.size() < SHOT_VOICES:
		var made := AudioStreamPlayer.new()
		made.bus = BUS_ROOM
		add_child(made)
		_shot_voices.append(made)
		return made
	var reused: AudioStreamPlayer = _shot_voices[_shot_next]
	_shot_next = (_shot_next + 1) % _shot_voices.size()
	return reused


func enemy_shot(pos: Vector3) -> void:
	var camera := get_viewport().get_camera_3d()
	var dist := camera.global_position.distance_to(pos) if camera != null else 0.0
	play_3d("shot_enemy", pos, -6.0, randf_range(0.94, 1.06))
	if dist < NEAR_SHOT_REACH:
		play_3d("shot_near", pos, lerpf(0.0, -12.0, dist / NEAR_SHOT_REACH), randf_range(0.95, 1.05))


func stream_2d(stream: AudioStream, volume_db: float, bus: String = BUS_MASTER, pitch: float = 1.0) -> AudioStreamPlayer:
	return _spawn(bus, stream, volume_db, pitch)


func play_2d(sound_name: String, adjust_db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer:
	if not SOUNDS.has(sound_name):
		push_error("Sonido desconocido: " + sound_name)
		return null
	var entry: Dictionary = SOUNDS[sound_name]
	return _spawn(entry["bus"], _pick(entry), entry["db"] + adjust_db, pitch)


func play_3d(sound_name: String, pos: Vector3, adjust_db: float = 0.0, pitch: float = 1.0) -> void:
	if not SOUNDS.has(sound_name):
		push_error("Sonido desconocido: " + sound_name)
		return
	var entry: Dictionary = SOUNDS[sound_name]
	stream_3d(_pick(entry), pos, entry["db"] + adjust_db, entry.get("reach", Vector2(12.0, 90.0)), entry["bus"], pitch)


func stream_3d(stream: AudioStream, pos: Vector3, volume_db: float, reach: Vector2, bus: String = BUS_WORLD,
		pitch: float = 1.0) -> void:
	var camera := get_viewport().get_camera_3d()
	var heard_db := volume_db
	var heard_bus := bus
	if camera != null and bus == BUS_WORLD:
		_occlusion.from = pos
		_occlusion.to = camera.global_position
		_occlusion.collision_mask = 1
		if not camera.get_world_3d().direct_space_state.intersect_ray(_occlusion).is_empty():
			heard_bus = BUS_OCCLUDED
			heard_db -= 5.0
	var delay := pos.distance_to(camera.global_position) / SPEED_OF_SOUND if camera != null else 0.0
	if delay > 0.02:
		get_tree().create_timer(delay, false).timeout.connect(
			_voice_play.bind(stream, pos, heard_db, reach, heard_bus, pitch))
	else:
		_voice_play(stream, pos, heard_db, reach, heard_bus, pitch)


func _voice_play(stream: AudioStream, pos: Vector3, volume_db: float, reach: Vector2, bus: String, pitch: float) -> void:
	var p := _voice3d()
	if p == null:
		return
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.bus = bus
	p.unit_size = reach.x
	p.max_distance = reach.y
	p.global_position = pos
	p.play()


func _voice3d() -> AudioStreamPlayer3D:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	if _voice_root != scene:
		_voice_root = scene
		for p in _voices3d:
			p.reparent(scene)
	if _voices3d.size() < VOICES_3D:
		var made := AudioStreamPlayer3D.new()
		made.bus = BUS_WORLD
		scene.add_child(made)
		_voices3d.append(made)
		return made
	for p in _voices3d:
		if not p.playing:
			return p
	var reused: AudioStreamPlayer3D = _voices3d[_voice_next]
	_voice_next = (_voice_next + 1) % _voices3d.size()
	return reused


func footstep(pos: Vector3, world: World3D, adjust_db: float, positional: bool) -> void:
	_step_query.from = pos + Vector3.UP * 0.3
	_step_query.to = pos + Vector3.DOWN * 0.4
	_step_query.collision_mask = 1
	var hit := world.direct_space_state.intersect_ray(_step_query)
	var surface := "concrete"
	if not hit.is_empty() and hit.collider is Node:
		surface = (hit.collider as Node).get_meta("step", "concrete")
	if positional:
		play_3d("step_" + surface, pos, adjust_db, randf_range(0.9, 1.1))
	else:
		play_2d("step_" + surface, adjust_db, randf_range(0.92, 1.08))


func loop(loop_name: String, adjust_db: float = 0.0) -> AudioStreamPlayer:
	var entry: Dictionary = LOOPS[loop_name]
	var stream: AudioStream = entry["stream"].duplicate()
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	else:
		stream.set("loop", true)
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = entry["db"] + adjust_db
	p.bus = entry["bus"]
	add_child(p)
	p.play(randf() * stream.get_length())
	return p


func _pick(entry: Dictionary) -> AudioStream:
	if entry.has("streams"):
		var list: Array = entry["streams"]
		return list[randi() % list.size()]
	return entry["stream"]


func _spawn(bus: String, stream: AudioStream, volume_db: float, pitch: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.bus = bus
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	return p
