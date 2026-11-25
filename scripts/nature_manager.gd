extends Node3D
class_name NatureManager

var is_desktop := true
var last_cell := Vector2i(999999, 999999)

var mm_palm_trunk: MultiMeshInstance3D
var mm_palm_crown: MultiMeshInstance3D
var mm_oak_trunk: MultiMeshInstance3D
var mm_oak_canopy: MultiMeshInstance3D
var mm_shrub: MultiMeshInstance3D
var mm_grass: MultiMeshInstance3D

var max_palms := 90
var max_oaks := 75
var max_shrubs := 180
var max_grass := 260

func _add_prim(st: SurfaceTool, mesh: Mesh, xf: Transform3D) -> void:
	for s in mesh.get_surface_count():
		st.append_from(mesh, s, xf)

func _build_palm_trunk() -> ArrayMesh:
	var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y := 0.0; var x := 0.0
	for i in 7:
		var seg_h = 1.15
		var r_bot = lerpf(0.28, 0.13, float(i) / 7.0)
		var r_top = lerpf(0.25, 0.12, float(i + 1) / 7.0)
		var cyl = CylinderMesh.new(); cyl.bottom_radius = r_bot; cyl.top_radius = r_top; cyl.height = seg_h; cyl.radial_segments = 8
		var tilt = 0.05 + float(i) * 0.025
		_add_prim(st, cyl, Transform3D(Basis(Vector3.FORWARD, -tilt), Vector3(x, y + seg_h * 0.5, 0)))
		x += sin(tilt) * seg_h * 0.85
		y += cos(tilt) * seg_h * 0.96
	st.generate_normals()
	return st.commit()

func _build_palm_crown() -> ArrayMesh:
	var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base_pos = Vector3(1.05, 7.6, 0.0)
	# Layered arching tropical palm fronds
	for layer in 2:
		var frond_cnt = 9 if layer == 0 else 7
		var pitch_base = 0.35 if layer == 0 else -0.25
		for i in frond_cnt:
			var yaw = (TAU * float(i) / float(frond_cnt)) + (0.35 * layer)
			var b_yaw = Basis(Vector3.UP, yaw)
			# Inner arching frond segment
			var f1 = PrismMesh.new(); f1.size = Vector3(0.75, 2.2, 0.08)
			var xf1 = Transform3D(b_yaw * Basis(Vector3.RIGHT, PI * 0.42 + pitch_base), base_pos + b_yaw * Vector3(0, 0.15 * layer, 1.05))
			_add_prim(st, f1, xf1)
			# Drooping outer frond tip
			var f2 = PrismMesh.new(); f2.size = Vector3(0.52, 1.9, 0.05)
			var xf2 = Transform3D(b_yaw * Basis(Vector3.RIGHT, PI * 0.68 + pitch_base * 0.7), base_pos + b_yaw * Vector3(0, -0.28 + 0.25 * layer, 2.55))
			_add_prim(st, f2, xf2)
	st.generate_normals()
	return st.commit()

func _build_oak_trunk() -> ArrayMesh:
	var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Flared root base + gnarled main trunk
	var base = CylinderMesh.new(); base.bottom_radius = 0.62; base.top_radius = 0.36; base.height = 1.6; base.radial_segments = 8
	_add_prim(st, base, Transform3D(Basis.IDENTITY, Vector3(0, 0.8, 0)))
	var mid = CylinderMesh.new(); mid.bottom_radius = 0.36; mid.top_radius = 0.26; mid.height = 2.6; mid.radial_segments = 8
	_add_prim(st, mid, Transform3D(Basis(Vector3.FORWARD, 0.06), Vector3(0.06, 2.7, 0)))
	# 4 Primary Spreading Limbs
	for i in 4:
		var ang = TAU * float(i) / 4.0 + 0.4
		var limb = CylinderMesh.new(); limb.bottom_radius = 0.18; limb.top_radius = 0.08; limb.height = 2.8; limb.radial_segments = 6
		var rot = Basis(Vector3.UP, ang) * Basis(Vector3.RIGHT, 0.78)
		_add_prim(st, limb, Transform3D(rot, Vector3(0.1, 3.8, 0) + Basis(Vector3.UP, ang) * Vector3(0, 0.7, 0.95)))
	st.generate_normals()
	return st.commit()

func _build_oak_canopy() -> ArrayMesh:
	var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var puffs = [
		[Vector3(0.0, 5.6, 0.0), Vector3(2.8, 1.8, 2.8)],
		[Vector3(1.8, 4.9, 1.2), Vector3(2.1, 1.5, 2.0)],
		[Vector3(-1.9, 5.0, 1.0), Vector3(2.2, 1.5, 2.1)],
		[Vector3(1.1, 4.8, -1.8), Vector3(2.0, 1.4, 2.0)],
		[Vector3(-1.3, 4.7, -1.6), Vector3(2.1, 1.4, 1.9)],
		[Vector3(0.2, 6.7, 0.1), Vector3(1.9, 1.3, 1.9)]
	]
	var sp = SphereMesh.new(); sp.radius = 1.0; sp.height = 2.0; sp.radial_segments = 9; sp.rings = 5
	for pf in puffs:
		_add_prim(st, sp, Transform3D(Basis.IDENTITY.scaled(pf[1]), pf[0]))
	st.generate_normals()
	return st.commit()

func _build_shrub_mesh() -> ArrayMesh:
	var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Dense tropical bush core + radiating saw-palmetto leaves
	var core = SphereMesh.new(); core.radius = 0.62; core.height = 0.92; core.radial_segments = 8; core.rings = 4
	_add_prim(st, core, Transform3D(Basis.IDENTITY.scaled(Vector3(1.25, 0.85, 1.25)), Vector3(0, 0.36, 0)))
	var blade = PrismMesh.new(); blade.size = Vector3(0.32, 1.15, 0.04)
	for i in 8:
		var yaw = TAU * float(i) / 8.0
		var b = Basis(Vector3.UP, yaw)
		_add_prim(st, blade, Transform3D(b * Basis(Vector3.RIGHT, 0.82), b * Vector3(0, 0.42, 0.58)))
	st.generate_normals()
	return st.commit()

func _build_grass_mesh() -> ArrayMesh:
	var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blade = PrismMesh.new(); blade.size = Vector3(0.14, 0.65, 0.02)
	for i in 6:
		var yaw = TAU * float(i) / 6.0
		var b = Basis(Vector3.UP, yaw)
		_add_prim(st, blade, Transform3D(b * Basis(Vector3.RIGHT, 0.25), b * Vector3(0, 0.30, 0.14)))
	st.generate_normals()
	return st.commit()

func _make_mm(mesh: Mesh, mat: Material, cnt: int, cast_sh: bool) -> MultiMeshInstance3D:
	mesh.surface_set_material(0, mat)
	var mm = MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = true
	mm.mesh = mesh; mm.instance_count = cnt; mm.visible_instance_count = 0
	var mmi = MultiMeshInstance3D.new(); mmi.multimesh = mm; mmi.extra_cull_margin = 160.0
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_sh else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi); return mmi

func setup(desktop_mode: bool) -> void:
	is_desktop = desktop_mode
	max_palms  = 95 if is_desktop else 45
	max_oaks   = 80 if is_desktop else 35
	max_shrubs = 190 if is_desktop else 85
	max_grass  = 260 if is_desktop else 110

	var bark_mat = StandardMaterial3D.new()
	bark_mat.vertex_color_use_as_albedo = true; bark_mat.roughness = 0.92

	var wind_mat = ShaderMaterial.new()
	wind_mat.shader = load("res://shaders/foliage_wind.gdshader")
	wind_mat.set_shader_parameter("wind_strength", 0.14)

	var grass_mat = ShaderMaterial.new()
	grass_mat.shader = load("res://shaders/foliage_wind.gdshader")
	grass_mat.set_shader_parameter("wind_strength", 0.22)
	grass_mat.set_shader_parameter("wind_speed", 2.4)

	mm_palm_trunk = _make_mm(_build_palm_trunk(), bark_mat, max_palms, true)
	mm_palm_crown = _make_mm(_build_palm_crown(), wind_mat, max_palms, false)
	mm_oak_trunk  = _make_mm(_build_oak_trunk(),  bark_mat, max_oaks, true)
	mm_oak_canopy = _make_mm(_build_oak_canopy(), wind_mat, max_oaks, false)
	mm_shrub      = _make_mm(_build_shrub_mesh(), wind_mat, max_shrubs, false)
	mm_grass      = _make_mm(_build_grass_mesh(), grass_mat, max_grass, false)

func _hash2(x: int, z: int, salt: int) -> float:
	var n = (x * 374761393 + z * 668265263 + salt * 1442695041) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	return float(n & 0xffff) / 65535.0

func update_nature(focus_pos: Vector3) -> void:
	# Re-scatter deterministically only when crossing a 18m grid cell
	var cell = Vector2i(int(floor(focus_pos.x / 18.0)), int(floor(focus_pos.z / 18.0)))
	if cell == last_cell: return
	last_cell = cell

	var p_i := 0; var o_i := 0; var s_i := 0; var g_i := 0
	var rad = 6 if is_desktop else 4

	for gx in range(cell.x - rad, cell.x + rad + 1):
		for gz in range(cell.y - rad, cell.y + rad + 1):
			# Keep clear corridors every 3rd grid line for main roads/sidewalks
			if abs(gx) % 3 == 0 or abs(gz) % 3 == 0:
				continue

			var h1 = _hash2(gx, gz, 11)
			var h2 = _hash2(gx, gz, 29)
			var h3 = _hash2(gx, gz, 47)
			var wx = float(gx) * 18.0 + (h1 - 0.5) * 14.0
			var wz = float(gz) * 18.0 + (h2 - 0.5) * 14.0
			var yaw = h3 * TAU

			# Trees (Royal Palms + Live Oaks)
			if h3 < 0.52 and p_i < max_palms:
				var sc = lerpf(0.82, 1.32, h1)
				var xf = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * sc), Vector3(wx, 0.0, wz))
				mm_palm_trunk.multimesh.set_instance_transform(p_i, xf)
				mm_palm_crown.multimesh.set_instance_transform(p_i, xf)
				mm_palm_trunk.multimesh.set_instance_color(p_i, Color(0.46, 0.39, 0.32).lightened((h2 - 0.5) * 0.12))
				mm_palm_crown.multimesh.set_instance_color(p_i, Color(0.16, 0.44, 0.14).lightened((h1 - 0.5) * 0.16))
				p_i += 1
			elif h3 >= 0.52 and h3 < 0.88 and o_i < max_oaks:
				var sc = lerpf(0.85, 1.40, h2)
				var xf = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * sc), Vector3(wx, 0.0, wz))
				mm_oak_trunk.multimesh.set_instance_transform(o_i, xf)
				mm_oak_canopy.multimesh.set_instance_transform(o_i, xf)
				mm_oak_trunk.multimesh.set_instance_color(o_i, Color(0.30, 0.22, 0.16).lightened((h1 - 0.5) * 0.08))
				mm_oak_canopy.multimesh.set_instance_color(o_i, Color(0.13, 0.36, 0.13).lightened((h2 - 0.5) * 0.14))
				o_i += 1

			# Surrounding Tropical Shrubs (2 per vegetated cell)
			for sub in 2:
				if s_i >= max_shrubs: break
				var sx = wx + (_hash2(gx, gz, 71 + sub * 7) - 0.5) * 8.5
				var sz = wz + (_hash2(gx, gz, 97 + sub * 7) - 0.5) * 8.5
				var ssc = lerpf(0.65, 1.35, _hash2(gx, gz, 113 + sub))
				var sxf = Transform3D(Basis(Vector3.UP, _hash2(gx, gz, 131 + sub) * TAU).scaled(Vector3.ONE * ssc), Vector3(sx, 0.0, sz))
				mm_shrub.multimesh.set_instance_transform(s_i, sxf)
				mm_shrub.multimesh.set_instance_color(s_i, Color(0.14, 0.40, 0.14).lightened((_hash2(gx, gz, 149 + sub) - 0.5) * 0.18))
				s_i += 1

			# Wild Grass / Fern Clusters (3 per vegetated cell)
			for gr in 3:
				if g_i >= max_grass: break
				var gx_p = wx + (_hash2(gx, gz, 173 + gr * 5) - 0.5) * 11.0
				var gz_p = wz + (_hash2(gx, gz, 191 + gr * 5) - 0.5) * 11.0
				var gsc = lerpf(0.75, 1.55, _hash2(gx, gz, 211 + gr))
				var gxf = Transform3D(Basis(Vector3.UP, _hash2(gx, gz, 227 + gr) * TAU).scaled(Vector3.ONE * gsc), Vector3(gx_p, 0.0, gz_p))
				mm_grass.multimesh.set_instance_transform(g_i, gxf)
				mm_grass.multimesh.set_instance_color(g_i, Color(0.22, 0.48, 0.16).lightened((_hash2(gx, gz, 241 + gr) - 0.5) * 0.20))
				g_i += 1

	mm_palm_trunk.multimesh.visible_instance_count = p_i
	mm_palm_crown.multimesh.visible_instance_count = p_i
	mm_oak_trunk.multimesh.visible_instance_count = o_i
	mm_oak_canopy.multimesh.visible_instance_count = o_i
	mm_shrub.multimesh.visible_instance_count = s_i
	mm_grass.multimesh.visible_instance_count = g_i
