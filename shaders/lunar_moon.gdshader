shader_type spatial;
render_mode specular_schlick_ggx;

varying vec3 v_dir;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash3(i + vec3(0,0,0)), hash3(i + vec3(1,0,0)), f.x),
			mix(hash3(i + vec3(0,1,0)), hash3(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0,0,1)), hash3(i + vec3(1,0,1)), f.x),
			mix(hash3(i + vec3(0,1,1)), hash3(i + vec3(1,1,1)), f.x), f.y), f.z
	);
}

float crater_layer(vec3 p, float scale) {
	vec3 q = p * scale;
	vec3 cell = floor(q);
	vec3 frac = fract(q) - 0.5;
	float r = length(frac);
	float rnd = hash3(cell);
	float rad = 0.22 + rnd * 0.22;
	float bowl = smoothstep(rad, rad * 0.25, r);
	float rim = smoothstep(rad * 1.18, rad, r) * (1.0 - smoothstep(rad, rad * 0.82, r));
	return (rim * 0.45 - bowl * 0.55) * step(0.42, rnd);
}

void vertex() {
	v_dir = normalize(VERTEX);
}

void fragment() {
	vec3 p = normalize(v_dir);
	// Dark basalt lunar maria + bright dusty highlands
	float maria = noise3(p * 2.4) * 0.65 + noise3(p * 5.2) * 0.35;
	float regolith = noise3(p * 14.0) * 0.6 + noise3(p * 32.0) * 0.4;

	// Multi-scale impact craters
	float c_big = crater_layer(p, 4.5);
	float c_med = crater_layer(p + vec3(2.3, 1.1, 4.7), 11.0);
	float c_sml = crater_layer(p + vec3(5.1, 3.7, 1.9), 24.0);
	float h = c_big * 0.55 + c_med * 0.30 + c_sml * 0.15 + regolith * 0.15;

	vec3 mare_col = vec3(0.24, 0.25, 0.28);
	vec3 high_col = vec3(0.76, 0.75, 0.72);
	vec3 col = mix(mare_col, high_col, smoothstep(0.36, 0.68, maria));
	col *= clamp(0.82 + h * 0.55, 0.45, 1.25);

	// Subtle relief normal perturbation for crisp crater shadows
	vec3 n_pert = vec3(
		noise3(p * 18.0 + vec3(0.05, 0, 0)) - noise3(p * 18.0 - vec3(0.05, 0, 0)),
		noise3(p * 18.0 + vec3(0, 0.05, 0)) - noise3(p * 18.0 - vec3(0, 0.05, 0)),
		0.0
	);
	NORMAL = normalize(NORMAL + n_pert * 0.45);

	// Soft silver-blue lunar rim glow visible from the city below
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.2);
	ALBEDO = col;
	ROUGHNESS = 0.94;
	METALLIC = 0.0;
	EMISSION = col * 0.16 + vec3(0.58, 0.66, 0.85) * fres * 0.55;
}
