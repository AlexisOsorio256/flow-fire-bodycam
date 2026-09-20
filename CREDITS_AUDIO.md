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

Los cinco disparos (`shot_1..5.wav`) tampoco pasan por ahí: son **48 kHz** mono
16-bit y los construye `tools/build_shot_real.py` desde UNA toma real de seis
disparos de una **Glock 18C 9×19** (ver la tabla de abajo). La toma es de un solo
arma, de una sola sesión y de un solo micrófono; el builder la corta a cinco
tomas de 160 ms con HPF de 36 Hz + pico a −0,5 dBFS + fade de 20 ms, sin pitch,
sin capas y sin cola sintetizada. **No es una Glock 19**, es la 18C (variante
selectiva de la 17 con compensador, misma familia 9×19): se declara aquí porque
el producto es una G19.

Los seis de impacto (`impact_*.wav`, `ricochet.wav`) tampoco pasan por
`process_audio.sh`: los corta `tools/build_impacts.py`, **cada uno de una
grabación distinta**, y se normalizan por **pico** (−1,2 dBFS) y no por media,
porque su factor de cresta va de 14,2 a 29,2 dB y una media común los dejaba
descompensados. El equilibrio de la familia vive en la tabla `SOUNDS` de
`scripts/GameAudio.gd`, medido sobre estos WAV.

## Familia arma (bus `Weapons`)

| archivo | fuente | autor / licencia | transformación |
|---|---|---|---|
| `shot_1..5.wav` | **5 tomas de UNA grabación real de Glock 18C 9×19** (6 disparos en una toma; se conservan los 5 menos recortados) | Pole Position Production — **Sonniss #GameAudioGDC Bundle 2016**, EULA comercial sin atribución | construidos por `tools/build_shot_real.py`; medidos por `tools/measure_shots.py`. Un arma, una sesión, un micro (MKH416 a 1 m fuera del eje); la sala la pone el bus `Range`, no el WAV |
| `magin.wav`, `magout.wav` | foley de cargador, micro MKH60 close-up — Sonniss #GameAudioGDC Bundle 2016 | Heckler & Koch G36C (Sonniss EULA) | cortes de `assets/audio/source/g36c_mag_in_out_excerpt.wav`; el clack del asiento cae ~60 ms dentro de `magin.wav` y `Glock.gd` lo adelanta ese tiempo |
| `empty_b.wav` | "9mm Handgun Being Dry Fired" | serøutōnin--deprivəd — https://freesound.org/s/674568/ — CC0 | alineado al ataque |
| `slide_rear.wav` | "Glock 19 Handgun Pistol Slide Cocking Sounds" (evento de 10,972 s) | jackthemurray — https://freesound.org/s/393734/ — CC0 | corte al ataque (tope trasero de la corredera) |
| `slide_battery.wav` | "Sig Sauer P229 Handgun slide rack.wav" (evento de 4,016 s) | nikkolaus — https://freesound.org/s/442560/ — CC0 | corte al ataque (vuelta a batería) |
| `slide_hand.wav` | "Metal Contact" (contact small metal box lid subtle hits) | SoundHolder / Sonniss #GameAudioGDC Bundle 2017, espejo `http://ftpmirror.your.org/pub/misc/sonniss2017/` — EULA comercial sin atribución | recortado |

### Los cinco disparos: qué es cada uno

Cinco tomas de la MISMA grabación real: `Glock_18_1m_left_off_axis_MKH416_clean_
Six_shots_x_1.wav` (96 kHz / 24 bit mono, 3,733 s, seis disparos). Un arma
(Glock 18C 9×19), una sesión, un micrófono (Sennheiser MKH416 a 1 m a la
izquierda del arma, fuera del eje). La toma es una ráfaga: los huecos entre
disparos van de 177 a 440 ms.

| archivo | qué es | fuente | autor | licencia |
|---|---|---|---|---|
| `shot_1.wav` | disparo real 2 de 6, anclado a su transitorio (0,341 s) | Sonniss #GameAudioGDC 2016, pack *Pole Position Production – Glock 18c* | Pole Position Production | EULA comercial de Sonniss, sin obligación de atribución |
| `shot_2.wav` | disparo real 3 de 6 (0,781 s) | ídem | ídem | ídem |
| `shot_3.wav` | disparo real 4 de 6 (0,988 s) | ídem | ídem | ídem |
| `shot_4.wav` | disparo real 5 de 6 (1,165 s) | ídem | ídem | ídem |
| `shot_5.wav` | disparo real 6 de 6 (1,349 s) | ídem | ídem | ídem |

El disparo 1 de 6 (0,121 s) se descarta por ser el más recortado de la toma
original (la librería normaliza a tope y deja rachas de ≤8 muestras al ras en
cada transitorio). Se conservan los cinco con menos muestras al ras, en orden
temporal; el builder lo decide con el dato, no con un número fijo.

Descartados para producción (investigados y medidos el 2026-09-20):

- **kante `glock_one_shot.wav` / `glock_rapid_fire.wav`** (Freesound 35799 /
  35800, **Glock 19 9 mm real**, CC BY 3.0): el propio autor declara que grabó en
  una galería interior y que el eco "no lo pudo quitar". Medido: entre los ocho
  disparos de la ráfaga la envolvente no baja de −15 dBFS, así que cada toma
  arrastra la cola de la anterior y no se puede aislar limpia. Referencia A/B.
- **serøutōnin--deprivəd 855652** (la familia anterior): no es una Glock grabada;
  su autor documenta que apiló .22 LR, .22 Magnum, .357 y .44 Magnum. Fuera.
- **Walther PPQ 9 mm** (Still North Media, CC0, 96 kHz/24 bit, `X_39P.wav`):
  real y muy seco, pero es **otra pistola**, solo tiene 3 tomas y su energía cae
  33 dB en 50 ms (sin cuerpo). Fuera por identidad y por cuerpo.
- **db465 `glock_fire`** (Freesound 865987): el autor declara que está
  **sintetizado por procedimiento**, no es una grabación de campo.
- **gsparrysound Glock 18** (Freesound 591428): salva de fogueo en un teatro.
- **JG_Booysen Glock G42** (Freesound 353093): es .380 y **CC BY-NC** (no
  comercial).
- **areniporgen Glock 19X** (Freesound 828786): Glock real pero de otra sesión y
  otro micro; mantenerla rompía la identidad de sesión.

### La cadena que se les aplica (`tools/build_shot_real.py`)

DSP mínimo y reversible, a propósito:

1. **Detección de los disparos**: picos de la envolvente de 1 ms; los rebotes de
   sala caen ≥4 dB por debajo del ataque de 40 ms y se descartan solos, sin
   umbrales por archivo.
2. **Selección**: se descarta la toma más recortada de la fuente (rachas de
   muestras a pleno uso) y se conservan cinco.
3. **Ventana de 160 ms**: el hueco más corto entre dos disparos de la ráfaga es
   177 ms; una ventana más larga metería el disparo siguiente dentro de la
   muestra. La sala NO se hornea: la pone el bus `Range`.
4. **HPF Butterworth de 4.º orden a 36 Hz**: fuera retumbe infrasónico, nada más.
5. **Normalización de pico a −0,5 dBFS** por toma (no común: cada toma conserva
   su ataque natural) y **fade de salida de 20 ms**, con 0 muestras al ras.

### Disparos: familia anterior (compuesta) y actual (real)

Medido con `tools/measure_shots.py`:

| | familia anterior (master compuesto 855652, 3 tomas) | familia actual (Glock 18C real, 5 tomas) |
|---|---|---|
| duracion | 380 ms | 160 ms (toma seca; la sala la pone `Range`) |
| pico | −0,50 en las tres | **−0,50 en las cinco** |
| **RMS** | −14,91 a −16,10 dBFS | **−17,54 a −18,60 dBFS** |
| **cresta** | 14,41 a 15,60 dB | **17,04 a 18,10 dB** |
| **ataque (40 ms)** | −12,47 a −13,00 (dispersion 0,53 dB) | **−13,93 a −14,92 (dispersion 0,99 dB, natural)** |
| **muestras al ras** | 0 | **0** |
| **120-400 Hz** | 0,158 a 0,180 | **0,071 a 0,087 (natural de la sesion)** |
| **cola (caida ultimos 30 ms)** | 14,4 a 18,6 dB | **12,3 a 13,5 dB (natural, todas decaen)** |

Criterios de aceptación (duración 140–450 ms, cresta 12–19 dB, pico ≤ −0,5 sin
recorte, ataque de 40 ms −18 a −6 dB, cola de 30 ms que decae ≥4 dB, ataque
dentro de 1,5 dB como RED anti-regresiones (no identidad); bandas solo
informativas): **las cinco variantes los cumplen**.

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
