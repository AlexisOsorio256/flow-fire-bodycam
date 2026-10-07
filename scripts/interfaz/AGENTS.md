# Interfaz

`HUD` es la imagen de bodycam (lente, caras pixeladas, reloj y REC) y monta los
controles táctiles. `Lobby` es el menú con un panel a la vez a la derecha
(`SettingsPanel`, controles, `LocalPanel` para jugar con amigos). `PauseMenu`,
`DeathScreen` y `Scoreboard` son pausa, fin de partida y marcador.
`TouchControls` son los controles de móvil (diseño editable con `TouchEditor`,
iconos dibujados en `TouchIcons`, ayuda al apuntar en `AimAssist`). `UiStyle`
da letras, colores y botones.

Textos en lenguaje natural, como se le hablaría al jugador: nada de siglas,
jerga ni mayúsculas de consola. En móvil, botones de verdad y nunca pistas de
teclado. La UI escala con la pantalla (`stretch canvas_items`): las posiciones
se calculan sobre el tamaño visible, no sobre píxeles fijos.

## Trampas medidas

- El propietario rechazó iconos con letras («F», «MIRA») y mostrar direcciones
  IP: iconos dibujados y listas que se tocan.
- En Android el modo de ratón capturado no se mantiene: la pausa es
  `Player.paused`.
- Un error dice qué pasó y qué probar en palabras llanas, sin jerga ni siglas: nada de cortafuegos o mayúsculas de consola (`LocalPanel._on_closed` reescucha para reintentar).

## Deuda

- Pendiente: el editor de controles no se ha probado en un teléfono.

Usa: audio, enemigos, jugador, partida, red
Checks: tactil, pantalla, local
