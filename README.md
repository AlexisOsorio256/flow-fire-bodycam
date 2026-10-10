# FlowFire Bodycam

Shooter en primera persona con cámara de bodycam. Godot 4.7, renderer Mobile.
Se vende en PC (Steam, itch.io) y en Android (Google Play).

Lo que se busca: cámara de bodycam con ojo de pez, manos enguantadas con el arma
siempre en cuadro, arma con masa, luz y exposición creíbles, audio violento y
caras pixeladas como en un vídeo real. Buenos fps en equipos de gama baja, con
calidad realista y optimizaciones que no se ven.

## Qué manda

1. La orden directa del propietario en el chat.
2. Vender y divertir. Un cambio se juzga jugando: si no hace mejor la partida, no
   se hace. Lo realista que no divierte, sobra.
3. Lo más pequeño que funciona: menos código, menos archivos, menos assets y menos
   peso. Lo que no aporta se borra; su historia queda en git.
4. Lo que el propietario ya validó jugando no se cambia para parecerse a algo de
   fuera.
5. Ante una duda de estas reglas, gana la lectura que deja el juego más pequeño y
   más simple, y se anota en el commit.

## Reglas

- **Godot primero.** Lo que el motor ya hace (importar, físicas, luces,
  post-proceso, interfaz) se usa tal cual. Nada de sistemas propios que lo repitan.
- **Una autoridad por comportamiento.** Un disparo, un daño o un sonido se decide
  en un solo sitio.
- **Scripts de hasta 350 líneas, sin comentarios ni docstrings.** Los nombres
  explican el código.
- **Cuadro:** lo que cuesta fps se mide en un equipo de gama baja antes de subirlo.
- **Textos en lenguaje natural**, sin jerga ni mayúsculas de consola.
- **No debe parecer hecho por IA.** Lo desarrollan agentes, pero iconos, textos,
  voces e imágenes salen de una idea concreta, nunca de plantillas.
- **Blender es la autoridad** de modelos, mapas, rig y animación
  (`blender/AGENTS.md`). Las claves se ponen a mano, nunca por fórmula.
- **Imágenes:** el agente mira sus capturas y renders antes de dar algo por
  hecho. No envía pruebas al propietario; él juzga jugando.
- **Peso:** un fichero nuevo se justifica y se mide. Lo que se genera (cachés,
  exportaciones, capturas) no se versiona.
- **Cada cambio pedido por el propietario se hace y se sube:** commit y push a
  `main`, con lo que cambió. No quedan ramas abiertas.

## Definición de terminado

`python tools/check.py`: arquitectura (tamaños, comentarios, fichas, versión en un
solo sitio) y sintaxis de todos los scripts en un arranque headless de Godot.
Tarda unos segundos. Lo demás lo juzga el propietario jugando.

## Dónde está todo

- `AGENTS.md`: mapa del repo y modo de trabajo.
- `scripts/<dominio>/AGENTS.md`: cómo funciona cada dominio, sus trampas medidas y
  su deuda. Se toca solo cuando la lección volvería a morder.
- `blender/`: modelos, mapas y animación. `tools/`: pipelines (ver
  `tools/AGENTS.md`).

## Este README

Lo cambia el propietario con una orden en el chat. Si una regla no encaja en un
caso concreto, aplica la regla 5.
