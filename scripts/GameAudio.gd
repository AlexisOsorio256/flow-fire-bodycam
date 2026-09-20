extends Node

## Audio mixto con mix por buses: CC0, Freesound CC BY 3.0, Sonniss y sintesis propia.
## El disparo son CINCO tomas de una grabacion REAL de Glock 17 9x19 en campo
## de tiro exterior (Freesound 34982 por gezortenplotz, CC BY 3.0).
## `tools/build_shot_real.py` extrae 5 disparos aislados con ventana de 380 ms,
## transitorio agresivo, cuerpo de 9 mm y decaimiento natural (HPF 36 Hz + pico
## -0,5 dBFS + fade de 30 ms), sin sintetizar cola: la sala la pone el bus `Range`.
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
# El blast real ya trae mecanismo en la propia grabacion, pero estos dos son los
# transitorios cercanos cronometrados a la fisica (tope trasero y bateria, ver
# Glock.gd): sin ellos la corredera se mueve muda. Niveles bajos a proposito
# para no duplicar el blast. Su energia vive en agudos, donde el estampido ya
# no compite (medido 2026-09-20 sobre la familia real de 5 tomas: el trasero
# queda ~13 dB por debajo del blast en >2,5 kHz, presente sin competir). La
# bateria sube 3 dB porque quedaba 27 dB bajo la cola del disparo: inaudible, y
# el tiro perdia su peso.
const SOUNDS := {
	# Disparo en seco / gatillo. Un clic cercano debe quedar claramente por debajo
	# del estampido; el nivel se mantiene en -14 dB.
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
	# `tools/build_impacts.py`, pero NO comparten media. Los `db` de abajo se
	# conservan por material y dejan sus ataques medidos claramente por debajo del
	# blast actual:
	#
	#   sonido             ataque 40 ms (WAV)   db    ataque en el mix
	#   shot_* (5 tomas)         -8,96 media   -4,5       -13,46
	#   impact_metal             -9,13        -18,5       -27,63  ->  14,2 dB por debajo
	#   impact_concrete         -11,98        -17,0       -28,98  ->  15,5 dB por debajo
	#   ricochet                -18,53        -10,5       -29,03  ->  15,6 dB por debajo
	#   impact_drywall          -13,71        -17,0       -30,71  ->  17,3 dB por debajo
	#   impact_wood             -15,99        -15,0       -30,99  ->  17,5 dB por debajo
	#   impact_aluminum         -14,06        -19,0       -33,06  ->  19,6 dB por debajo
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
	preload("res://assets/audio/shot_4.wav"),
	preload("res://assets/audio/shot_5.wav"),
]

# Nivel del disparo. La familia son CINCO tomas de una grabacion real de Glock
# 17 9x19 (Freesound 34982, gezortenplotz, CC BY 3.0), con
# ventana de 380 ms y ataque de 40 ms -8,67 a -9,21 dBFS (dispersion 0,54 dB;
# ver `tools/measure_shots.py`).
#
# -4,5 dBFS: a igual pico integra el cuerpo y pegada completa del 9 mm exterior.
# Con SHOT_DB = -4,5 el ataque en el mix se situa en -13,17 a -13,71 dBFS (media
# -13,46 dBFS) y el pico en -5,0 dBFS, manteniendo dominio total sobre los impactos
# (ricochet pico -11,7 dBFS, 6,7 dB por debajo; metal ataque -27,6 dBFS, 14,2 dB
# por debajo) y sobre la mecanica del arma.
#
# Ataque (RMS de 40 ms) en el mix y margen sobre el resto:
#   disparo          -8,96 + -4,5 = -13,46 (media de las 5 tomas)
#   impacto metal     -9,13 + -18,5 = -27,63  ->  14,2 dB por debajo
#   impacto concreto -11,98 + -17,0 = -28,98  ->  15,5 dB por debajo
#   mecanica mas alta mag_drop         -15,12 + -16,0 = -31,12  ->  17,7 dB por debajo
#   paso (mundo)      footstep         -12,13 + -14,0 = -26,13  ->  12,7 dB por debajo
# El pico mas alto del proyecto es el del disparo (-5,0 dBFS); el siguiente es el
# del ricochet (-11,7 dBFS).
#
# Headroom SIN ducking (medido, 2026-09-20): suma seca nominal de 20 eventos,
# rotando las cinco tomas a pitch 1.0 y SHOT_DB=-4,5: pico -4,73 dBFS a 6/s,
# -2,87 a 10/s y -1,52 a 13/s, siempre con 0 muestras al ras. El runtime añade
# la variacion pequena declarada en play_shot(); una captura real con el bus
# Range dio pico -2,50 dBFS y 0 muestras al tope. El layout de buses
# (`default_bus_layout.tres`) NO tiene limitador en Master.
const SHOT_DB := -4.5


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
## SIN DUCKING. Hubo un `_duck_old_blasts()` que apagaba las colas anteriores a
## los 120 ms guardando sus voces en un array: la voz moria por su propio
## `finished -> queue_free` y el array seguia apuntando a un objeto liberado. En
## el segundo disparo (el primero ya terminado, 380 ms) eso reventaba con
## "Trying to assign invalid previously freed instance" y el juego se cerraba.
## Se elimino la logica entera en vez de taparla con `is_instance_valid`: ahora
## cada voz tiene UN solo dueño, su propia señal `finished`, y nadie la libera
## desde fuera. La mezcla se resuelve con la fuente, la ganancia y la sala.
func play_shot() -> void:
	var stream: AudioStream = SHOT_STREAMS[randi() % SHOT_STREAMS.size()]
	# Variacion menor que las diferencias naturales entre tomas (medido
	# 2026-09-19: el pitch +-3,5 % desplazaba mas las bandas que la distancia
	# entre las dos tomas mas parecidas): la variacion la ponen los WAV, no el
	# randf. No debe cambiar la identidad/tamano aparente del arma.
	_spawn(BUS_WEAPONS, stream, SHOT_DB + randf_range(-0.5, 0.5), randf_range(0.985, 1.015))


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
	# Alcance del rango con caida INVERSE_DISTANCE: `unit_size` es la distancia
	# a la que el sonido va a nivel pleno. Con 3 m (el valor anterior) una placa
	# a 27 m caia 19 dB SOLO por distancia, encima de su nivel base, o sea ~28 dB
	# por debajo del estampido: el impacto existia en la tabla y no se oia en el
	# rango. 12 m deja 18 m a -3,5 dB, 27 m a -7,0 y 50 m a -12,4, conservando la
	# distancia como pista y haciendo audible el material. Solo afecta a los
	# eventos del mundo: el disparo es 2D y las piezas cercanas caen dentro del
	# radio pleno, asi que su mezcla no cambia.
	p.unit_size = 12.0
	scene.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


## Una voz = un nodo = una señal. `finished` es el UNICO dueño de la vida del
## nodo: no hay array de voces, ni fades de corte, ni nadie que lo libere desde
## fuera. Si un sonido se solapa con el siguiente, se solapa: un disparo previo
## no desaparece porque llegue otro.
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
