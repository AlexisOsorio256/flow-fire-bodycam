# FlowFire Bodycam: mapa para agentes

Las reglas están en `README.md` (constitución: léela entera una vez). Aquí, el
modo de trabajo y el mapa. Cada carpeta de dominio tiene su `AGENTS.md`: léelo
antes de tocarla; no hace falta leer más.

## Modo de trabajo

1. Lee el `AGENTS.md` del dominio que vas a tocar y, si vas a ver o medir,
   `tools/AGENTS.md`.
2. Resuelve el frente entero dentro de su dominio; si toca otro, lee también su
   `AGENTS.md`.
3. `python3 tools/check.py --cambios` mientras trabajas (solo los dominios
   tocados); `python3 tools/check.py` entero antes del commit.
4. Lo que te costó aprender, una línea en «Trampas medidas» del dominio. Lo que
   dejas sin hacer, una línea «- Pendiente: ...» en su «Deuda».
5. Commit y push por frente, con la medida y la fricción.

Sin frente asignado: `python3 tools/check.py --informe` ordena los dominios
por deuda; ataca el primero y deja la medida en el commit.

## Mapa

| Dominio | Qué hace |
|---|---|
| `scripts/armas` | lo que el jugador lleva en las manos; cómo añadir un arma |
| `scripts/balistica` | balas, penetración, impactos y lo que cae al suelo |
| `scripts/enemigos` | cuerpo, cerebro, heridas, reacciones y ragdoll |
| `scripts/jugador` | movimiento, daño, cámara de pecho y muerte |
| `scripts/partida` | arranque, modos, directores y ajustes |
| `scripts/red` | jugar con amigos en el mismo wifi |
| `scripts/interfaz` | lobby, HUD, pausa, fin y controles táctiles |
| `scripts/audio` | buses, catálogo de sonidos y voces |
| `scripts/comun` | piezas que usan varios dominios |
| `blender/` | modelos, rig, animación y exportadores |
| `tools/` | medir, ver, capturar, empaquetar |
| `assets/procedencia.txt` | de dónde sale cada asset y si ya es nuestro |

`shaders/` y `scenes/` son del juego; `captures/` son imágenes locales,
regenerables, nunca autoridad.

## Lo que comprueba la máquina

`check.py` vigila en menos de un segundo, antes de arrancar Godot: scripts de
más de 300 líneas, comentarios, scripts fuera de un dominio, fichas largas o
sin «Checks:» y «Usa:», dependencias entre dominios no declaradas (o
declaradas y ya sin uso), rutas y `Clase.miembro` citados en las fichas que ya
no existen, la versión del juego en un solo sitio, herramientas sin su línea y
assets sin procedencia. Cada fallo dice cómo arreglarlo. No se afloja una
regla para que pase: se arregla el código o la ficha.
