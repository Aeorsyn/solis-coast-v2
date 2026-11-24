shader_type spatial;
render_mode blend_add, depth_draw_never, cull_back, unshaded;

uniform vec3 pulse_origin = vec3(0.0);
uniform float pulse_radius = 0.0;
uniform float max_radius = 160.0;
uniform vec3 pulse_color : source_color = vec3(0.10, 0.92, 1.0);

varying vec3 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float dist = distance(v_world_pos.xz, pulse_origin.xz);
	float band = smoothstep(pulse_radius - 6.5, pulse_radius, dist) * (1.0 - smoothstep(pulse_radius, pulse_radius + 1.8, dist));
	float fade = clamp(1.0 - (pulse_radius / max_radius), 0.0, 1.0);

	// Topographic elevation contour lines + 10m world grid inside the pulse trail
	float trail = smoothstep(pulse_radius - 32.0, pulse_radius - 2.0, dist) * step(dist, pulse_radius);
	float elev_line = 1.0 - smoothstep(0.0, 0.08, abs(fract(v_world_pos.y * 0.35) - 0.5));
	float grid_x = 1.0 - smoothstep(0.0, 0.03, abs(fract(v_world_pos.x * 0.1) - 0.5));
	float grid_z = 1.0 - smoothstep(0.0, 0.03, abs(fract(v_world_pos.z * 0.1) - 0.5));
	float grid = max(elev_line * 0.65, max(grid_x, grid_z) * 0.35);

	float intensity = (band * 1.4 + trail * grid * 0.65) * fade;
	ALBEDO = pulse_color * intensity * 2.2;
	ALPHA = clamp(intensity, 0.0, 1.0);
}
