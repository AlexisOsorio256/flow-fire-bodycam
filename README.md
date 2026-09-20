# FlowFire

Laboratorio FPS centrado en una sola Glock 19: ciclo mecánico, disparo,
proyectil, material, penetración, física, audio y feedback visual. El rango es
un instrumento pequeño de medición, no un mapa de juego.

## Contrato de producción

- Una autoridad por estado y por transformación. `Glock.gd` decide la mecánica;
  los demás scripts la representan o la hacen sonar.
- Una sola ruta de producción. Si falta un asset obligatorio, el arranque falla;
  no hay offsets históricos, piezas procedurales de reserva ni sistemas de
  armas genéricos. El arma y los brazos son obligatorios.
- Los problemas de asset se resuelven en Blender; los de gameplay, física y
  audio en Godot o en las herramientas offline que los producen.
- Los objetos declaran material y geometría. Los números de resistencia viven
  únicamente en `Ballistics.MATERIALS`.
- `CREDITS_MODELS.md`, `CREDITS_TEXTURES.md` y `CREDITS_AUDIO.md` son la fuente
  de atribución; Git conserva los assets y herramientas retirados.

## Arquitectura real

| Responsabilidad | Autoridad |
|---|---|
| Arranque y composición | `scripts/Main.gd` |
| Estado de Glock: munición, recámara, gatillo, corredera, recarga, inspección | `scripts/Glock.gd` |
| Piezas, sockets, escala y movimiento de la malla | `scripts/GlockWeapon.gd` |
| Montaje, pose, ADS, brazos y petición de clips | `scripts/GlockViewmodel.gd` |
| Retroceso rápido del arma y cesión lenta del conjunto | `scripts/GlockRecoil.gd` |
| Huesos humanos: cinco clips horneados | `AnimationPlayer` de `ArmsRig` (asset) |
| Fogonazo, humo y luz de boca | `scripts/WeaponFX.gd` |
| Proyectil, penetración, rebote e impulso | `scripts/Ballistics.gd` |
| Decals, partículas y sonidos de impacto | `scripts/ImpactFX.gd` + `GameAudio` |
| Cargador expulsado y casquillos | `scripts/MagazineDrop.gd`, `scripts/Shell.gd` |
| Arquitectura visual, colisiones de sala y luminarias | `scenes/RangeShell.tscn` |
| Materiales PBR de la sala (texturas externas) | `scripts/RangeShell.gd` |
| Estaciones balísticas, blancos y cuerpos físicos | `scripts/World.gd`, `scripts/Target.gd`, `scripts/Crate.gd` |

La escena principal es `scenes/Main.tscn`. Los autoloads son `GameAudio`,
`ImpactFX` y `Ballistics`. El renderer es Mobile y la física es Jolt.

## Glock 19: referencia y asset

La referencia física es una Glock 19 Gen5 stock: 185 × 128 × 30 mm, cargador
estándar de 15 cartuchos, recorrido de disparador aproximado de 12,5 mm y
recorrido de corredera de 39 mm. Esos datos no se modifican para hacerlos
coincidir con la malla.

El `g19_pistol.glb` canónico es una aproximación visual: mide aproximadamente
174 mm de largo, 127 mm de alto y 31 mm de ancho. Godot la importa en metros,
valida ese contrato y mantiene escala 1; no la estira ni corrige sus orígenes en
runtime. La diferencia de largo frente a la referencia real queda declarada,
no escondida.

Su árbol obligatorio es:

```text
Glock
├── Frame
├── Slide
├── Barrel
├── Trigger
├── Magazine
├── Muzzle
├── EjectionPort
├── SightRear
├── SightFront
├── Grip
└── Magwell
```

`Muzzle` cuelga de `Barrel`; `Grip` y `Magwell` de `Frame`; `EjectionPort`,
`SightRear` y `SightFront` de `Slide`. Si falta una pieza o un padre es
incorrecto, `GlockWeapon.build()` devuelve error y el viewmodel no arranca.
El pivote de retroceso sale de `Grip`.

El GLB **no lleva ninguna imagen dentro**: es geometría con un material y sus
texturas son los `assets/models/g19_pistol_Image_*.png` que el importador
extrajo y que hoy son la fuente única de los mapas del arma.

La Glock no está en un esqueleto. `Slide`, `Barrel`, `Trigger` y `Magazine` son
piezas rígidas con transform propio. La corredera recorre 39 mm, el cañón
retrocede inicialmente y luego cae, el gatillo gira sobre su pasador y el
cargador sale por su eje medido.

## Brazos y viewmodel

El viewmodel es deliberadamente mínimo:

```text
Viewmodel
└── PoseRoot              cadera / ADS / sprint / bob / sway / respiración
    └── BodyGive          cesión lenta del conjunto (GlockRecoil.give_*)
        ├── ArmsRig       fps_arms.glb
        └── WeaponGrip
            └── WeaponSocket   retroceso: única transformación del arma
                └── Weapon
```

Los brazos son un único asset de producción, `assets/models/fps_arms.glb`, y son
**obligatorios**: si falta, el viewmodel no arranca. Medido sobre el GLB y
comprobado por `tools/check_weapon.tscn`:

| qué | valor |
|---|---|
| mallas | 1 (`Arms_Mesh`) |
| triángulos | 13.536 |
| materiales | 1 (`arms`), con baseColor, metallicRoughness y normal |
| texturas | 3, todas 1024²; Godot las extrae a `fps_arms_arms_*.png` al importar |
| huesos | 51, todos deform, sin IK/constraints/helpers runtime; conserva los nombres del rig DJMaesen |
| clips | `Idle` 3,00 s · `Fire` 0,26 s · `Reload` 2,10 s · `ReloadEmpty` 2,35 s · `Inspect` 2,00 s |
| tamaño | 6,2 MB |

Su origen y licencia están en `CREDITS_MODELS.md`. El GLB de producción actual
proviene de DJMaesen, "animated pistol", normalizado y verificado mediante
`tools/build_arms.py` (`VERIFY OK`, `check_weapon.tscn OK`).

**El asset se autora en el espacio del arma** (el mismo sistema que
`g19_pistol.glb`: +Y arriba, −Z al morro, origen en la raíz del arma) con la mano
derecha empuñando y la izquierda acoplada en un agarre firme a dos manos.
Por eso no hay calibración en runtime: `mount_arms()` iguala la raíz del brazo a
la del arma con **una** operación medida, y `GRIP_POS` / `GRIP_ROT` siguen siendo
`(0,0,0)`. Cambiar la malla del brazo no obliga a tocar `GlockViewmodel.gd`.

**Los brazos no escriben el transform del arma.** `ArmsRig` cuelga de
`BodyGive`, así que recibe la cesión lenta del conjunto pero **no** el retroceso
rápido: el arma cabecea dentro del agarre, que es lo que hay que leer.
`WeaponSocket` sigue siendo la única autoridad del retroceso completo.

**El `AnimationPlayer` solo anima huesos humanos y no decide nada.** Reproduce
cinco clips —`Idle`, `Fire`, `Reload`, `ReloadEmpty`, `Inspect`— y quien los pide
es `Glock.gd` en sus propios hitos, que siguen siendo la autoridad de corredera,
gatillo y cargador. No hay `HandManager`, ni `ArmController` ni IK runtime.
`tools/build_arms.py` ya no recorta ventanas del donor: toma su malla/esqueleto,
hornea una escala/orientación base y genera las cinco acciones directamente a
100 FPS. `Reload`, `ReloadEmpty` e `Inspect` usan una solución analítica de
dos huesos **solo durante la autoría Blender** para preservar las cadenas de
brazo; al GLB exportado llegan únicamente huesos deform y keyframes horneados.

**Límite importante del agarre base:** la pose inicial de manos/dedos sigue
partiendo del fotograma 0 del donor, transformado de forma rígida al espacio de
nuestra G19 (escala total 0,84 sobre la normalización 0,01 y giro de 180°).
`Idle` modifica respiración e índice; el builder NO rehace de cero la flexión de
todos los dedos alrededor de la empuñadura. Por eso `VERIFY OK` demuestra
estructura, huesos y exportación, pero no certifica por sí solo anatomía,
contacto de dedos ni ausencia de clipping.

**Acciones autoradas actuales:** `Reload` mueve la muñeca izquierda por los
hitos 0,28 / 0,62 / 1,02 / 1,40 s con apertura de dedos, agarre táctico del
cargador e impacto de talón de palma contra la base del cargador; `ReloadEmpty`
calibra el carpo hacia la palanca del retén con pulsación activa de pulgar a
1,72 s y reacción de batería; `Inspect` orienta la pistola hacia delante en el
eje del rango con cabeceo y alabeo que exponen la recámara a la bodycam, pinza
real de corredera sobre las estrías superiores y hombros en reposo anatómico
natural sin contrarrotación de torso. Esos tiempos coinciden con la mecánica,
pero la aceptación final es perceptual: video normal para continuidad/peso y
cámara lenta/contact sheets para contactos, magwell, retén y recámara.

**Validación de grip:** `tools/render_grip_angles.py` renderiza siete vistas
estáticas (FPS, laterales, trasera, superior y dos 3/4) de la pose exportada.
`tools/check_weapon.tscn` protege el contrato estructural (1 malla, 30–60
huesos, cinco clips y duraciones); ninguno de esos checks debe citarse como
prueba de que una pose humana se ve bien.



## Rango de medición

`range_shell.glb` es sólo presentación estática: suelo, paredes, techo,
columnas, vigas, canaletas, luminarias, marcaciones y bullet trap. **No tiene
separadores de calle ni mamparas**: se quitaron a petición del dueño del repo
("no quiero que estén los fierros, debe estar sin eso para moverme por donde yo
quiero"). El rango es un pasillo abierto que se recorre entero.
Tiene pocas mallas y siete materiales PBR **sin una sola imagen dentro**: el GLB
es geometría con ranuras de material con nombre
(`Range_Concrete_Brushed`, `Range_Concrete_Floor`, `Range_Concrete_Wall`,
`Range_Luminaire`, `Range_Markings`, `Range_Oak_Trim`, `Range_Painted_Metal`) y
solo `baseColorFactor` como respaldo. Las texturas PBR reales son externas
(Poly Haven CC0, `CREDITS_TEXTURES.md`) y las enchufa `scripts/RangeShell.gd` al
arrancar, material por material. No contiene latas, cajas, drywall, blancos ni
metadatos balísticos. Sus colisiones, ReflectionProbe y luminarias viven en
`scenes/RangeShell.tscn`.

`World.gd` conserva únicamente las estaciones funcionales:

Distancias medidas sobre `World.gd` (la línea de tiro es z = 0):

- mesa de cargadores al puesto: **1,4 m** — 4 cargadores físicos de 15, única
  fuente de recarga; se regeneran solos porque es un banco de pruebas, no un
  inventario;
- **8–11 m**: barreras, muro de tablones de pino, torre de 4 cajas y bidones;
- **9,5–13,7 m**: latas, de pie sobre el bidón de 6,6 m y en el suelo (el caso
  de prueba de `thin_shell`);
- **14 y 18 m**: paneles de pladur penetrable, con entrada, salida y paso
  visibles;
- **18 m**: 5 blancos de papel;
- **27 m**: 3 placas de acero;
- **35 m**: 3 blancos de papel (agrupación);
- **50 m**: 1 placa de acero (caída y cero).

La sala es interior. `RangeShell.tscn` contiene **12 OmniLight3D de relleno**
distribuidas hasta z = -57 m y **1 SpotLight3D con sombra** sobre el puesto. Las
estaciones de 35 y 50 m quedan dentro de la cobertura del conjunto; no hay sol
atravesando el techo. El ambiente está controlado. Las luces del mundo excluyen deliberadamente la
capa 13 del viewmodel mediante `light_cull_mask = 4095`; Glock y brazos reciben
únicamente el KEY/FILL tenue definido en `GlockViewmodel.gd`, además del
postproceso fullscreen.

## Audio

Los WAV de runtime viven en `assets/audio/`. Las fuentes que reconstruyen
disparos e impactos viven en `downloads/`, ignorado por Git y fuera del
importador de Godot; `assets/audio/source/` conserva únicamente el excerpt de
G36C que todavía usa el Foley de cargador y lleva `.gdignore`. La única sala
sintética es el bus `Range`, reservado al mundo:

```text
Weapons (Glock + Foley cercano) ───────────────────→ Master
World (impactos/rebotes/pasos/vainas) → Range ─────→ Master
```

La topología vive en `default_bus_layout.tres`; `GameAudio.gd` la valida y no
crea buses ni reverb de repuesto en runtime. No se usa +6 dB ni HardLimiter como
sustituto de mezcla. Cada material tiene **su propia grabación** y su procedencia
está en `CREDITS_AUDIO.md`: ningún impacto es un pitch-shift de otro.

Cada sonido corresponde a un evento que existe: el golpe del cargador y de los
casquillos nace del contacto físico, el reset del gatillo es propio, y los
golpes de corredera están ligados a sus umbrales mecánicos. El estampido domina
la mezcla; la mecánica vive por debajo y el casquillo aparece después y en su
sitio del espacio.

La familia de disparo son **cinco tomas de una grabación real de Glock 17 9×19**
en galería exterior (Freesound 34982, `glock17_02.wav` por gezortenplotz,
CC BY 3.0). La ficha oficial publica el original como WAV 44,1 kHz / 16-bit /
estéreo. En este workspace el builder consume la preview HQ MP3 pública; cada
disparo está separado por varios segundos.
`tools/build_shot_real.py` detecta las tomas reales y corta cinco ventanas raw de
380 ms con 11 ms de pre-roll. No aplica HPF, EQ, fades, pitch ni capas. Cuando el
decode MP3 presenta overshoot por encima de 0 dBFS, baja la toma completa con una
ganancia uniforme hasta −0,1 dBFS antes de escribir PCM16; no cambia timbre ni
dinámica y evita añadir clipping. La escucha A/B humana prefirió B (raw), seguida
de C; D (pasada por `Range`) se percibía como un impacto. Por eso tanto el blast
como la mecánica cercana de la Glock van directos a `Master`. `Range` queda para
los sonidos del mundo.

Medido (`tools/measure_shots.py`, 2026-09-20): 380 ms en las cinco, pico
−0,10 dBFS, RMS −11,30 a −12,00 dBFS, cresta 11,20 a 11,90 dB, ataque de 40 ms
−5,61 a −6,81 dBFS (dispersión 1,20 dB) y 0 muestras al ras en los WAV finales.
La preview de entrada ya presenta saturación/overshoot en los transientes; la
ganancia uniforme de salida evita clipping nuevo pero no puede recuperar lo que
la preview ya perdió. Éste sigue siendo el límite técnico de la fuente gratuita.

Los impactos del mundo son posicionales con caída inversa y `unit_size = 12 m`.
Con los 3 m anteriores, una placa a 27 m caía 19 dB **solo por distancia**,
encima de su nivel base, y el impacto existía en la tabla pero no se oía en el
rango. Medido en la captura de `hero_normal`: el impacto lejano (bullet trap,
~+200 ms) sube ~9 dB y sigue 14–15 dB por debajo del estampido.


**Headroom, medido en vez de supuesto.** El gatillo da 10/10 disparos con taps a
0,12 s (~8,3/s) y sólo 2/10 a 0,11 s; esa es la cadencia práctica de estrés. El
blast usa pitch 1,0 y ganancia fija, sin ducking. Una captura real con
`SHOT_DB = −3,0` llegó a 0,0 dBFS; −5,0 todavía tocaba techo en la secuencia
rápida. La última captura PCM temporal medida a −6,0 dB dio **−0,6 dBFS máximo**. Después de
escucha humana, producción sube deliberadamente medio dB a **−5,5 dB** para ganar
presencia; por petición expresa no se repitió la batería de audio. Sigue sin
limitador, ducking ni `Range` en el blast. El raw conserva más energía que la
pasada C procesada, así que el número del fader no describe por sí solo la pegada.

**Sin ducking.** Cada voz de disparo termina por su propia señal `finished`; un
tiro anterior no desaparece porque llegue otro y no hay un tope artificial de
voces usado para esconder problemas de mezcla.

## Balística y física

`Ballistics.gd` es la única autoridad de:

```text
material + geometría + velocidad
→ penetración → velocidad de salida → impulso p_entrada - p_salida
```

La salida usa la forma de colisión que recibió el impacto. Una lata o un bidón
fino declara `thin_shell` y `wall_thickness`: se atraviesan sus dos paredes,
no el diámetro completo del cilindro. Una caja hueca está formada por seis
paneles reales; cada panel puede producir su propia entrada/salida y Jolt aporta
el torque por el punto de impacto. `Target` y `Crate` no inventan callbacks de
balística.

La tabla única mantiene separados `steel`, `aluminum`, `gypsum`, `pine`,
`paper` y `concrete`. ImpactFX conserva perfil, decal y partículas distintos para
cada uno, y audio propio para **acero, aluminio, pino, yeso y hormigón**. El
`paper` es la única excepción y está declarada: reutiliza la muestra del pino a
−10 dB, porque queda fuera de los materiales que el laboratorio pide diferenciar
y a 18 m lo que domina es la llegada del proyectil (`CREDITS_AUDIO.md`).

El proyectil nace en `Muzzle`, alineado con el ánima; fogonazo y humo usan la
misma dirección. El cero de miras es paralelo y explícito. La dispersión es
gaussiana, mecánica y con media cero: `SHOT_DISPERSION_SIGMA = 1,6 mrad` por
eje; se puede poner en cero para una comprobación.

## Herramientas y verificación

Las herramientas protegen preguntas objetivas, no una apariencia ceremonial:

- `tools/frame_probe.gd` + `.tscn`: imprime en JSON la transformación real de
  cada nodo del viewmodel en cada estado (cadera, ADS, recarga por hitos,
  inspección, pico de retroceso, sprint). Es la verdad del encuadre para el
  banco de Blender: sin esto el banco certifica una pose que el juego no dibuja.
- `tools/bench_arms.py`: **banco obligatorio antes del runtime**. Coloca la
  Glock y los brazos en el encuadre real (sacado del probe) y renderiza cadera,
  ADS, recarga, inspección y pico de retroceso desde el ojo y desde órbita
  sobre la empuñadura. Un AABB no certifica un brazo; una captura sí.
  **Sus vistas de órbita sobre la empuñadura son la autoridad para juzgar el
  agarre; su vista `eye` NO lo es**: reproduce el encuadre y la orientación del
  juego (con `--gunspace 1`, que es el valor por defecto, porque el importador
  glTF mete los assets en `(x, -z, y)`), pero queda un desplazamiento vertical
  residual de ~0,3 de cuadro respecto al juego, así que para juzgar el encuadre
  final manda la captura real (`tools/captura.sh`).
- `tools/build_arms.py`: constructor oficial de los brazos de producción
  a partir del donante "animated pistol" de DJMaesen. Normaliza la armadura a
  metros, limpia geometrías ajenas, orienta y alinea el túnel de puño y hornea
  los cinco clips a 100 fps en el espacio del arma con la raíz en identidad.
- `tools/build_range_shell.py`: reconstruye la arquitectura del rango (geometría
  con UV a densidad física, sin texturas dentro del GLB).
- `tools/medir.sh` + `tools/bench_render.gd`: frame time REAL del render (delta
  entre frames con vsync off), con `--view=WxH` para medir a 1080p en un
  viewport interno, y `--skin=0` para apagar sólo los brazos y poder atribuirles
  un coste (dos pasadas del mismo build, no un número de otra máquina).
- `tools/captura.sh` + `tools/shot.gd`: el ÚNICO capturador. Guarda frames de
  una acción concreta, nombrados por su tiempo de juego real en ms, y admite
  cámara lenta (`--time-scale`), así como grabación de video real
  (`record_normal` y `record_slow`) con audio sincronizado. La regresión de
  disparo real (`--action=double_tap`) encadena N taps press/release por el flujo
  de input del juego: `--taps=N` y `--gap=segundos` (por defecto 2 y 0,18 s; a
  0,18 s se disparan los 10, con 0,10 s el propio gatillo limita la cadencia).
- `tools/review_contact_sheet.py`: monta esos frames en una sola hoja de
  contacto por acción para mirarlos de una vez.
- `tools/coverage_arms.py`: mide oclusión del arma por los brazos sobre máscaras
  del banco (`captures/arms_bench/dj/_mask` + `_mask_gunonly`, generadas con
  `bench_arms.py --mask 1 [--hide-arms 1]`). PENDIENTE: las máscaras eye no
  contienen brazos en 4 de 6 estados; su 0 % actual es máscara vacía, no aprobado.
- `tools/check_weapon.tscn`: piezas obligatorias, contratos de escala,
  referencia mecánica de la Glock y contrato completo de los brazos (clips, sus
  duraciones, esqueleto sin huesos de autoría, raíz del brazo sobre la del
  arma, presupuesto de triángulos).
- `tools/check_reload.tscn`: la mesa de cargadores no se gasta si el arma
  rechaza la recarga, y se regenera sola.
- `tools/check_slide_lock.tscn`: el bloqueo de corredera es VISIBLE (39 mm y la
  ventana de expulsión abierta), no sólo correcto en el estado interno.
- `tools/check_range_shell.tscn`: pocas mallas/materiales, dimensiones del
  rango y separación de objetos funcionales.
- `tools/process_audio.sh`: procesamiento offline y medición de duración, peak,
  RMS, cresta y clipping. Los disparos y los impactos tienen sus propios
  constructores y este script no los toca.
- `tools/build_shot_real.py`: detecta los ocho disparos separados de la grabación
  de Glock 17 9×19 de Freesound 34982, conserva los cinco primeros y corta cinco
  tomas raw de 380 ms con 11 ms de pre-roll. Sin HPF/EQ/fades/pitch/capas; sólo
  ganancia uniforme hasta −0,1 dBFS cuando el decode MP3 presenta overshoot.
- `tools/measure_shots.py`: mide la familia de disparos contra sus criterios
  (duración 140–450 ms, cresta 10–19 dB, ataque de 40 ms −18 a −5 dB, cola de
  30 ms que decae ≥4 dB, 0 muestras al ras). Son guardarraíles técnicos: no
  dictaminan si el disparo suena grande, cercano o convincente.

- `tools/build_impacts.py` / `tools/measure_impacts.py`: reconstruyen y miden los
  seis impactos, uno por material y por grabación distinta.

Las fuentes que los builders de audio necesitan de verdad son **siete archivos:
la preview HQ de la Glock 17, dos MP3 de impacto y cuatro WAV de impacto**: los
archivos grandes de `downloads/` (la librería completa de sonido
de armas, los volcados de investigación) no hacen falta para reconstruir nada y
se han borrado. Comprobado después del barrido: reejecutar los builders da los
mismos WAV, byte a byte. `downloads/` lleva `.gdignore` para que Godot no importe
material de trabajo que nadie carga.

De los builders de assets, los de audio están verificados **reejecutándolos y
comparando bytes**: los cinco `shot_*.wav` y los seis `impact_*.wav` +
`ricochet.wav` salen idénticos byte a byte, así que son reconstrucciones de
verdad y no andamiaje de migración. Además imprimen su tabla de medidas al
construir, para que "suena flojo" no sea una opinión. Los de brazos y rango no
se han reejecutado byte a byte en esta pasada.
- `tools/make_weapon_sounds.py`: sintetiza el Foley que no existe grabado
  (reset del gatillo, caída del cargador, roce del brocal, retén).

Los checks estructurales se pueden ejecutar con `godot --headless --path .`.
La revisión visual se hace en una ventana real de Godot; un PNG vacío o un
inspector headless no certifica un viewmodel.

### Rendimiento medido

`tools/bench_render.gd` a 1080p en el viewport interno, 120 frames tras 40 de
calentamiento, en la máquina de prueba (Intel HD 520):

```text
Pass pasada (producción) 47,70 ms/frame  p50 47,62  p95 47,92  draws 278  prims 70.236
Baseline original         46,47 ms/frame  p50 46,67  p95 49,23  draws 315  prims 125.940
Pasada 2026-09-19 pre     49,19 ms/frame  p50 49,07  p95 50,89  draws 278  prims 70.236
Pasada 2026-09-19 post    45,56 ms/frame  p50 45,45  p95 45,83  draws 278  prims 70.236
Pasada 2026-09-20 audio   43,97 ms/frame  p50 42,59  p95 50,00  draws 278  prims 70.236
```

Misma máquina (Intel HD 520), mismo viewport 1080p, mismo benchmark. La
variación entre pasadas (±2 ms con draws/prims idénticos) es ruido de
compositor/vsync, no del contenido: el cambio de luz del viewmodel (misma
cantidad de luces, solo energías) no mueve el frame time. Las luces del mundo
siguen siendo ~50 % del frame (`sin_luces` 23,9 ms); la pasada de audio no toca
el render y conserva 278 llamadas y 70.236 primitivas.


Para regenerar los assets Blender:

```text
blender --background --python tools/build_range_shell.py   # carcasa del rango
blender --background --python tools/build_arms.py          # brazos (necesita el donante)
```

## Fuera de alcance

Multijugador, lobby, mapa, controles Android finales, vida/puntuación de
blancos, IK y más de una arma.

FlowFire busca más realidad con menos arquitectura: una Glock bien montada, dos
brazos que la agarran como una persona, un rango legible y una cadena
física/audiovisual que se pueda seguir sin buscar quién manda.
