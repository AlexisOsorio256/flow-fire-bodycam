# Red

Jugar con amigos en la misma red, sin escribir direcciones. `Net` (autoload) crea
o se une a una partida, reparte equipos y lleva los mensajes; `LanDiscovery`
anuncia la partida por difusión (255.255.255.255 y la de cada interfaz), a un
grupo de multidifusión fijo (239.255.47.82) y además por ping directo a cada vecino
del /24 de cada segmento local. Quien busca pregunta cada dos segundos al puerto
47829, y quien crea la partida contesta con su baliza al que preguntó, para que la
respuesta vuelva por el mismo socket. `NetMatch` es el director: manda el estado del
jugador 20 veces por segundo, hace aparecer a los demás como `NetPuppet` (el soldado
con su ragdoll, sangre y reacciones, que no piensa) y lleva el marcador desde quien
creó la partida.

Quien dispara decide el impacto: su bala pega en el `NetPuppet` y este manda `hit`
a su dueño, que aplica el daño con `Player.take`. Las balas ajenas son solo
visuales. La revancha la lanza quien creó la partida.

Con el relleno activo (por defecto en el menú), el anfitrión llena los puestos
libres con bots del tamaño elegido (1v1, 2v2, 4v4): su estado viaja por `_bots` a 20
por segundo y su caída por `_bot_down`; los clientes los ven como `NetPuppet` con id
negativo. Sin relleno, la partida solo arranca cuando hay alguien en cada equipo.

`Net.host` busca puerto desde el 47820 (salta el de la baliza) y la baliza lleva el
elegido en `port`: dos partidas pueden convivir en una máquina.

## Trampas

- Cada RPC con efecto en partida lleva `Net.PROTOCOL` en la baliza y en `_hello`.
  Al cambiar un RPC se sube el número: sin versión no hay ni intento de conexión
  (`actualiza el juego`).
- Dos instancias en un PC prueban la red; cada una corre a su ritmo, así que
  `start_match()` se reintenta varias veces (no reinicia una partida en curso).
- Al probar con dos instancias, la que cierra primero hace que la otra vea
  `server_disconnected` y pase a roster 0: parece un fallo de unión y no lo es.
- Si no une fuera de la máquina, mira antes versiones distintas, el cortafuegos o un
  AP aislado que el código de unión. En Windows, el «Permitir» de la primera vez
  decide todo: sin él, ni difusión ni ping cruza. El panel dice qué probar en
  palabras llanas.
- La difusión por 255.255.255.255 se pierde en los AP que aíslan a los clientes o
  con la tasa base de 802.11: el ping directo a cada vecino del /24 la cruza. La
  subred asume /24; un `10.` o `172.` con máscara más ancha pide ajustar
  `LanDiscovery`.
- El barrido de vecinos cubre los segmentos privados, el CGNAT (`100.64.`) y el
  enlace local (`169.254.`); la baliza va también al grupo de multidifusión, que no
  depende del direccionamiento, y sale por tandas (`BATCH`) para no llenar el búfer.
- El ENet del anfitrión y el puerto de la baliza no se pisan (47820+ contra 47821).
  Las preguntas van al 47829, fuera de ese rango.
- Un «no» en el aviso de red de Windows deja al jugador sin ver ninguna partida. Por
  eso quien busca pregunta y el anfitrión contesta al que preguntó: la respuesta
  vuelve por el socket que preguntó y el cortafuegos la deja pasar.
- `Net.host` reserva antes un puerto TCP (puerto de juego + 1000) y salta el que ya
  tenga dueño: en Windows, dos procesos pueden abrir el mismo puerto UDP sin error.
- La baliza se guarda por IP y puerto: dos partidas en una misma máquina aparecen
  las dos en la lista.
- El estado lleva el arma (`send_state`/`send_shot` con `weapon`);
  `EnemyRifle.set_weapon` esconde `Gun` y cuelga `Rifle3P` en su mismo anclaje.

## Deuda

- Pendiente: sin probar en móvil (el PC de desarrollo no tiene SDK de Android).
- Pendiente: confirmar que la búsqueda que pregunta muestra las partidas en la red
  del propietario; su subred ya está en el barrido, pero no se ha vuelto a probar
  en su equipo.
- Pendiente: dos partidas creadas en la misma máquina comparten el 47829 de las
  preguntas y la segunda puede quedarse sin contestarlas (la difusión sigue igual).
- Pendiente: una red solo IPv6 no la cubre la búsqueda: `addresses` mira IPv4.
- Pendiente: un programa ajeno que use el puerto UDP de la partida puede compartirlo
  en Windows sin error; el cerrojo TCP solo protege entre partidas de FlowFire.

Usa: audio, balistica, enemigos, jugador, partida
