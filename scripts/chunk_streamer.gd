extends Node3D
class_name ChunkStreamer

var city_slug := ""; var city_name := "Solis Coast"; var biome := "urban"
var origin_lat := 0.0; var origin_lon := 0.0; var chunk_size := 250.0
var available_chunks: Dictionary = {}; var loaded_chunks: Dictionary = {}; var chunk_cache: Dictionary = {}
var last_center := Vector2i(999999, 999999)

var ground_mat: StandardMaterial3D; var road_mat: StandardMaterial3D
var building_mats: Array[StandardMaterial3D] = []
var roof_mat: StandardMaterial3D; var water_mat: ShaderMaterial; var wetland_mat: StandardMaterial3D

func list_regions() -> Array:
	var p := "res://world_data/regions.json"
	if not FileAccess.file_exists(p): return []
	var d = JSON.parse_string(FileAccess.open(p, FileAccess.READ).get_as_text())
	return d if typeof(d) == TYPE_ARRAY else []

func load_active_city() -> bool: return _load_manifest_path("res://world_data/active_city.json")
func load_region(slug: String) -> bool: return _load_manifest_path("res://world_data/%s/manifest.json" % slug)

func _load_manifest_path(manifest_path: String) -> bool:
	if not FileAccess.file_exists(manifest_path): return false
	var data = JSON.parse_string(FileAccess.open(manifest_path, FileAccess.READ).get_as_text())
	if typeof(data) != TYPE_DICTIONARY: return false
	for k in loaded_chunks.keys(): loaded_chunks[k].queue_free()
	loaded_chunks.clear(); chunk_cache.clear(); last_center = Vector2i(999999, 999999)
	city_slug = data.get("slug", ""); city_name = data.get("name", "Unknown"); biome = data.get("biome", "urban")
	origin_lat = float(data.get("origin_lat", 0.0)); origin_lon = float(data.get("origin_lon", 0.0))
	chunk_size = float(data.get("chunk_size", 250.0))
	available_chunks.clear()
	for k in data.get("chunk_keys", []): available_chunks[str(k)] = true
	_init_materials()
	return not available_chunks.is_empty()

func _init_materials() -> void:
	var sw = ProcTextures.sidewalk_pbr()
	ground_mat = StandardMaterial3D.new()
	ground_mat.albedo_texture = sw["albedo"]; ground_mat.normal_enabled = true; ground_mat.normal_texture = sw["normal"]
	ground_mat.uv1_scale = Vector3(0.22, 0.22, 0.22); ground_mat.uv1_triplanar = true; ground_mat.roughness = 0.78
	if biome == "everglades": ground_mat.albedo_color = Color(0.55, 0.64, 0.44)
	elif biome == "florida_coast": ground_mat.albedo_color = Color(0.95, 0.92, 0.86)

	var rd = ProcTextures.road_pbr()
	road_mat = StandardMaterial3D.new()
	road_mat.albedo_texture = rd["albedo"]; road_mat.normal_enabled = true; road_mat.normal_texture = rd["normal"]
	road_mat.roughness_texture = rd["roughness"]; road_mat.roughness = 0.65

	# 6 Distinct Architectural Styles per Biome
	building_mats.clear()
	var styles = [
		[Color(0.86, 0.86, 0.84), Color(0.35, 0.92, 1.0),  0.48, 0.12, 11, 0.13], # Art Deco White Stucco
		[Color(0.30, 0.56, 0.68), Color(0.65, 0.95, 1.0),  0.14, 0.78, 23, 0.16], # Reflective Cyan Glass Tower
		[Color(0.88, 0.66, 0.60), Color(1.0,  0.86, 0.55), 0.58, 0.08, 37, 0.12], # Coral Pastel Condo
		[Color(0.82, 0.76, 0.64), Color(1.0,  0.90, 0.68), 0.65, 0.05, 53, 0.14], # Warm Limestone / Sand
		[Color(0.24, 0.28, 0.36), Color(0.88, 0.42, 0.95), 0.18, 0.72, 71, 0.17], # Modern Dark-Glass High-Rise
		[Color(0.66, 0.44, 0.36), Color(1.0,  0.82, 0.48), 0.72, 0.05, 89, 0.15]  # Terracotta / Brick Commercial
	] if biome == "florida_coast" else [
		[Color(0.62, 0.36, 0.30), Color(1.0,  0.84, 0.52), 0.78, 0.05, 13, 0.14], # Red Brick
		[Color(0.34, 0.46, 0.56), Color(0.75, 0.92, 1.0),  0.18, 0.72, 29, 0.16], # Steel & Glass Office
		[Color(0.72, 0.70, 0.64), Color(1.0,  0.88, 0.62), 0.68, 0.06, 43, 0.13], # Limestone Mid-Rise
		[Color(0.48, 0.50, 0.54), Color(0.95, 0.82, 0.55), 0.75, 0.10, 61, 0.15], # Industrial Concrete
		[Color(0.26, 0.28, 0.34), Color(0.55, 0.85, 1.0),  0.22, 0.68, 79, 0.17], # Dark Slate Tower
		[Color(0.76, 0.66, 0.54), Color(1.0,  0.85, 0.58), 0.70, 0.05, 97, 0.12]  # Warm Sandstone
	]
	for st in styles:
		var fac = ProcTextures.building_facade(st[0], st[1], st[4])
		var m = StandardMaterial3D.new()
		m.albedo_texture = fac["albedo"]; m.normal_enabled = true; m.normal_texture = fac["normal"]
		m.emission_enabled = true; m.emission_texture = fac["emission"]; m.emission_energy_multiplier = 0.85
		m.roughness = st[2]; m.metallic = st[3]
		m.uv1_scale = Vector3(st[5], st[5], st[5]); m.uv1_triplanar = true
		building_mats.append(m)

	roof_mat = StandardMaterial3D.new(); roof_mat.vertex_color_use_as_albedo = true; roof_mat.roughness = 0.82
	water_mat = ShaderMaterial.new()
	water_mat.shader = load("res://shaders/aurora_water.gdshader")
	if biome == "everglades":
		water_mat.set_shader_parameter("deep_color", Color(0.03, 0.14, 0.10))
		water_mat.set_shader_parameter("shallow_color", Color(0.08, 0.32, 0.22))
		water_mat.set_shader_parameter("wave_height", 0.08)
	wetland_mat = StandardMaterial3D.new(); wetland_mat.albedo_color = Color(0.24, 0.42, 0.20); wetland_mat.roughness = 0.88

func set_wetness(wet: float) -> void:
	if road_mat == null: return
	road_mat.roughness = lerpf(0.65, 0.10, wet); road_mat.metallic = lerpf(0.05, 0.28, wet)
	ground_mat.roughness = lerpf(0.78, 0.22, wet)

func set_lidar_overlay(mat: Material) -> void:
	if road_mat: road_mat.next_pass = mat
	if ground_mat: ground_mat.next_pass = mat
	for bm in building_mats: bm.next_pass = mat

func _read_chunk_json(key: String) -> Dictionary:
	if chunk_cache.has(key): return chunk_cache[key]
	var path = "res://world_data/%s/chunk_%s.json" % [city_slug, key]
	if not FileAccess.file_exists(path): return {}
	var data = JSON.parse_string(FileAccess.open(path, FileAccess.READ).get_as_text())
	if typeof(data) == TYPE_DICTIONARY: chunk_cache[key] = data; return data
	return {}

func _in_building(pt: Vector2, bldgs: Array) -> bool:
	for b in bldgs:
		var raw = b.get("pts", [])
		if raw.size() < 3: continue
		var poly := PackedVector2Array()
		for p in raw: poly.append(Vector2(float(p[0]), float(p[1])))
		if Geometry2D.is_point_in_polygon(pt, poly): return true
	return false

func get_sidewalk_spawns(ref_pos: Vector3) -> Array:
	var out: Array = []
	var cx = int(floor(ref_pos.x / chunk_size)); var cz = int(floor(ref_pos.z / chunk_size))
	var data = _read_chunk_json("%d_%d" % [cx, cz])
	if data.is_empty(): return out
	var roads = data.get("roads", [])
	var step = max(1, int(roads.size() / 48))
	for i in range(0, roads.size(), step):
		var r = roads[i]
		var a = Vector2(float(r["a"][0]), float(r["a"][1])); var b = Vector2(float(r["b"][0]), float(r["b"][1]))
		var seg = b - a
		if seg.length() < 4.0: continue
		var dir2 = seg.normalized()
		var side = 1.0 if (i % 2 == 0) else -1.0
		var perp = Vector2(-dir2.y, dir2.x) * (float(r.get("w", 6.5)) * 0.5 + 1.3) * side
		var pt = (a + b) * 0.5 + perp
		out.append({"pos": Vector3(pt.x, 0.0, pt.y), "dir": Vector3(dir2.x * side, 0.0, dir2.y * side)})
	return out

func get_safe_road_spawn(ref_pos: Vector3 = Vector3.ZERO) -> Dictionary:
	var cx = int(floor(ref_pos.x / chunk_size)); var cz = int(floor(ref_pos.z / chunk_size))
	var keys: Array[String] = ["%d_%d" % [cx, cz]]
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var k = "%d_%d" % [cx + dx, cz + dz]
			if available_chunks.has(k) and not keys.has(k): keys.append(k)
	if keys.is_empty() and not available_chunks.is_empty(): keys.append(available_chunks.keys()[0])
	var ref2 = Vector2(ref_pos.x, ref_pos.z); var best_pt := Vector2.ZERO; var best_dir := Vector2(0, -1); var best_d := 999999.0; var found := false
	for key in keys:
		var data = _read_chunk_json(key)
		if data.is_empty(): continue
		var bldgs = data.get("buildings", [])
		for r in data.get("roads", []):
			var a = Vector2(float(r["a"][0]), float(r["a"][1])); var b = Vector2(float(r["b"][0]), float(r["b"][1]))
			var mid = (a + b) * 0.5; var seg = b - a
			if seg.length() < 4.0 or _in_building(mid, bldgs): continue
			var d = mid.distance_to(ref2)
			if d < best_d: best_d = d; best_pt = mid; best_dir = seg.normalized(); found = true
	if not found: return {"car_pos": Vector3(0, 0.9, 0), "car_yaw": 0.0, "player_pos": Vector3(0, 1.2, 5.0)}
	var p_pt = best_pt - best_dir * 4.8
	return {"car_pos": Vector3(best_pt.x, 0.95, best_pt.y), "car_yaw": atan2(best_dir.x, best_dir.y), "player_pos": Vector3(p_pt.x, 1.15, p_pt.y)}

func get_gps_string(w: Vector3) -> String:
	var lat = origin_lat - (w.z / 111320.0)
	var lon = origin_lon + (w.x / (111320.0 * cos(deg_to_rad(origin_lat))))
	return "%s [%s] (%.4f, %.4f)" % [city_name, biome.to_upper(), lat, lon]

func update_streaming(focus_pos: Vector3) -> void:
	var cx = int(floor(focus_pos.x / chunk_size)); var cz = int(floor(focus_pos.z / chunk_size))
	var center = Vector2i(cx, cz)
	if center == last_center: return
	last_center = center
	var keep := {}
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var k = "%d_%d" % [cx + dx, cz + dz]; keep[k] = true
			if not loaded_chunks.has(k): _load_chunk(cx + dx, cz + dz, k)
	for k in loaded_chunks.keys():
		if not keep.has(k): loaded_chunks[k].queue_free(); loaded_chunks.erase(k)

func _load_chunk(cx: int, cz: int, key: String) -> void:
	var root = Node3D.new(); root.name = "Chunk_" + key; add_child(root); loaded_chunks[key] = root
	# Ground on Collision Layer 1
	var gb = StaticBody3D.new(); gb.collision_layer = 1
	gb.position = Vector3((cx + 0.5) * chunk_size, -0.5, (cz + 0.5) * chunk_size)
	var gmi = MeshInstance3D.new(); var gbm = BoxMesh.new(); gbm.size = Vector3(chunk_size, 1.0, chunk_size); gbm.material = ground_mat
	gmi.mesh = gbm; gb.add_child(gmi)
	var gc = CollisionShape3D.new(); var gbs = BoxShape3D.new(); gbs.size = Vector3(chunk_size, 1.0, chunk_size); gc.shape = gbs; gb.add_child(gc)
	root.add_child(gb)

	if not available_chunks.has(key): return
	var data = _read_chunk_json(key)
	if data.is_empty(): return
	_build_flat_polys(root, data.get("wetlands", []), 0.02, wetland_mat)
	_build_flat_polys(root, data.get("water", []), 0.035, water_mat)
	_build_roads(root, data.get("roads", []))
	_build_buildings(root, data.get("buildings", []))
	InfillBuilder.populate_chunk(root, data.get("roads", []), data.get("buildings", []), biome)
	if biome == "florida_coast" or biome == "everglades":
		_scatter_florida_palms(root, data.get("roads", []), data.get("buildings", []))

func _build_flat_polys(parent: Node3D, polys: Array, y_lvl: float, mat: Material) -> void:
	if polys.is_empty(): return
	var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for raw in polys:
		if raw.size() < 3: continue
		var poly := PackedVector2Array()
		for p in raw: poly.append(Vector2(float(p[0]), float(p[1])))
		if not Geometry2D.is_polygon_clockwise(poly): poly.reverse()
		var tris = Geometry2D.triangulate_polygon(poly)
		for t in range(0, tris.size(), 3):
			var a = poly[tris[t]]; var c = poly[tris[t + 1]]; var d = poly[tris[t + 2]]
			st.set_normal(Vector3.UP); st.add_vertex(Vector3(a.x, y_lvl, a.y))
			st.set_normal(Vector3.UP); st.add_vertex(Vector3(c.x, y_lvl, c.y))
			st.set_normal(Vector3.UP); st.add_vertex(Vector3(d.x, y_lvl, d.y))
	var mesh = st.commit()
	if mesh.get_surface_count() > 0:
		mesh.surface_set_material(0, mat)
		var mi = MeshInstance3D.new(); mi.mesh = mesh; parent.add_child(mi)

func _build_roads(parent: Node3D, roads: Array) -> void:
	if roads.is_empty(): return
	var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in roads:
		var a = Vector2(float(r["a"][0]), float(r["a"][1])); var b = Vector2(float(r["b"][0]), float(r["b"][1]))
		var seg = b - a; var length = seg.length()
		if length < 0.2: continue
		var perp = Vector2(-seg.y, seg.x).normalized() * (float(r.get("w", 6.5)) * 0.5)
		var fl = Vector3(a.x + perp.x, 0.06, a.y + perp.y); var fr = Vector3(a.x - perp.x, 0.06, a.y - perp.y)
		var bl = Vector3(b.x + perp.x, 0.06, b.y + perp.y); var br = Vector3(b.x - perp.x, 0.06, b.y - perp.y)
		var vr = length / 8.0
		st.set_normal(Vector3.UP); st.set_uv(Vector2(0, 0)); st.add_vertex(fl)
		st.set_normal(Vector3.UP); st.set_uv(Vector2(1, 0)); st.add_vertex(fr)
		st.set_normal(Vector3.UP); st.set_uv(Vector2(1, vr)); st.add_vertex(br)
		st.set_normal(Vector3.UP); st.set_uv(Vector2(0, 0)); st.add_vertex(fl)
		st.set_normal(Vector3.UP); st.set_uv(Vector2(1, vr)); st.add_vertex(br)
		st.set_normal(Vector3.UP); st.set_uv(Vector2(0, vr)); st.add_vertex(bl)
	var mesh = st.commit(); mesh.surface_set_material(0, road_mat)
	var mi = MeshInstance3D.new(); mi.mesh = mesh; parent.add_child(mi)

func _build_buildings(parent: Node3D, buildings: Array) -> void:
	if buildings.is_empty(): return
	var n_styles = building_mats.size()
	var wall_sts: Array[SurfaceTool] = []
	var has_v: Array[bool] = []
	for s in n_styles:
		var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		wall_sts.append(st); has_v.append(false)
	var st_roof = SurfaceTool.new(); st_roof.begin(Mesh.PRIMITIVE_TRIANGLES)
	var has_roof := false

	var roof_tints = [Color(0.68, 0.68, 0.70), Color(0.35, 0.42, 0.48), Color(0.72, 0.56, 0.50), Color(0.54, 0.52, 0.48), Color(0.28, 0.30, 0.36), Color(0.60, 0.46, 0.40)]

	for b in buildings:
		var raw = b.get("pts", [])
		if raw.size() < 3: continue
		var poly := PackedVector2Array()
		var cx := 0.0; var cz := 0.0
		for p in raw:
			var px = float(p[0]); var pz = float(p[1])
			poly.append(Vector2(px, pz)); cx += px; cz += pz
		cx /= poly.size(); cz /= poly.size()
		if not Geometry2D.is_polygon_clockwise(poly): poly.reverse()

		var h = float(b.get("h", 10.0))
		# Pick distinct architectural style by height + deterministic location hash
		var style_i = int(abs(cx * 13.0 + cz * 7.0)) % n_styles
		if h > 34.0:
			style_i = 1 if (int(abs(cx)) % 2 == 0) else 4 # Tall towers favor glass/modern facades

		var st_w = wall_sts[style_i]; has_v[style_i] = true
		var n = poly.size()
		for i in n:
			var p0 = poly[i]; var p1 = poly[(i + 1) % n]
			st_w.add_vertex(Vector3(p1.x, h, p1.y)); st_w.add_vertex(Vector3(p0.x, h, p0.y)); st_w.add_vertex(Vector3(p0.x, 0, p0.y))
			st_w.add_vertex(Vector3(p1.x, h, p1.y)); st_w.add_vertex(Vector3(p0.x, 0, p0.y)); st_w.add_vertex(Vector3(p1.x, 0, p1.y))

		var rcol = roof_tints[style_i]
		var tris = Geometry2D.triangulate_polygon(poly)
		for t in range(0, tris.size(), 3):
			var a = poly[tris[t]]; var c = poly[tris[t + 1]]; var d = poly[tris[t + 2]]
			st_roof.set_color(rcol); st_roof.set_normal(Vector3.UP); st_roof.add_vertex(Vector3(a.x, h, a.y))
			st_roof.set_color(rcol); st_roof.set_normal(Vector3.UP); st_roof.add_vertex(Vector3(c.x, h, c.y))
			st_roof.set_color(rcol); st_roof.set_normal(Vector3.UP); st_roof.add_vertex(Vector3(d.x, h, d.y))
			has_roof = true

		# Add rooftop mechanical penthouse on tall buildings for silhouette variety
		if h > 20.0:
			var pw = 3.2; var ph = 2.6
			var top_c = rcol.darkened(0.22)
			for s_pts in [
				[Vector3(cx-pw, h+ph, cz-pw), Vector3(cx+pw, h+ph, cz-pw), Vector3(cx+pw, h, cz-pw), Vector3(cx-pw, h, cz-pw)],
				[Vector3(cx+pw, h+ph, cz+pw), Vector3(cx-pw, h+ph, cz+pw), Vector3(cx-pw, h, cz+pw), Vector3(cx+pw, h, cz+pw)],
				[Vector3(cx-pw, h+ph, cz+pw), Vector3(cx-pw, h+ph, cz-pw), Vector3(cx-pw, h, cz-pw), Vector3(cx-pw, h, cz+pw)],
				[Vector3(cx+pw, h+ph, cz-pw), Vector3(cx+pw, h+ph, cz+pw), Vector3(cx+pw, h, cz+pw), Vector3(cx+pw, h, cz-pw)],
				[Vector3(cx-pw, h+ph, cz-pw), Vector3(cx+pw, h+ph, cz-pw), Vector3(cx+pw, h+ph, cz+pw), Vector3(cx-pw, h+ph, cz+pw)]
			]:
				st_roof.set_color(top_c); st_roof.set_normal(Vector3.UP)
				st_roof.add_vertex(s_pts[0]); st_roof.add_vertex(s_pts[1]); st_roof.add_vertex(s_pts[2])
				st_roof.add_vertex(s_pts[0]); st_roof.add_vertex(s_pts[2]); st_roof.add_vertex(s_pts[3])

	var mesh = ArrayMesh.new()
	var s_idx := 0
	for s in n_styles:
		if has_v[s]:
			wall_sts[s].generate_normals()
			wall_sts[s].commit(mesh)
			mesh.surface_set_material(s_idx, building_mats[s])
			s_idx += 1
	if has_roof:
		st_roof.commit(mesh)
		mesh.surface_set_material(s_idx, roof_mat)

	var mi = MeshInstance3D.new(); mi.mesh = mesh; parent.add_child(mi)
	# Buildings on Collision Layer 2 (Ghost/Noclip ignores Layer 2 while staying on Layer 1 ground!)
	var body = StaticBody3D.new(); body.collision_layer = 2
	var col = CollisionShape3D.new(); col.shape = mesh.create_trimesh_shape()
	body.add_child(col); parent.add_child(body)

func _scatter_florida_palms(parent: Node3D, roads: Array, bldgs: Array) -> void:
	var placed := 0; var step = max(1, int(roads.size() / 16))
	for i in range(0, roads.size(), step):
		if placed >= 18: break
		var r = roads[i]
		var a = Vector2(float(r["a"][0]), float(r["a"][1])); var b = Vector2(float(r["b"][0]), float(r["b"][1]))
		var seg = b - a
		if seg.length() < 5.0: continue
		var pt = (a + b) * 0.5 + Vector2(-seg.y, seg.x).normalized() * (float(r.get("w", 6.5)) * 0.5 + 2.2)
		if _in_building(pt, bldgs): continue
		var n = Node3D.new(); n.position = Vector3(pt.x, 0.0, pt.y)
		var tm = StandardMaterial3D.new(); tm.albedo_color = Color(0.42, 0.30, 0.20)
		var lm = StandardMaterial3D.new(); lm.albedo_color = Color(0.14, 0.52, 0.22)
		var trunk = MeshInstance3D.new(); var cm = CylinderMesh.new(); cm.top_radius = 0.14; cm.bottom_radius = 0.24; cm.height = 6.8; cm.material = tm
		trunk.mesh = cm; trunk.position = Vector3(0, 3.4, 0); n.add_child(trunk)
		for f in 6:
			var fr = MeshInstance3D.new(); var bm = BoxMesh.new(); bm.size = Vector3(0.42, 0.08, 3.0); bm.material = lm
			fr.mesh = bm; fr.rotation_degrees = Vector3(-22, f * 60.0, 0)
			fr.position = Vector3(0, 6.7, 0) + Vector3(0, 0, -1.3).rotated(Vector3.UP, deg_to_rad(f * 60.0)); n.add_child(fr)
		parent.add_child(n); placed += 1
