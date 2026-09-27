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
  declaran las dos y se marca la decisión como **pendiente**: nadie decide esto
  por escrito hasta que se mida en juego.

Medición de la paleta: PIL sobre cada mapa de `assets/textures/real/`, imagen
reescalada a 256x256, media en sRGB y media convertida a lineal (IEC 61966-2-1);
`C` = croma (max-min en sRGB) y `H` = tono en grados. Medición de la casa:
lectura de los 158 `StaticBody3D` de `scenes/House.tscn` (156 `BoxShape3D` +
2 `CylinderShape3D`) con su `position` y `size`, que es el dato exacto con el
que corre la física y `Ballistics`.

---

## 1. Estado del árbol

| Pieza | Estado |
| --- | --- |
| `assets/models/house.glb` + `scenes/House.tscn` | **Vigente**. 158 cuerpos: 108 de carcasa y 50 de mobiliario. |
| `scripts/CombatMap.gd` | **Vigente**. Materiales, luz, zonas de exposición y los 4 puestos. |
| `tools/build_props.py` → `assets/models/props.glb` | **Pendiente**. El builder existe; el `.glb` todavía no está en el árbol. |
| `docs/HOUSE_DESIGN.md` | Este fichero (la ficha de arte que los dos builders citan). |

---

## 2. Cotas de la casa

### 2.1 Estructura (medida en `House.tscn` y `tools/build_house.py`)

| Concepto | Cota |
| --- | --- |
| Eje de muros este/oeste | `x = ±5,48`; cara interior `±5,36` (muro de 0,24) |
| Eje de fachada y trasera | `z = +4,48` (sur, a la calle) y `z = -5,48`; caras interiores `4,36` / `-5,36` |
| Forro interior de yeso | 24 mm: cara útil aproximada `x ±5,336`, `z 4,336 / -5,336` |
| Suelo planta baja | `y = 0` (losa `Ground` de -0,30 a 0, 14,80 x 16,40) |
| Forjado | 2,80 a 3,00 (colisores `C076..C078_Slab2` en `y = 2,90`, 0,20 de canto) |
| Techo planta baja / suelo de la alta | cara inferior 2,80 / cara superior 3,00 (acabado `Floor_Dorm` a 3,011) |
| Techo planta alta / cubierta | 5,60 / losa 5,60 a 5,75 (`C079_Roof` en `y = 5,67`) |
| **Altura libre real** | planta baja **2,80** (0 → 2,80) · planta alta **2,60** (3,00 → 5,60) |
| Tabique sala-pasillo | `x = -0,90` (caras -0,98 / -0,82), de `-5,36` a `4,36`, ambas plantas |
| Tabique pasillo-este | `x = 1,90` (caras 1,82 / 1,98), de `-5,36` a `4,36`, ambas plantas |
| Tabique cocina-baño | `z = -2,28` (x 1,98 a 5,36), **solo planta baja** |
| Escalera | 16 pasos, huella 0,26 x contrahuella 0,1875, **35,8°**; `x 0,98..1,78`, primer peldaño en `z = -5,12`; hueco `x 0,92..1,82` hasta `z = -0,96`; rampa `C105` (0,80 x 0,38 x 5,32, centro `1,38 / 1,29 / -3,01`) |
| Barandas | galería en `x = 0,92` (z -5,20 a -1,06) y las tres del balcón (y = 3,00 a 4,00) |
| Balcón | losa 1,60 x 1,70 en `3,70 / 2,90 / 5,45`, con puerta alta `x 3,20..4,15` |

Suelos horneados (`finishes()`): roble en el oeste completo y en la planta alta;
gres en el pasillo (`Floor_Hall`), en la cocina (`Floor_Cocina`, x 1,98 a 5,36,
z -2,20 a 4,36) y en el baño (`Floor_Bano`, x 1,98 a 5,36, z -5,36 a -2,20);
techos de escayola.

### 2.2 Cuartos (rectángulos interiores, caras de muro ya descontadas)

**Planta baja (`y = 0`)**

| Cuarto | x | z | Suelo |
| --- | --- | --- | --- |
| Sala (oeste entero) | -5,336 a -0,98 | -5,336 a 4,336 | roble |
| Vestíbulo / pasillo | -0,82 a 1,82 | -5,336 a 4,336 | gres |
| Cocina (este-sur) | 1,98 a 5,336 | -2,20 a 4,336 | gres |
| Baño (este-norte) | 1,98 a 5,336 | -5,336 a -2,36 | gres |
| Patio (a la calle, exterior) | -7,40 a 7,40 | 4,60 a 8,60 | losa `Ground`, fuera del muro de fachada |

**Planta alta (`y = 3,00`)**

| Cuarto | x | z | Nota |
| --- | --- | --- | --- |
| Dormitorio oeste | -5,336 a -0,98 | -5,336 a 4,336 | puerta `Door_Dorm` en `x = -0,90`, z -2,60 a -1,50 |
| Galería / escalera | -0,82 a 1,82 | -5,336 a 4,336 | hueco de escalera + baranda |
| Estudio este | 1,98 a 5,336 | -5,336 a 4,336 | sin tabique interior; ventana `Win_E_Estudio` y puerta de balcón al sur |
| Balcón | 2,90 a 4,50 | 4,60 a 6,30 | exterior |

---

## 3. Paleta croma medida (`assets/textures/real/`)

### 3.1 Mapas de albedo

| Mapa | Media sRGB | Media lineal | C | H | Uso |
| --- | --- | --- | --- | --- | --- |
| `concrete_concrete_diff.jpg` | 0,446 / 0,414 / 0,353 | 0,173 / 0,148 / 0,107 | 0,093 | 39° | obra de la casa (`House_Concrete`) |
| `concrete_brushed_concrete_diff.jpg` | 0,417 / 0,388 / 0,345 | 0,146 / 0,125 / 0,098 | 0,072 | 36° | gres de vestíbulo/cocina/baño/patio (`House_Tile`) |
| `wood_oak_wood_planks_diff.jpg` | 0,636 / 0,461 / 0,328 | **0,364 / 0,180 / 0,088** | **0,308** | 26° | suelos nobles y carpintería (`House_Wood`) |
| `gypsum_diff.jpg` | 0,390 / 0,390 / 0,390 | 0,127 / 0,127 / 0,127 | 0,000 | — | yeso pintado y, en props, tapizado (`House_Gypsum`, `House_Fabric`) |
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
  `props.glb` (pendiente).

| Material | `CombatMap.MAPS` (efectivo) | `build_house` (en el .glb) | `build_props` (pendiente) | m/vuelta |
| --- | --- | --- | --- | --- |
| `House_Concrete` | 0,58 / 0,56 / 0,51 · r 0,84 | 0,62 / 0,60 / 0,56 · r 0,84 | 0,74 / 0,74 / 0,76 (sobre gres) | 2,4 |
| `House_Tile` | 0,50 / 0,50 / 0,51 · r 0,70 | 0,52 / 0,52 / 0,53 · r 0,68 | — | 2,6 |
| `House_Wood` | **0,30 / 0,42 / 0,62** · r 0,80 | 0,40 / 0,30 / 0,20 · r 0,78 | 0,72 / 0,76 / 0,84 · r 0,78 | 1,2 |
| `House_Gypsum` | 0,78 / 0,76 / 0,72 · r 0,90 | 0,80 / 0,78 / 0,74 · r 0,90 | 0,88 / 0,86 / 0,82 (liso) | 2,0 |
| `House_Metal` | 1,00 / 1,06 / 1,18 · met 0,55 · r 0,40 | 0,55 / 0,57 / 0,60 · met 0,75 | 1,00 / 1,06 / 1,18 · met 0,35 | 1,6 |
| `House_Glass` | 0,05 / 0,06 / 0,07 · met 0,30 · r 0,07 | 0,045 / 0,055 / 0,065 | 0,90 / 0,93 / 0,96 · met 1,00 | 2,0 |
| `House_Mirror` | 0,80 / 0,84 / 0,88 · met 0,95 · r 0,05 | igual | — | 2,0 |
| `House_Fabric` | 0,30 / 0,32 / 0,36 · r 0,95 | 0,30 / 0,31 / 0,34 | 1,10 / 1,02 / 0,90 sobre yeso, tile 0,40 | 2,0 |

Dos decisiones que ya están tomadas y aquí se recogen:

- el roble **sube verde y azul** (0,30 / 0,42 / 0,62) respecto a su lineal
  0,364 / 0,180 / 0,088: sin eso, con el sol encima se quemaba a rosa;
- la obra **no es hormigón de banco**: sube rojo y baja azul (estuco cálido).

### 3.3 Mapas sin uso en el árbol

`diffuser_rib.png` (0,693 gris), `metal_plate_grain.jpg` (0,596) y
`metal_paint_grain.jpg` (0,746) **no los referencia ni el builder ni el
runtime**. Regla 10 del README: son candidatos a salir del árbol activo.
Decisión del dueño; este documento no los borra.

---

## 4. Muebles por cuarto (dos plantas)

### 4.1 Planta baja — **vigente** en `house.glb`

81 piezas de mobiliario horneadas en la carcasa: **50 con colisionador**
(48 cajas + 2 cilindros) y **31 láminas decorativas sin colisión** (`plate()`
no duplica el colisor de lo que ya responde; la excepción es `Mirror_Dorm`, que
es lámina con `collider()` explícito y cuenta en los 50).

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

**Planta alta: vacía.** Lo único horneado arriba es el radiador `Rad_Estudio`
(0,90 x 0,50 x 0,06 en `3,40 / 4,30 / -5,25`, y = 4,05 a 4,55). Dormitorios,
galería y estudio **no tienen ni un mueble** en el árbol activo.

### 4.2 Conflictos medidos dentro de `house.glb` (sin tocar nada)

Solapes de colisionador mayores de 5 cm entre piezas de mobiliario (el ensamblaje
del sofá se excluye: base, brazos y cojines se pisan a propósito):

| Piezas | Solape (x / y / z) |
| --- | --- |
| `Coffee_body` ↔ `Bed_frame` | 0,23 / 0,34 / 0,58 — la mesa de centro está metida en la cama |
| `Coffee_body` ↔ `Bed_mattress` | 0,18 / 0,10 / 0,58 |
| `Counter_E` ↔ `Fridge` | 0,60 / 0,90 / 0,60 — el frigorífico dentro de la encimera este |
| `Shelf_1` ↔ `Washer` | 0,50 / 0,84 / 0,21 — el estante del estudio dentro de la lavadora |
| `Shelf_2` ↔ `WC_base` | 0,38 / 0,40 / 0,29 — el otro estante dentro del inodoro |

Además: la silla del estudio (`z = -1,95`) queda al otro lado del tabique
`z = -2,28` de su escritorio (`z = -2,80`), y la puerta de ese tabique está en
`x 2,35..3,25`, no en `x = 4,30`: no hay paso entre las dos piezas.

### 4.3 Mobiliario pendiente (`tools/build_props.py`, aún sin exportar)

Rectángulos `ROOMS` del builder (planta alta = `NIVEL_ALTA = 2,90`):

| Cuarto | x | z | Mobiliario previsto |
| --- | --- | --- | --- |
| `patio` | -6,00 a 6,00 | 4,00 a 11,00 | macetero, palés, banco de jardín, cubo, dos cajas, maceta |
| `salon` | -4,88 a -0,82 | -0,94 a 3,88 | sofá 2,10, mesa auxiliar, mueble + TV, estantería, butaca, lámpara de pie, alfombra, radiador, maceta, 3 cuadros |
| `comedor` | 0,82 a 4,88 | -0,94 a 3,88 | mesa 1,60 x 0,90, 5 sillas, aparador, lámpara colgante, alfombra, maceta, cuadro |
| `cocina` | -4,88 a -0,82 | -5,88 a -1,06 | mueble bajo + fregadero, placa, mueble bajo lateral, cajalera, frigorífico, despensa, mesa + 2 sillas, cubo, cuadro |
| `bano_pb` | 2,28 a 4,88 | -5,88 a -3,46 | lavabo + espejo, inodoro, ducha con mampara, toallero, alfombra |
| `lavadero` | 2,28 a 4,88 | -3,34 a -1,06 | lavadora, estante, cubo, toallero, cajas |
| `pasillo` | -0,70 a 0,70 | -5,88 a 3,88 | consola, alfombra, 2 cuadros, puerta de entrada |
| `dorm1` (alta) | 0,82 a 4,88 | -0,94 a 3,88 | armario 2,00, cama 1,60 x 2,00, 2 mesillas, cómoda, espejo, lámpara, alfombra, radiador, cuadro |
| `dorm2` (alta) | -4,88 a -0,82 | -0,94 a 3,88 | cama 1,50, 2 mesillas, escritorio + silla, estante, alfombra, cuadro, lámpara |
| `dorm3` (alta) | -4,88 a -0,82 | -4,34 a -1,06 | cama 1,40, 2 mesillas, armario 1,50, cómoda, alfombra, cuadro, lámpara |
| `bano_alta` | -4,88 a -0,82 | -5,88 a -4,46 | bañera, inodoro, lavabo, espejo, toallero, alfombra |
| `estudio` (alta) | 2,28 a 4,88 | -5,88 a -1,06 | escritorio + silla, estante, cama individual, mesilla, alfombra, cuadro, lámpara |
| `pasillo_alta` | -0,70 a 0,70 | -5,88 a 3,88 | consola, alfombra, maceta, cuadro |

### 4.4 Diferencias medidas entre `build_props.ROOMS` y la carcasa

Pendiente de decisión **antes** de exportar `props.glb` (este documento no
elige autoridad):

1. **Norte invadido.** Todo `z0 = -5,88` está **0,52 m al norte** de la cara
   interior (`-5,36`) y **0,28 m al norte** de la cara exterior (`-5,60`):
   inodoro, bañera, lavabo, espejo y toallero de los baños entrarían en el muro
   de fachada.
2. **Este espejado.** `comedor` y `dorm1` arrancan en `x = 0,82`, pero el tabique
   `P_Hall` está en `x = 1,90` (caras 1,82 / 1,98): ese rectángulo lo cruza.
   El margen del oeste (`x1 = -0,82`) sí coincide con `P_Sala`.
3. **Nivel de la planta alta.** `NIVEL_ALTA = 2,90` es el centro de la losa
   (2,80 a 3,00), no su cara superior (`3,00`): los muebles de arriba quedarían
   hundidos 10 cm. Y `ALTURA = 2,70` no es ninguna altura libre real (2,80
   abajo, 2,60 arriba), así que `check()` dejaría pasar piezas a través del
   techo de la planta alta.
4. **Dos cocinas.** La carcasa hornea la cocina en el **este-sur** (suelo
   `Floor_Cocina`, ventana `Win_E_Cocina`, encimeras, fregadero, placa y
   frigorífico) y `build_props` la coloca en el **oeste-norte** (que en la
   carcasa es sala con suelo de roble). Mientras no se decida, la casa tendría
   dos cocinas y el comedor sentado sobre la horneada.

---

## 5. Los cuatro puestos enemigos

`CombatMap.POSTS` (coordenadas y yaw exactos del runtime). Dos por planta:

| # | Nombre | Posición | Yaw (rad) | Piso | Por qué es buen sitio |
| --- | --- | --- | --- | --- | --- |
| 1 | `Sofa` | `-4,60 / 0,05 / 0,30` | 0,6 | baja | Oeste de la sala, a 0,74 del muro oeste y a 4,6 del eje de entrada: cobertura tras el mueble y flanqueo de la galería y la puerta de calle |
| 2 | `Cocina` | `4,70 / 0,05 / 2,90` | -2,4 | baja | Este-sur, pegado a la encimera larga y al frigorífico; con el puesto 1 forma **tenaza** sobre el eje `x = 0` por donde se entra |
| 3 | `TechoA` | `-2,90 / 3,25 / 1,40` | -2,0 | alta | Dormitorio oeste a 3,25 de altura: domina la lectura de la galería y del hueco de escalera |
| 4 | `TechoB` | `3,00 / 3,25 / -1,40` | -2,9 | alta | Dormitorio este: cubre la mitad este de la planta alta y la bajada del balcón |

- **Dos arriba, dos abajo, y los de arriba diagonales** (oeste-sur / este-norte):
  no se cubren mutuamente y entre los dos barre la planta alta completa.
- Los de abajo flanquean la galería; los de arriba **dominan desde la altura y
  caen al rodar** (el ragdoll recibe el impulso de verdad, y un cuerpo que cae
  se lee sin adorno). Medido: la losa alta está en 3,00 y `POSTS` los pone en
  `y = 3,25`, así que esa holgura de 0,25 m viaja al modelo.
- `y = 0,05` en planta baja y `y = 3,25` en alta: **`Enemy.gd` no pega al
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
   (el de `Main.tscn`; un segundo environment sería inerte) y guarda su valor de
   origen → instancia `House.tscn` → reengancha los 8 materiales **por nombre**
   → sombras de contacto de los props con meta `contact` → sol + 3 rellenos →
   siembra los 4 enemigos → `AmmoTable` en `1,30 / 0,00 / 3,00` (vestíbulo, a un
   paso de la puerta y fuera de la línea de `check_walk`).
3. **Entrada del jugador**: `SPAWN["combat"] = (0, 0,05, 7,40)`, yaw 0. Está en
   el **patio**, mirando la puerta de calle; la línea recta de caminata entra en
   `x = 0` por el vano `x -0,55..0,55`. La calle se ve primero: es el choque de
   exposición del apartado 7.
4. **Zonas de exposición** (rectángulos en x, z; **no distinguen planta**, medido
   que la diferencia entre pisos es media exposición). Se recorre en orden y
   manda la primera que contiene la cámara:

   | Orden | Rectángulo (x, z) | zona | exposición | ambiente | cielo | contrib. |
   | --- | --- | --- | --- | --- | --- | --- |
   | 1 | 1,9 / -5,4 · 3,5 x 3,2 | baño-estudio, el ríncon más oscuro | 4,55 | 0,045 | 0,95 | 0,12 |
   | 2 | -5,4 / -5,4 · 4,5 x 9,8 | oeste (sala y dormitorio) | 4,20 | 0,100 | 1,00 | 0,20 |
   | 3 | 1,9 / -2,2 · 3,5 x 6,6 | este-sur (cocina/comedor) | 4,05 | 0,120 | 1,05 | 0,28 |
   | 4 | -0,9 / -5,4 · 2,8 x 9,8 | pasillo y vestíbulo | 3,75 | 0,160 | 1,10 | 0,38 |
   | — | fuera (patio y calle) | por defecto | 2,50 | 0,340 | 1,25 | 1,00 |

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
| Ambiente del interior (`AMBIENT_INDOOR`) | **0,68 / 0,64 / 0,58** (sustituye al 0,56 / 0,58 / 0,63 azulado de `Main.tscn`) |
| Sol (única luz con sombra) | rotación `-46, 168, 0`, color 1,00 / 0,97 / 0,92, energía 1,25, sombra a 42 m, **sin disco solar** (`SKY_MODE_LIGHT_ONLY`), cull mask 1 |
| `FillSala` | `-2,6 / 2,45 / 0,6`, 0,78 / 0,74 / 0,66, energía 0,85, alcance 7,5 |
| `FillEste` | `3,5 / 2,45 / 0`, 0,74 / 0,76 / 0,80, energía 0,85, alcance 7,5 |
| `FillGaleria` | `0,5 / 5,25 / 1,6`, 0,76 / 0,74 / 0,70, energía 0,55, alcance 5,0 (dos plantas no piden cuarta bombilla, piden que la de arriba no se lea hueca) |

Los tres rellenos van **sin sombra** y con cull mask 1 para no tocar el
viewmodel. En Mobile cada luz se paga por pixel de lo que caiga en su radio, de
aquí que las tres vayan con alcance corto (7,5 / 7,5 / 5,0) en vez de pedir una
cuarta bombilla para la planta alta.

**Exterior quemado.** El cielo es frío arriba y tierra quemada en el horizonte:
`sky_top 0,25 / 0,32 / 0,44`, `sky_horizon 0,42 / 0,38 / 0,34`,
`ground_horizon 0,34 / 0,33 / 0,32`. Fuera no hay adaptation automática (es
Forward+), así que la calle quemada se consigue con la diferencia de zonas:

| | dentro (patio se ve desde dentro) | baño (ríncon más oscuro) | fuera |
| --- | --- | --- | --- |
| exposición tonemap | 3,75 a 4,20 | 4,55 | **2,50** |
| energía de ambiente | 0,100 a 0,160 | 0,045 | **0,340** (hasta 7,5x más) |
| energía del fondo (cielo) | 1,00 a 1,10 | 0,95 | **1,25** |
| contribución del cielo al ambiente | 0,20 a 0,38 | 0,12 | **1,00** |

Y la **adaptación asimétrica** (es cómo se comporta el ojo): salir a la luz usa
`ADAPT_TO_LIGHT = 2,0` (90 % en 1,15 s) y entrar en la oscuridad
`ADAPT_TO_DARK = 0,8` (90 % en 2,88 s). La interpolación es exponencial:
`1 - exp(-rate * delta)`.

Todo el ambiente sale de ahí: `Main.tscn` tiene SSAO, SSIL, glow, niebla y
niebla volumétrica **apagados**, tonemap fílmico y saturación 1,03. Cero
postproceso que oculte un número mal medido.

---

## 8. Lo que este documento no toca

`README.md`, `*.py`, `*.glb`, `*.tscn`, `*.gd`, `*.gdshader`, y concretamente
nada del lobby, del tiro ni del enemigo. Aquí no se genera ningún `.glb`: las
secciones 4.3 y 4.4 quedan como decisiones abiertas para la siguiente pasada.
