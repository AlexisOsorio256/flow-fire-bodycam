# Herramientas

Antes de escribir un script suelto, mira aquí: casi todo lo que hace falta
para ver, aislar y medir ya existe. Cada herramienta tiene una línea; el check
de arquitectura falla si un archivo de `tools/` no aparece en esta ficha.

- `python3 tools/check.py [dominio..] [--cambios] [--ver]`: definición de
  terminado. Primero la arquitectura (sin Godot, menos de 1 s; ver
  `AGENTS.md` raíz); luego las tablas de `tools/checks/`. `--cambios` corre solo
  los dominios que tocan los archivos cambiados (línea `Checks:` de cada
  `AGENTS.md`; fuera de `scripts/` corre todo). `--arquitectura` solo la
  primera parte; `--informe` ordena los dominios por deuda (pendientes,
  scripts grandes, dependencias y ciclos entre dominios). Entero, unos 4 min.
  `--ver` deja `captures/check_ver.png` (reposo, apuntando, inspeccionando).
  Cada check es `nombre|situación|cuadro|expresión|condición`; la situación
  (argumentos de snap) vive en `checks/situaciones.txt`. La expresión es de
  Godot (sin `is` ni listas por comprensión); la condición es Python sobre
  `x`. Un texto sin comillas no se evalúa: bool, número o lista (0/1 en listas).
- `godot --fixed-fps 30 --path . tools/snap.tscn -- --mode=combat --out=X.png`:
  captura determinista del juego (unos 7 s); `tools/snap.gd` es su arnés.
  `--frames=N` es el cuadro de la captura (60 si no se da) y `--act=acción:K`
  la lanza K cuadros antes
  (`reload`, `rempty`, `inspect`, `iempty`, `aim`, `hip`, `shot`, `die`,
  `hit`, `hurt`...), `--shots=f1,f2`
  con `--sheet=4`, `--crop=x,y,w,h` en fracciones, `--pos`, `--yaw`, `--pitch`
  y `--eval=cuadro:expresión;...`. Imprime el tiempo de cuadro y de GPU. El
  desenfunde ocupa el arma hasta el cuadro 40 y lo que se pida antes se avisa
  con `ACT ... ignorada`. `--record=archivo.wav` graba la salida maestra desde
  el cuadro `--record_from` (60 si no se da), que es como se mide el audio.
- `tools/probes.gd`: las expresiones de `--eval`. Para saber qué es cada cosa
  en pantalla: `ids()` pinta cada pieza de brazos y arma de un color plano y
  devuelve la leyenda, `solo('arms,magazine')` deja solo esas piezas,
  `no_world()` quita el mundo y `parts()` las lista. Animación: `bones()`,
  `sample()`, `contact_end()`. Ragdoll: `fall_test()`, `fall_hit()`,
  `fall_summary()`. Pantalla: `screen(p)` a través de la lente, `sight_px()`,
  `hud_texts()`. Táctil: `touch(dedo, x, y, pulsado)` y `drag(dedo, x, y, dx, dy)` en fracciones de pantalla, con `--touch` en snap.
  Red: `net()` da el autoload `Net`; dos instancias de snap, una con
  `net().host(1)` y otra con `net().join("127.0.0.1")` y varios
  `start_match()` reintentados, prueban una partida local en un solo PC.
- `tools/probes_pen.gd`: diana de penetración (`pen_shoot`, `pen_hp`), conteo
  de fusileros (`rifle_foes`), táctica de recluta (`recruit_tactics`), guard
  de versión al unirse (`join_guard`, `closed_hint`), traspaso de muros
  reales del mapa (`map_pen`, `map_pen_hp`, `map_scan`) y relleno y puerto
  (`fill_ready`, `bot_teams`, `bot_puppets`, `port_taken`).
- `tools/probes_audio.gd`: el sonido dentro de `--eval`, con `main` a un lado.
  `sound.heard('radio_')` lista lo que sonó (cuadro, archivo, distancia y bus),
  `bus_peak(bus)` y `bus_db(bus)` el nivel y el volumen de un bus,
  `sidechain(bus)` su sidechain, `in_room(filtro)` si algo sonó en la sala,
  `shot_layers()` las capas del último disparo, `enemy_shot_at(metros)` y
  `pos_at(metros)` disparan y sitúan sin depender de la cámara, `game()` da el
  nodo `GameAudio` (los globales como `AudioServer` no se resuelven solos) y
  `master_fx('muffle'|'headroom')` lee la cadena del maestro.
- Icono: en el Blender MCP, `runpy.run_path("tools/build_icon.py",
  run_name="__main__")` modela una cámara corporal sobre un chaleco a oscuras
  y renderiza `assets/icon.png` en Cycles (unos segundos; avisa con
  `/tmp/flowfire_icon_done`).
- `runpy.run_path("tools/build_flash.py", run_name="__main__")` y
  `tools/build_smoke.py`: los otros dos atlas de Blender. El primero hornea
  `assets/textures/muzzle_flash.png` (4 variantes del fogonazo) y el segundo
  `assets/textures/muzzle_puff.png` (8 fotogramas del humo, que usan
  `scripts/FxPools.gd` y `scripts/EnemyBlood.gd`). Los dos aceptan `--out`.
- `tools/package.sh [windows|linux|android]`: exporta las tres en 1 min (o una)
  y solo deja en `build/dist/` un archivo por plataforma listo para compartir
  (`.zip`, `.tar.gz` con el ejecutable que lleva el juego dentro, `.apk`), con
  la versión que declara `project.godot`. Los presets excluyen tools, blender,
  docs y captures. Android usa el SDK y el JDK de
  `~/.local/share/blockfire-tools/` (configurados en el editor).
- `[CROP=x,y,w,h] [SOLO=arms,...] [IDS=1] [NOWORLD=1] tools/sheet.sh nombre
  acción t1 t2..`: varios instantes de una acción en un arranque (unos 14 s),
  en `captures/<nombre>_sheet.png`.
- `python3 tools/build_audio.py`: regenera las voces sintetizadas en unos 3 min
  con Piper (voz neuronal local en `~/.local/opt/piper`: `uv venv venv`,
  `uv pip install piper-tts` y `en_US-libritts_r-medium.onnx` de
  huggingface.co/rhasspy/piper-voices, CC BY 4.0): radio de aliados y gritos
  de enemigos en `assets/audio/voice/`, y `hit_thump.wav`. Las frases están en
  el propio script y `scripts/audio/Voices.gd` decide quién habla.
- `python3 tools/import_sounds.py [nombre..]`: los sonidos grabados (disparos,
  ambientes, respiración, dolor y agonía) salen de Freesound CC0. Cada uno es
  una línea de su tabla (archivo, id del sonido, corte); los baja a
  `~/.cache/flowfire/freesound/`, los corta y normaliza. Poner, cambiar o
  quitar un sonido es tocar esa línea y volver a ejecutarlo.
- `tools/listen.sh nombre [argumentos de snap]`: graba la mezcla que sale de
  verdad, en esa situación (unos 100 s por cada 15 s de juego, que dura
  `--frames`/60). Imprime LUFS, rango y pico, y deja en
  `captures/audio/<nombre>.png` el espectrograma con la onda, y el `.wav`.
  Así se juzga la mezcla con números. Toma la salida del bus maestro con un
  `AudioEffectCapture`; **la pista de audio de `--write-movie` no sirve para
  esto**: se salta los buses, así que EQ, reverb, compresión y volúmenes de
  bus no aparecen en ella.
- `tools/fps_phone.sh [segundos] [muestras]`: mide los FPS reales en el móvil
  por USB sin depender de cifras del juego. Espera a que el teléfono enfríe
  (estado térmico 0), encuentra la capa del juego en `dumpsys SurfaceFlinger` y
  saca la mediana y el rango de los cuadros dibujados. Con el teléfono
  caliente las cifras no valen: tres medidas del mismo build dieron 31,2, 41,7
  y 40,2 FPS.
- `tools/refcmp.sh [idle aim reload inspect fire hit fall]`: referencia y
  juego en el mismo encuadre, mientras su pregunta siga abierta.
- Blender, `v = runpy.run_path("tools/blender_view.py")`:
  `v["game"](clip, [t..], nombre, show="all"|"arms"|"weapon",
  color="MATERIAL"|"VERTEX")` es la vista del juego en 1 s por instante, con
  el FOV de `BodyCam.gd` y la lente ojo de pez de `HUD.gd`; su silueta
  coincide con la del juego (IoU 0,87-0,90). También `closeup()` de un hueso,
  `shift_keys()` y `turn_keys()` para mover o girar claves en ejes de cámara,
  y `plan()` del mapa. Los tiempos van en segundos y los clips se escriben
  como en el `.blend`: `Idle`, `Aim`, `Fire`, `Reload`, `ReloadEmpty`,
  `Inspect`, `Equip`.
- Blender, `m = runpy.run_path("tools/blender_mesh.py")`: `islands()` (islas
  de malla con su hueso), `stretch(clips=[..])` (islas más estiradas respecto
  al reposo, 1 s por clip) y `paint(marked=[..])` para verlas con
  `game(..., color="VERTEX")`; `paint([])` las borra antes de exportar.
- Exportadores de Blender (`rebuild_arms.py`, `export_soldier.py`,
  `export_map.py`, `export_weapon.py`) y `factory_import.gd` (lo aplica Godot al
  importar el mapa): su uso está en `blender/AGENTS.md`.

## Trampas medidas

- snap pone `mouse_captured` a falso cada cuadro (para que el ratón no mire):
  la pausa es `Player.paused`, no la captura.
- Los toques inyectados van en píxeles de ventana; con el escalado de UI la
  ventana y el lienzo no coinciden (`touch()` ya lo resuelve).
- `get_tree().paused` congela también al arnés: para fotografiar la pausa se
  pone `paused` sin pausar el árbol.
- Lanzar Godot en paralelo falsea las medidas de GPU (HD 520 compartida); para
  probar la red sí se lanzan dos a la vez, pero sin mirar sus tiempos.
- `pkill -f` con un patrón que también coincide con tu orden mata tu shell.
- Godot se cuelga ~1 de cada 40 arranques al salir; check.py reintenta.
- Tras exportar un `.glb` o añadir un `class_name`, `godot --headless --path .
  --import` antes de capturar, o Godot usa lo viejo.
- La versión vive en `config/version` de `project.godot`; `export_presets.cfg`
  no la hereda: check.py exige que coincidan y `package.sh` nombra con ella.
