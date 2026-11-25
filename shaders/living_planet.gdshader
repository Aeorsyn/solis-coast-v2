shader_type spatial;
render_mode specular_schlick_ggx;

uniform int planet_type = 0; // 0 = Rocky/Terran/Ocean/Volcanic, 1 = Gas Giant, 2 = Ice Giant
uniform float planet_seed = 1.0;
uniform float life_level : hint_range(0.0, 1.0) = 0.0;
uniform float civ_level : hint_range(0.0, 1.0) = 0.0;
uniform float ruin_level : hint_range(0.0, 1.0) = 0.0;
uniform vec3 land_color : source_color = vec3(0.18, 0.46, 0.16);
uniform vec3 ocean_color : source_color = vec3(0.04, 0.24, 0.56);
uniform vec3 atmo_color : source_color = vec3(0.28, 0.72, 1.0);
uniform vec3 sun_dir = vec3(0.55, 0.48, 0.68);

varying vec3 v_dir;
varying vec3 v_world_n;

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

float fbm(vec3 p) {
	return noise3(p) * 0.58 + noise3(p * 2.18 + vec3(1.4, 2.7, 0.9)) * 0.28 + noise3(p * 4.55 + vec3(3.1, 0.5, 4.2)) * 0.14;
}

void vertex() {
	v_dir = normalize(VERTEX);
	v_world_n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 d = normalize(v_dir);
	vec3 p = d + vec3(planet_seed * 3.7, planet_seed * 1.9, planet_seed * 5.3);
	float polar = abs(d.y);
	float day_mask = smoothstep(-0.22, 0.35, dot(normalize(v_world_n), normalize(sun_dir)));
	float night_mask = 1.0 - day_mask;

	vec3 surface = vec3(0.3);
	float rough_val = 0.78;
	float metal_val = 0.04;
	float sea_mask = 1.0;
	float bump_h = 0.0;

	if (planet_type == 1) {
		// GAS GIANT: Turbulent zonal wind bands + Great Red Spot cyclone storm
		float warp = fbm(p * 3.8 + vec3(TIME * 0.018, 0.0, 0.0));
		float lat = d.y * 11.5 + warp * 2.6;
		float bands = sin(lat) * 0.5 + 0.5;
		float fine_bands = sin(lat * 2.7 + warp * 3.4) * 0.5 + 0.5;

		surface = mix(ocean_color, land_color, bands);
		surface = mix(surface, mix(atmo_color, vec3(0.96, 0.90, 0.78), 0.55), fine_bands * 0.42);

		// Giant anticyclonic storm eye
		vec3 storm_c = normalize(vec3(0.65, -0.26, 0.71));
		float storm_d = length((d - storm_c) * vec3(1.0, 1.9, 1.0));
		float storm_m = smoothstep(0.26, 0.06, storm_d);
		surface = mix(surface, vec3(0.88, 0.32, 0.16) * (0.85 + warp * 0.3), storm_m * 0.85);
		rough_val = 0.52;
		bump_h = warp * 0.25;
	} else if (planet_type == 2) {
		// ICE GIANT / CRYO-WORLD: Glaciated shell with glowing subsurface ocean fissures
		float ice_n = fbm(p * 4.5);
		float crack = 1.0 - smoothstep(0.0, 0.08, abs(fbm(p * 9.5) - 0.5));
		surface = mix(ocean_color * 0.85, mix(land_color, vec3(0.92, 0.96, 1.0), 0.65), smoothstep(0.32, 0.72, ice_n));
		surface = mix(surface, atmo_color * 1.15, crack * (0.45 + life_level * 0.55));
		rough_val = mix(0.24, 0.58, ice_n);
		metal_val = 0.14;
		bump_h = ice_n * 0.6 - crack * 0.4;
	} else {
		// TERRAN / OCEAN / DESERT / VOLCANIC: Satellite relief continents, specular seas & cloud decks
		float cont = fbm(p * 2.7);
		float mtn  = fbm(p * 9.5);
		sea_mask = smoothstep(0.46, 0.51, cont);

		vec3 rock = mix(vec3(0.20, 0.18, 0.17), vec3(0.48, 0.44, 0.39), cont * 0.65 + mtn * 0.35);
		vec3 biome = mix(land_color * 0.72, land_color * 1.30, mtn);
		// Mountain snowlines & polar ice caps
		biome = mix(biome, vec3(0.86, 0.90, 0.94), smoothstep(0.72, 0.88, mtn) * 0.55);
		biome = mix(biome, vec3(0.92, 0.95, 0.98), smoothstep(0.75, 0.89, polar));

		vec3 deep_sea = mix(ocean_color * 0.62, ocean_color * 1.25, smoothstep(0.32, 0.48, cont));
		vec3 living = mix(deep_sea, biome, sea_mask);

		// Drifting satellite cloud layer
		float clouds = smoothstep(0.54, 0.78, fbm((d + vec3(TIME * 0.010, 0.0, 0.0)) * 5.4)) * life_level * 0.62;
		surface = mix(rock, living, life_level);
		surface = mix(surface, vec3(0.96, 0.98, 1.0), clouds);
		rough_val = mix(0.86, mix(0.14, 0.74, sea_mask), life_level);
		metal_val = mix(0.05, 0.22 * (1.0 - sea_mask), life_level);
		bump_h = mix(mtn * 0.4, mtn * sea_mask * 0.85, life_level);
	}

	// Scorched extinction fissures when smitten or bombed
	float cracks = smoothstep(0.66, 0.83, noise3(p * 12.0));
	vec3 scorched = mix(vec3(0.07, 0.06, 0.06), vec3(1.0, 0.28, 0.03), cracks * ruin_level);
	surface = mix(surface, scorched, ruin_level * 0.88);

	// 3D Terrain Bump Relief (adds crisp satellite depth along the day/night terminator)
	vec3 n_off = vec3(
		noise3(p * 16.0 + vec3(0.04, 0.0, 0.0)) - noise3(p * 16.0 - vec3(0.04, 0.0, 0.0)),
		noise3(p * 16.0 + vec3(0.0, 0.04, 0.0)) - noise3(p * 16.0 - vec3(0.0, 0.04, 0.0)),
		0.0
	);
	NORMAL = normalize(NORMAL + n_off * (0.48 + bump_h * 0.35));

	// Night-side Civilization City Grids (like Google Earth from orbit!)
	float city_net = smoothstep(0.64, 0.85, noise3(p * 28.0)) * smoothstep(0.45, 0.75, noise3(p * 11.0));
	float city_mask = (planet_type == 1 ? 0.55 : sea_mask) * civ_level * (1.0 - ruin_level);
	vec3 city_col = mix(vec3(1.0, 0.74, 0.28), vec3(0.24, 0.96, 1.0), smoothstep(0.55, 0.95, civ_level));
	vec3 city_glow = city_col * city_net * city_mask * (0.65 + night_mask * 3.8);

	// Rayleigh Atmospheric Limb Scattering
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.8);
	float atmo_str = (planet_type == 1) ? 1.15 : (0.28 + life_level * 1.05);
	vec3 atmo_glow = mix(vec3(0.25, 0.28, 0.36), atmo_color, max(life_level, planet_type > 0 ? 0.85 : 0.0)) * fres * atmo_str;
	vec3 lava_glow = vec3(1.0, 0.26, 0.03) * cracks * ruin_level * 3.0;

	ALBEDO = surface;
	ROUGHNESS = rough_val;
	METALLIC = metal_val;
	EMISSION = city_glow + atmo_glow + lava_glow;
}
