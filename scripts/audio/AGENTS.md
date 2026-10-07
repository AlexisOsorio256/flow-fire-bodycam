# Audio

`GameAudio` (autoload) reproduce por buses (mundo, sala, armas, ambiente) con
sidechain y compresión; `SOUNDS` es el catálogo de nombres. `Voices` decide
quién habla: radio de aliados y gritos y dolor de enemigos.

Los sonidos grabados salen de Freesound CC0 con `tools/import_sounds.py` (una
línea por sonido: archivo, id, tipo de corte); las voces sintetizadas, de
`tools/build_audio.py` (Piper). La mezcla se juzga con números:
`tools/listen.sh` (LUFS, rango, pico y espectrograma).

## Trampas medidas

- La pista de audio de `--write-movie` se salta los buses: no sirve para
  medir la mezcla.
- Las grabaciones recortadas de origen (clipping) se bajan a -6 dB de pico al
  importarlas (tipo `cut`).

## Deuda

- Pendiente: `Voices` conoce a `Enemy` y `Player`; debería recibir solo posición y equipo.

Usa: enemigos, jugador
Checks: audio
