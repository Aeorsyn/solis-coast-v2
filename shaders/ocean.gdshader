shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

uniform vec3 deep_color : source_color = vec3(0.02, 0.16, 0.28);
uniform vec3 shallow_color : source_color = vec3(0.06, 0.42, 0.56);
uniform vec3 dusk_glow : source_color = vec3(0.92, 0.34, 0.52);

void vertex() {
	float t = TIME * 1.4;
	float w1 = sin(VERTEX.x * 0.18 + t) * 0.22;
	float w2 = cos(VERTEX.z * 0.14 + t * 0.85) * 0.18;
	VERTEX.y += w1 + w2;
}

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float ripple = sin(UV.x * 90.0 + TIME * 2.0) * cos(UV.y * 90.0 - TIME * 1.6) * 0.05;
	vec3 base = mix(deep_color, shallow_color, clamp(fresnel + ripple, 0.0, 1.0));
	ALBEDO = mix(base, dusk_glow, fresnel * 0.38);
	METALLIC = 0.25;
	ROUGHNESS = 0.12;
	SPECULAR = 0.85;
}
