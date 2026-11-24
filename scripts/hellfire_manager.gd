extends Node3D
class_name HellfireManager

var active := false
var is_desktop := true
var fx_root: Node3D
var p_sparks: GPUParticles3D
var p_charred: GPUParticles3D
var p_flames: GPUParticles3D
var fire_light_a: OmniLight3D
var fire_light_b: OmniLight3D

var demons: Array[Dictionary] = []
var bursts: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var kills := 0
var overdrive_timer := 0.0
var unlocked_incendiary := false
var unlocked_armor := false
var unlocked_brimstone := false
var spawn_timer := 0.0
var saved_fog := 0.002

signal demon_killed(cash: int, msg: String)
signal player_hit(dmg: float)
signal pickup_collected(kind: String, msg: String)
signal milestone_unlocked(tier: int, msg: String)

func setup(desktop_mode: bool) -> void:
	is_desktop = desktop_mode
	fx_root = Node3D.new()
	fx_root.visible = false
	add_child(fx_root)

	# 1. High-Density Incandescent Flying Sparks (Velocity-Aligned Streaks)
	p_sparks = GPUParticles3D.new()
	p_sparks.amount = 650 if is_desktop else 220
	p_sparks.lifetime = 1.6
	p_sparks.emitting = false
	p_sparks.visibility_aabb = AABB(Vector3(-45, -15, -45), Vector3(90, 50, 90))
	var sp_pm = ParticleProcessMaterial.new()
	sp_pm.particle_flag_align_y = true
	sp_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	sp_pm.emission_box_extents = Vector3(16.0, 5.0, 16.0)
	sp_pm.direction = Vector3(0.25, 1.0, -0.2)
	sp_pm.spread = 52.0
	sp_pm.gravity = Vector3(1.5, 4.5, -1.0)
	sp_pm.initial_velocity_min = 4.0; sp_pm.initial_velocity_max = 11.5
	sp_pm.turbulence_enabled = true; sp_pm.turbulence_noise_strength = 2.8
	p_sparks.process_material = sp_pm
	var sp_mesh = BoxMesh.new(); sp_mesh.size = Vector3(0.035, 0.42, 0.035)
	var sp_mat = StandardMaterial3D.new()
	sp_mat.albedo_color = Color(1.0, 0.85, 0.45)
	sp_mat.emission_enabled = true; sp_mat.emission = Color(1.0, 0.52, 0.10); sp_mat.emission_energy_multiplier = 7.5
	sp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sp_mesh.material = sp_mat; p_sparks.draw_pass_1 = sp_mesh
	fx_root.add_child(p_sparks)

	# 2. Tumbling Charred Ash & Burnt Debris Chunks with Glowing Edges
	p_charred = GPUParticles3D.new()
	p_charred.amount = 240 if is_desktop else 90
	p_charred.lifetime = 2.4
	p_charred.emitting = false
	p_charred.visibility_aabb = AABB(Vector3(-45, -15, -45), Vector3(90, 50, 90))
	var ch_pm = ParticleProcessMaterial.new()
	ch_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	ch_pm.emission_box_extents = Vector3(14.0, 4.5, 14.0)
	ch_pm.direction = Vector3(0.1, 1.0, 0.0); ch_pm.spread = 45.0
	ch_pm.gravity = Vector3(0.8, 2.2, 0.4)
	ch_pm.initial_velocity_min = 1.8; ch_pm.initial_velocity_max = 5.5
	ch_pm.angular_velocity_min = -180.0; ch_pm.angular_velocity_max = 180.0
	ch_pm.scale_min = 0.55; ch_pm.scale_max = 1.65
	p_charred.process_material = ch_pm
	var ch_mesh = BoxMesh.new(); ch_mesh.size = Vector3(0.26, 0.20, 0.05)
	var ch_mat = ShaderMaterial.new(); ch_mat.shader = load("res://shaders/charred_ember.gdshader")
	ch_mesh.material = ch_mat; p_charred.draw_pass_1 = ch_mesh
	fx_root.add_child(p_charred)

	# 3. Billowing Hellfire Flame Plumes
	p_flames = GPUParticles3D.new()
	p_flames.amount = 150 if is_desktop else 65
	p_flames.lifetime = 1.15
	p_flames.emitting = false
	p_flames.visibility_aabb = AABB(Vector3(-45, -15, -45), Vector3(90, 50, 90))
	var fl_pm = ParticleProcessMaterial.new()
	fl_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	fl_pm.emission_ring_radius = 16.0; fl_pm.emission_ring_inner_radius = 5.0; fl_pm.emission_ring_height = 1.0
	fl_pm.direction = Vector3(0, 1, 0); fl_pm.spread = 22.0
	fl_pm.gravity = Vector3(0, 6.5, 0)
	fl_pm.initial_velocity_min = 3.0; fl_pm.initial_velocity_max = 7.5
	fl_pm.scale_min = 0.7; fl_pm.scale_max = 2.2
	p_flames.process_material = fl_pm
	var fl_mesh = SphereMesh.new(); fl_mesh.radius = 0.48; fl_mesh.height = 1.25
	var fl_mat = StandardMaterial3D.new()
	fl_mat.albedo_color = Color(1.0, 0.32, 0.04, 0.42)
	fl_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fl_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fl_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fl_mat.emission_enabled = true; fl_mat.emission = Color(1.0, 0.42, 0.08); fl_mat.emission_energy_multiplier = 4.2
	fl_mesh.material = fl_mat; p_flames.draw_pass_1 = fl_mesh
	fx_root.add_child(p_flames)

	# 4. Flickering Dynamic Fire Rim-Lights
	fire_light_a = OmniLight3D.new(); fire_light_a.light_color = Color(1.0, 0.44, 0.12); fire_light_a.omni_range = 24.0; fire_light_a.light_energy = 5.5
	fire_light_b = OmniLight3D.new(); fire_light_b.light_color = Color(1.0, 0.24, 0.05); fire_light_b.omni_range = 20.0; fire_light_b.light_energy = 4.5
	fx_root.add_child(fire_light_a); fx_root.add_child(fire_light_b)

func set_active(state: bool, env: Environment, sky: ProceduralSkyMaterial, sun: DirectionalLight3D, focus_pos: Vector3) -> void:
	active = state
	fx_root.visible = active
	p_sparks.emitting = active
	p_charred.emitting = active
	p_flames.emitting = active

	if active:
		saved_fog = env.volumetric_fog_density
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.018
		env.volumetric_fog_albedo = Color(0.55, 0.18, 0.06)
		env.glow_intensity = 1.15; env.glow_bloom = 0.38
		env.ambient_light_energy = 0.85
		sky.sky_top_color = Color(0.14, 0.04, 0.02)
		sky.sky_horizon_color = Color(0.75, 0.24, 0.06)
		sky.ground_horizon_color = Color(0.32, 0.10, 0.03)
		sun.light_color = Color(1.0, 0.48, 0.18); sun.light_energy = 1.25; sun.rotation_degrees.x = -34.0
		spawn_timer = 0.5
		for i in 4: _spawn_demon(focus_pos)
	else:
		env.volumetric_fog_density = saved_fog
		env.volumetric_fog_albedo = Color(0.45, 0.28, 0.42)
		env.glow_intensity = 0.72; env.glow_bloom = 0.20
		for d in demons:
			if is_instance_valid(d["body"]): d["body"].queue_free()
		demons.clear()

func _spawn_demon(around: Vector3) -> void:
	var body = CharacterBody3D.new()
	body.collision_layer = 8; body.collision_mask = 3
	var ang = randf() * TAU; var dist = randf_range(16.0, 32.0)
	body.position = Vector3(around.x + cos(ang) * dist, 1.1, around.z + sin(ang) * dist)

	var skin = StandardMaterial3D.new()
	skin.albedo_color = Color(0.14, 0.05, 0.05); skin.roughness = 0.45
	skin.emission_enabled = true; skin.emission = Color(0.95, 0.22, 0.02); skin.emission_energy_multiplier = 0.75

	var lava = StandardMaterial3D.new()
	lava.albedo_color = Color(1.0, 0.55, 0.08); lava.emission_enabled = true; lava.emission = Color(1.0, 0.45, 0.05); lava.emission_energy_multiplier = 5.5

	# Hulking Horned Demon Silhouette
	var torso = MeshInstance3D.new(); var tm = CylinderMesh.new(); tm.top_radius = 0.46; tm.bottom_radius = 0.28; tm.height = 1.15; tm.material = skin
	torso.mesh = tm; torso.position = Vector3(0, 0.45, 0); body.add_child(torso)

	var core = MeshInstance3D.new(); var cm = SphereMesh.new(); cm.radius = 0.24; cm.material = lava
	core.mesh = cm; core.position = Vector3(0, 0.58, 0.24); body.add_child(core)

	var head = MeshInstance3D.new(); var hm = SphereMesh.new(); hm.radius = 0.24; hm.material = skin
	head.mesh = hm; head.position = Vector3(0, 1.24, 0.08); body.add_child(head)

	# Curved Glowing Horns & Eyes
	for sx in [-1.0, 1.0]:
		var horn = MeshInstance3D.new(); var hnm = CylinderMesh.new(); hnm.top_radius = 0.02; hnm.bottom_radius = 0.08; hnm.height = 0.55; hnm.material = lava
		horn.mesh = hnm; horn.position = Vector3(sx * 0.22, 1.48, 0.02); horn.rotation_degrees = Vector3(-18, 0, -sx * 32); body.add_child(horn)
		var eye = MeshInstance3D.new(); var em = SphereMesh.new(); em.radius = 0.05; em.material = lava
		eye.mesh = em; eye.position = Vector3(sx * 0.09, 1.28, 0.28); body.add_child(eye)
		var arm = MeshInstance3D.new(); var am = CapsuleMesh.new(); am.radius = 0.13; am.height = 1.05; am.material = skin
		arm.mesh = am; arm.position = Vector3(sx * 0.52, 0.35, 0.18); arm.rotation_degrees.x = -35; body.add_child(arm)

	var col = CollisionShape3D.new(); var cs = CapsuleShape3D.new(); cs.radius = 0.55; cs.height = 2.1; col.shape = cs
	col.position = Vector3(0, 0.45, 0); body.add_child(col)
	add_child(body)
	demons.append({"body": body, "skin": skin, "hp": 80.0, "atk_cd": 0.0, "flash": 0.0})

func try_hit_demon(collider: Object, dmg: float, hit_pos: Vector3) -> bool:
	for i in range(demons.size() - 1, -1, -1):
		var d = demons[i]
		if d["body"] == collider:
			d["hp"] -= dmg; d["flash"] = 0.12
			d["skin"].emission_energy_multiplier = 6.0
			_spawn_ember_burst(hit_pos, 18)
			if d["hp"] <= 0.0:
				_spawn_ember_burst(d["body"].global_position + Vector3(0, 0.8, 0), 55)
				d["body"].queue_free()
				demons.remove_at(i)
				kills += 1
				_spawn_pickup(d["body"].global_position + Vector3(0, 0.55, 0))
				demon_killed.emit(250, "DEMON BANISHED (%d KILLS)! +$250" % kills)
				_check_unlocks()
			return true
	return false

func _spawn_ember_burst(pos: Vector3, amt: int) -> void:
	var p = GPUParticles3D.new()
	p.one_shot = true; p.explosiveness = 0.92; p.amount = amt; p.lifetime = 0.75
	p.position = pos
	var pm = ParticleProcessMaterial.new()
	pm.particle_flag_align_y = true; pm.spread = 180.0
	pm.initial_velocity_min = 5.0; pm.initial_velocity_max = 15.0; pm.gravity = Vector3(0, -6.0, 0)
	p.process_material = pm
	var m = BoxMesh.new(); m.size = Vector3(0.06, 0.36, 0.06)
	var mat = StandardMaterial3D.new(); mat.albedo_color = Color(1, 0.8, 0.3)
	mat.emission_enabled = true; mat.emission = Color(1, 0.45, 0.06); mat.emission_energy_multiplier = 8.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material = mat; p.draw_pass_1 = m
	add_child(p); p.emitting = true
	bursts.append({"node": p, "t": 0.9})

func update_hellfire(delta: float, focus_pos: Vector3) -> void:
	if overdrive_timer > 0.0: overdrive_timer = maxf(0.0, overdrive_timer - delta)
	for i in range(pickups.size() - 1, -1, -1):
		var pk = pickups[i]
		pk["node"].rotate_y(delta * 3.2)
		pk["t"] -= delta
		if pk["node"].global_position.distance_to(focus_pos) < 3.2:
			var kind: String = pk["kind"]
			if kind == "overdrive":
				overdrive_timer = 12.0
				pickup_collected.emit("overdrive", "HELLFIRE OVERDRIVE! 12s Infinite Ammo + Rapid Fire + Speed!")
			else:
				pickup_collected.emit("soul", "SOUL ORB ABSORBED! +35 HP & +$350!")
			pk["node"].queue_free(); pickups.remove_at(i)
		elif pk["t"] <= 0.0:
			pk["node"].queue_free(); pickups.remove_at(i)
	for i in range(bursts.size() - 1, -1, -1):
		bursts[i]["t"] -= delta
		if bursts[i]["t"] <= 0.0:
			bursts[i]["node"].queue_free(); bursts.remove_at(i)
	if not active: return

	fx_root.global_position = Vector3(focus_pos.x, focus_pos.y + 1.5, focus_pos.z)
	var t = Time.get_ticks_msec() * 0.015
	fire_light_a.position = Vector3(sin(t) * 2.5, 2.2, cos(t * 0.8) * 2.5 - 3.5)
	fire_light_a.light_energy = 4.5 + sin(t * 2.3) * 1.8
	fire_light_b.position = Vector3(cos(t * 1.1) * 3.5, 1.8, sin(t) * 3.5 + 3.0)
	fire_light_b.light_energy = 3.5 + cos(t * 2.9) * 1.5

	# Maintain active wave of demons stalking through the hellfire
	spawn_timer -= delta
	if spawn_timer <= 0.0 and demons.size() < (8 if is_desktop else 5):
		_spawn_demon(focus_pos); spawn_timer = 3.2

	for d in demons:
		var b: CharacterBody3D = d["body"]
		if d["flash"] > 0.0:
			d["flash"] -= delta
			if d["flash"] <= 0.0: d["skin"].emission_energy_multiplier = 0.75
		var to_p = focus_pos - b.global_position; to_p.y = 0
		var dist = to_p.length()
		if dist > 48.0:
			var ang = randf() * TAU
			b.global_position = Vector3(focus_pos.x + cos(ang) * 24.0, 1.1, focus_pos.z + sin(ang) * 24.0)
		elif dist > 2.2:
			var dir = to_p.normalized()
			b.velocity.x = dir.x * 5.2; b.velocity.z = dir.z * 5.2
			b.look_at(Vector3(focus_pos.x, b.global_position.y, focus_pos.z), Vector3.UP)
		else:
			b.velocity.x = 0; b.velocity.z = 0
			d["atk_cd"] -= delta
			if d["atk_cd"] <= 0.0:
				d["atk_cd"] = 1.1; player_hit.emit(10.0)
		b.velocity.y = 0.0 if b.is_on_floor() else b.velocity.y - 20.0 * delta
		b.move_and_slide()

func _spawn_pickup(pos: Vector3) -> void:
	var is_over = (kills % 3 == 0)
	var mi = MeshInstance3D.new()
	var m = SphereMesh.new(); m.radius = 0.34 if is_over else 0.28
	var mat = StandardMaterial3D.new()
	var col = Color(0.15, 0.95, 1.0) if is_over else Color(1.0, 0.28, 0.12)
	mat.albedo_color = col; mat.emission_enabled = true; mat.emission = col; mat.emission_energy_multiplier = 6.0
	m.material = mat; mi.mesh = m; mi.position = pos; add_child(mi)
	pickups.append({"node": mi, "kind": "overdrive" if is_over else "soul", "t": 22.0})

func _check_unlocks() -> void:
	if kills >= 3 and not unlocked_incendiary:
		unlocked_incendiary = true
		milestone_unlocked.emit(1, "UNLOCKED: HELLFIRE INCENDIARY ROUNDS (2x Damage + Molten Tracers)!")
	if kills >= 7 and not unlocked_armor:
		unlocked_armor = true
		milestone_unlocked.emit(2, "UNLOCKED: INFERNAL ARMOR (150 Max HP + Ember Aura)!")
	if kills >= 12 and not unlocked_brimstone:
		unlocked_brimstone = true
		milestone_unlocked.emit(3, "UNLOCKED: BRIMSTONE TRIPLE-SHOT CANNON!")
