extends Node3D
class_name LandmarkLoader

var origin_lat := 0.0
var origin_lon := 0.0
var use_gps := false
var loaded_count := 0

func load_landmarks(p_use_gps: bool, p_lat: float, p_lon: float) -> int:
	use_gps = p_use_gps; origin_lat = p_lat; origin_lon = p_lon; loaded_count = 0
	var cfg := "res://assets/landmarks/landmarks.json"
	if not FileAccess.file_exists(cfg): return 0
	var data = JSON.parse_string(FileAccess.open(cfg, FileAccess.READ).get_as_text())
	if typeof(data) != TYPE_ARRAY: return 0
	for entry in data:
		if typeof(entry) == TYPE_DICTIONARY: _spawn_landmark(entry)
	return loaded_count

func _resolve_pos(entry: Dictionary) -> Vector3:
	if use_gps and entry.has("lat") and entry.has("lon"):
		var x = (float(entry["lon"]) - origin_lon) * 111320.0 * cos(deg_to_rad(origin_lat))
		var z = -(float(entry["lat"]) - origin_lat) * 111320.0
		return Vector3(x, float(entry.get("y", 0.0)), z)
	var p = entry.get("pos", [0.0, 0.0, 0.0])
	return Vector3(float(p[0]), float(p[1]), float(p[2]))

func _spawn_landmark(entry: Dictionary) -> void:
	var fpath: String = str(entry.get("file", ""))
	var pos = _resolve_pos(entry)
	var sc = float(entry.get("scale", 1.0))
	var yaw = float(entry.get("yaw_deg", 0.0))
	var title = str(entry.get("name", "Landmark"))

	if fpath.ends_with(".ply"):
		if FileAccess.file_exists(fpath) and ClassDB.class_exists("GaussianSplatNode"):
			var splat = ClassDB.instantiate("GaussianSplatNode")
			splat.position = pos; splat.rotation_degrees.y = yaw; splat.scale = Vector3.ONE * sc
			var res = ResourceLoader.load(fpath)
			if res: splat.set("splat_data", res)
			add_child(splat); loaded_count += 1; return
		_spawn_beacon(pos, title + "\n[Drop .ply + Install GDGS]"); return

	if (fpath.ends_with(".glb") or fpath.ends_with(".gltf")) and FileAccess.file_exists(fpath):
		var gltf = GLTFDocument.new(); var state = GLTFState.new()
		if gltf.append_from_buffer(FileAccess.get_file_as_bytes(fpath), "", state) == OK:
			var scene = gltf.generate_scene(state)
			scene.position = pos; scene.rotation_degrees.y = yaw; scene.scale = Vector3.ONE * sc
			add_child(scene)
			if bool(entry.get("collision", true)): _add_collisions(scene)
			loaded_count += 1; return

	_spawn_beacon(pos, title + "\n[Drop .glb scan here]")

func _add_collisions(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null: node.create_trimesh_collision()
	for child in node.get_children(): _add_collisions(child)

func _spawn_beacon(pos: Vector3, txt: String) -> void:
	var r = Node3D.new(); r.position = pos; add_child(r)
	var mi = MeshInstance3D.new(); var cm = CylinderMesh.new()
	cm.top_radius = 1.6; cm.bottom_radius = 1.6; cm.height = 0.14
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.90, 1.0, 0.7); mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true; mat.emission = Color(0.15, 0.90, 1.0); mat.emission_energy_multiplier = 2.8
	cm.material = mat; mi.mesh = cm; mi.position.y = 0.08; r.add_child(mi)
	var lbl = Label3D.new(); lbl.text = txt; lbl.position = Vector3(0, 2.2, 0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED; lbl.font_size = 24; lbl.outline_size = 6
	lbl.modulate = Color(0.45, 0.95, 1.0); r.add_child(lbl)
