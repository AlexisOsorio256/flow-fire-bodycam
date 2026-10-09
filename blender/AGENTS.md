# Blender

Blender es la autoridad de modelos, mapa, rig y animación; Godot solo los usa.
Todo se edita por el Blender MCP (`execute_blender_code`) y se exporta desde él
con `runpy.run_path(<script>, run_name="__main__")`. Los exportadores no
imprimen nada y avisan con un archivo en `/tmp`.

| Archivo | Qué es | Exporta | Aviso |
|---|---|---|---|
| `fparms.blend` | brazos del jugador: rig, clips de cada arma, vista previa de las armas y anclas `<Prefijo>Mount` | `tools/rebuild_arms.py` → `assets/models/fps_arms.glb` | `/tmp/flowfire_arms_done` |
| `soldier.blend` | enemigo: malla, rig con IK, clips y reacciones a impactos | `tools/export_soldier.py` → `enemy.glb` | `/tmp/flowfire_soldier_done` |
| `factory.blend` | el mapa | `tools/export_map.py` → `factory.glb` | `/tmp/flowfire_map_done` |
| `mapas/*.py`, `biblioteca_mapas.glb` | mapas de combate Patio y Callejones: `piezas.py` (librería: cajas, muros con huecos, techos, colisionadores, props, puestos), `patio.py` y `callejones.py` (cada uno lleva su lista de piezas en metros de Godot) → `assets/models/patio.glb`, `callejones.glb`; `biblioteca_mapas.glb` es la fuente de los props (10 objetos: barriles, barrera, neumático, farola, pila de fuego, hidrante, estantería, generador, compresor y coche; texturas a 512 px) | sin aviso (`MAPA_SALIDA` cambia la ruta) |
| `<arma>.blend` (`ar15.blend`) | arma por piezas, origen en la empuñadura, cañón hacia +Y | `tools/export_weapon.py` con `init_globals={"NAME": "ar15"}` → `<arma>.glb` | `/tmp/flowfire_weapon_done` |

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
- No uses `wm.read_factory_settings` (tumba la sesión con interfaz) ni dejes
  cambiada la escena de la ventana.
- Los `Transform3D` de un `.tscn` van por filas: comprueba la dirección de una
  luz con `str_to_var` antes de hornear (el sol llegó a alumbrar desde abajo).
- Blender del sistema (Python 3.12) se cae con Mantaflow; se usa el oficial
  4.0.2 en `~/.local/opt/blender-4.0.2-linux-x64` (servidor MCP en el 9876).
- `RifleInspect` traía la mano a la palanca en 80-94 pero el hueso `Slide` clavado a 0: se le ponen 45 mm a mano y `timing_errors` ya da `slide_back` 3,29 s y `slide_home` 3,92 s.
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
- Una ventana es un hueco real: booleano sobre la pared `Static` y su colisionador `-convcolonly` partido en cajas alrededor del hueco (`<superficie>_<pared>_<k>-convcolonly`). Un panel encima no abre nada: sin colisionador la pared sigue entera.
- Las armas salen con bisel de 0,7 mm y aristas a 35° suavizadas: sin suavizado la escopeta se leía en facetas. `export_weapon.py` arranca su exportación con un temporizador que `blender -b` no ejecuta: en fondo se llama a `export()` directamente.
- Un mapa sin lightmaps horneados queda a oscuras: `CombatMap` oculta el `Sun`. El GLB va con `meshes/light_baking=2` (lightmaps estáticos) o el horneado no escribe nada; se hornea con `godot -e --path . -- --bake-lightmaps res://scenes/<Mapa>.tscn`.
- Un `.blend` que importa glTF de Poly Haven guarda sus texturas empaquetadas: un `.blend` con glTF de Poly Haven llegó a 110 MB. Antes de guardar se sacan a `assets/models/<mapa>_*.jpg` (ignorado por git) y se desempaquetan: el `.blend` vuelve a 4-5 MB.
- `tools/export_map.py` no exporta con `blender -b` (no hay ventana para su `window.scene`): se llama a `_merged` del script y se exporta con `use_selection`.
- Los modelos de Poly Haven llegan con 5 000 a 33 000 caras (el barril es un grupo de 4,4 m): se decimen a unas 2 400 antes de repetirlos.

- Hornear un mapa tarda 77–101 s en la pantalla real (`DISPLAY=:0`, GPU); bajo Xvfb (software) tardaba unos 20 min. Las capturas de comprobación también van en `DISPLAY=:0`.
- Una caja de colisión de un modelo abierto (estantería, valla, carretilla, farola) ocupa todo su volumen: la bala se para en el aire. Lo abierto lleva malla cóncava (`-colonly`); `ShapeExit` no sabe salir de mallas cóncavas, así que lo que es malla va como `steel`, no penetrable.
- El tinte de un material con nodo Multiply no sale como `baseColorFactor` en el GLB: un color de muro hay que darlo de otra forma (no recodificando texturas).

## Deuda

Mapas de combate (Patio, Callejones): se corren con Blender 4.5 sin ventana: `"<Blender>/blender.exe" -b --factory-startup -P blender/mapas/patio.py`. Luego `godot --headless --path . --import` y el horneado `godot -e --path . -- --bake-lightmaps res://scenes/Patio.tscn`.

- Tras un bisel, los índices de bmesh (`bm.verts[n:]`) apuntan a otra geometría: las piezas nuevas se identifican por pertenencia (`_nuevos`). Con el corte por índice, la caja biselada siguiente llevaba vértices a 300 m.
- `transform_apply` sobre props compartidos falla («multi user»): antes `make_single_user(obdata=True)`.
- `export_map.py` no exporta en `blender -b`: los mapas nuevos exportan con `export_scene.gltf` y `use_selection`.
- Texturas de los mapas a 1024 y props a 512, GLB en JPEG 80: ~7 MB por mapa. Con PNG sueltos y props a 2k pasaba de 30 MB.
- El editor de Godot abierto importa un GLB nuevo en cuanto aparece; si se reescribe mientras importa, la escritura falla: exportar a temporal y mover.
- `LightmapGI.environment_custom_energy` no cambió el horneado de estos mapas (0,2, 0,7 y 1,4 dieron el mismo lightmap). El relleno exterior es una `DirectionalLight3D` estática sin sombras (`SkyFill`): solo existe al hornear, no cuesta en partida.
- Sol del horneado: 1,0 dejaba las sombras negras; 3,5 da luz de patio.
- El horneado puede caer con segfault (pasó una vez): se repite, sale el mismo resultado.
- Un colisionador sin prefijo de superficie conocido (`concrete`, `steel`, `pine`, `barrel`, `rack`, `paper`) avisa al importar.

## Deuda (mapas nuevos)

- Pendiente: Patio y Callejones se juegan por primera vez: revisar alturas, líneas de tiro y la reaparición en los puestos `post_*`.
- Pendiente: Callejones tiene la plaza y las calles anchas en el centro-este: falta densidad de tapias y casas.
