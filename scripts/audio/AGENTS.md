# Audio

`GameAudio` (autoload) reproduce por buses (mundo, sala, armas, ambiente) con
sidechain y compresión; `SOUNDS` es el catálogo de nombres y `SHOT_STREAMS` la
única tabla de disparos por arma (pistola, Desert Eagle, fusil, Barrett,
escopeta) con su volumen y su tono: un arma nueva entra en esa tabla, no en una
rama de `play_shot`. `Voices` decide quién habla: radio de aliados y gritos y
dolor de enemigos.

Los sonidos con origen conocido (los de la tabla de
`tools/import_sounds.py`: archivo, fuente, tipo de corte) se regeneran con esa
herramienta, igual que las voces con `build_audio.py` (Piper); los que no
están en la tabla (impacts, pasos, tela, carne) vinieron de importaciones
anteriores y solo viajan en git. La mezcla la
juzga el propietario jugando.

## Trampas medidas

- El equipo aliado no es fijo: `Voices.ally_team` lo escribe `Main` al aparecer el
  jugador, porque en red `my_team()` puede ser 1. Con el 0 clavado, en una partida
  de red la radio sonaba en el equipo contrario y los aliados gritaban.
- Un lambda que captura un nodo imprime «Lambda capture at index 0 was freed» cuando
  el nodo muere antes que el temporizador (`Voices._after` y `_groan_later` lo
  hacen): es ruido de Godot, el callback ya valida el nodo y no se toca.

- La pista de audio de `--write-movie` se salta los buses: no sirve para
  medir la mezcla.
- Las grabaciones recortadas de origen (clipping) se bajan a -6 dB de pico al
  importarlas (tipo `cut`).
- La palanca del M16 suena entre el tap y el cerrojo (3,58-3,80 s del 725397, `rifle_charge.wav`).
- La escopeta sale del 7z de OpenGameArt (Mossberg N_26P): 3 bocinazos (`shot`),
  bomba completa tras el disparo y solo el tiempo de adelante al soltar (el
  doble sonaba a eco).
- Las voces 3D van por un pool con techo (`VOICES_3D`): con 24 cortaba caídas y
  el check de ragdoll lo cazó (esperaba 10 de 12 sonidos); con 64 no corta. La
  sonda `heard()` cuenta reproducciones, no reproductores, así que un pool no
  la engaña.
- Los disparos del .50 AE y del .50 BMG salen de Freesound con filtro **CC0** (`deagle_1..3` 865992,
  160880, 712310; `barrett_1..3` 865990, 737570, 668071), elegidos por medida y no por oído: se
  miró la proporción de energía por debajo de 250 Hz (0,88 y 0,68 frente a 0,1 de un tiro fino) y
  dónde estaba el pico. El `at` de la tabla es el pico más 0,05 s: el detector de comienzo resta
  esos 0,05 s y con un `at` menor la ventana salía vacía y reventaba el importador.
- El Barrett va 6 dB por encima del fusil y con el tono bajado (0,90-0,96): es lo que lo hace sonar
  a .50 sin grabar otra cosa.

## Deuda

- Pendiente: `Voices` conoce a `Enemy` y `Player`; debería recibir solo posición y equipo.

Usa: enemigos, jugador
