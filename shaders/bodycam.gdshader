shader_type canvas_item;
render_mode unshaded;

// Post-proceso bodycam: identidad de cámara (lente ancha + sensor barato) sin
// comerse el detalle.
//
// Medido sobre capturas reales del juego (misma imagen con y sin shader):
// - el blur direccional anterior quitaba un 38% de contraste a los bordes
//   fuertes al girar, y su normalización estaba mal (los pesos suman 3.197 y
//   dividía por 2.15, así que además aclaraba un 49% la imagen al girar);
// - el grano de 0.028 metía 5.5x más ruido que el propio render;
// - pow(0.9) + contraste 1.18 recortaba las altas luces.
// Aquí no hay blur ni aberración cromática. El FOV de cámara ya aporta la lente
// ancha; volver a deformar la pantalla sólo obligaba a 5 lecturas por píxel para
// corregir el detalle perdido. Se conserva la firma bodycam con viñeta, sensor
// y respuesta al fogonazo, pero la imagen base pasa 1:1 y sólo se lee una vez.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float vignette = 0.035;      // viñeta óptica muy sutil
uniform float grain_amount = 0.0015; // textura de sensor, no ruido que tape material
uniform float exposure_pulse = 0.0;  // reacción del AGC al disparo
uniform float time = 0.0;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

void fragment() {
    vec2 cuv = SCREEN_UV - 0.5;
    float r2 = dot(cuv, cuv);
    vec3 col = texture(screen_texture, SCREEN_UV).rgb;

    // El sensor reacciona al fogonazo, pero no se lava la imagen.
    col *= 1.0 + exposure_pulse * 0.10;

    // Lift sólo del toe: negro real permanece negro, pero guantes, metal oscuro
    // y rincones conservan información en vez de convertirse en masas negras.
    float luma = dot(col, vec3(0.299, 0.587, 0.114));
    float shadow_lift = (1.0 - smoothstep(0.02, 0.38, luma)) * 0.06;
    col *= 1.0 + shadow_lift;

    // Viñeta óptica sutil: cámara de seguridad/cuerpo policial nítida, sin túnel negro.
    float vig = smoothstep(1.40, 0.35, r2 * 1.15);
    col *= mix(1.0, vig, vignette);

    // Ruido de sensor: monocromo, más visible en sombra (es donde el AGC sube
    // la ganancia). Es el único efecto que aporta "textura de cámara barata".
    float noise = hash21(SCREEN_UV * vec2(1920.0, 1080.0) + vec2(time * 97.3, time * 51.7)) - 0.5;
    float shadow = 1.0 - smoothstep(0.04, 0.45, luma);
    col += noise * grain_amount * (0.30 + 0.70 * shadow);

    COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
