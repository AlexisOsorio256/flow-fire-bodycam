# Jugador

`Player` mueve el cuerpo (andar, correr, agacharse, saltar), recibe daño por zona
(`Player.take`: cabeza 100, pecho 55, vientre 50, piernas 20; dos tiros al torso
matan) y, sin recibir fuego, regenera a los 3 s. `BodyCam` es la cámara de pecho:
muelles de golpe, balanceo y retroceso de cámara. `PlayerAudio` es la respiración,
el latido y los pasos; `PlayerDeath`, la caída de la cámara al morir. Las armas
cuelgan de `Player.loadout` (dominio `armas`).

`Player.paused` es la pausa del jugador (menú de pausa, controles táctiles); en red
no se pausa el árbol. Las teclas no se leen aquí por código: se piden por acción
(`move_*`, `jump`, `crouch`…) definidas en `project.godot`, sección `[input]`.

## Trampas

- Con `paused` el jugador no toca ratón ni teclas: si no, el clic del menú de
  pausa recapturaba el ratón y «Volver al menú» nunca se disparaba.
- Zona desconocida: la que llega por red se busca con `DAMAGE.get`, no con
  `DAMAGE[zona]`; una zona nueva mataba la partida en vez de contar como pecho.
- El salto medido: 1,07 m de alto y 0,83 s en el aire con 4,5 m/s de impulso;
  gravedad 9,8 al subir y 15 al bajar; 0,35 de control en el aire y 0,12 s de
  coyote. Al aterrizar avisa a los enemigos que oyen (`hear_step`, 9 m por golpe)
  y mueve cámara y arma (`BodyCam.kick_land`, `WeaponRecoil.kick_land`).
- El deseo de saltar es `Player.jump_held` (lo enciende el botón táctil) o la
  acción `jump`: un botón nuevo no necesita variable propia en el pad.

## Deuda

- Pendiente: «algo te saca del mapa» sin reproducir aún. Medido: al morir agachado
  por las piernas, la cápsula de la cámara baja más que el hueco hasta el suelo y
  la física la expulsa 0,28 m hacia arriba; 2 min de paseo aleatorio contra
  paredes no sacaron al jugador.
- Pendiente: `Player` tiene 335 de 350 líneas y depende de `interfaz`, `red` y
  `partida`: el control táctil y la pausa de red deberían llegarle por señales.
- Pendiente: el salto no se ha probado en un teléfono, y el salto encadenado
  (mantener la barra) aún no tiene límite: mirar si se puede abusar de él.

Usa: armas, audio, balistica, comun, enemigos, interfaz, partida, red
