---
name: correccion-visual
description: Acerca el juego a la referencia visual en vueltas de UN cambio, con captura, medida, gate y reversión si no mejora. Úsala cuando el objetivo sea calidad visual o perceptual contra docs/refs/ (luz, materiales, escala de textura, encuadre, viewmodel).
---

# Corrección visual en bucle

Una vuelta = una desviación = un cambio. Nunca dos cambios en la misma vuelta.

## 1. Fotogramas de referencia

Extráelos del vídeo; no trabajes de memoria. El viewport del editor está en
x=160, y=50, 1000x596: los paneles (Place Actors, Outliner, Content Browser) son
gris plano y contaminan media, p95 y esquinas si se miden con ellos.

```
ffmpeg -y -i "docs/refs/recrear esta calidad perceptual. para flowfire bodycam.mp4" \
  -vf "crop=1000:596:160:50,fps=2" -q:v 2 /tmp/ref/f_%04d.png
```

## 2. Captura del estado actual

```
SHOT_OUT=captures/loop tools/captura.sh patio --warmup=80 --total=2
SHOT_OUT=captures/loop tools/captura.sh downrange --warmup=70 --total=2
SHOT_OUT=captures/loop tools/captura.sh back --warmup=80 --total=2
```

Y para movimiento, arma y audio (graba 1920x1080 30 fps **con el audio del juego**):

```
SHOT_OUT=captures/loop/hero.mp4 tools/captura.sh record_normal
```

`captura.sh` abre ventana: si el sandbox de terminal lo bloquea, pide permiso para lanzarla
fuera del sandbox. Encuadres disponibles en `tools/shot.gd::_place_combat`.

## 3. Mirar y medir

El agente acepta **imagen, vídeo y audio nativos**: pide al humano que pegue en el chat el vídeo
de referencia y tu `hero.mp4` (con su audio) o los pares de captura, y compáralos directamente.
Para el audio, el contraste útil es el disparo y la recarga contra `assets/audio/`.

```
python3 tools/measure_perceptual.py captures/loop
python3 tools/measure_perceptual.py /tmp/ref
```

Anota luminancia media, p5, p95, saturación y energía de esquinas. Y nombra la desviación de
forma concreta: QUÉ elemento, en QUÉ encuadre, contra QUÉ fotograma. "Se ve plano" o "falta
ambiente" no son desviaciones, son opiniones.

## 4. Decidir

Elige UNA desviación, la de más impacto visual por línea tocada. Antes de editar escribe el
comando de medida y el número que debería salir si el arreglo es correcto. Sin ese número, no
se edita.

## 5. Editar lo mínimo

Una autoridad por comportamiento. Si el cambio mueve un número publicado en
`docs/MAP.md`, corrige la ficha en el mismo cambio.

## 6. Verificar

```
./tools/verificar.sh      # GREEN obligatorio
tools/medir.sh base       # sólo si tocaste render o geometría: p50 <= 25 ms
```

Repite la medida del paso 3 con el MISMO comando. Si no mejora, **revierte**. Sin excepciones
y sin "casi mejora".

## 7. Cerrar la vuelta

Deja un Walkthrough con estos seis datos, siempre los mismos:

1. Desviación elegida y fotograma de referencia contra el que compites.
2. Comando de medida.
3. Número antes y número después.
4. Fichero:línea tocados y líneas netas.
5. Salida de `./tools/verificar.sh`.
6. Ruta de la captura nueva y si el cambio se queda o se revierte.

## Árbol de decisión

- **¿El cambio no mueve ningún número medible?** Entonces no es una desviación medible: párate y
  pregunta al dueño (§3 de `CICLO.md`).
- **¿El gate se pone rojo?** Has roto algo real. Arregla la causa; no toques el gate.
- **¿Dos desviaciones del mismo nivel se contradicen?** Párate y pregunta; no elijas tú.
- **¿El arreglo pide una capa o un sistema nuevo?** Es sobreingeniería (regla 4): busca la
  autoridad que ya existe.
