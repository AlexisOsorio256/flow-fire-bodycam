# Red

Jugar con amigos en la misma red, sin escribir direcciones. `Net` (autoload)
crea o se une a una partida, reparte equipos y lleva los mensajes;
`LanDiscovery` anuncia la partida por difusión (255.255.255.255 y la de cada
interfaz), a un grupo de multidifusión fijo (239.255.47.82) y además por ping
directo a cada vecino del /24 de cada segmento local, por si la red de verdad
se come la difusión: es una trampa de AP ratradas y del punto de acceso
aislado. Escucha las partidas de otros. `NetMatch` es el director: manda el estado del
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

- Dos instancias del juego en un PC prueban la red; cada una corre a su ritmo,
  así que `start_match()` se reintenta varias veces (`start_match` no reinicia
  una partida en curso).
- Android necesita los permisos de red y de multidifusión
  (`export_presets.cfg`); en móvil aún no se ha probado.
- Cada RPC con efecto en partida lleva `Net.PROTOCOL` en la baliza y en `_hello`; al cambiar un RPC se sube el número. Sin versión no hay ni intento de conexión (`actualiza el juego`).
- Dos instancias en un PC sí se unen en local (medido: `connected` y roster de 2); fuera del wifi no une: mira versiones distintas, cortafuegos o AP aislado antes que el código de unión. En Windows, ese «Permitir» de primera vez decide todo: sin él, ni difusión ni ping cruza; el panel dice qué probar en palabras llanas.
- La difusión por 255.255.255.255 se lleva a la basura en el AP que aísla a los clientes o cuando 802.11 la tasa base filtra tramas de difusión: el ping directo a cada vecino del /24 lo cruza. La subred asume /24: un `10.` o `172.` con máscara más ancha pide el mismo ajuste en `LanDiscovery`.
- El barrido de vecinos miraba solo las direcciones `192.168.`, `10.` y `172.`: un PC con otra conexión (CGNAT `100.64.`, enlace local `169.254.`, VPN) se quedaba sin barrido y solo con la difusión global, que muchos AP tiran; por eso el propietario no veía la partida de sus amigos de Linux y Windows y sospechaba de su tipo de conexión. Ahora el barrido cubre los segmentos privados, el CGNAT y el enlace local, la baliza va también al grupo de multidifusión `239.255.47.82` (que no depende del direccionamiento) y sale por tandas (`BATCH`) para no llenar el búfer de envío.
- Al probar con dos instancias, la que arranca antes termina antes: evalúa el roster con las dos vivas. Si una cierra, la otra ve `server_disconnected` y pasa a roster 0, que parece un fallo de unión y no lo es (medido); el `NO GRAB` de X11 al capturar el ratón es ruido del solape.
- El ENet del anfitrión y el puerto de la baliza no se pisan (47820+ contra 47821): en la misma máquina, la escucha de la baliza del cliente falla si el anfitrión cae en su puerto.
- El estado lleva el arma (`send_state`/`send_shot` con `weapon`); `EnemyRifle.set_weapon` esconde `Gun` y cuelga `Rifle3P` en su mismo anclaje: la pose `Aim` de pistola lo sujeta bien con ambas manos (medido en capturas de lado).
- En Windows dos procesos pueden abrir el mismo puerto UDP sin error y el cliente entra al otro: `Net.host` reserva antes un puerto TCP (puerto de juego + 1000) y salta el que ya tenga dueño. `leave` lo suelta, así que cerrar y abrir libera el puerto.
- La baliza se guarda por IP y puerto: dos partidas en una misma máquina aparecen las dos en la lista.

## Deuda

- Pendiente: sin probar en móvil (el PC de desarrollo no tiene SDK de Android). El propietario vio jugar a Linux y Windows entre sí, pero su PC no veía su partida: falta que confirme que con esta búsqueda la ve.
- Pendiente: una red solo IPv6 no la cubre la búsqueda: `addresses` mira IPv4 y no hay difusión de la que tirar.
- Pendiente: un programa ajeno que use el puerto UDP de la partida puede compartirlo en Windows sin error; el cerrojo TCP solo protege entre partidas de FlowFire.
- Pendiente: `NetPuppet` repite de `Enemy` el tiro, el impacto y la zancada, y ya divergió (su `react.kick` no lleva el `clampf` de `EnemyWounds.kick`): unificarlo cambia la reacción de los muñecos y lo da por bueno el propietario jugando.
- Pendiente: `NetMatch._spawn_bot` copia `TeamMatch._spawn` y el anillo de cadáveres está en tres sitios; subirlo a `TeamMatch` con un gancho es refactor puro.

Usa: audio, balistica, enemigos, jugador, partida
