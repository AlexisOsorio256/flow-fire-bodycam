# Común

Piezas sin dominio propio que usan varios: `Springs` integra muelles
amortiguados (cámara, retroceso, reacciones), `Clips` empareja el nombre de un
clip con el de la animación (`nombre`, `algo/nombre`, `algo|nombre`,
`algo_nombre`), `Impulse` da las dos formas de escalar un impulso
(`scale(impulso, referencia, min, max)` y `push(impulso, factor, min, max)`), el
umbral de muerte súbita (`lethal`) y `Nodes` camina el árbol de un nodo por
fuera (`each`, `paint`, `first`, `aabb`, `verts`): lo que en cuatro ficheros era
el mismo bucle de pila a mano.
Solo entra aquí lo que usan dos dominios o más.

Usa: -

## Trampas medidas

- `AABB.merge` no ignora una caja vacía: mezcla mínimos y máximos a pelo, así que
  `AABB().merge(parte)` mete el origen (0, 0, 0) en la caja. En `Nodes.aabb` la
  primera malla se asigna (`box = part`) y solo las siguientes se mezclan; con el
  ternario al revés el rifle medía 77 mm en vez de 840 y la caja de choque de lo
  que cae al suelo salía inflada hacia el origen.

- Las cinco curvas de «cuánto empuja un tiro» están todas en `Impulse`:
  daño por potencia (`EnemyWounds.power`, referencia 2,77), reacción al hueso
  (`EnemyWounds.kick_for`, 2,6), golpe de cámara (`Player.take`, 2,5), empuje del
  ragdoll (`EnemyRagdoll.topple`, ×5) y empujón a un cadáver (`Enemy.shove`,
  ×3). Se tocan juntas o no se tocan.

- `Impulse.lethal(impulso)` es el único umbral de muerte súbita: 8,0 kg·m/s, por
  encima del rifle de 900 m/s (6,7) y por debajo del .50 AE (9,1). Va por impulso
  y no por un aviso del arma porque el impulso ya viaja en el disparo de red, así
  que la letalidad no tocó el protocolo. Qué zonas matan sí es de cada cuerpo:
  `EnemyWounds.LETHAL_REGIONS` y `Player.LETHAL_ZONES`.

- El oscilador amortiguado vive en `Springs.step(pos, vel, goal, k, c, h)`: lo usan `Springs.scalar`, `WeaponAction` (paso fijo de 0,0025) y `BodyCam` (delta crudo), cada uno con su paso y su objetivo, y con la misma aritmética dan 0 píxeles de diferencia. `PlayerDeath` no es el mismo muelle: es un retardo de primer orden hacia `axis_angle * SPRING / DAMP`, y por eso se queda con su fórmula.
