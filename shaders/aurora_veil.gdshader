shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform vec3 color_a : source_color = vec3(0.05, 0.98, 0.72);
uniform vec3 color_b : source_color = vec3(0.24, 0.46, 1.00);
uniform vec3 color_c : source_color = vec3(0.95, 0.20, 0.82);
uniform float intensity = 1.55;
uniform float flow_speed = 0.20;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x),
		mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

void vertex() {
	float t = TIME * flow_speed;
	float wave = sin(VERTEX.x * 0.014 + t * 2.0) * 16.0 + cos(VERTEX.z * 0.012 - t * 1.5) * 12.0;
	VERTEX.y += wave;
}

void fragment() {
	float t = TIME * flow_speed;
	vec2 uv = UV;
	float n1 = noise2(vec2(uv.x * 16.0 + t * 0.7, uv.y * 2.4 - t * 0.25));
	float n2 = noise2(vec2(uv.x * 34.0 - t * 1.0, uv.y * 5.2 + n1 * 1.5));
	float ridge = pow(smoothstep(0.32, 0.92, n1 * 0.5 + n2 * 0.5), 1.65);

	float v_fade = pow(sin(clamp(uv.y, 0.0, 1.0) * 3.14159265), 1.6);
	vec3 col = mix(color_a, color_b, smoothstep(0.18, 0.74, uv.y + n1 * 0.22));
	col = mix(col, color_c, smoothstep(0.62, 0.96, n2) * 0.72);

	ALBEDO = col * intensity * (0.72 + 0.48 * n2);
	ALPHA = clamp(ridge * v_fade * 0.34, 0.0, 0.65);
}
