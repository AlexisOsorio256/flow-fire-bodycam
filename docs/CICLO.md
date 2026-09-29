# CICLO — cómo trabaja un agente autónomo en este repositorio

Este documento **no** es la ficha del proyecto (`docs/HOUSE_DESIGN.md`) ni el
contrato visual (`docs/REFS.md`). Es el **protocolo de trabajo**: qué se
considera un avance, cómo se elige, cómo se prueba y cuándo un ciclo debe parar.

Se escribe una vez y no se reinterpreta. Si algo de aquí choca con
`README.md`, manda `README.md` (regla 12).

---

## 0. Cuántos trabajadores: UNO

**Un solo trabajador, secuencial.** No es una preferencia de estilo: es lo que
permite el árbol.

`scenes/House.tscn` y `assets/models/house.glb` son **cuello de botella**: de
ellos cuelgan la geometría, los 299 colisionadores, los 71 ocultadores, los
rectángulos de `CombatMap.ZONES`, el reparto de luces y la ruta de
`tools/check_walk.gd`. Dos trabajadores a la vez sobre ese fichero no producen
dos mejoras: producen un conflicto y una decisión duplicada, que es justo lo
que prohíbe la regla 5 (*"si dos sitios pueden decidir lo mismo, sobra uno"*).

Fronteras que **sí** son reales en este repo, por si algún día hacen falta:

| Frente | Escribe | Lee como autoridad |
| --- | --- | --- |
| Casa | `build_house.py` → `house.glb`, `House.tscn` | — |
| Props / kit | `build_props.py`, `build_kit.py` → `props.glb` | `House.tscn` **solo lectura** |
| Arma / brazos | `build_arms.py` → `fps_arms.glb`, `g19_pistol.glb` | — |
| Enemigo | `build_enemy.py` → `enemy.glb` | — |
| Runtime | `scripts/*.gd`, `scenes/Main.tscn` | los GLB ya exportados |

**Condiciones para pasar a 3 trabajadores** (las tres a la vez, ninguna
negociable). Si no se cumplen las tres, se trabaja con uno:

1. Cada trabajador en su **worktree** (`git worktree add`), nunca el mismo árbol.
2. **Ficheros disjuntos** según la tabla de arriba. Dos frentes que compartan un
   fichero no pueden correr a la vez, ni con worktrees.
3. Un **único gate** (`./tools/verificar.sh`) sobre el resultado ya integrado.
   Cada trabajador corre `verificar.sh` en su worktree antes de proponer el
   merge, pero el verde que cuenta es el del árbol integrado.

Con menos de las tres, el paralelismo es sobreingeniería (regla 4) y produce
exactamente el problema que este documento existe para evitar.

---

## 1. Objetivo inmutable del ciclo

> **En cada ciclo, identifica la desviación más importante entre el proyecto
> actual y su especificación, corrígela por completo y deja el proyecto
> objetivamente más cerca de esa especificación.**

Ese es el objetivo. Lo que sigue no lo amplía ni lo suaviza: lo hace
**ejecutable**, porque "la especificación" tiene que ser algo que un verificador
pueda decidir sin opinar.

---

## 2. Qué es "la especificación" (el árbitro)

Sólo estas tres fuentes, **en este orden de prioridad**. Ninguna otra cosa es
una desviación.

1. **Rojo en `./tools/verificar.sh`.** Dos fases: `parse` (29 scripts) e
   `import/recursos`, y luego **7 checks** (`weapon`, `reload`, `slide_lock`,
   `weapon_fx`, `walk`, `enemy`, `hechos`). Un rojo se corrige antes que
   cualquier otra cosa.
2. **Un número que la ficha publica y el proyecto ya no cumple.** Lo decide
   `tools/check_hechos.gd`, que lee el proyecto vivo y compara contra
   `docs/HOUSE_DESIGN.md` y `docs/REFS.md`. Si el proyecto cambió y la ficha no,
   o la ficha dice algo que ya no es verdad, eso es una desviación.
3. **Un incumplimiento medido de una referencia de `docs/refs/`.** Sólo cuenta
   si la medida se escribió **antes** del cambio y con un comando reproducible
   sobre un fichero que existe hoy (regla de `docs/REFS.md`).

Lo que **no** es una desviación y no autoriza un ciclo:

- Una opinión sobre lo que "quedaría mejor".
- Una referencia que no se ha medido todavía.
- Un número nuevo publicado para tapar uno viejo incumplido.
- Refactorizar por gusto sin un rojo o una medida que lo justifique.

`README.md` es la constitución y **no se toca nunca** en un ciclo (regla 12). Si
una desviación exigiera cambiarla, el ciclo **para y pregunta al dueño**.

---

## 3. Protocolo del ciclo (obligatorio, en este orden)

### Antes de tocar

1. **Elegir la desviación** por el orden de §2. Si hay varias del mismo nivel, la
   de mayor impacto medido.
2. **Escribir el comando que la reproduce y su número.** Sin esto el ciclo no
   empieza. "Medir antes de afirmar" (regla 9) no es un consejo: es la puerta de
   entrada.
3. **Escribir qué número debería salir** si el arreglo es correcto. Un criterio
   de éxito escrito *a posteriori* no vale.

### Al tocar

4. **Una autoridad por comportamiento** (regla 5). Si el arreglo introduce una
   segunda fuente de verdad para algo que ya tenía una, el arreglo está mal
   aunque pase el test. Caso real: los vanos del muro y la carpintería eran dos
   listas con las mismas cotas escritas dos veces; al ampliar la casa se
   desincronizaron y un tramo sólido cayó sobre la puerta.
5. **Si el cambio mueve un número que la ficha publica, se corrige la ficha en
   el mismo commit.** La ficha es `docs/HOUSE_DESIGN.md`. Un cambio que deja la
   ficha mintiendo es un ciclo fallido, no un ciclo pendiente.
6. **`README.md` no se toca.** Ni `docs/refs/`. Si hace falta, se para.
7. **No se añade un test que no falsifique una duda real** (regla 8) ni una
   pieza que no justifique su coste (regla 3).

### Después de tocar

8. **`./tools/verificar.sh` verde**, con parse, import y los 7 checks.
9. **Repetir la medida del paso 2 con el mismo comando.** Si el número no mejora
   según el criterio del paso 3, **se revierte**. No se deja a medias con la
   esperanza de que el siguiente ciclo lo arregle.
10. **Si el cambio toca el render o la geometría**, medir con
    `tools/medir.sh base` (objetivo constitucional: 40 FPS estables, regla 2) y
    actualizar la tabla `perfil` de la ficha. Calidad y rendimiento pesan igual
    (regla 1): una mejora visual que rompa los 40 FPS no es una mejora.
11. **Commit con el qué y el por qué.** Si el ciclo se revirtió, se dice.

---

## 4. Parada (un resultado válido, no un fracaso)

El ciclo **termina y lo reporta** cuando no hay ninguna desviación que cumpla §2:
sin rojo en el gate, sin número desviado en `check_hechos` y sin referencia
incumplida **medida**.

Eso es un resultado correcto. **No se inventa trabajo para seguir.** En un
proyecto mantenido al 100 % por IA, un ciclo que se niega a parar es exactamente
el camino a "más documentación que proyecto": cambios que parecen avance porque
el agente se autoevalúa con un criterio que él mismo eligió.

Se para **y se pregunta al dueño** (no se decide solo) cuando:

- el arreglo exige cambiar `README.md` o una referencia de `docs/refs/`;
- el arreglo exige una decisión de arte que la especificación no cubre (por
  ejemplo, mover un mueble que tapa una ruta: el check avisa, pero moverlo es
  decisión de arte);
- dos desviaciones del mismo nivel se contradicen entre sí;
- el arreglo no se puede medir con ningún comando reproducible.

Se declara **bloqueado** sólo si la misma condición concreta impide avanzar
durante 3 ciclos seguidos, y se dice cuál es esa condición. Dificultad,
incertidumbre o "queda trabajo útil" **no** son bloqueo.

---

## 5. Ejemplos del propio repo (para que no haya que interpretar)

**Un ciclo bien elegido.** El gate `walk` se puso rojo al ampliar la casa ×1,25.
Prioridad 1 (§2.1), comando `godot4 --headless --path . tools/check_walk.tscn`,
número: *"encallado a 2,46 m de porche y vano de la puerta"*. La corrección fácil
—escalar las cotas de la ruta ×1,25— **se intentó y no arregló nada**: el
jugador seguía clavado en z=6,06. La causa real era que `front_holes` estaba en
coordenadas absolutas mientras la hoja de la puerta estaba centrada: dos
autoridades del mismo vano. Se unificó (§3.4) y quedó verde. El criterio de
éxito era *"el jugador cruza de la fachada al fondo"*, escrito antes.

**Un ciclo mal elegido.** "Los mipmaps se ven borrosos, añado más resolución."
Sería un cambio que *parece* acercarse a `ref2` sin medir nada: la causa real
estaba en `mipmaps/generate=false` y en `compress/normal_map` en 12 texturas, y
lo que lo decidió fue medir los `.import`, no una impresión.

**La trampa a evitar.** Un gate que pasa porque el test se relajó no es un gate
verde. Si el arreglo de una desviación consiste en cambiar el test, la carga de
la prueba es demostrar que el test estaba **mal** y por qué, no que era
incómodo.

---

## 6. Resumen en una línea

Un trabajador. Una desviación por ciclo, elegida contra un árbitro externo
(gate rojo → número desviado → referencia medida), con el número escrito antes y
después. Si no hay desviación, el ciclo **para y lo dice**.
