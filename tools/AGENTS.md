# Herramientas

Lo que produce el juego: modelos, texturas, audio y paquetes. Cada herramienta
entra si ahorra más tiempo del que cuesta. Si añades una, escribe su línea aquí.

## Comprobar y empaquetar

- `python tools/check.py`: la definición de terminado. Arquitectura (unas
  decenas de milisegundos) y sintaxis de todos los scripts en un arranque
  headless de Godot (1 o 2 segundos). Usa el Godot de la variable `GODOT`, o el
  del PATH.
  - `--arquitectura`: solo la primera parte.
  - `--informe`: dominios con líneas, scripts y pendientes, y los ficheros
    trackeados más pesados.
- `python tools/package.py [windows|linux|android]`: exporta a `build/dist/` un
  `.zip`, un `.tar.gz` o un `.apk`, con la versión de `project.godot`. Si el
  export falla, para con error y no deja restos en `build/`. Los presets excluyen
  `tools`, `blender`, `captures`, `build`, `addons` y la librería `mapa_*`.
- Windows: `check.py` y `package.py windows` son el mismo trabajo. Hace falta
  Godot en el PATH (o `GODOT=` con su ruta) y Python 3.
- Android: las claves de firma del Play Store viven fuera del repo, en
  `%USERPROFILE%\.local\share\blockfire-tools\`. No van en git.
- Linux o macOS: el comando es `python3`.
- La grabación de pantalla no va: `--write-movie` necesita un escritorio gráfico.
  Las capturas se miran.

## Imágenes del juego y de Blender

- `tools/shot.tscn`: capturas del juego desde cámaras dadas, a `captures/`:
  `godot --path . --resolution 960x540 --scene res://tools/shot.tscn -- <nombre> res://scenes/Patio.tscn "x,y,z/mirada" ...`.
  Las coordenadas son de Godot: Blender (x, y, z) es Godot (x, z, -y).
- `tools/shot_arma.gd`: el arma en la mano, disparando o recargando, con
  fotogramas en los tiempos dados:
  `godot --path . --resolution 960x540 -s res://tools/shot_arma.gd -- --map=0 --weapon=1 --settle=2.6 --pitch=0 --yaw=0 --fire --times=0.03,0.08 --out=nombre`.
  `--map` 0 Patio, 1 Callejones; `--weapon` 0 pistola, 1 fusil, 2 escopeta;
  `--settle` da tiempo a desenfundar (2,6 s el fusil, 3,2 s la escopeta). `--reload`
  con `--rounds`, `--mag` y `--chamber` arranca una recarga. Fija `--pitch` y
  `--yaw`, o la vista cambia de una ejecución a otra. `--gente` arranca la partida
  con bots.
- Blender, `v = runpy.run_path("tools/blender_view.py")`:
  `v["game"](clip, [t..], nombre, show="all"|"arms"|"weapon", color="MATERIAL"|"VERTEX")`
  renderiza la vista del juego, con el FOV y la lente de `BodyCam.gd` y `HUD.gd`,
  en los instantes dados (segundos). También `closeup()`, `shift_keys()`,
  `turn_keys()` y `plan()`. Clips: `Idle`, `Aim`, `Fire`, `Reload`, `ReloadEmpty`,
  `Inspect`, `Equip`.
- Blender, `m = runpy.run_path("tools/blender_mesh.py")`: `islands()`,
  `stretch(clips=[..])` y `paint(marked=[..])`, para ver estiramientos de malla con
  `game(..., color="VERTEX")`. `paint([])` las borra antes de exportar.
- `tools/factory_import.gd`: lo que Godot aplica al importar un mapa (superficie de
  cada colisionador, occluders y sombras de las lámparas). Un cuerpo sin prefijo
  conocido avisa con `push_error`.
- `tools/syntax.gd`: lo usa `check.py` para cargar todos los scripts.

## Blender → Godot

- `tools/anim_pose.py`: claves a mano por script. `bend`, `nudge` y `fingers`
  posan huesos y dedos; `travel` devuelve el recorrido para medirlo.
- `tools/rebuild_arms.py`, `tools/export_weapon.py` y `tools/export_soldier.py`:
  exportan los brazos, cada arma y el soldado. Al terminar escriben un aviso en
  `build/avisos/`. Su uso está en `blender/AGENTS.md`.
- `tools/build_icon.py`: el icono (`assets/icon.png`). Aviso en
  `build/avisos/icon_done`.
- `tools/build_flash.py` y `tools/build_smoke.py`: fogonazos y humo
  (`assets/textures/muzzle_flash.png` y `muzzle_puff.png`). Aceptan `--out`; sin
  él, los intermedios van a `build/`.

## Audio y texturas

- `python tools/build_audio.py`: voces sintetizadas con Piper (voz local, CC BY
  4.0): radio de aliados, gritos de enemigos y `hit_thump.wav`. Las frases están
  en el script, y `scripts/audio/Voices.gd` decide quién habla. Piper vive en
  `~/.local/opt/piper` (Linux).
- `python tools/import_sounds.py [nombre..]`: los sonidos grabados (Freesound CC0
  y OpenGameArt). Cada sonido es una línea de su tabla: archivo, fuente y corte.
- `python tools/cap_textures.py [1024]`: techo de las fotos de los mapas
  (`mapa_*`): 1024 de lado, compresión y mipmaps. Las armas, los brazos y el
  soldado no se tocan.

## Trampas medidas

- `gltf/embedded_image_handling=0` en un `.glb.import` descarta todas sus texturas
  al importar. Un mapa salió blanco y el check estaba verde.
- `export_filter=all_resources` mete en el paquete todo lo importado; lo que el
  juego no carga va en `exclude_filter`.
- Tras exportar un `.glb` o añadir un `class_name`, `godot --headless --path .
  --import` antes de jugar, o Godot usa lo viejo.
- La versión vive en `config/version` de `project.godot`. `export_presets.cfg` la
  repite a mano, y `check.py` exige que coincida.
- Godot se cuelga 1 de cada 40 arranques al salir, más o menos.
- Si Godot da «Failed loading resource» de un `.glb` por una PNG que ya no existe,
  la caché `.godot/imported/<glb>-*` apunta a ella: hay que borrar esa caché y
  reimportar.
- En Android el modo de ratón capturado no se mantiene: la pausa es
  `Player.paused`.
- Dos instancias del juego en un PC sirven para probar la red.
