extends Node3D
class_name ArchetypeNPCManager

var npcs: Array[Dictionary] = []
var active := false
var _scan_cd := 2.0

const FIRST_NAMES = ["Kaelen", "Seraphia", "Orin", "Lyra", "Vael", "Theron", "Nyx", "Solon", "Aurelia", "Malakor", "Enoch", "Zephira"]
const TITLES = {
	"PROPHET": "Voice of the Wheels",
	"WARLORD": "Void-Admiral",
	"ARCHITECT": "Star-Architect",
	"ARCHON": "Ascended Archon"
}

signal npc_emerged(msg: String)
signal npc_destroyed(msg: String, cash: int, xp: int, roll_loot: bool)

func set_active(state: bool) -> void:
	active = state
	visible = state

func clear_sector_npcs() -> void:
	for n in npcs:
		if is_instance_valid(n["node"]):
			n["node"].queue_free()
	npcs.clear()

func _has_archetype_on(planet_name: String, arch: String) -> bool:
	for n in npcs:
		if n["home"] == planet_name and n["archetype"] == arch:
			return true
	return false

func _spawn_archetype_vessel(p: Dictionary, arch: String) -> void:
	var root = StaticBody3D.new()
	root.collision_layer = 2
	root.collision_mask = 0
	root.add_to_group("archetype_npc")
	add_child(root)

	var cshape = CollisionShape3D.new()
	var sph = SphereShape3D.new(); sph.radius = 4.6
	cshape.shape = sph
	root.add_child(cshape)

	var col := Color(1.0, 0.86, 0.30)
	var max_hp := 130.0
	if arch == "WARLORD": col = Color(1.0, 0.16, 0.32); max_hp = 190.0
	elif arch == "ARCHITECT": col = Color(0.18, 0.96, 1.0); max_hp = 140.0
	elif arch == "ARCHON": col = Color(0.76, 0.38, 1.0); max_hp = 260.0

	var mat = StandardMaterial3D.new()
	mat.albedo_color = col; mat.metallic = 0.85; mat.roughness = 0.16
	mat.emission_enabled = true; mat.emission = col; mat.emission_energy_multiplier = 4.4

	var halo_mat = StandardMaterial3D.new()
	halo_mat.albedo_color = Color.WHITE; halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_mat.emission_enabled = true; halo_mat.emission = col; halo_mat.emission_energy_multiplier = 6.5

	var core = MeshInstance3D.new()
	if arch == "PROPHET":
		var pm = PrismMesh.new(); pm.size = Vector3(2.8, 5.4, 2.8); pm.material = mat; core.mesh = pm
	elif arch == "WARLORD":
		var bm = BoxMesh.new(); bm.size = Vector3(4.8, 1.6, 8.2); bm.material = mat; core.mesh = bm
	elif arch == "ARCHITECT":
		var sm = SphereMesh.new(); sm.radius = 2.4; sm.height = 4.8; sm.radial_segments = 8; sm.rings = 4; sm.material = mat; core.mesh = sm
	else:
		var am = SphereMesh.new(); am.radius = 1.6; am.height = 3.2; am.radial_segments = 12; am.rings = 6; am.material = halo_mat; core.mesh = am
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(core)

	var ring = MeshInstance3D.new()
	var tor = TorusMesh.new(); tor.inner_radius = 3.4; tor.outer_radius = 3.9; tor.rings = 22; tor.ring_segments = 6; tor.material = halo_mat
	ring.mesh = tor; ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)

	var fname: String = FIRST_NAMES[(npcs.size() * 7 + int(p["year"])) % FIRST_NAMES.size()]
	var full_name = "%s, %s" % [fname, TITLES[arch]]

	# Compact, scaled-to-distance nameplate (never fills the screen up close)
	var lbl = Label3D.new()
	lbl.text = "%s [%s]" % [full_name, arch]
	lbl.position = Vector3(0, 4.2, 0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.font_size = 34; lbl.outline_size = 6; lbl.pixel_size = 0.016
	lbl.modulate = col
	root.add_child(lbl)

	var orbit_r = float(p["r"]) + randf_range(26.0, 54.0)
	var ang = randf() * TAU
	root.global_position = p["body"].global_position + Vector3(cos(ang) * orbit_r, randf_range(-12.0, 18.0), sin(ang) * orbit_r)

	npcs.append({
		"name": full_name, "archetype": arch, "home": p["name"], "planet": p,
		"node": root, "ring": ring, "lbl": lbl, "mat": mat, "base_col": col,
		"orbit_r": orbit_r, "ang": ang, "spd": randf_range(0.32, 0.65),
		"y_off": randf_range(-14.0, 18.0), "escort": (arch == "ARCHON"),
		"hp": max_hp, "max_hp": max_hp, "hit_t": 0.0, "hostile": false
	})
	npc_emerged.emit("ARCHETYPE EMERGED on %s: %s (%s)!" % [p["name"], full_name, arch])

func try_hit_ray(origin: Vector3, dir: Vector3, dmg: float, max_dist := 650.0) -> Dictionary:
	if not active or npcs.is_empty(): return {}
	var ndir := dir.normalized()
	var best_i := -1
	var best_d := max_dist
	for i in npcs.size():
		var n = npcs[i]
		var to_n: Vector3 = n["node"].global_position - origin
		var proj := to_n.dot(ndir)
		if proj < 2.0 or proj > best_d: continue
		var perp := (to_n - ndir * proj).length()
		var hit_r := 6.8 if n["archetype"] == "ARCHON" else 5.8
		if perp <= hit_r:
			best_d = proj; best_i = i
	if best_i == -1: return {}

	var tgt = npcs[best_i]
	var hit_pos: Vector3 = tgt["node"].global_position
	tgt["hp"] -= dmg
	tgt["hit_t"] = 0.22
	tgt["hostile"] = true
	tgt["escort"] = false

	if tgt["hp"] <= 0.0:
		var arch: String = tgt["archetype"]
		var nm: String = tgt["name"]
		var home: String = tgt["home"]
		var cash := 1200 if arch == "ARCHON" else 650
		var xp := 220 if arch == "ARCHON" else 110
		tgt["node"].queue_free()
		npcs.remove_at(best_i)
		npc_destroyed.emit("DESTROYED %s [%s of %s]! (+$%d, +%d XP)" % [nm, arch, home, cash, xp], cash, xp, arch == "ARCHON")
		return {"hit": true, "killed": true, "pos": hit_pos, "name": nm}
	return {"hit": true, "killed": false, "pos": hit_pos, "name": tgt["name"], "hp_pct": int(100.0 * tgt["hp"] / tgt["max_hp"])}

func update_npcs(delta: float, planets: Array[Dictionary], player_pos: Vector3) -> void:
	if not active: return

	_scan_cd -= delta
	if _scan_cd <= 0.0:
		_scan_cd = 3.0
		for p in planets:
			if p["shattered"] or p["stage"] == 0: continue
			var pn: String = p["name"]
			if p["faith"] >= 60.0 and not _has_archetype_on(pn, "PROPHET"):
				_spawn_archetype_vessel(p, "PROPHET")
			if p["tech"] >= 2000.0 and p["stability"] < 68.0 and not _has_archetype_on(pn, "WARLORD"):
				_spawn_archetype_vessel(p, "WARLORD")
			if p["tech"] >= 3000.0 and p["stability"] >= 65.0 and not _has_archetype_on(pn, "ARCHITECT"):
				_spawn_archetype_vessel(p, "ARCHITECT")
			if p["tech"] >= 5000.0 and p["faith"] >= 70.0 and not _has_archetype_on(pn, "ARCHON"):
				_spawn_archetype_vessel(p, "ARCHON")

	for i in range(npcs.size() - 1, -1, -1):
		var n = npcs[i]
		var p: Dictionary = n["planet"]
		if p["shattered"]:
			n["node"].queue_free(); npcs.remove_at(i); continue

		var spd_m := 2.4 if n["hostile"] else 1.0
		n["ang"] += delta * n["spd"] * spd_m
		n["ring"].rotate_x(delta * 2.2 * spd_m)
		n["ring"].rotate_y(delta * 1.6 * spd_m)

		# Hit flash recovery
		if n["hit_t"] > 0.0:
			n["hit_t"] = maxf(0.0, n["hit_t"] - delta)
			n["mat"].emission = Color(1.0, 0.15, 0.10) if n["hit_t"] > 0.0 else n["base_col"]
			n["mat"].emission_energy_multiplier = 9.0 if n["hit_t"] > 0.0 else 4.4

		var target_pos: Vector3
		if n["hostile"]:
			# Evasive combat orbit around the player
			target_pos = player_pos + Vector3(cos(n["ang"] * 1.4) * 48.0, 12.0 + sin(n["ang"] * 2.5) * 14.0, sin(n["ang"] * 1.4) * 48.0)
		elif n["escort"]:
			target_pos = player_pos + Vector3(cos(n["ang"]) * 26.0, 7.0 + sin(n["ang"] * 2.0) * 4.0, sin(n["ang"]) * 26.0)
		else:
			var c: Vector3 = p["body"].global_position
			target_pos = c + Vector3(cos(n["ang"]) * n["orbit_r"], n["y_off"] + sin(n["ang"] * 1.5) * 6.0, sin(n["ang"]) * n["orbit_r"])

		n["node"].global_position = n["node"].global_position.lerp(target_pos, clampf(delta * 2.6, 0.0, 1.0))

		# Keep nameplate small & proportional to distance so it NEVER dominates the screen up close
		var d_cam = player_pos.distance_to(n["node"].global_position)
		var l_sc = clampf(d_cam * 0.018, 0.24, 1.45)
		n["lbl"].scale = Vector3.ONE * l_sc
		n["lbl"].visible = d_cam < 520.0
		if n["hp"] < n["max_hp"]:
			n["lbl"].text = "%s [%d%% HP]" % [n["name"], int(100.0 * n["hp"] / n["max_hp"])]

		if not n["hostile"]:
			if n["archetype"] == "PROPHET": p["faith"] = minf(100.0, p["faith"] + delta * 0.45)
			elif n["archetype"] == "ARCHITECT": p["tech"] += delta * 18.0
			elif n["archetype"] == "WARLORD": p["tech"] += delta * 12.0

func get_summary_lines() -> String:
	if npcs.is_empty():
		return "No Archetypal NPCs emerged yet. Seed worlds & raise Faith/Tech to awaken Prophets, Warlords, Architects & Archons."
	var out: PackedStringArray = []
	for n in npcs:
		out.append("• %s [%s | %d%% HP] — Home: %s" % [n["name"], n["archetype"], int(100.0 * n["hp"] / n["max_hp"]), n["home"]])
	return "\n".join(out)
