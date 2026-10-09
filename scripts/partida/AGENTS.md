# Partida

`Main` arma el juego: carga el mapa, el lobby, la partida, la muerte y la
reaparición, y la pantalla final. `CombatMap` lee el mapa y elige el director
de cada modo: `TeamMatch` (equipos contra bots), `Survival` (oleadas, hereda de
`TeamMatch`) y `NetMatch` (con amigos, dominio `red`). `MapCatalog` lista los
mapas (Patio, Callejones) y sortea uno distinto del anterior cada vez que
se entra a jugar (`Main._play`); en red lo sortea el anfitrión y viaja en
`Net._start`. Cada mapa trae `home_0` y `home_1` (bases de cada equipo), y sin
ellas `TeamMatch` usa `HOMES`. Un director nuevo hereda
de `TeamMatch` y se engancha en `CombatMap.set_mode`. `Settings` guarda los
ajustes en `user://settings.cfg`. Las partidas no tienen tiempo límite: gana el
primer equipo que llega a `TeamMatch.TARGET` (150 puntos), y el reloj del marcador
sube.

Un director ofrece: `start`, `stop`, `my_team`, `attach`, `player_down`,
`spawn_point`, `board`, `result`, `elapsed` y las señales `actor_down` y
`finished`.

## Trampas medidas

- Los rivales salen con fusil según dificultad (`RIFLE_CHANCE` 15/35/60 %) y en oleadas sube un 6 % por oleada; la prisa (`rush`) también va con `skill` (30-60 %).
- Las previews del lobby del anfitrión (`assets/maps/preview_*.png`) son capturas del propio juego desde la aparición sin arma: regenerarlas si cambia un mapa.
- Cada colisionador lleva su superficie en el nombre (`concrete_`, `steel_`, `pine_`, `barrel_`, `rack_`, `paper_`, `glass_`): sin ella la bala avisa «sin perfil» y no deja impacto.
- El equipo empieza agrupado en `home_0`/`home_1` (cuatro puestos a ±1,3 m, `TeamMatch.opening_point`): un home dentro de un edificio con techo los encierra en una sala oscura. Los mapas los ponen en descampado y lo comprueban con `comprobar_base`.
- El modo a oscuras se quitó por orden del propietario: `Blackout`, su ajuste y la tormenta de ambiente salieron del árbol.
- El editor abre el juego maximizado (`Settings.apply`): con bordes y ocupando el área útil de la pantalla. Embebido (`Embed Game on Next Play`), Godot lo dibuja sin bordes con el tamaño de `project.godot` (overrides 1440x810), y se recorta si el panel es más chico.

## Deuda
- Patio y Callejones son al aire libre (el propietario lo aprobó: antes se prohibían) y cierran el recinto con muros de 8,5 m y 9 m (`muro_*` del GLB): no hay `Shell`; todos los `post_*` cuentan.
- Un puesto `post_*` sirve si está a cubierto y lejos de la línea de visión del rival: `TeamMatch.spawn_point` elige el de unos 14 m de recorrido al rival sin verlo. Por eso cada mapa trae 18–20 puestos repartidos por los dos lados.
- Al empezar la partida (4 contra 4) cada equipo aparece junto en su base: `home_0`/`home_1` con cuatro ranuras a 1,3 m (`TeamMatch.opening_point`). El jugador ocupa la ranura 0 y sus aliados 1 a 3; los enemigos ocupan las 0 a 3 de su base. Los respawns siguen en los puestos `post_*`.
- Pendiente: Patio y Callejones se juegan por primera vez: revisar la reaparición en los puestos `post_*` y las líneas de tiro.

- Pendiente: `Main` arma demasiadas cosas (lobby, partida, red, pausa); el flujo entre pantallas puede salir a su módulo.

Usa: armas, audio, balistica, enemigos, interfaz, jugador, red
