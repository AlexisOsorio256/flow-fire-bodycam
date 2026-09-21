# FlowFire — estado de producción

Este documento contiene el detalle técnico **actual** que no necesita vivir en
el README. No es changelog: Git conserva la historia.

## Plataforma y runtime

- Godot 4.7.2 Standard.
- GDScript.
- Renderer Mobile / Forward Mobile.
- Jolt Physics.
- Escena principal: `scenes/Main.tscn`.
- Autoloads: `GameAudio`, `ImpactFX`, `Ballistics`.
- Salida: 1920×1080.
- Raster 3D de producción: **1920×1080 nativo** (`scaling_3d/scale = 1.0`).
- El reescalado interno queda fuera de la estrategia de rendimiento.
- MSAA: 2x (`anti_aliasing/quality/msaa_3d=1`).
- SSAO/SSIL: fuera de la ruta de producción.

El objetivo mínimo de esta etapa es **35 FPS a 1080p nativo** manteniendo o
mejorando la calidad. La vía de optimización prioritaria es reducir coste real
de iluminación/render/culling, no bajar resolución ni oscurecer la escena.

El HUD debe mostrar exactamente:

```text
Creador: Alexis Osorio BETA 1
```

## Glock 19

### Referencia física

La referencia es una Glock 19 Gen5 stock:

| Dato | Valor |
|---|---:|
| largo | 185 mm |
| alto | 128 mm |
| ancho | 30 mm |
| cargador estándar | 15 cartuchos |
| recorrido aproximado de disparador | 12,5 mm |
| recorrido de corredera | 39 mm |

`assets/models/g19_pistol.glb` es una aproximación visual de ~174 × 127 ×
31 mm. Godot la importa en metros y la mantiene a escala 1. La diferencia de
largo frente a la referencia no se compensa deformando la malla en runtime.

### Árbol obligatorio

```text
Glock
├── Frame
├── Slide
├── Barrel
├── Trigger
├── Magazine
├── Muzzle
├── EjectionPort
├── SightRear
├── SightFront
├── Grip
└── Magwell
```

`Muzzle` cuelga de `Barrel`; `Grip` y `Magwell` de `Frame`;
`EjectionPort`, `SightRear` y `SightFront` de `Slide`. Si falta una pieza
o el parent no coincide, `GlockWeapon.build()` falla y el viewmodel no arranca.

La Glock no usa esqueleto. Corredera, cañón, gatillo y cargador son piezas
rígidas con transform propio. El pivote de retroceso sale de `Grip`.

## Viewmodel y brazos

Jerarquía:

```text
Viewmodel
└── PoseRoot
    └── BodyGive
        ├── ArmsRig
        └── WeaponGrip
            └── WeaponSocket
                └── Weapon
```

`PoseRoot` maneja cadera/ADS/sprint/bob/sway/respiración. `BodyGive` aplica
la cesión lenta del conjunto. `WeaponSocket` es la única autoridad del
retroceso rápido del arma.

`assets/models/fps_arms.glb` es obligatorio y es el único asset de brazos:

| Dato | Estado |
|---|---|
| mallas | 1 (`Arms_Mesh`) |
| triángulos | 13.536 |
| materiales | 1, con baseColor + metallicRoughness + normal |
| texturas | 3 × 1024² |
| huesos | 51 deform |
| tamaño | ~6,2 MB |
| clips | `Idle` 3,00 s · `Fire` 0,26 s · `Reload` 2,10 s · `ReloadEmpty` 2,35 s · `Inspect` 2,00 s |

El asset se autora en espacio de arma (+Y arriba, −Z al morro, raíz en el origen
del arma). `GRIP_POS` y `GRIP_ROT` son `Vector3(0,0,0)`; no existe una
calibración runtime para esconder una pose incorrecta.

El `AnimationPlayer` anima sólo huesos humanos. `Glock.gd` conserva la
autoridad sobre corredera, gatillo, cargador y estados mecánicos. No hay
`HandManager`, `ArmController` ni IK runtime.

### Timings autorados actuales

- `Fire`: cadena hombro → codo → antebrazo → muñeca horneada offline. La mano
  alcanza la cesión hacia ~50 ms, el hombro hacia ~78 ms y la pose vuelve al
  agarre base a ~130 ms.
- `Reload`: hitos 0,28 / 0,62 / 1,02 / 1,40 s.
- `ReloadEmpty`: llega al retén ~1,64 s, estabiliza hasta 1,70, pulsa ~1,72 y
  libera ~1,75.
- `Inspect`: acompaña ~37,7 mm de los 39 mm de recorrido de corredera y separa
  la mano al soltar para evitar atravesarla.

Estos valores son sincronización mecánica, no certificación visual. La pose base
de manos/dedos sigue partiendo del donor transformado; la aceptación final de
contacto, anatomía y clipping requiere captura real.

## Rango de medición

`range_shell.glb` es presentación estática: suelo, paredes, techo, columnas,
vigas, canaletas, luminarias, marcaciones y bullet trap. El espacio permanece
abierto: **sin mamparas, separadores ni fierros de calle**.

Producción canónica:

- 31 mallas.
- dimensiones verificadas ~24,0 × 4,7 × 72,22 m.
- segmentos longitudinales de hasta ~14,62 m.
- `BAY = 3.6`.
- `LIGHT_CHUNK = BAY * 4.0`.
- 7 materiales PBR obligatorios:
  - `Range_Concrete_Brushed`
  - `Range_Concrete_Floor`
  - `Range_Concrete_Wall`
  - `Range_Luminaire`
  - `Range_Markings`
  - `Range_Oak_Trim`
  - `Range_Painted_Metal`

El GLB no es autoridad de las texturas. `scripts/RangeShell.gd` carga y asigna
los mapas externos de producción. Si falta material o textura requerida, el
arranque falla; no existe material plano de reserva.

`World.gd` aporta la capa funcional/disparable y no reintroduce divisores de
calle.

### Estaciones

- 1,4 m: mesa con 4 cargadores físicos de 15.
- 3,7–13,7 m: props cercanos, placas, papel, madera, cajas y bidones.
- 9,5–13,7 m: thin-shell.
- 14 y 18 m: paneles de pladur penetrable.
- 18 m: 5 blancos de papel.
- 27 m: 3 placas de acero.
- 35 m: 3 blancos de papel.
- 50 m: 1 placa de acero.

### Respuesta visual del acero

La legibilidad del acero se resuelve en el material, no subiendo exposición ni
oscureciendo/aclarando globalmente la sala.

- placa: base ~0,60–0,66, `metallic = 0.52`, `roughness = 0.68`;
- soporte: base ~0,42–0,48, `metallic = 0.45`, `roughness = 0.62`;
- bidón pintado: base ~0,30–0,37, `metallic = 0`, `roughness = 0.64`.

Normal y roughness se conservan.

### Iluminación

`RangeShell.tscn` usa `LightmapGI` con UV2 generada por el importador. Las 10
`OmniLight3D` y 3 `SpotLight3D` son fuentes de **autoría/bake**: permanecen en
la escena para poder rehornear, pero `RangeShell.gd` las apaga en runtime. El
bake activo es no direccional y de un rebote; no hay `ReflectionProbe` en
producción.

Glock y brazos conservan su PBR y reciben el ambiente/reflejo de cielo sin KEY/
FILL local permanente. Las dos Omni del fogonazo existen sólo durante el pulso
real del disparo; en reposo están `visible=false`, no sólo a energía cero.

Glow y fog de entorno están apagados: el glow mínimo y la niebla 0,0012 no
aportaban suficiente imagen frente a su coste combinado en Mobile. La firma
bodycam permanece en el post fullscreen optimizado.

## Audio

Topología de producción:

```text
Weapons (Glock + Foley cercano) ───────────────────→ Master
World (impactos/rebotes/pasos/vainas) → Range ─────→ Master
```

`default_bus_layout.tres` define la topología y `GameAudio.gd` la valida al
arrancar. Si faltan `Range`, `Weapons`, `World` o sus rutas esperadas, el
arranque falla.

Valores actuales:

| Evento | Nivel |
|---|---:|
| blast | `SHOT_DB = -5.5 dB` |
| `slide_battery` | -8 dB |
| `magin` | -10 dB |
| `slide_release` | -7 dB |
| `mag_insert` | -9 dB |

Restricciones de mezcla:

- blast cercano directo a `Master`;
- mecánica cercana directa a `Master`;
- mundo/impactos por `World -> Range -> Master`;
- sin limiter;
- sin ducking;
- sin reverb añadida al blast;
- sin HPF/EQ/fades/pitch/layers añadidos al disparo raw.

La familia de disparo usa cinco tomas de una grabación real de Glock 17 9×19.
`tools/build_shot_real.py` corta ventanas raw de 380 ms con 11 ms de pre-roll y
sólo aplica ganancia uniforme cuando el decode presenta overshoot. La limitación
de la preview fuente está documentada en `CREDITS_AUDIO.md`.

## Balística y física

`Ballistics.gd` es la única autoridad de:

```text
material + geometría + velocidad
→ penetración
→ velocidad de salida
→ impulso p_entrada - p_salida
```

La salida usa la forma de colisión real. Los objetos `thin_shell` declaran
`wall_thickness`; las cajas huecas están construidas por paneles y Jolt aporta
el torque por el punto de impacto.

`Ballistics.MATERIALS` contiene la resistencia de `steel`, `aluminum`,
`gypsum`, `pine`, `paper` y `concrete`. `Target` y `Crate` no
duplican esos números.

El proyectil nace en `Muzzle` alineado con el ánima. La dispersión mecánica es
gaussiana de media cero con `SHOT_DISPERSION_SIGMA = 1.6 mrad` por eje.

## Alcance del producto

El producto actual termina en una Glock 19 y su cadena de disparo/material/
feedback. Quedan fuera: segunda arma, weapon manager genérico, multiplayer,
backend, cuentas, economía, anuncios, ranking, chat, clans, vehículos, campaña,
loot, matchmaking e IK runtime.
