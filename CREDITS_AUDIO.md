# Créditos de audio

Sólo créditos: archivo actual, fuente, autor, licencia y qué se le hizo. La
investigación (pruebas, descartes y medidas) vive en la historia de Git, no aquí.

La mayoria de WAV se convierten a 44,1 kHz mono 16-bit con `tools/process_audio.sh`
(ffmpeg), alineados a su ataque y normalizados por familia. Los cuatro de Foley
sintetizado NO los toca ese script: los genera `tools/make_weapon_sounds.py`.
Los WAV de runtime estan versionados en `assets/audio/`. Las fuentes crudas
que necesitan `build_shot_real.py` y `build_impacts.py` viven en
`downloads/` (gitignored y fuera del importador de Godot); `assets/audio/source/`
solo conserva los excerpts que todavía consume el Foley heredado.

Los tres disparos (`shot_1..3.wav`) tampoco pasan por ahí: son **48 kHz** mono
16-bit y los construye `tools/build_shot_real.py` desde tres tomas reales de
UNA misma sesión de Glock, con HPF a 36 Hz + pico a −0,5 dBFS + fade. Sin
matching espectral ni trim de ataque común: la dispersión de ataque resultante
(0,53 dB) es natural. Los mide `tools/measure_shots.py`, que comprueba los
criterios de dinámica uno a uno (las bandas son informativas, no criterio).

Los seis de impacto (`impact_*.wav`, `ricochet.wav`) tampoco pasan por
`process_audio.sh`: los corta `tools/build_impacts.py`, **cada uno de una
grabación distinta**, y se normalizan por **pico** (−1,2 dBFS) y no por media,
porque su factor de cresta va de 14,2 a 29,2 dB y una media común los dejaba
descompensados. El equilibrio de la familia vive en la tabla `SOUNDS` de
`scripts/GameAudio.gd`, medido sobre estos WAV.

## Familia arma (bus `Weapons`)

| archivo | fuente | autor / licencia | transformación |
|---|---|---|---|
| `shot_1..3.wav` | **3 tomas REALES de Glock de UNA misma sesión** (tabla abajo) | serøutōnin--deprivəd, **`Creative Commons 0`** (texto leído en la página del sonido al descargarlo; ver la nota de licencias) | construidos por `tools/build_shot_real.py` con DSP mínimo y verificados con `tools/measure_shots.py`. Sustituyen a la familia anterior de 5 (Glock 19X + trio + Kodack forzados con matching espectral hasta ±12 dB/banda y trim común 0,00 dB): cinco identidades que sonaban a lotería. Y sustituyen, antes que eso, a cinco cortes de la Walther PPQ que medían **cresta 26,4-28,4 dB**: pico a tope (-1,00 dBFS) pero **RMS -27,4..-29,4 dBFS** y -20 dB a los 15 ms, o sea un chasquido fino sin cuerpo ni cola. La causa era la fuente (tomas de micro cercano: `X_39.wav` cruda mide **39,0 dB** de cresta), no el corte |
| `magin.wav`, `magout.wav` | foley de cargador, micro MKH60 close-up — Sonniss #GameAudioGDC Bundle 2016 | Heckler & Koch G36C (Sonniss EULA) | cortes de `assets/audio/source/g36c_mag_in_out_excerpt.wav`; el clack del asiento cae ~60 ms dentro de `magin.wav` y `Glock.gd` lo adelanta ese tiempo |
| `empty_b.wav` | "9mm Handgun Being Dry Fired" | serøutōnin--deprivəd — https://freesound.org/s/674568/ — CC0 | alineado al ataque |
| `slide_rear.wav` | "Glock 19 Handgun Pistol Slide Cocking Sounds" (evento de 10,972 s) | jackthemurray — https://freesound.org/s/393734/ — CC0 | corte al ataque (tope trasero de la corredera) |
| `slide_battery.wav` | "Sig Sauer P229 Handgun slide rack.wav" (evento de 4,016 s) | nikkolaus — https://freesound.org/s/442560/ — CC0 | corte al ataque (vuelta a batería) |
| `slide_hand.wav` | "Metal Contact" (contact small metal box lid subtle hits) | SoundHolder / Sonniss #GameAudioGDC Bundle 2017, espejo `http://ftpmirror.your.org/pub/misc/sonniss2017/` — EULA comercial sin atribución | recortado |

### Los tres disparos: qué es cada uno

Tres tomas de UNA misma sesión de Glock real (mismo arma, micro y sala), no por
el nombre del fichero sino por MEDIDA: con DSP mínimo (HPF + pico + fade) dan
dispersión de ataque natural de 0,53 dB, sin forzar nada.

| archivo | qué es | fuente (URL) | autor | licencia |
|---|---|---|---|---|
| `shot_1.wav` | **Glock real** (9 mm), toma 1 anclada al transitorio inicial (0,0417 s) | https://freesound.org/s/855652/ | serøutōnin--deprivəd | `Creative Commons 0` |
| `shot_2.wav` | **Glock real** (9 mm), toma 2 anclada al transitorio inicial (1,6531 s) | https://freesound.org/s/855652/ | serøutōnin--deprivəd | `Creative Commons 0` |
| `shot_3.wav` | **Glock real** (9 mm), toma 3 anclada al transitorio inicial (3,2204 s) | https://freesound.org/s/855652/ | serøutōnin--deprivəd | `Creative Commons 0` |

Eliminados de la familia anterior (medido 2026-09-19 con DSP mínimo):

- **Kodack `Pistol Shot`** (freesound 253736): única no-Glock, ataque +4,6 dB
  sobre el trío, cresta 9,5 (falla 12-18) y cola que apenas decae 4,7 dB.
  Envolvente incompatible homogeneizada a martillo: fuera.
- **Glock 19X de areniporgen** (freesound 828786): Glock real pero de otra
  sesión/micro, ataque 3 dB por encima del trío. Mantenerla rompía la
  coherencia de sesión que pide la familia: fuera (su fuente sigue registrada
  en `downloads/AUDIO_SOURCES.md`).

**Nota de licencias (honesta):** la cadena `Creative Commons 0` se leyó en la
página del sonido al descargarlo (pasada anterior) y está registrada en
`downloads/AUDIO_SOURCES.md`. Durante esta pasada **freesound.org devolvió HTTP
502**, así que no se pudo re-verificar en vivo, y Wayback no tiene instantánea
de este sonido. La cadena es la registrada, no inventada, pero **no está
verificada en esta pasada**. (El `ricochet.wav` sí se pudo verificar por
Wayback: ver su fila.)

### La cadena que se les aplica (`tools/build_shot_real.py`)

DSP minimo y reversible, a proposito (2026-09-19: se retiraron el matching
espectral, el modelado de cola y el trim de ataque comun porque convertian
cinco grabaciones incompatibles en una familia que pasaba los checks por
construccion, a costa de microdinamica, transiente y cola natural):

1. **Anclaje al verdadero transitorio inicial**: se detecta el pico real de boca
   (evitando anclarse 50 ms tarde en reflexiones de sala, como ocurria antes).
2. **HPF Butterworth de 4.o orden a 36 Hz**: fuera retumbe infrasonico, nada mas.
3. **Normalizacion de pico a -0,5 dBFS** por toma (no comun: cada toma conserva
   su ataque natural).
4. **Fade de salida de 30 ms** y comprobacion de 0 muestras al ras (sin clipping).

### Disparos: familia anterior (5, forzada) y actual (3, natural)

Medido con `tools/measure_shots.py` el 2026-09-19:

| | familia anterior (19X + Glock 3x + Kodack, con Spectral Matching) | familia actual (solo Glock 3x, DSP minimo) |
|---|---|---|
| duracion | 380 ms | 380 ms |
| pico | -0,50 a -2,18 dBFS | **-0,50 en las tres** |
| **RMS** | -13,26 a -15,11 dBFS | **-14,91 a -16,10 dBFS** |
| **cresta** | 12,62 a 14,19 dB | **14,41 a 15,60 dB** |
| **ataque (40 ms)** | -10,86 en las cinco (dispersion 0,00 dB, por trim comun) | **-12,47 a -13,00 (dispersion 0,53 dB, natural)** |
| **muestras al ras** | 0 | **0** |
| **120-400 Hz** | 0,232 a 0,249 (forzado a ~24 % en todas) | 0,158 a 0,180 (natural de la sesion) |
| **cola (caida ultimos 100 ms)** | 20,6 a 21,3 dB (forzada a 0,7 dB) | 14,4 a 18,6 dB (natural, todas decaen) |

Criterios de aceptacion (cresta 12-18 dB, pico <= -0,5 sin recorte, RMS >= -18 dBFS,
ataque dentro de 1,5 dB como RED anti-regresiones (no identidad), 250-450 ms con
cola que decae; bandas solo informativas): **las tres variantes los cumplen**.

### Foley sintetizado (sin master)

Estos no vienen de ninguna grabación: son eventos que estaban mudos y se
sintetizan en `tools/make_weapon_sounds.py`, que es su fuente y su licencia
(propia, mismo LICENSE que el codigo: Todos los derechos reservados). Regenerarlos es volver a
ejecutarlo y reimportar.

| archivo | evento | carácter |
|---|---|---|
| `trigger_reset.wav` | click del reset del disparador | sintesis 50 ms, un transitorio (ver `make_weapon_sounds.py`) |
| `mag_drop.wav` | el cargador golpeando hormigon | UN golpe (220 ms); cada contacto dispara uno con nivel/pitch por velocidad |
| `mag_insert.wav` | el cargador rozando el brocal al subir | metal contra metal, costillas y resorte |
| `slide_release.wav` | el retén de la corredera al soltarse | tic de acero corto y agudo |

## Familia mundo (bus `World`, enviado al bus de sala `Range`)

Los seis impactos son **grabaciones distintas entre sí**. Ninguno es copia,
pitch-shift ni EQ de otro del mismo set.

| archivo | qué es REALMENTE | fuente exacta (URL descargada) | autor | licencia (texto exacto) | transformación |
|---|---|---|---|---|---|
| `impact_metal.wav` | **Impacto de BALA REAL** sobre placa de metal pesada | `http://ftpmirror.your.org/pub/misc/sonniss2017/individual/Gamemaster%20Audio%20-%20%20Bullet%20Impact%20Sounds/bullet_impact_metal_heavy_08.wav` (`bullet_impact_metal_heavy_08.wav`) | Gamemaster Audio | **`THE SONNISS #GAMEAUDIOGDC BUNDLE LICENSING AGREEMENT`** | corte tight de 260 ms (fade 60 ms), ataque re-anclado, DC fuera, pico -1,2 dBFS. Centroide 2.430 Hz, 66 % de energía <800 Hz y 27 % >2,5 kHz: golpe seco, físico y metálico sin retumbe fofo de sala |
| `impact_concrete.wav` | **Impacto de BALA REAL** sobre ladrillo/hormigón | `http://ftpmirror.your.org/pub/misc/sonniss2017/individual/Gamemaster%20Audio%20-%20%20Bullet%20Impact%20Sounds/bullet_impact_concrete_brick_01.wav` (`bullet_impact_concrete_brick_01.wav`) | Gamemaster Audio | **`THE SONNISS #GAMEAUDIOGDC BUNDLE LICENSING AGREEMENT`** | corte de 220 ms (fade 50 ms), pico -1,2 dBFS. Centroide 3.380 Hz: crack mineral seco |
| `impact_aluminum.wav` | **FOLEY de chapa fina** (calibre 20) golpeada — nivel 3. La librería **no documenta la aleación**, así que NO se puede afirmar que la grabación sea de aluminio; sí es chapa fina, que es el comportamiento que pide el set (sin cuerpo, resonancia alta) | `http://ftpmirror.your.org/pub/misc/sonniss2019/individual/Airborne%20Sound%20-%20Elements%20Metal/Metal%2CCrash%2CConcrete%2CSheet%20Metal%2C20%20Gauge%2CSlow%2CComplex.wav` (`Metal,Crash,Concrete,Sheet Metal,20 Gauge,Slow,Complex.wav`) | Airborne Sound | **`THE SONNISS #GAMEAUDIOGDC BUNDLE LICENSING AGREEMENT`** (misma cita) | corte: un golpe aislado en 1,688 s, 160 ms, fade 45 ms, +12,6 dB de ganancia para llegar al pico, pico a −1,2 dBFS. 5.112 Hz de centroide, 0,6 % <800 Hz y 83,6 % >2,5 kHz: el material más agudo y con menos cuerpo de los seis |
| `impact_wood.wav` | **FOLEY de tabla de madera** golpeada/partida — nivel 3. Es un *crack* seco de madera real, no un bloque-instrumento | `http://ftpmirror.your.org/pub/misc/sonniss2017/individual/Double%20Trouble%20Audio%20-%20Wood%20Impacts%20and%20Debris/Impacts%20Soft%20-%20Short%2C%20Crack.wav` (`Impacts Soft - Short, Crack.wav`) | Double Trouble Audio | **`THE SONNISS #GAMEAUDIOGDC BUNDLE LICENSING AGREEMENT`** (misma cita) | corte del **primer** crack de la toma (0,009 s), 100 ms, fade 30 ms, pico a −1,2 dBFS. 1.612 Hz de centroide, 25,2 % <800 Hz: el más grave de los cuatro materiales "duros" |
| `impact_drywall.wav` | **PROYECTIL REAL** (flecha) contra un panel fino — nivel 2. No hay disponible ninguna grabación de bala contra pladur en ninguna fuente alcanzable sin login; esta es la única cosa real que atraviesa un panel | `https://freesound.org/s/802473/` ("Arrow in something thin"), descargado como preview `-hq` (184 kbps MP3) porque freesound.org exige cuenta para el original | Sadiquecat | **`Creative Commons 0`** — texto leído en la propia página del sonido al descargarlo (pasada anterior) y registrado en `downloads/AUDIO_SOURCES.md`. **Aviso honesto: NO se ha podido re-verificar de forma independiente.** freesound.org devolvió HTTP 502 toda la pasada, y Wayback **no tiene ninguna copia** de este sonido (`web.archive.org/cdx/search/cdx?url=freesound.org/*802473*` devuelve vacío; los snapshots de este autor sólo llegan a sonidos de 2021). La cadena es la registrada, no inventada, pero no está verificada en vivo | corte: 120 ms desde el ataque, fade 35 ms, pico a −1,2 dBFS. 2.647 Hz de centroide, 6,3 % <800 Hz: mucho más ligero que hormigón (36,8 %) |
| `ricochet.wav` | **RICOCHET de BALA REAL** con barrido Doppler (nivel 1). El espectrograma muestra el banco de armónicos cayendo de ~5,2 kHz a ~1,7 kHz en 500 ms | `https://freesound.org/s/30932/` ("bullet ricochet.wav", preview `-hq`, MP3) | aust_paul | **`Creative Commons 0`** — **re-verificado de forma independiente en esta pasada** sobre la copia archivada de la página del sonido (`http://web.archive.org/web/2024id_/https://freesound.org/people/aust_paul/sounds/30932/`, snapshot 2026-02-22): la página enlaza a `http://creativecommons.org/publicdomain/zero/1.0/` con la etiqueta literal *"Creative Commons 0"* y el texto *"You can copy, modify, distribute and perform the sound, even for commercial purposes, all without the need of asking permission to the author."* (freesound.org seguía en HTTP 502, por eso se usó Wayback) | corte del **primer** rebote (el segundo empieza en 0,992 s): 700 ms, fade 120 ms, pico a −1,2 dBFS. Sustituye a un recorte de 3,0 s de *The Warfare Library* (Pole Position) cuyo pico caía a 2,6 s y medía 423 Hz de centroide: **no era un ricochet, era un retumbe** |
| `bullet_flyby.wav` | "Bullet Impact Sounds" (`bullet_flyby_fast_05`) | `http://ftpmirror.your.org/pub/misc/sonniss2017/individual/Gamemaster%20Audio%20-%20%20Bullet%20Impact%20Sounds/bullet_flyby_fast_05.wav` | Gamemaster Audio / Sonniss 2017 — EULA sin atribución (misma cita) | alineado al ataque. **No tocado en esta pasada** |
| `shell_drop.wav` | "Metal_Shell_Spin_10" | BlondPanda — https://freesound.org/s/777923/ — CC0 | BlondPanda | `Creative Commons 0` | alineado al ataque. **No tocado en esta pasada**; sólo se le bajó el nivel en `GameAudio.gd` |
| `footstep.wav` | "Footsteps on concrete" | florianreichelt — https://freesound.org/s/459964/ — CC0 | florianreichelt | `Creative Commons 0` | alineado al ataque. **No tocado en esta pasada** |

### Lo que se descartó, y por qué

- **`impact_aluminum` como derivado de `impact_metal`**: retirado. Era un
  high-pass/treble/tempo del acero, es decir, el mismo material con otro color.
- **`impact_drywall` como copia de `impact_concrete`**: retirado. Era
  literalmente el mismo master (mismo MD5) con otro nombre.
- **`impact_wood` = "Wooden Blocks" (NearTheAtmoshphere, CC0)**: retirado. Era
  foley de un bloque de madera, no un golpe de proyectil sobre tabla; medía
  642 Hz de centroide y 64 % de energía <800 Hz, o sea un golpe sordo.
- **`ricochet` = Pole Position, *The Warfare Library***: retirado. La toma es una
  ametralladora real, pero el recorte de 3,0 s no contenía un rebote: su pico
  estaba en 2,6 s y su centroide medía 423 Hz. Ningún transitorio de esa toma
  (181 s analizados) supera 1 kHz de centroide, así que no hay de dónde sacar un
  zing.
- **Bala real contra pladur, aluminio o madera**: **no existe** en ninguna
  fuente alcanzable sin cuenta ni API key. Se buscó en los seis bundles Sonniss
  #GameAudioGDC (2016-2020, 1.566 packs inventariados), archive.org, Wikimedia
  Commons y OpenGameArt. El pack "Bullet Impact Sounds" de Gamemaster Audio sólo
  aporta a los bundles 4 archivos (hormigón, metal pesado, cuerpo, flyby); el
  pack completo es de pago y no está espejado.
- Esa conclusión se **corroboró con una segunda búsqueda independiente** (96
  archivos validados, tabla completa en `downloads/bullet_hunt/FINDINGS.md`,
  gitignored) que rastreó además los espejos de los bundles Sonniss en
  archive.org y reconstruyó URLs de previews de Freesound desde instantáneas de
  Wayback. Su veredicto, literal: **"Drywall/gypsum: nothing found on any
  reachable source"** y **"no real bullet-on-aluminium exists"**. El único
  impacto real sobre chapa fina que encontró es una bala de goma contra una lata
  (`sounddino.com`, **licencia sin verificar** ⇒ descartado por las reglas), y el
  único candidato real sobre madera (`Bullet_Drop_Wood_04`, que ya se midió aquí:
  632 Hz de centroide = sordo) es ambiguo por su propio nombre (*drop*). También
  avisó de dos candidatos de Freesound con licencia **CC BY-NC 3.0**
  (benjaminharveydesign 315858, LiamG_SFX 323070): **no comerciales, no se han
  usado**.

Los EULA de Sonniss conceden uso comercial mundial, libre de regalías y sin
obligación de atribución (la propia cláusula *"without attribution to the
original creator"*); se acredita igualmente por cortesía. Si se reemplaza un
WAV, se actualiza su fila en el mismo cambio.
