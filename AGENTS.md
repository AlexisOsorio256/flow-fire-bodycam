# FlowFire Bodycam — reglas del agente

La constitución es `README.md`. Léela entera antes de tocar nada: manda sobre este fichero y
sobre cualquier prompt. Aquí sólo va el resumen operativo.

## Lo que no se puede romper

- **Gate**: `./tools/verificar.sh` tiene que quedar GREEN. Es la única autoridad de "funciona".
  Un check en rojo es un daño real: se arregla o se revierte. El gate no se toca para que pase.
- **Historial**: regla 14. Prohibido escribir en código o documento por qué se cambió algo, qué
  valor tenía antes, "pasadas", fechas, medidas que ya no aplican o aprobaciones del dueño. El
  historial vive en `git log`, que ya lo guarda.
- **Prosa**: regla 15. Un comentario no puede pesar más que el código que describe. Sólo dice
  QUÉ hace y QUÉ invariante protege, en presente.
- **Autoridad**: un comportamiento, un sitio (regla 5). Antes de añadir una capa, comprueba si la
  autoridad ya existe.
- **Autorías**: `README.md` y el contenido de `docs/refs/` no se tocan sin autorización
  explícita del dueño.
- **Sobreingeniería**: regla 4. Nada de dependencias, frameworks ni "sistemas" nuevos.

## Herramientas

| Para qué | Comando |
| --- | --- |
| El gate | `./tools/verificar.sh` (fase `rapido` = sólo parse) |
| Frame time | `tools/medir.sh base` — p50 ≤ 25 ms (40 FPS, regla 2) |
| Capturar encuadres | `SHOT_OUT=<dir> tools/captura.sh <encuadre>` |
| Capturar vídeo **con audio** | `SHOT_OUT=<dir>/hero.mp4 tools/captura.sh record_normal` |
| Métricas de imagen | `python3 tools/measure_perceptual.py <dir>` |
| Ficha y contrato | `docs/MAP.md`, `docs/REFS.md` |

El agente ve **imagen, vídeo y audio nativos**: pegar `hero.mp4` (con su audio) o pares de
captura en el chat vale más que cien fotogramas sueltos.

`tools/captura.sh` **abre ventana** en `DISPLAY=:0`: necesita permiso de terminal que pueda
lanzar procesos gráficos. Los encuadres válidos están en `tools/shot.gd::_place_combat`.
`hero_normal` y `hero_slow` NO escriben PNG: sólo sirven para grabar vídeo.

## La referencia visual

`docs/refs/ref8_mapa.jpg` es la **única** referencia: casa de tiro de tablero OSB, pasillo
central con rastreles vistos, techo de chapa con celosía y tubos fluorescentes encendidos. El
resto no se copia de ningún fichero: se **mira el juego**, se captura con `tools/captura.sh` y se
mide con `tools/measure_perceptual.py`.

Para el trabajo visual, usa la skill `correccion-visual`.

## Modo desatendido (el dueño se va y el agente sigue)

- Antigravity Desktop ejecuta **un turno largo**, no un bucle infinito: termina cuando el agente
  decide que acabó. Trabaja en tareas ACOTADAS con final claro, no en "mejorar el juego".
- **No esperes aprobación.** Una confirmación pendiente deja el trabajo parado hasta que el dueño
  vuelva. No pidas permiso para editar ni para ejecutar comandos.
- **Una vuelta, un commit**: `git add -A && git commit -m "vuelta N"`. Es lo único que permite
  revertir una vuelta sola en la mañana.
- **Gate rojo = revertir y parar**: `git checkout -- . && git clean -fd`.
- **El gate no ve la imagen.** `verificar.sh` comprueba que el juego funciona y que la ficha no
  miente; NO comprueba que se vea mejor. Ninguna vuelta se cierra sin un número de
  `measure_perceptual.py` antes y después; si no mejora, se revierte.
- **Tope de vueltas.** Fíjalo y párate. Sin tope, la deriva es invisible.
- **No suspender la máquina**, y comprobar UNA captura con la pantalla bloqueada antes de
  dejarlo: si el compositor deja de dibujar, el bucle mide capturas negras y "mejora" a ciegas.
