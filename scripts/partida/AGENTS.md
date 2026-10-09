# Partida

`Main` arma el juego: carga el mapa, el lobby, la partida, la muerte y la
reaparición, y la pantalla final. `CombatMap` lee el mapa y elige el director
de cada modo: `TeamMatch` (equipos contra bots), `Survival` (oleadas, hereda de
`TeamMatch`) y `NetMatch` (con amigos, dominio `red`). `MapCatalog` lista los
mapas (Fábrica, Muelle, Nave) y sortea uno distinto del anterior cada vez que
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
- El suelo de la Fábrica (un convexo `concrete_001` de 0,5 m) cubre solo 54 x 61 m y el mapa seguía abierto hacia fuera: el jugador caía sin fin. `MapShell` (nodo `Shell` de `Factory.tscn`) cierra el mapa con muros de chapa a 7 m, techo y un ribete de suelo de 0,5 m. `CombatMap` descarta los `post_` fuera del cascarón (`post_19` estaba a z -33,6). `Main` devuelve al jugador a su aparición por debajo de -6 m.
- Muelle y Nave tenían el suelo colisionable entre x -20 y 19,5 y z -17,5 y 18, con el terreno visible y el cielo más allá: cada escena trae su `Shell` (centro -0,25; 0,25 y medias 19,75 x 17,75).
- Las previews del lobby del anfitrión (`assets/maps/preview_*.png`) son capturas del propio juego desde la aparición sin arma: regenerarlas si cambia un mapa.
- El modo a oscuras se quitó por orden del propietario: `Blackout`, su ajuste y la tormenta de ambiente salieron del árbol.

## Deuda
- Pendiente: el cascarón de la Fábrica es geometría de código con luz ambiental, no horneada: revisar si su brillo casa con el interior.

- Pendiente: `Main` arma demasiadas cosas (lobby, partida, red, pausa); el flujo entre pantallas puede salir a su módulo.
- Pendiente: el mapa trae un marcador `player_spawn` que ya nadie lee (el jugador sale de `director.spawn_point`): decidir si se usa o se saca del `.blend`.

Usa: armas, audio, balistica, enemigos, interfaz, jugador, red
