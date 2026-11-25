extends Node3D
class_name AbyssManager

var active := false
var is_desktop := true
var fx_root: Node3D
var p_stars: GPUParticles3D
var p_shards: GPUParticles3D
var p_nebula: GPUParticles3D
var p_dust: GPUParticles3D
var light_a: OmniLight3D
var light_b: OmniLight3D
var moon_body: StaticBody3D = null
var moon_mesh: MeshInstance3D = null
var moon_pos := Vector3.ZERO

# Array name kept as "demons" so RPG Short Circuit & Plasma Dash work seamlessly
var demons: Array[Dictionary] = []
var bolts: Array[Dictionary] = []
var bursts: Array[Dictionary] = []
var pickups: Array[Dictionary] = []

# Shared cached meshes & materials for high-FPS aerial dogfights
var m_tictac: CapsuleMesh; var m_tictac_ring: TorusMesh
var m_tri_hull: PrismMesh; var m_tri_node: SphereMesh
var m_orb_core: SphereMesh; var m_orb_halo: TorusMesh
var m_boss_disc: CylinderMesh; var m_boss_ring: TorusMesh; var m_boss_spire: PrismMesh
var m_bolt: SphereMesh

var mat_white_gloss: StandardMaterial3D
var mat_obsidian: StandardMaterial3D
var mat_chrome: StandardMaterial3D
var neon_mats: Array[StandardMaterial3D] = []
var bolt_mats: Array[StandardMaterial3D] = []
var neon_cols := [
	Color(0.00, 0.98, 1.00), # Electric Cyan (Tic-Tac)
	Color(1.00, 0.08, 0.62), # Hot Magenta (TR-3B)
	Color(0.22, 1.00, 0.08), # Acid Lime (Plasma Orb)
	Color(1.00, 0.88, 0.06)  # Solar Gold (Dreadnought)
]

var spawn_timer := 0.0
var kills := 0
var boss_active := false
var overdrive_timer := 0.0

signal void_killed(cash: int, msg: String)
signal player_hit(dmg: float)
signal pickup_collected(kind: String, msg: String)

func setup(desktop_mode: bool) -> void:
	is_desktop = desktop_mode
	_init_cached_assets()
	fx_root = Node3D.new(); fx_root.visible = false; add_child(fx_root)

	# 1. Cosmic Starfield
	p_stars = GPUParticles3D.new()
	p_stars.amount = 320 if is_desktop else 140; p_stars.lifetime = 2.8; p_stars.emitting = false
	p_stars.visibility_aabb = AABB(Vector3(-85, -85, -85), Vector3(170, 170, 170))
	var st_pm = ParticleProcessMaterial.new()
	st_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	st_pm.emission_box_extents = Vector3(50.0, 40.0, 50.0)
	st_pm.gravity = Vector3.ZERO; st_pm.spread = 180.0
	st_pm.initial_velocity_min = 0.4; st_pm.initial_velocity_max = 2.2
	p_stars.process_material = st_pm
	var st_mesh = SphereMesh.new(); st_mesh.radius = 0.09; st_mesh.height = 0.18; st_mesh.radial_segments = 6; st_mesh.rings = 3
	var st_mat = StandardMaterial3D.new()
	st_mat.albedo_color = Color(0.78, 0.94, 1.0); st_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	st_mat.emission_enabled = true; st_mat.emission = Color(0.55, 0.85, 1.0); st_mat.emission_energy_multiplier = 6.0
	st_mesh.material = st_mat; p_stars.draw_pass_1 = st_mesh; fx_root.add_child(p_stars)

	# 2. Zero-G Obsidian Shards
	p_shards = GPUParticles3D.new()
	p_shards.amount = 75 if is_desktop else 35; p_shards.lifetime = 4.2; p_shards.emitting = false
	p_shards.visibility_aabb = AABB(Vector3(-65, -65, -65), Vector3(130, 130, 130))
	var sh_pm = ParticleProcessMaterial.new()
	sh_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	sh_pm.emission_box_extents = Vector3(32.0, 22.0, 32.0)
	sh_pm.gravity = Vector3.ZERO; sh_pm.spread = 180.0
	sh_pm.initial_velocity_min = 0.5; sh_pm.initial_velocity_max = 2.2
	sh_pm.angular_velocity_min = -80.0; sh_pm.angular_velocity_max = 80.0
	sh_pm.scale_min = 0.5; sh_pm.scale_max = 1.5
	p_shards.process_material = sh_pm
	var sh_mesh = PrismMesh.new(); sh_mesh.size = Vector3(0.42, 0.68, 0.24)
	var sh_mat = StandardMaterial3D.new()
	sh_mat.albedo_color = Color(0.06, 0.03, 0.12); sh_mat.roughness = 0.3; sh_mat.metallic = 0.7
	sh_mat.emission_enabled = true; sh_mat.emission = Color(0.58, 0.14, 1.0); sh_mat.emission_energy_multiplier = 2.4
	sh_mesh.material = sh_mat; p_shards.draw_pass_1 = sh_mesh; fx_root.add_child(p_shards)

	# 3. Cosmic Nebula Wisps
	p_nebula = GPUParticles3D.new()
	p_nebula.amount = 50 if is_desktop else 24; p_nebula.lifetime = 3.0; p_nebula.emitting = false
	p_nebula.visibility_aabb = AABB(Vector3(-65, -65, -65), Vector3(130, 130, 130))
	var nb_pm = ParticleProcessMaterial.new()
	nb_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	nb_pm.emission_ring_radius = 30.0; nb_pm.emission_ring_inner_radius = 12.0; nb_pm.emission_ring_height = 20.0
	nb_pm.gravity = Vector3.ZERO; nb_pm.scale_min = 1.0; nb_pm.scale_max = 2.4
	p_nebula.process_material = nb_pm
	var nb_mesh = SphereMesh.new(); nb_mesh.radius = 0.48; nb_mesh.height = 0.96; nb_mesh.radial_segments = 8; nb_mesh.rings = 4
	var nb_mat = StandardMaterial3D.new()
	nb_mat.albedo_color = Color(0.42, 0.12, 0.95, 0.22)
	nb_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; nb_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	nb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	nb_mat.emission_enabled = true; nb_mat.emission = Color(0.48, 0.16, 1.0); nb_mat.emission_energy_multiplier = 3.2
	nb_mesh.material = nb_mat; p_nebula.draw_pass_1 = nb_mesh; fx_root.add_child(p_nebula)

	# 4. Luminous Golden/Cyan Cosmic Stardust Drift Layer
	p_dust = GPUParticles3D.new()
	p_dust.amount = 240 if is_desktop else 95; p_dust.lifetime = 3.6; p_dust.emitting = false
	p_dust.visibility_aabb = AABB(Vector3(-70, -70, -70), Vector3(140, 140, 140))
	var du_pm = ParticleProcessMaterial.new()
	du_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	du_pm.emission_box_extents = Vector3(38.0, 28.0, 38.0)
	du_pm.gravity = Vector3.ZERO; du_pm.spread = 180.0
	du_pm.initial_velocity_min = 0.6; du_pm.initial_velocity_max = 2.8
	p_dust.process_material = du_pm
	var du_mesh = SphereMesh.new(); du_mesh.radius = 0.055; du_mesh.height = 0.11; du_mesh.radial_segments = 5; du_mesh.rings = 3
	var du_mat = StandardMaterial3D.new(); du_mat.albedo_color = Color(1.0, 0.88, 0.55)
	du_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	du_mat.emission_enabled = true; du_mat.emission = Color(1.0, 0.80, 0.35); du_mat.emission_energy_multiplier = 7.2
	du_mesh.material = du_mat; p_dust.draw_pass_1 = du_mesh; fx_root.add_child(p_dust)

	light_a = OmniLight3D.new(); light_a.light_color = Color(0.22, 0.85, 1.0); light_a.omni_range = 28.0; light_a.light_energy = 4.2
	light_b = OmniLight3D.new(); light_b.light_color = Color(0.72, 0.18, 1.0); light_b.omni_range = 26.0; light_b.light_energy = 3.8
	fx_root.add_child(light_a); fx_root.add_child(light_b)

	# Lifelike Flyable Cratered Moon
	moon_body = StaticBody3D.new()
	moon_body.collision_layer = 2; moon_body.collision_mask = 0; moon_body.visible = false
	moon_mesh = MeshInstance3D.new()
	var msph = SphereMesh.new(); msph.radius = 52.0; msph.height = 104.0; msph.radial_segments = 48; msph.rings = 24
	var mmat = ShaderMaterial.new(); mmat.shader = load("res://shaders/lunar_moon.gdshader")
	msph.material = mmat; moon_mesh.mesh = msph; moon_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	moon_body.add_child(moon_mesh)
	var mcol = CollisionShape3D.new(); var mcs = SphereShape3D.new(); mcs.radius = 52.0
	mcol.shape = mcs; moon_body.add_child(mcol)
	add_child(moon_body)

func _init_cached_assets() -> void:
	# Tic-Tac Interceptor meshes
	m_tictac = CapsuleMesh.new(); m_tictac.radius = 0.52; m_tictac.height = 2.65; m_tictac.radial_segments = 12; m_tictac.rings = 4
	m_tictac_ring = TorusMesh.new(); m_tictac_ring.inner_radius = 0.62; m_tictac_ring.outer_radius = 0.78; m_tictac_ring.rings = 16; m_tictac_ring.ring_segments = 6

	# Black Triangle TR-3B meshes
	m_tri_hull = PrismMesh.new(); m_tri_hull.size = Vector3(3.4, 3.6, 0.42)
	m_tri_node = SphereMesh.new(); m_tri_node.radius = 0.34; m_tri_node.height = 0.68; m_tri_node.radial_segments = 8; m_tri_node.rings = 4

	# Plasma Orb / Foo Fighter meshes
	m_orb_core = SphereMesh.new(); m_orb_core.radius = 0.72; m_orb_core.height = 1.44; m_orb_core.radial_segments = 12; m_orb_core.rings = 6
	m_orb_halo = TorusMesh.new(); m_orb_halo.inner_radius = 0.96; m_orb_halo.outer_radius = 1.16; m_orb_halo.rings = 18; m_orb_halo.ring_segments = 6

	# Seraphim Dreadnought Boss meshes
	m_boss_disc = CylinderMesh.new(); m_boss_disc.top_radius = 2.2; m_boss_disc.bottom_radius = 3.8; m_boss_disc.height = 1.3; m_boss_disc.radial_segments = 16
	m_boss_ring = TorusMesh.new(); m_boss_ring.inner_radius = 4.2; m_boss_ring.outer_radius = 4.85; m_boss_ring.rings = 24; m_boss_ring.ring_segments = 8
	m_boss_spire = PrismMesh.new(); m_boss_spire.size = Vector3(1.6, 3.4, 1.6)

	m_bolt = SphereMesh.new(); m_bolt.radius = 0.25; m_bolt.height = 0.50; m_bolt.radial_segments = 8; m_bolt.rings = 4

	mat_white_gloss = StandardMaterial3D.new()
	mat_white_gloss.albedo_color = Color(0.95, 0.98, 1.0); mat_white_gloss.roughness = 0.12; mat_white_gloss.metallic = 0.35
	mat_white_gloss.emission_enabled = true; mat_white_gloss.emission = Color(0.25, 0.92, 1.0); mat_white_gloss.emission_energy_multiplier = 0.45

	mat_obsidian = StandardMaterial3D.new()
	mat_obsidian.albedo_color = Color(0.05, 0.05, 0.08); mat_obsidian.roughness = 0.18; mat_obsidian.metallic = 0.85
	mat_obsidian.emission_enabled = true; mat_obsidian.emission = Color(0.75, 0.06, 0.45); mat_obsidian.emission_energy_multiplier = 0.35

	mat_chrome = StandardMaterial3D.new()
	mat_chrome.albedo_color = Color(0.85, 0.92, 0.96); mat_chrome.roughness = 0.08; mat_chrome.metallic = 0.96

	neon_mats.clear(); bolt_mats.clear()
	for nc in neon_cols:
		var nm = StandardMaterial3D.new()
		nm.albedo_color = Color.WHITE; nm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		nm.emission_enabled = true; nm.emission = nc; nm.emission_energy_multiplier = 7.2
		neon_mats.append(nm)

		var bm = StandardMaterial3D.new()
		bm.albedo_color = nc; bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bm.emission_enabled = true; bm.emission = nc; bm.emission_energy_multiplier = 6.8
		bolt_mats.append(bm)

func set_active(state: bool, env: Environment, sky: ProceduralSkyMaterial, sun: DirectionalLight3D, focus_pos: Vector3) -> void:
	active = state
	fx_root.visible = active
	p_stars.emitting = active; p_shards.emitting = active; p_nebula.emitting = active; if p_dust: p_dust.emitting = active

	if active:
		if moon_body:
			moon_pos = Vector3(focus_pos.x, 265.0, focus_pos.z - 250.0)
			moon_body.global_position = moon_pos
			moon_body.visible = true
		env.volumetric_fog_enabled = false
		env.fog_enabled = true; env.fog_density = 0.005; env.fog_light_color = Color(0.14, 0.06, 0.34)
		env.glow_intensity = 1.25; env.glow_bloom = 0.40; env.ambient_light_energy = 0.72
		sky.sky_top_color = Color(0.01, 0.01, 0.04)
		sky.sky_horizon_color = Color(0.16, 0.05, 0.34)
		sky.ground_horizon_color = Color(0.05, 0.02, 0.14)
		sun.light_color = Color(0.62, 0.78, 1.0); sun.light_energy = 1.05; sun.rotation_degrees.x = -28.0
		spawn_timer = 0.3; boss_active = false
		var init_cnt = 10 if is_desktop else 6
		for i in init_cnt: _spawn_uap_enemy(focus_pos, "")
	else:
		if moon_body: moon_body.visible = false
		env.fog_enabled = false; env.glow_intensity = 0.72; env.glow_bloom = 0.20
		for d in demons:
			if is_instance_valid(d["body"]): d["body"].queue_free()
		demons.clear(); boss_active = false
		for b in bolts:
			if is_instance_valid(b["node"]): b["node"].queue_free()
		bolts.clear()

func _add_part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot_deg := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh; mi.material_override = mat
	mi.position = pos; mi.rotation_degrees = rot_deg; mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi); return mi

func _spawn_uap_enemy(around: Vector3, force_kind: String) -> void:
	var kind = force_kind
	if kind.is_empty():
		var r = randf()
		kind = "tictac" if r < 0.38 else ("tr3b" if r < 0.68 else "orb")

	var body = CharacterBody3D.new()
	body.collision_layer = 8; body.collision_mask = 0
	var ang = randf() * TAU
	var dist = randf_range(36.0, 56.0) if kind == "dreadnought" else randf_range(22.0, 50.0)
	var y_off = randf_range(6.0, 22.0) if kind == "dreadnought" else randf_range(-5.0, 18.0)
	body.position = Vector3(around.x + cos(ang) * dist, maxf(6.0, around.y + y_off), around.z + sin(ang) * dist)

	var rig = Node3D.new(); body.add_child(rig)
	var spinner: Node3D = null
	var col_idx := 0; var hp := 55.0; var hit_r := 1.25

	match kind:
		"tictac":
			col_idx = 0; hp = 48.0; hit_r = 1.35
			_add_part(rig, m_tictac, mat_white_gloss, Vector3.ZERO, Vector3(90, 0, 0))
			spinner = Node3D.new(); rig.add_child(spinner)
			_add_part(spinner, m_tictac_ring, neon_mats[0], Vector3(0, 0, 0), Vector3(90, 0, 0))
		"tr3b":
			col_idx = 1; hp = 115.0; hit_r = 1.95
			_add_part(rig, m_tri_hull, mat_obsidian, Vector3.ZERO, Vector3(90, 0, 0))
			# 3 Corner Thrusters + Central Gravitic Core
			_add_part(rig, m_tri_node, neon_mats[1], Vector3(0, 0.0, 0.12), Vector3.ZERO, Vector3(1.4, 0.7, 1.4))
			for pt in [Vector3(0, 0, -1.45), Vector3(-1.35, 0, 1.25), Vector3(1.35, 0, 1.25)]:
				_add_part(rig, m_tri_node, neon_mats[1], pt, Vector3.ZERO, Vector3(0.75, 0.75, 0.75))
		"orb":
			col_idx = 2; hp = 58.0; hit_r = 1.20
			_add_part(rig, m_orb_core, mat_chrome, Vector3.ZERO)
			spinner = Node3D.new(); rig.add_child(spinner)
			_add_part(spinner, m_orb_halo, neon_mats[2], Vector3.ZERO)
			_add_part(spinner, m_orb_halo, neon_mats[0], Vector3.ZERO, Vector3(90, 0, 0), Vector3(0.86, 0.86, 0.86))
		"dreadnought":
			col_idx = 3; hp = 290.0; hit_r = 3.9; boss_active = true
			_add_part(rig, m_boss_disc, mat_obsidian, Vector3.ZERO)
			_add_part(rig, m_boss_spire, neon_mats[3], Vector3(0, 1.5, 0))
			_add_part(rig, m_boss_spire, neon_mats[1], Vector3(0, -1.5, 0), Vector3(180, 0, 0))
			spinner = Node3D.new(); rig.add_child(spinner)
			_add_part(spinner, m_boss_ring, neon_mats[3], Vector3.ZERO)
			for i in 6:
				var a = TAU * float(i) / 6.0
				_add_part(spinner, m_tri_node, neon_mats[0], Vector3(cos(a) * 4.5, 0, sin(a) * 4.5), Vector3.ZERO, Vector3(1.2, 1.2, 1.2))

	var col = CollisionShape3D.new(); var cs = SphereShape3D.new(); cs.radius = hit_r
	col.shape = cs; body.add_child(col)
	add_child(body)

	demons.append({
		"body": body, "rig": rig, "spinner": spinner, "kind": kind,
		"col_idx": col_idx, "col": neon_cols[col_idx], "hp": hp,
		"atk_cd": randf_range(1.4, 2.8), "hit_pop": 0.0,
		"juke_cd": randf_range(1.2, 2.5), "juke_vel": Vector3.ZERO,
		"phase": randf() * TAU, "orbit_dir": 1.0 if randf() > 0.5 else -1.0,
		"y_bias": randf_range(-4.0, 14.0)
	})

func _spawn_bolt(origin: Vector3, dir: Vector3, col_idx: int, spd := 22.0) -> void:
	if bolts.size() >= 22: return
	var mi = MeshInstance3D.new()
	mi.mesh = m_bolt; mi.material_override = bolt_mats[col_idx % bolt_mats.size()]
	mi.position = origin; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	bolts.append({"node": mi, "vel": dir.normalized() * spd, "col": neon_cols[col_idx % neon_cols.size()], "t": 3.6})

func try_hit_demon(collider: Object, dmg: float, hit_pos: Vector3) -> bool:
	for i in range(demons.size() - 1, -1, -1):
		var d = demons[i]
		if d["body"] == collider:
			d["hp"] -= dmg; d["hit_pop"] = 0.12
			d["rig"].scale = Vector3.ONE * 1.22
			_spawn_burst(hit_pos, 14, d["col"])
			if d["hp"] <= 0.0:
				var p = d["body"].global_position
				var kind: String = d["kind"]
				_spawn_burst(p, 75 if kind == "dreadnought" else 40, d["col"])
				kills += 1
				if kind == "dreadnought": boss_active = false
				_spawn_pickup(p, kind == "dreadnought")
				d["body"].queue_free(); demons.remove_at(i)
				var cash = 1200 if kind == "dreadnought" else (500 if kind == "tr3b" else 350)
				var label = {"tictac": "TIC-TAC INTERCEPTOR", "tr3b": "TR-3B BLACK TRIANGLE", "orb": "PLASMA ORB", "dreadnought": "SERAPHIM DREADNOUGHT BOSS"}[kind]
				void_killed.emit(cash, "%s DESTROYED (%d KILLS)! +$%d" % [label, kills, cash])
			return true
	return false

func _spawn_burst(pos: Vector3, amt: int, col: Color) -> void:
	var p = GPUParticles3D.new()
	p.one_shot = true; p.explosiveness = 0.94; p.amount = amt; p.lifetime = 0.65; p.position = pos
	var pm = ParticleProcessMaterial.new()
	pm.particle_flag_align_y = true; pm.spread = 180.0; pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 6.0; pm.initial_velocity_max = 18.0
	p.process_material = pm
	var m = BoxMesh.new(); m.size = Vector3(0.07, 0.42, 0.07)
	var mat = StandardMaterial3D.new(); mat.albedo_color = col
	mat.emission_enabled = true; mat.emission = col; mat.emission_energy_multiplier = 8.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material = mat; p.draw_pass_1 = m; add_child(p); p.emitting = true
	bursts.append({"node": p, "t": 0.75})

func _spawn_pickup(pos: Vector3, force_overdrive := false) -> void:
	var is_over = force_overdrive or (kills % 3 == 0)
	var mi = MeshInstance3D.new(); var m = SphereMesh.new(); m.radius = 0.45; m.height = 0.90; m.radial_segments = 8; m.rings = 4
	var mat = StandardMaterial3D.new(); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var col = Color(0.20, 1.0, 0.85) if is_over else Color(0.85, 0.28, 1.0)
	mat.albedo_color = col; mat.emission_enabled = true; mat.emission = col; mat.emission_energy_multiplier = 6.5
	m.material = mat; mi.mesh = m; mi.position = pos; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	pickups.append({"node": mi, "kind": "overdrive" if is_over else "astral", "t": 22.0})

func update_abyss(delta: float, focus_pos: Vector3) -> void:
	if overdrive_timer > 0.0: overdrive_timer = maxf(0.0, overdrive_timer - delta)

	for i in range(pickups.size() - 1, -1, -1):
		var pk = pickups[i]; var n: Node3D = pk["node"]
		n.rotate_y(delta * 3.5); pk["t"] -= delta
		var dist = n.global_position.distance_to(focus_pos)
		if dist < 24.0 and dist > 0.2:
			n.global_position = n.global_position.lerp(focus_pos, clampf(delta * 5.2, 0.0, 1.0))
		if dist < 4.0:
			if pk["kind"] == "overdrive":
				overdrive_timer = 12.0
				pickup_collected.emit("overdrive", "ASTRAL OVERDRIVE! 12s Infinite Ammo + Hyper-Warp!")
			else:
				pickup_collected.emit("astral", "UAP ENERGY CORE ABSORBED! +35 HP & +$400!")
			n.queue_free(); pickups.remove_at(i)
		elif pk["t"] <= 0.0:
			n.queue_free(); pickups.remove_at(i)

	for i in range(bursts.size() - 1, -1, -1):
		bursts[i]["t"] -= delta
		if bursts[i]["t"] <= 0.0: bursts[i]["node"].queue_free(); bursts.remove_at(i)

	for i in range(bolts.size() - 1, -1, -1):
		var b = bolts[i]; b["t"] -= delta
		b["node"].global_position += b["vel"] * delta
		if b["node"].global_position.distance_to(focus_pos + Vector3(0, 0.6, 0)) < 1.6:
			_spawn_burst(b["node"].global_position, 16, b["col"])
			player_hit.emit(10.0)
			b["node"].queue_free(); bolts.remove_at(i)
		elif b["t"] <= 0.0:
			b["node"].queue_free(); bolts.remove_at(i)

	if not active: return

	fx_root.global_position = focus_pos
	if moon_mesh and moon_body.visible: moon_mesh.rotate_y(delta * 0.015)
	var t = Time.get_ticks_msec() * 0.008
	light_a.position = Vector3(sin(t) * 4.5, 3.0, cos(t) * 4.5)
	light_b.position = Vector3(-cos(t * 0.9) * 4.5, -2.0, sin(t * 1.1) * 4.5)

	# Maintain 18 UAP enemies (10 mobile) + Dreadnought Boss every 6 kills
	spawn_timer -= delta
	var max_d = 18 if is_desktop else 10
	if spawn_timer <= 0.0 and demons.size() < max_d:
		if kills > 0 and kills % 6 == 0 and not boss_active:
			_spawn_uap_enemy(focus_pos, "dreadnought")
		else:
			_spawn_uap_enemy(focus_pos, "")
		spawn_timer = 1.3

	for d in demons:
		var b: CharacterBody3D = d["body"]
		var kind: String = d["kind"]
		if d["hit_pop"] > 0.0:
			d["hit_pop"] -= delta
			if d["hit_pop"] <= 0.0: d["rig"].scale = Vector3.ONE

		d["phase"] += delta * 5.0
		if d["spinner"]:
			d["spinner"].rotate_y(delta * (3.8 if kind == "orb" else 2.2))
			if kind == "orb": d["spinner"].rotate_x(delta * 2.9)

		var to_p = focus_pos - b.global_position
		var dist = to_p.length()
		if dist > 95.0:
			var a = randf() * TAU
			b.global_position = focus_pos + Vector3(cos(a) * 38.0, randf_range(-4.0, 16.0), sin(a) * 38.0)
			continue

		var horiz = Vector3(to_p.x, 0, to_p.z)
		var rad_dir = horiz.normalized() if horiz.length() > 0.1 else Vector3.FORWARD
		var tang = Vector3(-rad_dir.z, 0, rad_dir.x) * d["orbit_dir"]

		match kind:
			"tictac":
				# Instantaneous right-angle UAP quantum jukes
				d["juke_cd"] -= delta
				if d["juke_cd"] <= 0.0:
					d["juke_cd"] = randf_range(1.1, 2.2)
					var j_dir = (tang * (1.0 if randf() > 0.5 else -1.0) + Vector3(0, randf_range(-0.6, 0.7), 0)).normalized()
					d["juke_vel"] = j_dir * 32.0
				d["juke_vel"] = d["juke_vel"].lerp(Vector3.ZERO, clampf(delta * 3.8, 0.0, 1.0))
				var pull = 1.0 if dist > 30.0 else (-0.8 if dist < 14.0 else 0.0)
				b.global_position += (d["juke_vel"] + rad_dir * pull * 8.0) * delta
				b.look_at(focus_pos, Vector3.UP)
			"tr3b":
				# Smooth ominous triangle patrol
				var pull = 1.0 if dist > 34.0 else (-0.5 if dist < 18.0 else 0.0)
				var ty = maxf(6.0, focus_pos.y + d["y_bias"] + 5.0)
				var vel = tang * 7.5 + rad_dir * pull * 5.0
				vel.y = clampf((ty - b.global_position.y) * 1.8, -5.0, 5.0)
				b.global_position += vel * delta
				b.look_at(focus_pos, Vector3.UP)
			"orb":
				# Fast corkscrew swarm weaving
				var pull = 1.0 if dist > 24.0 else (-0.9 if dist < 10.0 else 0.0)
				var weave = Vector3(0, sin(d["phase"] * 1.6) * 9.0, 0) + tang * (12.5 + cos(d["phase"]) * 4.0)
				b.global_position += (weave + rad_dir * pull * 9.0) * delta
			"dreadnought":
				# Towering slow-orbiting boss
				var pull = 1.0 if dist > 44.0 else (-0.4 if dist < 24.0 else 0.0)
				var ty = maxf(14.0, focus_pos.y + 10.0)
				var vel = tang * 5.2 + rad_dir * pull * 4.5
				vel.y = clampf((ty - b.global_position.y) * 1.4, -4.0, 4.0)
				b.global_position += vel * delta

		d["atk_cd"] -= delta
		if d["atk_cd"] <= 0.0 and dist < 56.0:
			var aim_dir = (focus_pos + Vector3(0, 0.6, 0) - b.global_position).normalized()
			match kind:
				"tictac":
					d["atk_cd"] = randf_range(2.2, 3.6)
					_spawn_bolt(b.global_position, aim_dir, 0, 27.0)
				"tr3b":
					d["atk_cd"] = randf_range(3.0, 4.4)
					# 3-shot plasma spread
					for spread in [-0.14, 0.0, 0.14]:
						_spawn_bolt(b.global_position, aim_dir.rotated(Vector3.UP, spread), 1, 21.0)
				"orb":
					d["atk_cd"] = randf_range(2.4, 3.8)
					_spawn_bolt(b.global_position, aim_dir, 2, 24.0)
				"dreadnought":
					d["atk_cd"] = 2.6
					# 6-way radial plasma barrage
					for k in 6:
						var sp_a = (TAU * float(k) / 6.0) + d["phase"] * 0.2
						var d_rad = (aim_dir * 0.75 + Vector3(cos(sp_a), sin(sp_a) * 0.35, sin(sp_a)) * 0.45).normalized()
						_spawn_bolt(b.global_position, d_rad, 3, 22.0)
