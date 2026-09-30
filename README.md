# FlowFire Bodycam

FlowFire Bodycam es un shooter singleplayer bodycam pequeño y extremadamente pulido.

Un modo: combate. Una Glock.

La referencia principal de sensación son `docs/refs/` y UNRECORD DE PC: es lo que el creador intenta. Gameplay bodycam realista: cámara física, movimiento humano, arma con masa, iluminación/exposición creíble, audio violento y alto realismo perceptual.

## Constitución

1. Calidad visual y rendimiento tienen el mismo peso.
2. Objetivo de referencia: 40 FPS estables.
3. Todo debe justificar su coste perceptual y técnico.
4. Sobreingeniería absolutamente prohibida.
5. Una autoridad por comportamiento.
6. Godot primero para runtime.
7. Blender es autoridad para assets, geometría, rig y animación. **Importar un
   asset ya riggeado y animado con licencia limpia y traducir su esqueleto en el
   JSON del GLB antes de importarlo ES esa autoridad, no una excepción**:
   `tools/build_enemy.py` lo hace así con el cuerpo del soldado (`--fbx`, 46
   animaciones CC0) y falla diciendo qué hueso falta. Lo que esta regla prohíbe
   es **generar el gesto por fórmula** (IK + `smooth_step` escribiendo keyframes)
   y llamarlo animación: sale interpolación mecánica, no animación. La animación
   importada y retargeteada es la vía, con los keyframes de CONTACTO (mano al
   brocal, cargador presentado) autorados a mano.
8. Tests sólo cuando falsifican una duda real o protegen una regresión material.
9. Medir antes de afirmar.
10. El árbol activo sólo conserva lo necesario.
11. No se añaden créditos al árbol activo;
12. README.md es esta constitución.
13. La eficiencia también es del código, no sólo del frame: cada módulo es su propia autoridad, con una responsabilidad y una frontera explícitas, y se prefieren piezas desacopladas y reemplazables a capas que se conocen entre sí. Si dos sitios pueden decidir lo mismo, sobra uno. Un módulo se lee de arriba abajo sin reconstruir el resto del proyecto, porque quien mantiene esto es una IA sin la sesión anterior en la cabeza.
14. **El historial vive en Git, no en el código.** Prohibido absolutamente
    escribir en un `.gd`, `.py`, `.sh`, `.gdshader`, `.tscn` o documento:
    por qué se cambió algo, qué valor tenía antes, "pasadas" de trabajo, fechas,
    medidas que ya no aplican, defectos ya corregidos, autorizaciones del
    propietario, y capturas o comandos citados como prueba de una decisión.
    Un comentario sólo dice **QUÉ hace el código y QUÉ invariante protege, en
    presente**; el número que aparece es el CONTRATO vigente, jamás la historia
    de ese número. El pasado se lee con `git log`, que ya lo guarda y no ocupa
    una sola línea del árbol.
15. **La prosa no puede pesar más que el código.** Si un módulo necesita más
    líneas de comentario que de código para entenderse, el comentario sobra o el
    módulo está mal cortado. Un documento que crece para justificarse a sí mismo
    es peso muerto: se recorta o se borra. La constitución se aplica a sí misma.

## Inmutabilidad

Este README sólo puede cambiar con:

- autorización explícita del propietario;
- motivo concreto para modificar la constitución.

Ningún modelo, agente o herramienta puede reinterpretar una orden general como permiso para modificarlo.

Git conserva el pasado.
