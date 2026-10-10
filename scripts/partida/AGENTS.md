# Partida

`Main` arma el juego: carga el mapa, el lobby, la partida, la muerte y la
reaparición, y la pantalla final. `CombatMap` lee el mapa y elige el director
de cada modo: `TeamMatch` (equipos contra bots), `Survival` (oleadas, hereda de
`TeamMatch`) y `NetMatch` (con amigos, dominio `red`). `MapCatalog.MAPS` es la
única tabla por mapa (escena, nombre, vista previa y la z de la cámara del
lobby) y sortea uno distinto del anterior cada vez que se entra a jugar
(`Main._play`); en red lo sortea el anfitrión y viaja en `Net._start`. Un mapa
nuevo es una entrada en esa tabla; los índices salen de ella, así que no hay
listas paralelas que se desincronicen. Cada mapa trae `home_0` y `home_1` (bases
de cada equipo), y sin ellas `TeamMatch` usa `HOMES`. Un director nuevo hereda
de `TeamMatch` y se engancha en `CombatMap.set_mode`, que es el único que crea
directores (`build()` ya no monta uno de prueba). `Settings` guarda los
ajustes en `user://settings.cfg` y su `TIERS` es la única tabla de calidades
(escala de dibujo, antialiasing, sesgo de mipmaps y filtro de texturas);
«Muy alta» es el índice 0, y un fichero viejo se corre uno al cargar (`tiers`
dentro del fichero) porque su 0 era «Alta». `CombatMap.build` viste el mapa con
el nivel elegido (`Settings.dress`). Las partidas no tienen tiempo límite: gana el
primer equipo que llega a `TeamMatch.TARGET` (150 puntos), y el reloj del marcador
sube.

Un director ofrece: `start`, `stop`, `my_team`, `attach`, `player_down`,
`spawn_point`, `board`, `result`, `elapsed` y las señales `actor_down` y
`finished`. Por dentro, `_process` lleva el reloj y llama a `_advance` (el bucle
de reaparición y órdenes, que cada modo extiende) y `_spawn` monta el cuerpo y
llama a `_wire` (lo que cada modo engancha al actor) y a `_goal_for` (adónde va
un bot en HOLD).

## Trampas medidas

- Los rivales salen con fusil según dificultad (`RIFLE_CHANCE` 15/35/60 %) y en oleadas sube un 6 % por oleada; la prisa (`rush`) también va con `skill` (30-60 %).
- Las previews del lobby del anfitrión (`assets/maps/preview_*.png`) son capturas del propio juego desde la aparición sin arma: regenerarlas si cambia un mapa.
- Cada colisionador lleva su superficie en el nombre (`concrete_`, `steel_`, `pine_`, `barrel_`, `rack_`, `paper_`, `glass_`): sin ella la bala avisa «sin perfil» y no deja impacto.
- El equipo empieza agrupado en `home_0`/`home_1` (cuatro puestos a ±1,3 m, `TeamMatch.opening_point`): un home dentro de un edificio con techo los encierra en una sala oscura. Los mapas los ponen en descampado y lo comprueban con `comprobar_base`.
- El modo a oscuras se quitó por orden del propietario: `Blackout`, su ajuste y la tormenta de ambiente salieron del árbol.
- La calidad se mide, no se adivina: en la APU AMD (Patio, 7 bots, 1600×900) «Alta» son 3,4–3,7 ms de GPU (220–233 fps) y «Muy alta» 5,3 ms (162 fps). MSAA 2× cuesta 0,7 ms y SMAA 0,8; el resto del nivel (sesgo de mipmaps −0,35, debanding y anisotrópico —128 superficies, 27 materiales—) no llega al ruido de medida. `scaling_3d_scale`, `msaa_3d`, `screen_space_aa`, `texture_mipmap_bias` y `use_debanding` son del viewport y se cambian en caliente; lo de `project.godot` pide reinicio.
- Se mide con un arnés local (`build/medir.gd`, no versionado) que lee `RenderingServer.viewport_get_measured_render_time_gpu` durante 10 s de partida andando: sin `viewport_set_measure_render_time(rid, true)` devuelve 0, y sin `Engine.max_fps = 0` después de arrancar `Main` (que lo vuelve a poner a 30) todo se mide contra el techo.
- El SSAO no existe en el renderer Mobile: el motor avisa («only available when using the Forward+ or Compatibility renderers») y la propiedad se guarda sin tocar un píxel. Dos capturas iguales ya difieren un 0,9 % de píxeles por el grano y los fogonazos de los bots: una diferencia de imagen sin la escena quieta no prueba nada.
- «Muy alta» pide el doble de fotograma que «Alta» a resolución nativa: por eso los niveles de abajo siguen bajando la escala de dibujo (`scaling_3d_scale`) en vez de apagar efectos, que es lo que ya estaba validado.
- El editor abre el juego maximizado (`Settings.apply`): con bordes y ocupando el área útil de la pantalla. Embebido (`Embed Game on Next Play`), Godot lo dibuja sin bordes con el tamaño de `project.godot` (overrides 1440x810), y se recorta si el panel es más chico.

## Deuda
- Patio y Callejones son al aire libre (el propietario lo aprobó: antes se prohibían) y cierran el recinto con muros de 8,5 m y 9 m (`muro_*` del GLB): no hay `Shell`; todos los `post_*` cuentan.
- Un puesto `post_*` sirve si está a cubierto y lejos de la línea de visión del rival: `TeamMatch.spawn_point` elige el de unos 14 m de recorrido al rival sin verlo. Por eso cada mapa trae 18–20 puestos repartidos por los dos lados. El recorrido se mide contra el rival más cercano en línea recta, no contra todos: con los 20 puestos y 4 rivales eran hasta 80 consultas de navegación por reaparición dentro del bucle del fotograma.
- Al empezar la partida (4 contra 4) cada equipo aparece junto en su base: `home_0`/`home_1` con cuatro ranuras a 1,3 m (`TeamMatch.opening_point`). El jugador ocupa la ranura 0 y sus aliados 1 a 3; los enemigos ocupan las 0 a 3 de su base. Los respawns siguen en los puestos `post_*`.
- Pendiente: Patio y Callejones se juegan por primera vez: revisar la reaparición en los puestos `post_*` y las líneas de tiro.
- Pendiente: el coste de «Muy alta» (5,3 ms en una APU AMD a 1600×900) no se ha medido en un PC lento ni en un teléfono; el nivel se queda sin probar donde más importa.

Usa: armas, audio, balistica, enemigos, interfaz, jugador, red
