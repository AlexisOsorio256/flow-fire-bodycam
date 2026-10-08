# Enemigos

`Enemy` es el cuerpo (movimiento, disparo, impactos, muerte) y avisa `fired`
en cada disparo; `EnemyBrain` decide (patrulla, alerta, combate, cobertura);
`EnemySenses` ve y oye;
`EnemyTrigger` regula las ráfagas; `EnemyWounds` lleva la vida por zona, el
aturdimiento, la cojera, el tumbado y el sangrado. `EnemyModel` carga `enemy.glb` y sus clips;
`HitReact` añade muelles a los huesos en cada impacto; `EnemyRagdoll` monta las
cajas de impacto y la caída; `EnemyBlood` y `BloodSplats`, la sangre.

Cada zona tiene su reacción animada en `soldier.blend` (`HitChest`, `HitGut`,
`HitBack`, `HitArmL/R`, `HitLegL/R`); el aturdimiento dura lo que la reacción.
Quien sobrevive al tiro queda tumbado (`EnemyWounds.downed`, sin cerebro) en
`CrouchAim` y se desangra (`EnemyWounds.bleed`): el siguiente tiro lo remata
y nadie se levanta.

## Trampas medidas

- `obj.set("x", v)` sobre una propiedad que no existe no hace nada ni avisa
  (la vida es `wounds.hp`).
- Un clip nuevo en el `.blend` no llega al juego sin exportar
  (`tools/export_soldier.py`), reimportar y añadirlo a `EnemyModel.ONCE` o
  `LOOPING`.
- Las claves de influencia de los constraints van en cada acción.
- Velocidades medidas de la zancada: andar 0,85 m/s, correr 5 m/s.
- El fusil de terceros es `EnemyRifle` (`Rifle3P` en el anclaje de `Gun`); `Enemy.set_weapon` lo monta, `Enemy.fire_at` tira a 900 m/s y `EnemyRifle.drop` suelta el arma al morir (fusil 3,2 kg, pistola 0,67 kg). `NetPuppet` hereda: nada duplicado.
- Tiros de fusil en ráfagas de 3-5 (`BURST_RIFLE`); la táctica escala con `skill` pero el recluta maniobra: cubrirse tras 4,5-2 s, memoria 2,5-5 s, carga 30-60 % (`cover_after`, `search_for`, `rush_chance`).
- La percepción no es el cuello (medido): `_hostiles()` cuesta 1,85 µs por llamada (grupo `combatant` + `alive()`) y `EnemySenses.clear` 1,3 µs; con 12 cerebros a 8 Hz son 0,18 ms por segundo, así que la O(N²) de la auditoría es teórica a este tamaño y no se toca. De `clear` solo se quitó la query nueva por mirada: el acceso tipado con `actor as Enemy` salió más caro que el `call()` que sustituía.
- Los recursos de los efectos son estáticos y compartidos: un `ParticleProcessMaterial`, un `QuadMesh`, un `ArrayMesh` y su material para todos los cuerpos, más la mancha de `EnemyBlood` y el material de `ContactBlob` que ya lo eran. Antes cada enemigo creaba los suyos (unos 5 recursos y 2 texturas por cuerpo). Compartirlos es seguro porque nadie los muta en partida: lo que cambia por nodo es `amount_ratio`, la posición y la emisión; el `ArrayMesh` se cachea por los parámetros de `add()`.

## Deuda

- Pendiente: poses de soldado con rifle (apunta con la pose de pistola; de lado cuela, al hombro no).

Usa: armas, audio, balistica, comun, jugador
Checks: enemigos, ragdoll, sangre, dano, rendimiento
