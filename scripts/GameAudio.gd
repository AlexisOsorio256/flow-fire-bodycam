extends Node

## Audio mixto con mix por buses: CC0, Sonniss (EULA sin atribucion) y sintesis propia.
## El disparo usa TRES eventos del mismo master CC0 de seroutonin (Freesound
## 855652). El propio autor documenta que NO es una Glock grabada: es sound
## design construido apilando disparos propios de .22 LR, .22 Magnum, .357 y
## .44 Magnum, mas Foley de mecanismo. `tools/build_shot_real.py` solo extrae
## esos tres eventos con DSP minimo (HPF 36 Hz + pico -0,5 dBFS + fade); no debe
## presentarse esta familia como referencia acustica autentica de una G19.
##
## Solo el Foley restante pasa por `tools/process_audio.sh`. Los disparos los
## construye `build_shot_real.py` (48 kHz, pico -0,5) y los impactos
## `build_impacts.py` (pico -1,2): este mix da por hecha esa construccion y los
## niveles de abajo estan medidos sobre ella.
##
## Ruta verdadera: Weapons y World envian a Range; Range envia a Master y es el
## unico lugar con reverberacion. El layout vive en `default_bus_layout.tres`, no
## se reconstruye ni se corrige en runtime. Predelay 35 ms (valor en el .tres;
## Godot come los comentarios `;` al guardar, asi que el por que vive aqui):
## con 14 ms las primeras reflexiones sumaban +2-4 dB coherentes al transiente
## (+2,2 dBFS medido en juego en rafaga).
##
## No hay +6 dB de buses ni HardLimiter usado como diseño de mezcla. Los niveles
## de cada familia se miden y se dejan en el master PCM; el bus sólo representa
## la sala.

const BUS_WEAPONS := "Weapons"
const BUS_WORLD := "World"
const BUS_RANGE := "Range"

# Tabla única de sonidos: archivo + nivel base en dB. `play_2d` sirve tanto para
# arma como para sonidos locales del jugador (pasos); el BUS de cada entrada es
# la autoridad que decide a qué mezcla pertenece. `play_3d` se usa para eventos
# posicionales del mundo. El segundo argumento de ambos es un *ajuste* en dB
# sobre este nivel base.
# `slide_rear` y `slide_battery` son los DOS golpes de la corredera, que son dos
# eventos fisicos distintos (tope trasero a ~12 ms y vuelta a bateria a ~54 ms) y
# por eso son dos grabaciones distintas:
#
#   slide_rear     Glock 19 real. Pico -0.85 dBFS y 85% de su energia por encima
#                  de 2,5 kHz: chasquido de acero, sin cuerpo.
#   slide_battery  Sig P229 real. Pico -9,82 dBFS y 75% de su energia por debajo
#                  de 800 Hz (centroide 774 Hz): golpe sordo y pesado.
#
# El master del blast ya trae mecanismo enterrado a 1 m, pero estos dos son los
# transitorios cercanos cronometrados a la fisica (tope trasero y bateria, ver
# Glock.gd): sin ellos la corredera se mueve muda. Niveles bajos a proposito
# para no duplicar el blast. Su energia vive en agudos, donde el estampido ya
# no compite (medido 2026-09-19 sobre la familia de 3 tomas: el trasero queda
# ~13 dB por debajo del blast en >2,5 kHz, presente sin competir). La bateria
# sube 3 dB porque quedaba 27 dB bajo la cola del disparo: inaudible, y el tiro
# perdia su peso.
const SOUNDS := {
	# Disparo en seco / gatillo. Antes -8,0: su pico en el mix quedaba a -9,5
	# dBFS, solo 2,5 dB bajo el pico del estampido (-7,0) y con MAS RMS que el
	# disparo (-20,8 de muestra contra -27,4). Un clic de gatillo no puede
	# competir con el disparo; a -14,0 queda 8,5 dB bajo su pico.
	"empty": {"stream": preload("res://assets/audio/empty_b.wav"), "db": -14.0, "bus": BUS_WEAPONS},
	"slide_rear": {"stream": preload("res://assets/audio/slide_rear.wav"), "db": -17.0, "bus": BUS_WEAPONS},
	"slide_battery": {"stream": preload("res://assets/audio/slide_battery.wav"), "db": -15.0, "bus": BUS_WEAPONS},
	# Mano sobre la corredera: no es un disparo mecanico, es un golpe de acero
	# seco y corto (SoundHolder, Metal Contact). Antes no existia y el gesto de
	# agarrar la corredera era mudo hasta que volvia a bateria.
	"slide_hand": {"stream": preload("res://assets/audio/slide_hand.wav"), "db": -16.0, "bus": BUS_WEAPONS},
	"trigger_reset": {"stream": preload("res://assets/audio/trigger_reset.wav"), "db": -14.0, "bus": BUS_WEAPONS},
	# Asiento del cargador (el clack). Antes -10,0: pico -11,5 en el mix, a 4,5
	# dB del estampido. Es el golpe mas fuerte de la recarga y tiene que oirse,
	# pero no a la altura del disparo: -14,0 lo deja 8,5 dB por debajo.
	"magin": {"stream": preload("res://assets/audio/magin.wav"), "db": -14.0, "bus": BUS_WEAPONS},
	# Extraccion del cargador (reten + friccion): -12,0.
	"magout": {"stream": preload("res://assets/audio/magout.wav"), "db": -12.0, "bus": BUS_WEAPONS},
	# Mecanica de recarga: reten, insercion, asiento y reten de corredera.
	# Sin Foley de manos/ropa/palma mientras no haya mano (ver Glock.gd).
	"slide_release": {"stream": preload("res://assets/audio/slide_release.wav"), "db": -15.0, "bus": BUS_WEAPONS},
	# El cargador cae al mundo, no al arma: bus de mundo y 3D en el suelo. Un
	# cargador pesa mas que una vaina, asi que su pico en el mix (-20,2) queda
	# por encima del de la vaina (-21,5) aunque el WAV tenga menos pico.
	"mag_drop": {"stream": preload("res://assets/audio/mag_drop.wav"), "db": -16.0, "bus": BUS_WORLD},
	# El roce del cargador contra el brocal mientras sube: es el tramo que iba
	# mudo entre que el lleno entra en cuadro y asienta. Suena al entrar y su
	# cola muere justo en el clack del asiento.
	"mag_insert": {"stream": preload("res://assets/audio/mag_insert.wav"), "db": -14.0, "bus": BUS_WEAPONS},
	"footstep": {"stream": preload("res://assets/audio/footstep.wav"), "db": -14.0, "bus": BUS_WORLD},
	# Impactos: cada material es una grabacion DISTINTA (Sonniss #GameAudioGDC
	# 2017/2019 y Freesound CC0; procedencia exacta en CREDITS_AUDIO.md). No hay
	# pitch-shift ni EQ de un material para fingir otro.
	#
	# Los seis WAV vienen normalizados a PICO -1,2 dBFS por
	# `tools/build_impacts.py`, pero NO comparten media: su factor de cresta va de
	# 14,2 (chapa fina) a 29,2 dB (ricochet), asi que a igual pico el ataque del
	# acero queda 10,3 dB por encima del estampido y el del ricochet 0,4 dB por
	# encima. Los `db` de abajo igualan el ATAQUE medido (RMS de los primeros
	# 40 ms) de la familia dentro de 4,1 dB y lo dejan 4,1-8,1 dB por debajo del
	# estampido, que es lo que hace que el disparo domine:
	#
	#   sonido             ataque 40 ms (WAV)   db    ataque en el mix
	#   shot_* (familia, 3 tomas) -12,79 media -5,5       -18,29  (medido 2026-09-19)
	#   impact_metal             -9,13        -18,5       -27,63  ->   9,3 dB por debajo
	#   impact_concrete         -11,98        -17,0       -28,98  ->  10,7 dB por debajo
	#   ricochet                -18,53        -10,5       -29,03  ->  10,7 dB por debajo
	#   impact_drywall          -13,71        -17,0       -30,71  ->  12,4 dB por debajo
	#   impact_wood             -15,99        -15,0       -30,99  ->  12,7 dB por debajo
	#   impact_aluminum         -14,06        -19,0       -33,06  ->  14,8 dB por debajo
	#
	# Aluminio, madera y pladur no los ata el ataque sino el RMS de la muestra:
	# a igual ataque su RMS en el mix quedaba por encima del estampido (-34,5),
	# porque son cortos y densos (cresta 16,5-14,2) frente a la cola larga del
	# disparo. El pico mas alto de la familia en el mix es el del ricochet, -11,7,
	# 4,7 dB por debajo del pico del disparo (-7,0).
	"impact_concrete": {"stream": preload("res://assets/audio/impact_concrete.wav"), "db": -17.0, "bus": BUS_WORLD},
	"impact_drywall": {"stream": preload("res://assets/audio/impact_drywall.wav"), "db": -17.0, "bus": BUS_WORLD},
	"impact_metal": {"stream": preload("res://assets/audio/impact_metal.wav"), "db": -18.5, "bus": BUS_WORLD},
	"impact_aluminum": {"stream": preload("res://assets/audio/impact_aluminum.wav"), "db": -19.0, "bus": BUS_WORLD},
	"impact_wood": {"stream": preload("res://assets/audio/impact_wood.wav"), "db": -15.0, "bus": BUS_WORLD},
	"ricochet": {"stream": preload("res://assets/audio/ricochet.wav"), "db": -10.5, "bus": BUS_WORLD},
	# Silbido de paso de bala: solo cuando el proyectil cruza cerca del oido
	# (ver Ballistics.gd), nunca por disparar.
	"bullet_flyby": {"stream": preload("res://assets/audio/bullet_flyby.wav"), "db": -12.0, "bus": BUS_WORLD},
	# Vaina al tocar el suelo. Antes -14,0: su ataque (RMS de 40 ms) en el mix
	# era -26,1, practicamente el del estampido (-24,9), asi que la vaina sonaba
	# como un segundo disparo. A -20,0 el ataque queda 7,1 dB por debajo y el
	# pico 14,5: se lee DESPUES y aparte, que es lo que pide el diseno. El
	# "despues" lo pone Glock.gd; aqui solo se le da el nivel.
	"shell_drop": {"stream": preload("res://assets/audio/shell_drop.wav"), "db": -20.0, "bus": BUS_WORLD},
}

const SHOT_STREAMS: Array[AudioStream] = [
	preload("res://assets/audio/shot_1.wav"),
	preload("res://assets/audio/shot_2.wav"),
	preload("res://assets/audio/shot_3.wav"),
]

# Nivel del disparo. Los tres WAV son tres eventos del mismo master de sound
# design (ataques -12,90/-12,47/-13,00, dispersion 0,53 dB medida 2026-09-19).
# Esa coherencia sirve para mezcla; NO convierte la fuente en una Glock real.
#
# -5,5 y no -6,5: +1 dB de cuerpo para que el estampido domine sin pedir mas
# pico del necesario (pico en el mix -6,0 dBFS). Cabe porque el ducking de
# `play_shot` impide apilar colas: a 6 tiros/s el pico es el de una sola voz.
#
# Ataque (RMS de 40 ms) en el mix y margen sobre el resto:
#   disparo          -12,79 + -5,5 = -18,29 (media de las 3 tomas)
#   impacto metal     -9,13 + -18,5 = -27,63  ->   9,3 dB por debajo
#   impacto concreto -11,98 + -17,0 = -28,98  ->  10,7 dB por debajo
#   mecanica mas alta mag_drop         -15,12 + -16,0 = -31,12  ->  12,8 dB por debajo
#   paso (mundo)      footstep         -12,13 + -14,0 = -26,13  ->   7,8 dB por debajo
# El pico mas alto del proyecto es el del disparo (-6,0); el siguiente es el del
# ricochet (-11,7).
#
# OJO, headroom en rafaga: sin ducking convivian ~5 blasts de 380 ms y el RMS
# conjunto subia ~7 dB. Con ducking (colas viejas apagadas a los 120 ms) a
# 13 tiros/s el peor caso seco mide -1,49 dBFS con 0 muestras al ras. El layout
# de buses (`default_bus_layout.tres`) NO tiene limitador en Master y esta
# pasada no lo ha tocado: si en captura se oye recorte a cadencia maxima, el
# sitio para arreglarlo es el bus, no estos WAV.
const SHOT_DB := -5.5

# Voces simultáneas del arma. El presupuesto de 16 se conserva por margen ante
# solapamientos de blast + mecánica; la prueba offline de ~13 tiros/s es un
# stress test de mezcla, NO una afirmación de que la G19 semiautomática dispare
# continuamente con el gatillo sostenido.
const MAX_WEAPON_VOICES := 16
const VOICE_FADE := 0.06
## Edad a la que una cola de estampido se apaga al llegar el siguiente tiro, y
## duracion de ese apagado. 120 ms cubre transiente + cuerpo; lo que muere es
## reverberacion de sala apilada, no el disparo.
const BLAST_DUCK_AGE := 0.12
const BLAST_DUCK_FADE := 0.05

var _weapon_voices: Array[AudioStreamPlayer] = []
var _blast_voices: Array = []


func _ready() -> void:
	_validate_buses()


## El layout es una dependencia de produccion. Si falta o alguien rompe un
## envio, se grita: no se crea una sala de repuesto ni se hornea reverb en WAV.
func _validate_buses() -> void:
	for bus_name in [BUS_RANGE, BUS_WEAPONS, BUS_WORLD]:
		if AudioServer.get_bus_index(bus_name) < 0:
			push_error("Falta el bus de audio obligatorio: " + bus_name)
	var range_index := AudioServer.get_bus_index(BUS_RANGE)
	var weapons_index := AudioServer.get_bus_index(BUS_WEAPONS)
	var world_index := AudioServer.get_bus_index(BUS_WORLD)
	if weapons_index >= 0 and AudioServer.get_bus_send(weapons_index) != BUS_RANGE:
		push_error("Weapons debe enviar a Range")
	if world_index >= 0 and AudioServer.get_bus_send(world_index) != BUS_RANGE:
		push_error("World debe enviar a Range")
	if range_index >= 0 and AudioServer.get_bus_send(range_index) != "Master":
		push_error("Range debe enviar a Master")


## Sólo el estampido. El golpe mecánico lo emite Glock.gd cuando la corredera
## llega físicamente al tope trasero; mantener ambas autoridades separadas evita
## que una cola fija de audio se despegue del movimiento a otro FPS.
##
## Ducking de colas: al disparar, los estampidos anteriores con mas de 120 ms se
## apagan en 50 ms. Sin esto, en rafaga conviven 5-6 colas de 380 ms que se
## apilan con la reverb hasta saturar y embarran el transiente (lento + sucio).
## El transiente nuevo queda intacto; solo muere la cola vieja. Medido offline:
## a 6 tiros/s el pico pasa de apilarse a ser el de una sola voz.
func play_shot() -> void:
	var stream: AudioStream = SHOT_STREAMS[randi() % SHOT_STREAMS.size()]
	# Variacion menor que las diferencias naturales entre tomas (medido
	# 2026-09-19: el pitch +-3,5 % desplazaba mas las bandas que la distancia
	# entre las dos tomas mas parecidas): la variacion la ponen los WAV, no el
	# randf. No debe cambiar la identidad/tamano aparente del arma.
	var p := _spawn(BUS_WEAPONS, stream, SHOT_DB + randf_range(-0.5, 0.5), randf_range(0.985, 1.015))
	_duck_old_blasts(p)


## Sonido no posicional. El bus lo declara la tabla según el sonido (el arma va
## a Weapons y el mundo a World), no la función: antes los pasos acababan en el
## bus del arma aunque el diseño dijera lo contrario.
func play_2d(sound_name: String, adjust_db: float = 0.0, pitch: float = 1.0) -> void:
	if not SOUNDS.has(sound_name):
		return
	var entry: Dictionary = SOUNDS[sound_name]
	_spawn(entry["bus"], entry["stream"], entry["db"] + adjust_db, pitch)


## Sonido del mundo, posicional. `adjust_db` matiza el nivel base de la tabla.
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
	p.unit_size = 3.0
	scene.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


func _spawn(bus: String, stream: AudioStream, volume_db: float, pitch: float, cap_voices := true, autoplay := true) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.bus = bus
	add_child(p)
	p.finished.connect(p.queue_free)
	# El limite protege SOLO las voces del arma. Un sonido 2D puede pertenecer
	# al mundo (los pasos locales son el caso actual) y no debe consumir el
	# presupuesto ni provocar que se corte blast/mecanica.
	if cap_voices and bus == BUS_WEAPONS:
		_limit_weapon_voices(p)
	if autoplay:
		p.play()
	return p


## Apaga las colas de estampido con mas de BLAST_DUCK_AGE al llegar un tiro
## nuevo. Solo blasts (este array), nunca mecanica: el clic de corredera y el
## clack del cargador viven por debajo y no apilan. El fade evita chasquidos.
func _duck_old_blasts(newest: AudioStreamPlayer) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var alive: Array = []
	for entry in _blast_voices:
		var voice: AudioStreamPlayer = entry[0]
		if not is_instance_valid(voice) or not voice.playing:
			continue
		if now - float(entry[1]) >= BLAST_DUCK_AGE:
			var fade := create_tween()
			fade.tween_property(voice, "volume_db", -60.0, BLAST_DUCK_FADE)
			fade.tween_callback(voice.queue_free)
		else:
			alive.append(entry)
	alive.append([newest, now])
	_blast_voices = alive


## Corta las voces más viejas del arma cuando se dispara muy seguido.
func _limit_weapon_voices(newest: AudioStreamPlayer) -> void:
	var alive: Array[AudioStreamPlayer] = []
	for voice in _weapon_voices:
		if is_instance_valid(voice) and voice.playing:
			alive.append(voice)
	_weapon_voices = alive
	_weapon_voices.append(newest)
	while _weapon_voices.size() > MAX_WEAPON_VOICES:
		var oldest: AudioStreamPlayer = _weapon_voices.pop_front()
		if not is_instance_valid(oldest):
			continue
		# Fade corto para que el corte no chasquee.
		var fade := create_tween()
		fade.tween_property(oldest, "volume_db", -60.0, VOICE_FADE)
		fade.tween_callback(oldest.queue_free)
