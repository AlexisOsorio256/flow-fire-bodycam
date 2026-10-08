# Interfaz

`HUD` es la imagen de bodycam (lente, caras pixeladas, reloj y REC) y monta los
controles táctiles. `Lobby` es el menú con un panel a la vez a la derecha
(`SettingsPanel`, controles, `LocalPanel` para jugar con amigos, con relleno
de puestos libres por enemigos y el puerto que la baliza anuncia).
`PauseMenu`, `DeathScreen` y `Scoreboard` son pausa, fin de partida y marcador.
`TouchControls` son los controles de móvil (diseño editable con `TouchEditor`,
iconos dibujados en `TouchIcons`, ayuda al apuntar en `AimAssist`); dos botones
para disparar, el de la izquierda solo dispara (no gira la vista) y ambos se
mueven en el editor. `UiStyle` da letras, colores y botones.

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
- Los ajustes van por grupos (partida, control, imagen, sonido) y enseñan solo lo del aparato: en PC no salen los táctiles y en móvil no sale Pantalla.
- El look de la lente vive en `bodycam.gdshader`: lo fijo (viñeta, grano, saturación, dureza del aro, celdas de la cara) es `const`; desde código solo se pone lo que cambia en partida (fov, círculo, barrel, pulsos, caras y desvanecido).
- Las caras pixeladas cuestan 0,028 ms por cuadro con 12 enemigos delante (medido): recalcularlas 1 de cada 3 cuadros ahorraría un 0,17 % del cuadro y añadiría 50 ms de retraso a la cara, así que no se baja la tasa. Lo que sí se hace es reutilizar la query de línea de visión y no trabajar con el árbol en pausa.

## Deuda

- Pendiente: el editor de controles no se ha probado en un teléfono.

Usa: audio, enemigos, jugador, partida, red
