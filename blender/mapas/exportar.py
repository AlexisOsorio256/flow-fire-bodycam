import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)

from piezas import exportar_colecciones

nombre = os.path.splitext(os.path.basename(bpy.data.filepath))[0]
colecciones = [bpy.data.collections[n] for n in ("Static", "Props", "Colliders", "Markers")]
exportar_colecciones(os.path.join(REPO, "assets", "models", nombre + ".glb"), colecciones)
print("EXPORTADO", nombre)
