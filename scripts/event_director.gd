extends Node3D
class_name EventDirector

var active_event: Dictionary = {}
var event_root: Node3D = null
var cooldown := 8.0
var race_target := Vector3.ZERO
var race_active := false

signal event_toast(msg: String)
signal event_reward(cash: int, msg: String)

func update_director(delta: float, player_pos: Vector3, player_fwd: Vector3, streamer: ChunkStreamer) -> void:
	if race_active:
		if player_pos.distance_to(race_target) < 11.0:
			race_active = false
			_clear_event()
			event_reward.emit(1200, "STREET SPRINT WON! +$1,200")
		return

	if active_event.is_empty():
		cooldown -= delta
		if cooldown <= 0.0:
			_spawn_emergent_event(player_pos, player_fwd, streamer)
			cooldown = 28.0
	else:
		# Pulse the sky beacon
		if event_root and is_instance_valid(event_root):
			var b = event_root.get_node_or_null("Beacon")
			if b: b.scale.x = 1.0 + sin(Time.get_ticks_msec() * 0.008) * 0.25
		# Despawn if player drives far past it
		if player_pos.distance_to(active_event["pos"]) > 175.0:
			_clear_event()
			cooldown = 12.0

func _spawn_emergent_event(p_pos: Vector3, p_fwd: Vector3, streamer: ChunkStreamer) -> void:
	var ahead = p_pos + p_fwd.normalized() * 68.0
	var spawn_pos = ahead
	if streamer != null:
		spawn_pos = streamer.get_safe_road_spawn(ahead)["car_pos"]
	spawn_pos.y = 0.0

	var types = ["breakdown", "mugging", "street_race", "gator_road"]
	var kind = types[randi() % types.size()]
	_clear_event()

	event_root = Node3D.new()
	event_root.position = spawn_pos
	add_child(event_root)

	var col = Color(1.0, 0.82, 0.15)
	var title = ""
	var prompt = ""
	match kind:
		"breakdown":
			col = Color(1.0, 0.62, 0.12)
			title = "STRANDED DRIVER — Needs Jumpstart"
			prompt = "[F / ACT] Help Stranded Driver (+$350)"
			_add_prop_box(Vector3(2.1, 1.0, 4.3), Vector3(0, 0.55, 0), Color(0.28, 0.45, 0.72))
			_add_prop_box(Vector3(0.9, 0.9, 0.9), Vector3(0, 1.35, 1.4), Color(0.55, 0.55, 0.58)) # Hood smoke
		"mugging":
			col = Color(1.0, 0.20, 0.25)
			title = "STREET MUGGING IN PROGRESS!"
			prompt = "[F / ACT] or [FIRE] Intervene & Save Civilian (+$600)"
			_add_prop_box(Vector3(0.5, 1.7, 0.4), Vector3(-1.2, 0.85, 0), Color(0.92, 0.22, 0.22))
			_add_prop_box(Vector3(0.5, 1.7, 0.4), Vector3( 1.2, 0.85, 0), Color(0.22, 0.78, 0.95))
		"street_race":
			col = Color(0.15, 0.95, 0.55)
			title = "UNDERGROUND STREET RACER!"
			prompt = "[F / ACT] Accept 180m Street Sprint ($1,200 Prize)"
			_add_prop_box(Vector3(2.2, 0.9, 4.5), Vector3(0, 0.5, 0), Color(0.15, 0.92, 0.45))
		"gator_road":
			col = Color(0.30, 0.90, 0.25)
			title = "WILDLIFE ALERT — Giant Gator Blocking Road!"
			prompt = "[F / ACT] Relocate Gator Safely (+$450)"
			_add_prop_box(Vector3(0.85, 0.42, 3.6), Vector3(0, 0.22, 0), Color(0.18, 0.34, 0.16))

	# Tall Glowing Sky Beacon so you spot it cruising down the boulevard
	var beacon = MeshInstance3D.new(); beacon.name = "Beacon"
	var cm = CylinderMesh.new(); cm.top_radius = 0.22; cm.bottom_radius = 0.65; cm.height = 42.0
	var bmat = StandardMaterial3D.new(); bmat.albedo_color = Color(col.r, col.g, col.b, 0.32)
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.emission_enabled = true; bmat.emission = col; bmat.emission_energy_multiplier = 3.0
	cm.material = bmat; beacon.mesh = cm; beacon.position.y = 21.0; event_root.add_child(beacon)

	var lbl = Label3D.new(); lbl.text = title; lbl.position = Vector3(0, 4.0, 0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED; lbl.font_size = 34; lbl.outline_size = 8; lbl.modulate = col
	event_root.add_child(lbl)

	active_event = {"kind": kind, "pos": spawn_pos, "col": col, "title": title, "prompt": prompt}
	event_toast.emit("LIVE EVENT NEARBY: " + title)

func _add_prop_box(sz: Vector3, pos: Vector3, col: Color) -> void:
	var mi = MeshInstance3D.new(); var bm = BoxMesh.new(); bm.size = sz
	var m = StandardMaterial3D.new(); m.albedo_color = col; m.roughness = 0.4
	bm.material = m; mi.mesh = bm; mi.position = pos; event_root.add_child(mi)

func try_interact(p_pos: Vector3, streamer: ChunkStreamer) -> bool:
	if active_event.is_empty() or race_active: return false
	if p_pos.distance_to(active_event["pos"]) > 11.0: return false
	var k = active_event["kind"]
	if k == "street_race":
		var dest = p_pos + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * 175.0
		race_target = streamer.get_safe_road_spawn(dest)["car_pos"] if streamer else dest
		race_active = true
		event_root.position = Vector3(race_target.x, 0.0, race_target.z)
		active_event["pos"] = race_target
		active_event["title"] = "FINISH LINE (180m)"
		event_toast.emit("STREET SPRINT STARTED! Race to the green beacon!")
		return true
	var payouts = {"breakdown": [350, "Helped stranded driver! +$350"], "mugging": [600, "Stopped mugging! Grateful citizen paid +$600"], "gator_road": [450, "Cleared giant gator off the street! +$450"]}
	var pay = payouts.get(k, [300, "Event completed! +$300"])
	_clear_event()
	event_reward.emit(pay[0], pay[1])
	return true

func _clear_event() -> void:
	if event_root and is_instance_valid(event_root): event_root.queue_free()
	event_root = null; active_event = {}
