# Armas

Lo que el jugador lleva en las manos.

`Loadout` lleva las armas de `WeaponSpec.all()` y cambia entre ellas (1, 2, 3,
Q, rueda, botón táctil). Cada arma es un `Firearm`: gatillo, corchete, recarga e
inspección, sin un solo valor propio de un arma; todo sale de su `WeaponSpec`
(balística, cadencia, tiempos `times`, sonidos `sounds`, retroceso `recoil`).
`WeaponSequence` arma las secuencias de recarga, inspección y desenfunde; las
armas de cartuchos (`spec.shells`, la escopeta) recargan uno a uno y no sueltan
cargador. `WeaponModel` es la base de los modelos: piezas, sockets y el gatillo
(`set_trigger` y `TRIGGER_TRAVEL` son suyos; la Glock lo reescribe porque su
gatillo gira en vez de correr). `Viewmodel` coloca arma y brazos ante la cámara
y alinea las miras.
`FpArms` monta `fps_arms.glb`, toca los clips con el prefijo del arma y lee del
clip cuándo sale y entra el cargador (hueso `Mag`) y cuándo va y vuelve el
cerrojo (hueso `Slide`). Las piezas y los sockets de cada arma los mide su
propio `<Arma>Weapon.gd`; `Nodes.aabb` mide la malla entera (el largo de la
Glock se comprueba contra 174 mm).

## Añadir un arma

1. `blender/<arma>.blend` por piezas y `tools/export_weapon.py`.
2. En `fparms.blend`: vista previa colgada del hueso `Weapon`, un vacío
   `<Prefijo>Mount` en la misma posición y los clips `<Prefijo>Idle`, `Aim`,
   `Fire`, `Reload`, `ReloadEmpty`, `Inspect`, `Equip` y `Trigger` a mano.
3. `<Arma>Weapon.gd` hereda de `WeaponModel`; su ficha en `WeaponSpec` y una
   línea en `WeaponSpec.all()`.

## Trampas medidas

- La dispersión sube una vez por disparo, no por perdigón: `WeaponAim.bloom_per_shot`
  lo llama `Firearm._fire` antes del bucle de `pellets`. Con el aumento dentro de
  `bore`, los perdigones 5 a 9 de la escopeta salían con 0,028 más de sigma que el
  primero y la dispersión medida de `hip_spread` ya no era la que se ajustó.
- La mira se guarda como deseo (`Firearm.want_aim`): `_process` la enciende cuando
  no hay recarga, inspección ni desenfunde en curso. Con el pestillo de antes,
  apuntar durante una recarga dejaba al jugador sin mira hasta soltar y volver a
  pulsar el botón.
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
- El arma declara su proyectil en `WeaponSpec.ballistic()` (masa, arrastre y penetración); un campo a cero quiere decir «la de siempre» (7,45 g y 0,00142 en `Ballistics`), así que la Glock, el fusil y la escopeta no cambian ni un número. `Firearm` la manda en cada `Ballistics.fire`.
- Los calibres nuevos (`.50 AE` de 12,7×33 y `.50 BMG` de 12,7×99) entran en `Shell.CALIBERS` con sus medidas y su masa reales: el BMG es el único con `neck_rad`, `shoulder_len` y `nose_len`, y su culote de 10,2 mm de radio es también el del colisionador, así que la vaina rueda como el objeto grande que es. `RoundMesh` dibuja la bala del cargador con la misma vaina (`Shell.case_of`), así que un calibre nuevo sale igual en la mano y en el suelo.
- La Desert Eagle trae sus ocho clips `Deagle*` en `fparms.blend` (copia de los de pistola, `blender/desert_eagle_clips.py`), su ancla `DeagleMount` y su vista previa `Deagle_*`. Lo que la colocaba mal no era el agarre sino el prefijo: **con el prefijo vacío el arma la pone el viewmodel (`_hold_pose` sale antes de tiempo) y solo la Glock está hecha para eso**; con prefijo propio se cuelga del hueso `Weapon` y la mano la sostiene.
- El origen de un arma descargada se ancla al asa de la Glock (`WEB_GLOCK` en `blender/desert_eagle.py`), no al ánima: el asa de la Glock queda 3,1 cm bajo su origen y 1,7 cm delante, y con el origen en el ánima de la Desert Eagle la mano acababa en la corredera.
- La palanca se tira en `RifleInspect` 80-94 (45 mm, la mano ya la abrazaba); `RifleEquip` es solo hombro: el rifle no pide corredera al desenfundar.
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
- El salto no tiene clips: `Firearm.set_motion` lleva la velocidad vertical hasta
  `Viewmodel`, que hunde el arma al subir y la deja flotar al caer, y
  `WeaponRecoil.kick_land` la golpea al aterrizar. Así el arma acompaña al cuerpo
  con cualquier arma del loadout y sin tocar Blender.
- Los casquillos no se veían: salían a la derecha y hacia atrás del ojo, así que a 0,1 s ya estaban fuera de cuadro o detrás de la cámara. `Shell.spawn` los lanza sobre todo a la derecha y arriba, y el latón va al 55 % de metal: al 95 % se leía negro en las salas oscuras.

- La escopeta tiene el agarre real en la bomba: en fparms.blend IK_Hand_L va a (Y 0,20 m, Z -0,068 m en montura) con los dedos envolviendo el guardamanos y el pulgar apoyado en el flanco izquierdo. Con la mano en la bomba real en vez de en el cañón lejano, el brazo izquierdo ya no se hiperextiende y el parche ElbowPole queda eliminado en todos los clips.
- La recarga de la escopeta no traía claves de rotación ni de escala para la mano derecha (603 pistas frente a 610 en el reposo): el juego la dejaba en la postura por defecto y no salía en el cuadro. `ShotgunReload` y `ShotgunReloadEmpty` la clavan ahora en el reposo.
- Dispersión de cadera de la escopeta 1,2 (era 2,2): con 2,2 un cartucho solo mataba de un tiro hasta 6 m (31 % a 10 m); con 1,2, un 89 % a 10 m y de dos a tres cartuchos a larga. Medido con la fórmula de `WeaponAim` y 9 perdigones de 60 al pecho.
- Pegado a una cobertura el cañón entra en ella: la bala nacía dentro y se paraba en el primer milímetro, con el impacto flotando delante del arma. `WeaponAim.origin_of` sale desde la cámara cuando el tramo cámara→cañón choca.
- La escopeta tiene su propio `hip_pos` (x 0): con el compartido (x 0,085) el cuerpo quedaba a la derecha del centro en reposo. Con x 0 queda centrada y la mano derecha sigue agarrando la empuñadura. La mano izquierda va con la bomba.

## Deuda

- Pendiente: la recarga por cartuchos de la escopeta no se ha probado en un teléfono.
- Pendiente: la mano derecha de la recarga va fija en el agarre (base funcional); cargar por abajo, como el AR15, es el siguiente pulido sobre esa base. Los tiempos de cartucho viven en `WeaponSpec.shells` y la mano ya no los sigue.
- Pendiente: bajar el arma en la cadera (`hip_pos`) saca la mano derecha del cuadro; decidir antes de tocarlo.
- Pendiente: la Desert Eagle se sostiene con los clips `Deagle*` (copia de los de pistola): el asa cae donde la Glock deja la mano, pero los dedos siguen abiertos para el asa de la Glock (30 mm) y la de la Desert Eagle mide 38,5 mm. Abrirlos es el siguiente pulido.
- Pendiente: el Barrett M82A1 está descargado, decimado (218k → 55k caras) y pasado a `blender/barrett.blend`, pero sin origen bueno, sin clips y sin enchufar al juego.

Usa: audio, balistica, comun, enemigos, jugador

