# FlowFire Bodycam

Shooter bodycam singleplayer, pequeño y extremadamente pulido.
Una Glock. Godot 4.7, renderer Mobile.

Es un juego comercial para PC y móviles de gama media y baja: existe para
venderse, y solo se vende si es divertido. El realismo está al servicio de la
diversión, nunca al revés. Cada partida debe tener ritmo, tensión, decisiones y
variedad, y al terminar tiene que dar ganas de jugar otra en el acto. Lo
realista que no hace el juego más divertido sobra; lo especializado pero
aburrido no vende.

## Modo dinero

FlowFire está en modo dinero y esa es la máxima autoridad: todo gira en
torno a vender ya, en PC (Steam, itch.io) y en móvil (Google Play). Un
frente se elige y se juzga por cuánto acerca a la venta: que se pueda
descargar, que se entienda en 10 segundos de clip, que enganche a jugar
otra y que aguante las reseñas. La diversión y la calidad perceptual son
el medio para eso; el realismo cede en cuanto estorbe a la venta.

Nada que parezca hecho por IA. Iconos, textos, voces, imágenes y
promoción salen del juego propio o de una idea concreta que se pueda
defender, nunca de plantillas: nada de texto genérico sobre una captura,
poses de catálogo, adornos sin propósito ni frases de relleno. Si alguien
lo vería y pensaría "esto lo hizo una IA", se rehace.

## Autoridad

FlowFire manda. Una solución perceptual implementada y validada (la protege un
check o el propietario la dio por buena jugando) es la autoridad de esa
solución: el juego, `blender/` y `tools/checks/`. No se cambia para parecerse
más a algo de fuera.

Lo que se busca: cámara física de bodycam con ojo de pez, manos enguantadas
con el arma siempre en cuadro, arma con masa, luz y exposición creíbles, audio
violento y caras de enemigos pixeladas como en un vídeo real.

`docs/refs/` es material de trabajo, no autoridad. Una referencia externa solo
entra para una pregunta visual, de animación o de sensación que FlowFire aún no
ha resuelto, y solo si aporta algo concreto para resolverla; su nombre dice qué
pregunta es y `tools/refcmp.sh` la pone junto al juego. Solo vale para lo que
aún no está validado; cuando todo lo que mostraba ya lo está, quien cierra ese
frente la saca del árbol.

## Constitución

0. La diversión manda. Antes de añadir o pulir algo se pregunta si hace que
   jugar sea mejor; si no, no se hace. Se juzga jugando el juego real, no
   leyendo el código.
1. Calidad perceptual primero, con un suelo duro de 30 FPS estables en la
   máquina de referencia (Intel HD 520, 1080p). La resolución 3D es nativa
   (`scaling_3d` 1,0) y solo baja un escalón si la GPU no llega. Todo el
   margen por encima de 30 se invierte en calidad.
2. Más con menos: todo debe justificar su coste perceptual y técnico. Lo que no
   aporta al juego se borra (código, assets, herramientas, documentos).
3. Sobreingeniería prohibida. Una autoridad por comportamiento; módulos pequeños
   con una responsabilidad, legibles de arriba abajo sin el resto del proyecto:
   quien venga a cambiar una cosa lee solo el archivo que la contiene. Un script
   que pasa de unas 300 líneas o arrastra dependencias ajenas a su tarea se parte.
   Lo modular es lo eficiente, para el juego y para los modelos que lo editan.
4. FlowFire lo desarrollan solo IAs y el repositorio existe para que trabajen
   más rápido y con más calidad. Lo que se juzga a ojo se ajusta viéndolo, lo
   que se juzga con números se ajusta con datos. Una herramienta entra cuando
   ahorra tiempo o sube la calidad de forma medible, aunque sea grande: se mide
   antes y después y la medida va en el commit. Cada herramienta tiene un solo
   sitio y una línea en «Herramientas»; lo que no está ahí, un modelo nuevo no
   lo encuentra y lo vuelve a escribir. Cualquier modelo puede añadir, cambiar
   o borrar una herramienta con esa medida. El commit que cierra un frente
   anota lo que más tiempo costó (`Fricción: ...`).
5. Godot es el runtime. Blender, manejado por el Blender MCP, es la autoridad
   de modelos, mapas, rig y animación. La animación propia vive en
   `blender/<asset>.blend`: rig con controles (IK y polos), acciones con claves
   puestas a mano y una cámara `GameCam` idéntica a la del juego para juzgar
   las poses sin abrir Godot. Nunca keyframes generados por fórmula. Los
   scripts de `tools/` solo generan lo procedural (mallas, texturas), reproyectan
   animación importada, exportan y miden el juego. Lo propio manda sobre lo ajeno: un asset de
   terceros solo entra si no hay alternativa propia razonable y con licencia
   limpia, y se reemplaza en cuanto se pueda construir mejor.
6. Medir antes de afirmar. `python3 tools/check.py` es la definición de
   terminado: nada se da por acabado sin pasarlo. Cada fallo real corregido
   deja su comprobación en `tools/checks/<dominio>.txt`; nada especulativo.
   Lo visual se da por bueno solo tras mirar ampliada la imagen de
   `python3 tools/check.py --ver` o una hoja de capturas del juego.
7. La libertad de cada modelo es proporcional a lo que FlowFire puede
   verificar. Verde (el objetivo y todo lo que el cambio toca están medidos
   en `tools/checks/`: estados, munición, HUD, tiempos, importación,
   rendimiento): cualquier modelo cambia, pasa todos los checks y hace commit.
   Pasar los checks no vuelve verde un cambio que toca algo que ninguna tabla
   mide: eso es amarillo o rojo. Amarillo (ragdoll, animación, IA, shaders,
   optimizaciones visuales): además deja medidas y la imagen de `--ver` o una
   hoja de capturas para que el propietario la mire. Rojo (dirección visual,
   sensación de juego, audio, mecánicas nuevas, arquitectura): el modelo más
   fuerte disponible; un modelo que no sabe si lo es, no lo es: lo propone
   al propietario y no lo cambia. Nadie borra ni afloja un check para que
   pase; si está mal, se corrige con la medida en el commit. Quien resuelve
   algo nuevo deja su check y amplía lo verde. La autoridad por dominio se
   gana con resultados medidos, no con el nombre del modelo.
8. El historial vive en Git. El código no lleva comentarios: ni de línea, ni
   de bloque, ni docstrings. Los nombres y la estructura lo explican; el código
   es limpio, eficiente y legible de arriba abajo.
9. Este README es el único documento de reglas. No se añaden créditos ni otros
   documentos de proceso al árbol. FlowFire lo mantienen solo IAs, también
   modelos inferiores: quien cambia una regla comprueba que un modelo menor
   sin contexto, leyendo solo este README, la aplica en un frente real sin
   adivinar, y corrige solo donde falla.

## Dónde vive cada cosa

- `blender/fparms.blend`, `soldier.blend` y `factory.blend`: brazos, enemigo y
  mapa. Se editan por el Blender MCP y se exportan desde él
  (`execute_blender_code`) con `runpy.run_path(<script>, run_name="__main__")`
  de `tools/rebuild_arms.py`, `tools/export_soldier.py` y
  `tools/export_map.py`, que no imprimen nada y avisan con
  `/tmp/flowfire_{arms,soldier,map}_done`.
- `assets/models/*.glb`: salida de esos exportadores, nunca se editan a mano
  (salvo `g19_pistol.glb`, de terceros y sin `.blend`).
- `scripts/`, `shaders/`, `scenes/`: el juego. `tools/factory_import.gd` lo
  aplica Godot al importar el mapa.
- `tools/checks/`: lo medido, que ejecuta `tools/check.py`; las consultas de
  `--eval` viven en `tools/probes.gd`.
- `captures/`: capturas locales fuera de Git, regenerables, nunca autoridad.
- Los originales descargados de terceros no se guardan: lo que se usa vive en
  `blender/` o `assets/`, y una licencia que exige acompañar al asset va junto
  a él (`assets/fonts/OFL-*.txt`).

## Herramientas

Antes de escribir un script suelto, mira aquí: casi todo lo que hace falta
para ver, aislar y medir ya existe.

- `python3 tools/check.py [dominio..] [--ver]`: definición de terminado (unos
  80 s entero, 10-20 s un dominio). `--ver` deja `captures/check_ver.png` con
  el juego en reposo, apuntando e inspeccionando.
- `godot --fixed-fps 30 --path . tools/snap.tscn -- --mode=combat --out=X.png`:
  captura determinista del juego (unos 7 s). `--frames=N` es el cuadro de la
  captura (60 si no se da) y `--act=acción:K` la lanza K cuadros antes
  (`reload`, `rempty`, `inspect`, `iempty`, `aim`, `hip`, `shot`, `die`,
  `hit`, `hurt`...), `--shots=f1,f2`
  con `--sheet=4`, `--crop=x,y,w,h` en fracciones, `--pos`, `--yaw`, `--pitch`
  y `--eval=cuadro:expresión;...`. Imprime el tiempo de cuadro y de GPU. El
  desenfunde ocupa el arma hasta el cuadro 40 y lo que se pida antes se avisa
  con `ACT ... ignorada`.
- `tools/probes.gd`: las expresiones de `--eval`. Para saber qué es cada cosa
  en pantalla: `ids()` pinta cada pieza de brazos y arma de un color plano y
  devuelve la leyenda, `solo('arms,magazine')` deja solo esas piezas,
  `no_world()` quita el mundo y `parts()` las lista. Animación: `bones()`,
  `sample()`, `contact_end()`. Ragdoll: `fall_test()`, `fall_hit()`,
  `fall_summary()`. Pantalla: `screen(p)` a través de la lente, `sight_px()`,
  `hud_texts()`. Táctil: `touch(dedo, x, y, pulsado)` y `drag(dedo, x, y, dx, dy)` en fracciones de pantalla, con `--touch` en snap. Sonido: `sound.heard('radio_')` lista lo que sonó (cuadro,
  archivo, distancia y bus).
- `tools/package.sh`: exporta Windows, Linux y Android en 1 min y deja en
  `build/dist/` un archivo por plataforma listo para compartir (`.zip`,
  `.tar.gz` con el ejecutable que lleva el juego dentro, `.apk`). Los
  presets excluyen tools, blender, docs y captures. Android usa el SDK y el
  JDK de `~/.local/share/blockfire-tools/` (configurados en el editor).
- `[CROP=x,y,w,h] [SOLO=arms,...] [IDS=1] [NOWORLD=1] tools/sheet.sh nombre
  acción t1 t2..`: varios instantes de una acción en un arranque (unos 14 s),
  en `captures/<nombre>_sheet.png`.
- `python3 tools/build_audio.py`: regenera el audio sintetizado en unos 3 min
  con Piper (voz neuronal local en `~/.local/opt/piper`: `uv venv venv`,
  `uv pip install piper-tts` y `en_US-libritts_r-medium.onnx` de
  huggingface.co/rhasspy/piper-voices, CC BY 4.0):
  `assets/audio/voice/` (radio de aliados, gritos de enemigos, dolor, agonía
  y respiración) y `hit_thump.wav`. Las frases están en el propio script y
  `scripts/Voices.gd` decide quién habla.
- `tools/refcmp.sh [idle aim reload inspect fire hit fall]`: referencia y
  juego en el mismo encuadre, mientras su pregunta siga abierta.
- Blender, `v = runpy.run_path("tools/blender_view.py")`:
  `v["game"](clip, [t..], nombre, show="all"|"arms"|"weapon",
  color="MATERIAL"|"VERTEX")` es la vista del juego en 1 s por instante, con
  el FOV de `BodyCam.gd` y la lente ojo de pez de `HUD.gd`; su silueta
  coincide con la del juego (IoU 0,87-0,90). También `closeup()` de un hueso,
  `shift_keys()` y `turn_keys()` para mover o girar claves en ejes de cámara,
  y `plan()` del mapa. Los tiempos van en segundos y los clips se escriben
  como en el `.blend`: `Idle`, `Aim`, `Fire`, `Reload`, `ReloadEmpty`,
  `Inspect`, `Equip`.
- Blender, `m = runpy.run_path("tools/blender_mesh.py")`: `islands()` (islas
  de malla con su hueso), `stretch(clips=[..])` (islas más estiradas respecto
  al reposo, 1 s por clip) y `paint(marked=[..])` para verlas con
  `game(..., color="VERTEX")`; `paint([])` las borra antes de exportar.

## Inmutabilidad

Este README solo cambia con autorización explícita del propietario y un motivo
concreto. Ningún agente puede reinterpretar una orden general como permiso.
