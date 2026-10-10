# Común

Piezas sin dominio propio que usan varios: `Springs` integra muelles amortiguados
(cámara, retroceso, reacciones), `Clips` empareja el nombre de un clip con el de la
animación (`nombre`, `algo/nombre`, `algo|nombre`, `algo_nombre`), `Impulse` da las
dos formas de escalar un impulso (`scale(impulso, referencia, min, max)` y
`push(impulso, factor, min, max)`), el umbral de muerte súbita (`lethal`) y `Nodes`
camina el árbol de un nodo por fuera (`each`, `paint`, `first`, `aabb`, `verts`).
Solo entra aquí lo que usan dos dominios o más.

Usa: -

## Trampas

- `AABB.merge` no ignora una caja vacía: `AABB().merge(parte)` mete el origen en la
  caja. En `Nodes.aabb` la primera malla se asigna y solo las siguientes se mezclan.
- Las cinco curvas de «cuánto empuja un tiro» están todas en `Impulse`: daño por
  potencia (`EnemyWounds.power`), reacción al hueso (`EnemyWounds.kick_for`), golpe
  de cámara (`Player.take`), empuje del ragdoll (`EnemyRagdoll.topple`) y empujón a
  un cadáver (`Enemy.shove`). Se tocan juntas o no se tocan.
- `Impulse.lethal(impulso)` es el único umbral de muerte súbita (8,0 kg·m/s): por
  encima del rifle de 900 m/s y por debajo del .50 AE. Va por impulso para que la
  letalidad no toque el protocolo de red. Qué zonas matan es de cada cuerpo: el
  enemigo muere de cualquiera (`EnemyWounds.take`); el jugador, de cabeza o pecho
  (`Player.LETHAL_ZONES`).
- El oscilador amortiguado vive en `Springs.step(pos, vel, goal, k, c, h)`. Cada
  usuario pone su paso y su objetivo. `PlayerDeath` no es el mismo muelle: es un
  retardo de primer orden, y por eso conserva su fórmula.
