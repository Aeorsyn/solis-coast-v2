extends Node3D
class_name BiblicalUAP

var ring_outer: Node3D
var ring_mid: Node3D
var ring_inner: Node3D
var core_mesh: MeshInstance3D
var core_light: OmniLight3D
var pulse := 0.0
var t_acc := 0.0
var siphon_active := false
var siphon_charge := 0.0

func _ready() -> void:
	var gold_mat = StandardMaterial3D.new()
	gold_mat.albedo_color = Color(0.95, 0.76, 0.32)
	gold_mat.metallic = 0.92; gold_mat.roughness = 0.18
	gold_mat.emission_enabled = true; gold_mat.emission = Color(0.85, 0.58, 0.14); gold_mat.emission_energy_multiplier = 0.65

	var eye_sclera = StandardMaterial3D.new()
	eye_sclera.albedo_color = Color(1.0, 0.98, 0.92)
	eye_sclera.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye_sclera.emission_enabled = true; eye_sclera.emission = Color(1.0, 0.92, 0.65); eye_sclera.emission_energy_multiplier = 3.2

	var eye_iris = StandardMaterial3D.new()
	eye_iris.albedo_color = Color(0.20, 0.95, 1.0)
	eye_iris.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye_iris.emission_enabled = true; eye_iris.emission = Color(0.18, 0.92, 1.0); eye_iris.emission_energy_multiplier = 7.0

	var core_mat = StandardMaterial3D.new()
	core_mat.albedo_color = Color(1.0, 0.98, 0.88)
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.emission_enabled = true; core_mat.emission = Color(1.0, 0.88, 0.45); core_mat.emission_energy_multiplier = 8.5

	# Blazing Sacred Core
	core_mesh = MeshInstance3D.new()
	var cm = SphereMesh.new(); cm.radius = 0.48; cm.height = 0.96; cm.radial_segments = 14; cm.rings = 8
	cm.material = core_mat; core_mesh.mesh = cm; core_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core_mesh)

	core_light = OmniLight3D.new()
	core_light.light_color = Color(1.0, 0.88, 0.52); core_light.light_energy = 5.5; core_light.omni_range = 24.0
	add_child(core_light)

	# 3 Nested Counter-Rotating Ophanim Rings Studded With Glowing Eyes
	ring_outer = _make_eye_ring(1.95, 0.13, 16, gold_mat, eye_sclera, eye_iris)
	ring_mid   = _make_eye_ring(1.42, 0.11, 12, gold_mat, eye_sclera, eye_iris)
	ring_inner = _make_eye_ring(0.94, 0.09,  8, gold_mat, eye_sclera, eye_iris)
	add_child(ring_outer); add_child(ring_mid); add_child(ring_inner)

func _make_eye_ring(radius: float, tube: float, eye_cnt: int, ring_mat: Material, sclera_mat: Material, iris_mat: Material) -> Node3D:
	var root = Node3D.new()
	var tor = TorusMesh.new()
	tor.inner_radius = radius - tube; tor.outer_radius = radius + tube
	tor.rings = 28; tor.ring_segments = 10; tor.material = ring_mat
	var mi = MeshInstance3D.new(); mi.mesh = tor; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)

	var sm = SphereMesh.new(); sm.radius = tube * 1.15; sm.height = tube * 1.65; sm.radial_segments = 8; sm.rings = 5
	var im = SphereMesh.new(); im.radius = tube * 0.62; im.height = tube * 0.95; im.radial_segments = 6; im.rings = 4

	for i in eye_cnt:
		var ang = TAU * float(i) / float(eye_cnt)
		var dir = Vector3(cos(ang), 0.0, sin(ang))
		var eye = MeshInstance3D.new(); eye.mesh = sm; eye.material_override = sclera_mat
		eye.position = dir * (radius + tube * 0.55)
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(eye)

		var pupil = MeshInstance3D.new(); pupil.mesh = im; pupil.material_override = iris_mat
		pupil.position = dir * (radius + tube * 1.28)
		pupil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(pupil)
	return root

func pulse_fire() -> void:
	pulse = 1.0

func set_siphon_state(active: bool, charge_ratio: float) -> void:
	siphon_active = active
	siphon_charge = clampf(charge_ratio, 0.0, 1.0)

func update_uap(u_delta: float, vel: Vector3, is_aiming: bool) -> void:
	t_acc += u_delta
	pulse = maxf(0.0, pulse - u_delta * 4.5)
	var spd_boost = 1.0 + clampf(vel.length() / 22.0, 0.0, 2.6) + pulse * 1.8 + (2.4 if siphon_active else 0.0) + siphon_charge * 1.2

	# Gyroscopic Ezekiel-Wheel counter-rotations
	ring_outer.rotate_y(u_delta * 1.35 * spd_boost)
	ring_outer.rotate_x(u_delta * 0.45 * spd_boost)
	ring_mid.rotate_z(-u_delta * 1.95 * spd_boost)
	ring_mid.rotate_x(u_delta * 1.10 * spd_boost)
	ring_inner.rotate_x(-u_delta * 2.65 * spd_boost)
	ring_inner.rotate_y(u_delta * 1.75 * spd_boost)

	var sc = 1.0 + sin(t_acc * 5.0) * 0.07 + pulse * 0.28 + siphon_charge * 0.85 + (0.22 if siphon_active else 0.0)
	core_mesh.scale = Vector3.ONE * sc
	core_light.light_energy = (7.5 if is_aiming else 5.2) + pulse * 4.5 + siphon_charge * 5.0 + (3.5 if siphon_active else 0.0)
