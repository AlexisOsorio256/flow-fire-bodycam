shader_type canvas_item;
render_mode unshaded;

// Post-proceso bodycam: identidad de cámara (lente ancha + sensor barato).
//
// AUTORIDAD: docs/refs/ref5.jpg y ref1.jpg son las dos tomas de lente del
// contrato (`docs/REFS.md` §3). Medido sobre ellas y sobre las cinco
// referencias: la firma NO es "nítido con un toque de viñeta", es un gran
// angular de cuerpo con tres rasgos que se ven a simple vista:
//
//   1. BARRIL fuerte. En ref5 la barandilla recta del primer plano se curva;
//      con fisheye 0,08 el borde apenas respiraba (2 % del ancho en la
//      esquina). 0,15 dobla la esquina un 3,75 % del ancho.
//   2. VIÑETA DE VERDAD. La vieja caía a 0,4 % en la esquina (smoothstep
//      0,35..1,40 sobre r2 máximo 0,5): no existía. Medido en las referencias,
//      entre el 4,6 % (ref3) y el 16,6 % (ref1) de los píxeles están por
//      debajo de luma 0,10, y p05 baja a 0,00-0,10. Eso es la viñeta, y es lo
//      que hacía que el juego se leyera "con mucha luz" aunque su luma media
//      ya coincidiera con la de las referencias: sin negros, un cuadro de
//      medios tonos se lee plano y lavado.
//   3. ABERRACIÓN CROMÁTICA de borde (rojo/cian en barandillas y marcos, muy
//      visible en ref1/ref5).
//
// Coste: UNA lectura de barril + UNA de rojo (la segunda existía ya). Ni blur
// ni segunda pasada.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float vignette = 0.50;       // caída de esquina (0,50 = 50 % en la esquina)
uniform float vignette_start = 0.05; // r2 donde empieza a caer
uniform float vignette_end = 0.58;   // r2 donde ya cae del todo (0,5 = esquina)
uniform float grain_amount = 0.0045; // textura de sensor, no ruido que tape material
uniform float exposure_pulse = 0.0;  // reacción del AGC al disparo
uniform float fisheye = 0.15;        // barril del gran angular
uniform float ca_edge = 0.010;       // separación del canal rojo en el borde

void fragment() {
    vec2 cuv = SCREEN_UV - 0.5;
    float r2 = dot(cuv, cuv);
    vec3 col = texture(screen_texture, 0.5 + cuv * (1.0 + fisheye * r2)).rgb;
    col.r = texture(screen_texture, 0.5 + cuv * (1.0 + (fisheye + ca_edge) * r2)).r;

    // El sensor reacciona al fogonazo, pero no se lava la imagen.
    col *= 1.0 + exposure_pulse * 0.10;

    // Viñeta óptica CALIBRADA contra las referencias: cae desde r2 0,05 (el
    // 32 % central queda intacto) hasta 0,50 (esquina), donde pierde la mitad.
    float edge = smoothstep(vignette_start, vignette_end, r2);
    col *= 1.0 - edge * vignette;

    // Ruido de sensor: monocromo y coherente con el frame (fixed-pattern), más
    // visible en sombra, que es donde el AGC de una bodycam sube la ganancia.
    vec2 pixel = FRAGCOORD.xy;
    float noise = fract(pixel.x * 0.754877666 + pixel.y * 0.569840296) - 0.5;
    col += noise * grain_amount * (0.35 + 0.65 * edge);

    COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
