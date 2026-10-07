# Blender

Blender es la autoridad de modelos, mapa, rig y animación; Godot solo los usa.
Todo se edita por el Blender MCP (`execute_blender_code`) y se exporta desde él
con `runpy.run_path(<script>, run_name="__main__")`. Los exportadores no
imprimen nada y avisan con un archivo en `/tmp`.

| Archivo | Qué es | Exporta | Aviso |
|---|---|---|---|
| `fparms.blend` | brazos del jugador: rig, clips de cada arma, vista previa de las armas y anclas `<Prefijo>Mount` | `tools/rebuild_arms.py` → `assets/models/fps_arms.glb` | `/tmp/flowfire_arms_done` |
| `soldier.blend` | enemigo: malla, rig con IK, clips y reacciones a impactos | `tools/export_soldier.py` → `enemy.glb` | `/tmp/flowfire_soldier_done` |
| `factory.blend` | el mapa | `tools/export_map.py` → `factory.glb` | `/tmp/flowfire_map_done` |
| `<arma>.blend` (`ar15.blend`) | arma por piezas, origen en la empuñadura, cañón hacia +Y | `tools/export_weapon.py` con `init_globals={"NAME": "ar15"}` → `<arma>.glb` | `/tmp/flowfire_weapon_done` |

`assets/models/*.glb` nunca se editan a mano (salvo `g19_pistol.glb`, sin
`.blend`). Tras exportar: `godot --headless --path . --import`.

Para juzgar sin abrir Godot: `tools/blender_view.py` (vista de juego con la
lente, ver `tools/AGENTS.md`) y `tools/blender_mesh.py` (estiramientos de malla).
Las claves se ponen a mano, pose a pose; nunca curvas generadas por fórmula.
Reproyectar animación importada sí es válido, pero una coreografía de pistola
reproyectada sobre un rifle no convence: cada arma anima sus propios clips.

## Trampas medidas

- Reasignar o borrar una acción que está en uso tumba Blender: guarda antes.
- Al asignar una acción a un rig, la primera actualización reevalúa la
  animación y pisa la pose que acabas de poner: actualiza antes de posar.
- Una pose base de una acción que no clavea un hueso conserva el valor
  anterior: pon el hueso en reposo antes de leerla.
- En Blender 4.0 `image.pack()` falla si la textura original ya no existe:
  guarda la imagen en disco y luego empaqueta.
- No uses `wm.read_factory_settings` (tumba la sesión con interfaz) ni dejes
  cambiada la escena de la ventana.
- Los `Transform3D` de un `.tscn` van por filas: comprueba la dirección de una
  luz con `str_to_var` antes de hornear (el sol llegó a alumbrar desde abajo).
- Blender del sistema (Python 3.12) se cae con Mantaflow; se usa el oficial
  4.0.2 en `~/.local/opt/blender-4.0.2-linux-x64` (servidor MCP en el 9876).
- `RifleInspect` traía la mano a la palanca en 80-94 pero el hueso `Slide` clavado a 0: se le ponen 45 mm a mano y `timing_errors` ya da `slide_back` 3,29 s y `slide_home` 3,92 s.
