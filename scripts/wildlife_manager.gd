extends Node3D
class_name WildlifeManager

var bird_count := 45
var critter_count := 60 # Squirrels (urban) / Iguanas & Lizards (Florida)
var gator_count := 10   # Florida Coast & Everglades

var mm_bird_body: MultiMeshInstance3D
var mm_wing_l: MultiMeshInstance3D
var mm_wing_r: MultiMeshInstance3D
var mm_critter: MultiMeshInstance3D
var mm_critter_tail: MultiMeshInstance3D
var mm_gator: MultiMeshInstance3D

var birds: Array[Dictionary] = []
var critters: Array[Dictionary] = []
var gators: Array[Dictionary] = []
var active_biome := "florida_coast"

func setup(biome_name: String, is_desktop: bool) -> void:
	active_biome = biome_name
	bird_count = 48 if is_desktop else 24
	critter_count = 64 if is_desktop else 32
	gator_count = 12 if (biome_name in ["florida_coast", "everglades"]) else 0

	mm_bird_body = _make_mm(CapsuleMesh.new(), Vector3(0.16, 0.48, 0.16), bird_count, 0.55)
	mm_wing_l    = _make_mm(BoxMesh.new(),     Vector3(0.65, 0.04, 0.24), bird_count, 0.55)
	mm_wing_r    = _make_mm(BoxMesh.new(),     Vector3(0.65, 0.04, 0.24), bird_count, 0.55)

	mm_critter      = _make_mm(CapsuleMesh.new(), Vector3(0.14, 0.38, 0.14), critter_count, 0.65)
	mm_critter_tail = _make_mm(BoxMesh.new(),     Vector3(0.08, 0.08, 0.42), critter_count, 0.65)
	if gator_count > 0:
		mm_gator = _make_mm(BoxMesh.new(), Vector3(0.62, 0.30, 2.65), gator_count, 0.72)

	var fl_birds = [Color(0.95, 0.96, 0.98), Color(0.88, 0.90, 0.94), Color(0.98, 0.52, 0.62), Color(0.22, 0.85, 0.35)]
	var ur_birds = [Color(0.32, 0.34, 0.38), Color(0.14, 0.15, 0.18), Color(0.55, 0.52, 0.48)]
	var b_pal = fl_birds if biome_name in ["florida_coast", "everglades"] else ur_birds

	birds.clear()
	for i in bird_count:
		var ang = randf() * TAU
		birds.append({
			"pos": Vector3(cos(ang) * randf_range(10, 90), randf_range(12, 34), sin(ang) * randf_range(10, 90)),
			"vel": Vector3(cos(ang + 1.5), 0.0, sin(ang + 1.5)) * randf_range(7.0, 12.0),
			"phase": randf() * TAU, "alt": randf_range(11.0, 36.0)
		})
		var c = b_pal[i % b_pal.size()]
		mm_bird_body.multimesh.set_instance_color(i, c)
		mm_wing_l.multimesh.set_instance_color(i, c.darkened(0.08))
		mm_wing_r.multimesh.set_instance_color(i, c.darkened(0.08))

	# Florida: bright green iguanas & tan anole lizards | Urban: brown/grey squirrels
	var fl_crit = [Color(0.22, 0.76, 0.24), Color(0.36, 0.82, 0.28), Color(0.85, 0.52, 0.18), Color(0.58, 0.48, 0.32)]
	var ur_crit = [Color(0.46, 0.32, 0.22), Color(0.54, 0.42, 0.30), Color(0.42, 0.42, 0.44)]
	var c_pal = fl_crit if biome_name in ["florida_coast", "everglades"] else ur_crit

	critters.clear()
	for i in critter_count:
		critters.append({
			"pos": Vector3(0, -50, 0), "dir": Vector3(1, 0, 0),
			"spd": randf_range(2.2, 4.5), "timer": randf_range(0.5, 2.5), "flee": 0.0
		})
		var cc = c_pal[i % c_pal.size()]
		mm_critter.multimesh.set_instance_color(i, cc)
		mm_critter_tail.multimesh.set_instance_color(i, cc.darkened(0.15))

	gators.clear()
	for i in gator_count:
		gators.append({"pos": Vector3(0, -50, 0), "yaw": randf() * TAU, "timer": randf_range(2.0, 6.0)})
		mm_gator.multimesh.set_instance_color(i, Color(0.18, 0.28, 0.16))

func _make_mm(mesh: PrimitiveMesh, sz: Vector3, cnt: int, rough: float) -> MultiMeshInstance3D:
	if mesh is BoxMesh: (mesh as BoxMesh).size = sz
	elif mesh is CapsuleMesh:
		(mesh as CapsuleMesh).radius = sz.x * 0.5; (mesh as CapsuleMesh).height = sz.y
	var mat = StandardMaterial3D.new(); mat.vertex_color_use_as_albedo = true; mat.roughness = rough
	mesh.material = mat
	var mm = MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = true
	mm.mesh = mesh; mm.instance_count = cnt
	var mmi = MultiMeshInstance3D.new(); mmi.multimesh = mm; mmi.extra_cull_margin = 220.0
	add_child(mmi); return mmi

func scatter_near(origin: Vector3, radius: float) -> void:
	for c in critters:
		if c["pos"].distance_to(origin) < radius: c["flee"] = 4.5
	for b in birds:
		if b["pos"].distance_to(origin) < radius * 1.5: b["vel"].y += 4.5

func update_wildlife(delta: float, focus_pos: Vector3) -> void:
	# 1. Overhead Flocking Birds with Animated Flapping Wings
	var bm = mm_bird_body.multimesh; var wl = mm_wing_l.multimesh; var wr = mm_wing_r.multimesh
	for i in bird_count:
		var b = birds[i]
		var to_c = focus_pos - b["pos"]; to_c.y = 0
		if to_c.length() > 125.0:
			b["vel"] += to_c.normalized() * 14.0 * delta
		else:
			var tang = Vector3(-to_c.z, 0, to_c.x).normalized()
			b["vel"] += tang * 3.5 * delta
		b["vel"].y = lerpf(b["vel"].y, (b["alt"] - b["pos"].y) * 0.6, delta * 2.0)
		var spd = clampf(b["vel"].length(), 7.5, 15.0)
		b["vel"] = b["vel"].normalized() * spd
		b["pos"] += b["vel"] * delta
		b["phase"] += delta * 13.0

		var yaw = atan2(b["vel"].x, b["vel"].z)
		var flap = sin(b["phase"]) * 0.72
		var body_b = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI * 0.5)
		bm.set_instance_transform(i, Transform3D(body_b, b["pos"]))
		var lb = Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, flap)
		var rb = Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, -flap)
		wl.set_instance_transform(i, Transform3D(lb, b["pos"] + Basis(Vector3.UP, yaw) * Vector3(-0.34, 0, 0)))
		wr.set_instance_transform(i, Transform3D(rb, b["pos"] + Basis(Vector3.UP, yaw) * Vector3( 0.34, 0, 0)))

	# 2. Ground Critters (Iguanas/Lizards/Squirrels darting in bursts)
	var cm = mm_critter.multimesh; var tm = mm_critter_tail.multimesh
	for i in critter_count:
		var c = critters[i]
		var pos: Vector3 = c["pos"]
		if pos.y < -10.0 or pos.distance_to(focus_pos) > 95.0:
			var a = randf() * TAU; var r = randf_range(10.0, 75.0)
			pos = Vector3(focus_pos.x + cos(a) * r, 0.12, focus_pos.z + sin(a) * r)
			c["dir"] = Vector3(cos(randf() * TAU), 0, sin(randf() * TAU))
		if pos.distance_to(focus_pos) < 7.0: c["flee"] = 3.0
		c["timer"] -= delta
		var spd = c["spd"]
		if c["flee"] > 0.0:
			c["flee"] -= delta
			var away = pos - focus_pos; away.y = 0
			if away.length() > 0.1: c["dir"] = away.normalized()
			spd = 7.2
		elif c["timer"] <= 0.0:
			c["timer"] = randf_range(0.8, 3.0)
			c["dir"] = Vector3.ZERO if randf() < 0.42 else Vector3(cos(randf() * TAU), 0, sin(randf() * TAU))
		pos += c["dir"] * spd * delta; pos.y = 0.12; c["pos"] = pos
		var yaw = atan2(c["dir"].x, c["dir"].z) if c["dir"].length() > 0.05 else 0.0
		var cb = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI * 0.5)
		cm.set_instance_transform(i, Transform3D(cb, pos))
		tm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yaw), pos - Basis(Vector3.UP, yaw) * Vector3(0, 0, 0.34)))

	# 3. Florida Alligators
	if gator_count > 0:
		var gm = mm_gator.multimesh
		for i in gator_count:
			var g = gators[i]
			var pos: Vector3 = g["pos"]
			if pos.y < -10.0 or pos.distance_to(focus_pos) > 130.0:
				var a = randf() * TAU; var r = randf_range(24.0, 105.0)
				pos = Vector3(focus_pos.x + cos(a) * r, 0.16, focus_pos.z + sin(a) * r)
			g["timer"] -= delta
			if g["timer"] <= 0.0: g["timer"] = randf_range(3.0, 7.0); g["yaw"] += randf_range(-0.6, 0.6)
			pos += Vector3(sin(g["yaw"]), 0, cos(g["yaw"])) * 0.9 * delta; pos.y = 0.16; g["pos"] = pos
			gm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, g["yaw"]), pos))
