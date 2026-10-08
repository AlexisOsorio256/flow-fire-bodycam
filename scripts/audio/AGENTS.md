# Audio

`GameAudio` (autoload) reproduce por buses (mundo, sala, armas, ambiente) con
sidechain y compresión; `SOUNDS` es el catálogo de nombres. `Voices` decide
quién habla: radio de aliados y gritos y dolor de enemigos.

Los sonidos grabados salen de Freesound CC0 y de OpenGameArt con `tools/import_sounds.py` (una
línea por sonido: archivo, fuente, tipo de corte); las voces sintetizadas, de
`tools/build_audio.py` (Piper). La mezcla se juzga con números:
`tools/listen.sh` (LUFS, rango, pico y espectrograma).

## Trampas medidas

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

## Deuda

- Pendiente: `Voices` conoce a `Enemy` y `Player`; debería recibir solo posición y equipo.
- Pendiente: `EnemyBrain` pide `shout_fired` al oír un tiro y esa línea no existe (el enemigo investiga en silencio); falta grabarla con `build_audio.py` o quitar la llamada.

Usa: enemigos, jugador
Checks: audio
