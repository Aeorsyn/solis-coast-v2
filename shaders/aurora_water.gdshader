shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

uniform vec3 deep_color : source_color = vec3(0.01, 0.14, 0.28);
uniform vec3 shallow_color : source_color = vec3(0.04, 0.48, 0.58);
uniform vec3 sky_reflect_color : source_color = vec3(0.45, 0.72, 0.96);
uniform vec3 sun_color : source_color = vec3(1.0, 0.92, 0.75);
uniform vec3 sun_dir = vec3(0.45, 0.55, -0.70);
uniform float wave_height = 0.22;
uniform float wave_speed = 1.15;
uniform float hell_mix : hint_range(0.0, 1.0) = 0.0;

varying vec3 v_world;

float wave_h(vec2 p, float t) {
	float w1 = sin(p.x * 0.28 + t * 1.4 + p.y * 0.15) * 0.45;
	float w2 = sin(p.x * -0.18 + p.y * 0.36 + t * 1.9) * 0.35;
	float w3 = sin((p.x + p.y) * 0.65 - t * 2.6) * 0.20;
	return (w1 + w2 + w3) * wave_height;
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * wave_speed;
	float h = wave_h(wp.xz, t);
	VERTEX.y += h;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	// Analytical finite-difference normal for crisp Aurora Voyage ripples
	float eps = 0.35;
	float hx = wave_h(wp.xz + vec2(eps, 0.0), t);
	float hz = wave_h(wp.xz + vec2(0.0, eps), t);
	NORMAL = normalize(vec3(h - hx, eps, h - hz));
}

void fragment() {
	float t = TIME * wave_speed;
	// High-frequency micro-ripples for realistic specular glints
	vec2 uv1 = v_world.xz * 0.42 + vec2(t * 0.45, t * 0.28);
	vec2 uv2 = v_world.xz * 0.78 - vec2(t * 0.32, t * 0.51);
	float r1 = sin(uv1.x * 3.1 + cos(uv1.y * 2.7));
	float r2 = cos(uv2.x * 4.3 - sin(uv2.y * 3.9));
	vec3 n = normalize(NORMAL + vec3(r1 * 0.09, 0.0, r2 * 0.09));

	float fresnel = pow(1.0 - clamp(dot(n, VIEW), 0.0, 1.0), 3.6);
	vec3 base_water = mix(deep_color, shallow_color, clamp(0.35 + (r1 + r2) * 0.12, 0.0, 1.0));
	vec3 reflected = mix(base_water, sky_reflect_color, fresnel * 0.85);

	// Sun / Moon sparkle glint
	vec3 ldir = normalize(sun_dir);
	vec3 half_v = normalize(ldir + VIEW);
	float glint = pow(max(dot(n, half_v), 0.0), 180.0) * 2.2;
	float foam = smoothstep(0.68, 0.96, (r1 * r2) * 0.5 + 0.5) * 0.22;

	vec3 final_col = reflected + sun_color * glint + vec3(foam);
	// Hellfire Mode transforms waterways into dark crusted molten lava
	vec3 lava_col = mix(vec3(0.08, 0.02, 0.01), vec3(1.0, 0.34, 0.04), smoothstep(-0.2, 0.6, r1 + r2));
	ALBEDO = mix(final_col, lava_col, hell_mix);
	ROUGHNESS = mix(0.08, 0.35, hell_mix);
	METALLIC = mix(0.28, 0.05, hell_mix);
	EMISSION = mix(sun_color * glint * 0.35, lava_col * 1.8, hell_mix);
}
