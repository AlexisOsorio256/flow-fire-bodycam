# Jugador

`Player` mueve el cuerpo (andar, correr, agacharse), recibe daño por zona
(`Player.take`: cabeza 100, pecho 55, vientre 50, piernas 20; dos tiros al
torso matan; la pierna hace sangrar (`Player.bleed`) y el siguiente tiro
remata) y, sin sangrar, regenera a los 5 s. `BodyCam` es la cámara de pecho:
muelles de golpe, balanceo y retroceso de cámara. `PlayerAudio` es la
respiración, el latido y los pasos; `PlayerDeath`, la caída de la cámara al morir. Las
armas cuelgan de `Player.loadout` (dominio `armas`).

`Player.paused` es la pausa del jugador (menú de pausa, controles táctiles);
en red no se pausa el árbol.

## Trampas medidas

- El clic en la pausa lo robaba `Player._input` (recapturaba el ratón y
  despausaba entre la pulsación y la soltada, y «Volver al menú» nunca se
  disparaba): con `paused` no toca ratón ni teclas.

## Deuda

- Pendiente: «algo te saca del mapa» sin reproducir aún. Medido: al morir
  agachado por las piernas la cápsula de la cámara baja más que el hueco hasta
  el suelo y la física la expulsa 0,28 m hacia arriba; 2 min de paseo
  aleatorio contra paredes no sacaron al jugador.
- Pendiente: `Player` roza las 300 líneas y depende de `interfaz`, `red` y
  `partida`: el control táctil y la pausa de red deberían llegarle por señales.

Usa: armas, audio, balistica, comun, enemigos, interfaz, partida, red
