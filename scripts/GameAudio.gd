extends Node

## Mezcla de audio. Buses (default_bus_layout.tres): Weapons -> Master (arma en
## mano, seco); World -> Range -> Master (mundo con sala); Master lleva un
## limitador como techo. Los disparos traen la cola de la nave horneada y
## saturacion de microfono de bodycam.

const BUS_WEAPONS := "Weapons"
const BUS_WORLD := "World"
const BUS_MASTER := "Master"

const SOUNDS := {
	"empty": {"stream": preload("res://assets/audio/empty_b.wav"), "db": -8.0, "bus": BUS_WEAPONS},
	"slide_rear": {"stream": preload("res://assets/audio/slide_rear.wav"), "db": -12.0, "bus": BUS_WEAPONS},
	"slide_battery": {"stream": preload("res://assets/audio/slide_battery.wav"), "db": -8.0, "bus": BUS_WEAPONS},
	"trigger_reset": {"stream": preload("res://assets/audio/trigger_reset.wav"), "db": -14.0, "bus": BUS_WEAPONS},
	"magin": {"stream": preload("res://assets/audio/magin.wav"), "db": -2.0, "bus": BUS_WEAPONS},
	"magout": {"stream": preload("res://assets/audio/magout.wav"), "db": -4.0, "bus": BUS_WEAPONS},
	"slide_release": {"stream": preload("res://assets/audio/slide_release.wav"), "db": 1.0, "bus": BUS_WEAPONS},
	"mag_drop": {"stream": preload("res://assets/audio/mag_drop.wav"), "db": -8.0, "bus": BUS_WORLD},
	"mag_insert": {"stream": preload("res://assets/audio/mag_insert.wav"), "db": -1.0, "bus": BUS_WEAPONS},
	"footstep": {"stream": preload("res://assets/audio/footstep.wav"), "db": -14.0, "bus": BUS_WORLD},
	"impact_concrete": {"stream": preload("res://assets/audio/impact_concrete.wav"), "db": -17.0, "bus": BUS_WORLD},
	"impact_drywall": {"stream": preload("res://assets/audio/impact_drywall.wav"), "db": -17.0, "bus": BUS_WORLD},
	"impact_metal": {"stream": preload("res://assets/audio/impact_metal.wav"), "db": -18.5, "bus": BUS_WORLD},
	"impact_aluminum": {"stream": preload("res://assets/audio/impact_aluminum.wav"), "db": -19.0, "bus": BUS_WORLD},
	"impact_wood": {"stream": preload("res://assets/audio/impact_wood.wav"), "db": -15.0, "bus": BUS_WORLD},
	"ricochet": {"stream": preload("res://assets/audio/ricochet.wav"), "db": -10.5, "bus": BUS_WORLD},
	"bullet_flyby": {"stream": preload("res://assets/audio/bullet_flyby.wav"), "db": -12.0, "bus": BUS_WORLD},
	"shot_enemy": {"stream": preload("res://assets/audio/shot_far.ogg"), "db": -4.0, "bus": BUS_WORLD},
	"shell_drop": {"stream": preload("res://assets/audio/shell_drop.wav"), "db": -20.0, "bus": BUS_WORLD},
}

const SHOT_STREAMS: Array[AudioStream] = [
	preload("res://assets/audio/shot_1.ogg"),
	preload("res://assets/audio/shot_2.ogg"),
	preload("res://assets/audio/shot_3.ogg"),
	preload("res://assets/audio/shot_4.ogg"),
	preload("res://assets/audio/shot_5.ogg"),
]
const SHOT_DB := -3.5


func play_shot() -> void:
	var stream: AudioStream = SHOT_STREAMS[randi() % SHOT_STREAMS.size()]
	_spawn(BUS_MASTER, stream, SHOT_DB, randf_range(0.97, 1.03))


func play_2d(sound_name: String, adjust_db: float = 0.0, pitch: float = 1.0) -> void:
	if not SOUNDS.has(sound_name):
		return
	var entry: Dictionary = SOUNDS[sound_name]
	_spawn(entry["bus"], entry["stream"], entry["db"] + adjust_db, pitch)


func play_3d(sound_name: String, pos: Vector3, adjust_db: float = 0.0, pitch: float = 1.0) -> void:
	if not SOUNDS.has(sound_name):
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var entry: Dictionary = SOUNDS[sound_name]
	var p := AudioStreamPlayer3D.new()
	p.stream = entry["stream"]
	p.volume_db = entry["db"] + adjust_db
	p.pitch_scale = pitch
	p.bus = entry["bus"]
	p.max_distance = 90.0
	p.unit_size = 12.0
	scene.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


func _spawn(bus: String, stream: AudioStream, volume_db: float, pitch: float, autoplay := true) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.bus = bus
	add_child(p)
	p.finished.connect(p.queue_free)
	if autoplay:
		p.play()
	return p
