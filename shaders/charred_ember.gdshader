shader_type spatial;
render_mode cull_disabled;

uniform vec3 ash_color : source_color = vec3(0.05, 0.03, 0.03);
uniform vec3 ember_color : source_color = vec3(1.0, 0.36, 0.04);
uniform float glow_power = 5.5;

void fragment() {
	// Dark charred ash core with incandescent molten-orange glowing edges
	float edge = pow(1.0 - abs(dot(NORMAL, VIEW)), 1.7);
	float flicker = 0.75 + 0.25 * sin(TIME * 14.0 + VERTEX.x * 18.0 + VERTEX.y * 12.0);
	ALBEDO = mix(ash_color, ember_color, edge * 0.5);
	ROUGHNESS = 0.9;
	EMISSION = ember_color * edge * glow_power * flicker;
}
