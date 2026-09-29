# REFS → CÓDIGO — dónde vive cada rasgo de las referencias

Este documento **no** sustituye a `docs/REFS.md` (el contrato visual del dueño).
Responde a una sola pregunta, y existe por un error real cometido el 2026-09-28:

> **¿Este rasgo de las referencias ya está implementado, y dónde?**

## Por qué existe (el falso negativo que lo motiva)

Se buscó `viñeta`, `fisheye` y `chromatic` en `scripts/`, `scenes/` y
`tools/*.py`, salió **0**, y se estuvo a punto de escribir un backlog con tres
desviaciones **inexistentes**: los tres rasgos **ya estaban**, en
`shaders/bodycam.gdshader`, que es un directorio que el `grep` no tocaba.

Dos formas de llegar a la conclusión contraria a la verdad, las dos medidas:

1. **Buscar sólo en `scripts/`.** Los efectos de lente viven en `shaders/`.
   Aplicado desde `scripts/HUD.gd` (combate) y `scripts/Lobby.gd` (lobby).
2. **Buscar en inglés.** El código nombra en español: `palé`, no `pallet`;
   `tragaluz`, no `skylight`. `pallet` da 0 y sin embargo **los palés existen**
   (`Pales_Patio` en `tools/build_props.py`).
3. **Buscar en el fichero equivocado.** `casco` en `tools/build_enemy.py` da 2,
   y esas 2 son comentarios explicando por qué ese builder **no** viste al
   enemigo: el equipo lo pone `tools/build_kit.py` (donde casco/chaleco/rifle
   dan 6/7/14). Un agente que concluyera "el enemigo no tiene casco" a partir de
   `build_enemy.py` construiría un casco que ya está hecho.

Antes de declarar que algo falta: `grep` en **todo** el árbol y en **los dos
idiomas**.

## Rasgos verificados (comando por fila)

Todo lo de esta tabla es reproducible con un `grep` sobre el árbol de hoy. La
columna *Dónde* es la que evita el trabajo duplicado: es el sitio al que hay que
ir para **cambiar** el rasgo, no para añadirlo.

| Rasgo (REFS) | Dónde vive | Valor / dato | Comando que lo prueba |
| --- | --- | --- | --- |
| Viñeta | `shaders/bodycam.gdshader` | `vignette` 1.0; cae de `r²=0,10` a `0,46` | `grep -n vignette shaders/bodycam.gdshader` |
| Fisheye / barril | `shaders/bodycam.gdshader` | `fisheye = 0.30` | `grep -n fisheye shaders/bodycam.gdshader` |
| Aberración cromática | `shaders/bodycam.gdshader` | `ca_edge = 0.012` (separa el canal rojo) | `grep -n ca_edge shaders/bodycam.gdshader` |
| Grano de sensor | `shaders/bodycam.gdshader` | `grain_amount = 0.0045` | idem |
| Pulso del AGC al disparo | `shaders/bodycam.gdshader` | `exposure_pulse` | idem |
| Cielo nublado (REF2) | `scripts/CombatMap.gd` `_lights()` + `scenes/Main.tscn` | sol 0,14 con tinte frío; ambiente 0,10–0,195 | `grep -n light_energy scripts/CombatMap.gd` |
| Palés del patio (REF2) | `tools/build_props.py` | `Pales_Patio` en `(2,90 / 6,90)` | `grep -n 'palé(' tools/build_props.py` |
| Graffiti (REF1/REF5) | `tools/build_house.py` | 17 referencias | `grep -rni graffiti tools/build_house.py \| wc -l` |
| Malla verde (REF2) | `tools/build_house.py` | 5 referencias | `grep -rni 'malla verde' tools/` |
| Enemigo: casco, chaleco, rifle (REF3) | **`tools/build_kit.py`** (el equipo; `build_enemy.py` sólo pone el cuerpo) | 6 / 7 / 14 referencias | `grep -rniE 'casco\|chaleco\|rifle' tools/build_kit.py \| wc -l` |
| Anillo/halo del arma (REF5) | `tools/` + `scripts/` | 14 coincidencias | `grep -rniE 'anillo\|halo' --include=*.gd --include=*.py . \| wc -l` |

## Huecos verificados (medidos, no supuestos)

| Rasgo (REFS) | Esperado | Medición | Sinónimos probados |
| --- | --- | --- | --- |
| **Tragaluz roto** (REF5 / `ref5.jpg`) | Tragaluz roto en la escalera | **0** en todo el árbol | `tragaluz`, `claraboya`, `lucernario`, `hatch`, `skylight` — los cinco dan 0 |

Es el **único** hueco duro que se ha podido verificar sin GPU. Los demás rasgos
de `REFS.md` (§2 y §3) exigen **comparar contra las imágenes**, y eso pide
capturas: no se declaran aquí para no repetir el error del falso negativo.

## Lo que este documento NO afirma

- No dice que el juego "se parezca" a las referencias. Eso se mide mirando las
  capturas, y aquí no se ha hecho.
- No dice que los valores de la tabla sean *correctos*: dice que **existen** y
  dónde están para ajustarlos.
- No sustituye a `docs/REFS.md` §3 (qué referencia manda en qué sistema), que es
  la autoridad cuando hay contradicción entre número de fichero y contenido.

## Regla al editar

Si un rasgo de la tabla se mueve de sitio o desaparece, **se corrige esta tabla
en el mismo commit** — igual que `docs/HOUSE_DESIGN.md` con sus números. Una
tabla que apunta a un fichero que ya no existe manda al siguiente agente a
construir algo que ya está hecho, que es exactamente el fallo que la motivó.
