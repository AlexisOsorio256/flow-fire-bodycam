# FlowFire Bodycam

Shooter bodycam singleplayer, pequeño y extremadamente pulido.
Una Glock. Godot 4.7, renderer Mobile.

Es un juego comercial para PC y móviles de gama media y baja: existe para
venderse, y solo se vende si es divertido. El realismo está al servicio de la
diversión, nunca al revés. Cada partida debe tener ritmo, tensión, decisiones y
variedad, y al terminar tiene que dar ganas de jugar otra en el acto. Lo
realista que no hace el juego más divertido sobra; lo especializado pero
aburrido no vende.

## Referencia

`docs/refs/` manda. `ref8_.jpg`: pasillo de casa de tiro (montantes vistos y
tablero OSB), cerchas rojas, lucernarios, ojo de pez con anillo oscuro, manos
enguantadas con el arma siempre en cuadro. `ref9_.jpg`: nave de hormigón con
paneles OSB exentos y soldado de negro con casco y chaleco.
`objetivo glock.mp4`: manejo del arma (recarga, corredera, inspección).
`objetivo disparo y radgolls.mp4`: disparo, impacto y caída. La sensación es
la de UNRECORD y Bodycam: cámara física, arma con masa, luz y exposición
creíbles, audio violento, caras de enemigos pixeladas como en un vídeo real.

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
   `python3 tools/check.py --ver`, con referencia y juego lado a lado.
7. El historial vive en Git. El código no lleva comentarios: ni de línea, ni
   de bloque, ni docstrings. Los nombres y la estructura lo explican; el código
   es limpio, eficiente y legible de arriba abajo.
8. Este README es el único documento de reglas. No se añaden créditos ni otros
   documentos de proceso al árbol.

## Inmutabilidad

Este README solo cambia con autorización explícita del propietario y un motivo
concreto. Ningún agente puede reinterpretar una orden general como permiso.
