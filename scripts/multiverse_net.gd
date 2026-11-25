extends Node3D
class_name MultiverseNet

const DEFAULT_PORT := 7777
const MAX_BEACONS := 550

var active := false
var universe_id := 1
var sector_seed := 101
var player_callsign := "SOVEREIGN-UAP"
var player_coalition := "UNALIGNED"
var empire_planets := 5 # Scales seamlessly from 5 -> 50 -> 500+ worlds across universes!

# Live Galactic Coalitions & Rival UAP Sovereigns (populated by network peers + simulated multiverse empires)
var coalitions: Array[Dictionary] = [
	{"name": "NEW DAWN COMPACT",   "leader": "Wanderer-09",  "planets": 5,   "status": "NEUTRAL", "col": Color(0.25, 0.96, 0.72)},
	{"name": "SOLARIS HEGEMONY",   "leader": "Archon-Kael",  "planets": 64,  "status": "NEUTRAL", "col": Color(0.28, 0.76, 1.00)},
	{"name": "IRON ECLIPSE PACT",  "leader": "Dread-Vex",    "planets": 185, "status": "HOSTILE", "col": Color(1.00, 0.24, 0.36)},
	{"name": "SERAPHIM OVERMIND",  "leader": "Ezekiel-500",  "planets": 512, "status": "ALLIED",  "col": Color(1.00, 0.84, 0.28)}
]

# Remote Multiplayer UAP Avatars (peer_id -> Node3D)
var remote_uaps: Dictionary = {}
var net_status := "OFFLINE MULTIVERSE (Press Host/Join for Live Co-op)"
var _sync_cd := 0.0

# GPU-Instanced Distant Empire Beacons (shows 5 to 500+ claimed worlds shimmering across the multiverse sky)
var mm_beacons: MultiMeshInstance3D

# Next-Gen 3D Volumetric Aurora Curtains surrounding the Star System
var aurora_root: Node3D

# Multiverse & Coalition HUD Panel ([M])
var ui_layer: CanvasLayer
var panel: PanelContainer
var hdr_lbl: Label
var net_lbl: Label
var coal_rtl: RichTextLabel
var arch_rtl: RichTextLabel
var ip_edit: LineEdit

signal warp_requested(new_universe: int, new_seed: int, label: String)
signal multiverse_toast(msg: String)

func setup() -> void:
	_build_aurora_veils()
	_build_empire_beacons()
	_build_ui()
	visible = false
	ui_layer.visible = false

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connected_fail)

func _build_aurora_veils() -> void:
	aurora_root = Node3D.new()
	add_child(aurora_root)
	var sh = load("res://shaders/aurora_veil.gdshader")
	var palettes = [
		[Color(0.05, 1.00, 0.76), Color(0.22, 0.48, 1.00), Color(0.95, 0.20, 0.82)],
		[Color(0.18, 0.88, 1.00), Color(0.66, 0.24, 1.00), Color(1.00, 0.76, 0.24)],
		[Color(0.08, 0.96, 0.52), Color(0.14, 0.68, 1.00), Color(0.84, 0.28, 1.00)]
	]
	for i in 3:
		var mat = ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("color_a", palettes[i][0])
		mat.set_shader_parameter("color_b", palettes[i][1])
		mat.set_shader_parameter("color_c", palettes[i][2])
		mat.set_shader_parameter("intensity", 2.2)
		mat.set_shader_parameter("flow_speed", 0.18 + float(i) * 0.05)

		# Curved sweeping ribbon built from an open cylinder band
		var cyl = CylinderMesh.new()
		cyl.top_radius = 680.0 + float(i) * 95.0
		cyl.bottom_radius = 650.0 + float(i) * 95.0
		cyl.height = 170.0 + float(i) * 35.0
		cyl.radial_segments = 48; cyl.rings = 6
		cyl.cap_top = false; cyl.cap_bottom = false
		cyl.material = mat

		var mi = MeshInstance3D.new()
		mi.mesh = cyl
		mi.position = Vector3(0, 320.0 + float(i) * 55.0, 0)
		mi.rotation_degrees = Vector3(14.0 * float(i - 1), float(i) * 52.0, -10.0 * float(i - 1))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		aurora_root.add_child(mi)

func _build_empire_beacons() -> void:
	var sp = SphereMesh.new(); sp.radius = 2.8; sp.height = 5.6; sp.radial_segments = 6; sp.rings = 3
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true; mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sp.material = mat

	var mm = MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = true
	mm.mesh = sp; mm.instance_count = MAX_BEACONS; mm.visible_instance_count = 0
	mm_beacons = MultiMeshInstance3D.new(); mm_beacons.multimesh = mm
	mm_beacons.extra_cull_margin = 1600.0
	mm_beacons.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mm_beacons)
	_rebuild_beacon_sky()

func _rebuild_beacon_sky() -> void:
	var mm = mm_beacons.multimesh
	var idx := 0
	# Player's own empire stars (Gold-Cyan)
	var mine = mini(empire_planets, 300)
	for i in mine:
		if idx >= MAX_BEACONS: break
		var a = float(i) * 2.39996 + float(universe_id)
		var elev = sin(float(i) * 0.37) * 280.0 + 360.0
		var r = 740.0 + fmod(float(i) * 29.0, 260.0)
		mm.set_instance_transform(idx, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 1.1), Vector3(cos(a) * r, elev, sin(a) * r)))
		mm.set_instance_color(idx, Color(1.0, 0.88, 0.35))
		idx += 1

	# Coalition & rival player empire stars across the distant horizon (scales to 500+!)
	for c in coalitions:
		var share = mini(int(c["planets"]) / 3 + 3, 75)
		for k in share:
			if idx >= MAX_BEACONS: break
			var a = float(idx) * 1.61803 + float(sector_seed)
			var elev = cos(float(idx) * 0.43) * 260.0 + 380.0
			var r = 820.0 + fmod(float(idx) * 37.0, 240.0)
			mm.set_instance_transform(idx, Transform3D(Basis.IDENTITY, Vector3(cos(a) * r, elev, sin(a) * r)))
			mm.set_instance_color(idx, c["col"])
			idx += 1
	mm.visible_instance_count = idx

func _build_ui() -> void:
	ui_layer = CanvasLayer.new(); add_child(ui_layer)

	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -410; panel.offset_right = 410; panel.offset_top = -275; panel.offset_bottom = 275
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.12, 0.94); sb.border_color = Color(0.24, 0.96, 0.86, 0.92)
	sb.set_border_width_all(2); sb.set_corner_radius_all(14)
	sb.content_margin_left = 16; sb.content_margin_right = 16; sb.content_margin_top = 14; sb.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", sb)
	panel.visible = false
	ui_layer.add_child(panel)

	var vb = VBoxContainer.new(); vb.add_theme_constant_override("separation", 8); panel.add_child(vb)

	var top_h = HBoxContainer.new(); vb.add_child(top_h)
	hdr_lbl = Label.new(); hdr_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_lbl.add_theme_font_size_override("font_size", 18); hdr_lbl.modulate = Color(0.32, 0.98, 0.86)
	top_h.add_child(hdr_lbl)
	var close_b = Button.new(); close_b.text = "CLOSE [M]"
	close_b.pressed.connect(toggle_panel); top_h.add_child(close_b)

	# Row 1: Multiverse Sector Warp & Empire Expansion Controls
	var warp_h = HBoxContainer.new(); warp_h.add_theme_constant_override("separation", 8); vb.add_child(warp_h)
	var b_next = Button.new(); b_next.text = "WARP NEW UNIVERSE (+8 Worlds)"; b_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_next.pressed.connect(_warp_next_universe); warp_h.add_child(b_next)
	var b_claim = Button.new(); b_claim.text = "ANNEX SECTOR (+25 Empire Worlds)"; b_claim.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_claim.pressed.connect(_annex_sector); warp_h.add_child(b_claim)
	var b_coal = Button.new(); b_coal.text = "ALLY / JOIN TOP COALITION"; b_coal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_coal.pressed.connect(_join_next_coalition); warp_h.add_child(b_coal)

	# Row 2: Live Multiplayer Host / Join (ENet Desktop & Android LAN/WAN)
	var net_h = HBoxContainer.new(); net_h.add_theme_constant_override("separation", 8); vb.add_child(net_h)
	ip_edit = LineEdit.new(); ip_edit.text = "127.0.0.1"; ip_edit.custom_minimum_size = Vector2(180, 0)
	ip_edit.placeholder_text = "Host IP (e.g. 10.0.0.92)"; net_h.add_child(ip_edit)
	var b_host = Button.new(); b_host.text = "HOST MULTIVERSE (:7777)"
	b_host.pressed.connect(host_session); net_h.add_child(b_host)
	var b_join = Button.new(); b_join.text = "JOIN MULTIVERSE"
	b_join.pressed.connect(_join_from_input); net_h.add_child(b_join)
	net_lbl = Label.new(); net_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	net_lbl.add_theme_font_size_override("font_size", 12); net_lbl.modulate = Color(1.0, 0.86, 0.42)
	net_h.add_child(net_lbl)

	# Split Ledger: Galactic Coalitions (Left) + Emergent Archetypal NPCs (Right)
	var split = HBoxContainer.new(); split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 12); vb.add_child(split)

	coal_rtl = RichTextLabel.new(); coal_rtl.bbcode_enabled = true; coal_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coal_rtl.add_theme_font_size_override("normal_font_size", 13); split.add_child(coal_rtl)

	arch_rtl = RichTextLabel.new(); arch_rtl.bbcode_enabled = true; arch_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arch_rtl.add_theme_font_size_override("normal_font_size", 13); split.add_child(arch_rtl)

func set_active(state: bool, origin: Vector3) -> void:
	active = state
	visible = state
	ui_layer.visible = state
	if state:
		aurora_root.global_position = Vector3(origin.x, 0.0, origin.z)
		mm_beacons.global_position = Vector3(origin.x, 0.0, origin.z)

func toggle_panel(arch_summary := "") -> void:
	panel.visible = not panel.visible
	if panel.visible:
		refresh_ui(arch_summary)

func refresh_ui(arch_summary := "") -> void:
	hdr_lbl.text = "MULTIVERSE #%d (Sector %d) | YOUR EMPIRE: %d PLANETS | COALITION: %s" % [
		universe_id, sector_seed, empire_planets, player_coalition
	]
	net_lbl.text = net_status

	var cl := "[color=#55f2ff][b]GALACTIC COALITIONS & SOVEREIGNS[/b][/color]\n"
	cl += "[color=#ffd86b]• YOU (%s): %d Planets [%s][/color]\n\n" % [player_callsign, empire_planets, player_coalition]
	for c in coalitions:
		var hex = c["col"].to_html(false)
		cl += "[color=#%s]• %s[/color] — Leader: %s | [b]%d Planets[/b] (%s)\n" % [hex, c["name"], c["leader"], int(c["planets"]), c["status"]]
	coal_rtl.text = cl

	if not arch_summary.is_empty():
		arch_rtl.text = "[color=#ffd86b][b]EMERGENT ARCHETYPAL NPCs[/b][/color]\n" + arch_summary

func record_seeded_planet() -> void:
	empire_planets += 1
	_rebuild_beacon_sky()

func _warp_next_universe() -> void:
	universe_id += 1
	sector_seed = universe_id * 137 + randi_range(1, 99)
	_rebuild_beacon_sky()
	var label = "UNIVERSE-%d // SECTOR-%d" % [universe_id, sector_seed]
	warp_requested.emit(universe_id, sector_seed, label)
	multiverse_toast.emit("WARPED TO %s! Fresh 8-planet system generated!" % label)
	refresh_ui()

func _annex_sector() -> void:
	empire_planets += 25
	_rebuild_beacon_sky()
	multiverse_toast.emit("GALACTIC EXPANSION: Annexed +25 worlds! Empire total: %d planets!" % empire_planets)
	refresh_ui()

func _join_next_coalition() -> void:
	var idx := 0
	for i in coalitions.size():
		if coalitions[i]["name"] == player_coalition:
			idx = (i + 1) % coalitions.size()
			break
	var c = coalitions[idx]
	player_coalition = c["name"]
	c["status"] = "YOUR COALITION"
	multiverse_toast.emit("JOINED COALITION: %s (%d combined worlds)!" % [c["name"], int(c["planets"]) + empire_planets])
	refresh_ui()

func host_session() -> void:
	if OS.has_feature("web"):
		net_status = "Web builds join via WebSocket relay; simulated multiverse active."
		refresh_ui(); return
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(DEFAULT_PORT, 16)
	if err == OK:
		multiplayer.multiplayer_peer = peer
		net_status = "HOSTING ON PORT %d (Peers: %d)" % [DEFAULT_PORT, remote_uaps.size()]
		multiverse_toast.emit("MULTIVERSE SERVER LIVE ON PORT %d! Friends can join via your IP." % DEFAULT_PORT)
	else:
		net_status = "Host failed (port %d busy)" % DEFAULT_PORT
	refresh_ui()

func _join_from_input() -> void:
	join_session(ip_edit.text.strip_edges())

func join_session(addr: String) -> void:
	if OS.has_feature("web"):
		net_status = "Web client: simulated coalitions active."
		refresh_ui(); return
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(addr if not addr.is_empty() else "127.0.0.1", DEFAULT_PORT)
	if err == OK:
		multiplayer.multiplayer_peer = peer
		net_status = "Connecting to %s:%d..." % [addr, DEFAULT_PORT]
	else:
		net_status = "Join error (%d)" % err
	refresh_ui()

func _on_peer_connected(id: int) -> void:
	_spawn_remote_uap(id)
	net_status = "CONNECTED PEERS: %d" % remote_uaps.size()
	multiverse_toast.emit("SOVEREIGN UAP PEER #%d ENTERED YOUR UNIVERSE!" % id)

func _on_peer_disconnected(id: int) -> void:
	if remote_uaps.has(id):
		if is_instance_valid(remote_uaps[id]["node"]):
			remote_uaps[id]["node"].queue_free()
		remote_uaps.erase(id)

func _on_connected_ok() -> void:
	net_status = "CONNECTED TO MULTIVERSE HOST!"
	multiverse_toast.emit("LINKED TO LIVE MULTIVERSE SESSION!")

func _on_connected_fail() -> void:
	net_status = "Connection failed — continuing in Multiverse Coalition mode."

func _spawn_remote_uap(id: int) -> void:
	if remote_uaps.has(id): return
	var n = Node3D.new(); add_child(n)
	var tor = TorusMesh.new(); tor.inner_radius = 1.8; tor.outer_radius = 2.2; tor.rings = 22; tor.ring_segments = 8
	var mat = StandardMaterial3D.new(); mat.albedo_color = Color(0.28, 0.96, 1.0); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true; mat.emission = Color(0.28, 0.96, 1.0); mat.emission_energy_multiplier = 7.0
	tor.material = mat
	var mi = MeshInstance3D.new(); mi.mesh = tor; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)
	var lbl = Label3D.new(); lbl.text = "PEER #%d" % id; lbl.position = Vector3(0, 4.2, 0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED; lbl.font_size = 76; lbl.pixel_size = 0.06
	n.add_child(lbl)
	remote_uaps[id] = {"node": n, "ring": mi, "lbl": lbl}

@rpc("any_peer", "unreliable")
func _rpc_sync_uap(pos: Vector3, planets_cnt: int, coal: String) -> void:
	var sid = multiplayer.get_remote_sender_id()
	if not remote_uaps.has(sid): _spawn_remote_uap(sid)
	var r = remote_uaps[sid]
	r["node"].global_position = r["node"].global_position.lerp(pos, 0.45)
	r["lbl"].text = "[%s] PEER #%d (%d Worlds)" % [coal, sid, planets_cnt]

func update_multiverse(delta: float, player_pos: Vector3) -> void:
	if not active: return
	aurora_root.rotate_y(delta * 0.012)
	for id in remote_uaps:
		remote_uaps[id]["ring"].rotate_x(delta * 2.4)
		remote_uaps[id]["ring"].rotate_y(delta * 1.8)

	# Broadcast local UAP position & empire scale to connected multiplayer peers
	if multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
		_sync_cd -= delta
		if _sync_cd <= 0.0:
			_sync_cd = 0.06
			_rpc_sync_uap.rpc(player_pos, empire_planets, player_coalition)
