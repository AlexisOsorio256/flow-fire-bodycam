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
- Cada RPC con efecto en partida lleva `Net.PROTOCOL` en la baliza y en `_hello`; al cambiar un RPC se sube el número. Sin versión no hay ni intento de conexión (`actualiza el juego`).
- Dos instancias en un PC sí se unen en local (medido: `connected` y roster de 2); fuera del wifi no une: mira versiones distintas, cortafuegos o AP aislado antes que el código de unión.
- El estado lleva el arma (`send_state`/`send_shot` con `weapon`); `EnemyRifle.set_weapon` esconde `Gun` y cuelga `Rifle3P` en su mismo anclaje: la pose `Aim` de pistola lo sujeta bien con ambas manos (medido en capturas de lado).

## Deuda

- Pendiente: sin probar en móvil.

Usa: audio, balistica, enemigos, jugador, partida
Checks: local
