shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float fov_v = 100.0;
uniform float barrel = 0.5;
uniform float circle = 1.97;
const float RING_SOFT = 0.12;
const float VIGNETTE = 0.30;
const float CA_EDGE = 0.0035;
const float SHARPEN = 0.15;
const float EDGE_AA = 0.55;
const float GRAIN = 0.014;
uniform float exposure_pulse = 0.0;
uniform float hit_pulse = 0.0;
uniform float hurt = 0.0;
uniform float bleed = 0.0;
uniform float suppress = 0.0;
uniform float time_seed = 0.0;
const float SATURATION = 0.90;
uniform float fade = 0.0;
uniform float signal_loss = 0.0;
uniform vec4 faces[8];
uniform int face_count = 0;
const float FACE_CELLS = 6.0;

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

vec2 mosaic(vec2 uv, vec2 screen_px) {
	if (face_count <= 0) {
		return uv;
	}
	for (int i = 0; i < face_count; i++) {
		vec4 f = faces[i];
		float block = f.w * 2.0 / FACE_CELLS * screen_px.y;
		if (block < 4.0) {
			continue;
		}
		vec2 slack = block * 0.5005 / screen_px;
		if (any(greaterThan(abs(uv - f.xy), f.zw + slack))) {
			continue;
		}
		vec2 cell = (floor(uv * screen_px / block) + 0.5) * block / screen_px;
		vec2 k = (cell - f.xy) / f.zw;
		if (dot(k, k) < 1.0) {
			return cell;
		}
	}
	return uv;
}

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 p = (SCREEN_UV - 0.5) * vec2(aspect, 1.0) * 2.0;
	float r = max(length(p), 1e-5);
	float tv = tan(radians(fov_v) * 0.5);
	float rc = length(vec2(aspect, 1.0));
	float theta = atan(rc * tv) * r / circle;
	float r_fish = tan(min(theta, 1.5)) / tv;
	float r_src = mix(r * rc / circle, r_fish, barrel);
	vec2 q = p * (r_src / r);
	vec2 uv = mosaic(q / vec2(aspect, 1.0) * 0.5 + 0.5, 1.0 / SCREEN_PIXEL_SIZE);
	float torn = 0.0;
	if (signal_loss > 0.0) {
		float band = floor(SCREEN_UV.y * 36.0) + floor(time_seed * 0.37) * 53.0;
		torn = step(1.0 - signal_loss * 0.55, fract(sin(band * 91.7) * 4375.85));
		vec2 block = vec2(64.0, 36.0);
		uv = mix(uv, (floor(uv * block) + 0.5) / block, torn * step(0.5, signal_loss));
		uv.x += torn * (fract(sin(band * 17.3) * 9137.1) - 0.5) * 0.09 * signal_loss;
	}

	vec2 d = uv - 0.5;
	float ca = CA_EDGE * smoothstep(0.35, 1.0, r / circle);
	vec2 px = SCREEN_PIXEL_SIZE;
	vec3 c = texture(screen_texture, uv).rgb;
	vec3 cl = texture(screen_texture, uv - vec2(px.x, 0.0)).rgb;
	vec3 cr = texture(screen_texture, uv + vec2(px.x, 0.0)).rgb;
	vec3 cu = texture(screen_texture, uv - vec2(0.0, px.y)).rgb;
	vec3 cd = texture(screen_texture, uv + vec2(0.0, px.y)).rgb;
	vec3 hi = c - (cl + cr + cu + cd) * 0.25;
	float contrast = max(max(abs(hi.r), abs(hi.g)), abs(hi.b));
	float lc = luma(c);
	float ll = luma(cl);
	float lr = luma(cr);
	float lu = luma(cu);
	float ld = luma(cd);
	float lmin = min(min(ll, lr), min(lu, ld));
	float lmax = max(max(ll, lr), max(lu, ld));
	vec3 along = mix(cu + cd, cl + cr, step(abs(lu + ld - 2.0 * lc), abs(ll + lr - 2.0 * lc))) * 0.5;
	float edge = clamp(max(lmin - lc, lc - lmax) * 8.0, 0.0, 1.0) * EDGE_AA;
	vec3 col = mix(c + hi * SHARPEN / (1.0 + contrast * 6.0), along, edge);
	if (ca > 0.0005) {
		col.r += texture(screen_texture, 0.5 + d * (1.0 + ca)).r - c.r;
		col.b += texture(screen_texture, 0.5 + d * (1.0 - ca)).b - c.b;
	}

	col *= 1.0 + exposure_pulse * 0.10;
	col *= 1.0 - hit_pulse * 0.10 - suppress * 0.06;
	float lum = luma(col);
	col = mix(vec3(lum), col, SATURATION * (1.0 - hurt * 0.30));
	col = col / (1.0 + col * 0.06);
	col = mix(vec3(0.010), col, 0.988);

	float rn = r / circle;
	float ring = smoothstep(1.0 - RING_SOFT, 1.0 + RING_SOFT * 0.35, rn);
	float pulse = 0.75 + 0.25 * sin(time_seed * 0.25);
	col *= (1.0 - (VIGNETTE + hurt * 0.38 + hit_pulse * 0.22 + bleed * 0.25 * pulse) * rn * rn) * (1.0 - ring);
	float bleed_ring = bleed * smoothstep(0.40, 1.05, rn) * pulse;
	float hem = max(max(hit_pulse * smoothstep(0.30, 1.05, rn), hurt * smoothstep(0.55, 1.10, rn) * 0.55), bleed_ring * 0.65);
	col = mix(col, vec3(0.28, 0.008, 0.005), clamp(hem, 0.0, 0.78));

	vec2 g = FRAGCOORD.xy + time_seed * 37.0;
	float noise = fract(sin(dot(g, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	col += noise * GRAIN * (1.0 + hurt * 1.2 + max(hit_pulse, suppress) * 1.6) * (0.6 + 0.4 * rn) * (1.0 - ring);
	if (signal_loss > 0.0) {
		col = mix(col, vec3(luma(col)) * vec3(0.9, 1.0, 1.05), signal_loss * 0.7);
		col += noise * signal_loss * 0.22 + torn * signal_loss * vec3(0.02, 0.05, 0.035);
	}
	col *= 1.0 - fade;
	COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
