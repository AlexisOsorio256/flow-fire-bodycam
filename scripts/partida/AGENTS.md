# Partida

`Main` arma el juego: carga el mapa, el lobby, la partida, la muerte y la
reaparición, y la pantalla final. `CombatMap` lee el mapa y elige el director de
cada modo: `TeamMatch` (equipos contra bots), `Survival` (oleadas, hereda de
`TeamMatch`) y `NetMatch` (con amigos, dominio `red`). `MapCatalog.MAPS` es la
única tabla por mapa (escena, nombre, vista previa y la z de la cámara del lobby) y
sortea uno distinto del anterior cada vez que se entra a jugar; en red lo sortea el
anfitrión y viaja en `Net._start`. Un mapa nuevo es una entrada en esa tabla.
Cada mapa trae `home_0` y `home_1` (bases de cada equipo).

`Settings` guarda los ajustes en `user://settings.cfg`; su `TIERS` es la única
tabla de calidades (escala de dibujo, antialiasing, sesgo de mipmaps y filtro de
texturas). «Muy alta» es el índice 0. Un director nuevo hereda de `TeamMatch` y se
engancha en `CombatMap.set_mode`, que es el único que crea directores.

Si cambia el orden de `TIERS` o se añade un nivel delante, sube `TIERS_VERSION` y
añade la migración en `Settings.load_saved`: un ajuste guardado con la versión vieja
se corre un nivel al cargar, o el jugador acaba con otra calidad sin tocar nada.

Un director ofrece: `start`, `stop`, `my_team`, `attach`, `player_down`,
`spawn_point`, `board`, `result`, `elapsed` y las señales `actor_down` y
`finished`. Por dentro, `_process` lleva el reloj y llama a `_advance` (lo que cada
modo extiende) y `_spawn` monta el cuerpo y llama a `_wire` y `_goal_for`.

## Trampas

- Los rivales salen con fusil según dificultad (`RIFLE_CHANCE` 15/35/60 %); en
  oleadas sube un 6 % por oleada. La prisa (`rush`) va con `skill` (30-60 %).
- El equipo empieza agrupado en `home_0`/`home_1` (cuatro puestos a ±1,3 m,
  `TeamMatch.opening_point`). Un home dentro de un edificio con techo encierra al
  equipo en una sala oscura: los mapas los ponen en descampado y `comprobar_base`
  lo verifica.
- Cada colisionador lleva su superficie en el nombre (`concrete_`, `steel_`,
  `pine_`, `barrel_`, `rack_`, `paper_`, `glass_`): sin ella la bala avisa «sin
  perfil» y no deja impacto.
- Las previews del lobby (`assets/maps/preview_*.png`) son capturas del propio juego
  desde la aparición sin arma: regenerarlas si cambia un mapa.
- El modo a oscuras se quitó por orden del propietario: no volver a añadirlo sin
  pedirlo.
- La calidad se mide, no se adivina. En una APU AMD (Patio, 7 bots, 1600×900),
  «Alta» son 3,4–3,7 ms de GPU y «Muy alta» 5,3 ms. MSAA 2× cuesta 0,7 ms y SMAA
  0,8. El resto del nivel no llega al ruido de medida.
- Los niveles bajan la escala de dibujo (`scaling_3d_scale`) y no apagan efectos:
  «Muy alta» pide el doble de fotograma que «Alta» a resolución nativa.
- `scaling_3d_scale`, `msaa_3d`, `screen_space_aa`, `texture_mipmap_bias` y
  `use_debanding` se cambian en caliente; lo de `project.godot` pide reinicio.
- `scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR` en Baja (0,70) y Media (0,85) aplica escalado espacial nativo de Godot 4 con nitidez adaptativa (`fsr_sharpness`), reduciendo el relleno de píxeles sin el coste de re-renderizado nativo. `mesh_lod_threshold` (2,0 en Baja, 1,2 en Media) alivia la geometría en gama baja.
- Para medir, `RenderingServer.viewport_get_measured_render_time_gpu` necesita
  `viewport_set_measure_render_time(rid, true)` y `Engine.max_fps = 0` tras arrancar
  `Main` (que lo pone a 30). `tools/medir.gd` lo hace durante 10 s de partida
  andando.
- El SSAO no existe en el renderer Mobile: el motor avisa y la propiedad no hace
  nada. Dos capturas iguales ya difieren un 0,9 % de píxeles por el grano y los
  fogonazos de los bots: una diferencia de imagen sin la escena quieta no prueba nada.
- El editor abre el juego maximizado (`Settings.apply`). Embebido, Godot lo dibuja
  con el tamaño de `project.godot` (overrides 1440x810) y lo recorta si el panel es
  más chico.

## Deuda

- Patio y Callejones son al aire libre (el propietario lo aprobó) y cierran el
  recinto con muros de 8,5 m y 9 m (`muro_*` del GLB): no hay `Shell`; todos los
  `post_*` cuentan.
- Un puesto `post_*` sirve si está a cubierto y lejos de la línea de visión del
  rival: `TeamMatch.spawn_point` elige el de unos 14 m de recorrido al rival sin
  verlo. Cada mapa trae 18–20 puestos repartidos por los dos lados.
- Pendiente: Patio y Callejones se juegan por primera vez: revisar la reaparición en
  los puestos `post_*` y las líneas de tiro.
- Pendiente: el coste de «Muy alta» (5,3 ms en una APU AMD a 1600×900) no se ha
  medido en un PC lento ni en un teléfono; el nivel se queda sin probar donde más
  importa.

Usa: armas, audio, balistica, enemigos, interfaz, jugador, red
