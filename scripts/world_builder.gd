class_name WorldBuilder

static func setup_nextgen_env(root: Node3D) -> Dictionary:
	var we = WorldEnvironment.new()
	var env = Environment.new()
	var sky = Sky.new()
	var sm = ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.06, 0.05, 0.20)
	sm.sky_horizon_color = Color(0.96, 0.36, 0.46)
	sm.ground_bottom_color = Color(0.08, 0.06, 0.14)
	sm.ground_horizon_color = Color(0.32, 0.18, 0.32)
	sm.sun_angle_max = 12.0
	sky.sky_material = sm

	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.65
	env.glow_enabled = true
	env.glow_intensity = 0.72
	env.glow_bloom = 0.20
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0032
	env.volumetric_fog_albedo = Color(0.45, 0.28, 0.42)

	# Enable true Next-Gen Forward+ features on Desktop (skip heavy passes on Mobile)
	var is_desktop = not OS.has_feature("mobile") and not OS.has_feature("android")
	if is_desktop:
		env.ssao_enabled = true
		env.ssao_radius = 1.6
		env.ssao_intensity = 1.4
		env.ssil_enabled = true
		env.ssil_radius = 4.5
		env.ssil_intensity = 0.85
		env.ssr_enabled = true
		env.ssr_max_steps = 48
		env.ssr_fade_in = 0.15
		env.ssr_fade_out = 2.0

	we.environment = env
	root.add_child(we)

	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-26, 48, 0)
	sun.light_color = Color(1.0, 0.82, 0.64)
	sun.light_energy = 1.65
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 180.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if is_desktop else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	root.add_child(sun)

	# Camera-tracked GPU Rain Particles (off by default, toggle via F3)
	var rain = GPUParticles3D.new()
	rain.amount = 900 if is_desktop else 300
	rain.lifetime = 0.85
	rain.emitting = false
	rain.visibility_aabb = AABB(Vector3(-40, -30, -40), Vector3(80, 50, 80))
	var pmat = ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(28.0, 1.0, 28.0)
	pmat.gravity = Vector3(0, -34.0, 0)
	pmat.direction = Vector3(0, -1, 0)
	pmat.initial_velocity_min = 12.0
	pmat.initial_velocity_max = 18.0
	rain.process_material = pmat

	var drop_mesh = BoxMesh.new()
	drop_mesh.size = Vector3(0.025, 0.85, 0.025)
	var dmat = StandardMaterial3D.new()
	dmat.albedo_color = Color(0.68, 0.86, 1.0, 0.48)
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop_mesh.material = dmat
	rain.draw_pass_1 = drop_mesh
	root.add_child(rain)

	return {"sun": sun, "sky_mat": sm, "env": env, "rain": rain, "is_desktop": is_desktop}

static func build_fallback_city(root: Node3D) -> Dictionary:
	var refs = setup_nextgen_env(root)
	var sw_pbr = ProcTextures.sidewalk_pbr()
	var rd_pbr = ProcTextures.road_pbr()

	var g_mat = StandardMaterial3D.new()
	g_mat.albedo_texture = sw_pbr["albedo"]; g_mat.normal_enabled = true; g_mat.normal_texture = sw_pbr["normal"]
	g_mat.uv1_scale = Vector3(0.22, 0.22, 0.22); g_mat.uv1_triplanar = true; g_mat.roughness = 0.78
	_box_mat(root, Vector3(200, 1, 290), Vector3(-45, -0.5, 0), g_mat, true)
	_box(root, Vector3(22, 0.9, 290), Vector3(64, -0.55, 0), Color(0.84, 0.74, 0.56), false, true)

	var water = MeshInstance3D.new()
	var pm = PlaneMesh.new(); pm.size = Vector2(220, 380); pm.subdivide_width = 48; pm.subdivide_depth = 64
	var wmat = ShaderMaterial.new(); wmat.shader = load("res://shaders/aurora_water.gdshader")
	pm.material = wmat; water.mesh = pm; water.position = Vector3(175, -0.30, 0); root.add_child(water)

	var r_mat = StandardMaterial3D.new()
	r_mat.albedo_texture = rd_pbr["albedo"]; r_mat.normal_enabled = true; r_mat.normal_texture = rd_pbr["normal"]
	r_mat.roughness_texture = rd_pbr["roughness"]; r_mat.roughness = 0.65
	_road(root, r_mat, Vector3(16, 0.08, 270), Vector3(0, 0.04, 0), 0.0, 22.0)
	_road(root, r_mat, Vector3(16, 0.08, 195), Vector3(-42, 0.035, 0), 90.0, 16.0)

	# Dual-Exit Walk-In Buildings (Front Entrance + Rear Exit with glowing green exit beacons)
	_walkin_dual_exit(root, Vector3(26, 0, -29), 18.0, 5.2, 14.0, Color(0.22, 0.28, 0.32), Color(0.15, 0.95, 0.45), 5.5)
	_walkin_dual_exit(root, Vector3(-28, 0, 32), 20.0, 5.5, 16.0, Color(0.20, 0.24, 0.26), Color(0.10, 0.88, 0.98), 8.5)
	_walkin_dual_exit(root, Vector3(-42, 0, -97), 16.0, 4.8, 12.0, Color(0.32, 0.20, 0.34), Color(0.95, 0.28, 0.85), 5.0)

	refs["road_mat"] = r_mat
	refs["ground_mat"] = g_mat
	return refs

static func _box_mat(root: Node3D, size: Vector3, pos: Vector3, mat: Material, solid: bool) -> StaticBody3D:
	var b = StaticBody3D.new(); b.position = pos
	var mi = MeshInstance3D.new(); var bm = BoxMesh.new(); bm.size = size; bm.material = mat
	mi.mesh = bm; b.add_child(mi)
	if solid:
		var cs = CollisionShape3D.new(); var bs = BoxShape3D.new(); bs.size = size; cs.shape = bs; b.add_child(cs)
	root.add_child(b); return b

static func _box(root: Node3D, size: Vector3, pos: Vector3, col: Color, emissive := false, solid := true) -> StaticBody3D:
	var mat = StandardMaterial3D.new(); mat.albedo_color = col
	if emissive: mat.emission_enabled = true; mat.emission = col; mat.emission_energy_multiplier = 2.6
	return _box_mat(root, size, pos, mat, solid)

static func _road(root: Node3D, mat: StandardMaterial3D, size: Vector3, pos: Vector3, rot_y: float, tiles: float) -> void:
	var m = mat.duplicate() as StandardMaterial3D
	m.uv1_scale = Vector3(1, tiles, 1)
	var mi = MeshInstance3D.new(); var bm = BoxMesh.new(); bm.size = size; bm.material = m
	mi.mesh = bm; mi.position = pos; mi.rotation_degrees.y = rot_y; root.add_child(mi)

static func _walkin_dual_exit(root: Node3D, center: Vector3, w: float, h: float, d: float, wall_col: Color, neon_col: Color, door_w: float) -> void:
	var t := 0.6
	_box(root, Vector3(w, 0.14, d), Vector3(center.x, 0.07, center.z), wall_col.lightened(0.22), false, false)
	_box(root, Vector3(w + 0.6, 0.5, d + 0.6), Vector3(center.x, h + 0.25, center.z), wall_col.darkened(0.2), false, true)
	_box(root, Vector3(w + 0.9, 0.32, d + 0.9), Vector3(center.x, h + 0.05, center.z), neon_col, true, false)
	_box(root, Vector3(t, h, d), Vector3(center.x - w * 0.5, h * 0.5, center.z), wall_col, false, true)
	_box(root, Vector3(t, h, d), Vector3(center.x + w * 0.5, h * 0.5, center.z), wall_col, false, true)

	# Both South (Front) and North (Rear) walls feature wide open exits + glowing green EXIT bars
	var sw = maxf(0.5, (w - door_w) * 0.5)
	for z_sign in [-1.0, 1.0]:
		var z_pos = center.z + z_sign * (d * 0.5)
		_box(root, Vector3(sw, h, t), Vector3(center.x - w * 0.5 + sw * 0.5, h * 0.5, z_pos), wall_col, false, true)
		_box(root, Vector3(sw, h, t), Vector3(center.x + w * 0.5 - sw * 0.5, h * 0.5, z_pos), wall_col, false, true)
		_box(root, Vector3(door_w * 0.6, 0.26, 0.35), Vector3(center.x, h - 0.55, z_pos), Color(0.15, 1.0, 0.45), true, false)

	var il = OmniLight3D.new(); il.position = Vector3(center.x, h - 1.0, center.z)
	il.light_color = neon_col.lerp(Color.WHITE, 0.65); il.light_energy = 3.2; il.omni_range = maxf(w, d) * 1.3
	root.add_child(il)
