extends Node3D
class_name WildlifeManager

var bird_count := 45
var critter_count := 60
var gator_count := 10

var mm_bird_body: MultiMeshInstance3D
var mm_wing_l: MultiMeshInstance3D
var mm_wing_r: MultiMeshInstance3D
var mm_critter: MultiMeshInstance3D
var mm_critter_tail: MultiMeshInstance3D
var mm_gator: MultiMeshInstance3D
var mm_gator_tail: MultiMeshInstance3D

var birds: Array[Dictionary] = []
var critters: Array[Dictionary] = []
var gators: Array[Dictionary] = []
var active_biome := "florida_coast"

func _add_prim(st: SurfaceTool, mesh: Mesh, xf: Transform3D) -> void:
	for s in mesh.get_surface_count():
		st.append_from(mesh, s, xf)

func _build_bird_body_mesh() -> ArrayMesh:
	var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var torso = SphereMesh.new(); torso.radius = 0.14; torso.height = 0.44; torso.radial_segments = 10; torso.rings = 6
	_add_prim(st, torso, Transform3D(Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3(0.85, 1.0, 0.78)), Vector3.ZERO))
	var head = SphereMesh.new(); head.radius = 0.085; head.height = 0.17; head.radial_segments = 8; head.rings = 5
	_add_prim(st, head, Transform3D(Basis.IDENTITY, Vector3(0, 0.06, 0.24)))
	var beak = CylinderMesh.new(); beak.top_radius = 0.005; beak.bottom_radius = 0.032; beak.height = 0.14; beak.radial_segments = 6
	_add_prim(st, beak, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.05, 0.36)))
	var tail = PrismMesh.new(); tail.size = Vector3(0.24, 0.26, 0.03)
	_add_prim(st, tail, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.02, -0.32)))
	st.generate_normals()
	return st.commit()

func _build_wing_mesh(side: float) -> ArrayMesh:
	var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inner = BoxMesh.new(); inner.size = Vector3(0.42, 0.035, 0.22)
	_add_prim(st, inner, Transform3D(Basis.IDENTITY, Vector3(side * 0.21, 0.0, -0.02)))
	var outer = PrismMesh.new(); outer.size = Vector3(0.20, 0.44, 0.028)
	var rot = Basis(Vector3.FORWARD, side * PI * 0.5) * Basis(Vector3.UP, side * 0.18)
	_add_prim(st, outer, Transform3D(rot, Vector3(side * 0.58, -0.01, -0.06)))
	st.generate_normals()
	return st.commit()

func _build_iguana_body_mesh() -> ArrayMesh:
	var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body = CapsuleMesh.new(); body.radius = 0.085; body.height = 0.46; body.radial_segments = 8
	_add_prim(st, body, Transform3D(Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3(1.1, 1.0, 0.72)), Vector3(0, 0.09, 0)))
	var head = SphereMesh.new(); head.radius = 0.075; head.height = 0.18; head.radial_segments = 8
	_add_prim(st, head, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.13, 0.26)))
	# Dorsal crest ridge along spine
	var crest = BoxMesh.new(); crest.size = Vector3(0.025, 0.055, 0.42)
	_add_prim(st, crest, Transform3D(Basis.IDENTITY, Vector3(0, 0.17, -0.02)))
	# 4 splayed reptile legs
	var leg = CapsuleMesh.new(); leg.radius = 0.028; leg.height = 0.18; leg.radial_segments = 6
	for lx in [-1.0, 1.0]:
		for lz in [-0.14, 0.14]:
			_add_prim(st, leg, Transform3D(Basis(Vector3.FORWARD, lx * 0.65), Vector3(lx * 0.12, 0.05, lz)))
	st.generate_normals()
	return st.commit()

func _build_squirrel_body_mesh() -> ArrayMesh:
	var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body = SphereMesh.new(); body.radius = 0.10; body.height = 0.28; body.radial_segments = 8
	_add_prim(st, body, Transform3D(Basis(Vector3.RIGHT, PI * 0.42), Vector3(0, 0.10, 0)))
	var head = SphereMesh.new(); head.radius = 0.072; head.height = 0.14; head.radial_segments = 8
	_add_prim(st, head, Transform3D(Basis.IDENTITY, Vector3(0, 0.18, 0.14)))
	var ear = CylinderMesh.new(); ear.top_radius = 0.005; ear.bottom_radius = 0.025; ear.height = 0.055; ear.radial_segments = 5
	for ex in [-0.045, 0.045]:
		_add_prim(st, ear, Transform3D(Basis.IDENTITY, Vector3(ex, 0.25, 0.12)))
	st.generate_normals()
	return st.commit()

func _build_critter_tail_mesh(is_florida: bool) -> ArrayMesh:
	var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if is_florida:
		var t = CylinderMesh.new(); t.top_radius = 0.008; t.bottom_radius = 0.048; t.height = 0.62; t.radial_segments = 6
		_add_prim(st, t, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.07, -0.31)))
	else:
		# Bushy curved squirrel tail
		var t1 = CapsuleMesh.new(); t1.radius = 0.065; t1.height = 0.26; t1.radial_segments = 7
		_add_prim(st, t1, Transform3D(Basis(Vector3.RIGHT, -0.65), Vector3(0, 0.14, -0.14)))
		_add_prim(st, t1, Transform3D(Basis(Vector3.RIGHT, 0.35), Vector3(0, 0.28, -0.22)))
	st.generate_normals()
	return st.commit()

func _build_gator_body_mesh() -> ArrayMesh:
	var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Armored wide torso
	var torso = CapsuleMesh.new(); torso.radius = 0.34; torso.height = 1.65; torso.radial_segments = 10
	_add_prim(st, torso, Transform3D(Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3(1.15, 1.0, 0.58)), Vector3(0, 0.24, 0)))
	# Dorsal armored ridge plates
	var scute = BoxMesh.new(); scute.size = Vector3(0.32, 0.10, 1.35)
	_add_prim(st, scute, Transform3D(Basis.IDENTITY, Vector3(0, 0.42, -0.05)))
	# Tapered snout + brow ridges
	var snout = CylinderMesh.new(); snout.top_radius = 0.14; snout.bottom_radius = 0.28; snout.height = 0.92; snout.radial_segments = 8
	_add_prim(st, snout, Transform3D(Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3(1.1, 1.0, 0.52)), Vector3(0, 0.24, 1.12)))
	var eye = SphereMesh.new(); eye.radius = 0.065; eye.height = 0.11; eye.radial_segments = 6
	for ex in [-0.14, 0.14]:
		_add_prim(st, eye, Transform3D(Basis.IDENTITY, Vector3(ex, 0.37, 0.82)))
	# 4 heavy crouched legs
	var leg = CapsuleMesh.new(); leg.radius = 0.095; leg.height = 0.45; leg.radial_segments = 6
	for lx in [-1.0, 1.0]:
		for lz in [-0.48, 0.48]:
			_add_prim(st, leg, Transform3D(Basis(Vector3.FORWARD, lx * 0.72), Vector3(lx * 0.42, 0.14, lz)))
	st.generate_normals()
	return st.commit()

func _build_gator_tail_mesh() -> ArrayMesh:
	var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tail = CylinderMesh.new(); tail.top_radius = 0.03; tail.bottom_radius = 0.24; tail.height = 1.65; tail.radial_segments = 8
	_add_prim(st, tail, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5).scaled(Vector3(1.0, 1.0, 0.65)), Vector3(0, 0.20, -0.82)))
	st.generate_normals()
	return st.commit()

func _make_mm(mesh: Mesh, cnt: int, rough: float) -> MultiMeshInstance3D:
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true; mat.roughness = rough
	mesh.surface_set_material(0, mat)
	var mm = MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = true
	mm.mesh = mesh; mm.instance_count = cnt
	var mmi = MultiMeshInstance3D.new(); mmi.multimesh = mm; mmi.extra_cull_margin = 220.0
	add_child(mmi); return mmi

func setup(biome_name: String, is_desktop: bool) -> void:
	active_biome = biome_name
	var is_fl = biome_name in ["florida_coast", "everglades"]
	bird_count = 48 if is_desktop else 24
	critter_count = 64 if is_desktop else 32
	gator_count = 12 if is_fl else 0

	mm_bird_body = _make_mm(_build_bird_body_mesh(), bird_count, 0.52)
	mm_wing_l    = _make_mm(_build_wing_mesh(-1.0), bird_count, 0.52)
	mm_wing_r    = _make_mm(_build_wing_mesh( 1.0), bird_count, 0.52)

	mm_critter      = _make_mm(_build_iguana_body_mesh() if is_fl else _build_squirrel_body_mesh(), critter_count, 0.58)
	mm_critter_tail = _make_mm(_build_critter_tail_mesh(is_fl), critter_count, 0.58)

	if gator_count > 0:
		mm_gator      = _make_mm(_build_gator_body_mesh(), gator_count, 0.62)
		mm_gator_tail = _make_mm(_build_gator_tail_mesh(), gator_count, 0.62)

	var b_pal = [Color(0.95, 0.96, 0.98), Color(0.86, 0.89, 0.93), Color(0.98, 0.54, 0.64), Color(0.24, 0.84, 0.36)] if is_fl else [Color(0.32, 0.34, 0.38), Color(0.14, 0.15, 0.18), Color(0.56, 0.52, 0.46)]
	birds.clear()
	for i in bird_count:
		var ang = randf() * TAU
		birds.append({
			"pos": Vector3(cos(ang) * randf_range(10, 90), randf_range(12, 34), sin(ang) * randf_range(10, 90)),
			"vel": Vector3(cos(ang + 1.5), 0.0, sin(ang + 1.5)) * randf_range(7.5, 13.0),
			"phase": randf() * TAU, "alt": randf_range(11.0, 36.0), "sc": randf_range(0.85, 1.35)
		})
		var c = b_pal[i % b_pal.size()]
		mm_bird_body.multimesh.set_instance_color(i, c)
		mm_wing_l.multimesh.set_instance_color(i, c.darkened(0.08))
		mm_wing_r.multimesh.set_instance_color(i, c.darkened(0.08))

	var c_pal = [Color(0.24, 0.72, 0.24), Color(0.38, 0.78, 0.26), Color(0.82, 0.50, 0.20), Color(0.54, 0.46, 0.30)] if is_fl else [Color(0.46, 0.32, 0.22), Color(0.54, 0.42, 0.30), Color(0.42, 0.42, 0.44)]
	critters.clear()
	for i in critter_count:
		critters.append({
			"pos": Vector3(0, -50, 0), "dir": Vector3(1, 0, 0),
			"spd": randf_range(2.2, 4.5), "timer": randf_range(0.5, 2.5), "phase": randf() * TAU, "flee": 0.0
		})
		var cc = c_pal[i % c_pal.size()]
		mm_critter.multimesh.set_instance_color(i, cc)
		mm_critter_tail.multimesh.set_instance_color(i, cc.darkened(0.12))

	gators.clear()
	for i in gator_count:
		gators.append({"pos": Vector3(0, -50, 0), "yaw": randf() * TAU, "timer": randf_range(2.0, 6.0), "phase": randf() * TAU})
		var gc = Color(0.18, 0.28, 0.16).lightened(randf_range(-0.04, 0.05))
		mm_gator.multimesh.set_instance_color(i, gc)
		mm_gator_tail.multimesh.set_instance_color(i, gc.darkened(0.08))

func scatter_near(origin: Vector3, radius: float) -> void:
	for c in critters:
		if c["pos"].distance_to(origin) < radius: c["flee"] = 4.5
	for b in birds:
		if b["pos"].distance_to(origin) < radius * 1.5: b["vel"].y += 4.5

func update_wildlife(delta: float, focus_pos: Vector3) -> void:
	var bm = mm_bird_body.multimesh; var wl = mm_wing_l.multimesh; var wr = mm_wing_r.multimesh
	for i in bird_count:
		var b = birds[i]
		var to_c = focus_pos - b["pos"]; to_c.y = 0
		if to_c.length() > 125.0: b["vel"] += to_c.normalized() * 14.0 * delta
		else: b["vel"] += Vector3(-to_c.z, 0, to_c.x).normalized() * 3.5 * delta
		b["vel"].y = lerpf(b["vel"].y, (b["alt"] - b["pos"].y) * 0.6, delta * 2.0)
		b["vel"] = b["vel"].normalized() * clampf(b["vel"].length(), 7.5, 15.0)
		b["pos"] += b["vel"] * delta; b["phase"] += delta * 12.5

		var yaw = atan2(b["vel"].x, b["vel"].z)
		var sc: float = b["sc"]
		var flap = sin(b["phase"]) * 0.68
		var body_b = Basis(Vector3.UP, yaw).scaled(Vector3.ONE * sc)
		bm.set_instance_transform(i, Transform3D(body_b, b["pos"]))
		var lb = (Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD,  flap)).scaled(Vector3.ONE * sc)
		var rb = (Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, -flap)).scaled(Vector3.ONE * sc)
		wl.set_instance_transform(i, Transform3D(lb, b["pos"] + Basis(Vector3.UP, yaw) * Vector3(-0.08 * sc, 0.02 * sc, 0)))
		wr.set_instance_transform(i, Transform3D(rb, b["pos"] + Basis(Vector3.UP, yaw) * Vector3( 0.08 * sc, 0.02 * sc, 0)))

	var cm = mm_critter.multimesh; var tm = mm_critter_tail.multimesh
	for i in critter_count:
		var c = critters[i]; var pos: Vector3 = c["pos"]
		if pos.y < -10.0 or pos.distance_to(focus_pos) > 95.0:
			var a = randf() * TAU; var r = randf_range(10.0, 75.0)
			pos = Vector3(focus_pos.x + cos(a) * r, 0.0, focus_pos.z + sin(a) * r)
			c["dir"] = Vector3(cos(randf() * TAU), 0, sin(randf() * TAU))
		if pos.distance_to(focus_pos) < 7.0: c["flee"] = 3.0
		c["timer"] -= delta
		var spd: float = c["spd"]
		if c["flee"] > 0.0:
			c["flee"] -= delta
			var away = pos - focus_pos; away.y = 0
			if away.length() > 0.1: c["dir"] = away.normalized()
			spd = 7.4
		elif c["timer"] <= 0.0:
			c["timer"] = randf_range(0.8, 3.0)
			c["dir"] = Vector3.ZERO if randf() < 0.42 else Vector3(cos(randf() * TAU), 0, sin(randf() * TAU))
		pos += c["dir"] * spd * delta; pos.y = 0.0; c["pos"] = pos
		c["phase"] += delta * (14.0 if c["dir"].length() > 0.05 else 2.5)
		var yaw = atan2(c["dir"].x, c["dir"].z) if c["dir"].length() > 0.05 else 0.0
		var wag = sin(c["phase"]) * 0.28
		var cb = Basis(Vector3.UP, yaw)
		cm.set_instance_transform(i, Transform3D(cb, pos))
		tm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yaw + wag), pos - cb * Vector3(0, 0, 0.18)))

	if gator_count > 0:
		var gm = mm_gator.multimesh; var gt = mm_gator_tail.multimesh
		for i in gator_count:
			var g = gators[i]; var pos: Vector3 = g["pos"]
			if pos.y < -10.0 or pos.distance_to(focus_pos) > 130.0:
				var a = randf() * TAU; var r = randf_range(24.0, 105.0)
				pos = Vector3(focus_pos.x + cos(a) * r, 0.0, focus_pos.z + sin(a) * r)
			g["timer"] -= delta
			if g["timer"] <= 0.0: g["timer"] = randf_range(3.0, 7.0); g["yaw"] += randf_range(-0.6, 0.6)
			pos += Vector3(sin(g["yaw"]), 0, cos(g["yaw"])) * 1.0 * delta; pos.y = 0.0; g["pos"] = pos
			g["phase"] += delta * 3.5
			var gb = Basis(Vector3.UP, g["yaw"])
			gm.set_instance_transform(i, Transform3D(gb, pos))
			gt.set_instance_transform(i, Transform3D(Basis(Vector3.UP, g["yaw"] + sin(g["phase"]) * 0.24), pos - gb * Vector3(0, 0, 0.80)))
