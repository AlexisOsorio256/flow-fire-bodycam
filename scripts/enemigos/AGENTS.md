# Enemigos

`Enemy` es el cuerpo (movimiento, disparo, impactos, muerte) y avisa `fired`
en cada disparo; `EnemyBrain` decide (patrulla, alerta, combate, cobertura);
`EnemySenses` ve y oye;
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
- El fusil de terceros es `EnemyRifle` (`Rifle3P` en el anclaje de `Gun`); `Enemy.set_weapon` lo monta, `fire_at` tira a 900 m/s y `_drop_gun` lo suelta (3,2 kg). `NetPuppet` hereda: nada duplicado.
- Tiros de fusil en ráfagas de 3-5 (`BURST_RIFLE`); la táctica escala con `skill` pero el recluta maniobra: cubrirse tras 4,5-2 s, memoria 2,5-5 s, carga 30-60 % (`cover_after`, `search_for`, `rush_chance`).

## Deuda

- Pendiente: poses de soldado con rifle (apunta con la pose de pistola; de lado cuela, al hombro no).

Usa: armas, audio, balistica, comun, jugador
Checks: enemigos, ragdoll, sangre, dano, rendimiento
