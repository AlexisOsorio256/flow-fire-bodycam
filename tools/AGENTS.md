# Herramientas

Lo que produce el juego: modelos, texturas, audio y paquetes. El control de
calidad es el propietario; cada herramienta entra solo si ahorra más tiempo del
que cuesta, y si añades una, deja su línea aquí.

- `python3 tools/check.py`: lo único que se comprueba solo, en menos de un
  segundo y sin arrancar el juego: arquitectura (líneas, comentarios, scripts
  fuera de dominio, versión en un sitio) y después la
  sintaxis de todos los scripts en un arranque headless. `--arquitectura` corre
  solo lo primero e `--informe` lista los dominios por tamaño y pendientes.

- `tools/package.sh [windows|linux|android]`: exporta las tres en 1 min (o una)
  y deja en `build/dist/` un archivo por plataforma (`.zip`, `.tar.gz` con el
  juego dentro, `.apk`) con la versión de `project.godot`. Los presets excluyen
  tools, blender, docs y captures; Android usa `~/.local/share/blockfire-tools/`.
- `tools/factory_import.gd`: lo que Godot aplica al importar el mapa (superficie
  de cada colisionador, occluders y sombras de las lámparas). Un cuerpo sin
  prefijo conocido avisa con `push_error`.
- Exportadores de Blender (`rebuild_arms.py`, `export_soldier.py`,
  `export_map.py`, `export_cover.py`, `export_weapon.py`): su uso está en `blender/AGENTS.md`.
- `tools/shot.tscn`: capturas del juego desde cámaras dadas, con el `build()` del
  mapa; un PNG por vista en `captures/<nombre>_<i>.png` (2 s con la GPU):
  `godot --path . --resolution 960x540 --scene res://tools/shot.tscn -- <nombre> res://scenes/Nave.tscn "x,y,z/mirada" ...`.
  Las coordenadas son de Godot: Blender (x, y, z) es Godot (x, z, -y).
- `tools/shot_arma.gd`: el arma en la mano, disparando, con fotogramas en los tiempos dados (segundos tras el disparo). `godot --path . --resolution 960x540 -s res://tools/shot_arma.gd -- --map=2 --weapon=1 --settle=2.6 --pitch=0 --yaw=0 --fire --times=0.03,0.08 --out=nombre`. `--map` 0 Fábrica, 1 Muelle, 2 Nave; `--weapon` 0 pistola, 1 fusil, 2 escopeta; `--settle` tiene que dar tiempo a desenfundar (2,6 s el fusil, 3,2 s la escopeta). Fija `--pitch` y `--yaw`: sin ellos la vista de salida cambia de una ejecución a otra.
- Blender, `v = runpy.run_path("tools/blender_view.py")`:
  `v["game"](clip, [t..], nombre, show="all"|"arms"|"weapon",
  color="MATERIAL"|"VERTEX")` es la vista del juego en 1 s por instante, con
  el FOV de `BodyCam.gd` y la lente ojo de pez de `HUD.gd`. También `closeup()`
  de un hueso, `shift_keys()` y `turn_keys()` para mover o girar claves en ejes
  de cámara, y `plan()` del mapa. Los tiempos van en segundos y los clips se
  escriben como en el `.blend`: `Idle`, `Aim`, `Fire`, `Reload`, `ReloadEmpty`,
  `Inspect`, `Equip`.
- Blender, `m = runpy.run_path("tools/blender_mesh.py")`: `islands()` (islas
  de malla con su hueso), `stretch(clips=[..])` (islas más estiradas respecto
  al reposo, 1 s por clip) y `paint(marked=[..])` para verlas con
  `game(..., color="VERTEX")`; `paint([])` las borra antes de exportar.
- Blender, `p = runpy.run_path("tools/anim_pose.py")`: claves a mano por
  script; `bend`, `nudge` y `fingers` posan huesos y dedos, `mirror` copia el
  giro local de otro clip y `travel` devuelve el recorrido para medir.
- `runpy.run_path("tools/build_flash.py")` y `tools/build_smoke.py` hornean
  `assets/textures/muzzle_flash.png` (4 fogonazos) y `muzzle_puff.png` (8 del
  humo, usados por `FxPools.gd` y `EnemyBlood.gd`); los dos aceptan `--out`.
- Icono: `runpy.run_path("tools/build_icon.py", run_name="__main__")` en el
  Blender MCP modela una bodycam sobre un chaleco a oscuras y renderiza
  `assets/icon.png` en Cycles (avisa con `/tmp/flowfire_icon_done`).
- `python3 tools/build_audio.py`: regenera las voces sintetizadas en unos 3 min
  con Piper (voz neuronal local en `~/.local/opt/piper`: `uv venv venv`,
  `uv pip install piper-tts` y `en_US-libritts_r-medium.onnx` de
  huggingface.co/rhasspy/piper-voices, CC BY 4.0): radio de aliados y gritos
  de enemigos en `assets/audio/voice/`, y `hit_thump.wav`. Las frases están en
  el propio script y `scripts/audio/Voices.gd` decide quién habla.
- `python3 tools/import_sounds.py [nombre..]`: los sonidos grabados salen de
  Freesound CC0 y de OpenGameArt (la escopeta, del 7z de la librería de armas).
  Cada uno es una línea de su tabla (archivo, fuente, corte); los baja a
  `~/.cache/flowfire/freesound/`, los corta y normaliza. Poner, cambiar o
  quitar un sonido es tocar esa línea y volver a ejecutarlo.

## Trampas medidas

- Godot se cuelga ~1 de cada 40 arranques al salir.
- Tras exportar un `.glb` o añadir un `class_name`, `godot --headless --path .
  --import` antes de jugar, o Godot usa lo viejo.
- La versión vive en `config/version` de `project.godot`; `export_presets.cfg`
  no la hereda: `package.sh` nombra con ella.
- En Android el modo de ratón capturado no se mantiene: la pausa es
  `Player.paused`, no la captura.
- Lanzar dos instancias del juego a la vez sirve para probar la red en un PC.
