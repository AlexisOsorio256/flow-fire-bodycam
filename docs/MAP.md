# MAPA — ficha de arte (modo COMBATE)

Documento de arte de la **fábrica de vallas**: una nave industrial con el suelo
de hormigón y **paneles de OSB exentos** que forman pasillos y cobertura. Es el
**contrato de cotas** que comparten `tools/build_map.py` (→ `assets/models/map.glb`
+ `scenes/Map.tscn`) y `scripts/CombatMap.gd` (runtime). El builder declara que
sus medidas salen de aquí; el runtime no repite ninguna: lee los marcadores de la
escena.

Alcance y autoridad:

- `README.md` es la constitución y **no se toca**. Este fichero no la sustituye.
- Aquí no se ejecuta ni se modifica ningún `.py`, `.gd`, `.tscn`, `.glb` ni
  `.gdshader`: solo se describe y se mide.
- Cada bloque indica de dónde sale el número. Reproducir la escena entera:
  `blender --background --python tools/build_map.py`.

## 1. Estado del árbol

| Pieza | Estado |
| --- | --- |
| `assets/models/map.glb` + `scenes/Map.tscn` | **Vigente**. 9.616 tris, 10 mallas (una por material en uso), **202 `StaticBody3D`**, **150 ocultadores** y 60 marcadores. |
| `scripts/CombatMap.gd` | **Vigente**. Materiales, luz, exposición, navegación y los 30 puestos. Las cotas no viven aquí: viven en los marcadores. |
| `tools/build_map.py` | **Vigente**. Único camino reproducible: malla, colisión, ocultadores, AO y marcadores salen del mismo dato. |
| `docs/MAP.md` | Este fichero. |

Medición de la estructura: lectura de los **202 `StaticBody3D`** de
`scenes/Map.tscn` (194 `BoxShape3D` + 8 `CylinderShape3D`) con su `position` y
`size`, que es el dato exacto con el que corren la física y `Ballistics`.

## 2. Cotas

| Cota | Valor |
| --- | --- |
| Nave | **32 × 40 m** (`x` ±16,00 / `z` ±20,00), 6,20 m de alero y 8,00 m de cumbrera |
| Cerramiento | Hormigón de 22 cm con correas de acero cada ~1,3 m |
| Lucernarios | 1,80 m de ancho entre 4,20 y 5,20 m de altura, cada 3,60 m |
| Cerchas | Rojas, cada 4,00 m, cordón inferior a 6,30 m |
| Valla | Panel OSB de 12 cm, **2,60 m** de alto, con travesaños vistos por las dos caras |
| Rejilla de vallas | Filas cada 5,40 m, columnas cada 5,40 m, valla de 3,40 m |
| Calles | Eje central y calle de cruce de 4,40 m libres; anillo perimetral de 2,40 m |
| Suelo | Losa de hormigón con juntas cada 4,00 m |

**La circulación se reserva, no se dibuja**: el generador deja libres el eje
central (`|x| < 2,20`), la calle de cruce (`|z| < 2,20`) y el anillo perimetral,
y planta vallas solo en los cuatro cuadrantes con calles de 2,0 m. Una lista a
mano de vallas cerraba el mapa.

### 2.1 Cuerpos por superficie

Es el desglose que cobra `Ballistics.MATERIALS`, leído del `metadata/surface` de
cada cuerpo — la misma fuente que el runtime:

| Superficie | Cuerpos | Qué es |
| --- | --- | --- |
| `steel` | 152 | cerramiento, correas, cerchas, vigas, tubos, tuberías y juntas |
| `pine` | 41 | vallas, travesaños y cajas de obra |
| `concrete` | 1 | losa del suelo |
| `aluminum` | 8 | bidones (cilindros: `Ballistics` los abre de pared a pared) |
| `paper` | — | sin uso |

## 3. Materiales

El `.glb` **no lleva texturas dentro**: exporta el nombre del material y
`CombatMap._rebind()` lo reengancha por nombre a los mapas del repo. Una textura
se paga una vez por mapa. **12 materiales**, ninguno sin resolver:

| Clave | Mapas | Tinte sRGB |
| --- | --- | --- |
| `Map_Osb` | `map/osb_*.jpg` | 0,60 / 0,51 / 0,40 |
| `Map_Floor` | `map/osb_*.jpg` | 0,42 / 0,36 / 0,28 |
| `Map_Stud` | `real/wood_oak_wood_planks_*.jpg` | 0,70 / 0,58 / 0,42 |
| `Map_Roof` | `map/roof_steel_*.jpg` (sin normal) | 0,55 / 0,54 / 0,52 |
| `Map_Rust` | `map/roof_steel_*.jpg` (tinte óxido) | 0,56 / 0,24 / 0,12 |
| `Map_Steel` | `map/roof_steel_*.jpg` | 0,30 / 0,26 / 0,24 |
| `Map_Tube` | — (emisivo) | 0,94 / 0,95 / 0,97 |
| `Map_Tarp` | `enemy/fabric_*.jpg` | 0,06 / 0,06 / 0,07 |
| `Map_Wall` | `real/concrete_brushed_*.jpg` | 0,78 / 0,77 / 0,75 |
| `Map_Concrete` | `real/concrete_brushed_*.jpg` | 0,80 / 0,72 / 0,60 |
| `Map_Frame` | `map/roof_steel_*.jpg` | 0,30 / 0,31 / 0,33 |
| `Map_Wood` | `real/wood_oak_wood_planks_*.jpg` | 0,52 / 0,42 / 0,30 |

El **techo no lleva mapa de normales a propósito**: la chapa grecada a ras de
ojo cae por debajo del píxel y aliasea; lisa, la única lectura es la de las
juntas. La escala de UV viaja horneada en la malla.

## 4. Marcadores

La escena es la **única autoridad** de dónde va cada cosa; `CombatMap.gd` no
declara ni una coordenada. **`Main` tampoco**: el punto de entrada lo pregunta al
mapa (`spawn_point()`), que lo lee del marcador; antes había una constante con la
coordenada que se quedó atrás y metía al jugador dentro de una valla.

| Marcador | Cuántos | Quién lo lee |
| --- | --- | --- |
| `Puesto*` | **30 puestos** | `_spawn_enemies()`, con el rumbo en `metadata/rumbo` |
| `Tubo*` | **27 tubos** | `_lights()`, una omni por tubo |
| `Spawn` | 1 | `CombatMap.spawn_point()` → `Main` |
| `Municion` | 1 | `AmmoTable` |
| `Interior` | 1 | rectángulo de la zona de exposición |

Los puestos se colocan en espiral si el punto ideal cae dentro de una valla: la
nave no pierde enemigos por una valla mal puesta.

## 4.1 Navegación

`CombatMap` hornea un `NavigationMesh` al construir el modo (parseo explícito de
los `StaticBody3D` que ya son la geometría de la física, radio de agente 0,34 m,
volumen de horneado cortado a 3 m para que el tejado no cuente como suelo) y se
lo da a cada `NavigationAgent3D`. Sin él los enemigos caminaban de frente contra
las vallas; con él `check_walk` recorre la fábrica entera por el mismo camino.

## 5. Luz y exposición

El mapa **no crea** su propio `WorldEnvironment`: escribe sobre el de `Main.tscn`
y lo devuelve a su valor al salir.

La nave está a pleno día: los **lucernarios** dejan entrar el sol y el hormigón
lo rebota; los tubos colgados de las cerchas son el remate, no la fuente. El
ambiente es el del cielo nublado y el sol mantiene sombra a 20 m. El alcance de
cada tubo es **6,5 m**: a 6,20 m de alero cubre su calle sin que cada omni
pinte media nave (a 9,0 m el coste por píxel no compensaba).

| Zona | exposure | ambient | sky | contrib |
| --- | --- | --- | --- | --- |
| Interior (marcador `Interior`, la nave) | 4,20 | 1,00 | 1,40 | 0,60 |
| Fuera (por defecto, lobby) | 1,95 | 0,47 | 1,55 | 1 |

Las dos calibraciones del cielo, leídas de `Main.tscn`: `sky_top` 0,50 / 0,525 /
0,575 y `sky_horizon` 0,80 / 0,845 / 0,88. Niebla y glow nacen **apagados**, y la
ficha no promete FSR: el renderer es **Mobile**, donde no existe.

### 5.1 Oclusión horneada

El builder hornea **oclusión ambiental en el color de vértice** (14 rayos por
vértice, alcance 1,20 m, suelo 0,45) y el runtime la multiplica por el albedo:
es la única sombra de contacto que Mobile paga sin `SSAO` ni `LightmapGI`.

## 6. Rendimiento medido

`tools/medir.sh base`, 1080p en la HD520, modo combate, `scaling_3d` **0,80**,
sin MSAA y filtrado **bilinear** (`mode=0`): **p50 = 30,95 ms = 32,3 FPS de
mediana** (mean 31,05, p95 32,84, 95 draws, 554.320 prims). El suelo duro que el
dueño fijó para este proyecto es **30 FPS** y el p95 (30,4 FPS) lo cumple. Coste
medido por perfil A/B: las luces ~9 ms (27 omnis de 6,5 m), el post de bodycam
~5 ms, el MSAA 2× ~4 ms (fuera). La escala 0,80 es el punto donde la definición
se mantiene y el cuadro entra en presupuesto.

## 7. El enemigo

**1,78 m** (`Enemy.BODY_HEIGHT`) y el glb exporta **6 clips** —`Idle`, `Walk`,
`Neck`, `Aim`, `Hit` y `Death`— de las 46 animaciones CC0 de la *Universal
Animation Library* de Quaternius.

**LA ZONA MANDA, Y NO TODAS MATAN.** El impacto se clasifica por el hueso más
cercano (cabeza, brazo, pierna, tronco) y la vitalidad se decide por punto:

| Impacto | Qué pasa |
| --- | --- |
| Cabeza | Muerte instantánea: la física toma el cuerpo en el mismo frame |
| Pecho / espalda | Herida vital: retroceso de 0,12 s y colapso |
| Cadera | **Herida**: no es vital, el cuerpo acusa el golpe y sigue |
| Muslo | **Vital** (femoral): se desangra en pie, cae con el clip `Death` |
| Pantorrilla / pie | **Herida**: cojera visible, sigue peleando |
| Brazo | **Herida**: pierde puntería (dispersión ×3,4) y tarda en responder |

Un herido acusa el golpe con los resortes del cuerpo (`_hit_vel`), cojea
(`_limp`) o dispara peor (`_aim_bad`), y se le puede seguir disparando: no hay
vida, hay zonas. Fuente, licencia y cotas del equipo: ver la cabecera de
`tools/build_enemy.py`.

## 8. Lo que este documento no toca

`README.md` (la constitución) y el contenido de `docs/refs/`.
