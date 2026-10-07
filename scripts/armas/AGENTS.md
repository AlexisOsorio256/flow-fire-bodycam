# Armas

Lo que el jugador lleva en las manos.

`Loadout` lleva las armas de `WeaponSpec.all()` y cambia entre ellas (1, 2, Q,
rueda, botón táctil). Cada arma es un `Firearm`: gatillo, cargador, recarga e
inspección, sin un solo valor propio de un arma; todo sale de su `WeaponSpec`
(balística, cadencia, tiempos de mano `times`, sonidos por función `sounds`,
retroceso `recoil` y golpe de cámara). `Viewmodel` coloca arma y brazos ante la
cámara y alinea las miras al apuntar. `FpArms` monta `fps_arms.glb`, toca los
clips con el prefijo del arma y lee del clip cuándo sale y entra el cargador
(hueso `Mag`) y cuándo va y vuelve el cerrojo (hueso `Slide`). `WeaponModel` es
la base de los modelos (`GlockWeapon`, `RifleWeapon`): piezas y sockets.

## Añadir un arma

1. `blender/<arma>.blend` por piezas y `tools/export_weapon.py`.
2. En `fparms.blend`: copia de vista previa colgada del hueso `Weapon`, un vacío
   `<Prefijo>Mount` en la misma posición, y los clips `<Prefijo>Idle`, `Aim`,
   `Fire`, `Reload`, `ReloadEmpty`, `Inspect`, `Equip` y `Trigger`, animados a
   mano para esa arma.
3. `<Arma>Weapon.gd` hereda de `WeaponModel`; su ficha en `WeaponSpec` y una
   línea en `WeaponSpec.all()`.
4. Sus checks en `tools/checks/arma.txt`: sale, dispara, recarga, miras.

## Trampas medidas

- Brazo 0,20 m y antebrazo 0,21 m. Alargarlos deformó la manga y costó 1,6 ms
  de GPU: para llegar lejos el clip adelanta el hueso `Body` (hombros, fuera de
  cámara); el rifle lo adelanta (0,02, 0,12, -0,06).
- `FpArms` toma como asiento del cargador el hueso `Mag` del primer fotograma
  de `<Prefijo>Idle`; con el cargador en la mano, `Mag` va fijo a la palma.
- Un rol de sonido vacío (`""`) no suena: el rifle no tiene corredera.
- Lo validado de la Glock no se mueve para encajar otra arma: `check.py --ver`
  antes y después debe dar 0 píxeles de diferencia.
- El propietario rechazó una alza de rifle hecha con cajas: nada de piezas
  inventadas que parezcan falsas.

## Deuda

- Pendiente: el rifle expulsa vainas de 9 mm (`Shell` no sabe de calibres).
- Pendiente: sin animación ni sonido de la palanca de carga del rifle.
- Pendiente: `Firearm` roza las 300 líneas; la recarga y la inspección pueden salir a su propio módulo.

Usa: audio, balistica, comun, enemigos, jugador
Checks: arma, animacion, municion, pantalla, audio, rendimiento
