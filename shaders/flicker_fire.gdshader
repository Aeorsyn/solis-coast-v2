shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

uniform float speed = 3.6;
uniform float intensity = 4.4;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

void vertex() {
	mat4 bb = mat4(
		normalize(INV_VIEW_MATRIX[0]) * length(MODEL_MATRIX[0]),
		normalize(INV_VIEW_MATRIX[1]) * length(MODEL_MATRIX[1]),
		normalize(INV_VIEW_MATRIX[2]) * length(MODEL_MATRIX[2]),
		MODEL_MATRIX[3]
	);
	MODELVIEW_MATRIX = VIEW_MATRIX * bb;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * speed;

	// Fast 2-octave flickering noise (70% cheaper than dual 4-octave FBM)
	float sway = sin(uv.y * 9.0 - t * 2.8) * 0.13 * (1.0 - uv.y);
	vec2 p = vec2((uv.x + sway) * 3.6, uv.y * 2.9 + t);
	float n = noise(p) * 0.65 + noise(p * 2.15 - vec2(0.0, t * 1.5)) * 0.35;

	float x_dist = abs((uv.x - 0.5) * 2.0 + sway * 1.35);
	float width = mix(0.16, 0.90, pow(uv.y, 0.65));
	float mask = (1.0 - smoothstep(width * 0.22, width, x_dist)) * smoothstep(0.0, 0.20, uv.y) * smoothstep(1.0, 0.80, uv.y);

	float flame = clamp(mask * 1.45 - (1.0 - n) * (1.12 - uv.y * 0.55), 0.0, 1.0);
	vec3 col = mix(vec3(0.88, 0.12, 0.01), vec3(1.0, 0.45, 0.04), smoothstep(0.15, 0.60, flame));
	col = mix(col, vec3(1.0, 0.94, 0.68), smoothstep(0.46, 0.90, flame));

	ALBEDO = col * intensity;
	ALPHA = smoothstep(0.08, 0.38, flame) * 0.85;
}
