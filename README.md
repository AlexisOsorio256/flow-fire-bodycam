# FlowFire

FlowFire es un FPS de cámara bodycam donde todo gira en torno a una sola
Glock 19: ciclo mecánico, disparo, proyectil, penetración, reacción física,
audio y feedback. El rango no es un mapa de juego: es el instrumento de
medición donde se prueba y calibra cada cadena.

Va hacia más realidad con menos arquitectura —estabilidad y game feel
primero, después rendimiento, UX e inmersión— con evidencia obligatoria,
nunca teoría. Estado: Godot 4.7.2 Standard, GDScript, Forward Mobile, Jolt.

## Contrato

- `main` es la única rama; git conserva la historia.
- Una autoridad por comportamiento: `Glock.gd` decide la mecánica; el resto
  representa, reproduce o mide. Sin managers, fallbacks ni sistemas legacy.
- Asset/pose/UV/rig → Blender; mecánica/física/audio → Godot o tooling
  offline mínimo.
- Material + geometría + velocidad entran a `Ballistics.gd`; las resistencias
  viven únicamente en `Ballistics.MATERIALS`.
- Nada se declara por teoría: visual → captura A/B, rendimiento → benchmark
  de render, audio → WAV medido.

## Qué hay hoy

- Una Glock 19 Gen5 de referencia (`GlockWeapon.gd`, validada por
  `check_weapon`); no existe una segunda arma.
- Viewmodel con brazos obligatorios: cinco clips horneados, sin IK runtime.
- Rango interior con LightmapGI horneado; 13 luminarias de autoría que no se
  evalúan por píxel. Carcasa canónica: 31 mallas, 7 materiales PBR.
- Salida 1920×1080 nativa con MSAA 2x; el reescalado interno queda descartado.
- Audio: Glock cercano directo a `Master`; mundo/impactos por
  `World -> Range -> Master`.
- HUD exacto: `Creador: Alexis Osorio BETA 1`.

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

La escena principal es `scenes/Main.tscn`; los autoloads son `GameAudio`,
`ImpactFX` y `Ballistics`.

## Verificación rápida

```bash
for t in weapon reload slide_lock weapon_fx range_shell; do
  /home/alex/.local/bin/godot4 --headless --path . tools/check_$t.tscn
done
./tools/medir.sh
./tools/captura.sh
```

Los checks headless protegen contratos objetivos; no certifican por sí solos
agarre, anatomía, iluminación ni legibilidad perceptual.

## Rendimiento de referencia

`tools/medir.sh` mide el render real a 1080p con el MSAA del proyecto. El
baseline de reposo ronda **39 FPS** en la HD 520 de referencia y el estrés
de disparo **~29-30 FPS**; la meta es acercarse a 45 sin tocar calidad. Cada
cambio exige frame time mejor (media, p95 y p99) con la misma imagen o mejor
en captura A/B.

## Créditos

- [Modelos](CREDITS_MODELS.md)
- [Texturas](CREDITS_TEXTURES.md)
- [Audio](CREDITS_AUDIO.md)

## Fuera de alcance

Multijugador, backend, cuentas, economía real, anuncios, ranking, chat, clans,
vehículos, campaña, loot, matchmaking, segunda arma, sistema genérico de
armas, IK runtime y expansión del rango como mapa de juego.
