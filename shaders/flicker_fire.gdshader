shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

uniform float speed = 3.2;
uniform float intensity = 4.6;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.08 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	// Camera-facing billboard preserving per-particle scale
	mat4 bb = mat4(
		normalize(INV_VIEW_MATRIX[0]) * length(MODEL_MATRIX[0]),
		normalize(INV_VIEW_MATRIX[1]) * length(MODEL_MATRIX[1]),
		normalize(INV_VIEW_MATRIX[2]) * length(MODEL_MATRIX[2]),
		MODEL_MATRIX[3]
	);
	MODELVIEW_MATRIX = VIEW_MATRIX * bb;
}

void fragment() {
	// UV.y = 0 is top tip of flame, UV.y = 1 is base
	vec2 uv = UV;
	float t = TIME * speed;

	// Horizontal flicker sway increasing toward the flame tips
	float sway = sin(uv.y * 8.0 - t * 2.4) * 0.12 * (1.0 - uv.y);
	vec2 n_uv = vec2((uv.x + sway) * 3.4, uv.y * 2.8 + t);
	float n1 = fbm(n_uv);
	float n2 = fbm(n_uv * 2.1 - vec2(0.0, t * 1.4));
	float n = n1 * 0.65 + n2 * 0.35;

	// Tapered flame silhouette with jagged tongues at top
	float x_dist = abs((uv.x - 0.5) * 2.0 + sway * 1.4);
	float width_profile = mix(0.18, 0.95, pow(uv.y, 0.65));
	float shape = (1.0 - smoothstep(width_profile * 0.25, width_profile, x_dist)) * smoothstep(0.0, 0.22, uv.y) * smoothstep(1.0, 0.78, uv.y);

	float flame = clamp((shape * 1.45) - (1.0 - n) * (1.15 - uv.y * 0.55), 0.0, 1.0);
	float core = smoothstep(0.45, 0.92, flame);
	float mid  = smoothstep(0.16, 0.62, flame);

	vec3 col = mix(vec3(0.85, 0.10, 0.01), vec3(1.0, 0.44, 0.04), mid);
	col = mix(col, vec3(1.0, 0.94, 0.68), core);

	ALBEDO = col * intensity;
	ALPHA = smoothstep(0.06, 0.36, flame) * 0.88;
}
