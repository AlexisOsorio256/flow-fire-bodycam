# Red

Jugar con amigos en el mismo wifi, sin escribir direcciones. `Net` (autoload)
crea o se une a una partida, reparte equipos y lleva los mensajes;
`LanDiscovery` anuncia la partida por difusión (a 255.255.255.255 y a la
subred) y escucha las de otros. `NetMatch` es el director: manda el estado del
jugador 20 veces por segundo, hace aparecer a los demás como `NetPuppet` (el
soldado con su ragdoll, sangre y reacciones, que no piensa) y lleva el marcador
desde quien creó la partida.

Quien dispara decide el impacto: su bala pega en el `NetPuppet` y este manda
`hit` a su dueño, que aplica el daño con `Player.take`. Las balas ajenas son
solo visuales. La revancha la lanza quien creó la partida.

## Trampas medidas

- Dos instancias de snap en un PC prueban la red; cada una corre a su ritmo,
  así que `start_match()` se reintenta varias veces (`start_match` no reinicia
  una partida en curso).
- Android necesita los permisos de red y de multidifusión
  (`export_presets.cfg`); en móvil aún no se ha probado.

## Deuda

- Pendiente: los demás jugadores se ven con pistola aunque lleven rifle.
- Pendiente: sin probar en móvil.

Usa: audio, balistica, enemigos, jugador, partida
Checks: local
