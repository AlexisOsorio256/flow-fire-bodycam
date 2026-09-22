# Créditos de texturas

Texturas PBR reales de **Poly Haven**, licencia **CC0**:

- `concrete_brushed_concrete_*`: "Brushed Concrete" — https://polyhaven.com/a/brushed_concrete
- `concrete_concrete_*`: "Concrete" — https://polyhaven.com/a/concrete
- `wood_oak_wood_planks_*`: "Oak Wood Planks" — https://polyhaven.com/a/oak_wood_planks
- `metal_metal_plate_*`: "Metal Plate" — https://polyhaven.com/a/metal_plate
- `gypsum_*`: derivadas de "Brushed Concrete" (mismo origen CC0); grano de
  escayola pintada calibrado a la luminancia del panel.
- `metal_plate_grain.jpg`: derivada de "Metal Plate" (mismo origen CC0);
  grano del difuso + relieve de diamante desde su normal, media 0,5964
  compensada en `albedo_color` para no mover la luz.
- `metal_paint_grain.jpg`: misma derivación pero solo grano (k=0,20, sin
  relieve) para la pintura de los bidones; media 0,7456 compensada.
- `diffuser_rib.png`: generada por el proyecto (patrón de costillas de
  difusor prismático 120×120, periodo 10 px = 0,133 m con UV de mundo a
  1,6 m/tile); valores 0/196/255, sin origen de terceros.

Las texturas de blancos y partículas siguen siendo generadas por el proyecto.
