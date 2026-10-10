# Blender

Blender es la autoridad de modelos, mapa, rig y animación; Godot solo los usa.
Todo se edita por el Blender MCP (`execute_blender_code`) y se exporta desde él
con `runpy.run_path(<script>, run_name="__main__")`. Los exportadores no
imprimen nada y avisan con un archivo en `build/avisos/` (misma ruta para Python,
Blender y Bash, porque está dentro del repo).

| Archivo | Qué es | Exporta | Aviso |
|---|---|---|---|
| `fparms.blend` | brazos del jugador: rig, clips de cada arma, vista previa de las armas y anclas `<Prefijo>Mount` | `tools/rebuild_arms.py` → `assets/models/fps_arms.glb` | `build/avisos/arms_done` |
| `soldier.blend` | enemigo: malla, rig con IK, clips y reacciones a impactos | `tools/export_soldier.py` → `enemy.glb` | `build/avisos/soldier_done` |
| `mapas/*.py`, `patio.blend`, `callejones.blend`, `biblioteca_mapas.glb` | mapas de combate: `piezas.py` (geometría de la librería: cada pieza es un objeto con nombre en la colección `Static`, colisionadores `<superficie>_<pieza>-convcolonly`, props y puestos), `materiales.py` (materiales, fusión por material y exportación a GLB), `patio.py` y `callejones.py` construyen el `.blend` y el `.glb`, `exportar.py` exporta el `.blend` que hayas editado | `assets/models/patio.glb`, `callejones.glb` | sin aviso (`MAPA_SALIDA` cambia la ruta del GLB) |
| `<arma>.blend` (`ar15.blend`) | arma por piezas, origen en la empuñadura, cañón hacia +Y | `tools/export_weapon.py` con `init_globals={"NAME": "ar15"}` → `<arma>.glb` | `build/avisos/weapon_done` |

`assets/models/*.glb` nunca se editan a mano (salvo `g19_pistol.glb`, sin
`.blend`). Tras exportar: `godot --headless --path . --import`.

Para juzgar sin abrir Godot: `tools/blender_view.py` (vista de juego con la
lente, ver `tools/AGENTS.md`) y `tools/blender_mesh.py` (estiramientos de malla).
Las claves se ponen a mano, pose a pose; nunca curvas generadas por fórmula.
Reproyectar animación importada sí es válido, pero una coreografía de pistola
reproyectada sobre un rifle no convence: cada arma anima sus propios clips.

## Trampas medidas

- Reasignar o borrar una acción que está en uso tumba Blender: guarda antes.
- Al asignar una acción a un rig, la primera actualización reevalúa la
  animación y pisa la pose que acabas de poner: actualiza antes de posar.
- Una pose base de una acción que no clavea un hueso conserva el valor
  anterior: pon el hueso en reposo antes de leerla.
- En Blender 4.0 `image.pack()` falla si la textura original ya no existe:
  guarda la imagen en disco y luego empaqueta.
- En Blender 4.5 (Windows) un material nuevo no trae un nodo llamado
  `Principled BSDF`: búscalo por `type` (`BSDF_PRINCIPLED`), nunca por nombre.
- No uses `wm.read_factory_settings` (tumba la sesión con interfaz) ni dejes
  cambiada la escena de la ventana.
- Los `Transform3D` de un `.tscn` van por filas: comprueba la dirección de una
  luz con `str_to_var` antes de hornear (el sol llegó a alumbrar desde abajo).
- Blender del sistema (Python 3.12) se cae con Mantaflow; se usa el oficial
  4.0.2 en `~/.local/opt/blender-4.0.2-linux-x64` (servidor MCP en el 9876).
- `RifleInspect` traía la mano a la palanca en 80-94 pero el hueso `Slide` clavado a 0: se le ponen 45 mm a mano ; medido, la corredera tarda 3,29 s en ir atrás y 3,92 s en volver.
- `shotgun.blend` se armó por script CLI (no MCP) y salió de pie: el cañón iba
  a -Z de Blender (= -Y de Godot), no a +Y como las demás armas. El importador
  OBJ deja una rotación +90°X sin aplicar y la malla quedó sin ese giro.
  Corregido girando toda la malla +90° en X y desplazándola (0; 0,045; 0,01)
  en Blender; los sockets de `ShotgunWeapon` son esas coordenadas.
- La escopeta estrenó clips `Shotgun*` (mano a la bomba y cartuchos por la
  recarga) y perdió el aro del alza `SightRear`, rechazado por el propietario:
  en `fparms.blend` su vista previa es `Shotgun_*` (`hide_render`) y su ancla,
  `ShotgunMount`, calcada de la del rifle.
- Los dedos no van fijos en reposo ni al disparar: `RifleIdle`/`ShotgunIdle`
  llevan claves en 25 y 75, y `RifleFire`/`ShotgunFire` en 3 y 5/7 (pulgar
  derecho), para acompañar el vaivén y el retroceso; sin ellas el arma se movía
  y los dedos se quedaban clavados.
- Un GLB de mapa sin `import_script/path="res://tools/factory_import.gd"` en su `.import` deja sus colisionadores sin superficie: la bala avisa «sin perfil de superficie» y no penetra nada.
- Una ventana es un hueco real: la pared `Static` va partida en tramos con su colisionador `-convcolonly` alrededor, y el hueco lleva su cristal (`caja` `cristal` + colisionador `glass`, penetrable, `thin_shell`). Sin cristal, el interior a oscuras se ve negro por el hueco desde fuera; con el panel solo (sin colisionador) se atraviesa andando.
- Las armas salen con bisel de 0,7 mm y aristas a 35° suavizadas: sin suavizado la escopeta se leía en facetas. `export_weapon.py` arranca su exportación con un temporizador que `blender -b` no ejecuta: en fondo se llama a `export()` directamente.
- Un mapa sin lightmaps horneados queda a oscuras: `CombatMap` oculta el `Sun`. El GLB va con `meshes/light_baking=2` (lightmaps estáticos) o el horneado no escribe nada; se hornea con `godot -e --path . -- --bake-lightmaps res://scenes/<Mapa>.tscn`.
- Un `.blend` que importa glTF de Poly Haven guarda sus texturas empaquetadas: un `.blend` con glTF de Poly Haven llegó a 110 MB. Antes de guardar se sacan a `assets/models/<mapa>_*.jpg` (ignorado por git) y se desempaquetan: el `.blend` vuelve a 4-5 MB.
- Un `.blend` va comprimido con zstd (`28 b5 2f fd`): no se lee a texto. Antes de borrar o mover una textura, descomprimirlo (`zstandard` en Python) y mirar qué imágenes referencia; `callejones.blend` referenciaba las cuatro que eran copia exacta de otras.
- Un `home_*` dentro de un edificio con techo encierra al equipo en una sala a oscuras al empezar (`opening_point` reparte cuatro puestos a ±1,3 m): los cuatro caían dentro de las oficinas, la nave y las casas. Los `home_0`/`home_1` van en descampado y el mapa los comprueba con `comprobar_base`.
- Los modelos de Poly Haven llegan con 5 000 a 33 000 caras (el barril es un grupo de 4,4 m): se decimen a unas 2 400 antes de repetirlos.

- Hornear un mapa tarda 77–101 s en la pantalla real (`DISPLAY=:0`, GPU); bajo Xvfb (software) tardaba unos 20 min. Las capturas de comprobación también van en `DISPLAY=:0`.
- Una caja de colisión de un modelo abierto (estantería, valla, carretilla, farola) ocupa todo su volumen: la bala se para en el aire. Lo abierto lleva malla cóncava (`-colonly`); `ShapeExit` no sabe salir de mallas cóncavas, así que lo que es malla va como `steel`, no penetrable.
- Una caja de colisión que envuelve piezas visibles separadas deja aire entre ellas: las palets de Patio (tablón y cartón) se paraban en el vacío a 0,6 m. Un colisionador por pieza visible.
- El tinte de un material con nodo Multiply no sale como `baseColorFactor` en el GLB: un color de muro hay que darlo de otra forma (no recodificando texturas).

## Deuda

Mapas de combate (Patio, Callejones): la fuente es el `.blend` (`blender/patio.blend`, `blender/callejones.blend`). Cada pieza es un objeto con nombre en `Static`, los colisionadores y los props van en `Colliders` y `Props`, y los puestos en `Markers`. Para editar: abre el `.blend` en Blender, cambia lo que haga falta y exporta con `"<Blender>/blender.exe" -b blender/patio.blend -P blender/mapas/exportar.py`; genera `assets/models/patio.glb` fusionando las piezas de `Static` por material. Luego `godot --headless --path . --import` y el horneado `godot -e --path . -- --bake-lightmaps res://scenes/Patio.tscn`. Para regenerar todo desde cero corre `blender -b --factory-startup -P blender/mapas/patio.py` (crea el `.blend` y el `.glb`).

- Tras un bisel, los índices de bmesh (`bm.verts[n:]`) apuntan a otra geometría: las piezas nuevas se identifican por pertenencia (`_nuevos`). Con el corte por índice, la caja biselada siguiente llevaba vértices a 300 m.
- `transform_apply` sobre props compartidos falla («multi user»): antes `make_single_user(obdata=True)`.
- Texturas de los mapas a 1024 y props a 512, GLB en JPEG 80: ~7 MB por mapa. Con PNG sueltos y props a 2k pasaba de 30 MB.
- El editor de Godot abierto importa un GLB nuevo en cuanto aparece; si se reescribe mientras importa, la escritura falla: exportar a temporal y mover.
- `LightmapGI.environment_custom_energy` no cambió el horneado de estos mapas (0,2, 0,7 y 1,4 dieron el mismo lightmap). El relleno exterior es una `DirectionalLight3D` estática sin sombras (`SkyFill`): solo existe al hornear, no cuesta en partida.
- Sol del horneado: 1,0 dejaba las sombras negras; 3,5 da luz de patio.
- El horneado puede caer con segfault (pasó una vez): se repite, sale el mismo resultado.
- Un colisionador sin prefijo de superficie conocido (`concrete`, `steel`, `pine`, `barrel`, `rack`, `paper`) avisa al importar.
- El `.exr` de `scenes/<Mapa>.exr` no es material de sobra: es la textura que referencia el `.lmbake` (`LightmapGIData`). Borrarlo deja el mapa sin luz horneada.
- La librería `assets/models/mapa_*.jpg` es solo de `piezas.py`; las texturas jugables van dentro de cada `.glb`, así que se excluye del paquete con `exclude_filter`.
- Pendiente: mover esa librería a `blender/` (fuera de `res://`) y reapuntar `piezas.py` y los `.blend`, para que Godot no la importe ni la tenga que apretar.

## Deuda (mapas nuevos)

- Pendiente: Patio y Callejones se juegan por primera vez: revisar alturas, líneas de tiro y la reaparición en los puestos `post_*`.
- Blender MCP: la extensión tiene que estar iniciada en `localhost:9876`; si no, las herramientas `mcp__Blender__*` fallan con «Cannot connect».
- Pendiente: Callejones tiene la plaza y las calles anchas en el centro-este: falta densidad de tapias y casas.
