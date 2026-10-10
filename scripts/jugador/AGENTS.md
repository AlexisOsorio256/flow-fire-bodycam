# Jugador

`Player` mueve el cuerpo (andar, correr, agacharse, saltar), recibe daño por zona
(`Player.take`: cabeza 100, pecho 55, vientre 50, piernas 20; dos tiros al
torso matan) y, sin recibir fuego, regenera a los 3 s. La zona que llega por red
se busca con `DAMAGE.get`, no con `DAMAGE[zona]`: una zona desconocida mataba la
partida en vez de contar como pecho. `BodyCam` es la cámara de pecho:
muelles de golpe, balanceo y retroceso de cámara. `PlayerAudio` es la
respiración, el latido y los pasos; `PlayerDeath`, la caída de la cámara al morir. Las
armas cuelgan de `Player.loadout` (dominio `armas`).

`Player.paused` es la pausa del jugador (menú de pausa, controles táctiles);
en red no se pausa el árbol.

## Trampas medidas

- El clic en la pausa lo robaba `Player._input` (recapturaba el ratón y
  despausaba entre la pulsación y la soltada, y «Volver al menú» nunca se
  disparaba): con `paused` no toca ratón ni teclas.
- El salto medido: 1,07 m de alto y 0,83 s en el aire con 4,5 m/s de impulso,
  gravedad 9,8 al subir y 15 al bajar (cae antes de lo que sube), 0,35 de
  control en el aire y 0,12 s de coyote tras dejar el borde. Al aterrizar avisa a
  los enemigos que oyen (`hear_step`, 9 m por golpe) y mueve cámara y arma
  (`BodyCam.kick_land`, `WeaponRecoil.kick_land`): un salto no es gratis.
- El deseo de saltar es `Player.jump_held` (lo enciende el botón táctil; la
  barra espaciadora se lee aparte con `Input.is_key_pressed`), el mismo patrón
  que `Firearm.want_aim`: deja probar el salto sin teclado y sin tocar el pad.

## Deuda

- Pendiente: «algo te saca del mapa» sin reproducir aún. Medido: al morir
  agachado por las piernas la cápsula de la cámara baja más que el hueco hasta
  el suelo y la física la expulsa 0,28 m hacia arriba; 2 min de paseo
  aleatorio contra paredes no sacaron al jugador.
- Pendiente: `Player` roza las 300 líneas y depende de `interfaz`, `red` y
  `partida`: el control táctil y la pausa de red deberían llegarle por señales.
- Pendiente: el salto no se ha probado en un teléfono, y el salto encadenado
  (mantener la barra) aún no tiene límite: mirar si se puede abusar de él.

Usa: armas, audio, balistica, comun, enemigos, interfaz, partida, red
