shader_type spatial;
render_mode specular_schlick_ggx;

uniform float planet_seed = 1.0;
uniform float life_level : hint_range(0.0, 1.0) = 0.0;
uniform float civ_level : hint_range(0.0, 1.0) = 0.0;
uniform float ruin_level : hint_range(0.0, 1.0) = 0.0;
uniform vec3 land_color : source_color = vec3(0.18, 0.46, 0.16);
uniform vec3 ocean_color : source_color = vec3(0.04, 0.24, 0.56);
uniform vec3 atmo_color : source_color = vec3(0.28, 0.72, 1.0);

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
	vec3 p = normalize(v_dir) + vec3(planet_seed * 3.7, planet_seed * 1.9, planet_seed * 5.3);
	float cont = noise3(p * 2.6) * 0.65 + noise3(p * 6.2) * 0.35;
	float detail = noise3(p * 16.0);
	float polar = abs(v_dir.y);

	// 1. Dead barren rock base
	vec3 rock = mix(vec3(0.22, 0.20, 0.19), vec3(0.46, 0.42, 0.38), cont * 0.7 + detail * 0.3);

	// 2. Living oceans, lush continents & polar ice caps
	float sea_mask = smoothstep(0.47, 0.52, cont);
	vec3 lush = mix(land_color * 0.75, land_color * 1.25, detail);
	lush = mix(lush, vec3(0.88, 0.92, 0.96), smoothstep(0.76, 0.90, polar));
	vec3 living = mix(ocean_color * (0.75 + detail * 0.35), lush, sea_mask);

	// Subtle drifting cloud bands when life flourishes
	float clouds = smoothstep(0.56, 0.78, noise3((normalize(v_dir) + vec3(TIME * 0.012, 0.0, 0.0)) * 5.2)) * life_level * 0.55;
	vec3 surface = mix(rock, living, life_level);
	surface = mix(surface, vec3(0.95, 0.97, 1.0), clouds);

	// 3. Scorched ash & molten fissures during Smite / Extinction
	float cracks = smoothstep(0.68, 0.84, noise3(p * 12.0));
	vec3 scorched = mix(vec3(0.08, 0.07, 0.07), vec3(1.0, 0.28, 0.03), cracks * ruin_level);
	surface = mix(surface, scorched, ruin_level * 0.88);

	// 4. Glowing civilization city grids & megastructures on land
	float city_pat = smoothstep(0.66, 0.86, noise3(p * 28.0)) * sea_mask * civ_level * (1.0 - ruin_level);
	vec3 city_glow = mix(vec3(1.0, 0.72, 0.22), vec3(0.22, 0.95, 1.0), smoothstep(0.55, 0.95, civ_level)) * city_pat * 3.8;

	// 5. Fresnel atmosphere rim
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 atmo_glow = mix(vec3(0.28, 0.28, 0.32), atmo_color, life_level) * fres * (0.28 + life_level * 0.95);
	vec3 lava_glow = vec3(1.0, 0.25, 0.02) * cracks * ruin_level * 2.8;

	ALBEDO = surface;
	ROUGHNESS = mix(0.88, mix(0.18, 0.72, sea_mask), life_level);
	METALLIC = mix(0.05, 0.15 * (1.0 - sea_mask), life_level);
	EMISSION = city_glow + atmo_glow + lava_glow;
}
