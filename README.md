# FlowFire Bodycam

Shooter bodycam singleplayer, pequeño y extremadamente pulido.
Una Glock y un AR-15. Godot 4.7, renderer Mobile.

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

## Modo velocidad

La velocidad de desarrollo es un criterio de primer orden, igual que el dinero:
un frente se elige y se juzga también por cuánto acelera el siguiente. Si
arreglar algo cuesta cinco horas y en diez minutos estaba hecho y subido, el
trabajo está mal hecho aunque el resultado sea correcto.

El control de calidad es el propietario. Lo que él detecta o pide se hace y se
sube, sin pedirle prueba. La máquina no justifica cambios: solo evita romper el
juego, y tiene que costar menos que el cambio que protege. Un trámite que no
evita una rotura se borra; un documento, un dato o una regla que solo se
mantiene por costumbre, también.

Nada que parezca hecho por IA. Iconos, textos, voces, imágenes y
promoción salen del juego propio o de una idea concreta que se pueda
defender, nunca de plantillas: nada de texto genérico sobre una captura,
poses de catálogo, adornos sin propósito ni frases de relleno. Si alguien
lo vería y pensaría "esto lo hizo una IA", se rehace. Todo lo que el juego
dice (menús, botones, avisos) habla en lenguaje natural y explica qué
probar, sin jerga técnica, siglas ni mayúsculas de consola.

## Autoridad

Por encima de todo manda la orden directa del propietario en el chat. Después,
FlowFire manda. Una solución perceptual implementada y validada (el propietario
la dio por buena jugando) es la autoridad de esa solución: el juego y
`blender/`. No se cambia para parecerse más a algo de fuera.

Lo que se busca: cámara física de bodycam con ojo de pez, manos enguantadas
con el arma siempre en cuadro, arma con masa, luz y exposición creíbles, audio
violento y caras de enemigos pixeladas como en un vídeo real.

`docs/refs/` es material de trabajo, no autoridad. Una referencia externa solo
entra para una pregunta visual, de animación o de sensación que FlowFire aún no
ha resuelto, y solo si aporta algo concreto para resolverla; su nombre dice qué
pregunta es. Solo vale para lo que
aún no está validado; cuando todo lo que mostraba ya lo está, quien cierra ese
frente la saca del árbol.

## Constitución

0. La diversión manda. Antes de añadir o pulir algo se pregunta si hace que
   jugar sea mejor; si no, no se hace. Se juzga jugando el juego real.
1. DIRECTO A LA YUGULAR LO QUE SE PUEDA COMPROBAR CON IMAGENES EN BLENDER
   DE LO QUE SE HIZO SE SUBE COMMIT AND PUSH Y SE AVISA LA EFICIENCIA
   Y LA VELOCIDAD DE DESARROLLO DEL JUEGO ES LO FUNDAMENTAL.
2. Más con menos: todo justifica su coste perceptual y técnico. Lo que no
   aporta se borra (código, assets, herramientas, documentos).
3. Sobreingeniería prohibida. Una autoridad por comportamiento; módulos
   pequeños, legibles de arriba abajo sin el resto del proyecto. Un script de
   más de 350 líneas se parte.
4. FlowFire lo desarrollan solo IAs. Lo que se juzga a ojo se ajusta viéndolo;
   lo que se juzga con números, con datos. Una herramienta o comprobación entra
   cuando ahorra más tiempo del que cuesta; si cuesta más que el cambio que
   protege, no entra. El commit que cierra un frente anota lo que más costó
   (`Fricción: ...`) solo si costó algo.
5. Godot es el runtime; Blender, por el Blender MCP, es la autoridad de
   modelos, mapa, rig y animación (`blender/AGENTS.md`). Claves puestas a mano,
   nunca por fórmula. Lo propio manda sobre lo ajeno: lo de fuera se hace
   nuestro (rig, texturas y animación en nuestro `.blend`) hasta poder
   rehacerlo mejor. Las licencias y los modelos de fuera los lleva el
   propietario.
6. La orden del propietario es la medida. Lo que él detecta o pide se hace y se
   sube: no se le pide prueba ni se demora por demostrarlo, y lo que dice basta
   como motivo. `python3 tools/check.py` es la definición de terminado y tarda
   menos de un segundo: arquitectura y sintaxis, nada que arranque el juego ni
   tablas de comprobaciones. Lo que se ve, se oye o se siente lo juzga él
   jugando.
7. La libertad de cada modelo es total: ninguna verificación lo frena. Lo que se
   ve, se oye o se siente lo da por bueno el propietario jugando, así que un
   cambio de aspecto, de sensación, de audio o de mecánicas se sube y se le
   cuenta; si él ya lo pidió, está autorizado. Nadie afloja una regla para que
   pase: se arregla el código o la ficha.
8. El historial vive en Git. El código no lleva comentarios; los nombres y la
   estructura lo explican.
9. Este README son las reglas; cada dominio explica cómo funciona en su
   `AGENTS.md`, junto a su código. Lo aprendido con esfuerzo —una trampa que
   volvería a morder— va a la ficha del dominio en el mismo commit; no se anota
   lo obvio ni se reescribe la ficha por rutina. No se añaden otros documentos.
10. Crecer sin encarecer. Cada cambio deja FlowFire igual o más fácil de
   mantener: un modo, arma, enemigo o mapa nuevo entra como módulo propio de
   su dominio, se engancha en un solo sitio y trae sus checks. Si un cambio
   encarece lo siguiente (más archivos que leer, checks más lentos, peor
   tiempo de cuadro), se arregla en el mismo frente.

La máquina solo comprueba lo instantáneo: líneas, comentarios, scripts fuera de
un dominio y la versión en un solo sitio. Todo lo demás lo juzga el propietario
jugando.

## Dónde está todo

`AGENTS.md` es el mapa y el modo de trabajo; cada carpeta de dominio tiene su
`AGENTS.md` con cómo funciona, sus trampas medidas, sus dependencias y su
deuda. Las herramientas cargan solas el más cercano al archivo que se edita.

## Inmutabilidad

Este README solo cambia con autorización explícita del propietario y un motivo
concreto. Ningún agente puede reinterpretar una orden general como permiso.
