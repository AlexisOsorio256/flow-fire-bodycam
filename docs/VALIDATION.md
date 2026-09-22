# FlowFire — validación y tooling

Este documento define cómo demostrar que un cambio sirve. Los checks objetivos,
las capturas y los benchmarks responden preguntas distintas y no se sustituyen
entre sí.

## Regla de evidencia

- Estructura/contrato → check headless.
- Apariencia/pose/legibilidad → captura real.
- Rendimiento → benchmark del render real.
- Audio → WAV + mezcla real.

Un check estructural no certifica calidad visual. Un PNG negro nacido de un
proyecto que no cargó no cuenta como evidencia. Una teoría de culling no cuenta
como mejora de FPS.

## Checks principales

```bash
/home/alex/.local/bin/godot4 --headless --path . tools/check_weapon.tscn
/home/alex/.local/bin/godot4 --headless --path . tools/check_reload.tscn
/home/alex/.local/bin/godot4 --headless --path . tools/check_slide_lock.tscn
/home/alex/.local/bin/godot4 --headless --path . tools/check_weapon_fx.tscn
/home/alex/.local/bin/godot4 --headless --path . tools/check_range_shell.tscn
```

Cobertura:

- `check_weapon.tscn`: piezas obligatorias, escala, referencia mecánica,
  contrato de brazos, clips, duraciones, esqueleto y presupuesto de triángulos.
- `check_reload.tscn`: validación antes de consumir cargador y mesa infinita.
- `check_slide_lock.tscn`: bloqueo visible con 39 mm de recorrido.
- `check_weapon_fx.tscn`: fogonazo visible incluso a 16 FPS y recursos de humo
  compartidos.
- `check_range_shell.tscn`: mallas, siete materiales exactos, PBR obligatorio,
  dimensiones, longitud de tramo y separación de objetos funcionales.

## Captura visual

`tools/captura.sh` es el capturador de referencia. Antes de capturar ejecuta un
preflight headless y aborta ante errores de parser, preload o recursos. También
falla si Godot termina mal o si no produce frames válidos.

Capacidades:

- acción concreta;
- frames nombrados por tiempo real de juego;
- cámara lenta con `--time-scale`;
- video normal y lento con audio sincronizado;
- `double_tap` por el flujo real de input;
- `--taps=N` y `--gap=segundos`.

`tools/review_contact_sheet.py` crea hojas de contacto para comparar acciones.

### Grip y brazos

`tools/frame_probe.gd` / `frame_probe.tscn` reportan transforms reales del
viewmodel por estado. `tools/bench_arms.py` usa esos datos para renderizar
cadera, ADS, recarga, inspección y retroceso antes de entrar al runtime. Es el
único banco offline de agarre: evita mantener un segundo renderer de cámaras
hardcodeadas que pueda separarse del frame real del juego.

La aceptación final de manos/dedos requiere revisar:

- grip a dos manos;
- contacto de dedos;
- magwell;
- retén;
- recámara/corredera;
- clipping durante `Reload`, `ReloadEmpty` e `Inspect`;
- lectura del recoil a velocidad normal.

## Benchmark de render

`tools/medir.sh` + `tools/bench_render.gd` miden frame time real entre frames
con vsync apagado. El wrapper:

- elimina JSON viejo antes de medir;
- falla si Godot devuelve error;
- falla ante parser/preload/resource errors;
- exige una línea `BENCH`;
- exige JSON no vacío.

Opciones relevantes:

- `--view=WxH`: viewport interno explícito;
- `--skin=0`: apaga sólo los brazos para atribuir coste.
- `--stress-fire=1 --fire-every=5`: dispara la Glock de producción contra el
  mismo blanco de acero por índice de frame. Sirve para medir picos de
  balística/FX/audio/casquillo sin que una corrida lenta reciba más disparos.

Atajos de wrapper:

- `tools/medir.sh base`: 120 frames, warmup 40.
- `tools/medir.sh perfil`: mismas ventanas con cortes de luces/sombras/mundo.
- `tools/medir.sh stress`: 600 frames, warmup 80 y un intento de disparo cada
  5 frames. `BENCH_FRAMES` / `BENCH_WARMUP` permiten ampliar una corrida sin
  cambiar el harness.

Para aceptar cambios en la ruta caliente del disparo se usan ventanas largas
(600 frames después del warmup) y varias corridas intercaladas A/B. El promedio
solo no basta: p95/p99 deben moverse en la misma dirección de forma reproducible.

## Producción de referencia

Configuración committed:

```text
salida                  1920×1080
3D interno              1920×1080
scaling 3D               default nativo 1.0 / bilinear
MSAA                     2x
range shell              31 mallas
LIGHT_CHUNK              14,4 m (BAY * 4)
LightmapGI               bake estático no direccional
luces de mundo runtime   0 en reposo (13 fuentes de bake)
ReflectionProbe runtime  0
```

Las medidas antiguas con 720p interno quedan fuera del baseline de aceptación.
El benchmark de `SubViewport` replica ahora el MSAA del proyecto cuando no se
fuerza `--msaa`, evitando medir accidentalmente sin antialias. La Intel HD 520
sigue siendo un proxy de desarrollo, no una promesa de Android.

La optimización LightmapGI + luces de bake fuera del runtime + post bodycam
abaratado cruzó **35 FPS promedio a 1080p nativo** en la HD 520. La aceptación
se basa en corridas repetidas y capturas A/B; p95 puede seguir por debajo de
35 FPS bajo variación térmica, por lo que aún hay margen para seguir afinando.

El stress-fire no sustituye ese baseline de reposo: es una prueba adversarial.
Con 600 frames / 120 disparos la ruta actual queda alrededor de 35 ms/frame de
media en esta máquina, y se usa sobre todo para detectar regresiones en las colas
p95/p99.

## Cómo aceptar una optimización

Una optimización de render entra a producción sólo si:

1. se compara contra el estado committed canónico;
2. usa el mismo escenario, warmup y cantidad de frames;
3. mejora frame time de forma repetible, no sólo una corrida aislada;
4. no desplaza el coste a draw calls/primitivas de forma peor;
5. se revisa una captura real A/B;
6. no oscurece globalmente ni destruye legibilidad;
7. no elimina normales, roughness, anisotropía, probes o MSAA por intuición;
8. README/docs se actualizan sólo después de aceptar el cambio.

Para cambios de iluminación, resolución interna, MSAA o segmentación, registrar
como mínimo:

- ms/frame promedio;
- p50/p95 si el bench los emite;
- draws;
- primitivas;
- resolución interna;
- MSAA;
- número de luces/probes;
- captura equivalente.

## Tooling de assets

`tools/build_arms.py`
: Constructor oficial de `fps_arms.glb`. Normaliza a metros, limpia geometría
  ajena, orienta/alinea el rig y hornea cinco clips a 100 FPS. La solución
  analítica de brazos existe sólo durante autoría Blender; al GLB llegan huesos
  deform + keyframes.

`tools/build_range_shell.py`
: Constructor de la carcasa del rango con UV a densidad física y sin texturas
  embebidas.

`tools/process_audio.sh`
: Regenera únicamente `magin.wav` y `magout.wav` desde
  `assets/audio/source/g36c_mag_in_out_excerpt.wav`. No depende de
  `/tmp/audio_backup`.

`tools/build_shot_real.py`
: Construye las cinco tomas raw de disparo sin HPF/EQ/fades/pitch/layers.

`tools/measure_shots.py`
: Mide duración, pico, RMS, cresta, ataque, cola y clipping. Es un guardarraíl
  técnico, no una evaluación perceptual.

`tools/build_impacts.py` / `tools/measure_impacts.py`
: Reconstruyen y miden impactos por material.

`tools/make_weapon_sounds.py`
: Sintetiza Foley que no existe grabado, como reset del gatillo y eventos
  mecánicos auxiliares.

## Reglas para cambios concurrentes

Un experimento no es producción hasta pasar el A/B anterior. Mientras esté
unstaged:

- no se documenta como estado final;
- no se mezcla con un commit no relacionado;
- no se revierte por accidente;
- si hace falta validar el estado canónico, se preserva byte por byte antes de
  sustituir temporalmente un asset.

Esto es especialmente importante para `range_shell.glb`, cuyo rebuild puede
ser binario y costoso de reproducir.
