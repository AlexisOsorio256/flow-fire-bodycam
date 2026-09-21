# FlowFire

FlowFire es un laboratorio FPS/bodycam centrado en una sola Glock 19: ciclo
mecánico, disparo, proyectil, material, penetración, física, audio y feedback
visual. El rango es un instrumento de medición abierto, no un mapa de juego.

Estado técnico objetivo: Godot 4.7.2 Standard, renderer Mobile, GDScript y Jolt.
La prioridad del proyecto es **estabilidad → gameplay/game feel → rendimiento →
UX → inmersión → features**.

## Contrato de producción

- `main` es la única rama de producción.
- Una autoridad por comportamiento. `Glock.gd` decide la mecánica; los demás
  sistemas representan, reproducen o miden ese estado.
- Una sola ruta de producción: sin managers genéricos, fallbacks activos,
  sistemas legacy ni piezas procedurales de reserva.
- Asset/pose/UV/origen/rig se corrige en Blender; mecánica/física/audio runtime se
  corrige en Godot o tooling offline mínimo.
- Material + geometría + velocidad entran a `Ballistics.gd`; la resistencia
  vive únicamente en `Ballistics.MATERIALS`.
- Una mejora visual exige captura real; una mejora de rendimiento exige benchmark
  de render; una mejora de audio exige inspeccionar los WAV y la mezcla.
- Git conserva la historia. README, docs y créditos describen sólo el estado vivo.

## Estado actual

- Una Glock 19 Gen5 de referencia; no existe una segunda arma.
- Viewmodel con brazos obligatorios, cinco clips horneados y sin IK runtime.
- Rango interior abierto: sin mamparas, separadores ni fierros de calle.
- Carcasa canónica de producción: 31 mallas, 7 materiales PBR obligatorios y
  tramos longitudinales de hasta ~14,6 m.
- 13 luces de mundo y 3 ReflectionProbe estáticos; el viewmodel usa sus propias
  luces tenues.
- Audio cercano de Glock directo a `Master`; mundo/impactos por
  `World -> Range -> Master`.
- Salida y raster 3D: **1920×1080 nativo** con MSAA 4x. El reescalado interno
  queda descartado como estrategia de rendimiento.
- El HUD debe mostrar exactamente: `Creador: Alexis Osorio BETA 1`.

## Arquitectura

| Responsabilidad | Autoridad |
|---|---|
| Arranque y composición | `scripts/Main.gd` |
| Estado de Glock | `scripts/Glock.gd` |
| Piezas/sockets de la Glock | `scripts/GlockWeapon.gd` |
| Montaje, pose, ADS y brazos | `scripts/GlockViewmodel.gd` |
| Retroceso | `scripts/GlockRecoil.gd` |
| Huesos humanos | `AnimationPlayer` de `ArmsRig` |
| Fogonazo, humo y luz de boca | `scripts/WeaponFX.gd` |
| Proyectil, penetración, rebote e impulso | `scripts/Ballistics.gd` |
| Impactos | `scripts/ImpactFX.gd` + `GameAudio` |
| Carcasa visual/colisiones/luminarias | `scenes/RangeShell.tscn` |
| Materiales PBR de la sala | `scripts/RangeShell.gd` |
| Estaciones y props disparables | `scripts/World.gd`, `Target.gd`, `Crate.gd` |

La escena principal es `scenes/Main.tscn`. Los autoloads son `GameAudio`,
`ImpactFX` y `Ballistics`.

## Resumen del producto

La referencia física de la Glock 19 Gen5 es 185 × 128 × 30 mm, cargador de 15
cartuchos, recorrido aproximado de disparador de 12,5 mm y recorrido de
corredera de 39 mm. El asset canónico es una aproximación visual y se mantiene a
escala 1; no se estira en runtime para ocultar diferencias.

`assets/models/fps_arms.glb` es el único asset de brazos de producción. Tiene
una malla, 51 huesos deform y los clips `Idle`, `Fire`, `Reload`,
`ReloadEmpty` e `Inspect`. `GRIP_POS` y `GRIP_ROT` son cero: el asset se
autora en el espacio del arma y el runtime no compensa una pose incorrecta.

El rango se recorre libremente. Las estaciones principales están a 14/18 m
(pladur), 18/35 m (papel), 27/50 m (acero), además de props cercanos para
penetración, thin-shell e impulso. El acero disparable usa una respuesta base
legible sin subir la exposición global.

El disparo usa `SHOT_DB = -5.5`. Mecánica cercana actual:
`slide_battery -8 dB`, `magin -10 dB`, `slide_release -7 dB`,
`mag_insert -9 dB`. No hay limiter, ducking ni reverb añadida al blast cercano.

El contrato de combate es:

```text
intent
→ cadence/ammo
→ trajectory/occlusion
→ damage/material behavior
→ feedback
→ resulting state
```

## Verificación rápida

```bash
/home/alex/.local/bin/godot4 --headless --path . tools/check_weapon.tscn
/home/alex/.local/bin/godot4 --headless --path . tools/check_reload.tscn
/home/alex/.local/bin/godot4 --headless --path . tools/check_slide_lock.tscn
/home/alex/.local/bin/godot4 --headless --path . tools/check_weapon_fx.tscn
/home/alex/.local/bin/godot4 --headless --path . tools/check_range_shell.tscn
./tools/medir.sh
./tools/captura.sh
```

Los checks headless protegen contratos objetivos. No certifican por sí solos
agarre, anatomía, iluminación, legibilidad o calidad perceptual.

## Rendimiento de referencia

El baseline de 1080p nativo se mide con `tools/medir.sh`; las cifras anteriores
con reescalado no son criterio de aceptación para esta etapa. El objetivo mínimo
es **35 FPS a 1080p nativo** sin degradar calidad, legibilidad ni materiales.

No se declara una optimización por teoría: cada cambio de luces, sombras, rango
o culling debe demostrar frame time mejor y conservar la imagen en captura A/B.

## Documentación

- [Estado de producción](docs/PRODUCTION.md): Glock, viewmodel, rango, audio,
  balística y valores actuales.
- [Validación](docs/VALIDATION.md): QA, capturas, benchmarks, tooling y criterios
  para aceptar cambios.
- [Créditos de modelos](CREDITS_MODELS.md)
- [Créditos de texturas](CREDITS_TEXTURES.md)
- [Créditos de audio](CREDITS_AUDIO.md)

## Fuera de alcance

Multijugador, backend, cuentas, economía real, anuncios, ranking, chat, clans,
vehículos, campaña, loot, matchmaking, segunda arma, sistema genérico de armas,
IK runtime y expansión del rango como mapa de juego.

FlowFire busca más realidad con menos arquitectura: una Glock bien montada, dos
brazos que la agarran como una persona, un rango legible y una cadena
física/audiovisual cuya autoridad se pueda seguir sin adivinar.
