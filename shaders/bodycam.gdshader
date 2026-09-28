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
//      0,15 apenas dobla la esquina: 0,30 la curva de ref5/ref1 se parece a
//      la captura del juego en pantalla.
//   2. CIRCULO DE LENTE. En ref1 el encuadre NO llega a la esquina: hay un
//      ANILLO NEGRO alrededor — la imagen visible es un círculo cuya corona
//      cae a negro (elija el dueno: "que se vea un circulo alrededor de la
//      camara"). Esto no es una viñeta de esquina: es la frontera óptica del
//      lente ancho. Medido en ref1: la corona arranca alrededor de r2 0,28
//      (57 % del radio) y ya es NEGRO en la esquina (r2 0,50).
//   3. ABERRACIÓN CROMÁTICA de borde (rojo/cian en barandillas y marcos, muy
//      visible en ref1/ref5).
//
// Coste: UNA lectura de barril + UNA de rojo (la segunda existía ya). Ni blur
// ni segunda pasada.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float vignette = 1.0;         // caida del anillo (1.0 = negro de lente)
uniform float vignette_start = 0.10;  // r2 donde empieza a caer
uniform float vignette_end = 0.46;    // r2 donde ya cae del todo (0,5 = esquina)
uniform float grain_amount = 0.0045; // textura de sensor, no ruido que tape material
uniform float exposure_pulse = 0.0;  // reacción del AGC al disparo
uniform float fisheye = 0.30;        // barril del gran angular
uniform float ca_edge = 0.012;       // separación del canal rojo en el borde

void fragment() {
    vec2 cuv = SCREEN_UV - 0.5;
    float r2 = dot(cuv, cuv);
    vec3 col = texture(screen_texture, 0.5 + cuv * (1.0 + fisheye * r2)).rgb;
    // La segunda lectura del canal rojo SOLO existe en el borde (aberración
    // cromática): el 70 % central saltaba la lectura y pagaba un texel de más
    // por pixel. Medido A/B: el salto vale ~1,3 ms del cuadro en esta HD520
    // (bench combat 1080p) por un filtrito que solo se ve en el anillo.
    float edge = smoothstep(vignette_start, vignette_end, r2);
    if (edge > 0.01) {
        col.r = texture(screen_texture, 0.5 + cuv * (1.0 + (fisheye + ca_edge) * r2)).r;
    }

    // El sensor reacciona al fogonazo, pero no se lava la imagen.
    col *= 1.0 + exposure_pulse * 0.10;

    // CIRCULO DE LENTE: el anillo optico. Caida suave desde el ancho del
    // anillo y NEGRO en la esquina, como en ref1: la imagen visible es un
    // circulo, no una esquina apagada.
    col *= 1.0 - edge * vignette;

    // Ruido de sensor: monocromo y coherente con el frame (fixed-pattern), ma's
    // visible en sombra, que es donde el AGC de una bodycam sube la ganancia.
    vec2 pixel = FRAGCOORD.xy;
    float noise = fract(pixel.x * 0.754877666 + pixel.y * 0.569840296) - 0.5;
    col += noise * grain_amount * (0.35 + 0.65 * edge);

    COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
