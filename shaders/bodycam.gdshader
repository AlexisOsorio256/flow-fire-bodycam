shader_type canvas_item;
render_mode unshaded;

// Lente de bodycam en una sola pasada: ojo de pez (la camara renderiza
// rectilinea a `fov_v` y aqui se remapea hacia equidistante), anillo oscuro,
// aberracion cromatica en la corona, pulso de exposicion y grano.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float fov_v = 100.0;          // FOV vertical de la Camera3D, en grados
uniform float fisheye = 0.85;         // 0 rectilinea, 1 equidistante
uniform float vignette = 0.92;
uniform float vignette_start = 0.55;  // radio normalizado a la esquina
uniform float vignette_end = 0.98;
uniform float ca_edge = 0.006;
uniform float grain_amount = 0.018;
uniform float exposure_pulse = 0.0;
uniform float time_seed = 0.0;
uniform float saturation = 0.82;

vec2 lens(vec2 p, float rc, float tv, float k) {
	float r = length(p);
	if (r < 1e-5) return p;
	float theta = atan(rc * tv) * r / rc;
	float r_src = tan(theta) / tv;
	return p * (mix(r, r_src, k) / r);
}

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 p = (SCREEN_UV - 0.5) * vec2(aspect, 1.0) * 2.0;
	float rc = length(vec2(aspect, 1.0));
	float tv = tan(radians(fov_v) * 0.5);
	vec2 q = lens(p, rc, tv, fisheye);
	vec2 uv = q / vec2(aspect, 1.0) * 0.5 + 0.5;
	float rn = length(p) / rc;

	vec3 col = texture(screen_texture, uv).rgb;
	float ca = ca_edge * smoothstep(0.45, 1.0, rn);
	if (ca > 0.0001) {
		vec2 d = (uv - 0.5);
		col.r = texture(screen_texture, 0.5 + d * (1.0 + ca)).r;
		col.b = texture(screen_texture, 0.5 + d * (1.0 - ca)).b;
	}

	col *= 1.0 + exposure_pulse * 0.12;
	// Sensor barato: croma contenido, hombros suaves y negros levantados.
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, saturation);
	col = col / (1.0 + col * 0.08);
	col = mix(vec3(0.012), col, 0.985);
	float edge = smoothstep(vignette_start, vignette_end, rn);
	col *= 1.0 - edge * edge * vignette;

	vec2 px = FRAGCOORD.xy + time_seed * 37.0;
	float n = fract(sin(dot(px, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	col += n * grain_amount * (0.6 + 0.4 * edge);
	COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
