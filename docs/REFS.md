# REFS — contrato visual

Qué manda y cuándo. Este documento **no** es la ficha del árbol: es lo que el
dueño ha pedido, más las medidas de las REFERENCIAS que lo representan (§2 y §3
miden los JPG de `docs/refs/`, y esas medidas sí son del estado real). El estado
del juego está en `docs/HOUSE_DESIGN.md`.

Regla al editar: cada número de aquí tiene que poder reproducirse con un comando
sobre un fichero que exista hoy. Un dato medido sin ruta de reproducción es una
afirmación, no una medida.

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

Las **siete** imágenes (`ref1`–`ref5`, `ref6.jpeg`, `ref7.jpg`) miden lo que sigue
y suman **1.461.187 B** (medido con `os.path.getsize` + `PIL.Image.size` sobre
`docs/refs/`, no copiado). **No comparten formato:** hay 1920x1080, 1600x900,
1600x840, 1280x720 y 739x415. Cualquier afirmación de "son 1600x900" es falsa
desde el 2026-09-28. **Ojo: el número de fichero NO coincide con el número de la
spec.** Se verificó el contenido de todas, una por una:

| Fichero | Tamaño | Qué contiene de verdad | Párrafo de la spec |
| --- | --- | --- | --- |
| `ref1.jpg` | 1600x900 · 217.742 B | Escalera interior, **fisheye con viñeta fuerte**, paredes con graffiti teal/rosa, barandilla metálica, **arma centrada con anillo/mira** | ≈ **REF5** |
| `ref2.jpg` | 1280x720 · 189.293 B | **Casa exterior de 2 pisos, madera weathered, porche con columnas, andamio a la derecha, patio tierra, barreras de hormigón, malla verde**, pistola en ADS centrada desde atrás con guante, **cielo nublado**, rótulo `BODYCAM` | ≈ **REF2** |
| `ref3.jpg` | 1600x840 · 164.662 B | Interior con **suelo de madera**, **soldado con casco, chaleco y rifle** junto a una ventana/puerta, viñeta pesante | ≈ **REF3** (el único cuyo número sí coincide) |
| `ref4.jpg` | 1600x900 · 310.340 B | **Casa exterior de 2 pisos, madera weathered, porche con columnas, andamio a la derecha, patio tierra, barreras, tubería, estantes**, **pistola inspeccionada en primer plano derecha con la corredera abierta y el latón visible**, guante táctico, **cielo azul**, rótulo `BODYCAM` | ≈ **REF1** |
| `ref5.jpg` | 1600x900 · 240.576 B | **Escalera fisheye**, tag de graffiti rojo en la pared, **soldado a la derecha con la CARA PIXELADA**, casco y rifle, **tragaluz roto**, **aberración cromática en los bordes y viñeta** | ≈ **REF4** |
| `ref6.jpeg` | 739x415 · 28.279 B | **Interior doméstico** (sala): suelo de madera, sofá, TV encendida, estanterías, puerta blanca abierta, cubo metálico, silla. **Glock en ambas manos con guante táctico**, apuntando. Viñeta muy fuerte (esquinas negras), marca `UNRECORD`, indicador de obturación `1/15` | — **sin spec** |
| `ref7.jpg` | 1920x1080 · 310.295 B | **Nave industrial** (no doméstica): estructura de acero, pasarelas y escaleras metálicas, contenedores, palés, bloques de hormigón, bidones, tuberías, malla azul al fondo, escombros. Pistola en mano. Viñeta + **desenfoque de campo muy marcado** (bokeh) | — **sin spec** |

`ref6` y `ref7` **no tienen párrafo en la spec** (§1 sólo transcribe cinco) y por
tanto **no tienen mapeo asignado**: qué sistema sirven es decisión del dueño. Se
documenta aquí lo que contienen, medido, para que la decisión no se tome a ciegas.
Nótese que `ref7` es un escenario **industrial**, no la casa del juego.

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
lo que se ha visto mirando los siete ficheros uno por uno.

Esta tabla **sólo cubre cinco ficheros**: `ref6` y `ref7` llegaron después y no
tienen spec ni mapeo (ver §2). No se les asigna sistema aquí.

## 4. El vídeo de referencia

`docs/refs/recrear esta calidad perceptual. para flowfire bodycam.mp4` — 12.404.227 B,
H.264 + AAC, **1280x718, 41,07 s** (medido con `ffprobe`). Está **versionado en
git**, así que pesa en cada clon: si deja de ser la referencia, se borra en el
mismo commit que lo decide (regla 10 de la constitución, *el árbol activo sólo
conserva lo necesario*).

## 5. Qué se ve en el vídeo (medido, 41 fotogramas en 3 hojas de contacto)

**El vídeo manda sobre las cinco imágenes cuando se contradicen.** Es una
**bodycam real** (no un render) de un operador armado moviéndose por un edificio
industrial abandonado. Lo que lo define, y que **no** es el escenario:

| Rasgo | Cómo es en el vídeo | Estado en el juego |
| --- | --- | --- |
| Viñeta | Circular y **muy negra**: las esquinas se comen el cuadro | Existe en `shaders/bodycam.gdshader` (`vignette` 1,0 / 0,46) |
| Gran angular | Ojo de pez **extremo**, con deformación de barril visible | Existe (`fisheye` 0,30) |
| Grano | Visible en toda la imagen, más en sombras | Existe (`grain_amount` 0,0045) |
| **Motion blur** | **Marcado en cada giro rápido**; en los barridos el cuadro se deshace | **NO existe** |
| **Cielo** | **Blanco quemado**, sin detalle: se sobreexpone siempre | El juego tiene cielo con color y detalle |
| **Contraste** | Interior oscuro contra luz dura que entra por huecos | Se acaba de **subir el ambiente** (nublado), que lo **reduce** |
| **Reflejos especulares** | Reales y fuertes: el agua del suelo devuelve el techo | **NO existen** (renderer Mobile, sin SSR) |
| Escenario | Nave industrial: óxido, hormigón, graffiti, escombros, contenedores | Casa doméstica |
| Punto de vista | A la altura del pecho, manos enguantadas y arma siempre en cuadro | Similar |
| Transiciones | Fundidos a negro entre tramos | — |

### Consecuencia: dos órdenes del dueño chocan

`ref2` pide **cielo nublado** y el vídeo manda **cielo quemado con contraste
alto**. No son lo mismo: el nublado que se implementó (sol 0,14 + ambiente +35 %)
aplana el contraste, y el vídeo lo quiere extremo. **Qué gana lo decide el
dueño**; hasta entonces este documento no da por bueno ni uno ni otro.

### Los `t*.jpg` que ya no están

Los seis `docs/refs/t*.jpg` (576x1024, media 50.082 B) se borraron en `034c7dd`.
Eran fotogramas de un vídeo vertical 576x1024 con marca de TikTok, filmado con el
móvil sobre un monitor; lo único aprovechable era el grano de cámara. Consta para
que el borrado no parezca un descuido.
