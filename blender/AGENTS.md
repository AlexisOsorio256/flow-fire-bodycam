# Blender

Blender es la autoridad de modelos, mapa, rig y animación; Godot solo los usa.
Todo se edita por el Blender MCP (`execute_blender_code`) y se exporta desde él con
`runpy.run_path(<script>, run_name="__main__")`. Los exportadores no imprimen nada
y avisan con un archivo en `build/avisos/` (misma ruta para Python, Blender y Bash,
porque está dentro del repo).

| Archivo | Qué es | Exporta | Aviso |
|---|---|---|---|
| `fparms.blend` | brazos del jugador: rig, clips de cada arma, vista previa de las armas y anclas `<Prefijo>Mount` | `tools/rebuild_arms.py` → `assets/models/fps_arms.glb` | `build/avisos/arms_done` |
| `soldier.blend` | enemigo: malla, rig con IK, clips y reacciones a impactos | `tools/export_soldier.py` → `enemy.glb` | `build/avisos/soldier_done` |
| `mapas/*.py`, `patio.blend`, `callejones.blend`, `biblioteca_mapas.glb` | mapas de combate: `piezas.py` (geometría de la librería: cada pieza es un objeto con nombre en `Static`, colisionadores `<superficie>_<pieza>-convcolonly`, props y puestos), `materiales.py` (materiales, fusión por material y exportación a GLB), `patio.py` y `callejones.py` construyen el `.blend` y el `.glb`, `exportar.py` exporta el `.blend` que hayas editado | `assets/models/patio.glb`, `callejones.glb` | sin aviso (`MAPA_SALIDA` cambia la ruta del GLB) |
| `<arma>.blend` (`ar15.blend`, `shotgun.blend`) | arma por piezas, origen en la empuñadura, cañón hacia +Y | `tools/export_weapon.py` con `init_globals={"NAME": "ar15"}` → `<arma>.glb` | `build/avisos/weapon_done` |
| `desert_eagle.py` | arma descargada (Sketchfab `cabde59f5cf24effaf80536e35d04e95`, autor ELIZION, CC-BY) pasada al contrato del juego: piezas `Frame`/`Slide`/`Trigger`/`Magazine`, escala 273 mm, origen en el asa de la Glock, texturas a 512 | deja `blender/desert_eagle.blend`; el GLB lo saca `tools/export_weapon.py` con `NAME=desert_eagle` | — |
| `barrett.py` | lo mismo con el M82A1 (Sketchfab `499195fd926c4016ae5aead4b9e33fb2`, autor Gintoki1234, CC-BY), decimado | deja `blender/barrett.blend` | — |

`assets/models/*.glb` nunca se editan a mano (salvo `g19_pistol.glb`, sin `.blend`).
Tras exportar: `godot --headless --path . --import`.

Para juzgar sin abrir Godot: `tools/blender_view.py` (vista de juego con la lente,
ver `tools/AGENTS.md`) y `tools/blender_mesh.py` (estiramientos de malla). Las claves
se ponen a mano, pose a pose; nunca curvas generadas por fórmula. Reproyectar
animación importada sí es válido, pero cada arma anima sus propios clips.

## Trampas

- Reasignar o borrar una acción que está en uso tumba Blender: guarda antes.
- La primera actualización tras asignar una acción a un rig reevalúa la animación y
  pisa la pose que acabas de poner: actualiza antes de posar.
- Una pose base de una acción que no clava un hueso conserva el valor anterior: pon
  el hueso en reposo antes de leerla.
- Un hueso clavado a 0 no mueve su pieza: clava la pose de cada extremo.
- Los dedos no pueden quedarse en reposo: sin claves en el vaivén, el arma se mueve y
  los dedos quedan clavados. Las claves de influencia de los constraints van en cada
  acción.
- En Blender 4.5 (Windows), un material nuevo no trae un nodo `Principled BSDF`:
  búscalo por `type` (`BSDF_PRINCIPLED`), nunca por nombre.
- En Blender 4.0 `image.pack()` falla si la textura original ya no existe: guarda la
  imagen en disco y luego empaqueta.
- No uses `wm.read_factory_settings` (tumba la sesión con interfaz) ni dejes cambiada
  la escena de la ventana.
- Los `Transform3D` de un `.tscn` van por filas: comprueba la dirección de una luz
  con `str_to_var` antes de hornear (el sol llegó a alumbrar desde abajo).
- El Blender del sistema (Python 3.12) se cae con Mantaflow; se usa el oficial 4.0.2
  en `~/.local/opt/blender-4.0.2-linux-x64` (servidor MCP en el 9876).
- Un `export_weapon.py` arranca su exportación con un temporizador que `blender -b`
  no ejecuta: en fondo se llama a `export()` directamente.
- Importar un OBJ deja una rotación +90°X sin aplicar: aplícala antes de medir.
  El cañón va a +Y en todas las armas; un giro sin aplicar lo deja a -Y.
- Las armas salen con bisel de 0,7 mm y aristas a 35° suavizadas: sin suavizado se
  leen en facetas.
- Un mapa sin lightmaps horneados queda a oscuras: `CombatMap` oculta el `Sun`. El GLB
  va con `meshes/light_baking=2` o el horneado no escribe nada. Se hornea con
  `godot -e --path . -- --bake-lightmaps res://scenes/<Mapa>.tscn`; tarda 77–101 s en
  una pantalla con GPU real (con Xvfb, unos 20 min).
- `LightmapGI.environment_custom_energy` no cambió el horneado de estos mapas; el sol
  sí: 1,0 dejaba sombras negras y 3,5 da luz de patio.
- El horneado puede caer con segfault: se repite, sale el mismo resultado.
- Un GLB de mapa sin `import_script/path="res://tools/factory_import.gd"` en su
  `.import` deja sus colisionadores sin superficie: la bala avisa y no penetra nada.
- Una caja de colisión de un modelo abierto (estantería, valla, farola) ocupa todo su
  volumen y la bala se para en el aire: lo abierto lleva malla cóncava (`-colonly`),
  y lo que es malla va como `steel`, no penetrable.
- Una caja que envuelve piezas visibles separadas deja aire entre ellas: un
  colisionador por pieza visible.
- Una ventana es un hueco real: la pared `Static` va partida en tramos con su
  colisionador `-convcolonly`, y el hueco lleva su cristal (`glass`, penetrable,
  `thin_shell`). Sin cristal, el interior se ve negro desde fuera.
- El tinte de un material con nodo Multiply no sale como `baseColorFactor` en el
  GLB: un color de muro se da de otra forma, no recodificando texturas.
- Un `.blend` que importa glTF de Poly Haven guarda sus texturas empaquetadas
  (llegó a 110 MB). Antes de guardar se sacan a `assets/models/<mapa>_*.jpg` (ignorado
  por git) y se desempaquetan.
- Un `.blend` va comprimido con zstd (`28 b5 2f fd`): no se lee a texto. Antes de
  borrar o mover una textura, descomprímelo (`zstandard` en Python) y mira qué imágenes
  referencia.
- Un `home_*` dentro de un edificio con techo encierra al equipo en una sala a
  oscuras: los `home_0`/`home_1` van en descampado y el mapa los comprueba con
  `comprobar_base`.
- Los modelos descargados llegan con 5 000 a 33 000 caras: se decimen a unas 2 400
  antes de repetirlos. Una caja de un modelo entra en una pieza o en piezas con
  nombres de otra herramienta: el script las reagrupa en los vacíos que pide
  `WeaponModel._mount`.
- Una textura de 1024 en un arma descargada pesa 11,5 MB de GLB; a 512 pesa 3,5 MB,
  como el AR15.
- Un modelo descargado ya puede venir en el eje bueno: girarlo a ojo lo rompe. Mide
  el largo real y gíralo con una cuenta.

## Deuda

Mapas de combate (Patio, Callejones): la fuente es el `.blend`
(`blender/patio.blend`, `blender/callejones.blend`). Cada pieza es un objeto con
nombre en `Static`, los colisionadores y los props van en `Colliders` y `Props`, y
los puestos en `Markers`. Para editar: abre el `.blend` en Blender, cambia lo que
haga falta y exporta con `"<Blender>/blender.exe" -b blender/patio.blend -P
blender/mapas/exportar.py`; genera `assets/models/patio.glb` fusionando las piezas de
`Static` por material. Luego `godot --headless --path . --import` y el horneado.
Para regenerar todo desde cero: `blender -b --factory-startup -P blender/mapas/patio.py`
(crea el `.blend` y el `.glb`; ojo, eso pisa las ediciones a mano del `.blend`).

- Tras un bisel, los índices de bmesh (`bm.verts[n:]`) apuntan a otra geometría: las
  piezas nuevas se identifican por pertenencia (`_nuevos`).
- `transform_apply` sobre props compartidos falla («multi user»): antes
  `make_single_user(obdata=True)`.
- Texturas de los mapas a 1024 y props a 512, GLB en JPEG 80: ~7 MB por mapa.
- El editor de Godot abierto importa un GLB nuevo en cuanto aparece; si se reescribe
  mientras importa, la escritura falla: exportar a temporal y mover.
- El relleno exterior es una `DirectionalLight3D` estática sin sombras (`SkyFill`):
  solo existe al hornear, no cuesta en partida.
- Un colisionador sin prefijo de superficie conocido avisa al importar.
- El `.exr` de `scenes/<Mapa>.exr` no es material de sobra: es la textura que
  referencia el `.lmbake`. Borrarlo deja el mapa sin luz horneada.
- La librería `assets/models/mapa_*.jpg` es solo de `piezas.py`; las texturas
  jugables van dentro de cada `.glb`, y el paquete la excluye con `exclude_filter`.
- Pendiente: `desert_eagle.py` y `barrett.py` leen su GLB de origen de
  `build/modelos/` (`de_gris13k.glb` y `m82_a1_218k.glb`), que ya no están: esos
  dos modelos solo se rehacen si se vuelven a bajar de Sketchfab (IDs arriba).
- Pendiente: mover esa librería a `blender/` (fuera de `res://`) y reapuntar
  `piezas.py`, `materiales.py` y las imágenes de los `.blend`, para que Godot no la
  importe ni la tenga que apretar. Hay que probar un GLB de prueba antes de pisar el
  de la partida.
- Pendiente: Patio y Callejones se juegan por primera vez: revisar alturas, líneas de
  tiro y la reaparición en los puestos `post_*`.
- Pendiente: Callejones tiene la plaza y las calles anchas en el centro-este: falta
  densidad de tapias y casas.
- Blender MCP: la extensión tiene que estar iniciada en `localhost:9876`; si no, las
  herramientas `mcp__Blender__*` fallan con «Cannot connect».
