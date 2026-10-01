# REFS — contrato visual

Qué manda. No es la ficha del árbol (esa es `docs/MAP.md`): aquí está la única
referencia visual del proyecto y lo que ordena.

Regla al editar: cada número de aquí tiene que poder reproducirse con un comando
sobre un fichero que exista hoy. Un dato medido sin ruta de reproducción es una
afirmación, no una medida.

## 1. La referencia

`docs/refs/ref8_mapa.jpg` — 1200x800 · **193.402 B**. Es la única imagen que
manda; la puso el dueño con una frase: *"esa será el nuevo mapa"*.

**Casa de tiro de tablero OSB**: pasillo central con muros de rastreles vistos y
paneles OSB, suelo de tablero, techo de chapa con celosía de acero y **tubos
fluorescentes encendidos**, vanos sin puerta, cuarto lateral con lona oscura en
el suelo, soldado con casco, chaleco y rifle al fondo del pasillo, y **manos
enguantadas con el arma** en primer plano.

## 2. Qué manda en cada sistema

| Sistema | Lo que manda la referencia |
| --- | --- |
| Mapa | Pasillo central, cuartos a los lados, rastreles vistos, OSB, suelo de tablero, techo de chapa con celosía y tubos |
| Luz | Fluorescentes encendidos en el techo, sombra dura en los vanos |
| Enemigo | Soldado de negro con casco, chaleco y rifle, al fondo del pasillo |
| Punto de vista | Manos enguantadas y arma siempre en cuadro |
| Lente | Gran angular: la imagen llega hasta los bordes, con una caída suave en las esquinas |

## 3. Cómo se comprueba

El estado del juego no se compara contra ficheros: se **mira el juego**. Se
captura con `SHOT_OUT=<dir> tools/captura.sh <encuadre>` y se mide con
`python3 tools/measure_perceptual.py <dir>`; el frame time, con
`tools/medir.sh base`. Las cotas y los materiales que el mapa cumple hoy están
en `docs/MAP.md`.
