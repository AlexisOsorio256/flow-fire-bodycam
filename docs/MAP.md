# MAPA — ficha de arte (modo COMBATE)

Documento de arte de la **casa de tiro** de una planta: pasillo central, seis
cuartos, muros de tablero OSB con rastreles vistos, techo de chapa con celosía de
acero y tubos fluorescentes encendidos. Es el **contrato de cotas** que comparten
`tools/build_map.py` (→ `assets/models/map.glb` + `scenes/Map.tscn`) y
`scripts/CombatMap.gd` (runtime). El builder declara que sus medidas salen de
aquí; el runtime no repite ninguna: lee los marcadores de la escena.

Alcance y autoridad:

- `README.md` es la constitución y **no se toca**. Este fichero no la sustituye.
- Aquí no se ejecuta ni se modifica ningún `.py`, `.gd`, `.tscn`, `.glb` ni
  `.gdshader`: solo se describe y se mide.
- Cada bloque indica de dónde sale el número. Reproducir la escena entera:
  `blender --background --python tools/build_map.py`.

Medición de la estructura: lectura de los **95 `StaticBody3D`** de
`scenes/Map.tscn` (95 `BoxShape3D` + 0 `CylinderShape3D`) con su `position` y
`size`, que es el dato exacto con el que corren la física y `Ballistics`. Son 95
formas **únicas**: cada cuerpo tiene la suya y ninguna se reusa.

---

## 1. Estado del árbol

| Pieza | Estado |
| --- | --- |
| `assets/models/map.glb` + `scenes/Map.tscn` | **Vigente**. 6.088 tris, 8 mallas (una por material), **95 `StaticBody3D`**, **64 ocultadores** y 31 marcadores. |
| `scripts/CombatMap.gd` | **Vigente**. Materiales, luz, exposición y los 8 puestos. Las cotas no viven aquí: viven en los marcadores. |
| `tools/build_map.py` | **Vigente**. Único camino reproducible del mapa: malla, colisión, ocultadores y marcadores salen del mismo dato. |
| `docs/MAP.md` | Este fichero. |

## 2. Cotas

| Cota | Valor |
| --- | --- |
| Planta exterior | 10,00 × 14,00 m (`x` ±5,00 / `z` ±7,00) |
| Pasillo central | 2,10 m de ancho libre, de fachada a fachada |
| Cuartos | 3,83 m de fondo × 4,61 m (4,54 m el central) |
| Altura libre | 2,80 m en los aleros, 4,10 m en la cumbrera |
| Tablero (muro, suelo, hastial) | 12 cm |
| Rastrel | 9 × 4,5 cm |
| Vanos de paso | 1,30 × 2,05 m |
| Ventanas | 1,50 × 0,95 m, alféizar a 1,00 m |
| Tabiques transversales | `z` = ±2,33 (parten cada banda en tres cuartos) |

Los vanos se reparten por banda: cada cuarto tiene **una puerta al pasillo** y
**una puerta al cuarto vecino** por el tabique, así que los seis se encadenan sin
volver al pasillo. Las dos fachadas llevan puerta centrada y dos ventanas; los
laterales, tres ventanas cada uno.

### 2.1 Cuerpos por superficie

Es el desglose que cobra `Ballistics.MATERIALS`, leído del `metadata/surface` de
cada cuerpo — la misma fuente que el runtime:

| Superficie | Cuerpos | Qué es |
| --- | --- | --- |
| `pine` | 73 | tablero y rastrel (muros, suelo, hastiales) |
| `steel` | 17 | chapa del techo, celosía y tubos |
| `ground` | 4 | terreno en anillo, al ras del suelo interior |
| `paper` | 1 | lona del cuarto |

## 3. Materiales

El `.glb` **no lleva texturas dentro**: exporta el nombre del material y
`CombatMap._rebind()` lo reengancha por nombre a los mapas del repo. Una textura
se paga una vez por mapa. **8 materiales**, ninguno sin resolver (un nombre que no
resuelva aborta el enganche en vez de dejar un color plano de reserva):

| Clave | Mapas | Tinte sRGB |
| --- | --- | --- |
| `Map_Osb` | `map/osb_*.jpg` | 0,95 / 0,91 / 0,85 |
| `Map_Floor` | `map/osb_*.jpg` (veta más abierta) | 0,60 / 0,54 / 0,46 |
| `Map_Stud` | `real/wood_oak_wood_planks_*.jpg` | 0,88 / 0,80 / 0,68 |
| `Map_Roof` | `map/roof_steel_*.jpg` | 0,70 / 0,65 / 0,59 |
| `Map_Steel` | `map/roof_steel_*.jpg` | 0,70 / 0,69 / 0,68 |
| `Map_Tube` | — (emisivo) | 0,94 / 0,95 / 0,97 |
| `Map_Tarp` | `enemy/fabric_*.jpg` | 0,20 / 0,20 / 0,22 |
| `Map_Ground` | `real/concrete_brushed_concrete_*.jpg` | 0,55 / 0,53 / 0,50 |

La escala de UV **no se toca en el runtime**: viaja horneada en la malla, en
metros por vuelta (1,20 m el tablero, 2,20 m la chapa, 3,00 m el terreno). `Map_Floor` y
`Map_Ground` la corrigen por material porque comparten textura con otro uso.

## 4. Marcadores

La escena es la **única autoridad** de dónde va cada cosa; `CombatMap.gd` no
declara ni una coordenada.

| Marcador | Cuántos | Quién lo lee |
| --- | --- | --- |
| `Puesto*` | **8 puestos** | `_spawn_enemies()`, con el rumbo en `metadata/rumbo` |
| `Tubo*` | **14 tubos** | `_lights()`, una omni por tubo |
| `Spawn` | 1 | punto de entrada declarado del mapa |
| `Municion` | 1 | `AmmoTable` |
| `Interior` | 1 | rectángulo de la zona de exposición de dentro |

Los 8 puestos van dos por banda y dos en el pasillo, todos con línea de vista al
eje por el que entra el jugador.

## 5. Luz y exposición

El mapa **no crea** su propio `WorldEnvironment`: escribe sobre el de `Main.tscn`
y lo devuelve a su valor al salir. Un segundo environment con más prioridad
ganaría y sería una segunda autoridad de cielo y exposición sobre el mismo
cuadro.

El sol (`-58°/-25°`, energía 1,15, sombra a 20 m) entra por los vanos y dibuja
las franjas claras del suelo; los tubos son la luz de dentro. El terreno vive en
su propia capa para que las omnis de dentro no lo enciendan y no se pague por
píxel. El alcance de cada tubo es **3,2 m**.

| Zona | exposure | ambient | sky | contrib |
| --- | --- | --- | --- | --- |
| Interior (marcador `Interior`) | 3,9 | 0,34 | 1,15 | 0,42 |
| Fuera (por defecto) | 1,95 | 0,47 | 1,55 | 1 |

Las dos calibraciones del cielo, leídas de `Main.tscn`: `sky_top` 0,50 / 0,525 /
0,575 y `sky_horizon` 0,80 / 0,845 / 0,88. Niebla y glow nacen **apagados**, y la
ficha no promete FSR: el renderer es **Mobile**, donde no existe.

## 6. Rendimiento medido

`tools/medir.sh base`, 1080p en la HD520, modo combate, `scaling_3d` **0,65** y
filtrado **bilinear** (`mode=0`, que es lo único real en Mobile): **p50 = 12,96 ms
= 77,2 FPS de mediana** (mean 13,46, p95 14,29, 48 draws, 166.598 prims).
Referencia de la constitución: 40 FPS (p50 ≤ 25 ms).

## 7. El enemigo

**1,78 m** (`Enemy.BODY_HEIGHT`, medido del hueso `Head` menos `Foot_L`) y el glb
exporta **3 clips** —`Idle`, `Walk` y `Neck`— de las 46 animaciones CC0 de la
*Universal Animation Library* de Quaternius. Los tres son los que pide
`Enemy.gd`; el resto no viaja al asset. Fuente, licencia y cotas del equipo: ver
la cabecera de `tools/build_enemy.py`.

## 8. Lo que este documento no toca

`README.md` (la constitución) y el contenido de `docs/refs/`.
