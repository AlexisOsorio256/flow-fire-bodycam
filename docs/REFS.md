# REFS — contrato visual

Qué manda y cuándo. Este documento **no** describe lo que hay hoy en el árbol:
describe lo que el dueño ha pedido, y qué fichero de `docs/refs/` lo representa.
Lo que todavía no se cumple está en `docs/HOUSE_DESIGN.md`, que sí es una ficha
medida del estado real.

## 1. Spec (texto del dueño, literal)

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

Los cinco JPG son 1600x900 (`ref3` es 1920x1080) y suman 1.271.763 B. **Ojo: el
número de fichero NO coincide con el número de la spec.** Se verificó el
contenido de los cinco, uno por uno:

| Fichero | Qué contiene de verdad | Párrafo de la spec |
| --- | --- | --- |
| `ref1.jpg` | Escalera interior, **fisheye con viñeta fuerte**, paredes con graffiti teal/rosa, barandilla metálica, **arma centrada con anillo/mira** | ≈ **REF5** |
| `ref2.jpg` | **Casa exterior de 2 pisos, madera weathered, porche con columnas, andamio a la derecha, patio tierra, barreras de hormigón, malla verde**, pistola en ADS centrada desde atrás con guante, **cielo nublado**, rótulo `BODYCAM` | ≈ **REF2** |
| `ref3.jpg` | Interior con **suelo de madera**, **soldado con casco, chaleco y rifle** junto a una ventana/puerta, viñeta pesante | ≈ **REF3** (el único cuyo número sí coincide) |
| `ref4.jpg` | **Casa exterior de 2 pisos, madera weathered, porche con columnas, andamio a la derecha, patio tierra, barreras, tubería, estantes**, **pistola inspeccionada en primer plano derecha con la corredera abierta y el latón visible**, guante táctico, **cielo azul**, rótulo `BODYCAM` | ≈ **REF1** |
| `ref5.jpg` | **Escalera fisheye**, tag de graffiti rojo en la pared, **soldado a la derecha con la CARA PIXELADA**, casco y rifle, **tragaluz roto**, **aberración cromática en los bordes y viñeta** | ≈ **REF4** |

## 3. Tabla de qué manda en qué sistema

La orden del dueño fue `ref1-2 → mapa`, `ref4-5 → lente`, `ref3-4 → enemigo`,
`luz nublada ref2`. **Esa orden se recoge tal cual, pero al contrastarla con el
contenido real de los ficheros, tres de los cinco mapeos no aguantan.** Se
dejan las dos columnas para que la contradicción se vea y se resuelva, en lugar
de escribir en el contrato algo que las imágenes desmienten.

| Sistema | Orden del dueño | Ficheros que de verdad lo sirven (verificado) | Nota |
| --- | --- | --- | --- |
| Mapa (fachada, patio, interior) | `ref1` / `ref2` | **`ref4` / `ref2`** | `ref1` NO es mapa: es la escalera fisheye. Los dos que sí son fachada son `ref4` (día) y `ref2` (nublado) |
| Lente / post de cámara | `ref4` / `ref5` | **`ref5` / `ref1`** | `ref4` NO es lente: es la fachada de día. Las dos escaleras fisheye son `ref5` y `ref1` |
| Enemigo | `ref3` / `ref4` | **`ref3` / `ref5`** | `ref3` sí vale para el cuerpo. El soldado con **cara pixelada** está en `ref5`, no en `ref4`, que no tiene a nadie |
| Luz | **nublada, `ref2`** | **`ref2`** | Correcto y sin cambios: el cielo cubierto está en `ref2.jpg`. **No la quemada** |

Para cerrar las tres discrepancias hay dos salidas y ambas son del dueño:
renombrar los ficheros para que el número sea el de la spec, o corregir la
tabla. Hasta que se decida, **manda el contenido medido de la sección 2**, que es
lo que se ha visto mirando los cinco ficheros uno por uno.

## 4. Nota sobre los `t*.jpg`

Los seis `docs/refs/t*.jpg` que estaban aquí (576x1024, media 50.082 B) eran
fotogramas extraídos de `~/Documentos/OBJETIVO DEL JUEGO A LOGRAR ALGO ASI.mp4`, y
**se han borrado del disco al llegar las referencias de verdad**: ya no están en
`docs/refs/`. Consta aquí solo para que el borrado no parezca un descuido, porque
aun figure su eliminación sin stagear en `git status`.

No eran ninguna de las cinco referencias: con `ffprobe` ese vídeo es un 576x1024
vertical, 30 fps, 1967 fotogramas, con marca de agua de TikTok (`@sb_designs`),
filmado con el móvil sobre un monitor de escritorio. Lo único aprovechable era el
grano de cámara.
