extends Node3D

var characters = [
	{"name": "VANCE", "shirt": Color(0.88, 0.87, 0.84), "alt": Color(0.12, 0.72, 0.92)},
	{"name": "NADIA", "shirt": Color(0.92, 0.20, 0.58), "alt": Color(0.20, 0.85, 0.52)}
]
var active_char_idx := 0; var using_alt_outfit := false
var banked_cash := 500; var player_hp := 100.0; var ammo := 30; var max_ammo := 30; var reload_t := 0.0; var fire_cd := 0.0
var focus_active := false; var time_of_day := 14.5; var weather_mode := 0
var weather_names := ["CLEAR", "OVERCAST", "NEON RAIN"]
var sdfgi_on := false; var is_desktop := true
var input_mode := "PC"

var llm_endpoint := "http://127.0.0.1:9931/v1/chat/completions"
var llm_http: HTTPRequest; var llm_booter: LLMBooter = null; var active_npc: AINPC = null; var llm_busy := false
var npcs: Array[AINPC] = []
var crowd_mgr: CrowdManager = null
var wildlife_mgr: WildlifeManager = null
var audio_mgr: AudioManager = null
var hellfire_mgr: HellfireManager = null
var char_creator: CharacterCreatorUI = null
var max_hp := 100.0
var event_dir: EventDirector = null
var ots_cam: OTSCamera = null
var minimap_hud: MiniMapHUD = null
var crosshair: ColorRect = null
var ghost_mode := false

var lidar_mat: ShaderMaterial; var lidar_active := false; var lidar_radius := 0.0; var lidar_max := 160.0
var status_msg := "[FIRE/Space/J] Shoot (On-Foot & Drive-By) | [N] Time | [F3] Weather | [X/SCAN] LIDAR"
var msg_timer := 8.0

var player: CharacterBody3D; var player_rig: CharacterRig; var player_col: CollisionShape3D
var muzzle_light: OmniLight3D; var muzzle_t := 0.0
var vehicles: Array[SolisVehicle] = []; var active_veh: SolisVehicle = null
var streamer: ChunkStreamer = null; var landmarks: LandmarkLoader = null; var real_world_mode := false
var sun: DirectionalLight3D; var sky_mat: ProceduralSkyMaterial; var world_env: Environment; var rain: GPUParticles3D
var fallback_road_mat: StandardMaterial3D = null; var fallback_ground_mat: StandardMaterial3D = null
var tracers: Array[Dictionary] = []; var cam: Camera3D; var touch_hud: TouchHUD
var hud_stats: Label; var hud_heat: Label; var hud_prompt: Label; var hud_toast: Label
var chat_panel: PanelContainer; var chat_title: Label; var chat_log: RichTextLabel; var chat_input: LineEdit; var llm_url_input: LineEdit

func _ready() -> void:
	lidar_mat = ShaderMaterial.new(); lidar_mat.shader = load("res://shaders/lidar_pulse.gdshader")
	lidar_mat.set_shader_parameter("max_radius", lidar_max)
	llm_http = HTTPRequest.new(); llm_http.timeout = 25.0; llm_http.request_completed.connect(_on_llm_response); add_child(llm_http)
	llm_booter = LLMBooter.new(); add_child(llm_booter)
	llm_booter.status_changed.connect(func(st, live): _toast(st); if live and llm_url_input: llm_endpoint = llm_booter.endpoint; llm_url_input.text = llm_endpoint)

	var sp := {"car_pos": Vector3(-11.5, 0.9, 16), "car_yaw": PI, "player_pos": Vector3(-7.0, 1.15, 16)}
	streamer = ChunkStreamer.new()
	if streamer.load_active_city():
		real_world_mode = true; add_child(streamer)
		var refs = WorldBuilder.setup_nextgen_env(self)
		sun = refs["sun"]; sky_mat = refs["sky_mat"]; world_env = refs["env"]; rain = refs["rain"]; is_desktop = refs["is_desktop"]
		sp = streamer.get_safe_road_spawn(Vector3.ZERO); streamer.update_streaming(sp["player_pos"])
		status_msg = "REAL-WORLD: " + streamer.city_name.to_upper() + " | [FIRE] Shoot | [C/ACT] AI NPCs"
	else:
		streamer.queue_free(); streamer = null
		var refs = WorldBuilder.build_fallback_city(self)
		sun = refs["sun"]; sky_mat = refs["sky_mat"]; world_env = refs["env"]; rain = refs["rain"]; is_desktop = refs["is_desktop"]
		fallback_road_mat = refs["road_mat"]; fallback_ground_mat = refs["ground_mat"]

	landmarks = LandmarkLoader.new(); add_child(landmarks)
	landmarks.load_landmarks(real_world_mode and streamer != null, streamer.origin_lat if streamer else 0.0, streamer.origin_lon if streamer else 0.0)
	_build_player(sp["player_pos"]); _spawn_vehicles(sp["car_pos"], sp["car_yaw"]); _spawn_ai_npcs(sp["player_pos"])
	crowd_mgr = CrowdManager.new(); add_child(crowd_mgr); crowd_mgr.setup(180 if is_desktop else 90)
	ots_cam = OTSCamera.new(); add_child(ots_cam); cam = ots_cam.cam
	wildlife_mgr = WildlifeManager.new(); add_child(wildlife_mgr); wildlife_mgr.setup(streamer.biome if streamer else "florida_coast", is_desktop)
	event_dir = EventDirector.new(); add_child(event_dir)
	event_dir.event_toast.connect(_toast)
	event_dir.event_reward.connect(func(c, m): banked_cash += c; if audio_mgr: audio_mgr.play_chime(); _toast(m))
	audio_mgr = AudioManager.new(); add_child(audio_mgr)
	hellfire_mgr = HellfireManager.new(); add_child(hellfire_mgr); hellfire_mgr.setup(is_desktop)
	hellfire_mgr.demon_killed.connect(func(c, m): banked_cash += c; if audio_mgr: audio_mgr.play_chime(); _toast(m))
	hellfire_mgr.player_hit.connect(func(d): player_hp = maxf(10.0, player_hp - d); _toast("DEMON HIT! HP: %d%%" % int(player_hp)))
	hellfire_mgr.pickup_collected.connect(func(k, m): if k == "soul": player_hp = minf(max_hp, player_hp + 35.0); banked_cash += 350; if audio_mgr: audio_mgr.play_chime(); _toast(m))
	hellfire_mgr.milestone_unlocked.connect(func(tier, m): if tier == 2: max_hp = 150.0; player_hp = 150.0; player_rig.set_infernal_aura(true); if audio_mgr: audio_mgr.play_chime(); _toast(m))
	_build_hud()
	var init_m = "TOUCH" if (not is_desktop) else ("PS5" if not Input.get_connected_joypads().is_empty() else "PC")
	_set_input_mode(init_m)

func _build_player(pos: Vector3) -> void:
	player = CharacterBody3D.new(); player.position = pos; player.collision_layer = 4; player.collision_mask = 3
	player_rig = CharacterRig.new(); player_rig.setup(characters[0]["shirt"], Color(0.14, 0.16, 0.22), true, "", Color(0.12, 0.12, 0.14), true); player.add_child(player_rig)
	muzzle_light = OmniLight3D.new(); muzzle_light.position = Vector3(0.3, 0.45, 0.7)
	muzzle_light.light_color = Color(1.0, 0.82, 0.35); muzzle_light.light_energy = 6.0; muzzle_light.omni_range = 8.0; muzzle_light.visible = false
	player_rig.add_child(muzzle_light)
	player_col = CollisionShape3D.new(); var cs = CapsuleShape3D.new(); cs.radius = 0.36; cs.height = 1.72; player_col.shape = cs
	player.add_child(player_col); add_child(player)

func _spawn_vehicles(car_pos: Vector3, car_yaw: float) -> void:
	var v1 = SolisVehicle.new(); v1.position = car_pos; v1.rotation.y = car_yaw
	v1.setup("Solis GT", Color(0.92, 0.14, 0.36), 120.0, false); v1.collision_mask = 3; add_child(v1); vehicles.append(v1)

func _spawn_ai_npcs(base_pos: Vector3) -> void:
	var specs = [
		["Marcus", "Street Mechanic", "You are Marcus, an underground mechanic who tunes sports cars.", Color(0.88, 0.55, 0.16), Vector3(5.5, 0, -3.0)],
		["Elena", "Local Reporter", "You are Elena, a local journalist tracking city rumors and street racing.", Color(0.22, 0.78, 0.62), Vector3(-5.0, 0, -6.5)],
		["Dante", "Fixer", "You are Dante, a calm fixer who hands out courier jobs.", Color(0.65, 0.28, 0.85), Vector3(8.0, 0, 6.0)]
	]
	for idx in range(specs.size()):
		var s = specs[idx]
		var npc = AINPC.new(); var p = base_pos + s[4]
		if real_world_mode and streamer: p = streamer.get_safe_road_spawn(p)["player_pos"]
		npc.position = p; npc.setup(s[0], s[1], s[2], s[3], "res://assets/avatars/npcs/npc_%d.glb" % idx); add_child(npc); npcs.append(npc)

func _build_hud() -> void:
	var layer = CanvasLayer.new(); add_child(layer)
	var sb = StyleBoxFlat.new(); sb.bg_color = Color(0.04, 0.06, 0.12, 0.82); sb.border_color = Color(0.25, 0.85, 0.98, 0.7)
	sb.set_border_width_all(2); sb.set_corner_radius_all(10); sb.content_margin_left = 14; sb.content_margin_right = 14; sb.content_margin_top = 8; sb.content_margin_bottom = 8
	var panel = PanelContainer.new(); panel.position = Vector2(16, 14); panel.add_theme_stylebox_override("panel", sb); layer.add_child(panel)
	var vb = VBoxContainer.new(); panel.add_child(vb)
	hud_stats = Label.new(); hud_stats.add_theme_font_size_override("font_size", 16); vb.add_child(hud_stats)
	hud_heat = Label.new(); hud_heat.add_theme_font_size_override("font_size", 14); hud_heat.modulate = Color(0.45, 0.92, 1.0); vb.add_child(hud_heat)
	hud_prompt = Label.new(); hud_prompt.set_anchors_preset(Control.PRESET_CENTER_TOP); hud_prompt.position = Vector2(-280, 18); hud_prompt.custom_minimum_size = Vector2(560, 34); hud_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; hud_prompt.add_theme_font_size_override("font_size", 18); hud_prompt.modulate = Color(0.35, 1.0, 0.72); layer.add_child(hud_prompt)
	hud_toast = Label.new(); hud_toast.set_anchors_preset(Control.PRESET_CENTER_TOP); hud_toast.position = Vector2(-380, 52); hud_toast.custom_minimum_size = Vector2(760, 32); hud_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; hud_toast.add_theme_font_size_override("font_size", 15); hud_toast.modulate = Color(1.0, 0.94, 0.62); layer.add_child(hud_toast)
	minimap_hud = MiniMapHUD.new(); minimap_hud.host = self; layer.add_child(minimap_hud)
	crosshair = ColorRect.new(); crosshair.size = Vector2(6, 6); crosshair.color = Color(0.25, 0.98, 1.0, 0.92)
	crosshair.set_anchors_preset(Control.PRESET_CENTER); crosshair.offset_left = -3; crosshair.offset_top = -3; crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE; layer.add_child(crosshair)
	touch_hud = TouchHUD.new(); touch_hud.on_action = Callable(self, "_on_touch_action"); layer.add_child(touch_hud)
	char_creator = CharacterCreatorUI.new(); layer.add_child(char_creator)
	char_creator.profile_updated.connect(func(prof): characters[0]["name"] = prof["name"]; player_rig.apply_profile(prof))
	char_creator.closed.connect(func(): if input_mode == "PC": Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED))
	characters[0]["name"] = char_creator.profile["name"]; player_rig.apply_profile(char_creator.profile)

	chat_panel = PanelContainer.new(); chat_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	chat_panel.offset_left = -310; chat_panel.offset_right = 310; chat_panel.offset_top = -270; chat_panel.offset_bottom = -20
	chat_panel.add_theme_stylebox_override("panel", sb); chat_panel.visible = false; layer.add_child(chat_panel)
	var cvb = VBoxContainer.new(); chat_panel.add_child(cvb)
	var top = HBoxContainer.new(); cvb.add_child(top)
	chat_title = Label.new(); chat_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(chat_title)
	var cbtn = Button.new(); cbtn.text = "Close [ESC]"; cbtn.pressed.connect(_close_chat); top.add_child(cbtn)
	var urow = HBoxContainer.new(); cvb.add_child(urow)
	var ul = Label.new(); ul.text = "LLM: "; urow.add_child(ul)
	llm_url_input = LineEdit.new(); llm_url_input.text = llm_endpoint; llm_url_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL; urow.add_child(llm_url_input)
	chat_log = RichTextLabel.new(); chat_log.custom_minimum_size = Vector2(0, 125); chat_log.scroll_following = true; cvb.add_child(chat_log)
	var irow = HBoxContainer.new(); cvb.add_child(irow)
	chat_input = LineEdit.new(); chat_input.placeholder_text = "Type to speak with NPC..."; chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL; chat_input.text_submitted.connect(_send_npc_message); irow.add_child(chat_input)
	var sbtn = Button.new(); sbtn.text = "Send"; sbtn.pressed.connect(func(): _send_npc_message(chat_input.text)); irow.add_child(sbtn)

func _fire_weapon() -> void:
	if reload_t > 0.0 or fire_cd > 0.0: return
	if ammo <= 0:
		reload_t = 1.1; _toast("Reloading sidearm..."); return
	var is_over = (hellfire_mgr != null and hellfire_mgr.overdrive_timer > 0.0)
	if not is_over: ammo -= 1
	fire_cd = 0.08 if is_over else (0.12 if focus_active else 0.17)

	var orig: Vector3
	var dir: Vector3
	var excl: Array[RID] = [player.get_rid()]
	if active_veh != null:
		# Drive-by shot from vehicle forward direction
		orig = active_veh.global_position + Vector3(0, 1.15, 0) + active_veh.global_transform.basis.z * 2.5
		dir = active_veh.global_transform.basis.z.normalized()
		excl.append(active_veh.get_rid())
	else:
		muzzle_light.visible = true; muzzle_t = 0.06
		orig = player.global_position + Vector3(0, 1.35, 0) + player_rig.global_transform.basis.z * 0.55
		var vp_c = get_viewport().get_visible_rect().size * 0.5
		var r_orig = cam.project_ray_origin(vp_c)
		var r_dir = cam.project_ray_normal(vp_c)
		var aim_pt = r_orig + r_dir * 70.0
		var aq = PhysicsRayQueryParameters3D.create(r_orig, aim_pt); aq.exclude = excl
		var ah = get_world_3d().direct_space_state.intersect_ray(aq)
		if ah: aim_pt = ah["position"]
		dir = (aim_pt - orig).normalized()

	var end_p = orig + dir * 65.0
	var q = PhysicsRayQueryParameters3D.create(orig, end_p); q.exclude = excl
	var hit = get_world_3d().direct_space_state.intersect_ray(q)
	if hit:
		end_p = hit["position"]
		if hit["collider"] is SolisVehicle:
			(hit["collider"] as SolisVehicle).take_damage(24.0)
			_toast("Hit vehicle!")
		elif hellfire_mgr and hellfire_mgr.try_hit_demon(hit["collider"], (75.0 if hellfire_mgr.unlocked_brimstone else (56.0 if hellfire_mgr.unlocked_incendiary else 32.0)), end_p):
			pass
		# Impact spark flash
		var sp = MeshInstance3D.new(); var sm = SphereMesh.new(); sm.radius = 0.14
		var smat = StandardMaterial3D.new(); smat.albedo_color = Color(1, 0.9, 0.4); smat.emission_enabled = true; smat.emission = Color(1, 0.75, 0.2); smat.emission_energy_multiplier = 6.0
		sm.material = smat; sp.mesh = sm; add_child(sp); sp.global_position = end_p
		tracers.append({"m": sp, "t": 0.08})

	var mi = MeshInstance3D.new(); var bm = BoxMesh.new(); bm.size = Vector3(0.06, 0.06, maxf(0.2, orig.distance_to(end_p)))
	var mat = StandardMaterial3D.new(); var col = Color(1.0, 0.25, 0.04) if (hellfire_mgr and hellfire_mgr.unlocked_incendiary) else (Color(0.25, 0.95, 1.0) if focus_active else Color(1.0, 0.85, 0.3))
	mat.albedo_color = col; mat.emission_enabled = true; mat.emission = col; mat.emission_energy_multiplier = 5.0
	bm.material = mat; mi.mesh = bm; add_child(mi); mi.global_position = (orig + end_p) * 0.5; mi.look_at(end_p, Vector3.UP)
	tracers.append({"m": mi, "t": 0.10})
	if crowd_mgr: crowd_mgr.panic_near(orig, 26.0)
	if wildlife_mgr: wildlife_mgr.scatter_near(orig, 32.0)
	if audio_mgr: audio_mgr.play_gunshot()
	if ammo == 0: reload_t = 1.1; _toast("Reloading sidearm...")

func _find_nearest_npc(max_d: float) -> AINPC:
	var best: AINPC = null; var bd := max_d
	for n in npcs:
		var d = player.global_position.distance_to(n.global_position)
		if d < bd: bd = d; best = n
	return best

func _open_chat(npc: AINPC) -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	active_npc = npc; active_npc.is_talking = true
	chat_title.text = "%s — %s (llama.cpp)" % [npc.npc_name, npc.npc_role]
	chat_log.text = "[color=#70e8ff]%s:[/color] Hey—what's the word out here?\n" % npc.npc_name
	chat_panel.visible = true; chat_input.grab_focus()

func _close_chat() -> void:
	if active_npc: active_npc.is_talking = false
	active_npc = null; chat_panel.visible = false; chat_input.release_focus()

func _send_npc_message(msg: String) -> void:
	msg = msg.strip_edges()
	if msg.is_empty() or active_npc == null or llm_busy: return
	chat_input.text = ""; chat_log.append_text("[color=#ffe066]You:[/color] %s\n" % msg)
	active_npc.history.append({"role": "user", "content": msg})
	var loc = streamer.get_gps_string(_ppos()) if (real_world_mode and streamer) else "Solis Coast"
	var hr = int(time_of_day); var mn = int((time_of_day - hr) * 60.0)
	var ctx = "Location: %s | Time: %02d:%02d | Weather: %s" % [loc, hr, mn, weather_names[weather_mode]]
	var payload = JSON.stringify({"model": "local-model", "messages": active_npc.build_messages(msg, ctx), "temperature": 0.75, "max_tokens": 110})
	llm_busy = true; llm_endpoint = llm_url_input.text.strip_edges()
	chat_log.append_text("[color=#999999](%s is thinking...)[/color]\n" % active_npc.npc_name)
	if llm_http.request(llm_endpoint, ["Content-Type: application/json"], HTTPClient.METHOD_POST, payload) != OK:
		llm_busy = false; chat_log.append_text("[color=#ff6666]Cannot reach llama-server at %s[/color]\n" % llm_endpoint)

func _on_llm_response(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	llm_busy = false
	if active_npc == null: return
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		var city_lbl = streamer.city_name if streamer else "Solis Coast"
		var w_lbl = "hellfire tearing through " + city_lbl if (hellfire_mgr and hellfire_mgr.active) else (weather_names[weather_mode].to_lower() + " skies over " + city_lbl)
		var fb = "Keeping my head down with these %s—stay sharp out there." % w_lbl
		chat_log.append_text("[color=#70e8ff]%s:[/color] %s\n" % [active_npc.npc_name, fb]); return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("choices") and parsed["choices"].size() > 0:
		var reply = str(parsed["choices"][0]["message"]["content"]).strip_edges()
		active_npc.history.append({"role": "assistant", "content": reply})
		chat_log.append_text("[color=#70e8ff]%s:[/color] %s\n" % [active_npc.npc_name, reply])

func _on_touch_action(aid: String) -> void:
	if chat_panel.visible: return
	match aid:
		"car": _toggle_vehicle()
		"swap": _swap_character()
		"scan": _trigger_lidar_pulse()
		"ghost": _toggle_ghost()
		"hell": _toggle_hellfire()
		"cycle_mode": _cycle_input_mode()
		"act":
			var n = _find_nearest_npc(5.5)
			if event_dir and event_dir.try_interact(_ppos(), streamer): pass
			elif active_veh == null and n != null: _open_chat(n)
			else: _cycle_weather()
		"trunk":
			using_alt_outfit = not using_alt_outfit
			var c = characters[active_char_idx]; player_rig.set_shirt_color(c["alt"] if using_alt_outfit else c["shirt"])

func _toast(t: String) -> void: status_msg = t; msg_timer = 5.0
func _ppos() -> Vector3: return active_veh.global_position if active_veh else player.global_position

func _trigger_lidar_pulse() -> void:
	lidar_active = true; lidar_radius = 1.0
	lidar_mat.set_shader_parameter("pulse_origin", _ppos()); lidar_mat.set_shader_parameter("pulse_radius", lidar_radius)
	if streamer: streamer.set_lidar_overlay(lidar_mat)
	if fallback_road_mat: fallback_road_mat.next_pass = lidar_mat
	if fallback_ground_mat: fallback_ground_mat.next_pass = lidar_mat
	_toast("LIDAR Topographic Pulse Deployed!")

func _cycle_weather() -> void:
	weather_mode = (weather_mode + 1) % 3
	var wet = 1.0 if weather_mode == 2 else (0.35 if weather_mode == 1 else 0.0)
	rain.emitting = (weather_mode == 2)
	world_env.volumetric_fog_density = 0.0055 if weather_mode == 2 else (0.0038 if weather_mode == 1 else 0.0020)
	if streamer: streamer.set_wetness(wet)
	if fallback_road_mat: fallback_road_mat.roughness = lerpf(0.65, 0.10, wet)
	_toast("Weather: " + weather_names[weather_mode])

func _swap_character() -> void:
	active_char_idx = (active_char_idx + 1) % characters.size()
	using_alt_outfit = false; player_rig.set_shirt_color(characters[active_char_idx]["shirt"])
	_toast("Switched to " + characters[active_char_idx]["name"])

func _pad_id() -> int:
	var pads = Input.get_connected_joypads()
	return pads[0] if not pads.is_empty() else -1

func _pad_stick(dev: int, ax_x: JoyAxis, ax_y: JoyAxis, dz := 0.16) -> Vector2:
	if dev < 0: return Vector2.ZERO
	var v = Vector2(Input.get_joy_axis(dev, ax_x), Input.get_joy_axis(dev, ax_y))
	return Vector2.ZERO if v.length() < dz else v

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		if chat_panel.visible:
			if event.button_index == JOY_BUTTON_B: _close_chat()
			return
		match event.button_index:
			JOY_BUTTON_Y: _toggle_vehicle()
			JOY_BUTTON_A:
				var n = _find_nearest_npc(5.5)
				if event_dir and event_dir.try_interact(_ppos(), streamer): pass
				elif active_veh == null and n != null: _open_chat(n)
			JOY_BUTTON_X:
				if ammo < max_ammo and reload_t <= 0.0: reload_t = 1.1; _toast("Reloading sidearm...")
			JOY_BUTTON_RIGHT_STICK:
				if ots_cam: ots_cam.swap_shoulder()
			JOY_BUTTON_DPAD_UP: _trigger_lidar_pulse()
			JOY_BUTTON_DPAD_RIGHT: _cycle_weather()
			JOY_BUTTON_DPAD_DOWN: _toggle_hellfire()
			JOY_BUTTON_DPAD_LEFT: _toggle_ghost()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if input_mode == "PC" and not chat_panel.visible and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			return
	if event is InputEventKey and event.pressed and not event.echo:
		if chat_panel.visible:
			if event.keycode == KEY_ESCAPE: _close_chat()
			return
		match event.keycode:
			KEY_C:
				var n = _find_nearest_npc(5.5)
				if active_veh == null and n != null: _open_chat(n)
			KEY_F1: _cycle_input_mode()
			KEY_ESCAPE:
				if input_mode == "PC" and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
					Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
					_toast("Mouse Unlocked (Click viewport to lock aim, or click top-right pills)")
			KEY_F2:
				if is_desktop: sdfgi_on = not sdfgi_on; world_env.sdfgi_enabled = sdfgi_on; _toast("SDFGI: " + ("ON" if sdfgi_on else "OFF"))
			KEY_F3: _cycle_weather()
			KEY_F4: _toggle_hellfire()
			KEY_X: _trigger_lidar_pulse()
			KEY_V: _toggle_ghost()
			KEY_B:
				if audio_mgr: _toast("AUDIO: " + ("MUTED" if audio_mgr.toggle_mute() else "ON"))
			KEY_H: ots_cam.swap_shoulder()
			KEY_F:
				if event_dir: event_dir.try_interact(_ppos(), streamer)
			KEY_R:
				if ammo < max_ammo and reload_t <= 0.0: reload_t = 1.1; _toast("Reloading sidearm...")
			KEY_U:
				if real_world_mode and streamer:
					var sp = streamer.get_safe_road_spawn(_ppos())
					if active_veh: active_veh.global_position = sp["car_pos"]; active_veh.linear_velocity = Vector3.ZERO
					else: player.global_position = sp["player_pos"]
					_toast("Relocated to nearest open street.")
			KEY_E: _toggle_vehicle()
			KEY_TAB: _swap_character()
			KEY_K: _toggle_creator()
			KEY_M: _cycle_region()

func _find_nearest_car(max_d: float) -> SolisVehicle:
	var best: SolisVehicle = null; var bd := max_d
	for v in vehicles:
		if v.hp <= 0.0: continue
		var d = player.global_position.distance_to(v.global_position)
		if d < bd: bd = d; best = v
	return best

func _toggle_vehicle() -> void:
	if active_veh != null:
		active_veh.is_player_controlled = false; active_veh.engine_force = 0.0; active_veh.brake = 20.0
		player.global_position = active_veh.global_position + active_veh.global_transform.basis.x * 2.5 + Vector3(0, 0.6, 0)
		active_veh = null; player.visible = true; player_col.disabled = false; return
	var v = _find_nearest_car(6.5)
	if v == null: return
	v.wake_for_player(); active_veh = v; player.visible = false; player_col.disabled = true

func _update_lighting(delta: float) -> void:
	if hellfire_mgr and hellfire_mgr.active: return
	var rate = 3.5 if (not chat_panel.visible and Input.is_key_pressed(KEY_N)) else 0.015
	time_of_day = fmod(time_of_day + delta * rate, 24.0)
	var day_f = clampf(sin((time_of_day - 6.0) / 12.0 * PI), 0.0, 1.0)
	var weather_dim = 0.78 if weather_mode > 0 else 1.0

	if day_f > 0.05:
		sun.rotation_degrees.x = -((time_of_day - 6.0) / 12.0) * 180.0
		sun.light_color = Color(1.0, 0.76, 0.56).lerp(Color(1.0, 0.96, 0.90), day_f)
		sun.light_energy = lerpf(0.75, 1.85, day_f) * weather_dim
	else:
		# Bright cool moonlight at night so buildings & streets stay clearly visible
		sun.rotation_degrees.x = -42.0
		sun.light_color = Color(0.55, 0.70, 0.95)
		sun.light_energy = 0.75 * weather_dim

	world_env.ambient_light_energy = lerpf(0.95, 1.15, day_f)
	sky_mat.sky_top_color = Color(0.10, 0.14, 0.28).lerp(Color(0.18, 0.48, 0.88), day_f * weather_dim)
	sky_mat.sky_horizon_color = Color(0.24, 0.22, 0.38).lerp(Color(0.88, 0.72, 0.64), day_f * weather_dim)
	sky_mat.ground_horizon_color = Color(0.18, 0.20, 0.30).lerp(Color(0.52, 0.54, 0.58), day_f)

func _physics_process(delta: float) -> void:
	_update_lighting(delta)
	var ppos = _ppos()
	if real_world_mode and streamer: streamer.update_streaming(ppos)
	if rain.emitting: rain.global_position = Vector3(ppos.x, ppos.y + 18.0, ppos.z)
	for n in npcs: n.update_ai(delta, ppos)
	if crowd_mgr: crowd_mgr.update_crowd(delta, ppos, streamer)
	if wildlife_mgr: wildlife_mgr.update_wildlife(delta, ppos)
	if hellfire_mgr: hellfire_mgr.update_hellfire(delta, ppos)
	if streamer and streamer.water_mat:
		streamer.water_mat.set_shader_parameter("sun_dir", -sun.global_transform.basis.z)
		streamer.water_mat.set_shader_parameter("sky_reflect_color", sky_mat.sky_horizon_color)
		streamer.water_mat.set_shader_parameter("hell_mix", 1.0 if (hellfire_mgr and hellfire_mgr.active) else 0.0)
	if audio_mgr:
		var v_spd = active_veh.linear_velocity.length() if active_veh else 0.0
		var w_spd = Vector2(player.velocity.x, player.velocity.z).length() if active_veh == null else 0.0
		audio_mgr.update_audio(delta, active_veh != null, v_spd, w_spd, weather_mode == 2, time_of_day)
	if event_dir:
		var fwd = active_veh.global_transform.basis.z if active_veh else -cam.global_transform.basis.z
		event_dir.update_director(delta, ppos, fwd, streamer)
	if lidar_active:
		lidar_radius += delta * 58.0; lidar_mat.set_shader_parameter("pulse_radius", lidar_radius)
		if lidar_radius >= lidar_max:
			lidar_active = false
			if streamer: streamer.set_lidar_overlay(null)
			if fallback_road_mat: fallback_road_mat.next_pass = null
			if fallback_ground_mat: fallback_ground_mat.next_pass = null

	if muzzle_t > 0.0:
		muzzle_t -= delta
		if muzzle_t <= 0.0: muzzle_light.visible = false
	var u_delta = delta / maxf(Engine.time_scale, 0.08)
	if fire_cd > 0.0: fire_cd -= u_delta
	if reload_t > 0.0:
		reload_t -= u_delta
		if reload_t <= 0.0: ammo = max_ammo; _toast("Reloaded (30/30).")
	for i in range(tracers.size() - 1, -1, -1):
		tracers[i]["t"] -= delta
		if tracers[i]["t"] <= 0.0: tracers[i]["m"].queue_free(); tracers.remove_at(i)

	var pad = _pad_id()
	var pad_l2 = Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_LEFT) if pad >= 0 else 0.0
	var pad_r2 = Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_RIGHT) if pad >= 0 else 0.0
	var pad_ls = _pad_stick(pad, JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)
	var pad_aim = (pad_l2 > 0.22) or (pad >= 0 and Input.is_joy_button_pressed(pad, JOY_BUTTON_LEFT_SHOULDER))
	var pad_fire = (pad_r2 > 0.25) or (pad >= 0 and Input.is_joy_button_pressed(pad, JOY_BUTTON_RIGHT_SHOULDER))
	var pad_sprint = pad >= 0 and Input.is_joy_button_pressed(pad, JOY_BUTTON_LEFT_STICK)

	if not chat_panel.visible:
		focus_active = Input.is_physical_key_pressed(KEY_Q) or Input.is_physical_key_pressed(KEY_ALT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_XBUTTON1) or touch_hud.hold_focus or (active_veh == null and pad_l2 > 0.75)
		Engine.time_scale = lerpf(Engine.time_scale, 0.35 if focus_active else 1.0, 0.2)
		var pc_fire = (input_mode == "PC") and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and (Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT))
		var want_fire = pc_fire or touch_hud.hold_fire or Input.is_key_pressed(KEY_J) or (active_veh == null and (Input.is_key_pressed(KEY_SPACE) or (input_mode == "PS5" and pad_fire)))
		if want_fire: _fire_weapon()

		if active_veh != null:
			var thr = clampf(-touch_hud.joy_vec.y + pad_r2 - pad_l2 + (1.0 if Input.is_key_pressed(KEY_W) else 0.0) - (1.0 if Input.is_key_pressed(KEY_S) else 0.0), -1.0, 1.0)
			var st = clampf(-touch_hud.joy_vec.x - pad_ls.x + (1.0 if Input.is_key_pressed(KEY_A) else 0.0) - (1.0 if Input.is_key_pressed(KEY_D) else 0.0), -1.0, 1.0)
			var ebrake = Input.is_key_pressed(KEY_SPACE) or touch_hud.hold_brake or (pad >= 0 and Input.is_joy_button_pressed(pad, JOY_BUTTON_B))
			active_veh.apply_drive_input(thr, st, ebrake, delta)
		else:
			var raw_d = Vector2(touch_hud.joy_vec.x + pad_ls.x, touch_hud.joy_vec.y + pad_ls.y)
			if Input.is_physical_key_pressed(KEY_W): raw_d.y -= 1.0
			if Input.is_physical_key_pressed(KEY_S): raw_d.y += 1.0
			if Input.is_physical_key_pressed(KEY_A): raw_d.x -= 1.0
			if Input.is_physical_key_pressed(KEY_D): raw_d.x += 1.0
			if raw_d.length() > 1.0: raw_d = raw_d.normalized()
			# Camera-relative movement so strafing & right-stick aiming work together
			var cam_f = -ots_cam.yaw_pivot.global_transform.basis.z; cam_f.y = 0; cam_f = cam_f.normalized()
			var cam_r =  ots_cam.yaw_pivot.global_transform.basis.x; cam_r.y = 0; cam_r = cam_r.normalized()
			var d = cam_r * raw_d.x + cam_f * (-raw_d.y)
			var sp = Input.is_physical_key_pressed(KEY_SHIFT) or touch_hud.hold_brake or pad_sprint
			var hold_aim = (input_mode == "PS5" and pad_aim) or (input_mode == "PC" and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)) or touch_hud.hold_focus
			var is_ads = hold_aim or want_fire
			var ov_m = 1.45 if (hellfire_mgr and hellfire_mgr.overdrive_timer > 0.0) else 1.0
			var focus_comp = 1.65 if focus_active else 1.0
			var move_spd = (6.2 if hold_aim else (11.5 if sp else 7.8)) * ov_m * focus_comp
			player.velocity.x = d.x * move_spd; player.velocity.z = d.z * move_spd
			player.velocity.y = 0 if player.is_on_floor() else player.velocity.y - 20.0 * delta
			player.move_and_slide()
			if is_ads:
				player_rig.rotation.y = lerp_angle(player_rig.rotation.y, atan2(cam_f.x, cam_f.z), clampf(delta * 18.0, 0.0, 1.0))
			elif d.length() > 0.1:
				player_rig.rotation.y = lerp_angle(player_rig.rotation.y, atan2(d.x, d.z), clampf(delta * 12.0, 0.0, 1.0))
			player_rig.animate(Vector2(player.velocity.x, player.velocity.z).length(), sp and not is_ads, is_ads, delta)
	else:
		Engine.time_scale = 1.0; player_rig.animate(0.0, false, false, delta)

	var aiming_now = (not chat_panel.visible) and (active_veh == null) and ((input_mode == "PS5" and (pad_aim or pad_fire)) or touch_hud.hold_fire or touch_hud.hold_focus or (input_mode == "PC" and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)))
	ots_cam.update_cam(delta, active_veh if active_veh else player, active_veh != null, aiming_now)
	if crosshair:
		var show_xh = (not chat_panel.visible) and (active_veh == null) and (aiming_now or (input_mode == "PC" and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED))
		crosshair.visible = show_xh
		crosshair.color = Color(1.0, 0.35, 0.12, 0.95) if aiming_now else Color(0.25, 0.98, 1.0, 0.85)
	if minimap_hud: minimap_hud.queue_redraw()

	if msg_timer > 0.0: msg_timer -= delta
	var hr = int(time_of_day); var mn = int((time_of_day - hr) * 60.0)
	var ammo_s = "RLD" if reload_t > 0.0 else ("%d/%d" % [ammo, max_ammo])
	var vstr = (" | %s %d MPH" % [active_veh.vehicle_name, int(active_veh.linear_velocity.length() * 2.237)]) if active_veh else ""
	hud_stats.text = "%s | $%d | %02d:%02d | %s | Ammo:%s | %d FPS%s" % [characters[active_char_idx]["name"], banked_cash, hr, mn, weather_names[weather_mode], ammo_s, Engine.get_frames_per_second(), vstr]
	hud_heat.text = ("GPS: " + streamer.get_gps_string(ppos)) if real_world_mode else "SOLIS COAST NEXT-GEN"
	hud_toast.text = status_msg if msg_timer > 0.0 else ""
	var near_npc = _find_nearest_npc(5.5) if active_veh == null else null
	if event_dir and not event_dir.active_event.is_empty() and ppos.distance_to(event_dir.active_event["pos"]) < 12.0: hud_prompt.text = event_dir.active_event["prompt"]
	elif near_npc != null and not chat_panel.visible: hud_prompt.text = "[C / ACT] Talk to %s (%s)" % [near_npc.npc_name, near_npc.npc_role]
	elif active_veh == null and _find_nearest_car(6.5) != null: hud_prompt.text = "[CAR / E] Drive Vehicle  •  [FIRE] Shoot  •  [X / SCAN] LIDAR"
	else: hud_prompt.text = ""


func _cycle_region() -> void:
	if not real_world_mode or streamer == null:
		_toast("Download cities with osm_city_builder.py to fast-travel."); return
	var regs = streamer.list_regions()
	if regs.size() < 2:
		_toast("Only 1 city installed. Run osm_city_builder.py to add more!"); return
	var cur_i := 0
	for i in range(regs.size()):
		if regs[i]["slug"] == streamer.city_slug: cur_i = i; break
	var nxt = regs[(cur_i + 1) % regs.size()]
	if streamer.load_region(nxt["slug"]):
		var sp = streamer.get_safe_road_spawn(Vector3.ZERO)
		streamer.update_streaming(sp["player_pos"])
		if active_veh: _toggle_vehicle()
		player.global_position = sp["player_pos"]
		if not vehicles.is_empty():
			vehicles[0].global_position = sp["car_pos"]
			vehicles[0].rotation.y = sp["car_yaw"]
			vehicles[0].linear_velocity = Vector3.ZERO
		for idx in range(npcs.size()):
			npcs[idx].global_position = streamer.get_safe_road_spawn(sp["player_pos"] + Vector3(6.0 * (idx + 1), 0, -4.0))["player_pos"]
		_toast("FAST TRAVELED TO " + nxt["name"].to_upper() + " [" + nxt["biome"].to_upper() + "]!")

func _toggle_ghost() -> void:
	ghost_mode = not ghost_mode
	var mask = 1 if ghost_mode else 3
	player.collision_mask = mask
	for v in vehicles: v.collision_mask = mask
	if touch_hud: touch_hud.ghost_enabled = ghost_mode; touch_hud.queue_redraw()
	_toast("GHOST / NOCLIP: " + ("ON (Phase through buildings safely!)" if ghost_mode else "OFF (Solid collisions restored)"))

func _toggle_hellfire() -> void:
	if hellfire_mgr == null: return
	var nxt = not hellfire_mgr.active
	hellfire_mgr.set_active(nxt, world_env, sky_mat, sun, _ppos())
	if touch_hud: touch_hud.hell_enabled = nxt; touch_hud.queue_redraw()
	_toast("HELLFIRE RIFT OPENED! Hold Right-Click / FOCUS & FIRE to fight demons!" if nxt else "Hellfire Rift Closed — returning to normal world.")

func _cycle_input_mode() -> void:
	var order = ["PC", "PS5", "TOUCH"]
	var nxt = order[(order.find(input_mode) + 1) % order.size()]
	_set_input_mode(nxt)

func _set_input_mode(mode: String) -> void:
	input_mode = mode
	if touch_hud: touch_hud.set_input_mode(mode)
	if ots_cam: ots_cam.input_mode = mode
	if mode == "PC" and not chat_panel.visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		_toast("MODE: PC (Mouse Aim | LMB Fire | RMB ADS | ESC Unlock Cursor)")
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_toast("MODE: PS5 Controller (Right-Stick Aim | L2 ADS | R2 Fire)" if mode == "PS5" else "MODE: TOUCH (On-Screen Stick & Buttons)")

func _toggle_creator() -> void:
	if char_creator == null: return
	char_creator.visible = not char_creator.visible
	if char_creator.visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_toast("CHARACTER CREATOR OPEN — Customize your hero live!")
	elif input_mode == "PC":
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
