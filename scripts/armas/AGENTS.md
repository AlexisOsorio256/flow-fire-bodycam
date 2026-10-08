# Armas

Lo que el jugador lleva en las manos.

`Loadout` lleva las armas de `WeaponSpec.all()` y cambia entre ellas (1, 2, 3,
Q, rueda, botón táctil). Cada arma es un `Firearm`: gatillo, corchete, recarga e
inspección, sin un solo valor propio de un arma; todo sale de su `WeaponSpec`
(balística, cadencia, tiempos `times`, sonidos `sounds`, retroceso `recoil`).
`WeaponSequence` arma las secuencias de recarga, inspección y desenfunde; las
armas de cartuchos (`spec.shells`, la escopeta) recargan uno a uno y no sueltan
cargador. `Viewmodel` coloca arma y brazos ante la cámara y alinea las miras.
`FpArms` monta `fps_arms.glb`, toca los clips con el prefijo del arma y lee del
clip cuándo sale y entra el cargador (hueso `Mag`) y cuándo va y vuelve el
cerrojo (hueso `Slide`). `WeaponModel` es la base de los modelos: piezas y
sockets.

## Añadir un arma

1. `blender/<arma>.blend` por piezas y `tools/export_weapon.py`.
2. En `fparms.blend`: vista previa colgada del hueso `Weapon`, un vacío
   `<Prefijo>Mount` en la misma posición y los clips `<Prefijo>Idle`, `Aim`,
   `Fire`, `Reload`, `ReloadEmpty`, `Inspect`, `Equip` y `Trigger` a mano.
3. `<Arma>Weapon.gd` hereda de `WeaponModel`; su ficha en `WeaponSpec` y una
   línea en `WeaponSpec.all()`.
4. Sus checks en `tools/checks/arma.txt`: sale, dispara, recarga, miras.

## Trampas medidas

- Brazo 0,20 m y antebrazo 0,21 m. Alargarlos deformó la manga y costó 1,6 ms
  de GPU: para llegar lejos el clip adelanta el hueso `Body` (hombros, fuera de
  cámara); el rifle lo adelanta (0,02, 0,12, -0,06).
- `FpArms` toma como asiento del cargador el hueso `Mag` del primer fotograma
  de `<Prefijo>Idle`; con el cargador en la mano, `Mag` va fijo a la palma.
- Un rol de sonido vacío (`""`) no suena: el rifle no tiene corredera, su `action_rear` es la palanca (`rifle_charge`).
- Lo validado de la Glock no se mueve para encajar otra arma: `check.py --ver`
  antes y después debe dar 0 píxeles de diferencia.
- El propietario rechazó alzas inventadas (cajas en el rifle) y el aro de la
  escopeta (`SightRear`, 31 mm): la malla salió de `shotgun.blend`, el socket
  queda de referencia y `arma` vigila que no vuelva.
- Vaina 5,56 de 44,7 mm y 6,1 g frente a 9 mm de 19,15 mm y 3,9 g (`Shell.CALIBERS`, `RoundMesh` por calibre); el `MagRound` del rifle baja a 0,043 m para que la punta no asome.
- La palanca se tira en `RifleInspect` 80-94 (45 mm, la mano ya la abrazaba); `RifleEquip` es solo hombro y `timing_errors` no le pide corredera al rifle.
- El impulso de `WeaponAction` es fijo (6,5) con física amortiguada: con la
  bomba de 85 mm no llegaba atrás; `cycle()` lo escala por `travel / TRAVEL_REF`.
- Con ciclo lento el alimentar cae después de pedir la recarga y entra la rama
  vacía: la táctica fija `chamber` a 1; la vacía deja 5 en tubo + 1 en recámara.
- La escopeta salía de pie (cañón 80-90° abajo): la malla iba a -Z de Blender y
  los sockets estaban bien. `arma` mide la malla; un socket pasa aunque la malla esté mal.
- La escopeta estrenó clips `Shotgun*` (mano en la bomba, cartuchos por la
  recarga) y `ShotgunMount` calcado del rifle; su vista previa `Shotgun_*` vive
  en `fparms.blend` (`hide_render`).
- Tumbada, la boca queda a -6,9° en cadera como el rifle: la empuñadura cae
  donde la del rifle (9,5 cm) y la izquierda ya sujeta la bomba.

## Deuda

- Pendiente: decidir si la escopeta en cadera va a nivel exacto (-6,9°), ya con la mano en la bomba.
- Pendiente: la recarga por cartuchos de la escopeta no se ha probado en un teléfono.

Usa: audio, balistica, comun, enemigos, jugador
Checks: arma, animacion, municion, pantalla, audio, rendimiento
