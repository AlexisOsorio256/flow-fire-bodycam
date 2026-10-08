# Común

Piezas sin dominio propio que usan varios: `Springs` integra muelles
amortiguados (cámara, retroceso, reacciones), `Clips` empareja el nombre de un
clip con el de la animación (`nombre`, `algo/nombre`, `algo|nombre`,
`algo_nombre`) e `Impulse` da las dos formas de escalar un impulso
(`scale(impulso, referencia, min, max)` y `push(impulso, factor, min, max)`).
Solo entra aquí lo que usan dos dominios o más.

Usa: -

## Trampas medidas

- Las cinco curvas de «cuánto empuja un tiro» están todas en `Impulse`:
  daño por potencia (`EnemyWounds.power`, referencia 2,77), reacción al hueso
  (`EnemyWounds.kick`, 2,6), golpe de cámara (`Player.take`, 2,5), empuje del
  ragdoll (`EnemyRagdoll.topple`, ×5) y empujón a un cadáver (`Enemy.shove`,
  ×3). Se tocan juntas o no se tocan.

- El oscilador amortiguado vive en `Springs.step(pos, vel, goal, k, c, h)`: lo usan `Springs.scalar`, `WeaponAction` (paso fijo de 0,0025) y `BodyCam` (delta crudo), cada uno con su paso y su objetivo, y con la misma aritmética dan 0 píxeles de diferencia. `PlayerDeath` no es el mismo muelle: es un retardo de primer orden hacia `axis_angle * SPRING / DAMP`, y por eso se queda con su fórmula.
