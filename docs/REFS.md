# REFS — contrato visual

Qué manda. No es la ficha del árbol (esa es `docs/MAP.md`): aquí está la única
referencia visual del proyecto y lo que ordena.

Regla al editar: cada número de aquí tiene que poder reproducirse con un comando
sobre un fichero que exista hoy. Un dato medido sin ruta de reproducción es una
afirmación, no una medida.

## 1. La referencia

Dos imágenes, puestas por el dueño. **El mapa manda por `ref9_fabrica.jpg`; las
demás capas por `ref8_mapa.jpg`.**

`docs/refs/ref9_fabrica.jpg` — 776x436 · **105.939 B**. Frase del dueño: *"así
debería ser el mapa todo así tipo esas vallas grandes, pero dentro de una fábrica
grande para que haya mucho espacio para muchos enemigos; el chiste es que sea
pequeño pero bien hecho"*.

**Nave industrial con vallas de OSB exentas**: suelo de hormigón, techo de chapa
con **cerchas rojas oxidadas** y lucernarios, **vallas/paneles de tablero OSB
sueltos** —no cuartos cerrados— formando pasillos y cobertura, soldado de negro
con casco, chaleco y rifle disparando, y **manos enguantadas con el arma** en
primer plano. Fuera de la valla, todo es espacio abierto de fábrica.

`docs/refs/ref8_mapa.jpg` — 1200x800 · **193.402 B**. Manda en lo que `ref9` no
cubre: **el lente** (viñeta circular visible, gran angular, la imagen llega hasta
los bordes), el encuadre del arma y el interior doméstico que ambienta el lobby.

Total de `docs/refs/`: **299.341 B** en 2 imágenes.

## 2. Qué manda en cada sistema

| Sistema | Lo que manda la referencia |
| --- | --- |
| Mapa | `ref9`: NAVE de fábrica con vallas de OSB EXENTAS sobre hormigón. Nada de casa ni de cuartos encadenados |
| Luz | `ref9`: lucernarios de chapa al fondo, fluorescentes en las cerchas, claridad de nave diurna |
| Enemigo | Soldado de negro con casco, chaleco y rifle, de pie y disparando |
| Punto de vista | Manos enguantadas y arma SIEMPRE en cuadro (`ref8`) |
| Lente | `ref8`: viñeta circular marcada, gran angular, imagen hasta los bordes |
| Suelo | `ref9`: hormigón claro con juntas y manchas de taller |

## 3. Qué NO es esta referencia

`ref9` **no** pide una casa: pide un recinto industrial **abierto y grande** con
cobertura exenta para que quepan muchos enemigos. Toda estructura interior que
no sea una valla con su travesaño es sobreingeniería.

## 4. Cómo se comprueba

El estado del juego no se compara contra ficheros: se **mira el juego**. Se
captura con `SHOT_OUT=<dir> tools/captura.sh <encuadre>` y se mide con
`python3 tools/measure_perceptual.py <dir>`; el frame time, con
`tools/medir.sh base`. Las cotas y los materiales que el mapa cumple hoy están
en `docs/MAP.md`.
