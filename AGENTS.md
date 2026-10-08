# FlowFire Bodycam: mapa para agentes

Las reglas están en `README.md` (constitución: léela entera una vez). Aquí, el
modo de trabajo y el mapa. Cada carpeta de dominio tiene su `AGENTS.md`: léelo
antes de tocarla; no hace falta leer más.

## Modo de trabajo

1. Lee el `AGENTS.md` del dominio que vas a tocar y, si vas a ver o medir,
   `tools/AGENTS.md`.
2. Resuelve el frente entero dentro de su dominio; si toca otro, lee también su
   `AGENTS.md`.
3. `python3 tools/check.py` es la definición de terminado y tarda menos de un
   segundo: arquitectura y sintaxis. No hay nada más que correr, y un cambio
   pedido por el propietario no espera a ninguna prueba: se hace y se sube.
4. La ficha del dominio se toca solo cuando la lección volvería a morder o la
   deuda cambia de verdad. Lo que dejas sin hacer, una línea
   «- Pendiente: ...» en su «Deuda».
5. Commit y push por frente, con lo que cambió. La medida y la fricción, solo
   si las hubo.

Sin frente asignado: `python3 tools/check.py --informe` lista los dominios por
tamaño y pendientes; ataca el primero.

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
| `tools/` | modelos, texturas, audio y paquetes |

`shaders/` y `scenes/` son del juego; `captures/` son imágenes locales,
regenerables, nunca autoridad.

## Lo que comprueba la máquina

Solo lo que cuesta menos de un segundo y evita romper el juego: que ningún
script pase de 350 líneas o lleve comentarios, que no haya scripts sueltos
fuera de un dominio, que cada dominio tenga ficha y que la versión del juego
viva en un solo sitio. Y la sintaxis de todos los scripts, en un arranque
headless.

No hay tablas de comprobaciones, ni capturas comparadas, ni medidores: eso
costaba minutos por cambio y el control de calidad es el propietario. No se
afloja una regla para que pase: se arregla el código o la ficha.
