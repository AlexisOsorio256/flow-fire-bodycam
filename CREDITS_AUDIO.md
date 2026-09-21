# Créditos de audio

Sólo créditos: archivo actual, fuente, autor, licencia y qué se le hizo. La
investigación (pruebas, descartes y medidas) vive en la historia de Git, no aquí.

`tools/process_audio.sh` sólo regenera `magin.wav` y `magout.wav` desde el
excerpt versionado `assets/audio/source/g36c_mag_in_out_excerpt.wav`; no usa
backups externos ni reprocesa otros masters. Los cuatro eventos de Foley
sintetizado los genera `tools/make_weapon_sounds.py`. Los WAV de runtime están
versionados en `assets/audio/`; las fuentes crudas que necesitan
`build_shot_real.py` y `build_impacts.py` viven en `downloads/` (gitignored y
fuera del importador de Godot). El Foley grabado restante está congelado en sus
WAV actuales y su procedencia figura en la tabla de esta página.

Los cinco disparos (`shot_1..5.wav`) tampoco pasan por ahí: son **48 kHz** mono
16-bit y los construye `tools/build_shot_real.py` desde una grabación real de
**Glock 17 9×19** en campo de tiro exterior (Freesound 34982, ver tabla). El
original publicado figura como WAV 44,1 kHz / 16-bit / estéreo; el builder de
este workspace consume su preview HQ MP3 pública, la baja a mono y remuestrea a
48 kHz. Extrae cinco tomas raw de 380 ms con 11 ms de pre-roll, sin HPF/EQ/fades,
pitch, capas ni cola sintetizada. Si el decode MP3 tiene overshoot, aplica sólo
ganancia uniforme hasta −0,1 dBFS antes de PCM16. Blast y mecánica cercana de la
Glock van directos a `Master`; `Range` queda para sonidos del mundo.

Los seis de impacto (`impact_*.wav`, `ricochet.wav`) tampoco pasan por
`process_audio.sh`: los corta `tools/build_impacts.py`, **cada uno de una
grabación distinta**, y se normalizan por **pico** (−1,2 dBFS) y no por media,
porque su factor de cresta va de 14,2 a 29,2 dB y una media común los dejaba
descompensados. El equilibrio de la familia vive en la tabla `SOUNDS` de
`scripts/GameAudio.gd`, medido sobre estos WAV.

## Familia arma (`Weapons` directo a `Master`)

| archivo | fuente | autor / licencia | transformación |
|---|---|---|---|
| `shot_1..5.wav` | **5 disparos separados de una grabación real de Glock 17 9×19** en galería exterior, Freesound 34982 (`glock17_02.wav`; original 44,1 kHz / 16-bit / estéreo) | gezortenplotz — https://freesound.org/people/gezortenplotz/sounds/34982/ — **Creative Commons Attribution 3.0 (CC BY 3.0)** | preview HQ MP3 pública → mono/48 kHz, 11 ms de pre-roll, corte raw de 380 ms; sin HPF/EQ/fades/pitch/capas. Sólo ganancia uniforme hasta -0,1 dBFS para evitar que el overshoot del decode clippee al escribir PCM16 |
| `magin.wav`, `magout.wav` | foley de cargador, micro MKH60 close-up — Sonniss #GameAudioGDC Bundle 2016 | Heckler & Koch G36C (Sonniss EULA) | cortes de `assets/audio/source/g36c_mag_in_out_excerpt.wav`; el clack del asiento cae ~60 ms dentro de `magin.wav` y `Glock.gd` lo adelanta ese tiempo |
| `empty_b.wav` | "9mm Handgun Being Dry Fired" | serøutōnin--deprivəd — https://freesound.org/s/674568/ — CC0 | alineado al ataque |
| `slide_rear.wav` | "Glock 19 Handgun Pistol Slide Cocking Sounds" (evento de 10,972 s) | jackthemurray — https://freesound.org/s/393734/ — CC0 | corte al ataque (tope trasero de la corredera) |
| `slide_battery.wav` | "Sig Sauer P229 Handgun slide rack.wav" (evento de 4,016 s) | nikkolaus — https://freesound.org/s/442560/ — CC0 | corte al ataque (vuelta a batería) |
| `slide_hand.wav` | "Metal Contact" (contact small metal box lid subtle hits) | SoundHolder / Sonniss #GameAudioGDC Bundle 2017, espejo `http://ftpmirror.your.org/pub/misc/sonniss2017/` — EULA comercial sin atribución | recortado |

### Los cinco disparos: qué es cada uno

Cinco tomas de la MISMA grabación real de campo:
`gunshot_glock17_outdoor_range.mp3`, preview HQ pública de Freesound 34982
(`glock17_02.wav`). La ficha oficial identifica una Glock 17 9×19 en galería
exterior. Los disparos están separados por varios segundos.

| archivo | qué es | fuente | autor | licencia |
|---|---|---|---|---|
| `shot_1.wav` | disparo real 1 de 8 (ventana desde 7,203 s) | Freesound 34982 (`glock17_02.wav`) | gezortenplotz | Creative Commons Attribution 3.0 (CC BY 3.0) |
| `shot_2.wav` | disparo real 2 de 8 (ventana desde 10,123 s) | ídem | ídem | ídem |
| `shot_3.wav` | disparo real 3 de 8 (ventana desde 19,152 s) | ídem | ídem | ídem |
| `shot_4.wav` | disparo real 4 de 8 (ventana desde 23,565 s) | ídem | ídem | ídem |
| `shot_5.wav` | disparo real 5 de 8 (ventana desde 28,799 s) | ídem | ídem | ídem |

El builder detecta las 8 tomas y conserva las cinco primeras en orden temporal;
ninguna métrica decide cuál "suena mejor". La preview de entrada llega ya
saturada en los transientes; los WAV finales no añaden clipping nuevo.

### La cadena que se les aplica (`tools/build_shot_real.py`)

DSP mínimo y reversible, a propósito:

1. **Detección de los disparos**: picos de la envolvente de 1 ms; los rebotes de
   sala caen ≥4 dB por debajo del ataque de 40 ms y se descartan solos.
2. **Pre-roll de 11 ms** antes del transitorio: conserva la entrada de la toma B
   raw que fue la preferida en la escucha A/B.
3. **Selección**: conserva las primeras 5 tomas reales en orden temporal.
4. **Ventana raw de 380 ms**: conserva transitorio, cuerpo y decaimiento tal como
   vienen de la grabación aprobada en B.
5. **Sin HPF, EQ ni fades**: no se vuelve a esculpir un disparo que ya funciona.
6. **Ganancia uniforme sólo para overshoot**: si el decode supera 0 dBFS, toda la
   toma baja hasta −0,1 dBFS antes de PCM16. En runtime Glock/Weapons van directos
   a `Master`; `Range` queda para el mundo.

### Disparos actuales: medidas técnicas

Medido con `tools/measure_shots.py`: las cinco tomas duran **380 ms**, tienen
pico **−0,10 dBFS**, RMS **−11,30 a −12,00 dBFS**, cresta **11,20 a 11,90 dB**,
ataque de 40 ms **−5,61 a −6,81 dBFS** y cero muestras al ras. La cola de los
últimos 30 ms decae **33,7 a 36,4 dB**. Son guardarraíles técnicos; no certifican
calidad perceptual.

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

Los EULA de Sonniss conceden uso comercial mundial, libre de regalías y sin
obligación de atribución (la propia cláusula *"without attribution to the
original creator"*); se acredita igualmente por cortesía. Si se reemplaza un
WAV, se actualiza su fila en el mismo cambio.
