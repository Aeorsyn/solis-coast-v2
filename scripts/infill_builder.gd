class_name InfillBuilder

static func populate_chunk(parent: Node3D, roads: Array, bldgs: Array, biome: String) -> void:
	if roads.is_empty(): return
	var placed_centers: Array[Vector2] = []
	var step = max(1, int(roads.size() / 14))
	var count := 0

	for i in range(0, roads.size(), step):
		if count >= 6: break
		var r = roads[i]
		var a = Vector2(float(r["a"][0]), float(r["a"][1]))
		var b = Vector2(float(r["b"][0]), float(r["b"][1]))
		var seg = b - a
		if seg.length() < 12.0: continue

		var dir = seg.normalized()
		var side = 1.0 if (i % 2 == 0) else -1.0
		var perp = Vector2(-dir.y, dir.x) * side
		var road_hw = float(r.get("w", 6.5)) * 0.5
		var lot_center = (a + b) * 0.5 + perp * (road_hw + 9.5)

		if not _is_lot_clear(lot_center, bldgs, roads, placed_centers):
			continue
		placed_centers.append(lot_center)

		var yaw = atan2(-perp.x, -perp.y) # Face the doorway toward the street
		var lot = Node3D.new()
		lot.position = Vector3(lot_center.x, 0.0, lot_center.y)
		lot.rotation.y = yaw
		parent.add_child(lot)

		var kind = (i + count) % 3
		if kind == 0:
			_build_restaurant(lot, biome)
		elif kind == 1:
			_build_store(lot, biome)
		else:
			_build_house(lot, biome)
		count += 1

static func _is_lot_clear(pt: Vector2, bldgs: Array, roads: Array, used: Array[Vector2]) -> bool:
	for u in used:
		if u.distance_to(pt) < 22.0: return false
	for r in roads:
		var a = Vector2(float(r["a"][0]), float(r["a"][1]))
		var b = Vector2(float(r["b"][0]), float(r["b"][1]))
		if Geometry2D.get_closest_point_to_segment(pt, a, b).distance_to(pt) < 8.0:
			return false
	for b in bldgs:
		var raw = b.get("pts", [])
		if raw.size() < 3: continue
		var poly := PackedVector2Array()
		for p in raw: poly.append(Vector2(float(p[0]), float(p[1])))
		if Geometry2D.is_point_in_polygon(pt, poly): return false
		for p in poly:
			if p.distance_to(pt) < 7.5: return false
	return true

static func _box(p: Node3D, sz: Vector3, pos: Vector3, col: Color, emissive := false, solid := true) -> void:
	var b = StaticBody3D.new(); b.position = pos; b.collision_layer = 2
	var mi = MeshInstance3D.new(); var bm = BoxMesh.new(); bm.size = sz
	var m = StandardMaterial3D.new(); m.albedo_color = col; m.roughness = 0.65
	if emissive: m.emission_enabled = true; m.emission = col; m.emission_energy_multiplier = 2.4
	bm.material = m; mi.mesh = bm; b.add_child(mi)
	if solid:
		var cs = CollisionShape3D.new(); var bs = BoxShape3D.new(); bs.size = sz
		cs.shape = bs; b.add_child(cs)
	p.add_child(b)

static func _shell(p: Node3D, w: float, h: float, d: float, wall_col: Color, trim_col: Color, floor_col: Color) -> void:
	var t := 0.35
	_box(p, Vector3(w, 0.12, d), Vector3(0, 0.06, 0), floor_col, false, false)
	_box(p, Vector3(w + 0.4, 0.35, d + 0.4), Vector3(0, h + 0.17, 0), wall_col.darkened(0.25), false, true)
	_box(p, Vector3(w + 0.6, 0.22, d + 0.6), Vector3(0, h + 0.02, 0), trim_col, true, false)
	_box(p, Vector3(t, h, d), Vector3(-w * 0.5, h * 0.5, 0), wall_col)
	_box(p, Vector3(t, h, d), Vector3( w * 0.5, h * 0.5, 0), wall_col)
	_box(p, Vector3(w, h, t), Vector3(0, h * 0.5, -d * 0.5), wall_col)
	# Wide open front entrance (+Z faces road)
	var sw = (w - 3.6) * 0.5
	_box(p, Vector3(sw, h, t), Vector3(-w * 0.5 + sw * 0.5, h * 0.5, d * 0.5), wall_col)
	_box(p, Vector3(sw, h, t), Vector3( w * 0.5 - sw * 0.5, h * 0.5, d * 0.5), wall_col)
	_box(p, Vector3(3.6, 0.9, t), Vector3(0, h - 0.45, d * 0.5), wall_col, false, false)
	var l = OmniLight3D.new(); l.position = Vector3(0, h - 0.7, 0)
	l.light_color = Color(1.0, 0.92, 0.78); l.light_energy = 2.6; l.omni_range = 12.0
	p.add_child(l)

static func _sign(p: Node3D, txt: String, pos: Vector3, col: Color) -> void:
	var lbl = Label3D.new(); lbl.text = txt; lbl.position = pos
	lbl.font_size = 42; lbl.outline_size = 8; lbl.modulate = col
	p.add_child(lbl)

static func _build_restaurant(p: Node3D, biome: String) -> void:
	var wall = Color(0.92, 0.84, 0.76) if biome == "florida_coast" else Color(0.68, 0.34, 0.28)
	var neon = Color(1.0, 0.32, 0.58)
	_shell(p, 11.0, 4.2, 9.5, wall, neon, Color(0.82, 0.80, 0.76))
	_box(p, Vector3(9.6, 0.22, 1.8), Vector3(0, 3.2, 5.4), Color(0.88, 0.18, 0.24), false, false) # Awning
	_sign(p, "PALM DINER" if biome == "florida_coast" else "METRO CAFE", Vector3(0, 4.7, 4.9), neon)

	# Service Counter & Bar Stools
	_box(p, Vector3(6.4, 1.05, 0.85), Vector3(0, 0.52, -2.6), Color(0.28, 0.18, 0.14))
	for sx in [-2.2, -0.8, 0.8, 2.2]:
		_box(p, Vector3(0.45, 0.72, 0.45), Vector3(sx, 0.36, -1.6), Color(0.82, 0.22, 0.25))
	# Furnished Dining Tables & Booths
	for tx in [-3.4, 3.4]:
		for tz in [-0.2, 2.4]:
			_box(p, Vector3(1.3, 0.76, 1.0), Vector3(tx, 0.38, tz), Color(0.48, 0.30, 0.18))
			_box(p, Vector3(1.3, 0.50, 0.45), Vector3(tx, 0.25, tz - 0.85), Color(0.76, 0.20, 0.26))
			_box(p, Vector3(1.3, 0.50, 0.45), Vector3(tx, 0.25, tz + 0.85), Color(0.76, 0.20, 0.26))

static func _build_store(p: Node3D, biome: String) -> void:
	var neon = Color(0.15, 0.95, 0.55)
	_shell(p, 10.5, 4.0, 9.0, Color(0.78, 0.82, 0.86), neon, Color(0.72, 0.74, 0.76))
	_box(p, Vector3(9.0, 0.22, 1.5), Vector3(0, 3.1, 5.1), Color(0.12, 0.62, 0.38), false, false)
	_sign(p, "COAST MART" if biome == "florida_coast" else "CORNER MARKET", Vector3(0, 4.5, 4.7), neon)

	# Checkout Counter & Display Aisles (Furniture)
	_box(p, Vector3(3.2, 1.0, 0.9), Vector3(3.0, 0.5, 2.2), Color(0.22, 0.36, 0.48))
	for ax in [-3.4, -1.0, 1.2]:
		_box(p, Vector3(0.75, 1.75, 4.4), Vector3(ax, 0.88, -0.8), Color(0.84, 0.84, 0.86))
		_box(p, Vector3(0.82, 0.30, 4.2), Vector3(ax, 1.35, -0.8), Color(0.92, 0.52, 0.18), false, false)
	# Rear Cold Drink Coolers
	_box(p, Vector3(7.5, 2.2, 0.75), Vector3(0, 1.1, -3.9), Color(0.35, 0.78, 0.95), true)

static func _build_house(p: Node3D, biome: String) -> void:
	var wall = Color(0.94, 0.86, 0.74) if biome == "florida_coast" else Color(0.78, 0.76, 0.70)
	var roof = Color(0.78, 0.36, 0.24) if biome == "florida_coast" else Color(0.30, 0.32, 0.36)
	# Front Lawn Yard
	_box(p, Vector3(13.0, 0.08, 13.0), Vector3(0, 0.04, 0.5), Color(0.24, 0.54, 0.22), false, false)
	_shell(p, 9.2, 3.5, 8.2, wall, roof, Color(0.62, 0.46, 0.32))
	# Sloped Residential Roof Cap
	_box(p, Vector3(9.8, 0.65, 8.8), Vector3(0, 3.9, 0), roof, false, false)
	_box(p, Vector3(7.4, 0.55, 6.4), Vector3(0, 4.45, 0), roof.darkened(0.1), false, false)

	# Living Room Sofa, Coffee Table, TV Stand & Bedroom Bed
	_box(p, Vector3(2.4, 0.78, 0.95), Vector3(-2.6, 0.39, -2.5), Color(0.26, 0.42, 0.58)) # Sofa
	_box(p, Vector3(1.3, 0.44, 0.75), Vector3(-2.6, 0.22, -1.1), Color(0.45, 0.28, 0.16)) # Coffee Table
	_box(p, Vector3(1.8, 0.65, 0.55), Vector3(-2.6, 0.32,  1.2), Color(0.16, 0.16, 0.18)) # TV Stand
	_box(p, Vector3(2.0, 0.62, 2.3),  Vector3( 2.8, 0.31, -2.2), Color(0.88, 0.86, 0.92)) # Bed
	_box(p, Vector3(2.0, 0.22, 0.55), Vector3( 2.8, 0.70, -3.0), Color(0.25, 0.62, 0.75), false, false) # Pillows
