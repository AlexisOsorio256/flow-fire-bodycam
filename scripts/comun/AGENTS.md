# Común

Piezas sin dominio propio que usan varios: `Springs` integra muelles
amortiguados (cámara, retroceso, reacciones). Solo entra aquí lo que usan dos
dominios o más.

Usa: -

## Trampas medidas

- El oscilador amortiguado vive en `Springs.step(pos, vel, goal, k, c, h)`: lo usan `Springs.scalar`, `WeaponAction` (paso fijo de 0,0025) y `BodyCam` (delta crudo), cada uno con su paso y su objetivo, y con la misma aritmética dan 0 píxeles de diferencia. `PlayerDeath` no es el mismo muelle: es un retardo de primer orden hacia `axis_angle * SPRING / DAMP`, y por eso se queda con su fórmula.
