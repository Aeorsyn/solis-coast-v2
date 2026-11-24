extends VehicleBody3D
class_name SolisVehicle

var vehicle_name := "Solis GT"
var max_hp := 120.0
var hp := 120.0
var is_ai := false
var ai_axis := "z"
var ai_sign := -1.0
var ai_speed := 13.0
var cur_ai_speed := 13.0
var top_speed := 38.0
var is_player_controlled := false

var paint_mat: StandardMaterial3D
var orig_color := Color(0.92, 0.14, 0.36)
var brake_mat: StandardMaterial3D
var smoke_mesh: MeshInstance3D
var smoke_mat: StandardMaterial3D
var rear_wheels: Array[VehicleWheel3D] = []
var headlights: Array[SpotLight3D] = []

func setup(v_name: String, paint_col: Color, v_max_hp: float, ai_mode: bool, axis := "z", s_dir := -1.0, spd := 13.0) -> void:
	vehicle_name = v_name
	orig_color = paint_col
	max_hp = v_max_hp
	hp = v_max_hp
	is_ai = ai_mode
	ai_axis = axis
	ai_sign = s_dir
	ai_speed = spd
	cur_ai_speed = spd

	mass = 1350.0
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.35, 0)
	contact_monitor = true
	max_contacts_reported = 4

	paint_mat = StandardMaterial3D.new()
	paint_mat.albedo_color = paint_col
	paint_mat.metallic = 0.72
	paint_mat.roughness = 0.18
	paint_mat.clearcoat_enabled = true
	paint_mat.clearcoat = 0.8

	# Sculpted Lower Body (+Z is Forward in VehicleBody3D)
	var chassis = MeshInstance3D.new()
	var cm = BoxMesh.new(); cm.size = Vector3(2.12, 0.66, 4.65); cm.material = paint_mat
	chassis.mesh = cm; chassis.position = Vector3(0, 0.25, 0); add_child(chassis)

	# Cabin / Tinted Glass
	var cabin = MeshInstance3D.new()
	var cab_m = BoxMesh.new(); cab_m.size = Vector3(1.76, 0.56, 2.05)
	var glass = StandardMaterial3D.new()
	glass.albedo_color = Color(0.05, 0.07, 0.12); glass.metallic = 0.9; glass.roughness = 0.06
	cab_m.material = glass; cabin.mesh = cab_m; cabin.position = Vector3(0, 0.80, -0.15); add_child(cabin)

	# Rear Wing
	var wing = MeshInstance3D.new()
	var wm = BoxMesh.new(); wm.size = Vector3(2.05, 0.08, 0.34); wm.material = paint_mat
	wing.mesh = wm; wing.position = Vector3(0, 0.82, -2.08); add_child(wing)

	# Headlights (+Z front)
	var hl_mat = StandardMaterial3D.new()
	hl_mat.albedo_color = Color(0.95, 0.98, 1.0); hl_mat.emission_enabled = true
	hl_mat.emission = Color(0.88, 0.96, 1.0); hl_mat.emission_energy_multiplier = 3.5
	for hx in [-0.72, 0.72]:
		var hl = MeshInstance3D.new()
		var hm = BoxMesh.new(); hm.size = Vector3(0.44, 0.16, 0.12); hm.material = hl_mat
		hl.mesh = hm; hl.position = Vector3(hx, 0.32, 2.30); add_child(hl)
		if not ai_mode:
			var spot = SpotLight3D.new()
			spot.position = Vector3(hx, 0.35, 2.38)
			spot.rotation_degrees = Vector3(-6, 180, 0)
			spot.light_color = Color(0.95, 0.96, 1.0)
			spot.light_energy = 4.5
			spot.spot_range = 32.0
			spot.spot_angle = 34.0
			add_child(spot)
			headlights.append(spot)

	# Brake Light Bar (-Z rear)
	brake_mat = StandardMaterial3D.new()
	brake_mat.albedo_color = Color(0.95, 0.08, 0.12); brake_mat.emission_enabled = true
	brake_mat.emission = Color(1.0, 0.08, 0.10); brake_mat.emission_energy_multiplier = 1.6
	var tl = MeshInstance3D.new()
	var tlm = BoxMesh.new(); tlm.size = Vector3(1.86, 0.15, 0.10); tlm.material = brake_mat
	tl.mesh = tlm; tl.position = Vector3(0, 0.38, -2.30); add_child(tl)

	# Engine Damage Smoke/Fire Plume
	smoke_mesh = MeshInstance3D.new()
	var sm = SphereMesh.new(); sm.radius = 0.52
	smoke_mat = StandardMaterial3D.new()
	smoke_mat.albedo_color = Color(0.35, 0.35, 0.38, 0.85)
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.material = smoke_mat; smoke_mesh.mesh = sm
	smoke_mesh.position = Vector3(0, 1.05, 1.45); smoke_mesh.visible = false
	add_child(smoke_mesh)

	# Collision Hull
	var col = CollisionShape3D.new()
	var bs = BoxShape3D.new(); bs.size = Vector3(2.12, 1.05, 4.65)
	col.shape = bs; col.position = Vector3(0, 0.48, 0); add_child(col)

	# 4 Jolt VehicleWheel3D Suspension Nodes
	var tire_mat = StandardMaterial3D.new(); tire_mat.albedo_color = Color(0.07, 0.07, 0.09); tire_mat.roughness = 0.85
	var rim_mat = StandardMaterial3D.new(); rim_mat.albedo_color = Color(0.84, 0.86, 0.90); rim_mat.metallic = 0.9; rim_mat.roughness = 0.2
	var w_specs = [
		{"p": Vector3( 1.05, 0.10,  1.42), "front": true},
		{"p": Vector3(-1.05, 0.10,  1.42), "front": true},
		{"p": Vector3( 1.05, 0.10, -1.42), "front": false},
		{"p": Vector3(-1.05, 0.10, -1.42), "front": false}
	]
	for ws in w_specs:
		var wh = VehicleWheel3D.new()
		wh.position = ws["p"]
		wh.wheel_radius = 0.38
		wh.wheel_rest_length = 0.20
		wh.suspension_travel = 0.26
		wh.suspension_stiffness = 42.0
		wh.damping_compression = 2.6
		wh.damping_relaxation = 3.0
		wh.wheel_friction_slip = 2.8
		wh.use_as_steering = ws["front"]
		wh.use_as_traction = true
		add_child(wh)
		if not ws["front"]:
			rear_wheels.append(wh)

		var tire = MeshInstance3D.new()
		var tm = CylinderMesh.new(); tm.top_radius = 0.38; tm.bottom_radius = 0.38; tm.height = 0.28; tm.material = tire_mat
		tire.mesh = tm; tire.rotation_degrees.z = 90; wh.add_child(tire)
		var rim = MeshInstance3D.new()
		var rm = CylinderMesh.new(); rm.top_radius = 0.22; rm.bottom_radius = 0.22; rm.height = 0.30; rm.material = rim_mat
		rim.mesh = rm; rim.rotation_degrees.z = 90; wh.add_child(rim)

	if is_ai:
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		freeze = true

func wake_for_player() -> void:
	is_ai = false
	freeze = false
	is_player_controlled = true
	if headlights.is_empty():
		for hx in [-0.72, 0.72]:
			var spot = SpotLight3D.new()
			spot.position = Vector3(hx, 0.35, 2.38)
			spot.rotation_degrees = Vector3(-6, 180, 0)
			spot.light_energy = 4.5; spot.spot_range = 32.0; spot.spot_angle = 34.0
			add_child(spot); headlights.append(spot)

func apply_drive_input(throttle: float, steer_input: float, handbrake: bool, delta: float) -> void:
	if hp <= 0.0:
		engine_force = 0.0; brake = 35.0; return
	var spd = linear_velocity.length()
	var fwd_dot = linear_velocity.dot(global_transform.basis.z)
	steering = move_toward(steering, steer_input * 0.46, delta * 3.8)

	if handbrake:
		engine_force = 0.0
		brake = 18.0
		for rw in rear_wheels: rw.wheel_friction_slip = 0.85 # Drifting!
	else:
		for rw in rear_wheels: rw.wheel_friction_slip = 2.8
		if throttle > 0.05:
			engine_force = throttle * 4600.0 if spd < top_speed else 0.0
			brake = 0.0
		elif throttle < -0.05:
			if fwd_dot > 1.5:
				engine_force = 0.0; brake = 28.0
			else:
				engine_force = throttle * 2800.0 if spd < 14.0 else 0.0
				brake = 0.0
		else:
			engine_force = 0.0; brake = 4.0

	brake_mat.emission_energy_multiplier = 4.5 if (handbrake or throttle < -0.1) else 1.5

func take_damage(amount: float) -> bool:
	if hp <= 0.0: return false
	hp = maxf(0.0, hp - amount)
	if hp <= 0.0:
		is_ai = false; freeze = false; engine_force = 0.0; brake = 40.0
		paint_mat.albedo_color = Color(0.11, 0.11, 0.13)
		smoke_mesh.visible = true
		smoke_mat.albedo_color = Color(1.0, 0.32, 0.05, 0.92)
		smoke_mat.emission_enabled = true; smoke_mat.emission = Color(1.0, 0.35, 0.05); smoke_mat.emission_energy_multiplier = 4.0
		return true
	elif hp < max_hp * 0.30:
		smoke_mesh.visible = true
		smoke_mat.albedo_color = Color(1.0, 0.42, 0.08, 0.88)
		smoke_mat.emission_enabled = true; smoke_mat.emission = Color(1.0, 0.35, 0.05); smoke_mat.emission_energy_multiplier = 2.8
	elif hp < max_hp * 0.60:
		smoke_mesh.visible = true
		smoke_mat.albedo_color = Color(0.45, 0.45, 0.48, 0.72)
		smoke_mat.emission_enabled = false
	return false

func repair_full() -> void:
	hp = max_hp
	smoke_mesh.visible = false
	paint_mat.albedo_color = orig_color
