shader_type sky;

uniform float hellfire_blend : hint_range(0.0, 1.0) = 0.0;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.11, 0.17, 0.23));
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

float fbm3(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * noise3(p);
		p = p * 2.15 + vec3(1.7, 3.1, 2.3);
		a *= 0.5;
	}
	return v;
}

float star_layer(vec3 dir, float scale, float thresh) {
	vec3 q = dir * scale;
	vec3 cell = floor(q);
	vec3 f = fract(q) - 0.5;
	float rnd = hash3(cell);
	if (rnd < thresh) return 0.0;
	vec3 jitter = vec3(hash3(cell + 1.1), hash3(cell + 2.3), hash3(cell + 3.7)) - 0.5;
	float d = length(f - jitter * 0.55);
	float twinkle = 0.78 + 0.22 * sin(TIME * (1.8 + rnd * 4.0) + rnd * 62.0);
	return smoothstep(0.19, 0.01, d) * twinkle * ((rnd - thresh) / (1.0 - thresh));
}

vec3 spiral_galaxy(vec3 dir, vec3 center, vec3 axis, float size, vec3 tint) {
	vec3 c = normalize(center);
	float dp = dot(dir, c);
	if (dp < 0.75) return vec3(0.0);
	vec3 diff = dir - c * dp;
	vec3 u = normalize(cross(axis, c));
	vec3 v = cross(c, u);
	vec2 uv = vec2(dot(diff, u), dot(diff, v) * 2.3) / size;
	float r = length(uv);
	if (r > 1.4) return vec3(0.0);
	float ang = atan(uv.y, uv.x);
	float arms = pow(0.5 + 0.5 * cos(ang * 2.0 - r * 7.5), 2.2);
	float disc = exp(-r * 3.1) * (0.35 + 0.65 * arms);
	float core = exp(-r * 11.5) * 1.6;
	return mix(tint, vec3(1.0, 0.94, 0.84), clamp(core, 0.0, 1.0)) * (disc + core);
}

void sky() {
	vec3 d = normalize(EYEDIR);

	// Tilted Milky Way Galactic Plane + Secondary Cosmic Rift
	float gal_y = dot(d, normalize(vec3(0.35, 0.82, -0.45)));
	float band = exp(-abs(gal_y) * 4.6);
	float core_glow = pow(max(0.0, dot(d, normalize(vec3(-0.45, 0.25, -0.85)))), 3.4);

	// Multi-Color Hubble/JWST Nebula Clouds & Dark Dust Pillars
	float neb1 = fbm3(d * 3.2 + vec3(0.0, TIME * 0.002, 0.0));
	float neb2 = fbm3(d * 6.8 - vec3(1.2, 0.4, 2.1));
	float neb3 = fbm3(d * 4.5 + vec3(2.8, -1.5, 0.9));
	float dust = smoothstep(0.40, 0.70, fbm3(d * 5.8 + vec3(4.1, 2.0, 1.3)));

	vec3 deep_void   = vec3(0.008, 0.012, 0.030);
	vec3 milky_col   = mix(vec3(0.12, 0.20, 0.44), vec3(0.54, 0.34, 0.72), neb1);
	vec3 hubble_cyan = vec3(0.06, 0.48, 0.64) * smoothstep(0.48, 0.84, neb2) * (0.28 + band * 0.95);
	vec3 carina_rose = vec3(0.68, 0.16, 0.48) * smoothstep(0.54, 0.86, neb3) * (0.20 + band * 0.85);
	vec3 hubble_gold = vec3(0.84, 0.48, 0.20) * core_glow * (0.45 + neb1 * 0.55);

	vec3 col = deep_void + milky_col * band * (0.42 + neb1 * 0.70) + hubble_cyan + carina_rose + hubble_gold;
	col *= (1.0 - dust * band * 0.58);

	// 3 Distant Telescopic Spiral Galaxies hanging in deep space
	col += spiral_galaxy(d, vec3( 0.62,  0.44, -0.65), vec3(0.1, 1.0, 0.2), 0.13, vec3(0.58, 0.76, 1.0)) * 0.85;
	col += spiral_galaxy(d, vec3(-0.70,  0.32,  0.62), vec3(0.4, 0.8, -0.3), 0.11, vec3(1.0, 0.62, 0.85)) * 0.75;
	col += spiral_galaxy(d, vec3( 0.12,  0.76,  0.64), vec3(-0.2, 0.6, 0.7), 0.09, vec3(0.45, 0.95, 0.88)) * 0.70;

	// 4-Tier Pinpoint Starfield (ultra-fine background dust stars to bright colored beacons)
	float s_dust = star_layer(d, 260.0, 0.955);
	float s_fine = star_layer(d, 165.0, 0.962);
	float s_mid  = star_layer(d,  88.0, 0.970);
	float s_big  = star_layer(d,  40.0, 0.984);
	vec3 star_tint = mix(vec3(0.70, 0.88, 1.0), vec3(1.0, 0.84, 0.60), hash3(floor(d * 88.0)));

	col += vec3(0.72, 0.80, 0.96) * s_dust * (0.55 + band * 1.2);
	col += vec3(0.88, 0.94, 1.00) * s_fine * (0.85 + band * 1.4);
	col += star_tint * s_mid * 1.75;
	col += mix(vec3(0.60, 0.90, 1.0), vec3(1.0, 0.72, 0.42), fract(s_big * 13.7)) * s_big * 3.0;

	if (hellfire_blend > 0.01) {
		vec3 infernal = vec3(0.60, 0.09, 0.14) * (0.35 + band * 0.85 + neb1 * 0.5);
		col = mix(col, col * 0.55 + infernal, hellfire_blend * 0.72);
	}

	COLOR = col;
}
