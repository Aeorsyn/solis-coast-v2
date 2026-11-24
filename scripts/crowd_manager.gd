extends Node3D
class_name CrowdManager

var count := 180
var use_glb_bases := false
var mm_male: MultiMeshInstance3D; var mm_female: MultiMeshInstance3D
var agents: Array[Dictionary] = []

func _extract_glb_mesh(path: String) -> ArrayMesh:
	if not FileAccess.file_exists(path): return null
	var gltf = GLTFDocument.new(); var st_gltf = GLTFState.new()
	if gltf.append_from_buffer(FileAccess.get_file_as_bytes(path), "", st_gltf) != OK: return null
	var scene = gltf.generate_scene(st_gltf)
	if scene == null: return null

	# 1. Gather raw mesh geometry & first albedo texture
	var raw_st = SurfaceTool.new(); raw_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base_tex: Texture2D = null
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is MeshInstance3D and n.mesh != null:
			var m: Mesh = n.mesh
			for s_idx in m.get_surface_count():
				if base_tex == null:
					var smat = m.surface_get_material(s_idx)
					if smat is StandardMaterial3D and smat.albedo_texture != null:
						base_tex = smat.albedo_texture
				raw_st.append_from(m, s_idx, Transform3D.IDENTITY)
		for c in n.get_children(): stack.append(c)
	scene.queue_free()

	var tmp_mesh = raw_st.commit()
	if tmp_mesh.get_surface_count() == 0: return null
	var arrays = tmp_mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if verts.is_empty(): return null

	# 2. Measure true vertex extents directly
	var mn = verts[0]; var mx = verts[0]
	for v in verts:
		mn = mn.min(v); mx = mx.max(v)
	var sz = mx - mn

	# 3. Rotate the longest axis onto +Y so no model can ever lie horizontal
	var rot := Basis.IDENTITY
	if sz.z > sz.y * 1.15 and sz.z >= sz.x:
		rot = Basis(Vector3.RIGHT, -PI * 0.5)
	elif sz.x > sz.y * 1.15 and sz.x >= sz.z:
		rot = Basis(Vector3.FORWARD, PI * 0.5)

	# 4. Re-measure after upright rotation, then normalize to exact 1.78m with feet at y = 0
	var r_mn = rot * verts[0]; var r_mx = r_mn
	for i in verts.size():
		var rv = rot * verts[i]
		verts[i] = rv
		r_mn = r_mn.min(rv); r_mx = r_mx.max(rv)

	var h = maxf(r_mx.y - r_mn.y, 0.001)
	var sc = 1.78 / h
	var cx = (r_mn.x + r_mx.x) * 0.5
	var cz = (r_mn.z + r_mx.z) * 0.5

	for i in verts.size():
		var v = verts[i]
		verts[i] = Vector3((v.x - cx) * sc, (v.y - r_mn.y) * sc, (v.z - cz) * sc)
	arrays[Mesh.ARRAY_VERTEX] = verts

	if arrays[Mesh.ARRAY_NORMAL] != null:
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in norms.size(): norms[i] = (rot * norms[i]).normalized()
		arrays[Mesh.ARRAY_NORMAL] = norms

	var out_mesh = ArrayMesh.new()
	out_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true; mat.roughness = 0.65
	if base_tex != null: mat.albedo_texture = base_tex
	out_mesh.surface_set_material(0, mat)
	return out_mesh

func _make_mm(mesh: Mesh, cnt: int) -> MultiMeshInstance3D:
	var mm = MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = true
	mm.mesh = mesh; mm.instance_count = cnt
	var mmi = MultiMeshInstance3D.new(); mmi.multimesh = mm; mmi.extra_cull_margin = 200.0
	add_child(mmi); return mmi

func setup(p_count: int) -> void:
	count = p_count
	var male_mesh = _extract_glb_mesh("res://assets/avatars/npcs/npc_0.glb")
	var female_mesh = _extract_glb_mesh("res://assets/avatars/npcs/npc_1.glb")
	if male_mesh != null and female_mesh == null: female_mesh = male_mesh
	if female_mesh != null and male_mesh == null: male_mesh = female_mesh

	var tints = [
		Color(1.0, 1.0, 1.0), Color(0.95, 0.85, 0.82), Color(0.82, 0.90, 0.98),
		Color(0.96, 0.92, 0.78), Color(0.84, 0.95, 0.86), Color(0.92, 0.82, 0.94)
	]
	agents.clear()
	if male_mesh == null: return
	use_glb_bases = true
	var half = int(count / 2); var rem = count - half
	mm_male = _make_mm(male_mesh, half); mm_female = _make_mm(female_mesh, rem)
	for i in count:
		var is_f = (i >= half); var slot = (i - half) if is_f else i
		agents.append({
			"pos": Vector3(0, -50, 0), "dir": Vector3(0, 0, 1),
			"spd": randf_range(1.4, 2.3), "phase": randf() * TAU,
			"flee": 0.0, "female": is_f, "slot": slot, "scale": randf_range(0.96, 1.04)
		})
		var col = tints[i % tints.size()]
		if is_f: mm_female.multimesh.set_instance_color(slot, col)
		else: mm_male.multimesh.set_instance_color(slot, col)

func panic_near(origin: Vector3, radius: float) -> void:
	for a in agents:
		if a["pos"].distance_to(origin) < radius: a["flee"] = 6.0

func update_crowd(delta: float, focus_pos: Vector3, streamer: ChunkStreamer) -> void:
	if not use_glb_bases: return
	var pool: Array = streamer.get_sidewalk_spawns(focus_pos) if streamer != null else []
	for i in count:
		var a = agents[i]; var pos: Vector3 = a["pos"]
		if pos.y < -10.0 or pos.distance_to(focus_pos) > 135.0:
			if not pool.is_empty():
				var pick = pool[randi() % pool.size()]
				pos = pick["pos"]; a["dir"] = pick["dir"]
			else:
				var ang = randf() * TAU; var r = randf_range(14.0, 95.0)
				pos = Vector3(focus_pos.x + cos(ang) * r, 0.0, focus_pos.z + sin(ang) * r)
				a["dir"] = Vector3(cos(randf() * TAU), 0.0, sin(randf() * TAU))
			a["flee"] = 0.0

		var dir: Vector3 = a["dir"]; var spd: float = a["spd"]
		if pos.distance_to(focus_pos) < 5.5: a["flee"] = maxf(a["flee"], 2.5)
		if a["flee"] > 0.0:
			a["flee"] -= delta
			var away = pos - focus_pos; away.y = 0
			if away.length() > 0.1: dir = away.normalized()
			spd = 5.4

		pos += dir * spd * delta; pos.y = 0.0
		a["pos"] = pos; a["phase"] += delta * spd * 3.8
		var yaw = atan2(dir.x, dir.z)
		var bob = abs(sin(a["phase"])) * 0.05
		var sc = a["scale"]
		var sway = Basis.from_euler(Vector3(0.05 if a["flee"] > 0.0 else 0.012, yaw, sin(a["phase"]) * 0.04)).scaled(Vector3.ONE * sc)
		var xf = Transform3D(sway, pos + Vector3(0, bob, 0))
		if a["female"]: mm_female.multimesh.set_instance_transform(a["slot"], xf)
		else: mm_male.multimesh.set_instance_transform(a["slot"], xf)
