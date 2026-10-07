# Enemigos

`Enemy` es el cuerpo (movimiento, disparo, impactos, muerte); `EnemyBrain`
decide (patrulla, alerta, combate, cobertura); `EnemySenses` ve y oye;
`EnemyTrigger` regula las ráfagas; `EnemyWounds` lleva la vida por zona, el
aturdimiento y la cojera. `EnemyModel` carga `enemy.glb` y sus clips;
`HitReact` añade muelles a los huesos en cada impacto; `EnemyRagdoll` monta las
cajas de impacto y la caída; `EnemyBlood` y `BloodSplats`, la sangre.

Cada zona tiene su reacción animada en `soldier.blend` (`HitChest`, `HitGut`,
`HitBack`, `HitArmL/R`, `HitLegL/R`); el aturdimiento dura lo que la reacción.
Los clips de torso y pierna acaban en la pose de `CrouchAim` porque todo tiro
al torso deja herido.

## Trampas medidas

- `obj.set("x", v)` sobre una propiedad que no existe no hace nada ni avisa
  (la vida es `wounds.hp`).
- Un clip nuevo en el `.blend` no llega al juego sin exportar
  (`tools/export_soldier.py`), reimportar y añadirlo a `EnemyModel.ONCE` o
  `LOOPING`.
- Las claves de influencia de los constraints van en cada acción.
- Velocidades medidas de la zancada: andar 0,85 m/s, correr 5 m/s.

## Deuda

- Pendiente: los enemigos solo llevan pistola.

Usa: armas, audio, balistica, comun, jugador
Checks: enemigos, ragdoll, sangre, dano, rendimiento
