# Audio

`GameAudio` (autoload) reproduce por buses (mundo, sala, armas, ambiente) con
sidechain y compresión; `SOUNDS` es el catálogo de nombres y `SHOT_STREAMS` la única
tabla de disparos por arma (pistola, Desert Eagle, fusil, Barrett, escopeta) con su
volumen y su tono: un arma nueva entra en esa tabla, no en una rama de `play_shot`.
`Voices` decide quién habla: radio de aliados y gritos y dolor de enemigos.

Los sonidos con origen conocido (la tabla de `tools/import_sounds.py`: archivo,
fuente, tipo de corte) se regeneran con esa herramienta, igual que las voces con
`build_audio.py` (Piper). Los que no están en la tabla (impactos, pasos, tela, carne)
vinieron de importaciones anteriores y solo viajan en git. La mezcla la juzga el
propietario jugando.

## Trampas

- El equipo aliado no es fijo: `Voices.ally_team` lo escribe `Main` al aparecer el
  jugador, porque en red `my_team()` puede ser 1. Con el 0 clavado, la radio sonaba
  en el equipo contrario.
- Un lambda que captura un nodo imprime «Lambda capture at index 0 was freed» cuando
  el nodo muere antes que el temporizador. Es ruido de Godot: el callback ya valida
  el nodo.
- La pista de audio de `--write-movie` se salta los buses: no sirve para medir la
  mezcla.
- Las grabaciones recortadas de origen (clipping) se bajan a -6 dB de pico al
  importarlas (tipo `cut`).
- El `at` de la tabla es el pico más 0,05 s: el detector de comienzo resta esos
  0,05 s y, con un `at` menor, la ventana sale vacía y el importador revienta.
- Las voces 3D van por un pool con techo (`VOICES_3D` = 64): con 24 cortaba caídas.
  La sonda `heard()` cuenta reproducciones, no reproductores, así que el pool no la
  engaña.
- Los disparos de .50 AE y .50 BMG se eligieron por medida (proporción de energía
  por debajo de 250 Hz y pico), no por oído. El Barrett va 6 dB por encima del fusil
  y con el tono bajado (0,90–0,96): es lo que lo hace sonar a .50.

## Deuda

- Pendiente: `Voices` conoce a `Enemy` y `Player`; debería recibir solo posición y
  equipo.

Usa: enemigos, jugador
