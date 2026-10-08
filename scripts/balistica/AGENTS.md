# Balística

Cada bala es un proyectil con caída, arrastre, penetración y rebote
(`Ballistics`, autoload). Los materiales del mapa llevan su superficie como
metadato (`tools/factory_import.gd`); `ImpactProfiles.SURFACES` es la única
tabla por superficie (cuánto frena y cómo se ve el impacto) y `ShapeExit` mide
el grosor que atraviesa. Una bala `harmless` (las de otros jugadores en red)
pinta impactos pero no hiere: el daño lo decide quien dispara. `ImpactFX`,
`FxPools` y `BulletHoles` son los efectos; `DroppedProp`, lo que cae al suelo
(cargadores, armas).

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
- La escopeta tira 9 perdigones de 12 (`pellets`, vaina 12ga de 70 mm y 10 g)
  con daño de zona entero cada uno: de cerca matan, de lejos un perdigón deja
  moribundo.
- Las máscaras de agujero se cuecen en una tabla de forma compartida (el ruido
  no depende del perfil) y salen con `Image.create_from_data`: 156 → 13 ms de
  arranque, con 0 píxeles de diferencia en las 7. Con `set_pixel` por perfil,
  el autoload costaba 157 ms antes del lobby en todos los aparatos.

Usa: armas, audio, enemigos, jugador
Checks: arma, sangre, ragdoll, enemigos, rendimiento
