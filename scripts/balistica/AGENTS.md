# Balística

Cada bala es un proyectil con caída, arrastre, penetración y rebote
(`Ballistics`, autoload). Los materiales del mapa llevan su superficie como
metadato (`tools/factory_import.gd`); `ImpactProfiles.SURFACES` es la única tabla
por superficie (cuánto frena y cómo se ve el impacto) y `ShapeExit` mide el grosor
que atraviesa. Una bala `harmless` (las de otros jugadores en red) pinta impactos
pero no hiere: el daño lo decide quien dispara. `ImpactFX`, `FxPools` y
`BulletHoles` son los efectos; `DroppedProp`, lo que cae al suelo.

El impulso de la bala (masa × velocidad) es su potencia: `EnemyWounds.power` escala
el daño hasta ×1,5. El proyectil lleva su ficha (`Ballistics.fire` recibe `shot`):
masa, arrastre y penetración salen del arma que dispara; lo que no declara se queda
con lo de siempre (7,45 g y 0,00142).

## Trampas

- `ShapeExit` solo conoce caja (convexo) y esfera envolvente: el importador de
  mapas (`factory_import.gd`) solo produce cascos convexos. Un colisionador
  penetrable con otra forma para la bala sin avisar.
- Un cuerpo del mapa sin superficie conocida es un `push_error`: todo colisionador
  necesita su prefijo en `factory_import.gd`.
- El cristal (`glass`) es penetrable con `thin_shell` de 4 mm: la bala lo cruza y
  deja agujero; el cuerpo no lo atraviesa.
- Las cajas de impacto de los enemigos son los huesos del ragdoll y siguen la
  animación sin retraso. Si una bala «no pega», mira la reacción, no la caja.
- La escopeta tira 9 perdigones de 12 (`pellets`), cada uno con daño de zona entero.
- Las vainas .50 BMG son torneadas (`Shell._turned`) solo cuando la ficha del
  calibre trae `neck_rad`; los calibres viejos siguen con su cilindro.
- El CCD de los casquillos se apaga en el primer bote (`Shell._on_body_entered`):
  con `continuous_cd` fijo, 60 casquillos sueltos cuestan más física.
- De `SURFACES` solo entran las superficies que un prefijo de `factory_import.gd`
  reparte. Las que nadie nombra costaban nodos de partículas y máscaras al arrancar.
- Las máscaras de agujero se cuecen en una tabla de forma compartida y salen con
  `Image.create_from_data`. Con `set_pixel` por perfil, el arranque costaba
  157 ms en todos los aparatos.
- Un agujero es un `MultiMesh` por colisionador: el orden de mezcla de las
  instancias transparentes cambia si se solapan.
- `ImpactFX` guarda el anfitrión de cada humo sin tipo y lo valida antes de usarlo:
  si se libera antes que el humo, `_process` falla cada cuadro y la entrada no se
  borra nunca.

Usa: armas, audio, enemigos, jugador
