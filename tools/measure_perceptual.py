#!/usr/bin/env python3
"""
measure_perceptual.py: Mide metricas perceptuales estandar sobre imagenes o directorios.
Metricas:
  - Luminancia media, p5, p95
  - Saturacion media (HSV)
  - Razon R/B media
  - Luminancia en las 4 esquinas (mascara de vinetado / ojo de pez)
"""
import sys
import glob
import os
import numpy as np
from PIL import Image

def analyze_image(path):
    img = Image.open(path).convert('RGB')
    arr = np.asarray(img, dtype=np.float32) / 255.0
    h, w, _ = arr.shape

    r = arr[:, :, 0]
    g = arr[:, :, 1]
    b = arr[:, :, 2]

    # Luminancia estandar Rec.709
    lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
    mean_lum = float(np.mean(lum))
    p5 = float(np.percentile(lum, 5))
    p95 = float(np.percentile(lum, 95))

    # Saturacion HSV
    max_c = np.maximum(np.maximum(r, g), b)
    min_c = np.minimum(np.minimum(r, g), b)
    delta = max_c - min_c
    sat = np.where(max_c > 1e-5, delta / (max_c + 1e-6), 0.0)
    mean_sat = float(np.mean(sat))

    # Razon R/B media
    mean_r = float(np.mean(r))
    mean_b = float(np.mean(b))
    rb_ratio = mean_r / (mean_b + 1e-6)

    # Luminancia en las 4 esquinas (parche de 5% x 5% en cada esquina)
    cw = max(1, int(w * 0.05))
    ch = max(1, int(h * 0.05))
    tl = float(np.mean(lum[:ch, :cw]))
    tr = float(np.mean(lum[:ch, -cw:]))
    bl = float(np.mean(lum[-ch:, :cw]))
    br = float(np.mean(lum[-ch:, -cw:]))
    corners = (tl + tr + bl + br) / 4.0

    return {
        "path": os.path.basename(path),
        "lum_mean": mean_lum,
        "p5": p5,
        "p95": p95,
        "sat_mean": mean_sat,
        "rb_ratio": rb_ratio,
        "corners": corners,
        "corners_detail": (tl, tr, bl, br)
    }

def analyze_paths(paths):
    results = []
    for p in paths:
        results.append(analyze_image(p))
    if not results:
        return None
    agg = {
        "lum_mean": float(np.mean([r["lum_mean"] for r in results])),
        "p5": float(np.mean([r["p5"] for r in results])),
        "p95": float(np.mean([r["p95"] for r in results])),
        "sat_mean": float(np.mean([r["sat_mean"] for r in results])),
        "rb_ratio": float(np.mean([r["rb_ratio"] for r in results])),
        "corners": float(np.mean([r["corners"] for r in results])),
        "count": len(results)
    }
    return agg, results

def main():
    if len(sys.argv) < 2:
        print("Uso: python3 tools/measure_perceptual.py <patron_o_carpeta_de_imagenes>")
        sys.exit(1)

    target = sys.argv[1]
    if os.path.isdir(target):
        files = sorted(glob.glob(os.path.join(target, "*.png")) + glob.glob(os.path.join(target, "*.jpg")))
    else:
        files = sorted(glob.glob(target))

    if not files:
        print(f"No se encontraron imagenes en: {target}")
        sys.exit(1)

    agg, details = analyze_paths(files)
    print(f"=== METRICAS PERCEPTUALES ({agg['count']} frames) ===")
    print(f"Luminancia media: {agg['lum_mean']:.4f}")
    print(f"p5:               {agg['p5']:.4f}")
    print(f"p95:              {agg['p95']:.4f}")
    print(f"Saturacion media: {agg['sat_mean']:.4f}")
    print(f"Razon R/B media:  {agg['rb_ratio']:.4f}")
    print(f"Luminancia esquinas: {agg['corners']:.4f}")

if __name__ == "__main__":
    main()
