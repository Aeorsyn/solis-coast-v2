shader_type spatial;
render_mode unshaded;

uniform vec3 core_color : source_color = vec3(1.0, 0.95, 0.82);
uniform vec3 flare_color : source_color = vec3(1.0, 0.48, 0.08);
uniform float pulse_speed = 1.6;
uniform float energy = 6.5;

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
	vec3 p = normalize(v_dir);
	float t = TIME * pulse_speed;
	float boil = noise3(p * 5.5 + vec3(t * 0.35, -t * 0.25, t * 0.2)) * 0.65
	           + noise3(p * 12.0 - vec3(t * 0.5, t * 0.4, 0.0)) * 0.35;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	vec3 col = mix(flare_color, core_color, smoothstep(0.28, 0.76, boil));
	col = mix(col, flare_color * 1.45, fres * 0.7);
	ALBEDO = col * energy * (0.92 + 0.08 * sin(t * 2.5));
}
