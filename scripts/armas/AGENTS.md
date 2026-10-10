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

## Trampas medidas

- Brazo 0,20 m y antebrazo 0,21 m. Alargarlos deformó la manga y costó 1,6 ms
  de GPU: para llegar lejos el clip adelanta el hueso `Body` (hombros, fuera de
  cámara); el rifle lo adelanta (0,02, 0,12, -0,06).
- `FpArms` toma como asiento del cargador el hueso `Mag` del primer fotograma
  de `<Prefijo>Idle`; con el cargador en la mano, `Mag` va fijo a la palma.
- Un rol de sonido vacío (`""`) no suena: el rifle no tiene corredera, su `action_rear` es la palanca (`rifle_charge`).
- Lo validado de la Glock no se mueve para encajar otra arma: si la Glock cambia
  de aspecto o de manos, se rehace.
- El propietario rechazó alzas inventadas (cajas en el rifle) y el aro de la
  escopeta (`SightRear`, 31 mm): la malla salió de `shotgun.blend`, el socket
  queda de referencia y `arma` vigila que no vuelva.
- Vaina 5,56 de 44,7 mm y 6,1 g frente a 9 mm de 19,15 mm y 3,9 g: `Shell.CALIBERS` es la única tabla (masa, largo, radio y punta), `Shell.dims_of` avisa si el calibre no tiene ficha y `RoundMesh` solo dibuja punta si la ficha la trae (el 12ga no la tiene); el `MagRound` del rifle baja a 0,043 m para que la punta no asome.
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
- Con la boca a -6,9° y yaw 3,8° (la cadera del rifle), el cañón de la escopeta
  va hacia la cámara y se pierde por perspectiva: su cadera está en
  `WeaponSpec.shotgun` (`hip_rot` 3°, 18°, -2°) y el tubo se lee.
- La izquierda no llegaba al guardamanos: el brazo mide 0,415 m y la muñeca
  estaba a 0,38 m del hombro, con el guardamanos a 0,6 m. El hueso `Body`
  (raíz; el arma cuelga de `Aim`) avanza 0,10 y 0,15 m en todos los clips
  `Shotgun*` y `IK_Hand_L` (hijo de `Weapon`) va a (0,09; 0,30; -0,17) del rig
  de Blender, con el mismo desplazamiento en cada clip: uno por clip salía 0,45 m.
- La boca de la escopeta estaba 2,2 cm bajo el cañón (socket a ojo, dentro del
  tubo del cargador): la boca se mide sobre los vértices del cañón, no a ojo.
- La mano izquierda de la recarga salta 0,69 m al entrar y 1,7 m al salir: los
  extremos de `ShotgunReload` y `ShotgunReloadEmpty` van a la pose de `Idle`.
- Retroceso del fusil y la escopeta más duro (`WeaponSpec.recoil`, `cam_kick`): más impulso de subida y lateral y menos amortiguación (c 17-18), para que rebote y cueste recuperar la mira al matar. El propietario juzga el tacto jugando.
- En la inspección de la escopeta la izquierda quedaba suelta cuando el arma gira (su IK cuelga de `Weapon`): `ShotgunInspect` fija `IK_Hand_L` en el guardamanos, igual que la recarga, y el brazo sigue al arma.
- La recarga de cartuchos era una copia de la de fusil: el hueso `Mag` recorría 0,6 m (un cargador que la escopeta no tiene) y los cartuchos caían por tiempos sin verse. Ahora cada cue de `shell_cues` es un ciclo de la mano derecha en Blender (`IK_Hand_R` a P en c-4 y a G en c; `Weapon`, `Mag` e `IK_Hand_L` fijos), y `insert_shell` suma uno al tubo. La caja de la escopeta no se oculta; disparar durante la recarga la corta (`cancel_reload`).
- Los casquillos no se veían: salían a la derecha y hacia atrás del ojo, así que a 0,1 s ya estaban fuera de cuadro o detrás de la cámara. `Shell.spawn` los lanza sobre todo a la derecha y arriba, y el latón va al 55 % de metal: al 95 % se leía negro en las salas oscuras.

- El brazo izquierdo de la escopeta quedaba casi estirado (alcance 0,40 m frente a 0,415 m) y salía de frente desde abajo. `ElbowPole` (solo con prefijo `Shotgun`) adelanta 10 cm el hueso `shoulder.L` y dobla el codo hacia fuera y abajo, en espacio de cámara, con la muñeca fija. Es un parche en código sobre los clips horneados. Con 5 cm el codo hacía un quiebro de unos 90° en reposo y al disparar; con 10 cm la curva es limpia en reposo, disparo y recarga.
- La recarga de la escopeta no traía claves de rotación ni de escala para la mano derecha (603 pistas frente a 610 en el reposo): el juego la dejaba en la postura por defecto y no salía en el cuadro. `ShotgunReload` y `ShotgunReloadEmpty` la clavan ahora en el reposo.
- Dispersión de cadera de la escopeta 1,2 (era 2,2): con 2,2 un cartucho solo mataba de un tiro hasta 6 m (31 % a 10 m); con 1,2, un 89 % a 10 m y de dos a tres cartuchos a larga. Medido con la fórmula de `WeaponAim` y 9 perdigones de 60 al pecho.
- Pegado a una cobertura el cañón entra en ella: la bala nacía dentro y se paraba en el primer milímetro, con el impacto flotando delante del arma. `WeaponAim.origin_of` sale desde la cámara cuando el tramo cámara→cañón choca.

## Deuda

- Pendiente: la recarga por cartuchos de la escopeta no se ha probado en un teléfono.
- Pendiente: la mano derecha de la recarga va fija en el agarre (base funcional); cargar por abajo, como el AR15, es el siguiente pulido sobre esa base. Los tiempos de cartucho viven en `WeaponSpec.shells` y la mano ya no los sigue.
- Pendiente: bajar el arma en la cadera (`hip_pos`) saca la mano derecha del cuadro; decidir antes de tocarlo.
- Pendiente: el brazo izquierdo de la escopeta es un parche en `ElbowPole`; la pose de verdad está en `ShotgunIdle`, `ShotgunFire` y `ShotgunReload` de `fparms.blend`. Rehacer esos clips y quitar el parche.

Usa: audio, balistica, comun, enemigos, jugador
