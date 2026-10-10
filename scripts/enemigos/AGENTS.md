# Enemigos

`Enemy` es el cuerpo (movimiento, disparo, impactos, muerte) y avisa `fired` en
cada disparo; `EnemyBrain` decide (patrulla, alerta, combate, cobertura);
`EnemySenses` ve y oye; `EnemyTrigger` regula las ráfagas; `EnemyWounds` lleva la
vida por zona, el aturdimiento, la cojera, el tumbado y el sangrado. `EnemyModel`
carga `enemy.glb` y sus clips; `HitReact` añade muelles a los huesos en cada
impacto; `EnemyRagdoll` monta las cajas de impacto y la caída; `EnemyBlood` y
`BloodSplats`, la sangre.

Cada zona tiene su reacción animada en `soldier.blend` (`HitChest`, `HitGut`,
`HitBack`, `HitArmL/R`, `HitLegL/R`); el aturdimiento dura lo que la reacción.
Cada tiro al cuerpo quita 50 de vida por potencia (cabeza, 200): dos de 9 mm o
5,56 matan, y un impulso letal (`Impulse.lethal`) mata de uno en cualquier zona.
Quien sobrevive va herido: `CrouchAim` si está quieto y se desangra
(`EnemyWounds.bleed`, 2 por segundo).

## Trampas

- `Enemy` y `NetPuppet` comparten `_assemble`, `_flesh` y `_strides`: el muñeco de
  red solo añade su estado y su envío. `EnemyWounds.kick_for` es la única curva de
  reacción; un muñeco y un enemigo reaccionan igual.
- `EnemyBrain` puede no existir (`NetPuppet` no lo monta): `hear` y `hear_step`
  comprueban `brain != null` en vez de dejar overrides vacíos.
- Las formas del ragdoll se comparten por hueso (`EnemyRagdoll._shapes`): cada
  cuerpo creaba sus 16 formas al aparecer.
- Los recursos de los efectos son estáticos y compartidos (`ParticleProcessMaterial`,
  `QuadMesh`, `ArrayMesh` y su material). Nadie los muta en partida: lo que cambia
  por nodo es `amount_ratio`, la posición y la emisión.
- `obj.set("x", v)` sobre una propiedad que no existe no hace nada ni avisa (la
  vida es `wounds.hp`).
- Un clip nuevo del `.blend` no llega al juego sin `tools/export_soldier.py`,
  reimportar y añadirlo a `EnemyModel.ONCE` o `LOOPING`.
- Las claves de influencia de los constraints van en cada acción.
- Velocidades medidas de la zancada: andar 0,85 m/s, correr 5 m/s.
- El fusil de terceros es `EnemyRifle` (`Rifle3P` en el anclaje de `Gun`);
  `Enemy.fire_at` tira a 900 m/s y `EnemyRifle.drop` suelta el arma al morir
  (fusil 3,2 kg, pistola 0,67 kg). `NetPuppet` hereda: nada duplicado.
- Tiros de fusil en ráfagas de 3-5 (`BURST_RIFLE`). La táctica escala con `skill`,
  pero el recluta maniobra: cubrirse tras 4,5-2 s, memoria 2,5-5 s, carga 30-60 %
  (`cover_after`, `search_for`, `rush_chance`).
- La percepción no es el cuello: `_hostiles()` cuesta 1,85 µs por llamada. Con 12
  cerebros a 8 Hz son 0,18 ms por segundo; la O(N²) es teórica a este tamaño y no
  se toca sin medir.
- Un enemigo tras una cobertura alta puede tener la mano dentro de ella: `fire_at`
  sale desde la cabeza cuando el tramo cabeza→mano choca.
- Medido con `take()`: con zonas de 25 a 60, el 9 mm tardaba 4 tiros en el brazo y
  el .50 AE 2 en el vientre. Cualquier zona nueva se mide antes de subirla.
- Los bots se avisan (`EnemyBrain._call_squad`) al ver a alguien nuevo y al recibir
  un tiro, a 30 m y en su mismo equipo. `report` solo actúa en HOLD o SEARCH: un aviso
  que pisara a quien ya combate lo sacaría de su cobertura. El compañero se para a
  10 m del contacto (`STANDOFF`), no encima: así llegan juntos y no uno a uno.
- Antes de cada tiro, `EnemySenses.friend_in_line` mira la línea desde la mano: si un
  compañero o el jugador (si es aliado) está delante, espera 0,2 s. Sin esto, la bala
  de un bot se paraba en su propia gente sin efecto (`Ballistics`).
- En SEARCH se corre (3,6 m/s) a más de 12 m de la meta y se anda (1,4) al llegar. A
  1,4 siempre, un aliado se quedaba atrás del jugador, que va a 5.

## Deuda

- Pendiente: poses de soldado con rifle (apunta con la pose de pistola; de lado
  cuela, al hombro no).
- Pendiente: flanqueo. Los bots se cubren, se avisan y se paran a 10 m, pero no rodean.

Usa: armas, audio, balistica, comun, jugador
