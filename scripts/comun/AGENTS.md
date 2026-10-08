# Común

Piezas sin dominio propio que usan varios: `Springs` integra muelles
amortiguados (cámara, retroceso, reacciones). Solo entra aquí lo que usan dos
dominios o más.

Usa: -
Checks: arma, enemigos, dano

## Deuda

- Pendiente: el mismo muelle está escrito cuatro veces (`Springs`, `WeaponAction`, `BodyCam`, `PlayerDeath`) con tres pasos distintos (adaptativo de hasta 96, fijo de 0,0025 y delta crudo a 30 FPS): unificarlo cambia la sensación y hay que medirla y verla.
