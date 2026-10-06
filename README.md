# FlowFire Bodycam

Shooter bodycam singleplayer, pequeño y extremadamente pulido.
Una Glock. Godot 4.7, renderer Mobile.

Es un juego comercial para PC y móviles de gama media y baja: existe para
venderse, y solo se vende si es divertido. El realismo está al servicio de la
diversión, nunca al revés. Cada partida debe tener ritmo, tensión, decisiones y
variedad, y al terminar tiene que dar ganas de jugar otra en el acto. Lo
realista que no hace el juego más divertido sobra; lo especializado pero
aburrido no vende.

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
4. El juego lo desarrollan IAs y el entorno existe para quitarles fricción: lo
   que se juzga a ojo se ajusta viéndolo, lo que se juzga con números se ajusta
   con datos. `tools/` crece solo por fricción demostrada: si en varios frentes
   un modelo sigue perdiendo tiempo en lo mismo, eso entra. Cualquier modelo
   puede añadir, cambiar o borrar una herramienta si mide antes y después que
   ahorra tiempo sin bajar la calidad, y deja la medida en el commit. El commit
   que cierra un frente anota lo que más tiempo costó (`Fricción: ...`).
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
   documentos de proceso al árbol.

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
- `captures/` y `downloads/`: material local fuera de Git, nunca autoridad.
  `downloads/` guarda los originales de terceros y sus licencias para los
  créditos; no se borra.

## Inmutabilidad

Este README solo cambia con autorización explícita del propietario y un motivo
concreto. Ningún agente puede reinterpretar una orden general como permiso.
