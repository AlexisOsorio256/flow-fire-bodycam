shader_type canvas_item;
render_mode unshaded;

// Lente de bodycam en una pasada: la camara renderiza rectilinea a `fov_v` y
// aqui se remapea en barril hacia equidistante. El circulo de imagen de la
// lente es algo menor que la diagonal: las esquinas caen fuera y forman el
// anillo oscuro de docs/refs. Encima: nitidez adaptativa (el remapeo
// ablanda), aberracion cromatica radial, pulso de exposicion, sensor y grano.
// Todas las muestras usan el mismo filtro sin mipmaps y sin ramas, asi que
// la imagen no cambia de nitidez ni de color a ningun radio.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float fov_v = 100.0;          // FOV vertical de la Camera3D, en grados
uniform float barrel = 0.36;          // 0 rectilinea, 1 equidistante
uniform float circle = 1.97;          // radio del circulo de imagen (alturas/2)
uniform float ring_soft = 0.12;       // ancho del borde del anillo
uniform float vignette = 0.30;
uniform float ca_edge = 0.0035;
uniform float sharpen = 0.40;
uniform float grain_amount = 0.014;
uniform float exposure_pulse = 0.0;
uniform float time_seed = 0.0;
uniform float saturation = 0.90;
uniform float fade = 0.0;             // 1 = negro (muerte, transiciones)

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 p = (SCREEN_UV - 0.5) * vec2(aspect, 1.0) * 2.0;
	float r = max(length(p), 1e-5);
	float tv = tan(radians(fov_v) * 0.5);
	float rc = length(vec2(aspect, 1.0));            // esquina de la fuente
	float theta = atan(rc * tv) * r / circle;        // equidistante
	float r_fish = tan(min(theta, 1.5)) / tv;
	float r_src = mix(r * rc / circle, r_fish, barrel);
	vec2 q = p * (r_src / r);
	vec2 uv = q / vec2(aspect, 1.0) * 0.5 + 0.5;

	vec2 d = uv - 0.5;
	float ca = ca_edge * smoothstep(0.35, 1.0, r / circle);
	vec2 px = SCREEN_PIXEL_SIZE;
	vec3 c = texture(screen_texture, uv).rgb;
	vec3 n = texture(screen_texture, uv + vec2(px.x, 0.0)).rgb
		+ texture(screen_texture, uv - vec2(px.x, 0.0)).rgb
		+ texture(screen_texture, uv + vec2(0.0, px.y)).rgb
		+ texture(screen_texture, uv - vec2(0.0, px.y)).rgb;
	// Nitidez adaptativa: refuerza el detalle fino y se contiene en bordes duros.
	vec3 hi = c - n * 0.25;
	float contrast = max(max(abs(hi.r), abs(hi.g)), abs(hi.b));
	vec3 col = c + hi * sharpen / (1.0 + contrast * 6.0);
	col.r += texture(screen_texture, 0.5 + d * (1.0 + ca)).r - c.r;
	col.b += texture(screen_texture, 0.5 + d * (1.0 - ca)).b - c.b;

	col *= 1.0 + exposure_pulse * 0.10;
	// Sensor barato: croma contenido, hombros suaves y negros levantados.
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, saturation);
	col = col / (1.0 + col * 0.06);
	col = mix(vec3(0.010), col, 0.988);

	float rn = r / circle;
	float ring = smoothstep(1.0 - ring_soft, 1.0 + ring_soft * 0.35, rn);
	col *= (1.0 - vignette * rn * rn) * (1.0 - ring);

	vec2 g = FRAGCOORD.xy + time_seed * 37.0;
	float noise = fract(sin(dot(g, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	col += noise * grain_amount * (0.6 + 0.4 * rn) * (1.0 - ring);
	col *= 1.0 - fade;
	COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
