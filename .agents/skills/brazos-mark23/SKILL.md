---
name: brazos-mark23
description: Implementa y corrige el viewmodel de brazos y arma Mark 23 (assets/models/mark23_viewmodel.glb) contra la referencia visual, en vueltas de UN cambio con captura, medida, gate y reversión. Úsala cuando el trabajo sea el viewmodel, las manos, la recarga, la inspección o el encuadre del arma.
---

# Brazos Mark 23 — implementar y corregir

La vuelta es la de la skill `correccion-visual`: UN cambio, número antes y después, gate verde,
reversión si no mejora. Aquí sólo va lo propio del viewmodel.

## 1. El activo

`assets/models/mark23_viewmodel.glb` — 2,29 MB en un solo fichero.

| | |
| --- | --- |
| Triángulos | 7.761 en 5 mallas con piel |
| Esqueleto | 54 huesos, 5 dedos por mano |
| Clips | `Reload` 3,767 s · `Shoot` 4,100 s · `Draw` 5,333 s · `Hide` 4,467 s |
| Cargador | malla aparte `mag_Mark23_D_0`, con joint propio que sólo se mueve en `Reload` |
| Caja | 188,48 × 21,34 × 33,50 unidades, origen en `y≈133` |

Está en centímetros y descentrado: **no es canónico**. Antes de montarlo hay que escalarlo a
metros, recentrarlo al origen del arma y nombrar los sockets. Eso es Blender (regla 7): se hace
con un builder en `tools/`, no a mano en la escena.

Trae manos de piel y manos de guante. La referencia lleva guante negro.

## 2. La referencia de los brazos

El vídeo **sí tiene viewmodel**: guantes negros, mangas negras que entran por abajo-derecha,
empuñadura a dos manos, viñeta muy marcada y ojo de pez. El arma se ve entera entre los
segundos 8 y 18.

```
ffmpeg -y -i "docs/refs/recrear esta calidad perceptual. para flowfire bodycam.mp4" \
  -vf "crop=iw:ih*0.86:0:ih*0.06,fps=2" -q:v 2 /tmp/ref/f_%04d.png
```

Compite contra esos fotogramas, no contra `ref1..ref7`: ésos son del escenario.

## 3. La vuelta

1. Captura (abre ventana en `DISPLAY=:0`):
   ```
   SHOT_OUT=captures/loop tools/captura.sh downrange --warmup=70 --total=2
   SHOT_OUT=captures/loop tools/captura.sh reload --warmup=20 --total=14 --stride=3 --time-scale=0.2
   SHOT_OUT=captures/loop tools/captura.sh inspect --warmup=20 --total=14 --stride=3 --time-scale=0.2
   ```
   `downrange` da el encuadre; `reload`/`reload_empty`/`inspect` con `--time-scale` dan la mano
   en movimiento. `hero_normal` no escribe PNG.
2. Mira los PNG con `read_image`, uno por uno, contra un fotograma concreto.
3. Mide: `python3 tools/measure_perceptual.py captures/loop`.
4. Elige UNA desviación, la de más impacto por línea tocada.
5. Escribe el comando y el número esperado **antes** de editar. Sin número, no se edita.
6. Toca lo mínimo: una autoridad por comportamiento (regla 5).
7. `./tools/verificar.sh` verde. Si tocaste render o geometría, `tools/medir.sh base` con
   p50 ≤ 25 ms.
8. Repite la medida del paso 3. Si no mejora, **revierte**.
9. Cierra: `git add -A && git commit -m "brazos: <cambio>"`.

## 4. Lo que muere cuando el Mark 23 entra

| Qué | Por qué |
| --- | --- |
| `tools/build_arms.py` (994 líneas) | su donante no está en el árbol: no es reproducible |
| `assets/models/fps_arms.glb` | sustituido |
| `assets/models/g19_pistol.glb` | el arma va dentro del Mark 23 |
| `shaders/glock_pbr.gdshader` | el Mark 23 trae sus materiales embebidos |
| los `CLIP_*` y las poses procedurales del cargador de `GlockViewmodel` | los clips son autorados |

**No muere** `GlockWeapon._build_cartridge`: es la geometría del cartucho, y el Mark 23 no la
trae.

Los cinco clips actuales duran lo que dura `Glock.gd` (`RELOAD_TOTAL` 2,10 s); los del Mark 23
duran más. Re-cronometrar toca la sensación, y eso no lo decide un agente.

## 5. Árbol de decisión

- **¿La desviación no mueve ningún número?** No es medible: párate y pregunta al dueño.
- **¿El gate se pone rojo?** Has roto algo real: arregla la causa, no el gate.
- **¿El arreglo pide una capa o un sistema nuevo?** Es sobreingeniería (regla 4): busca la
  autoridad que ya existe.
- **¿El clip del Mark 23 y el timeline de `Glock.gd` se contradicen?** Es decisión de
  sensación: párate y pregunta; no la tomes tú.

## 6. Informe de la vuelta (los mismos seis datos)

1. Desviación y fotograma de referencia.
2. Comando de medida.
3. Número antes y después.
4. Fichero:línea y líneas netas.
5. Salida de `./tools/verificar.sh`.
6. Ruta de la captura y si se queda o se revierte.
