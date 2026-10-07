# Partida

`Main` arma el juego: carga el mapa, el lobby, la partida, la muerte y la
reaparición, y la pantalla final. `CombatMap` lee el mapa y elige el director
de cada modo: `TeamMatch` (equipos contra bots), `Survival` (oleadas, hereda de
`TeamMatch`) y `NetMatch` (con amigos, dominio `red`). Un director nuevo hereda
de `TeamMatch` y se engancha en `CombatMap.set_mode`. `Blackout` es el modo a
oscuras. `Settings` guarda los ajustes en `user://settings.cfg`.

Un director ofrece: `start`, `stop`, `my_team`, `attach`, `player_down`,
`spawn_point`, `board`, `result`, `elapsed` y las señales `actor_down` y
`finished`.

## Deuda

- Pendiente: `Main` arma demasiadas cosas (lobby, partida, red, pausa); el flujo entre pantallas puede salir a su módulo.

Usa: armas, audio, balistica, enemigos, interfaz, jugador, red
Checks: supervivencia, apagon, luz, municion, local, rendimiento
