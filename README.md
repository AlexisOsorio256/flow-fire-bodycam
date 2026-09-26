# FlowFire Bodycam

Shooter singleplayer bodycam, pequeño y extremadamente pulido.

Dos modos: **Campo de tiro** y **Combate**.

Una Glock. Realismo audiovisual y físico alto.

**40 FPS estables como objetivo de referencia.** La calidad y el rendimiento se
optimizan juntos: no se baja la imagen para ganar frames, ni se sube el coste
por descuido. Todo efecto visual o físico debe pagar su coste perceptualmente.

## Reglas

- Todo justifica su coste. Cada archivo, nodo, script, textura, draw call,
  material, dependencia y test. Lo que exista "por si acaso" se elimina.
- Sobreingeniería prohibida. Sin managers, frameworks, capas genéricas ni
  arquitectura de empresa en un juego pequeño.
- Una autoridad por comportamiento. `Glock.gd` decide la mecánica del arma; el
  resto la representa, la reproduce o la mide.
- Godot primero. Solo se escribe algo propio cuando el motor no lo resuelve.
- Blender es la autoridad de autoría: mesh, rig, skin, UV, huesos, pose,
  animación, clip, socket, geometría. No se arregla en GDScript lo que
  pertenece al asset.
- Nada se declara por teoría. Visual → captura A/B. Rendimiento → frame time
  real. Sonido → WAV medido.
- Tests solo si protegen una regresión material o responden una pregunta real.
- Git conserva el pasado; el árbol activo solo conserva lo necesario.

## Verificación

```bash
for t in weapon reload slide_lock weapon_fx range_shell; do
  godot4 --headless --path . tools/check_$t.tscn
done
./tools/medir.sh                 # frame time real a 1080p
./tools/captura.sh evidencia     # capturas de todas las acciones
godot4 --headless --path . tools/frame_probe.tscn   # encuadre del viewmodel
```

## PENDIENTE

- **Cuerpo del enemigo.** La cadena entera está escrita y verificada
  (`scripts/Enemy.gd`, `tools/check_enemy.tscn`): un impacto mata, la reacción de
  cuello, la sangre y el ragdoll con el impulso de la bala. Falta el asset, que
  es un personaje real con esqueleto; el que se probó era un soldado medieval y
  se descartó. Hasta que llegue, `CombatMap` no puebla enemigos.
