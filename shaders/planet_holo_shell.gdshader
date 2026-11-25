shader_type spatial;
render_mode unshaded, cull_back, blend_add, depth_draw_never;

uniform float planet_seed = 1.0;
uniform float shell_layer = 0.0; // 0.0 = inner parallax ion/cloud veil, 1.0 = outer holographic lattice
uniform float holo_strength : hint_range(0.0, 2.0) = 1.0;
uniform vec3 atmo_color : source_color = vec3(0.28, 0.76, 1.0);

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

void vertex() {
	v_dir = normalize(VERTEX);
}

void fragment() {
	vec3 d = normalize(v_dir);
	vec3 p = d + vec3(planet_seed * 2.3, planet_seed * 1.1, planet_seed * 3.7);
	float ndv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fres = pow(1.0 - ndv, mix(2.2, 3.2, shell_layer));

	// Iridescent holographic spectral shift (cyan -> violet -> gold across viewing angle)
	vec3 spec = 0.5 + 0.5 * cos(6.28318 * (vec3(0.0, 0.33, 0.67) + fres * 0.85 + TIME * 0.04));
	vec3 holo_tint = mix(atmo_color, spec, 0.42);

	// Drifting 3D volumetric cloud/ion wisps for physical depth parallax
	float wisp = noise3(p * 5.2 + vec3(TIME * 0.025, -TIME * 0.012, 0.0)) * 0.65
	           + noise3(p * 11.5 - vec3(TIME * 0.04, 0.0, TIME * 0.02)) * 0.35;

	// Fine holographic scan-filaments & latitude/longitude resonance grid on outer shell
	float lat_lines = pow(abs(sin(d.y * 44.0 + TIME * 0.6)), 24.0);
	float lon_lines = pow(abs(sin(atan(d.z, d.x) * 24.0 - TIME * 0.25)), 28.0);
	float grid = max(lat_lines, lon_lines) * shell_layer;

	float density = mix(smoothstep(0.42, 0.82, wisp) * 0.42 + fres * 0.55, fres * 0.88 + grid * 0.38, shell_layer);
	ALBEDO = holo_tint * (0.95 + grid * 1.25) * holo_strength;
	ALPHA = clamp(density * (0.28 + fres * 0.52), 0.0, 0.62);
}
