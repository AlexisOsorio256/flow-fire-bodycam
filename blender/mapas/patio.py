import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)

from piezas import Escena, cajas_carton, cajas_pila, comprobar_base

ANCHO = 56.0
FONDO = 38.0
ALTO = 8.5
PI2 = math.pi * 0.5


def contenedores_fila(e, x0, z, largos, colores, apilado=()):
    x = x0
    for i, largo in enumerate(largos):
        centro = (x + largo * 0.5, 1.295, z)
        e.caja(colores[i % len(colores)], centro, (largo, 2.59, 2.44), 0.0, 0.02)
        e.colisor("steel", "contenedor", centro, (largo, 2.59, 2.44))
        if i in apilado:
            arriba = (x + largo * 0.5, 2.59 + 1.295, z)
            e.caja(colores[(i + 1) % len(colores)], arriba, (largo, 2.59, 2.44), 0.0, 0.02)
            e.colisor("steel", "contenedor_alto", arriba, (largo, 2.59, 2.44))
        x += largo + 0.25


def contenedores_columna(e, x, z0, largos, colores):
    z = z0
    for i, largo in enumerate(largos):
        centro = (x, 1.295, z + largo * 0.5)
        e.caja(colores[i % len(colores)], centro, (largo, 2.59, 2.44), PI2, 0.02)
        e.colisor("steel", "contenedor_col", centro, (largo, 2.59, 2.44), PI2)
        z += largo + 0.25


def silo(e, x, z, radio, alto):
    e.cilindro("chapa", (x, 0.0, z), radio, alto, 32, radio)
    e.cilindro("oxido", (x, alto, z), radio, 1.4, 32, 0.3)
    e.colisor_cilindro("steel", "silo", (x, 0.0, z), radio, alto)
    e.cilindro("hormigon", (x, 0.0, z), radio + 0.9, 0.25, 32)
    for h in (2.5, 5.0, 7.5):
        e.cilindro("oxido", (x, h, z), radio + 0.05, 0.18, 32)
    for dx in (-0.3, 0.3):
        e.caja("oxido", (x + dx, alto * 0.5, z + radio + 0.25), (0.08, alto, 0.08))
    for k in range(9):
        e.caja("oxido", (x, 1.0 + k * 0.9, z + radio + 0.25), (0.6, 0.05, 0.06))


def dique_muelle(e):
    e.caja("hormigon", (31.9, 0.55, -12.25), (3.6, 1.1, 4.5), 0.0, 0.03)
    e.colisor("concrete", "anden", (31.9, 0.55, -12.25), (3.6, 1.1, 4.5))
    e.caja("hormigon", (31.9, 0.55, 8.75), (3.6, 1.1, 11.0), 0.0, 0.03)
    e.colisor("concrete", "anden", (31.9, 0.55, 8.75), (3.6, 1.1, 11.0))


def caseta_bombas(e, x, z):
    mx, mz = 3.0, 2.5
    e.muro("hormigon", (x - mx, z + mz), (x - mx, z - mz), 3.4, 0.35, (), "concrete", "caseta_o")
    e.muro("hormigon", (x - mx, z - mz), (x + mx, z - mz), 3.4, 0.35,
           [(2.6, 3.4, 1.2, 2.4)], "concrete", "caseta_n")
    e.muro("hormigon", (x + mx, z - mz), (x + mx, z + mz), 3.4, 0.35, (), "concrete", "caseta_e")
    e.muro("hormigon", (x + mx, z + mz), (x - mx, z + mz), 3.4, 0.35,
           [(2.6, 3.9, 0.0, 2.2)], "concrete", "caseta_s")
    e.caja("hormigon", (x, 3.55, z), (mx * 2 + 0.6, 0.3, mz * 2 + 0.6), 0.0, 0.02)
    e.colisor("concrete", "caseta_techo", (x, 3.55, z), (mx * 2 + 0.6, 0.3, mz * 2 + 0.6))
    e.caja("oxido", (x - 1.0, 4.1, z + mz + 0.4), (1.6, 0.9, 0.6), 0.0, 0.02)


def detalles_nave(e):
    for z in (-7.5, 1.5):
        e.caja("oxido", (34.0, 3.5, z), (0.6, 0.6, 3.2), 0.0, 0.02)
    for y in (6.85,):
        e.caja("oxido", (33.85, y, 0.0), (0.3, 0.3, 30.0))
        e.caja("oxido", (52.15, y, 0.0), (0.3, 0.3, 30.0))
    for x, z in ((33.8, -14.6), (33.8, 14.6), (52.2, -14.6), (52.2, 14.6)):
        e.caja("oxido", (x, 3.5, z), (0.14, 7.0, 0.14))
    e.caja("oxido", (39.0, 2.6, 15.9), (2.6, 0.2, 1.2), 0.0, 0.02)


def detalles_oficinas(e):
    e.utileria("shelf_01", (-50.6, -21.0), PI2, ("steel", "estanteria"))
    e.utileria("generator_01", (-49.0, -28.6), 0.0, ("steel", "generador"))
    e.utileria("compressor_01", (-47.6, -22.0), 0.0, ("steel", "compresor"))


def construir(e):
    e.importar()

    e.caja("hormigon", (0.0, -0.25, 0.0), (2 * ANCHO, 0.5, 2 * FONDO), 0.0)
    e.colisor("concrete", "suelo", (0.0, -0.25, 0.0), (2 * ANCHO, 0.5, 2 * FONDO))

    mx = ANCHO + 0.5
    mz = FONDO + 0.5
    e.muro("hormigon", (-mx, -mz), (mx, -mz), ALTO, 1.0, (), "concrete", "muro_norte")
    e.muro("hormigon", (mx, mz), (-mx, mz), ALTO, 1.0, (), "concrete", "muro_sur")
    e.muro("hormigon", (-mx, mz), (-mx, -mz), ALTO, 1.0, (), "concrete", "muro_oeste")
    e.muro("hormigon", (mx, -mz), (mx, mz), ALTO, 1.0, (), "concrete", "muro_este")
    for x in range(-48, 49, 8):
        e.caja("hormigon", (x, ALTO * 0.5, -FONDO + 0.25), (0.9, ALTO, 0.5))
        e.caja("hormigon", (x, ALTO * 0.5, FONDO - 0.25), (0.9, ALTO, 0.5))
    for z in range(-32, 33, 8):
        e.caja("hormigon", (-ANCHO + 0.25, ALTO * 0.5, z), (0.5, ALTO, 0.9))
        e.caja("hormigon", (ANCHO - 0.25, ALTO * 0.5, z), (0.5, ALTO, 0.9))
    e.caja("hormigon", (0.0, ALTO + 0.15, -mz), (2 * mx + 1.0, 0.3, 1.2))
    e.caja("hormigon", (0.0, ALTO + 0.15, mz), (2 * mx + 1.0, 0.3, 1.2))
    e.caja("hormigon", (-mx, ALTO + 0.15, 0.0), (1.2, 0.3, 2 * mz + 1.0))
    e.caja("hormigon", (mx, ALTO + 0.15, 0.0), (1.2, 0.3, 2 * mz + 1.0))

    e.muro("yeso", (-52.0, -30.0), (-36.0, -30.0), 4.3, 0.4,
           [(3.0, 4.2, 1.2, 2.4), (10.0, 11.2, 1.2, 2.4)], "concrete", "oficinas_n")
    e.muro("yeso", (-52.0, -18.0), (-36.0, -18.0), 4.3, 0.4,
           [(6.0, 7.2, 1.2, 2.4)], "concrete", "oficinas_s")
    e.muro("yeso", (-52.0, -18.0), (-52.0, -30.0), 4.3, 0.4, (), "concrete", "oficinas_o")
    e.muro("yeso", (-36.0, -30.0), (-36.0, -18.0), 4.3, 0.4,
           [(4.0, 5.2, 0.0, 2.2), (8.5, 11.0, 1.2, 2.4)], "concrete", "oficinas_e")
    e.caja("hormigon", (-44.0, 4.45, -24.0), (16.8, 0.3, 12.8), 0.0, 0.02)
    e.colisor("concrete", "oficinas_techo", (-44.0, 4.45, -24.0), (16.8, 0.3, 12.8))
    detalles_oficinas(e)

    e.muro("chapa", (52.0, -15.0), (34.0, -15.0), 7.0, 0.5, (), "concrete", "nave_n")
    e.muro("chapa", (52.0, 15.0), (34.0, 15.0), 7.0, 0.5,
           [(13.3, 14.5, 0.0, 2.2), (8.5, 10.0, 3.0, 4.4), (3.5, 5.0, 3.0, 4.4)], "concrete", "nave_s")
    e.muro("chapa", (52.0, -15.0), (52.0, 15.0), 7.0, 0.5,
           [(4.0, 5.5, 3.0, 4.4), (18.0, 19.5, 3.0, 4.4)], "concrete", "nave_e")
    e.muro("chapa", (34.0, 15.0), (34.0, -15.0), 7.0, 0.5,
           [(21.0, 24.0, 0.0, 3.2), (12.0, 15.0, 0.0, 3.2)], "concrete", "nave_o")
    e.techo("chapa", (43.0, 7.0, 0.0), 30.0, 18.0, 3.6, PI2)
    detalles_nave(e)
    for z in (-10.0, -6.0, -2.0, 2.0, 6.0, 10.0):
        e.utileria("shelf_01", (46.5, z), PI2, ("steel", "estanteria"))
    e.caja("tablon", (39.5, 0.1, -12.0), (1.2, 0.2, 1.0))
    e.caja("caja", (39.5, 0.5, -12.0), (1.0, 0.8, 0.9), 0.0, 0.03)
    e.colisor("pine", "palet", (39.5, 0.3, -12.0), (1.2, 0.6, 1.0))
    e.caja("tablon", (38.6, 0.1, 4.0), (1.2, 0.2, 1.0))
    cajas_carton(e, 38.6, 4.0, [(0.0, 0.0, 2)])
    e.colisor("pine", "palet", (38.6, 0.3, 4.0), (1.2, 0.6, 1.0))
    dique_muelle(e)

    silo(e, -14.0, -24.0, 4.0, 9.0)
    silo(e, -4.0, -24.0, 4.0, 9.0)

    e.caja("cont_azul", (6.0, 2.35, 4.0), (13.6, 2.9, 2.5), 0.0, 0.03)
    e.colisor("steel", "remolque_1", (6.0, 2.35, 4.0), (13.6, 2.9, 2.5))
    e.caja("oxido", (-2.6, 2.2, 4.0), (2.6, 2.6, 2.4), 0.0, 0.05)
    e.colisor("steel", "cabina_1", (-2.6, 2.2, 4.0), (2.6, 2.6, 2.4))
    for x in (10.2, 11.4):
        for z in (2.85, 5.15):
            e.rueda((x, 0.5, z), 0.5, 0.35)
    for z in (2.9, 5.1):
        e.rueda((-3.0, 0.5, z), 0.5, 0.35)
    for x in (2.8, 3.4):
        e.utileria("tyre_01__old_tyre", (x, 6.8), 0.0, ("steel", "neumatico"))

    e.caja("cont_rojo", (-22.0, 2.35, 16.0), (13.6, 2.9, 2.5), PI2, 0.03)
    e.colisor("steel", "remolque_2", (-22.0, 2.35, 16.0), (13.6, 2.9, 2.5), PI2)
    e.caja("oxido", (-22.0, 2.2, 7.9), (2.6, 2.6, 2.4), PI2, 0.05)
    e.colisor("steel", "cabina_2", (-22.0, 2.2, 7.9), (2.6, 2.6, 2.4), PI2)
    for z in (20.4, 21.6):
        for x in (-23.15, -20.85):
            e.rueda((x, 0.5, z), 0.5, 0.35, PI2)

    contenedores_fila(e, -52.0, 21.0, [12.19, 6.06, 12.19, 12.19], ["cont_verde", "cont_ocre", "cont_azul"], (0, 2))
    contenedores_fila(e, -50.0, 28.5, [12.19, 12.19, 6.06], ["cont_rojo", "cont_verde", "cont_ocre"], (1,))
    contenedores_fila(e, 16.0, 21.0, [6.06, 12.19, 12.19], ["cont_azul", "cont_rojo", "cont_verde"], (2,))
    contenedores_fila(e, 14.0, 28.5, [12.19, 12.19, 6.06], ["cont_ocre", "cont_azul", "cont_rojo"], (0,))
    contenedores_columna(e, -40.0, -14.0, [12.19, 12.19], ["cont_rojo", "cont_verde"])
    contenedores_fila(e, -12.0, 13.5, [6.06, 6.06, 6.06], ["cont_rojo", "cont_azul", "cont_verde"], (1,))
    contenedores_columna(e, -14.0, 7.0, [6.06, 6.06], ["cont_ocre", "cont_azul"])
    contenedores_columna(e, 26.0, -10.0, [6.06, 6.06], ["cont_verde", "cont_rojo"])
    e.caja("cont_ocre", (26.0, 3.885, -6.97), (6.06, 2.59, 2.44), PI2, 0.02)
    e.colisor("steel", "contenedor_alto", (26.0, 3.885, -6.97), (6.06, 2.59, 2.44), PI2)
    contenedores_fila(e, -24.0, -14.0, [6.06, 6.06], ["cont_azul", "cont_rojo"], (0,))
    caseta_bombas(e, -27.0, -27.0)

    cajas_pila(e, -28.0, -6.0, [(0.0, 0.0, 3), (1.0, 0.0, 2), (0.5, 0.0, 0)])
    cajas_pila(e, 9.0, 8.5, [(0.0, 0.0, 2), (1.0, 0.0, 2)])
    cajas_pila(e, 22.0, -2.0, [(0.0, 0.0, 2), (1.0, 0.0, 1)])
    cajas_pila(e, -44.0, 8.0, [(0.0, 0.0, 2), (1.0, 0.0, 2)])
    cajas_pila(e, 16.0, -6.0, [(0.0, 0.0, 2), (1.0, 0.0, 1), (0.0, 1.0, 1)])
    cajas_pila(e, 16.0, 11.0, [(0.0, 0.0, 2), (1.0, 0.0, 2)])
    cajas_pila(e, -24.0, -10.0, [(0.0, 0.0, 2), (1.0, 0.0, 1)])
    cajas_pila(e, -47.0, 0.0, [(0.0, 0.0, 2), (0.0, 1.0, 1)])
    cajas_pila(e, 10.0, -20.0, [(0.0, 0.0, 3), (1.0, 0.0, 2)])
    cajas_pila(e, 26.0, -30.0, [(0.0, 0.0, 2)])
    cajas_carton(e, -34.0, 10.0, [(0.0, 0.0, 2), (0.6, 0.0, 1)])

    for k in range(8):
        e.utileria("cbar_01__concrete_road_barrier", (-6.0 + 1.6 * k, -12.5), 0.0, ("concrete", "barrera"))
    for k in range(8):
        e.utileria("cbar_01__concrete_road_barrier", (22.0, -20.0 + 1.6 * k), PI2, ("concrete", "barrera"))
    for k in range(3):
        e.utileria("cbar_01__concrete_road_barrier", (-34.0, 4.0 + 1.6 * k), PI2, ("concrete", "barrera"))
    for x, z in ((-28.0, 14.0), (-27.3, 14.9), (10.0, 16.0), (2.0, 22.0), (2.7, 22.8), (34.0, -22.0),
                 (-36.0, 34.0), (-44.0, -10.0)):
        e.utileria("barrels_01__wooden_barrels_01_barrel01", (x, z), 0.0, ("barrel", "barril"))

    e.utileria("car_01", (-30.0, 35.0), 0.0, ("steel", "coche"))
    e.utileria("car_01", (18.0, -30.0), 0.0, ("steel", "coche"))
    for x, z in ((-34.0, 16.0), (-33.4, 16.6)):
        e.utileria("tyre_01__old_tyre", (x, z), 0.0, ("steel", "neumatico"))

    for x, z in ((-30.0, -33.0), (0.0, -33.0), (24.0, -33.0), (-30.0, 0.0), (6.0, 0.0), (30.0, 0.0)):
        e.utileria("lamp_01__street_lamp_01", (x, z))

    e.marca("home_0", -50.0, -6.0)
    e.marca("home_1", 51.0, 20.0)
    comprobar_base(e, "home_0", -50.0, -6.0)
    comprobar_base(e, "home_1", 51.0, 20.0)
    posiciones = [
        (-42.0, -34.0), (-28.0, -34.0), (-33.0, -21.0), (-29.0, -9.0), (-45.0, -4.0),
        (-44.0, 10.0), (-30.0, 14.0), (-22.0, 24.7), (38.0, -10.0), (40.0, 5.0),
        (30.0, -26.0), (36.0, 24.7), (14.0, -12.0), (16.0, 8.0), (-8.0, 10.0),
        (-4.0, -10.0), (20.0, -20.0), (26.0, 14.0),
    ]
    for i, (x, z) in enumerate(posiciones, start=1):
        libre = e.solapa(x, z)
        if libre is not None:
            print("PUESTO EN OBJETO", i, x, z, libre)
        e.marca("post_%02d" % i, x, z)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    e = Escena()
    construir(e)
    e.guardar(os.path.join(REPO, "blender", "patio.blend"))
    e.exportar(os.environ.get("MAPA_SALIDA") or os.path.join(REPO, "assets", "models", "patio.glb"))
    print("PATIO LISTO", len(e.estatica.objects), "piezas", len(e.colisiones.objects), "colisiones", len(e.utilerias.objects), "utilerias")


main()
