# Balística

Cada bala es un proyectil con caída, arrastre, penetración y rebote
(`Ballistics`, autoload). Los materiales del mapa llevan su superficie como
metadato (`tools/factory_import.gd`); `MATERIALS` dice cuánto frena cada uno y
`ShapeExit` mide el grosor que atraviesa. Una bala `harmless` (las de otros
jugadores en red) pinta impactos pero no hiere: el daño lo decide quien
dispara. `ImpactFX`, `FxPools`, `BulletHoles` e `ImpactProfiles` son los
efectos; `DroppedProp`, lo que cae al suelo (cargadores, armas).

El impulso de la bala (masa × velocidad) es su potencia: `EnemyWounds.power`
escala el daño hasta ×1,5 (el rifle a 900 m/s deja a 10 de vida de un tiro al
pecho).

## Trampas medidas

- `ShapeExit` no sabía de cascos convexos (todo el mapa): se resuelve por AABB local; sin salida la bala se para sin avisar.

- Una colisión sin superficie conocida es un error a la vista
  (`push_error`): todo cuerpo del mapa necesita su prefijo en
  `factory_import.gd`.
- Las cajas de impacto de los enemigos son los huesos del ragdoll y siguen la
  animación sin retraso (medido, 0 mm): si «no pega», mira la reacción, no la
  caja.

Usa: armas, audio, enemigos, jugador
Checks: arma, sangre, ragdoll, enemigos, rendimiento
