extends Node3D
class_name BiblicalUAP

const MAX_SHELL := 72

var ring_outer: Node3D
var ring_mid: Node3D
var ring_inner: Node3D
var core_mesh: MeshInstance3D
var core_light: OmniLight3D

# Katamari Accretion Shell & Gravity Vortex FX
var vortex_root: Node3D
var vortex_rings: Array[MeshInstance3D] = []
var mm_shell: MultiMeshInstance3D
var shell_data: Array[Dictionary] = []

var pulse := 0.0
var t_acc := 0.0
var siphon_active := false
var siphon_charge := 0.0 # 0.0 to 5.0 (up to 5 full planets stored!)

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
	core_light.light_color = Color(1.0, 0.88, 0.52); core_light.light_energy = 5.5; core_light.omni_range = 28.0
	add_child(core_light)

	# 3 Nested Counter-Rotating Ophanim Rings Studded With Glowing Eyes
	ring_outer = _make_eye_ring(1.95, 0.13, 16, gold_mat, eye_sclera, eye_iris)
	ring_mid   = _make_eye_ring(1.42, 0.11, 12, gold_mat, eye_sclera, eye_iris)
	ring_inner = _make_eye_ring(0.94, 0.09,  8, gold_mat, eye_sclera, eye_iris)
	add_child(ring_outer); add_child(ring_mid); add_child(ring_inner)

	_build_katamari_fx()

func _build_katamari_fx() -> void:
	# 1. Orbiting Katamari Accretion Shell (72 magma-crust shards clinging around the UAP)
	var shard_m = PrismMesh.new(); shard_m.size = Vector3(0.46, 0.54, 0.38)
	var shard_mat = StandardMaterial3D.new()
	shard_mat.vertex_color_use_as_albedo = true; shard_mat.roughness = 0.65
	shard_mat.emission_enabled = true; shard_mat.emission = Color(1.0, 0.48, 0.12); shard_mat.emission_energy_multiplier = 1.9
	shard_m.material = shard_mat

	var mm = MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = true
	mm.mesh = shard_m; mm.instance_count = MAX_SHELL; mm.visible_instance_count = 0
	mm_shell = MultiMeshInstance3D.new(); mm_shell.multimesh = mm
	mm_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mm_shell)

	shell_data.clear()
	var pal = [Color(1.0, 0.52, 0.14), Color(0.28, 0.94, 1.0), Color(1.0, 0.86, 0.32), Color(0.75, 0.38, 0.24)]
	for i in MAX_SHELL:
		var axis = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var base_dir = axis.cross(Vector3.UP)
		if base_dir.length() < 0.1: base_dir = axis.cross(Vector3.RIGHT)
		base_dir = base_dir.normalized()
		shell_data.append({
			"axis": axis, "dir": base_dir,
			"rad": randf_range(2.35, 3.85),
			"spd": randf_range(1.6, 4.2) * (1.0 if i % 2 == 0 else -1.0),
			"ang": randf() * TAU, "sc": randf_range(0.55, 1.45),
			"col": pal[i % pal.size()]
		})
		mm.set_instance_color(i, shell_data[i]["col"])

	# 2. Pulsing Gravitational Singularity Vortex Rings (visible while holding [G])
	vortex_root = Node3D.new(); vortex_root.visible = false; add_child(vortex_root)
	var v_mat = StandardMaterial3D.new()
	v_mat.albedo_color = Color(0.32, 0.96, 1.0, 0.55); v_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	v_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; v_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	v_mat.emission_enabled = true; v_mat.emission = Color(0.25, 0.92, 1.0); v_mat.emission_energy_multiplier = 6.5

	for k in 3:
		var tor = TorusMesh.new(); tor.inner_radius = 2.6; tor.outer_radius = 2.82; tor.rings = 28; tor.ring_segments = 6
		tor.material = v_mat
		var mi = MeshInstance3D.new(); mi.mesh = tor; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.rotation_degrees = Vector3(k * 60.0, k * 45.0, k * 30.0)
		vortex_root.add_child(mi); vortex_rings.append(mi)

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
	siphon_charge = clampf(charge_ratio, 0.0, 5.0)

func update_uap(u_delta: float, vel: Vector3, is_aiming: bool) -> void:
	t_acc += u_delta
	pulse = maxf(0.0, pulse - u_delta * 4.5)
	var norm_c = clampf(siphon_charge / 5.0, 0.0, 1.0)
	var spd_boost = 1.0 + clampf(vel.length() / 22.0, 0.0, 2.6) + pulse * 1.8 + (2.8 if siphon_active else 0.0) + norm_c * 2.2

	# Gyroscopic Ezekiel-Wheel counter-rotations
	ring_outer.rotate_y(u_delta * 1.35 * spd_boost)
	ring_outer.rotate_x(u_delta * 0.45 * spd_boost)
	ring_mid.rotate_z(-u_delta * 1.95 * spd_boost)
	ring_mid.rotate_x(u_delta * 1.10 * spd_boost)
	ring_inner.rotate_x(-u_delta * 2.65 * spd_boost)
	ring_inner.rotate_y(u_delta * 1.75 * spd_boost)

	# Swelling molten core scaled by stored planet count
	var sc = 1.0 + sin(t_acc * 5.0) * 0.07 + pulse * 0.28 + clampf(siphon_charge * 0.28, 0.0, 1.25) + (0.26 if siphon_active else 0.0)
	core_mesh.scale = Vector3.ONE * sc
	core_light.light_energy = (7.5 if is_aiming else 5.2) + pulse * 4.5 + norm_c * 7.0 + (4.5 if siphon_active else 0.0)

	# Update Katamari Orbiting Accretion Shell
	var vis_cnt = int(round(clampf(siphon_charge / 3.5, 0.0, 1.0) * float(MAX_SHELL)))
	if siphon_charge > 0.05 and vis_cnt < 6: vis_cnt = 6
	var mm = mm_shell.multimesh
	mm.visible_instance_count = vis_cnt
	var rad_expand = 1.0 + norm_c * 0.55
	var orb_boost = 2.6 if siphon_active else 1.0
	for i in vis_cnt:
		var sd = shell_data[i]
		sd["ang"] += u_delta * sd["spd"] * orb_boost
		var pos = sd["dir"].rotated(sd["axis"], sd["ang"]) * (sd["rad"] * rad_expand)
		var rot = Basis(sd["axis"], sd["ang"] * 2.2).scaled(Vector3.ONE * (sd["sc"] * (0.85 + norm_c * 0.55)))
		mm.set_instance_transform(i, Transform3D(rot, pos))

	# Update Pulsing Singularity Vortex Rings when holding [G]
	vortex_root.visible = siphon_active
	if siphon_active:
		vortex_root.rotate_y(u_delta * 3.5)
		for k in vortex_rings.size():
			var vr = vortex_rings[k]
			var phase = fmod(t_acc * 2.4 + float(k) * 0.33, 1.0)
			# Imploding shock-rings pulling inward toward the UAP core!
			var ring_sc = lerpf(2.8, 0.35, phase)
			vr.scale = Vector3.ONE * ring_sc
			vr.rotate_z(u_delta * (2.5 + float(k)))
