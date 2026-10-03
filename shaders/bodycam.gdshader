shader_type canvas_item;
render_mode unshaded;

// Post-proceso bodycam: identidad de cámara (lente ancha + sensor barato).
//
//   1. BARRIL fuerte: 0,15 apenas dobla la esquina; 0,30 la dobla de más.
//   2. ANILLO NEGRO alrededor — la imagen visible es un círculo cuya corona
//      se come el cuadro.
//
// Coste: UNA lectura de barril + las dos de aberración cromática (rojo y azul).
// Sin segunda pasada: el cuadro se lee nítido en cualquier movimiento de ratón.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float vignette = 0.38;        // caida del anillo: ref8 manda anillo marcado
uniform float vignette_start = 0.48;  // la caida vive en la corona...
uniform float vignette_end = 0.58;    // ...y llega al tope en la esquina (r=0,57)
uniform float grain_amount = 0.0045; // textura de sensor CMOS
uniform float exposure_pulse = 0.0;  // reacción del AGC al disparo
uniform float fisheye = 0.05;        // barril del gran angular esferico
uniform float ca_edge = 0.008;       // separación lateral cromática en borde

void fragment() {
    vec2 cuv = SCREEN_UV - 0.5;
    // Corrección de relación de aspecto 16:9 para cálculo óptico radial circular
    float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
    vec2 uv_lens = vec2(cuv.x * aspect, cuv.y);
    float r_lens = length(uv_lens);
    float r2 = r_lens * r_lens;

    // Escala base para mantener los UVs muestreados dentro del marco sin clamping
    float scale = 0.94 + fisheye * r2;
    vec2 uv_distorted = 0.5 + cuv * scale;

    vec3 col = vec3(0.0);
    // Mascara de viñeteado circular de lente gran angular auténtica
    float edge = smoothstep(vignette_start, vignette_end, r_lens);

    if (uv_distorted.x >= 0.0 && uv_distorted.x <= 1.0 && uv_distorted.y >= 0.0 && uv_distorted.y <= 1.0) {
        col = texture(screen_texture, uv_distorted).rgb;
        // Aberración cromática radial: SOLO EN LA CORONA. Con la mascara vieja
        // (edge > 0,02, luego > 0,35) el 70 % del cuadro pagaba tres lecturas y
        // el filo del vignette amplificaba cualquier rejilla del mundo en
        // franjas de color. La lente de una bodycam real tiene la CA en la
        // corona, no en el centro: por encima de 0,55 solo queda el borde.
        if (edge > 0.55) {
            float ca = ca_edge * smoothstep(0.55, 1.0, edge);
            vec2 uv_r = 0.5 + cuv * (scale + ca * r2);
            vec2 uv_b = 0.5 + cuv * (scale - ca * 0.5 * r2);
            if (uv_r.x >= 0.0 && uv_r.x <= 1.0 && uv_r.y >= 0.0 && uv_r.y <= 1.0) {
                col.r = texture(screen_texture, uv_r).r;
            }
            if (uv_b.x >= 0.0 && uv_b.x <= 1.0 && uv_b.y >= 0.0 && uv_b.y <= 1.0) {
                col.b = texture(screen_texture, uv_b).b;
            }
        }
    }

    // Anillo del lente: OSCURO, como ref8. El halo azulado viejo pintaba un
    // circulo visible en medio del cuadro en cuanto el borde llegaba a 1: un
    // lente de bodycam viñetea a negro, no a azul.
    float halo = smoothstep(0.55, 0.95, edge) * (1.0 - smoothstep(0.95, 1.0, edge));
    col += vec3(0.02, 0.05, 0.10) * halo * 0.25;

    // Reacción del sensor al disparo
    col *= 1.0 + exposure_pulse * 0.10;

    // Corte suave de la corona del lente (anillo negro circular auténtico)
    col *= (1.0 - edge * vignette);

    // Ruido de sensor CMOS
    vec2 pixel = FRAGCOORD.xy;
    float noise = fract(pixel.x * 0.754877666 + pixel.y * 0.569840296) - 0.5;
    col += noise * grain_amount * (0.35 + 0.65 * edge);

    COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
