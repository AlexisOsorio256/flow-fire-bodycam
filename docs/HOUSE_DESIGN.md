# CASA — ficha de arte (modo COMBATE)

Documento de arte de la casa de dos plantas. Es el **contrato de cotas** que
comparten `tools/build_house.py` (carcasa → `assets/models/house.glb` +
`scenes/House.tscn`), `tools/build_props.py` (mobiliario → `assets/models/props.glb`)
y `scripts/CombatMap.gd` (runtime): los dos builders declaran que sus medidas
vienen de aquí.

Alcance y autoridad:

- `README.md` es la constitución y **no se toca**. Este fichero no la sustituye.
- Aquí no se ejecuta ni se modifica ningún `.py`, `.gd`, `.tscn`, `.glb` ni
  `.gdshader`: solo se describe y se mide.
- Cada bloque indica de dónde sale el número. Donde hay dos versiones, se
  declaran las dos y se marca la decisión como **pendiente**. Tras la pasada de
  luz/tierra/vacío ya no queda ninguna abierta: las cuatro que había (cocina
  duplicada, norte invadido, este espejado y nivel de la planta alta) se
  cerraron al exportar `props.glb`, y la escalera se rehizo entera.

Medición de la paleta: PIL sobre cada mapa de `assets/textures/real/`, imagen
reescalada a 256x256, media en sRGB y media convertida a lineal (IEC 61966-2-1);
`C` = croma (max-min en sRGB) y `H` = tono en grados. Medición de la casa:
lectura de los 296 `StaticBody3D` de `scenes/House.tscn` (283 `BoxShape3D` +
13 `CylinderShape3D`) con su `position` y `size`, que es el dato exacto con el
que corre la física y `Ballistics`.

**DOS RECUENTOS, Y NO SON EL MISMO NÚMERO** (confundirlos ya costó una ficha
falsa). Los 283 + 13 = 296 son **usos**: cada `CollisionShape3D` de la escena que
apunta a una caja o a un cilindro, y es lo que cuenta `tools/check_hechos.gd`
recorriendo los hijos de cada cuerpo — el número que esta ficha publica y el que
el gate exige. Los sub-recursos **únicos** son **186 `BoxShape3D` + 6
`CylinderShape3D` = 192**: la escena REUSA la misma forma en varios cuerpos
(296 cuerpos, 192 formas). Se reproduce con
`grep -c 'type="BoxShape3D"' scenes/House.tscn` (único) frente al recuento por
uso del check. Un ciclo que "corrija" 283/13 a 186/6 rompe el gate, y con razón.

---

## 1. Estado del árbol

| Pieza | Estado |
| --- | --- |
| `assets/models/house.glb` + `scenes/House.tscn` | **Vigente**. 296 cuerpos (7 de tierra, 20 de hormigón, 178 de pino, 50 de yeso, 29 de acero, 7 de papel, 5 de aluminio) + 71 ocultadores. |
| `scripts/CombatMap.gd` | **Vigente**. Materiales, luz, zonas de exposición y los 8 puestos. |
| `tools/build_props.py` → `assets/models/props.glb` | **Vigente**. 22 piezas, 21 colisores, 5 materiales; `CombatMap._props()` lo engancha y funde por material (22 mallas -> 5). |
| `docs/HOUSE_DESIGN.md` | Este fichero (la ficha de arte que los dos builders citan). |


### 1.1 Ampliación de planta (tercera pasada)

La planta escaló **×1,25** con una sola cifra (`build_house.ZOOM_PLANTA`): la
casa pasó de 11,96 × 12,84 m a **16,20 × 13,60 m**. No se tocaron `CEIL_Y`,
`SLAB_Y0/1` ni `ROOF_Y0`: la casa es más ancha y más larga con los mismos dos
pisos, que es lo que se nota al caminarla.

Lo que arrastró el escalado, todo desde esa misma constante:

| Pieza | Antes | Ahora |
| --- | --- | --- |
| Muros exteriores (`X_W`/`X_E`/`Z_S`/`Z_N`) | ±6,48 / 4,48 / −6,40 | ±8,10 / 5,60 / −8,00 |
| **Vano** de puerta de calle y trasera | ±0,55 | **±0,69** |
| Barandas del porche (hueco interior) | ±0,62 | ±0,76 |
| Vanos de ventana (los 13) | absolutos | derivados del centro |

**Un vano, una autoridad.** El hueco del muro y la hoja de la ventana eran dos
listas paralelas con las cotas escritas dos veces; al escalar se
desincronizaron y un tramo sólido cayó **sobre la puerta**: el jugador se
quedaba clavado a 0,46 m de la fachada, con la puerta dibujada y el muro
tapándola (medido con `check_walk`). Ahora `front_holes`/`back_holes`/
`west_holes`/`east_holes` son la única tabla, la carpintería se lee de ella por
índice y los cuatro muros la reciben convertida a `u` local, que es lo que come
`wall()`.

---

## 2. Cotas de la casa

### 2.1 Estructura (medida en `House.tscn` y `tools/build_house.py`)

Las cifras salen de las constantes del builder que genera la escena
(`tools/build_house.py:183-197`), y esa es su ruta de reproduccion:
`ZOOM_PLANTA = 1,25` escala la planta entera y todo lo demas cuelga de ahi.

| Concepto | Cota |
| --- | --- |
| Eje de muros este/oeste | `X_W = X_E = 6,48 * 1,25 = ±8,10`; caras interiores `±7,98` (`T_EXT` 0,24): **16,20 m de ancho** |
| Eje de fachada y trasera | `Z_S = 4,48 * 1,25 = +5,60` (sur, a la calle) · `Z_N = -6,40 * 1,25 = -8,00`; caras interiores `5,48 / -7,88`: **13,60 m de fondo** |
| Forro interior de yeso | 24 mm sobre la cara interior: útil ≈ `x ±7,956` |
| Vano de puerta | `VANO = 0,55 * 1,25 = ±0,6875`; alto `DOOR1_H = 2,15`; balcón `DOOR2_Y 3,00` / `1,95` |
| Ventanas | `H_W1 = (0,95, 2,35)` en planta baja · `H_W2 = (3,95, 5,15)` en alta |
| Suelo planta baja | `y = 0` (losa `Ground` de -0,30 a 0) |
| Forjado | 2,80 a 3,00 (colisores `C076..C078_Slab2` en `y = 2,90`, 0,20 de canto) |
| Techo planta baja / suelo de la alta | cara inferior 2,80 / cara superior 3,00 |
| Techo planta alta / cubierta | 5,60 / losa 5,60 a 5,75 (`C079_Roof` en `y = 5,67`) |
| **Altura libre real** | planta baja **2,80** (0 → 2,80) · planta alta **2,60** (3,00 → 5,60) |
| Tabique sala-pasillo | `X_SALA = -0,90` (caras -0,98 / -0,82), ambas plantas |
| Tabique pasillo-este | `X_HALL = 1,90` (caras 1,82 / 1,98), ambas plantas |
| Tabique cocina-baño | `Z_DIV = -2,28` (caras -2,20 / -2,36), canto `T_PART = 0,16`, **solo planta baja** |
| Escalera | 16 pasos, huella 0,26 x contrahuella 0,1875, **35,8°**; `x 0,96..1,80`, primer peldaño en **`z = -3,60`**; hueco `x 0,95..1,82`, `z -2,60..+0,56`; rampa de colisión 0,84 x 0,38 |
| Muro de caja de escalera | `P_Stair` en `x = 0,90`, de `z -2,60` a `+0,56`, de suelo a techo |
| Barandas y balcón | galería en `x = 0,92`; balcón losa 1,60 x 1,70 en `3,70 / 2,90 / 5,45` |

Suelos horneados (`finishes()`): roble en el oeste completo y en la planta alta;
gres en el pasillo (`Floor_Hall`), en la cocina (`Floor_Cocina`) y en el baño
(`Floor_Bano`); techos de escayola.

### 2.2 Cuartos (rectángulos interiores, caras de muro ya descontadas)

La autoridad es `tools/build_props.ROOMS`, que se **autovalida contra los 296
colisores de `scenes/House.tscn`** en solo lectura y no exporta si una pieza se

**AVISO MEDIDO, no cosmético:** esos rectángulos **no se re-escalaron** con
`ZOOM_PLANTA`. El interior real llega a `x ±7,98`, y `ROOMS` declara `-6,28 /
6,30`: la banda de ~1,7 m contra los muros este y oeste es interior jugable
**sin mobiliario**. No rompe nada (el rect es conservador, así que el autocote
pasa), pero explica por qué los cuartos se ven vacíos pegados a la pared. Se
declara aquí en vez de taparlo.

**Planta baja (`y = 0`, techo 2,80)**

| Cuarto | x | z | Rect de `ROOMS` |
| --- | --- | --- | --- |
| Sala / dormitorio oeste | -6,28 a -0,98 | -6,28 a 4,36 | roble |
| Vestíbulo / pasillo | -0,82 a 1,82 | -6,28 a 4,36 | gres |
| Cocina (este-sur) | 1,98 a 6,30 | -2,20 a 4,36 | gres |
| Baño (este-norte) | 1,98 a 6,30 | -6,28 a -2,36 | gres |
| Patio (a la calle, exterior) | -7,40 a 7,40 | 4,60 a 8,60 (alto 2,63) | **TIERRA** (`House_Dirt`, asfalto agrietado). La losa de obra queda para acera, calle y bordillo |

**Planta alta (`y = 3,00`, `NIVEL_ALTA`, techo 5,60)**

| Cuarto | x | z | Nota |
| --- | --- | --- | --- |
| Dormitorio oeste | -6,28 a -0,98 | -6,28 a 4,36 | puerta `Door_Dorm` en `x = -0,90` |
| Galería (solo la sur) | -0,82 a 1,82 | **0,56** a 4,36 | el rect arranca en +0,56 porque al norte está el HUECO de la escalera y el corredor oeste: son circulación, no sitio de mueble |
| Estudio este | 1,98 a 6,30 | -6,28 a 4,36 | sin tabique interior; puerta de balcón al sur |
| Balcón | 2,90 a 4,50 | 4,60 a 6,30 | exterior |

---

## 3. Paleta croma medida (`assets/textures/real/`)

### 3.0 MODELO DE COLOR (medido, y era el error de fondo de todas las pasadas)

El tinte de `CombatMap.MAPS` **no** se multiplica contra el valor lineal del mapa:
se multiplica contra el **sRGB del fichero**. Probado con un experimento de una
variable (cielo pintado de rojo puro + medida de la fachada): con el cielo rojo,
la razón G/B de la fachada midió 0,69, que es la del producto `sRGB x tinte`
(0,73) y no la del `lineal x tinte` (1,06).

Consecuencia: los tintes de la tabla 3.2 son
`objetivo_medido_en_la_referencia / media_sRGB_del_mapa`. Medias sRGB de los
cinco mapas con textura: roble 0,635/0,461/0,328 · yeso 0,390 neutro · gres
cepillado 0,418/0,388/0,346 · grava 0,473/0,420/0,331 · chapa 0,241/0,196/0,110.

Objetivos medidos en las referencias (sRGB): fachada ref4 (0,495/0,482/0,466);
tierra ref4 (0,429/0,407/0,381); cielo ref2 (0,855/0,886/0,914).

Verificación en captura `patio`: fachada del juego (0,505/0,495/0,477) contra
y azul.

### 3.1 Mapas de albedo

| Mapa | Media sRGB | Media lineal | C | H | Uso |
| --- | --- | --- | --- | --- | --- |
| `concrete_brushed_concrete_diff.jpg` | 0,418 / 0,388 / 0,346 | 0,146 / 0,125 / 0,098 | 0,072 | 36° | acera, calle y bordillo (`House_Tile`) |
| `ground_gravel_diff.jpg` (CC0 ambientCG) | 0,473 / 0,420 / 0,331 | 0,190 / 0,147 / 0,090 | 0,142 | 33° | **tierra del patio** (`House_Dirt`) |
| `wood_oak_wood_planks_diff.jpg` | 0,636 / 0,461 / 0,328 | **0,364 / 0,145 / 0,088** | **0,308** | 26° | suelos nobles y carpintería (`House_Wood`) |
| `plaster_painted_diff.jpg` (PaintedPlaster006, ambientCG) | rojo > verde > azul claro (crema) | — | bajo | — | **INTERIOR PINTADO** (`House_Gypsum`): el `gypsum_diff` del repo leía a cemento sucio en los muros; PaintedPlaster006 trae pintura que pelar y la capa de abajo crema, tal como pide ref3 `gypsum_diff` queda en el disco para `House_Fabric` (tapizado) |
| `metal_metal_plate_diff.jpg` | 0,241 / 0,196 / 0,110 | 0,049 / 0,034 / 0,012 | 0,131 | 39° | chapa: electrodomésticos y radiadores (`House_Metal`) |

Roughness media (gris neutro): hormigón 0,509 · gres cepillado 0,784 · yeso 0,876
· chapa 0,589 · roble 0,442. Normales: todos a `0,5 / 0,5 / 0,99` (sin sorpresas).

Lectura: **la única pieza de croma fuerte es el roble** (`C = 0,308`, tono 26°,
rojo el doble que el azul en lineal). Todo lo demás es de croma bajo (≤ 0,131) y
cálido (tonos 36°–39°) o neutro (yeso). De ahí que la casa lea **cálida por
material, no por luz**: el multiplicador de albedo es lo que corrige.

### 3.2 Tintes: quién manda en pantalla

El `.glb` sale **sin texturas y solo con el nombre de material**, y
`CombatMap._rebind()` pisa el material entero con `material_override`. Es decir:

- lo que se ve en casa = **`CombatMap.MAPS`** (y es el único tinte que cuenta);
- el tinte de `build_house.build()` solo vive si alguien lee el material del
  `.glb`, cosa que hoy no hace nadie;
- el tinte de `build_props.MATERIALES` solo valdrá cuando exista el enganche de
  `props.glb` (vigente).

| Material | `CombatMap.MAPS` (efectivo) | `build_house` (en el .glb) | m/vuelta |
| --- | --- | --- | --- |
| `House_Siding` | **0,779 / 1,046 / 1,421** · r 0,85 | 1,25 / 1,50 / 1,65 | 1,2 |
| `House_Tile` | **0,958 / 1,019 / 1,128** · r 0,72 | 0,52 / 0,52 / 0,53 | 2,6 |
| `House_Dirt` | **0,792 / 0,828 / 0,933** · r 0,95 | — | 3,0 |
| `House_Wood` | **0,472 / 0,629 / 0,823** · r 0,85 | 0,40 / 0,30 / 0,20 | 1,2 |
| `House_Metal` | 1,00 / 1,06 / 1,18 · met 0,55 · r 0,40 | 0,55 / 0,57 / 0,60 · met 0,75 | 1,6 |
| `House_Graffiti` / `House_GraffitiB` | tag CC0 sobre blanco · alfa scissor 0,35 · `cull_disabled` | — | 2,0 |
| `House_Scaffold` | **0,62 / 0,64 / 0,66** · met 0,55 · r 0,42 | 0,62 / 0,64 / 0,66 | 2,0 |
| `House_Tarp` | **0,155 / 0,285 / 0,165** · r 0,90 | 0,155 / 0,285 / 0,165 | 2,0 |
| `House_Bark` | **0,33 / 0,33 / 0,34** · r 0,92 | 0,33 / 0,33 / 0,34 | 2,0 |
| `House_Glass` | 0,55 / 0,58 / 0,60 · met 0,50 · r 0,30 | 0,045 / 0,055 / 0,065 | 2,0 |
| `House_Mirror` | 0,80 / 0,84 / 0,88 · met 0,95 · r 0,05 | igual | 2,0 |
| `House_Lamp` | 0,30 / 0,20 / 0,12 · r 0,70 · emisión ámbar 0,30 | 0,95 / 0,78 / 0,50 | 2,0 |
| `House_Bulb` | 0,20 / 0,12 / 0,06 · r 0,40 · emisión 1,00/0,70/0,42 x2,20 | 0,30 / 0,16 / 0,06 | 2,0 |
| `House_Fabric` | 0,30 / 0,32 / 0,36 · r 0,95 | 0,30 / 0,31 / 0,34 | 2,0 |

Dos decisiones que ya están tomadas y aquí se recogen:

- el roble **sube verde y azul** (0,472 / 0,629 / 0,823): su sRGB es
  1,94 veces más rojo que azul y una casa USA weathered es gris blanquecina;
- la chapa del andamio **no comparte material con la obra**: es tubo
  galvanizado claro, no chapa herrumbrosa (en captura salía negro).

### 3.3 GRAFFITI (REF4 "graffiti pared", REF5 "tag rojo en la pared")

Diez tags en el árbol: seis en muros interiores de las dos plantas y dos en la
lona de la valla. Textura CC0 recortada del atlas **ambientCG GraffitiSet001**
(dos celdas de las dieciséis, a 256 px: el atlas entero son 290 KB para catorce
tags que nadie va a ver).

**NO son `Decal` de Godot, y es una decisión medida**: el motor sólo proyecta
**ocho decales por malla**, y esos ocho los necesita el agujero de bala
(`ImpactFX.HOLES_PER_SURFACE`), que es el único feedback de puntería que hay.
Cuatro tags por pared habrían gastado la mitad del presupuesto de impactos de
todas las paredes del mismo material.

Son láminas de 2 mm con la UV 0..1 del dibujo, fundidas **por tag** (dos mallas,
no diez: diez mallas eran diez draw calls, medido draws 76 -> 92 y +1,4 ms de
mediana) y material con **alfa scissor** — borde duro, cero ordenación de
transparentes.

### 3.4 Mapas sin uso en el árbol

`metal_plate_grain.jpg`, `metal_paint_grain.jpg`,
`concrete_concrete_{diff,nor_gl,rough}.jpg` y las cuatro pieles `skin_*.jpg`.
2,1 MB versionados que no cargaba nadie.

`ground_gravel_*` entraron aquí como reemplazo y ahora **salen del árbol activo**
junto con `gypsum_*`, y el motivo es una medida, no una preferencia: **el runtime
no los lee**. El único sitio que los citaba era `build_house.material()`, y el
`.glb` que ese builder exporta va **sin imágenes** (`export_image_format="NONE"`),
así que esas rutas no llegaban nunca a un píxel. La autoridad de lo que se ve es
`CombatMap.MAPS`, y `House_Dirt` carga `asphalt_cracked_*` (no la grava) y
`House_Gypsum` carga `plaster_painted_*` (no el yeso). Los cinco ficheros se han
movido a `downloads/textures_fuera_de_runtime/` (fuera de git, como el resto del
material de trabajo): **1.446.667 B menos** en el árbol versionado. Los dos
builders apuntan ahora a la MISMA textura que el runtime, para que no vuelvan a
divergir.

**Tercera pasada, el arma.** `g19_pistol_Image_5.png` (2048², el "mapa de
emisión" del asset) se ha **borrado con su sampler**: sus tres canales miden
`0,0 / 0,0 / 0,0`, o sea que `EMISSION = texture(emission_tex, UV).rgb *
emission_energy` escribía negro exacto a cambio de un sampler, una textura en
VRAM y un fetch por fragmento del arma. `shaders/glock_pbr.gdshader` ya no
declara la uniform. Además los cinco `.glb.import` pasan de
`meshes/light_baking=1` a `0`: el proyecto no tiene **ni un** `LightmapGI` ni
`VoxelGI` (medido: 0 en `scenes/`), así que el importador generaba y guardaba
UV2 para 110.569 triángulos de un lightmap que no existe.

---

## 4. Muebles por cuarto (dos plantas)

### 4.1 Planta baja — **vigente** en `house.glb`

81 piezas de mobiliario horneadas en la carcasa: **46 con colisionador**
(44 cajas + 2 cilindros) y **35 láminas decorativas sin colisión** (`plate()`
no duplica el colisor de lo que ya responde; la excepción es `Mirror_Dorm`, que
es lámina con `collider()` explícito y cuenta en los 46).
cuerpos de mobiliario —los dos que faltaban en la cuenta, `C260_CoatRack` y
`C278_Boiler`, ya estaban dentro—. El total de cuerpos de la casa (296) no
cambia: lo que estaba mal era el desglose.

**Sala (oeste, x -5,336 a -0,98)**

- Sofá de 6 cajas en `-3,05 / 0,21 / 3,62` (base 2,20 x 0,42 x 0,95, respaldo,
  dos brazos y dos cojines de cáscara yeso con `thin 0,06`).
- Mesa de centro 1,16 x 0,44 x 0,58 en `-2,90 / 0,22 / 1,90` (tapa 1,24 x 0,045 sin colisión).
- Alfombra 3,00 x 2,60 (lámina, sin colisión), mueble de TV 0,46 x 0,56 x 1,70 en
  `-1,24 / -0,60` y pantalla 1,20 x 0,68 de cáscara (la bala pasa).
- Radiador `Rad_Sala` 0,90 x 0,50 x 0,06 en `-3,30 / 4,24` (chapa, cáscara 6 mm).
- Maceta de gres (lámina) en `-4,90 / -2,30`.

**Dormitorio, dentro de esa misma sala** (medido: la planta baja oeste es UNA
pieza, no hay tabique entre ellos)

- Cama: bastidor 2,00 x 0,34 x 1,80 en `-4,25 / 0,17 / 1,90` (pine macizo: **sí es cobertura**),
  colchón 1,90 x 0,26 x 1,70 de papel (**no es cobertura**), cabecero y dos almohadas.
- Dos mesillas 0,46 x 0,56 x 0,46 en `x = -5,05` (z 3,30 y 0,50).
- Armario 1,70 x 2,10 x 0,60 en `-2,60 / -4,90` (pine macizo: sí es cobertura).
- Espejo de cuerpo entero 0,02 x 1,70 x 0,60 en `-1,00 / 2,60` (laminilla, cáscara 2 mm).

**Vestíbulo / pasillo (centro)**

- Consola 0,30 x 0,84 x 1,00 en `-0,66 / 3,30` (cáscara 20 mm).
- Percha cilindro r 0,05 h 1,90 en `-0,60 / 1,60`.

**Cocina (este-sur, x 1,98 a 5,336, z -2,20 a 4,336)**

- Encimera norte 3,00 x 0,90 x 0,62 en `3,67 / -1,89` con tapa de gres;
  encimera este 0,62 x 0,90 x 2,60 en `5,05 / 2,90` con tapa de gres.
- Fregadero 0,56 x 0,12 x 0,46 (chapa, cáscara 4 mm), placa 0,66 x 0,92 x 0,60
  en `5,02 / 1,30`, frigorífico 0,72 x 1,86 x 0,70 en `4,98 / 3,95` (acero macizo: sí es cobertura).
- Mesa 1,40 x 0,05 x 0,86 con 4 sillas (asiento y respaldo de 18 mm, cáscara).
- Radiador `Rad_Cocina` 0,80 x 0,50 x 0,06 en `4,30 / -2,08`.

**Baño (este-norte, x 1,98 a 5,336, z -5,336 a -2,36)**

- Inodoro (base + depósito, yeso cáscara), lavabo con pie, espejo 0,55 x 0,75
  (laminilla), lavadora 0,60 x 0,84 x 0,60 (acero macizo: sí es cobertura) y caldera
  cilindro r 0,30 h 1,24 en `5,05 / -2,62`.

**Estudio (mezclado dentro de ese mismo baño)**

- Escritorio 1,20 x 0,05 + dos patas en `4,30 / -2,80`, silla en `4,30 / -1,95`,
  dos estantes 1,60 x 1,90 x 0,32 (z -5,05) y tres tacos de libros sin colisión.

**Planta alta.** La carcasa hornea allí el radiador `Rad_Estudio`
(0,90 x 0,50 x 0,06 en `3,40 / 4,30 / -5,25`) y el mobiliario fijo (cama,
armario, mesillas, escritorio del estudio); `props.glb` añade 9 piezas más
(escritorio y estantería del dormitorio, cama de invitado, ropero, estanterías,
alfombras, cuadros y la mesa de la galería).

### 4.2 Conflictos medidos dentro de `house.glb`

Cuatro solapes de mobiliario dentro de mobiliario (`Coffee_body` ↔ `Bed_frame`,
`Counter_E` ↔ `Fridge`, `Shelf_1` ↔ `Washer`, `Shelf_2` ↔ `WC_base`): deuda de
arte, no bloquean el paso.

Los que bloqueaban el paso van resueltos en la tabla:

| Defecto | Medida | Corrección |
| --- | --- | --- |
| El vano del baño (`z = -2,28`, `x 2,35..3,25`) quedaba detrás de la encimera norte (hasta `x = 2,17`) | paso imposible | encimera recortada a `x 3,57..5,17` |
| La mesa + 4 sillas dejaban huecos de 0,55 y 0,44 m contra los muros | cápsula del jugador = 0,68 | mesa al este con 2 sillas y pasillo oeste de 1,32 m |
| El radiador de cocina en el pasillo | acuñaba al jugador en `2,34 / -1,14` | movido a la pared sur |
| El pie de la escalera a 0,24 m del muro norte | encallado a 0,75 m del pie | pie en `z = -3,60`, 1,76 m de rellano |
| La silla del estudio al otro lado del tabique de su escritorio | sin paso | sigue igual: el escritorio del estudio se alcanza desde el otro lado |

### 4.3 Mobiliario de `props.glb` — **vigente**

`tools/build_props.py` exporta 22 piezas con 21 colisores en 5 materiales, y
`CombatMap._props()` las funde por material (22 mallas -> 5). Rectángulos `ROOMS`
 y el propio documento usa 3,00 dos veces mas abajo):

| Cuarto | x | z | Mobiliario |
| --- | --- | --- | --- |
| `patio` | -7,40 a 7,40 | 4,60 a 8,60 | macetero, palés, banco de jardín, cubo, dos cajas, maceta |
| `salon` | -5,36 a -0,98 | -5,36 a 4,36 | sofá, mesa auxiliar, mueble + TV, estantería, butaca, lámpara, alfombra, radiador, maceta, cuadros |
| `cocina` | 1,98 a 5,36 | -2,20 a 4,36 | despensa, mesa + sillas |
| `bano` | 1,98 a 5,36 | -5,36 a -2,36 | (la casa ya hornea inodoro, lavabo, lavadora y caldera) |
| `pasillo` | -0,82 a 1,82 | -5,36 a 4,36 | consola, alfombra, cuadros |
| `dorm` (alta) | -5,36 a -0,98 | -5,36 a 4,36 | escritorio + silla, estantería, alfombra, cuadro |
| `galeria` (alta) | -0,82 a 1,82 | **0,56** a 4,36 | mesa + 2 sillas. El rectángulo arranca en `+0,56` y no en `-0,96`: al norte está el HUECO de la escalera y el corredor oeste, que son circulación, no sitio de mueble |
| `estudio` (alta) | 1,98 a 5,36 | -5,36 a 4,36 | estantería, cama individual, ropero, alfombra, cuadro |

### 4.4 Diferencias medidas entre `build_props.ROOMS` y la carcasa

**Cerradas.** Las cuatro que este documento declaraba abiertas se resolvieron al
exportar el `.glb`: el norte se recortó a `z0 >= -5,36` (nada entra en el muro),
`comedor`/`dorm1` desaparecieron (la casa tiene UNA cocina y UN dormitorio por
planta, y `ROOMS` se reescribió sobre los cuartos reales), `NIVEL_ALTA` se usa
como cota de apoyo de los props y la doble cocina se resolvió dejando la cocina
donde la hornea la carcasa (este-sur) y poniendo en `build_props` solo lo que
falta. El autocote del builder comprueba cada pieza contra los 296 colisores de
`scenes/House.tscn` en SOLO LECTURA y **no exporta** si hay solape: cazó dos
apilada nuevas).

---

## 5. Los ocho puestos enemigos

`CombatMap.POSTS` (coordenadas y yaw exactos del runtime). OCHO puestos, y el
enemigos en posiciones". Los dos últimos entraron por las ampliaciones este y
norte, y son los que `CombatMap._spawn_enemies` cuenta en su log
(`CASA enemigos: 8 puestos (3 PB, 2 PB banda norte, 3 planta alta)`):

**3 en planta alta (`TechoA`, `TechoB`, `Estudio`) y 5 en planta baja.**

| # | Nombre | Posición | Yaw (rad) | Piso | Por qué es buen sitio |
| --- | --- | --- | --- | --- | --- |
| 1 | `Sofa` | `-4,60 / 0,05 / 0,30` | 0,6 | baja | Oeste de la sala, a 0,74 del muro oeste y a 4,6 del eje de entrada: cobertura tras el mueble y flanqueo de la galería y la puerta de calle |
| 2 | `Cocina` | `2,65 / 0,05 / 3,60` | 0,3 | baja | Suroeste de la cocina, **movido a propósito fuera del mueble** (veredicto `fec1dda`): el puesto anterior `4,70 / 0,05 / 2,90` caía **entre encimera y silla** y el enemigo montaba sobre la mesa; el nuevo sitio deja 0,6 m de sitio de pie y línea limpia a la puerta. Con el puesto 1 forma **tenaza asimétrica** sobre el eje `x = 0` por donde se entra: 4,60 al oeste vs 2,65 al este |
| 3 | `TechoA` | `-2,90 / 3,00 / 1,40` | -2,0 | alta | Dormitorio oeste a 3,00 (cara superior real del forjado; los postes flotaban 0,25 m) |
| 4 | `TechoB` | `3,00 / 3,00 / -1,40` | -2,9 | alta | Dormitorio este: cubre la mitad este de la planta alta y la bajada del balcón |
| 5 | `Bano` | `5,60 / 0,05 / -4,00` | 0,9 | baja | AMPLIACIÓN ESTE: esquina fierro del baño, cobertura de la pared de azulejos |
| 6 | `Estudio` | `5,40 / 3,00 / -3,40` | 2,6 | alta | AMPLIACIÓN ESTE: escritorio del estudio, domina la planta alta este |
| 7 | `Dorm` | `-3,20 / 0,05 / -5,60` | 2,6 | baja | AMPLIACIÓN NORTE: retaguardia del dormitorio con el armario de cobertura (la banda de +0,92 m aguanta cuerpo + retranqueo) |
| 8 | `EstNorte` | `5,20 / 0,05 / -5,70` | 0,0 | baja | AMPLIACIÓN NORTE: esquina biblioteca del estudio, mira a la puerta |


- **Los de arriba son tres y diagonales** (oeste-sur `TechoA`, este-norte
  `TechoB`, este-norte alto `Estudio`): no se cubren entre ellos y barren la
  planta alta casi completa.
- Los de abajo flanquean la galería; los de arriba **dominan desde la altura y
  caen al rodar** (el ragdoll recibe el impulso de verdad, y un cuerpo que cae
  se lee sin adorno). Medido: la losa alta está en 3,00 y `POSTS` los pone en
  `y = 3,00`, que es la cara superior real del forjado.
- `y = 0,05` en planta baja y `y = 3,00` en alta: **`Enemy.gd` no pega al
  enemigo al suelo** (no hay raycast de suelo), así que la cota es la de
  `POSTS` y nada la corrige.
- Sin `assets/models/enemy.glb` el mapa sale vacío y se avisa en consola
  (dependencia declarada, no fallo).

---

## 6. Flujo de combate

1. **Lobby** (`Main.gd` → `Lobby.gd`): una sola línea de combate. `mode_chosen`
   construye el mapa con `_build_mode("combat")` y llama `CombatMap.build()`.
   Las herramientas de medida entran en directo con `--mode=combat`.
2. **`build()`**, en este orden: escribe sobre el `WorldEnvironment` **activo**
   (el de `Main.tscn`, el único de la escena) y guarda su valor de origen →
   instancia `House.tscn` → reengancha los 20 materiales **por nombre**
   → sombras de contacto de los props con meta `contact` → sol + 3 rellenos →
   siembra los 8 enemigos → `AmmoTable` en `1,30 / 0,00 / 3,00` (vestíbulo, a un
   paso de la puerta y fuera de la línea de `check_walk`).
3. **Entrada del jugador**: `SPAWN["combat"] = (0, 0,05, 7,40)`, yaw 0. Está en
   el **patio**, mirando la puerta de calle; la línea recta de caminata entra en
   `x = 0` por el vano `x -0,69..0,69` (`VANO = 0.55 * ZOOM_PLANTA = 0,6875`,
   `build_house.py:1531`; el 0,55 era pre-escalado). La calle se ve primero: es el choque de
   exposición del apartado 7.
4. **Zonas de exposición** (rectángulos en x, z; **no distinguen planta**, medido
   que la diferencia entre pisos es media exposición). Se recorre en orden y
   manda la primera que contiene la cámara:

   Copiado de `CombatMap.ZONES`: si cambia allí, esta tabla miente.

   | Orden | Rectángulo (x, z) | tamaño | zona | exposición | ambiente | cielo | contrib. |
   | --- | --- | --- | --- | --- | --- | --- | --- |
   | 1 | 1,9 / -6,2 | 4,4 x 4,0 | baño-estudio, el rincón más oscuro | 3,18 | 0,100 | 1,05 | 0,26 |
   | 2 | -6,2 / -6,2 | 5,3 x 10,56 | oeste (sala y dormitorio) | 3,00 | 0,170 | 1,10 | 0,38 |
   | 3 | 1,9 / -2,2 | 4,4 x 7,44 | este-sur (cocina/comedor) | 2,95 | 0,170 | 1,10 | 0,40 |
   | 4 | -0,9 / -6,2 | 2,8 x 10,56 | pasillo y vestíbulo | 2,82 | 0,195 | 1,15 | 0,44 |
   | — | fuera (patio y calle) | — | por defecto | **1,95** | 0,470 | 1,55 | 1,00 |

5. **Combate**: `Ballistics` avisa a todos los enemigos con `hear(point)` en cada
   disparo. La herida **nunca decide si muere** (siempre muere); decide cómo cae:
   cabeza = instantanea, pecho = retardo corto, pierna = tropiezo y ragdoll a
   0,90 s. Cuerpos construidos **al morir**, no al montar (48 cuerpos rígidos por
   enemigo x 4 = 192 que no existen en el mapa vivo).
6. **Salir**: doble ESC. `_exit_tree()` devuelve exposición, ambiente, cielo,
   contribución y color **tal cual estaban** en `Main.tscn`, y el nodo del mapa
   se borra entero.

---

## 7. Luz cálida contra exterior quemado

**Interior cálido.** Todo es interior pintado, no cielo rebotado:

| Fuente | Valor |
| --- | --- |
| Ambiente del interior (`AMBIENT_INDOOR`) | **0,64 / 0,62 / 0,60**. El 0,74/0,65/0,51 anterior teñía TODO el interior de naranja (croma 0,18-0,25 y R-B +0,18..+0,25 contra 0,05-0,14 y R-B -0,06..+0,01 de las cinco referencias) |
| Sol (única luz con sombra) | rotación `-46, -20, 0`, color **0,98 / 0,97 / 0,95**, energía **0,30**, sombra a **16 m**, sin disco solar (`SKY_MODE_LIGHT_ONLY`), `light_cull_mask = 1 or 4` (capa exterior) |
| `Fill_Sala` | En la bombilla `-3,67 / 2,15 / -0,96` (caliente 0,95/0,90/0,82, `CombatMap.gd:861`), energía **0,50**, alcance **3,2** (PALANCA MEDIDA), atenuación 2,0. La sala es 7,38 m ancho x 10,64: una bombilla con radio 3 no la cubria y los rincones del ala nueva quedaban negros (captura `look` medido en marco) |
| `Fill_Dorm` | Bombilla alta `-3,67 / 5,05 / -0,96` (centro del dorm, re-centrado a la sala), energía **0,46**, alcance **3,2** |
| `Fill_Estudio` | NUEVO: cuarto de estudio alta `4,20 / 5,05 / -4,30`, energía **0,38**, alcance **3,0** — la campana del estudio estaba a z −0,9, dentro del P_Div: movida a −4,30 y su relleno entró; coste +1,1 ms |
| `Fill_Bano` | NUEVO: bano PB `4,20 / 2,15 / -4,30`, energía **0,40**, alcance **2,8** - el bano ampliado (6,36 x 3,92) era el cuarto mas oscuro sin foco propio; coste medido +1,4 ms del frame (omnis valen por pixel de su esfera) |

`omni_attenuation` subió de 0,9 a **2,0**: con 0,9 la omni de planta baja dejaba
un disco de luz casi plano sobre TODO el techo de la planta baja (visible en la
captura `back`) y el interior parecía iluminado desde dentro — el "el sol está

Los rellenos van **sin sombra** y con cull mask 1 para no tocar el viewmodel.
En Mobile cada luz se paga por pixel de lo que caiga en su radio, de aquí que
vayan con alcance corto (3,2 / 2,8 / 3,2 / 3,0 en `CombatMap._lights`) en vez
de pedir una bombilla más por cuarto. Son **cuatro** (`Fill_Sala`, `Fill_Bano`,

**Exterior quemado.** El cielo es una cúpula GRIS CLARA, más brillante en el
horizonte que en el cenit, porque es la fuente de luz de un día cubierto:
`sky_top 0,50 / 0,525 / 0,575`, `sky_horizon 0,80 / 0,845 / 0,88`,
`ground_horizon 0,66 / 0,665 / 0,67` (`scenes/Main.tscn`). Los valores viejos
—azul despejado arriba y horizonte marrón— son el defecto medido que
a 0,05-0,14 y R-B -0,06..+0,01 de las cinco referencias. Fuera no hay
adaptación automática (el renderer es **Mobile**, no Forward+), así que la calle
quemada se consigue con la diferencia de zonas:

| | dentro (patio se ve desde dentro) | baño (ríncon más oscuro) | fuera |
| --- | --- | --- | --- |
| exposición tonemap | 2,82 a 3,00 | 3,18 | **1,95** |
| energía de ambiente | 0,170 a 0,195 | 0,100 | **0,470** |
| energía del fondo (cielo) | 1,05 a 1,10 | 1,00 | **1,55** (`CombatMap.EXPOSURE_DEFAULT`) |
| contribución del cielo al ambiente | 0,28 a 0,34 | 0,18 | **1,00** |

Y la **adaptación asimétrica** (es cómo se comporta el ojo): salir a la luz usa
`ADAPT_TO_LIGHT = 2,0` (90 % en 1,15 s) y entrar en la oscuridad
`ADAPT_TO_DARK = 0,8` (90 % en 2,88 s). La interpolación es exponencial:
`1 - exp(-rate * delta)`.

Todo el ambiente sale de ahí: `Main.tscn` tiene SSAO, SSIL, glow, **niebla** y
niebla volumétrica **apagados**, tonemap ACES, saturación 1,02 y contraste 1,06.

**La niebla está apagada por una medida, no por gusto**: `tools/medir.sh perfil`
le cobró **9,1 ms** de un cuadro de 50,4 (A/B interleaved: 49,9 con niebla contra
40,8 sin ella) en esta HD520 a 1080p, y por eso `Main.tscn` la trae en
`fog_enabled = false`. El número es de la versión que la tenía encendida: con la
niebla ya apagada, `--no-glow=1 --no-fog=1` no puede volver a medirla (los dos
ya valen `false`), así que la fila `sin_glow_fog` de `medir.sh perfil` solo
puede dar ruido. Lo que tapa el vacío de verdad es la
arboleda (132 árboles pelados a 26-122 m) más la manzana vecina, y la perspectiva
aérea que la niebla daba gratis va **cocida** en el color de corteza y de las
casas vecinas.

---

## 8. Lo que este documento no toca

`README.md` (constitución) y las cinco referencias de `docs/refs/`.

### 8.1 Rendimiento medido (1080p, HD520, modo combate)

`tools/medir.sh base`: **p50 = 24,24 ms = 41,2 FPS de mediana** (mean 24,33,
p95 25,00, 81 draws, 353.706 prims), a `scaling_3d` 0,65 y filtrado **bilinear**
—FSR no existe en el renderer Mobile, así que `mode=0` es lo que de verdad
corre—. `tools/bench_render.gd` lee esa escala DEL PROYECTO en vez de clavar 1,0
(el banco medía una configuración que ya no existía). OJO AL MEDIR: en esta
máquina hay escritorio y navegador, y con carga de fondo la media sube a 38-43 ms
con p95 de 100+ **sin que la mediana se mueva**. La mediana es el número honesto;
la media, con esta carga, mide al vecino. Referencia de la constitución: 40 FPS
(25 ms). Medido: **41,2 FPS**, cumpliendo el objetivo de la constitución.

HUD 1,4 / mundo 0,3. Recortes, todos medidos: niebla fuera; capa exterior (3)
para suelo, valla, árboles y vecinos con las omnis del interior fuera de su
máscara; pase de sombras sin el vestuario lejano; sol de 24 a 12 m (pasando por
16).

Dos de esas filas ya no se pueden reproducir: la niebla y el glow nacen apagados
en `Main.tscn`, así que `--no-glow=1 --no-fog=1` mide cero por construcción. La
tabla del estado de HOY, medida con `tools/medir.sh perfil` (A/B interleaved,
1080p, combate, 120 frames, HD520), es:

| variante | dmean | dp50 | dp95 | dp99 |
| --- | --- | --- | --- | --- |
| `sin_mundo` | −22,80 | −22,50 | −25,30 | −26,65 |
| `sin_luces` | −12,30 | −12,33 | −12,63 | −12,88 |
| `sin_hud` | −2,67 | −2,11 | −4,53 | −5,42 |
| `sin_sombras` | −0,63 | −1,15 | +0,56 | −0,96 |
| `sin_glow_fog` | −0,23 | −0,81 | +2,37 | +3,03 |

Referencia `todo`: mean 30,06 ms (r1) / 28,74 ms (r2). Las dos últimas filas están
dentro del ruido: `sin_sombras` solo aísla el pase del sol (los cuatro rellenos ya
nacen sin sombra) y `sin_glow_fog` no puede restar nada porque ambos ya están
`World` que no existe —el mundo es `Main/Combat`, el hijo del modo— y ya apunta
ahí.

### 8.2 El enemigo (16.419 tris)

**16.419 tris, 53 huesos, 1,78 m** (`Enemy.BODY_HEIGHT`, medido del hueso
`Head` menos `Foot_L`), y el glb exporta **3 clips** —`Idle`, `Walk` y `Neck`—
de las **46 animaciones CC0** que trae la *Universal Animation Library* de
Quaternius (`Idle_Loop`, `Walk_Loop`, `Death01`, `Hit_Chest`, `Pistol_Aim_*`,
`Pistol_Shoot`...). Los tres son los que pide `Enemy.gd`; el resto no viaja al
asset. El equipo lo construye
`tools/build_kit.py` (autoridad propia, 48 piezas: casco
con montura NIV, pasamontañas, porta-placas, faja, tirantes, bolsas, hombreras,
mangas, coderas, guantes, pantalón, rodilleras, botas y rifle con correa).
Todas las cotas del equipo salen del alto real del rig con reglas
antropométricas.

Fuente, licencia y por qué ese cuerpo: ver la cabecera de `tools/build_enemy.py`.
Resumen: **CC0, sin crédito obligatorio, descargable sin cuenta**; no existe un
soldado realista completo, riggeado, animado y con licencia limpia en fuentes
gratuitas (lo gratis es realista-con-licencia-que-prohíbe-armas, o
limpia-pero-low-poly, o descargable-pero-sin-animaciones).

Cambiar de cuerpo es `--fbx <ruta>`: el importador traduce el rig **en el JSON

Coste medido: la mediana del cuadro pasa de 33,9 a 35,2 ms (29,2 -> 28,6 FPS)
por un enemigo 10 veces más pesado. Es el intercambio que pide la regla 1

### 8.3 Lo que sigue abierto
- **Cara del soldado**: el cuerpo es un maniquí liso y lo que se ve es el casco
  y el pasamontañas, que es lo que pide la referencia (ref5 tiene la CARA
- **Piel y tela del equipo**: los dos slots usan la tela CC0 `fabric_*.jpg`
