# REFS — contrato visual

Qué manda y cuándo. Este documento **no** describe lo que hay hoy en el árbol:
describe lo que el dueño ha pedido. Es un contrato, no un inventario. Lo que
todavía no se cumple está en `docs/HOUSE_DESIGN.md`, que sí es una ficha medida
del estado real.

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

## 2. Qué manda en qué sistema

| Sistema | Referencia que manda | Nota |
| --- | --- | --- |
| Mapa (fachada, patio, interior) | **REF1** / **REF2** | REF1 de día para volumes, REF2 para el estado nublado del mismo recinto |
| Lente / post de cámara | **REF4** / **REF5** | El barril gran angular y la aberración de bordes se calibran contra el tragaluz y la escalera, no a ojo |
| Enemigo | **REF3** / **REF4** | REF3 para el cuerpo y el equipo; REF4 para la cara pixelada, que es una decisión de legibilidad, no un descuido |
| Luz | **Nublada de REF2** | **No la quemada.** El contrato es el mismo recinto con cielo cubierto; si la exposición sube hasta quemar la fachada, se ha salido del contrato |

## 3. Procedencia de `docs/refs/`

Los seis JPG de esta carpeta (576x1024, media 50.082 B) son fotogramas
**mecánicamente extraídos** del vídeo `~/Documentos/OBJETIVO DEL JUEGO A LOGRAR
ALGO ASI.mp4` en t = 3, 9, 22, 34, 40 y 52 s. Se versionan como **textura de
tono**, no como las referencias.

Aviso medido, porque si no estos ficheros se leerían mal: dicho vídeo **no
contiene REF1-REF5**. Con `ffprobe` es un 576x1024 vertical, 30 fps, 1967
fotogramas, 65,5 s, con marca de agua de TikTok (`@sb_designs`); y por fotograma
es una grabación del **escritorio** de alguien filmando con el móvil un monitor
GIGABYTE, con teclado, manos y alfombrilla en plano. En la pantalla corre **otro
juego** (campo de trincheras con árboles secos, barro y tablas). Por tanto:

- **No son** la casa de madera, ni el ADS, ni el soldado, ni el graffiti.
- Sirven de referencia de **grano de cámara y deVerticalidad**, nada más.
- La especificación que manda es la de la sección 1, que viene del dueño y no de
  estos ficheros.

Para tener REF1-REF5 de verdad hay que capturarlas de su origen y meterlas aquí
junto a la spec. Hasta entonces, sección 1 y sección 2 son el contrato; esta
sección 3 es la advertencia de que los adjuntos no lo sustituyen.
