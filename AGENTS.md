# FlowFire Bodycam: mapa para agentes

Las reglas están en `README.md`. Aquí, el modo de trabajo y el mapa.

## Modo de trabajo

1. Lee el `AGENTS.md` del dominio que vas a tocar, y `tools/AGENTS.md` si vas a
   medir o exportar.
2. Haz el frente entero dentro de su dominio. Si toca otro, lee también su ficha.
3. `python tools/check.py` antes de subir. Es la definición de terminado.
4. Commit y push a `main`, con lo que cambió y, solo si costó algo, la fricción
   (`Fricción: ...`).
5. Ficha del dominio: solo la lección que volvería a morder y la deuda que cambia.
   Lo que queda sin hacer, una línea `- Pendiente: ...` en su «Deuda».

Sin frente asignado: `python tools/check.py --informe` lista los dominios por
tamaño y pendientes, y los ficheros más pesados del repo. Ataca el primero.

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
| `blender/` | modelos, mapas, rig y animación |
| `tools/` | comprobaciones, exportadores y pipelines de audio y texturas |

`shaders/` y `scenes/` son del juego. `captures/` y `build/` son locales y
regenerables: nunca autoridad.

Las teclas viven en `project.godot` (sección `[input]`). Un script pide la acción
(`move_forward`, `ui_accept`…), nunca un `KEY_*` ni `Input.is_key_pressed`.

## Lo que comprueba la máquina

Lo que dice `README.md`, en la práctica: ningún script de más de 350 líneas, sin
comentarios ni docstrings, ningún script suelto fuera de un dominio, una ficha por
dominio, la versión en un solo sitio y la sintaxis de todos los scripts. Nada más.
