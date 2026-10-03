# FlowFire Bodycam

Shooter bodycam singleplayer, pequeño y extremadamente pulido.
Una Glock. Godot 4.7, renderer Mobile.

## Referencia

`docs/refs/` manda. `ref8_mapa.jpg`: pasillo de casa de tiro (montantes vistos
y tablero OSB), cerchas rojas, lucernarios, ojo de pez con anillo oscuro, manos
enguantadas con el arma siempre en cuadro. `ref9_fabrica.jpg`: nave de hormigón
con paneles OSB exentos y soldado de negro con casco y chaleco. La sensación es
la de UNRECORD y Bodycam: cámara física, arma con masa, luz y exposición
creíbles, audio violento.

## Constitución

1. Calidad perceptual primero, con un suelo duro de 30 FPS estables en la
   máquina de referencia (Intel HD 520, 1080p). La resolución 3D es nativa
   (`scaling_3d` 1,0) y solo baja un escalón si la GPU no llega. Todo el
   margen por encima de 30 se invierte en calidad.
2. Más con menos: todo debe justificar su coste perceptual y técnico. Lo que no
   aporta al juego se borra (código, assets, herramientas, documentos).
3. Sobreingeniería prohibida. Una autoridad por comportamiento; módulos con una
   responsabilidad, legibles de arriba abajo sin el resto del proyecto.
4. Godot es el runtime. Blender (vía Blender MCP) es la autoridad de modelos,
   rig y animación: animación importada o autorada a mano, nunca keyframes
   generados por fórmula. Los assets de terceros solo con licencia limpia.
5. El mapa es dato: `PLAN` en `scripts/CombatMap.gd` genera geometría,
   colisión, navegación, luces y puestos.
6. Medir antes de afirmar: `godot --path . tools/snap.tscn -- --mode=combat
   --out=/tmp/a.png --pos=x,y,z --yaw=0 --pitch=0` captura el juego real y
   da el tiempo de cuadro. Tests solo para una duda real o una regresión
   material.
7. El historial vive en Git. El código no lleva comentarios: ni de línea, ni
   de bloque, ni docstrings. Los nombres y la estructura lo explican; el código
   es limpio, eficiente y legible de arriba abajo.
8. Este README es el único documento de reglas. No se añaden créditos ni otros
   documentos de proceso al árbol.

## Inmutabilidad

Este README solo cambia con autorización explícita del propietario y un motivo
concreto. Ningún agente puede reinterpretar una orden general como permiso.
