# Armas

Lo que el jugador lleva en las manos.

`Loadout` lleva las armas de `WeaponSpec.all()` y cambia entre ellas (1 a 5, Q,
rueda, botón táctil). Cada arma es un `Firearm`: gatillo, corchete, recarga e
inspección, sin un valor propio; todo sale de su `WeaponSpec` (balística,
cadencia, `times`, `sounds`, `recoil`). `WeaponSequence` arma las secuencias de
recarga, inspección y desenfunde; las armas de cartuchos (`spec.shells`, la
escopeta) recargan uno a uno y no sueltan cargador. `WeaponModel` es la base de
los modelos: piezas, sockets y el gatillo (`set_trigger` y `TRIGGER_TRAVEL` son
suyos; la Glock lo reescribe porque su gatillo gira). `Viewmodel` coloca arma y
brazos ante la cámara y alinea las miras.

`FpArms` monta `fps_arms.glb`, toca los clips con el prefijo del arma y lee del
clip cuándo sale y entra el cargador (hueso `Mag`) y cuándo va y vuelve el
cerrojo (hueso `Slide`). Las piezas y los sockets de cada arma los mide su
`<Arma>Weapon.gd`; `Nodes.aabb` mide la malla entera (el largo de la Glock se
comprueba contra 174 mm).

## Añadir un arma

1. `blender/<arma>.blend` por piezas y `tools/export_weapon.py`.
2. En `fparms.blend`: vista previa colgada del hueso `Weapon`, un vacío
   `<Prefijo>Mount` en la misma posición y los clips `<Prefijo>Idle`, `Aim`,
   `Fire`, `Reload`, `ReloadEmpty`, `Inspect`, `Equip` y `Trigger` a mano.
3. `<Arma>Weapon.gd` hereda de `WeaponModel`; su ficha en `WeaponSpec` y una
   línea en `WeaponSpec.all()`.

## Trampas

- La dispersión sube una vez por disparo, no por perdigón: `WeaponAim.bloom_per_shot`
  lo llama `Firearm._fire` antes del bucle de `pellets`.
- La mira es un deseo (`Firearm.want_aim`): `_process` la enciende cuando no hay
  recarga, inspección ni desenfunde. Un pestillo deja sin mira tras una recarga.
- Brazo 0,20 m y antebrazo 0,21 m: alargarlos deformó la manga y costó 1,6 ms de
  GPU. Para llegar lejos, el clip adelanta el hueso `Body` (fuera de cámara).
- `FpArms` toma como asiento del cargador el hueso `Mag` del primer fotograma de
  `<Prefijo>Idle`; con el cargador en la mano, `Mag` va fijo a la palma.
- Un rol de sonido vacío (`""`) no suena. El rifle no tiene corredera: su
  `action_rear` es la palanca (`rifle_charge`).
- Lo validado de la Glock no se mueve para encajar otra arma: si la Glock cambia,
  se rehace.
- Las alzas inventadas y el aro de la escopeta (`SightRear`) están rechazados por
  el propietario. `arma` vigila que el aro no vuelva.
- `Shell.CALIBERS` es la única tabla de calibres (masa, largo, radio y punta).
  `Shell.dims_of` avisa si un calibre no tiene ficha; `RoundMesh` solo dibuja
  punta si la ficha la trae.
- El arma declara su proyectil en `WeaponSpec.ballistic()`. Un campo a cero es
  «la de siempre» (7,45 g y 0,00142 en `Ballistics`): las armas validadas no
  cambian ni un número.
- El .50 BMG es el único calibre con `neck_rad`, `shoulder_len` y `nose_len`
  (vaina torneada). Su culote es también el del colisionador, así que la vaina
  rueda como un objeto grande. `RoundMesh` dibuja la bala del cargador con la
  misma vaina (`Shell.case_of`).
- Prefijo vacío: el viewmodel pone el arma (`_hold_pose` sale antes de tiempo) y
  solo la Glock está hecha para eso. Un arma nueva lleva prefijo propio: se cuelga
  del hueso `Weapon` y la mano la sostiene.
- El origen de un arma descargada se ancla al asa de la Glock (`WEB_GLOCK` en
  `blender/desert_eagle.py`), no al ánima: con el origen en el ánima, la mano
  acababa en la corredera.
- Un arma descargada se escala midiendo la pieza que recorre el arma (`Rail,
  Grip, Stock and others`), no la caja del modelo entero: un cerrojo metido en
  la culata estira la caja y el arma sale corta. El cerrojo de mano es `Slide` y
  el cañón va en `Frame`; si `Slide` fuera el cerrojo entero, al ciclar se movía
  el cañón.
- Cada arma grande tiene su cadera (`hip_pos`, `hip_rot`): con la compartida, el
  visor del Barrett queda en la cara y el cañón de la escopeta se pierde por
  perspectiva. Sus clips propios (`Barrett*`, `Shotgun*`, `Deagle*`) son copias de
  los de su familia (`blender/weapon_clips.py`, `blender/desert_eagle_clips.py`).
- El impulso de `WeaponAction` es fijo (6,5) con física amortiguada; `cycle()` lo
  escala por `travel / TRAVEL_REF`, así que una bomba de 85 mm llega atrás.
- Con ciclo lento, el alimentar cae después de pedir la recarga: la táctica fija
  `chamber` a 1.
- La escopeta: `arma` mide la malla, porque un socket bien colocado no garantiza
  una malla bien girada (salía de pie). Su boca se mide sobre los vértices del
  cañón, no a ojo.
- Escopeta: la mano izquierda agarra la bomba (IK en Y 0,20, Z -0,068), no el
  guardamanos lejano; su `hip_pos` tiene x 0 para quedar centrada. El hueso `Body`
  avanza 0,10–0,15 m en todos los clips `Shotgun*`, con el mismo desplazamiento de
  `IK_Hand_L` en cada clip (uno por clip salía 0,45 m).
- Escopeta: los extremos de `ShotgunReload` y `ShotgunReloadEmpty` van a la pose de
  `Idle` (si no, la mano salta 0,69 m al entrar y 1,7 m al salir). Sus claves de
  rotación y escala de la mano derecha son obligatorias; sin ellas no salen en el
  cuadro.
- Recarga de cartuchos: cada cue de `shell_cues` es un ciclo de la mano derecha
  (`IK_Hand_R`), e `insert_shell` suma uno al tubo. Disparar durante la recarga
  corta la caja (`cancel_reload`).
- Inspección de escopeta: `IK_Hand_L` fija en el guardamanos, igual que en la
  recarga, o el brazo cuelga cuando el arma gira.
- El salto no tiene clips: `Firearm.set_motion` pasa la velocidad vertical a
  `Viewmodel` (hunde el arma al subir y la deja flotar al caer) y
  `WeaponRecoil.kick_land` la golpea al aterrizar. Así cualquier arma acompaña al
  cuerpo sin tocar Blender.
- Los casquillos salen a la derecha y arriba (`Shell.spawn`): a 0,1 s, si salen
  hacia atrás, ya están fuera de cuadro. El latón va al 55 % de metal; al 95 %
  se lee negro en las salas oscuras.
- Retroceso del fusil y la escopeta más duro a propósito (`WeaponSpec.recoil`,
  `cam_kick`): el propietario juzga el tacto jugando.
- Pegado a una cobertura, el cañón entra en ella: `WeaponAim.origin_of` sale desde
  la cámara cuando el tramo cámara→cañón choca.
- En `fparms.blend`, `<Arma>Mount` debe ser hijo del hueso `Weapon` (`parent_type = BONE`, `parent_bone = Weapon`) con rotación invertida [-1, 0, 0 / 0, 0, 1 / 0, 1, 0]; si se emparenta como objeto raíz sin hueso, Godot no crea BoneAttachment3D, el offset cae a identidad y el arma queda rotada 180° apuntando al jugador.
- Al hornear clips (`nla.bake`) en Blender, cada acción debe marcarse con `use_fake_user = True` de inmediato o Blender la purga al cambiar de acción activa.

## Deuda

- Pendiente: retícula 2D con oscurecimiento perimetral para la mira telescópica del Barrett al apuntar con zoom de 28°.
- Pendiente: la recarga por cartuchos de la escopeta no se ha probado en un teléfono.
- Pendiente: afinar silueta de dedos de mano izquierda al agarrar las estrías traseras de la Desert Eagle en recarga en seco.
- Pendiente: grabaciones de campo dedicadas de disparos reales de .50 AE y .50 BMG (`GameAudio.SHOT_STREAMS`).

Usa: audio, balistica, comun, enemigos, jugador
