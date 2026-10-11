# Herramientas

Lo que produce el juego: modelos, texturas, audio y paquetes. Cada herramienta entra
si ahorra más tiempo del que cuesta. Si añades una, escribe su línea aquí.

## Comprobar y empaquetar

- `python tools/check.py`: la definición de terminado. Arquitectura (unas decenas de
  milisegundos) y sintaxis de todos los scripts en un arranque headless de Godot
  (1 o 2 segundos). Usa el Godot de la variable `GODOT`, o el del PATH.
  - `--arquitectura`: solo la primera parte.
  - `--informe`: dominios con líneas, scripts y pendientes, y los ficheros
    trackeados más pesados.
- `python tools/package.py [windows|linux|android]`: exporta a `build/dist/` un
  `.zip`, un `.tar.gz` o un `.apk`, con la versión de `project.godot`. Si el export
  falla, para con error y no deja restos en `build/`. Los presets excluyen `tools`,
  `blender`, `captures`, `build`, `addons` y la librería `mapa_*`.
- Windows: `check.py` y `package.py windows` son el mismo trabajo. Hace falta Godot
  en el PATH (o `GODOT=` con su ruta) y Python 3.
- Android: las claves de firma del Play Store viven fuera del repo, en
  `%USERPROFILE%\.local\share\blockfire-tools\`. No van en git.
- Linux o macOS: el comando es `python3`.
- La grabación de pantalla no va: `--write-movie` necesita un escritorio gráfico. Las
  capturas se miran.

## Medir

- `tools/medir.gd`: mide fps y tiempo de GPU de una partida andando, con el nivel
  y los ajustes que pidas. Ejemplo:
  `godot --path . -s res://tools/medir.gd -- --mode=combat --tier=2 --map=0 --seconds=10`.
  Argumentos: `tier` (0 Muy alta, 1 Alta, 2 Media, 3 Baja), `map` (0 Patio,
  1 Callejones), `warm` (3 s antes de medir) y `seconds` (10 s medidos). Para probar
  un ajuste suelto: `ssao`, `glow`, `fog`, `post`, `msaa`, `aa`, `bias`, `scale`,
  `lod`, `aniso`. Imprime una línea con fps, `gpu_medio`, `cpu_medio` y `peor` (el
  cuadro más lento), `llamadas` (llamadas de dibujo por cuadro), `tex_mb` y `buf_mb`
  (memoria de texturas y de búferes, en MB). `--mode=combat` es obligatorio: sin él,
  Main carga tus ajustes guardados y se queda en el lobby. Corre con ventana y GPU,
  como las capturas.

## Carpeta build/

`build/` es solo salida regenerable: `build/linux` y `build/dist` (los escribe
`package.py`) y `build/avisos/` (los exportadores). Las descargas no van ahí: los
modelos fuente de Sketchfab y los sonidos de Freesound viven en `~/.cache/flowfire/`,
fuera del repo. Un prototipo se borra al terminar; si merece quedarse, va a `tools/`
con su línea en este fichero.

## Imágenes del juego y de Blender

- `tools/shot.tscn`: capturas del juego desde cámaras dadas, a `captures/`:
  `godot --path . --resolution 960x540 --scene res://tools/shot.tscn -- <nombre> res://scenes/Patio.tscn "x,y,z/mirada" ...`.
  Las coordenadas son de Godot: Blender (x, y, z) es Godot (x, z, -y).
- `tools/shot_arma.gd`: el arma en la mano, disparando o recargando, con fotogramas
  en los tiempos dados:
  `godot --path . --resolution 960x540 -s res://tools/shot_arma.gd -- --map=0 --weapon=1 --settle=2.6 --pitch=0 --yaw=0 --fire --times=0.03,0.08 --out=nombre`.
  `--map` 0 Patio, 1 Callejones; `--weapon` 0 pistola, 1 fusil, 2 escopeta;
  `--settle` da tiempo a desenfundar (2,6 s el fusil, 3,2 s la escopeta). `--reload`
  con `--rounds`, `--mag` y `--chamber` arranca una recarga. Fija `--pitch` y
  `--yaw`, o la vista cambia de una ejecución a otra. `--gente` arranca la partida
  con bots. `--calidad` (0 Muy alta, 1 Alta, 2 Media, 3 Baja) elige el nivel.
- Blender, `v = runpy.run_path("tools/blender_view.py")`:
  `v["game"](clip, [t..], nombre, show="all"|"arms"|"weapon", color="MATERIAL"|"VERTEX")`
  renderiza la vista del juego, con el FOV y la lente de `BodyCam.gd` y `HUD.gd`, en
  los instantes dados (segundos). También `closeup()`, `shift_keys()`, `turn_keys()` y
  `plan()`. Clips: `Idle`, `Aim`, `Fire`, `Reload`, `ReloadEmpty`, `Inspect`, `Equip`.
- Blender, `m = runpy.run_path("tools/blender_mesh.py")`: `islands()`,
  `stretch(clips=[..])` y `paint(marked=[..])`, para ver estiramientos de malla con
  `game(..., color="VERTEX")`. `paint([])` las borra antes de exportar.
- `tools/factory_import.gd`: lo que Godot aplica al importar un mapa (superficie de
  cada colisionador, occluders y sombras de las lámparas).
- `tools/syntax.gd`: lo usa `check.py` para cargar todos los scripts.

## Blender → Godot

- `tools/anim_pose.py`: claves a mano por script. `bend`, `nudge` y `fingers` posan
  huesos y dedos; `travel` devuelve el recorrido para medirlo.
- `tools/rebuild_arms.py`, `tools/export_weapon.py` y `tools/export_soldier.py`
  exportan los brazos, cada arma y el soldado. Al terminar escriben un aviso en
  `build/avisos/`. Su uso está en `blender/AGENTS.md`.
- `tools/build_icon.py`: el icono (`assets/icon.png`). Aviso en
  `build/avisos/icon_done`.
- `tools/build_flash.py` y `tools/build_smoke.py`: fogonazos y humo
  (`assets/textures/muzzle_flash.png` y `muzzle_puff.png`). Aceptan `--out`; sin él,
  los intermedios van a `build/`.

## Audio y texturas

- `python tools/build_audio.py`: voces sintetizadas con Piper (voz local, CC BY 4.0):
  radio de aliados, gritos de enemigos y `hit_thump.wav`. Las frases están en el
  script, y `scripts/audio/Voices.gd` decide quién habla. Piper vive en
  `~/.local/opt/piper` (Linux).
- `python tools/import_sounds.py [nombre..]`: los sonidos grabados (Freesound CC0 y
  OpenGameArt). Cada sonido es una línea de su tabla: archivo, fuente y corte.
- `python tools/cap_textures.py [1024]`: techo de las fotos de los mapas (`mapa_*`):
  1024 de lado, compresión y mipmaps. Las armas, los brazos y el soldado no se tocan.

## Trampas

- `gltf/embedded_image_handling=0` en un `.glb.import` descarta todas sus texturas al
  importar. Un mapa salió blanco y el check estaba verde.
- `export_filter=all_resources` mete en el paquete todo lo importado; lo que el juego
  no carga va en `exclude_filter`.
- Tras exportar un `.glb` o añadir un `class_name`, `godot --headless --path .
  --import` antes de jugar, o Godot usa lo viejo.
- La versión vive en `config/version` de `project.godot`. `export_presets.cfg` la
  repite a mano (la plataforma la pide), y `check.py` exige que coincida.
- Si Godot da «Failed loading resource» de un `.glb` por una PNG que ya no existe, la
  caché `.godot/imported/<glb>-*` apunta a ella: hay que borrar esa caché y reimportar.
- Godot se cuelga 1 de cada 40 arranques al salir, más o menos.
- Dos instancias del juego en un PC sirven para probar la red.
- Un script `-s` que carga la escena principal puede fallar con «Identifier not
  found: Net» (los autoloads no existen al compilarlo). Entonces se lanza como
  escena: `godot --path . res://<escena>.tscn`. En headless el ratón no queda
  capturado, así que Esc saca al lobby y no pausa.
