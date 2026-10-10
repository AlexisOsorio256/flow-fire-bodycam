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
pecho). El proyectil lleva su ficha dentro (`Ballistics.fire` la recibe en
`shot`): masa, arrastre y penetración salen del arma que dispara, y lo que no
declara se queda con lo de siempre (7,45 g y 0,00142), así que las armas ya
validadas no se mueven. Con eso un .50 AE (19,4 g a 470 m/s, 9,1 kg·m/s) pasa el
umbral de `Impulse.lethal` y un .50 BMG (42,7 g a 853 m/s, 36,4) además vuela
plano (`drag` 0,00012) y atraviesa muro (`punch` 8).

## Trampas medidas

- `ShapeExit` no sabía de cascos convexos (todo el mapa): se resuelve por AABB local; sin salida la bala se para sin avisar. Solo quedan caja (convexo) y esfera envolvente: el importador de mapas (`factory_import.gd`) solo produce cascos convexos, así que las ramas de `BoxShape3D`, `CylinderShape3D` y `SphereShape3D` se quitaron. Si un colisionador penetrable entra con una de esas formas, la bala se parará en él sin atravesarlo.

- Una colisión sin superficie conocida es un error a la vista
  (`push_error`): todo cuerpo del mapa necesita su prefijo en
  `factory_import.gd`.
- El cristal de los huecos (`glass`) es penetrable con `thin_shell` de 4 mm: la bala lo cruza y deja agujero, el cuerpo no lo atraviesa.
- Las cajas de impacto de los enemigos son los huesos del ragdoll y siguen la
  animación sin retraso (medido, 0 mm): si «no pega», mira la reacción, no la
  caja.
- La escopeta tira 9 perdigones de 12 (`pellets`, vaina 12ga de 70 mm y 10 g)
  con daño de zona entero cada uno: de cerca matan, de lejos un perdigón deja
  moribundo.
- Los casquillos .50 BMG son la primera vaina torneada del juego (cuerpo, hombro
  y cuello, `Shell._turned`): las tapas de boca y culote iban con el giro al
  revés y la vaina se veía hueca por la boca. Solo se usa cuando la ficha del
  calibre trae `neck_rad`; los calibres viejos siguen con su cilindro.
- 60 casquillos .50 BMG sueltos cuestan 0,48 ms de física, y dejarlos con
  `continuous_cd` fijo añadía 0,07 ms: el CCD se apaga en el primer bote
  (`Shell._on_body_entered`). El golpe de la vaina también baja de tono con el
  largo del casquillo (`Shell.ring`), que es lo que hace que un .50 suene a .50.
- La vaina de 20 mm de culote no cabe en un colisionador de cilindro del rifle:
  el `.50` es `CylinderShape3D` de radio 10,2 mm y largo 99,3 mm, así que rueda y
  bota como un objeto grande, no como un grano de arroz.
- Las máscaras de agujero se cuecen en una tabla de forma compartida (el ruido
  no depende del perfil) y salen con `Image.create_from_data`: 156 → 13 ms de
  arranque, con 0 píxeles de diferencia en las máscaras. Con `set_pixel` por
  perfil,
  el autoload costaba 157 ms antes del lobby en todos los aparatos.
- De `SURFACES` solo entran las superficies que un prefijo de
  `factory_import.gd` reparte: las que nadie nombra (como `gypsum`,
  `aluminum`, `ground`) costaban 36 nodos de partículas y 3 máscaras al
  arrancar sin que ninguna bala las viera nunca.
- Los agujeros son un `MultiMesh` por colisionador (32 por cuerpo, como antes,
  y ya no hay 192 nodos): 32 agujeros visibles pasan de 32 dibujos a 1 (medido,
  228 → 197 dibujos con 60 agujeros). Sin solaparse la imagen es idéntica; si
  se solapan, el orden de mezcla de las instancias transparentes cambia unas
  decenas de píxeles (el mismo agujero, mezclado en otro orden).

- `ImpactFX` guarda el anfitrión de cada humo: si se libera antes que el humo, `_process` falla cada fotograma y la entrada nunca se borra. El anfitrión se guarda sin tipo y se valida antes de usarlo.

Usa: armas, audio, enemigos, jugador
