# Interfaz

`HUD` es la imagen de bodycam (lente, caras pixeladas, reloj y REC) y monta los
controles táctiles. `Lobby` es el menú con un panel a la vez a la derecha
(`SettingsPanel`, controles, `LocalPanel` para jugar con amigos, con relleno de
puestos libres por enemigos y el puerto que la baliza anuncia). `PauseMenu`,
`DeathScreen` y `Scoreboard` son pausa, fin de partida y marcador.
`TouchControls` son los controles de móvil (diseño editable con `TouchEditor`,
iconos dibujados en `TouchIcons`, ayuda al apuntar en `AimAssist`). `UiStyle` da
letras, colores y botones.

Textos en lenguaje natural, como se le hablaría al jugador: nada de siglas, jerga
ni mayúsculas de consola. Las rotulaciones de la cámara (REC, SEÑAL PERDIDA, FIN DE
GRABACIÓN) son parte de la imagen de bodycam y no cuentan. En móvil, botones de
verdad y nunca pistas de teclado. La UI escala con la pantalla (`stretch
canvas_items`).

Las teclas no se leen aquí: los menús usan `ui_up`, `ui_down`, `ui_left`,
`ui_right`, `ui_accept` y `ui_cancel` (`project.godot`, `[input]`), que ya llevan
W, S, A y D además de las flechas. Un menú nuevo no define su propia lista de teclas.

## Trampas

- El editor de controles consume el toque (`set_input_as_handled`): si no, el menú
  que queda debajo recibía el mismo toque y el botón de disparar caía sobre «Salir».
- Las medidas y los huecos de los paneles salen de `UiStyle` (`label`, `button`,
  `gap`).
- El propietario rechazó iconos con letras y mostrar direcciones IP: iconos
  dibujados y listas que se tocan.
- Un error dice qué pasó y qué probar, en palabras llanas: nada de cortafuegos ni
  siglas.
- Los ajustes van por grupos (partida, control, imagen, sonido) y enseñan solo lo
  del aparato: en PC no salen los táctiles y en móvil no sale Resolución.
- El nombre de cada calidad sale de `Settings.TIERS`: el panel no guarda su propia
  lista, así que un nivel nuevo se añade en una sola tabla. Su nota dice qué se
  gana y qué cuesta, porque el jugador elige a ciegas.
- El look de la lente vive en `bodycam.gdshader`: lo fijo (viñeta, grano,
  saturación, dureza del aro, celdas de la cara) es `const`; desde código solo se
  pone lo que cambia en partida (fov, círculo, barrel, pulsos, caras y desvanecido).
- Las caras pixeladas cuestan 0,028 ms por cuadro con 12 enemigos delante. Calcular
  1 de cada 3 cuadros ahorraría un 0,17 % y añadiría 50 ms de retraso: no se baja la
  tasa.
- La cámara del lobby camina en línea recta por el mapa, a la z y la media longitud
  de `MapCatalog.MAPS[].route`. Un mapa nuevo se mide con rayos antes de fijarle su
  línea, y los rayos no ven las mallas abiertas (una valla): hay que mirar la captura.
- El juego no fija tamaño de ventana: el 3D se dibuja al tamaño de la ventana, así
  que a pantalla completa sale a la resolución del jugador.
- En Android el modo de ratón capturado no se mantiene: la pausa es `Player.paused`.

## Deuda

- Pendiente: el editor de controles no se ha probado en un teléfono.

Usa: audio, enemigos, jugador, partida, red
