shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;

uniform float wind_strength = 0.14;
uniform float wind_speed = 1.8;
uniform float roughness_val = 0.72;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h_mask = clamp(VERTEX.y * 0.35, 0.0, 1.4);
	float t = TIME * wind_speed;
	float gust = sin(t + wp.x * 0.18 + wp.z * 0.14) * 0.65 + cos(t * 1.7 + wp.z * 0.31) * 0.35;
	VERTEX.x += gust * wind_strength * h_mask;
	VERTEX.z += cos(t * 1.3 + wp.x * 0.22) * wind_strength * 0.6 * h_mask;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = roughness_val;
	METALLIC = 0.02;
	// Subtle backlit leaf translucency
	BACKLIGHT = COLOR.rgb * 0.28;
}
