#!/usr/bin/env python3
"""FLOWFIRE MARK 23 VIEWMODEL BUILDER.

Canonicaliza assets/models/mark23_viewmodel.glb:
- Escala de centimetros a metros (factor 0.01).
- Recentra al origen del arma (cabeza de main_j_050 en reposo).
- Rota 180° sobre Y para alinear el cañón con -Z (forward de Godot) y las miras.
- Elimina mallas no deseadas: Icosphere y mano desnuda.
- Conserva mallas de producción con piel y guante negro (Arms).
- Nombra mallas canónicas: Frame, Slide, Magazine, Arms, Barrel, Trigger.
- Crea y nombra los sockets requeridos:
    Frame, Slide, Magazine, Barrel, Muzzle, EjectionPort,
    SightRear, SightFront, Grip, Magwell, Trigger.
- Conserva curvas de animacion autoradas.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
BUILDER_GD = REPO / "tools" / "build_mark23.gd"


def main() -> None:
    argv = sys.argv[1:]
    parser = argparse.ArgumentParser(description="FLOWFIRE Mark 23 viewmodel builder")
    parser.add_argument("--script", default=str(BUILDER_GD))
    args = parser.parse_args(argv)

    cmd = ["godot4", "--headless", "--path", str(REPO), "-s", str(args.script)]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        print(res.stderr, file=sys.stderr)
        print(res.stdout)
        sys.exit(res.returncode)
    print(res.stdout.strip())


if __name__ == "__main__":
    main()
