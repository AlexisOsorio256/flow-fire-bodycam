# FlowFire

FlowFire es un juego centrado en una sola Glock 19: ciclo mecánico, disparo,
proyectil, material, penetración, reacción física, audio y feedback visual.
El rango es un instrumento de medición abierto, no un mapa de juego.

Estado técnico: Godot 4.7.2 Standard, renderer Mobile, GDScript y Jolt. La
prioridad del proyecto es **estabilidad → gameplay/game feel → rendimiento →
UX → inmersión → features**.

## Contrato de producción

- `main` es la única rama de producción.
- Una autoridad por comportamiento. `Glock.gd` decide la mecánica; los demás
  sistemas representan, reproducen o miden ese estado.
- Una sola ruta de producción: sin managers genéricos, fallbacks activos,
  sistemas legacy ni piezas procedurales de reserva.
- Asset/pose/UV/origen/rig se corrige en Blender; mecánica/física/audio runtime
  se corrige en Godot o tooling offline mínimo.
- Material + geometría + velocidad entran a `Ballistics.gd`; la resistencia
  vive únicamente en `Ballistics.MATERIALS`.
- Toda mejora exige su prueba: visual → captura real, rendimiento → benchmark
  de render, audio → inspección de WAV y mezcla. Nada se declara por teoría.
- Git conserva la historia. README y créditos describen sólo el estado vivo.

## Estado actual

- Una Glock 19 Gen5 de referencia; no existe una segunda arma. La ficha
  física vive en `GlockWeapon.gd` y la valida `check_weapon`.
- Viewmodel con brazos obligatorios (`fps_arms.glb`, cinco clips horneados,
  sin IK runtime); el asset se autora ya en el espacio del arma.
- Rango interior abierto con LightmapGI horneado; las 13 luminarias son
  fuentes de autoría y no se evalúan por píxel durante el juego.
- Carcasa canónica: 31 mallas, 7 materiales PBR obligatorios.
- Audio cercano de Glock directo a `Master`; mundo/impactos por
  `World -> Range -> Master`.
- Salida y raster 3D: **1920×1080 nativo** con MSAA 2x. El reescalado interno
  queda descartado como estrategia de rendimiento.
- El HUD muestra exactamente: `Creador: Alexis Osorio BETA 1`.

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
| Estaciones y props disparables | `scripts/World.gd`, `Target.gd` |

La escena principal es `scenes/Main.tscn`. Los autoloads son `GameAudio`,
`ImpactFX` y `Ballistics`.

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

`tools/medir.sh` mide el render real a 1080p nativo con el MSAA del proyecto.
El baseline de reposo ronda **39 FPS** en la HD 520 de referencia y el estrés
de disparo **~29-30 FPS**; la cámara de trabajo es acercarse a 45 sin tocar
calidad. No se declara una optimización por teoría: cada cambio exige frame
time mejor (media, p95 y p99) con la misma imagen o mejor en captura A/B.

## Créditos

- [Modelos](CREDITS_MODELS.md)
- [Texturas](CREDITS_TEXTURES.md)
- [Audio](CREDITS_AUDIO.md)

## Fuera de alcance

Multijugador, backend, cuentas, economía real, anuncios, ranking, chat, clans,
vehículos, campaña, loot, matchmaking, segunda arma, sistema genérico de armas,
IK runtime y expansión del rango como mapa de juego.

FlowFire busca más realidad con menos arquitectura: una Glock bien montada, dos
brazos que la agarran como una persona, un rango legible y una cadena
física/audiovisual cuya autoridad se pueda seguir sin adivinar.
