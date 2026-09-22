# Créditos de modelos 3D

## G19 Pistol, Game Ready — Rotuma (EL ARMA)

- Archivo: `assets/models/g19_pistol.glb` (321 KB). **No lleva ninguna imagen
  dentro**: es geometria con un solo material. Sus texturas son externas, en los
  `assets/models/g19_pistol_Image_*.png` que el importador extrajo del archivo
  original del autor (2048² del arma, 512² de la bala) y que hoy son la fuente
  unica de los mapas del arma. Se quitaron del GLB porque eran las MISMAS
  imagenes duplicadas (10 MB) y el runtime las carga del disco.
- Fuente: Sketchfab —
  https://sketchfab.com/3d-models/g19-pistol-game-ready-free-version-e3412d9803f04bdaa97ad9b68ed665d7
- Autor: **Rotuma** (Nathan Nilsen) — https://sketchfab.com/Rotuma
- Licencia: **CC-BY 4.0**, la que trae el `license.txt` del propio autor.
  Atribución literal:
  *This work is based on "G19 Pistol, Game Ready, Free version"
  (https://sketchfab.com/3d-models/g19-pistol-game-ready-free-version-e3412d9803f04bdaa97ad9b68ed665d7)
  by Rotuma (https://sketchfab.com/Rotuma) licensed under CC-BY-4.0
  (http://creativecommons.org/licenses/by/4.0/)*
- Medidas del resultado, comprobadas con `tools/check_weapon.gd`: 174,0 mm de
  largo (malla), 127,0 mm de alto, 31,0 mm de ancho y 146,3 mm entre miras.
  REFERENCIA: G19 Gen5 stock (185 x 128 x 30, ~152 mm entre miras, 15 tiros,
  ~12,5 mm de disparador). La malla es aproximacion visual, 11 mm corta; se
  dibuja a su medida en metros y no se estira. Los sockets se leian por AABB
  hasta la canonicalizacion del parrafo siguiente; desde entonces vienen
  dentro del GLB y el runtime solo los lee (Muzzle bajo Barrel).
- El resultado son mallas rígidas —`Frame`, `Slide`, `Magazine`, `Trigger`,
  `Barrel`— sin esqueleto y sin animaciones.
- Las cuatro `g19_pistol_Image_3..6.png` son **mapas externos canónicos** del arma:
  el GLB de producción ya no contiene imágenes y `GlockWeapon.gd` carga esos
  PNG directamente. No son derivados temporales ni se deben borrar. Sus imports
  usan mipmaps y `Image_6` está marcado como normal map.

## Brazos — DJMaesen (LOS BRAZOS)

- Archivo: `assets/models/fps_arms.glb` (6,2 MB). Lleva **1 malla** (`Arms_Mesh`,
  **13.536 triangulos**), **1 material** (`arms`) y **3 texturas de 1024²**
  (baseColor, metallicRoughness y normal). Esqueleto **deform-only de 51 huesos**
  con los nombres originales del rig DJMaesen; el GLB no exporta IK,
  constraints, poles ni helpers de autoría.
- Contiene **exactamente cinco clips**, con estos nombres y estas duraciones, que
  son las de la mecanica de `scripts/Glock.gd`:

  | clip | duracion | hito mecanico |
  |---|---|---|
  | `Idle` | 3,00 s | bucle de agarre a dos manos |
  | `Fire` | 0,26 s | latigazo por disparo |
  | `Reload` | 2,10 s | `RELOAD_TOTAL` |
  | `ReloadEmpty` | 2,35 s | `RELOAD_EMPTY_TOTAL` |
  | `Inspect` | 2,00 s | `INSPECT_TOTAL` |

- Fuente: **DJMaesen**, "animated pistol" —
  https://sketchfab.com/3d-models/animated-pistol-bd896167e7ca44f19597d3afe6a8d83f
- Licencia: **CC-BY-4.0**, la que trae el `license.txt` del propio paquete:
  `license type: CC-BY-4.0` / `requirements: Author must be credited. Commercial
  use is allowed.` **Esta licencia OBLIGA a atribuir**, asi que la cadena de
  credito que pide el autor va literal aqui:
  *This work is based on "animated pistol"
  (https://sketchfab.com/3d-models/animated-pistol-bd896167e7ca44f19597d3afe6a8d83f)
  by DJMaesen (https://sketchfab.com/DJMaesen) licensed under CC-BY-4.0
  (http://creativecommons.org/licenses/by/4.0/)*
- El GLB de DJMaesen generado con `tools/build_arms.py` es la **fuente canónica
  de producción**. El builder actual ya no retima ventanas del donor: conserva
  su malla/esqueleto, normaliza el bind y genera directamente las cinco acciones
  con IK analítica de dos huesos sólo durante el bake Blender. La pose base de
  dedos/manos sigue naciendo del fotograma 0 del donor rigidamente colocado
  sobre la G19; por tanto `VERIFY OK` y `check_weapon.tscn` certifican el
  contrato técnico, **no** que el agarre sea anatómicamente perfecto. La
  aceptación visual corresponde a video/contact sheets y a las vistas del banco
  `tools/bench_arms.py`, alimentado por los transforms reales de
  `tools/frame_probe.gd`.
- El GLB de brazos lleva sus tres texturas embebidas. Godot puede extraer copias
  `assets/models/fps_arms_arms_*.png` al importar; esas copias están ignoradas y
  no son fuente de verdad. El GLB es el asset canónico.


## RangeShell — geometria original de FlowFire

- `assets/models/range_shell.glb`: carcasa estatica del rango, con suelo, muros,
  columnas, vigas, luminarias, rodapies, marcaciones de
  distancia y bullet trap visual. **Sin separadores de lane ni mamparas**:
  se quitaron a peticion del dueño (README §Rango); si una revision vieja los
  nombra, es estancada. **No lleva ninguna imagen dentro**: es
  geometria con siete materiales con nombre (`Range_Concrete_Brushed`,
  `Range_Concrete_Floor`, `Range_Concrete_Wall`, `Range_Luminaire`,
  `Range_Markings`, `Range_Oak_Trim`, `Range_Painted_Metal`) y el
  `baseColorFactor` de exportación no actúa como fallback. Las texturas PBR reales son externas
  (`assets/textures/real/*.jpg`, CC0 de Poly Haven, ver `CREDITS_TEXTURES.md`) y
  las enchufa `scripts/RangeShell.gd` al arrancar, material por material; si un
  nombre o mapa obligatorio falta, el rango falla al arrancar. No
  contiene latas, drywall, cajas, blancos ni metadata balistica. Sus colisiones
  funcionales viven en `scenes/RangeShell.tscn`.
