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
var projectiles: Array[Dictionary] = []
var bursts: Array[Dictionary] = []
var pickups: Array[Dictionary] = []

var spawn_timer := 0.0
var saved_fog := 0.002
var kills := 0
var overdrive_timer := 0.0
var unlocked_incendiary := false
var unlocked_armor := false
var unlocked_brimstone := false

signal demon_killed(cash: int, msg: String)
signal player_hit(dmg: float)
signal pickup_collected(kind: String, msg: String)
signal milestone_unlocked(tier: int, msg: String)

func setup(desktop_mode: bool) -> void:
	is_desktop = desktop_mode
	fx_root = Node3D.new(); fx_root.visible = false; add_child(fx_root)

	# 1. High-Density Incandescent Flying Sparks
	p_sparks = GPUParticles3D.new()
	p_sparks.amount = 650 if is_desktop else 220; p_sparks.lifetime = 1.6; p_sparks.emitting = false
	p_sparks.visibility_aabb = AABB(Vector3(-45, -15, -45), Vector3(90, 50, 90))
	var sp_pm = ParticleProcessMaterial.new()
	sp_pm.particle_flag_align_y = true; sp_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	sp_pm.emission_box_extents = Vector3(16.0, 5.0, 16.0); sp_pm.direction = Vector3(0.25, 1.0, -0.2); sp_pm.spread = 52.0
	sp_pm.gravity = Vector3(1.5, 4.5, -1.0); sp_pm.initial_velocity_min = 4.0; sp_pm.initial_velocity_max = 11.5
	sp_pm.turbulence_enabled = true; sp_pm.turbulence_noise_strength = 2.8
	p_sparks.process_material = sp_pm
	var sp_mesh = BoxMesh.new(); sp_mesh.size = Vector3(0.035, 0.42, 0.035)
	var sp_mat = StandardMaterial3D.new(); sp_mat.albedo_color = Color(1.0, 0.85, 0.45)
	sp_mat.emission_enabled = true; sp_mat.emission = Color(1.0, 0.52, 0.10); sp_mat.emission_energy_multiplier = 7.5
	sp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sp_mesh.material = sp_mat; p_sparks.draw_pass_1 = sp_mesh; fx_root.add_child(p_sparks)

	# 2. Tumbling Charred Ash & Burnt Debris
	p_charred = GPUParticles3D.new()
	p_charred.amount = 240 if is_desktop else 90; p_charred.lifetime = 2.4; p_charred.emitting = false
	p_charred.visibility_aabb = AABB(Vector3(-45, -15, -45), Vector3(90, 50, 90))
	var ch_pm = ParticleProcessMaterial.new()
	ch_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX; ch_pm.emission_box_extents = Vector3(14.0, 4.5, 14.0)
	ch_pm.direction = Vector3(0.1, 1.0, 0.0); ch_pm.spread = 45.0; ch_pm.gravity = Vector3(0.8, 2.2, 0.4)
	ch_pm.initial_velocity_min = 1.8; ch_pm.initial_velocity_max = 5.5
	ch_pm.angular_velocity_min = -180.0; ch_pm.angular_velocity_max = 180.0
	ch_pm.scale_min = 0.55; ch_pm.scale_max = 1.65
	p_charred.process_material = ch_pm
	var ch_mesh = BoxMesh.new(); ch_mesh.size = Vector3(0.26, 0.20, 0.05)
	var ch_mat = ShaderMaterial.new(); ch_mat.shader = load("res://shaders/charred_ember.gdshader")
	ch_mesh.material = ch_mat; p_charred.draw_pass_1 = ch_mesh; fx_root.add_child(p_charred)

	# 3. Billowing Hellfire Plumes
	p_flames = GPUParticles3D.new()
	p_flames.amount = 190 if is_desktop else 80; p_flames.lifetime = 1.15; p_flames.emitting = false
	p_flames.visibility_aabb = AABB(Vector3(-45, -15, -45), Vector3(90, 50, 90))
	var fl_pm = ParticleProcessMaterial.new()
	fl_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	fl_pm.emission_ring_radius = 16.0; fl_pm.emission_ring_inner_radius = 5.0; fl_pm.emission_ring_height = 1.0
	fl_pm.direction = Vector3(0, 1, 0); fl_pm.spread = 22.0; fl_pm.gravity = Vector3(0, 6.5, 0)
	fl_pm.initial_velocity_min = 3.0; fl_pm.initial_velocity_max = 7.5; fl_pm.scale_min = 0.85; fl_pm.scale_max = 2.1
	p_flames.process_material = fl_pm
	var fl_mesh = QuadMesh.new(); fl_mesh.size = Vector2(1.45, 2.35)
	var fl_mat = ShaderMaterial.new(); fl_mat.shader = load("res://shaders/flicker_fire.gdshader")
	fl_mesh.material = fl_mat; p_flames.draw_pass_1 = fl_mesh; fx_root.add_child(p_flames)

	# 4. Flickering Dynamic Fire Rim-Lights
	fire_light_a = OmniLight3D.new(); fire_light_a.light_color = Color(1.0, 0.44, 0.12); fire_light_a.omni_range = 24.0; fire_light_a.light_energy = 5.5
	fire_light_b = OmniLight3D.new(); fire_light_b.light_color = Color(1.0, 0.24, 0.05); fire_light_b.omni_range = 20.0; fire_light_b.light_energy = 4.5
	fx_root.add_child(fire_light_a); fx_root.add_child(fire_light_b)

func set_active(state: bool, env: Environment, sky: ProceduralSkyMaterial, sun: DirectionalLight3D, focus_pos: Vector3) -> void:
	active = state
	fx_root.visible = active
	p_sparks.emitting = active; p_charred.emitting = active; p_flames.emitting = active

	if active:
		saved_fog = env.volumetric_fog_density
		env.volumetric_fog_enabled = true; env.volumetric_fog_density = 0.018
		env.volumetric_fog_albedo = Color(0.55, 0.18, 0.06)
		env.glow_intensity = 1.15; env.glow_bloom = 0.38; env.ambient_light_energy = 0.85
		sky.sky_top_color = Color(0.14, 0.04, 0.02); sky.sky_horizon_color = Color(0.75, 0.24, 0.06)
		sky.ground_horizon_color = Color(0.32, 0.10, 0.03)
		sun.light_color = Color(1.0, 0.48, 0.18); sun.light_energy = 1.25; sun.rotation_degrees.x = -34.0
		spawn_timer = 0.5
		for i in 3: _spawn_demon(focus_pos, false)
		for i in 2: _spawn_demon(focus_pos, true)
	else:
		env.volumetric_fog_density = saved_fog; env.volumetric_fog_albedo = Color(0.45, 0.28, 0.42)
		env.glow_intensity = 0.72; env.glow_bloom = 0.20
		for d in demons:
			if is_instance_valid(d["body"]): d["body"].queue_free()
		demons.clear()
		for pr in projectiles:
			if is_instance_valid(pr["node"]): pr["node"].queue_free()
		projectiles.clear()

func _add_part(parent: Node3D, mesh: Mesh, pos: Vector3, rot_deg := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi = MeshInstance3D.new(); mi.mesh = mesh; mi.position = pos; mi.rotation_degrees = rot_deg; mi.scale = scl
	parent.add_child(mi); return mi

func _spawn_demon(around: Vector3, flying: bool) -> void:
	var body = CharacterBody3D.new()
	body.collision_layer = 8; body.collision_mask = 0 if flying else 3
	var ang = randf() * TAU
	var dist = randf_range(18.0, 34.0)
	var alt = randf_range(5.5, 11.5) if flying else 1.05
	body.position = Vector3(around.x + cos(ang) * dist, alt, around.z + sin(ang) * dist)

	var skin = StandardMaterial3D.new()
	skin.albedo_color = Color(0.16, 0.04, 0.05) if flying else Color(0.11, 0.04, 0.04)
	skin.roughness = 0.42; skin.metallic = 0.18
	skin.emission_enabled = true; skin.emission = Color(0.85, 0.16, 0.02); skin.emission_energy_multiplier = 0.55

	var lava = StandardMaterial3D.new()
	lava.albedo_color = Color(1.0, 0.60, 0.10); lava.emission_enabled = true
	lava.emission = Color(1.0, 0.42, 0.04); lava.emission_energy_multiplier = 6.2

	var wing_mat = StandardMaterial3D.new()
	wing_mat.albedo_color = Color(0.24, 0.04, 0.03); wing_mat.roughness = 0.55; wing_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	wing_mat.emission_enabled = true; wing_mat.emission = Color(0.95, 0.25, 0.02); wing_mat.emission_energy_multiplier = 0.9

	var rig = Node3D.new(); body.add_child(rig)
	var s = 0.88 if flying else 1.12

	# Sculpted Pelvis, Tapered Waist & Muscular Broad Chest
	var pelv = SphereMesh.new(); pelv.radius = 0.22 * s; pelv.height = 0.30 * s; pelv.material = skin
	_add_part(rig, pelv, Vector3(0, 0.0, 0), Vector3.ZERO, Vector3(1.1, 0.9, 0.85))
	var waist = CylinderMesh.new(); waist.top_radius = 0.28 * s; waist.bottom_radius = 0.19 * s; waist.height = 0.42 * s; waist.material = skin
	_add_part(rig, waist, Vector3(0, 0.26 * s, 0.04 * s), Vector3(14, 0, 0), Vector3(1.05, 1.0, 0.78))
	var chest = SphereMesh.new(); chest.radius = 0.36 * s; chest.height = 0.56 * s; chest.material = skin
	_add_part(rig, chest, Vector3(0, 0.62 * s, 0.10 * s), Vector3(18, 0, 0), Vector3(1.22, 0.96, 0.76))

	# Molten Ribcage & Spine Spikes
	for rz in [-0.14, 0.0, 0.14]:
		var rib = BoxMesh.new(); rib.size = Vector3(0.42 * s, 0.045 * s, 0.06 * s); rib.material = lava
		_add_part(rig, rib, Vector3(0, (0.50 + rz * 0.8) * s, 0.30 * s), Vector3(10, 0, 0))
	for sp_i in 4:
		var spk = CylinderMesh.new(); spk.top_radius = 0.01; spk.bottom_radius = 0.055 * s; spk.height = 0.24 * s; spk.material = lava
		_add_part(rig, spk, Vector3(0, (0.28 + sp_i * 0.18) * s, -0.18 * s), Vector3(-65, 0, 0))

	# Sculpted Horned Demon Skull + Protruding Jaw
	var head = Node3D.new(); head.position = Vector3(0, 0.96 * s, 0.20 * s); rig.add_child(head)
	var skull = SphereMesh.new(); skull.radius = 0.19 * s; skull.height = 0.36 * s; skull.material = skin
	_add_part(head, skull, Vector3(0, 0.06 * s, 0), Vector3.ZERO, Vector3(0.92, 1.05, 1.08))
	var jaw = BoxMesh.new(); jaw.size = Vector3(0.20 * s, 0.13 * s, 0.24 * s); jaw.material = skin
	_add_part(head, jaw, Vector3(0, -0.08 * s, 0.08 * s), Vector3(12, 0, 0))

	for sx in [-1.0, 1.0]:
		# Multi-segment curved ram/demon horns
		var h1 = CylinderMesh.new(); h1.top_radius = 0.045 * s; h1.bottom_radius = 0.075 * s; h1.height = 0.34 * s; h1.material = lava
		_add_part(head, h1, Vector3(sx * 0.18 * s, 0.24 * s, -0.02 * s), Vector3(-22, 0, -sx * 36))
		var h2 = CylinderMesh.new(); h2.top_radius = 0.012 * s; h2.bottom_radius = 0.045 * s; h2.height = 0.36 * s; h2.material = lava
		_add_part(head, h2, Vector3(sx * 0.30 * s, 0.44 * s, -0.10 * s), Vector3(18, 0, -sx * 12))
		var eye = SphereMesh.new(); eye.radius = 0.042 * s; eye.height = 0.07 * s; eye.material = lava
		_add_part(head, eye, Vector3(sx * 0.085 * s, 0.08 * s, 0.17 * s))

	# Muscular Articulated Arms + Glowing Claws
	var arm_l := Node3D.new(); arm_l.position = Vector3(-0.44 * s, 0.72 * s, 0.10 * s); rig.add_child(arm_l)
	var arm_r := Node3D.new(); arm_r.position = Vector3( 0.44 * s, 0.72 * s, 0.10 * s); rig.add_child(arm_r)
	var sh_m = SphereMesh.new(); sh_m.radius = 0.14 * s; sh_m.height = 0.28 * s; sh_m.material = skin
	var ua_m = CapsuleMesh.new(); ua_m.radius = 0.10 * s; ua_m.height = 0.46 * s; ua_m.material = skin
	var fa_m = CapsuleMesh.new(); fa_m.radius = 0.085 * s; fa_m.height = 0.44 * s; fa_m.material = skin
	var cl_m = CylinderMesh.new(); cl_m.top_radius = 0.008; cl_m.bottom_radius = 0.032 * s; cl_m.height = 0.22 * s; cl_m.material = lava
	for a_node in [arm_l, arm_r]:
		_add_part(a_node, sh_m, Vector3.ZERO)
		_add_part(a_node, ua_m, Vector3(0, -0.22 * s, 0.06 * s), Vector3(-22, 0, 0))
		_add_part(a_node, fa_m, Vector3(0, -0.52 * s, 0.24 * s), Vector3(-55, 0, 0))
		for ci in [-0.04, 0.0, 0.04]:
			_add_part(a_node, cl_m, Vector3(ci * s, -0.68 * s, 0.44 * s), Vector3(68, 0, 0))

	# Digitigrade Muscular Legs
	var leg_l := Node3D.new(); leg_l.position = Vector3(-0.18 * s, -0.04 * s, 0); rig.add_child(leg_l)
	var leg_r := Node3D.new(); leg_r.position = Vector3( 0.18 * s, -0.04 * s, 0); rig.add_child(leg_r)
	var th_m = CapsuleMesh.new(); th_m.radius = 0.12 * s; th_m.height = 0.52 * s; th_m.material = skin
	var shn_m = CapsuleMesh.new(); shn_m.radius = 0.085 * s; shn_m.height = 0.52 * s; shn_m.material = skin
	for l_node in [leg_l, leg_r]:
		_add_part(l_node, th_m, Vector3(0, -0.22 * s, 0.06 * s), Vector3(-20, 0, 0))
		_add_part(l_node, shn_m, Vector3(0, -0.64 * s, -0.04 * s), Vector3(18, 0, 0))

	# Articulated Leathery Demon Bat-Wings for Flying Demons
	var wing_l: Node3D = null; var wing_r: Node3D = null
	if flying:
		wing_l = Node3D.new(); wing_l.position = Vector3(-0.24 * s, 0.68 * s, -0.14 * s); rig.add_child(wing_l)
		wing_r = Node3D.new(); wing_r.position = Vector3( 0.24 * s, 0.68 * s, -0.14 * s); rig.add_child(wing_r)
		for pair in [[wing_l, -1.0], [wing_r, 1.0]]:
			var wn: Node3D = pair[0]; var side: float = pair[1]
			var spar = CylinderMesh.new(); spar.top_radius = 0.03; spar.bottom_radius = 0.055; spar.height = 1.65; spar.material = skin
			_add_part(wn, spar, Vector3(side * 0.78, 0.34, -0.08), Vector3(0, 0, side * 66))
			var mem1 = PrismMesh.new(); mem1.size = Vector3(1.55, 1.15, 0.04); mem1.material = wing_mat
			_add_part(wn, mem1, Vector3(side * 0.85, 0.05, -0.12), Vector3(8, 0, side * -18))
			var tip = PrismMesh.new(); tip.size = Vector3(0.95, 1.25, 0.035); tip.material = wing_mat
			_add_part(wn, tip, Vector3(side * 1.82, 0.12, -0.16), Vector3(10, 0, side * -52))
		# Barbed Demon Tail
		var tl = CylinderMesh.new(); tl.top_radius = 0.015; tl.bottom_radius = 0.06; tl.height = 1.15; tl.material = skin
		_add_part(rig, tl, Vector3(0, -0.22 * s, -0.45 * s), Vector3(-55, 0, 0))

	var col = CollisionShape3D.new()
	var cs = CapsuleShape3D.new()
	cs.radius = 0.85 if flying else 0.62
	cs.height = 2.0 if flying else 2.25
	col.shape = cs; col.position = Vector3(0, 0.32, 0); body.add_child(col)
	add_child(body)

	demons.append({
		"body": body, "skin": skin, "flying": flying,
		"hp": 65.0 if flying else 95.0,
		"atk_cd": randf_range(1.2, 2.5), "flash": 0.0,
		"phase": randf() * TAU, "orbit_dir": 1.0 if randf() > 0.5 else -1.0,
		"alt": alt, "arm_l": arm_l, "arm_r": arm_r, "leg_l": leg_l, "leg_r": leg_r,
		"wing_l": wing_l, "wing_r": wing_r
	})

func _spawn_fireball(origin: Vector3, target_pos: Vector3) -> void:
	var mi = MeshInstance3D.new()
	var sm = SphereMesh.new(); sm.radius = 0.24; sm.height = 0.48
	var mat = StandardMaterial3D.new(); mat.albedo_color = Color(1.0, 0.72, 0.20)
	mat.emission_enabled = true; mat.emission = Color(1.0, 0.35, 0.04); mat.emission_energy_multiplier = 7.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.material = mat; mi.mesh = sm; mi.position = origin
	add_child(mi)
	var dir = (target_pos + Vector3(0, 1.0, 0) - origin).normalized()
	projectiles.append({"node": mi, "vel": dir * 18.5, "t": 3.8})

func try_hit_demon(collider: Object, dmg: float, hit_pos: Vector3) -> bool:
	for i in range(demons.size() - 1, -1, -1):
		var d = demons[i]
		if d["body"] == collider:
			d["hp"] -= dmg; d["flash"] = 0.12
			d["skin"].emission_energy_multiplier = 6.5
			_spawn_ember_burst(hit_pos, 22)
			if d["hp"] <= 0.0:
				var is_f: bool = d["flying"]
				var drop_pos = d["body"].global_position
				_spawn_ember_burst(drop_pos + Vector3(0, 0.6, 0), 65)
				kills += 1
				# Drop Soul Orb / Overdrive Core onto ground height so flying kills are collectable
				_spawn_pickup(Vector3(drop_pos.x, 0.55, drop_pos.z))
				d["body"].queue_free(); demons.remove_at(i)
				var cash = 350 if is_f else 250
				var tag = "FLYING DEMON SHOT DOWN" if is_f else "DEMON BANISHED"
				demon_killed.emit(cash, "%s (%d KILLS)! +$%d" % [tag, kills, cash])
				_check_unlocks()
			return true
	return false

func _spawn_ember_burst(pos: Vector3, amt: int) -> void:
	var p = GPUParticles3D.new()
	p.one_shot = true; p.explosiveness = 0.92; p.amount = amt; p.lifetime = 0.75; p.position = pos
	var pm = ParticleProcessMaterial.new()
	pm.particle_flag_align_y = true; pm.spread = 180.0
	pm.initial_velocity_min = 5.0; pm.initial_velocity_max = 15.0; pm.gravity = Vector3(0, -6.0, 0)
	p.process_material = pm
	var m = BoxMesh.new(); m.size = Vector3(0.06, 0.36, 0.06)
	var mat = StandardMaterial3D.new(); mat.albedo_color = Color(1, 0.8, 0.3)
	mat.emission_enabled = true; mat.emission = Color(1, 0.45, 0.06); mat.emission_energy_multiplier = 8.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material = mat; p.draw_pass_1 = m; add_child(p); p.emitting = true
	bursts.append({"node": p, "t": 0.9})

func _spawn_pickup(pos: Vector3) -> void:
	var is_over = (kills % 3 == 0)
	var mi = MeshInstance3D.new(); var m = SphereMesh.new(); m.radius = 0.34 if is_over else 0.28; m.height = m.radius * 2.0
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

func update_hellfire(delta: float, focus_pos: Vector3) -> void:
	if overdrive_timer > 0.0: overdrive_timer = maxf(0.0, overdrive_timer - delta)

	for i in range(pickups.size() - 1, -1, -1):
		var pk = pickups[i]
		pk["node"].rotate_y(delta * 3.2); pk["t"] -= delta
		if pk["node"].global_position.distance_to(focus_pos) < 3.4:
			if pk["kind"] == "overdrive":
				overdrive_timer = 12.0
				pickup_collected.emit("overdrive", "HELLFIRE OVERDRIVE! 12s Infinite Ammo + Rapid Fire + Speed!")
			else:
				pickup_collected.emit("soul", "SOUL ORB ABSORBED! +35 HP & +$350!")
			pk["node"].queue_free(); pickups.remove_at(i)
		elif pk["t"] <= 0.0:
			pk["node"].queue_free(); pickups.remove_at(i)

	for i in range(bursts.size() - 1, -1, -1):
		bursts[i]["t"] -= delta
		if bursts[i]["t"] <= 0.0: bursts[i]["node"].queue_free(); bursts.remove_at(i)

	for i in range(projectiles.size() - 1, -1, -1):
		var pr = projectiles[i]
		pr["t"] -= delta
		pr["node"].global_position += pr["vel"] * delta
		if pr["node"].global_position.distance_to(focus_pos + Vector3(0, 0.9, 0)) < 1.35:
			_spawn_ember_burst(pr["node"].global_position, 24)
			player_hit.emit(12.0)
			pr["node"].queue_free(); projectiles.remove_at(i)
		elif pr["t"] <= 0.0 or pr["node"].global_position.y < 0.0:
			_spawn_ember_burst(pr["node"].global_position, 14)
			pr["node"].queue_free(); projectiles.remove_at(i)

	if not active: return

	fx_root.global_position = Vector3(focus_pos.x, focus_pos.y + 1.5, focus_pos.z)
	var t = Time.get_ticks_msec() * 0.015
	fire_light_a.position = Vector3(sin(t) * 2.5, 2.2, cos(t * 0.8) * 2.5 - 3.5); fire_light_a.light_energy = 4.5 + sin(t * 2.3) * 1.8
	fire_light_b.position = Vector3(cos(t * 1.1) * 3.5, 1.8, sin(t) * 3.5 + 3.0); fire_light_b.light_energy = 3.5 + cos(t * 2.9) * 1.5

	# Maintain mix of Ground & Flying Demons
	spawn_timer -= delta
	var max_d = 10 if is_desktop else 6
	if spawn_timer <= 0.0 and demons.size() < max_d:
		var fly_cnt = 0
		for d in demons:
			if d["flying"]: fly_cnt += 1
		_spawn_demon(focus_pos, fly_cnt < (4 if is_desktop else 2))
		spawn_timer = 2.6

	for d in demons:
		var b: CharacterBody3D = d["body"]
		if d["flash"] > 0.0:
			d["flash"] -= delta
			if d["flash"] <= 0.0: d["skin"].emission_energy_multiplier = 0.55

		if d["flying"]:
			d["phase"] += delta * 9.5
			var flap = sin(d["phase"]) * 0.65
			if d["wing_l"]: d["wing_l"].rotation.z = flap
			if d["wing_r"]: d["wing_r"].rotation.z = -flap

			var to_p = focus_pos - b.global_position; var horiz = Vector3(to_p.x, 0, to_p.z)
			var dist = horiz.length()
			if dist > 62.0:
				var a = randf() * TAU
				b.global_position = Vector3(focus_pos.x + cos(a) * 26.0, d["alt"], focus_pos.z + sin(a) * 26.0)
			else:
				var rad_dir = horiz.normalized() if dist > 0.1 else Vector3.FORWARD
				var tang = Vector3(-rad_dir.z, 0, rad_dir.x) * d["orbit_dir"]
				var pull = 1.0 if dist > 20.0 else (-0.6 if dist < 11.0 else 0.0)
				var target_y = focus_pos.y + d["alt"] + sin(d["phase"] * 0.28) * 1.8
				var vel = (tang * 7.8) + (rad_dir * pull * 5.0)
				vel.y = clampf((target_y - b.global_position.y) * 2.2, -5.0, 5.0)
				b.global_position += vel * delta
				b.look_at(Vector3(focus_pos.x, b.global_position.y, focus_pos.z), Vector3.UP)

				d["atk_cd"] -= delta
				if d["atk_cd"] <= 0.0 and dist < 34.0:
					d["atk_cd"] = randf_range(2.6, 4.2)
					_spawn_fireball(b.global_position + Vector3(0, 0.4, 0), focus_pos)
		else:
			d["phase"] += delta * 8.5
			var sw = sin(d["phase"]) * 0.55
			if d["leg_l"]: d["leg_l"].rotation.x = sw
			if d["leg_r"]: d["leg_r"].rotation.x = -sw
			if d["arm_l"]: d["arm_l"].rotation.x = -sw * 0.6 - 0.3
			if d["arm_r"]: d["arm_r"].rotation.x =  sw * 0.6 - 0.3

			var to_p = focus_pos - b.global_position; to_p.y = 0
			var dist = to_p.length()
			if dist > 48.0:
				var a = randf() * TAU
				b.global_position = Vector3(focus_pos.x + cos(a) * 24.0, 1.05, focus_pos.z + sin(a) * 24.0)
			elif dist > 2.3:
				var dir = to_p.normalized()
				b.velocity.x = dir.x * 5.5; b.velocity.z = dir.z * 5.5
				b.look_at(Vector3(focus_pos.x, b.global_position.y, focus_pos.z), Vector3.UP)
			else:
				b.velocity.x = 0; b.velocity.z = 0
				d["atk_cd"] -= delta
				if d["atk_cd"] <= 0.0:
					d["atk_cd"] = 1.1; player_hit.emit(10.0)
			b.velocity.y = 0.0 if b.is_on_floor() else b.velocity.y - 20.0 * delta
			b.move_and_slide()
