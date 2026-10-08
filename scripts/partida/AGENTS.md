# Partida

`Main` arma el juego: carga el mapa, el lobby, la partida, la muerte y la
reaparición, y la pantalla final. `CombatMap` lee el mapa y elige el director
de cada modo: `TeamMatch` (equipos contra bots), `Survival` (oleadas, hereda de
`TeamMatch`) y `NetMatch` (con amigos, dominio `red`). Un director nuevo hereda
de `TeamMatch` y se engancha en `CombatMap.set_mode`. `Settings` guarda los
ajustes en `user://settings.cfg`.

Un director ofrece: `start`, `stop`, `my_team`, `attach`, `player_down`,
`spawn_point`, `board`, `result`, `elapsed` y las señales `actor_down` y
`finished`.

## Trampas medidas

- Los rivales salen con fusil según dificultad (`RIFLE_CHANCE` 15/35/60 %) y en oleadas sube un 6 % por oleada; la prisa (`rush`) también va con `skill` (30-60 %).
- El modo a oscuras se quitó por orden del propietario: `Blackout`, su ajuste y la tormenta de ambiente salieron del árbol.

## Deuda

- Pendiente: `Main` arma demasiadas cosas (lobby, partida, red, pausa); el flujo entre pantallas puede salir a su módulo.
- Pendiente: el mapa trae un marcador `player_spawn` que ya nadie lee (el jugador sale de `director.spawn_point`): decidir si se usa o se saca del `.blend`.

Usa: armas, audio, balistica, enemigos, interfaz, jugador, red
Checks: supervivencia, luz, municion, local, rendimiento
