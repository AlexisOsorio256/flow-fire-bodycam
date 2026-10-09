import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)

from piezas import Escena

ANCHO = 52.0
FONDO = 42.0
ALTO = 9.0
PI2 = math.pi * 0.5

CASAS = [
    (-50.0, -40.0, -40.0, -30.0, 6.5, "s", "cal"),
    (-37.0, -40.0, -31.0, -30.0, 6.5, "s", "ocre"),
    (-50.0, -27.0, -36.0, -24.0, 4.0, "n", "cal"),
    (34.0, -40.0, 42.0, -29.0, 6.5, "s", "cal"),
    (45.0, -40.0, 51.0, -30.0, 6.5, "w", "ocre"),
    (-50.0, 30.0, -40.0, 40.0, 6.5, "e", "ocre"),
    (-36.0, 28.0, -31.0, 40.0, 4.0, "e", "cal"),
    (34.0, 30.0, 44.0, 40.0, 6.5, "n", "cal"),
    (47.0, 30.0, 51.0, 40.0, 6.5, "w", "ocre"),
    (-24.0, -19.0, -12.0, -10.0, 4.0, "e", "cal"),
    (-9.0, -19.0, -5.0, -10.0, 6.5, "w", "ocre"),
    (6.0, -19.0, 14.0, -10.0, 6.5, "w", "cal"),
    (17.0, -19.0, 24.0, -9.0, 4.0, "s", "ocre"),
    (-24.0, 6.0, -14.0, 16.0, 6.5, "e", "cal"),
    (-10.0, 8.0, -4.0, 17.0, 4.0, "n", "ocre"),
    (6.0, 6.0, 14.0, 15.0, 4.0, "w", "cal"),
    (17.0, 8.0, 25.0, 17.0, 6.5, "n", "cal"),
]


def casa(e, x0, z0, x1, z1, h, puerta, material):
    paredes = [
        ((x0, z0), (x1, z0), "n"),
        ((x1, z1), (x0, z1), "s"),
        ((x0, z1), (x0, z0), "o"),
        ((x1, z0), (x1, z1), "e"),
    ]
    for a, b, lado in paredes:
        largo = math.hypot(b[0] - a[0], b[1] - a[1])
        aberturas = []
        if lado == puerta:
            aberturas.append((largo * 0.5 - 0.6, largo * 0.5 + 0.6, 0.0, 2.2))
        for s in (largo / 3.0, 2.0 * largo / 3.0):
            if lado == puerta and abs(s - largo * 0.5) < 1.6:
                continue
            aberturas.append((s - 0.5, s + 0.5, 1.6, 2.6))
            if h >= 6.0:
                aberturas.append((s - 0.5, s + 0.5, 4.0, 5.0))
        e.muro(material, a, b, h, 0.4, aberturas, "concrete", "casa_%s" % lado)
    e.caja("hormigon", ((x0 + x1) * 0.5, h + 0.15, (z0 + z1) * 0.5),
           (x1 - x0 + 0.6, 0.3, z1 - z0 + 0.6), 0.0, 0.02)
    e.colisor("concrete", "azotea", ((x0 + x1) * 0.5, h + 0.15, (z0 + z1) * 0.5), (x1 - x0 + 0.6, 0.3, z1 - z0 + 0.6))
    if h >= 6.0:
        e.cilindro("oxido", (x0 + 1.2, h + 0.3, z0 + 1.2), 0.8, 1.4, 24)


def perimetro(e):
    mx = ANCHO + 0.5
    mz = FONDO + 0.5
    e.muro("ocre", (-mx, -mz), (mx, -mz), ALTO, 1.0, (), "concrete", "muro_norte")
    e.muro("ocre", (mx, mz), (-mx, mz), ALTO, 1.0, (), "concrete", "muro_sur")
    e.muro("ocre", (-mx, mz), (-mx, -mz), ALTO, 1.0, (), "concrete", "muro_oeste")
    e.muro("ocre", (mx, -mz), (mx, mz), ALTO, 1.0, (), "concrete", "muro_este")
    for x in range(-48, 49, 8):
        e.caja("ocre", (x, ALTO * 0.5, -FONDO + 0.25), (0.9, ALTO, 0.5))
        e.caja("ocre", (x, ALTO * 0.5, FONDO - 0.25), (0.9, ALTO, 0.5))
    for z in range(-32, 33, 8):
        e.caja("ocre", (-ANCHO + 0.25, ALTO * 0.5, z), (0.5, ALTO, 0.9))
        e.caja("ocre", (ANCHO - 0.25, ALTO * 0.5, z), (0.5, ALTO, 0.9))
    e.caja("piedra", (0.0, ALTO + 0.15, -mz), (2 * mx + 1.0, 0.3, 1.2))
    e.caja("piedra", (0.0, ALTO + 0.15, mz), (2 * mx + 1.0, 0.3, 1.2))
    e.caja("piedra", (-mx, ALTO + 0.15, 0.0), (1.2, 0.3, 2 * mz + 1.0))
    e.caja("piedra", (mx, ALTO + 0.15, 0.0), (1.2, 0.3, 2 * mz + 1.0))


def construir(e):
    e.importar()

    e.caja("arena", (0.0, -0.25, 0.0), (2 * ANCHO, 0.5, 2 * FONDO), 0.0)
    e.colisor("concrete", "suelo", (0.0, -0.25, 0.0), (2 * ANCHO, 0.5, 2 * FONDO))
    perimetro(e)

    for x0, z0, x1, z1, h, puerta, material in CASAS:
        casa(e, x0, z0, x1, z1, h, puerta, material)

    e.utileria("firepit_01__stone_fire_pit", (0.0, 0.0), 0.0, ("concrete", "pozo"))
    e.utileria("car_01", (9.0, 0.0), PI2, ("steel", "coche"))
    e.utileria("car_01", (-22.0, -36.0), 0.0, ("steel", "coche"))
    for x, z in ((0.0, -9.0), (0.0, 9.0), (-9.0, 0.0), (13.0, -1.5), (-13.0, 1.5), (30.0, -1.5)):
        e.utileria("lamp_01__street_lamp_01", (x, z))
    for x, z in ((-2.4, -18.0), (2.4, 13.0), (-2.4, 28.0)):
        e.utileria("hydrant_01__fire_hydrant", (x, z), 0.0, ("steel", "hidrante"))
    for x, z in ((-1.8, 9.0), (1.8, -9.0), (2.2, 14.0), (-2.2, -30.0)):
        e.utileria("barrels_01__wooden_barrels_01_barrel01", (x, z), 0.0, ("barrel", "barril"))
    for x, z in ((-9.5, 2.0), (-9.1, 2.5)):
        e.utileria("tyre_01__old_tyre", (x, z), 0.0, ("steel", "neumatico"))
    cajas_pila(e, -2.6, -1.8, [(0.0, 0.0, 2), (1.0, 0.0, 1)])
    cajas_pila(e, -26.0, -35.0, [(0.0, 0.0, 2), (1.0, 0.0, 2)])
    cajas_pila(e, 20.0, 36.0, [(0.0, 0.0, 2)])
    cajas_carton(e, 4.0, 1.0, [(0.0, 0.0, 2), (0.6, 0.0, 1)])

    for x, z in ((-40.0, -21.5), (-30.0, -21.5), (34.0, -21.5), (40.0, 21.5)):
        e.caja("ocre", (x, 1.1, z), (4.0, 2.2, 0.5), 0.0, 0.02)
        e.colisor("concrete", "tapia", (x, 1.1, z), (4.0, 2.2, 0.5))

    for (ax, az), (bx, bz) in (((14.5, -5.5), (26.5, -5.5)), ((-30.0, -8.0), (-24.5, -8.0)),
                               ((-14.0, 22.0), (-4.0, 22.0)), ((6.0, 22.5), (14.0, 22.5)),
                               ((-44.0, 8.0), (-38.0, 8.0)), ((34.0, 16.0), (44.0, 16.0))):
        e.muro("ocre", (ax, az), (bx, bz), 2.6, 0.5, (), "concrete", "tapia")

    e.marca("home_0", -45.0, -35.0)
    e.marca("home_1", 39.0, 35.0)
    posiciones = [
        (-28.5, -29.0), (-20.0, -34.0), (-14.0, -24.0), (-20.0, -15.0), (-30.0, -6.0),
        (-44.0, -2.0), (-26.0, 26.0), (-18.0, 34.0), (-6.0, 36.0), (0.0, -14.0),
        (0.0, 14.0), (-12.0, 0.0), (12.0, 0.0), (-4.0, -27.0), (30.0, 34.0),
        (20.0, 34.0), (26.0, 22.0), (30.0, 10.0), (16.0, -28.0), (30.0, -16.0),
    ]
    for i, (x, z) in enumerate(posiciones, start=1):
        libre = e.solapa(x, z)
        if libre is not None:
            print("PUESTO EN OBJETO", i, x, z, libre)
        e.marca("post_%02d" % i, x, z)


def cajas_pila(e, x, z, filas):
    for dx, dz, n in filas:
        for k in range(n):
            centro = (x + dx, 0.45 + k * 0.9, z + dz)
            e.caja("caja", centro, (1.0, 0.9, 0.9), 0.0, 0.03)
            e.colisor("pine", "caja", centro, (1.0, 0.9, 0.9))


def cajas_carton(e, x, z, filas):
    for dx, dz, n in filas:
        for k in range(n):
            centro = (x + dx, 0.3 + k * 0.6, z + dz)
            e.caja("carton", centro, (0.6, 0.6, 0.6), 0.0, 0.02)
            e.colisor("paper", "carton", centro, (0.6, 0.6, 0.6))


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    e = Escena()
    construir(e)
    e.guardar(os.path.join(REPO, "blender", "callejones.blend"))
    e.exportar(os.environ.get("MAPA_SALIDA") or os.path.join(REPO, "assets", "models", "callejones.glb"))
    print("CALLEJONES LISTO", len(e.estatica.objects), "piezas", len(e.colisiones.objects), "colisiones", len(e.utilerias.objects), "utilerias")


main()
