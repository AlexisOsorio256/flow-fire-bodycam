shader_type canvas_item;
render_mode unshaded;

// Post-proceso bodycam: identidad de cámara (lente ancha + sensor barato).
//
// AUTORIDAD: docs/refs/ref5.jpg y ref1.jpg son las dos tomas de lente del
//
//   1. BARRIL fuerte. En ref5 la barandilla recta del primer plano se curva;
//      0,15 apenas dobla la esquina: 0,30 la curva de ref5/ref1 se parece a
//      ANILLO NEGRO alrededor — la imagen visible es un círculo cuya corona
//
// Coste: UNA lectura de barril + UNA de rojo (la segunda existía ya). Ni blur
// ni segunda pasada.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float vignette = 1.0;         // caida del anillo (1.0 = negro de lente)
uniform float vignette_start = 0.68;  // radio corregido donde empieza a caer la lente
uniform float vignette_end = 0.94;    // radio donde la lente se vuelve negra
uniform float grain_amount = 0.0045; // textura de sensor CMOS
uniform float exposure_pulse = 0.0;  // reacción del AGC al disparo
uniform float fisheye = 0.18;        // barril del gran angular esférico
uniform float ca_edge = 0.008;       // separación lateral cromática en borde
uniform vec2 cam_velocity = vec2(0.0); // velocidad angular de giro de cámara

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
        // Aberración cromática radial en los bordes
        if (edge > 0.02) {
            vec2 uv_r = 0.5 + cuv * (scale + ca_edge * r2);
            vec2 uv_b = 0.5 + cuv * (scale - ca_edge * 0.5 * r2);
            if (uv_r.x >= 0.0 && uv_r.x <= 1.0 && uv_r.y >= 0.0 && uv_r.y <= 1.0) {
                col.r = texture(screen_texture, uv_r).r;
            }
            if (uv_b.x >= 0.0 && uv_b.x <= 1.0 && uv_b.y >= 0.0 && uv_b.y <= 1.0) {
                col.b = texture(screen_texture, uv_b).b;
            }
        }
        // Motion blur en giros rápidos de cámara (autoridad: ref video shot_06)
        vec2 blur_dir = -cam_velocity * 0.35;
        float blur_mag = length(blur_dir);
        if (blur_mag > 0.001) {
            blur_dir = clamp(blur_dir, vec2(-0.025), vec2(0.025));
            vec3 bcol = col;
            bcol += texture(screen_texture, clamp(uv_distorted + blur_dir * 0.40, vec2(0.0), vec2(1.0))).rgb;
            bcol += texture(screen_texture, clamp(uv_distorted + blur_dir * 0.80, vec2(0.0), vec2(1.0))).rgb;
            col = bcol * 0.3333;
        }
    }

    // Halo/anillo cromático azul en el borde óptico del lente (autoridad: frame_10 y video)
    float halo = smoothstep(0.20, 0.55, edge) * (1.0 - smoothstep(0.55, 0.95, edge));
    col += vec3(0.04, 0.22, 0.58) * halo * 0.35;

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
