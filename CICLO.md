# CICLO — protocolo de un agente autónomo

No es la ficha (`docs/HOUSE_DESIGN.md`) ni el contrato visual (`docs/REFS.md`).
Si algo de aquí choca con `README.md`, manda `README.md` (regla 12).

**Objetivo inmutable, un ciclo:**

> En cada ciclo, identifica la desviación más importante entre el proyecto actual
> y su especificación, corrígela por completo y deja el proyecto objetivamente
> más cerca de esa especificación.

## 1. El árbitro: qué es "la especificación"

Sólo estas tres fuentes, **por este orden**. Ninguna otra cosa autoriza un ciclo.

1. **Rojo en `./tools/verificar.sh`** — fase `parse` (29 scripts) + `import`, y
   **7 checks**: `weapon`, `reload`, `slide_lock`, `weapon_fx`, `walk`, `enemy`,
   `hechos`. Un rojo se corrige antes que nada.
2. **Un número que la ficha publica y el proyecto ya no cumple.** Lo decide
   `tools/check_hechos.gd`, que lee el proyecto vivo y lo compara contra
   `docs/HOUSE_DESIGN.md` y `docs/REFS.md`.
3. **Un incumplimiento medido de `docs/refs/`**, con el comando reproducible
   escrito **antes** del cambio.

No es una desviación: una opinión, una referencia sin medir, o refactorizar por
gusto sin un rojo o una medida que lo justifique.

## 2. El ciclo

**Antes de tocar:** elegir por §1 y **escribir el comando y el número** que la
miden, más el número que debería salir si el arreglo es correcto.

**Al tocar:** una autoridad por comportamiento (regla 5); si el cambio mueve un
número publicado, **corregir la ficha en el mismo commit**; `README.md` y
`docs/refs/` no se tocan nunca (si hiciera falta, el ciclo para).

**Después de tocar:** `./tools/verificar.sh` verde; repetir la medida con el
mismo comando y, si no mejora, **revertir**; si toca render o geometría, medir con
`tools/medir.sh` (40 FPS, regla 2).

## 3. Parada

Sin rojo, sin número desviado y sin referencia medida incumplida, el ciclo
**termina y lo dice**: es un resultado válido, no un fracaso. **No se inventa
trabajo para seguir.** Se **para y se pregunta al dueño** si hay que cambiar
`README.md` o `docs/refs/`, si es una decisión de arte que la especificación no
cubre, si dos desviaciones del mismo nivel se contradicen, o si el arreglo no es
medible. Se declara **bloqueado** sólo tras 3 ciclos con la misma condición.

## 4. Un trabajador

`scenes/House.tscn` y `assets/models/house.glb` son cuello de botella: de ellos
cuelgan la geometría, los colisionadores, `CombatMap.ZONES`, las luces y la ruta
de `tools/check_walk.gd`. Tres trabajadores sólo si se dan **las tres**: worktrees
separados, ficheros disjuntos y un solo gate sobre el árbol integrado.
