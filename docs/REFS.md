# REFS — contrato visual

Qué manda y cuándo. Este documento **no** es la ficha del árbol: es lo que el
dueño ha pedido, más las medidas de las REFERENCIAS que lo representan (§2 y §3
miden los JPG de `docs/refs/`, y esas medidas sí son del estado real). El estado
del juego está en `docs/HOUSE_DESIGN.md`.

Regla al editar: cada número de aquí tiene que poder reproducirse con un comando
sobre un fichero que exista hoy. Un dato medido sin ruta de reproducción es una
afirmación, no una medida.


Las cinco referencias siguientes son la especificación. Se transcriben **sin
interpretar**: mandan tal cual, y el arte que no las cumpla no vale aunque mida
bien.

> **REF1** casa exterior día: casa madera 2 pisos weathered, porche con columnas,
> andamio a la derecha, patio tierra con barreras concreto/tubos/estantes, pistola
> inspeccionada en primer plano dcha (corredera abierta, latón visible), guante
> táctico, cielo azul.
>
> **REF2** misma casa nublado: pistola en ADS centrada desde atrás, guante, suelo
> barro con escombro, malla verde, pallets.
>
> **REF3** interior piso madera: soldado full equipo (casco, chaleco, rifle) junto
> a ventana/puerta.
>
> **REF4** fisheye escalera: graffiti pared, soldado dcha con CARA PIXELADA + casco
> + rifle, tragaluz roto, aberración cromática bordes + viñeta.
>
> **REF5** fisheye cenital escalera graffiti color, arma con anillo/halo centrada.

## 2. Qué contiene cada fichero (verificado con `read`, uno por uno)

Las **ocho** imágenes (`ref1`–`ref5`, `ref6.jpeg`, `ref7.jpg`, `ref8_mapa.jpg`)
miden lo que sigue y suman **1.654.589 B** (medido con `os.path.getsize` +
`PIL.Image.size` sobre `docs/refs/`, no copiado). **No comparten formato:** hay
1920x1080, 1600x900, 1600x840, 1280x720, 1200x800 y 739x415. Cualquier
afirmación de "son 1600x900" es falsa spec.** Se verificó el contenido de todas,
una por una:

| Fichero | Tamaño | Qué contiene de verdad | Párrafo de la spec |
| --- | --- | --- | --- |
| `ref1.jpg` | 1600x900 · 217.742 B | Escalera interior, **fisheye con viñeta fuerte**, paredes con graffiti teal/rosa, barandilla metálica, **arma centrada con anillo/mira** | ≈ **REF5** |
| `ref2.jpg` | 1280x720 · 189.293 B | **Casa exterior de 2 pisos, madera weathered, porche con columnas, andamio a la derecha, patio tierra, barreras de hormigón, malla verde**, pistola en ADS centrada desde atrás con guante, **cielo nublado**, rótulo `BODYCAM` | ≈ **REF2** |
| `ref3.jpg` | 1600x840 · 164.662 B | Interior con **suelo de madera**, **soldado con casco, chaleco y rifle** junto a una ventana/puerta, viñeta pesante | ≈ **REF3** (el único cuyo número sí coincide) |
| `ref4.jpg` | 1600x900 · 310.340 B | **Casa exterior de 2 pisos, madera weathered, porche con columnas, andamio a la derecha, patio tierra, barreras, tubería, estantes**, **pistola inspeccionada en primer plano derecha con la corredera abierta y el latón visible**, guante táctico, **cielo azul**, rótulo `BODYCAM` | ≈ **REF1** |
| `ref5.jpg` | 1600x900 · 240.576 B | **Escalera fisheye**, tag de graffiti rojo en la pared, **soldado a la derecha con la CARA PIXELADA**, casco y rifle, **tragaluz roto**, **aberración cromática en los bordes y viñeta** | ≈ **REF4** |
| `ref6.jpeg` | 739x415 · 28.279 B | **Interior doméstico** (sala): suelo de madera, sofá, TV encendida, estanterías, puerta blanca abierta, cubo metálico, silla. **Glock en ambas manos con guante táctico**, apuntando. Viñeta muy fuerte (esquinas negras), marca `UNRECORD`, indicador de obturación `1/15` | — **sin spec** |
| `ref7.jpg` | 1920x1080 · 310.295 B | **Nave industrial** (no doméstica): estructura de acero, pasarelas y escaleras metálicas, contenedores, palés, bloques de hormigón, bidones, tuberías, malla azul al fondo, escombros. Pistola en mano. Viñeta + **desenfoque de campo muy marcado** (bokeh) | — **sin spec** |
| `ref8_mapa.jpg` | 1200x800 · 193.402 B | **Casa de tiro de tablero OSB**: pasillo central con muros de rastreles vistos y paneles OSB, suelo de tablero, techo de chapa con celosía de acero y **tubos fluorescentes encendidos**, vanos sin puerta, cuarto lateral con lona oscura en el suelo, soldado con casco/chaleco/rifle al fondo y **manos enguantadas con rifle** en primer plano | **EL MAPA** |

`ref6` y `ref7` **no tienen párrafo en la spec** (§1 sólo transcribe cinco) y por
documenta aquí lo que contienen, medido, para que la decisión no se tome a ciegas.
Nótese que `ref7` es un escenario **industrial**, no la casa del juego.

## 3. Tabla de qué manda en qué sistema

`luz nublada ref2`. **Esa orden se recoge tal cual, pero al contrastarla con el
contenido real de los ficheros, tres de los cinco mapeos no aguantan.** Se
dejan las dos columnas para que la contradicción se vea y se resuelva, en lugar
de escribir en el contrato algo que las imágenes desmienten.

| --- | --- | --- | --- |
| Mapa (fachada, patio, interior) | `ref1` / `ref2` | **`ref4` / `ref2`** | `ref1` NO es mapa: es la escalera fisheye. Los dos que sí son fachada son `ref4` (día) y `ref2` (nublado) |
| Lente / post de cámara | `ref4` / `ref5` | **`ref5` / `ref1`** | `ref4` NO es lente: es la fachada de día. Las dos escaleras fisheye son `ref5` y `ref1` |
| Enemigo | `ref3` / `ref4` | **`ref3` / `ref5`** | `ref3` sí vale para el cuerpo. El soldado con **cara pixelada** está en `ref5`, no en `ref4`, que no tiene a nadie |
| Luz | **nublada, `ref2`** | **`ref2`** | Correcto y sin cambios: el cielo cubierto está en `ref2.jpg`. **No la quemada** |

Entre renombrar los ficheros para que el número sea el de la spec o corregir la
tabla, **decide el dueño**. Hasta entonces manda el contenido medido de la
sección 2.

Esta tabla **sólo cubre cinco ficheros**: `ref6` y `ref7` llegaron después y no
tienen spec ni mapeo (ver §2). No se les asigna sistema aquí.

## 4. El vídeo de referencia

`docs/refs/recrear esta calidad perceptual. para flowfire bodycam.mp4` — 12.404.227 B,
H.264 + AAC, **1280x718, 41,07 s** (medido con `ffprobe`). Está **versionado en
git**, así que pesa en cada clon: si deja de ser la referencia, se borra en el
mismo commit que lo decide (regla 10 de la constitución, *el árbol activo sólo
conserva lo necesario*).

## 5. Qué se ve en el vídeo (medido frame a frame, 246 fotogramas)

**El vídeo manda sobre las cinco imágenes cuando se contradicen.** Su naturaleza
es una bodycam real ni un render limpio, es una GRABACIÓN DE PANTALLA DEL EDITOR
DE UNREAL ENGINE 5**, proyecto `Abandoned_Building_v3.1`, con la ventana del
editor entera en cuadro (barra de título, menús File/Edit/Window/Tools/Build/
Select/Actor/Help, *Place Actors*, *Content Browser* con `DracoCompressor` y
`DracoDecompressor`, *Outliner*, y barra de tareas de Windows). El look bodycam
—anillo negro, barril, motion blur— vive **dentro del viewport**, o sea que es el
post-proceso del proyecto de UE5, no la óptica de una cámara.

Esto importa para no perseguir un imposible: la referencia es **tiempo real de
otro motor** con reflejos en el suelo y auto-exposición, que el renderer Mobile
de este proyecto no tiene. Lo que se puede copiar es la **óptica y la luz**; lo
que no, se declara abajo en vez de fingirlo.

El escenario de la referencia es una **nave industrial abandonada** (hormigón con
graffiti, malla verde de obra, valla de simple torsión, escaleras de hormigón,
estructura de acero con lucernarios, contenedor marítimo oxidado, cubas IBC,
palés, escombros y **charco que refleja el techo**). La casa doméstica de madera
del proyecto **no sale de aquí**: es una desviación, y consta para que nadie la
defienda como si la referencia la pidiera.

Antes de declarar que un rasgo falta: los efectos de lente viven en
**`shaders/`**, no en `scripts/`; y el código nombra **en español** (`palé`, no
`pallet`; `tragaluz`, no `skylight`). Un `grep` en inglés o en la carpeta
equivocada produce desviaciones inexistentes.

Los números de la columna derecha son **el valor vivo del shader**, leído de
"corregir" el shader en dirección contraria.

| Rasgo | Cómo es en el vídeo | Dónde está (o si falta) |
| --- | --- | --- |
| Viñeta | Circular y **muy negra**: las esquinas se comen el cuadro | `shaders/bodycam.gdshader:15-17`, `vignette` 1,0 con `vignette_start` **0,68** / `vignette_end` **0,94** |
| Gran angular | Ojo de pez **extremo**, con deformación de barril visible | idem `:20`, `fisheye` **0,18** |
| Grano | Visible en toda la imagen, más en sombras | idem `:18`, `grain_amount` 0,0045 |
| **Motion blur** | **Marcado en cada giro rápido**; en los barridos el cuadro se deshace | **NO existe**: el cuadro se lee nítido en cualquier giro |
| **Cielo** | **Blanco quemado**, sin detalle: se sobreexpone siempre | El juego tiene cielo con color y detalle |
| **Contraste** | Interior oscuro contra luz dura que entra por huecos | Se acaba de **subir el ambiente** (nublado), que lo **reduce** |
| **Reflejos especulares** | Reales y fuertes: el agua del suelo devuelve el techo | **NO existen** (renderer Mobile, sin SSR) |
| Escenario | Nave industrial: óxido, hormigón, graffiti, escombros, contenedores | Casa doméstica |
| Equipo del enemigo (REF3) | — | `tools/build_kit.py` (casco/chaleco/rifle 6/7/14), **no** `build_enemy.py`: ése sólo pone el cuerpo |
| Punto de vista | A la altura del pecho, manos enguantadas y arma siempre en cuadro | Similar |
| Transiciones | Fundidos a negro entre tramos | — |


`ref2` pide **cielo nublado** y el vídeo manda **cielo quemado con contraste
alto**. No son lo mismo: el nublado que se implementó (sol 0,14 + ambiente +35 %)
aplana el contraste, y el vídeo lo quiere extremo. **Qué gana lo decide el
dueño**; hasta entonces este documento no da por bueno ni uno ni otro.
