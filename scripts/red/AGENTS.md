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

Con el relleno activo (por defecto en el menú), el anfitrión llena los puestos
libres con bots del tamaño elegido (1v1, 2v2, 4v4): su estado viaja por
`_bots` a 20 por segundo (con el tumbado) y su caída por `_bot_down`; los clientes los ven como
`NetPuppet` con id negativo y su daño viaja igual que el de un jugador. Sin
relleno, la partida solo arranca cuando hay alguien en cada equipo.

`Net.host` busca puerto desde el 47820 (salta el de la baliza) y la baliza
lleva el elegido en `port`: dos partidas pueden convivir en una máquina y un
puerto ocupado no da error.

## Trampas medidas

- Dos instancias de snap en un PC prueban la red; cada una corre a su ritmo,
  así que `start_match()` se reintenta varias veces (`start_match` no reinicia
  una partida en curso).
- Android necesita los permisos de red y de multidifusión
  (`export_presets.cfg`); en móvil aún no se ha probado.
- Cada RPC con efecto en partida lleva `Net.PROTOCOL` en la baliza y en `_hello`; al cambiar un RPC se sube el número. Sin versión no hay ni intento de conexión (`actualiza el juego`).
- Dos instancias en un PC sí se unen en local (medido: `connected` y roster de 2); fuera del wifi no une: mira versiones distintas, cortafuegos o AP aislado antes que el código de unión.
- Al medir con dos snap, la que arranca antes termina antes: evalúa el roster con las dos vivas. Si una cierra, la otra ve `server_disconnected` y pasa a roster 0, que parece un fallo de unión y no lo es (medido); el `NO GRAB` de X11 al capturar el ratón es ruido del solape.
- El ENet del anfitrión y el puerto de la baliza no se pisan (47820+ contra 47821): en la misma máquina, la escucha de la baliza del cliente falla si el anfitrión cae en su puerto.
- El estado lleva el arma (`send_state`/`send_shot` con `weapon`); `EnemyRifle.set_weapon` esconde `Gun` y cuelga `Rifle3P` en su mismo anclaje: la pose `Aim` de pistola lo sujeta bien con ambas manos (medido en capturas de lado).

## Deuda

- Pendiente: sin probar en móvil.
- Pendiente: `NetPuppet` repite de `Enemy` el tiro, el impacto y la zancada, y ya divergió (su `react.kick` no lleva el `clampf` de `EnemyWounds.kick`): unificarlo cambia la reacción de los muñecos y lo da por bueno el propietario jugando.
- Pendiente: `NetMatch._spawn_bot` copia `TeamMatch._spawn` y el anillo de cadáveres está en tres sitios; subirlo a `TeamMatch` con un gancho es refactor puro, medible con `check.py local` y dos snap.

Usa: audio, balistica, enemigos, jugador, partida
Checks: local
