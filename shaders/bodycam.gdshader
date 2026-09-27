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
// ancha; volver a deformar la pantalla con blur/aberración obligaba a 5 lecturas
// por píxel para corregir el detalle perdido. Se conserva la firma bodycam con
// viñeta, sensor y respuesta al fogonazo, y la imagen pasa por UNA lectura: el
// barril del gran angular desplaza la UV con la MISMA textura (el filtro lineal
// del sampler hace el resto), así que el coste extra por píxel es un fma.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float vignette = 0.035;      // viñeta óptica muy sutil
uniform float grain_amount = 0.0015; // textura de sensor, no ruido que tape material
uniform float exposure_pulse = 0.0;  // reacción del AGC al disparo
// Lente gran angular (barril) sólo en la periferia: el centro queda 1:1 y con
// k=0.05 la esquina (r2=0.5) muestrea un 2,5 % más afuera. Se midió A/B contra
// k=0 en el bench y en captura; si no gana, queda a 0 y no cuesta nada.
uniform float fisheye = 0.0;

void fragment() {
    vec2 cuv = SCREEN_UV - 0.5;
    float r2 = dot(cuv, cuv);
    vec3 col = texture(screen_texture, 0.5 + cuv * (1.0 + fisheye * r2)).rgb;

    // El sensor reacciona al fogonazo, pero no se lava la imagen.
    col *= 1.0 + exposure_pulse * 0.10;

    // Lift sólo del toe: recupera guantes, metal oscuro y rincones sin levantar
    // los medios/altas luces ni volver plana la iluminación horneada.
    float luma = dot(col, vec3(0.299, 0.587, 0.114));
    // Una sola mascara sirve al lift y al AGC del grano. Antes se evaluaban dos
    // smoothstep casi iguales por pixel; a 1080p era trabajo duplicado.
    float shadow = 1.0 - smoothstep(0.03, 0.42, luma);
    col += vec3(shadow * 0.025);

    // Viñeta óptica sutil: cámara de seguridad/cuerpo policial nítida, sin túnel negro.
    float edge = smoothstep(0.35, 1.40, r2 * 1.15);
    col *= 1.0 - edge * vignette;

    // Ruido de sensor: monocromo, más visible en sombra (es donde el AGC sube
    // la ganancia). Fixed-pattern noise es coherente con un sensor barato y
    // evita recomputar/actualizar una semilla temporal en cada frame.
    vec2 pixel = FRAGCOORD.xy;
    float noise = fract(pixel.x * 0.754877666 + pixel.y * 0.569840296) - 0.5;
    col += noise * grain_amount * (0.30 + 0.70 * shadow);

    COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
