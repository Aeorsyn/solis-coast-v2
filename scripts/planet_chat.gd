extends CanvasLayer
class_name PlanetChat

const LLAMA_URL := "http://127.0.0.1:8080/v1/chat/completions"

var panel: PanelContainer
var title_lbl: Label
var meta_lbl: Label
var log_rtl: RichTextLabel
var input_edit: LineEdit
var status_lbl: Label
var http: HTTPRequest

var active_planet: Dictionary = {}
var history_msgs: Array[Dictionary] = []
var busy := false

signal discourse_impact(planet_name: String, d_tech: float, d_faith: float, d_stab: float, note: String)
signal closed()

func _ready() -> void:
	http = HTTPRequest.new()
	http.timeout = 14.0
	add_child(http)
	http.request_completed.connect(_on_http_done)
	_build_ui()

func _build_ui() -> void:
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -360; panel.offset_right = 360; panel.offset_top = -255; panel.offset_bottom = 255
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.11, 0.95); sb.border_color = Color(1.0, 0.84, 0.34, 0.92)
	sb.set_border_width_all(2); sb.set_corner_radius_all(14)
	sb.content_margin_left = 16; sb.content_margin_right = 16; sb.content_margin_top = 14; sb.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", sb)
	panel.visible = false
	add_child(panel)

	var vb = VBoxContainer.new(); vb.add_theme_constant_override("separation", 8); panel.add_child(vb)

	var top_h = HBoxContainer.new(); vb.add_child(top_h)
	title_lbl = Label.new(); title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 18); title_lbl.modulate = Color(1.0, 0.88, 0.38)
	top_h.add_child(title_lbl)
	var x_btn = Button.new(); x_btn.text = "CLOSE [ESC]"
	x_btn.pressed.connect(close_chat); top_h.add_child(x_btn)

	meta_lbl = Label.new(); meta_lbl.add_theme_font_size_override("font_size", 13); meta_lbl.modulate = Color(0.45, 0.94, 1.0)
	vb.add_child(meta_lbl)

	log_rtl = RichTextLabel.new()
	log_rtl.bbcode_enabled = true; log_rtl.scroll_following = true
	log_rtl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_rtl.add_theme_font_size_override("normal_font_size", 14)
	vb.add_child(log_rtl)

	# 1-Click Discourse Quick-Chips
	var chip_h = HBoxContainer.new(); chip_h.add_theme_constant_override("separation", 6); vb.add_child(chip_h)
	for pair in [
		["Teach Science", "I grant you the equations of fusion and orbital mechanics. Advance your civilization."],
		["Speak Prophecy", "Behold my burning wheels of eyes. Build monuments to the cosmos and keep the faith."],
		["Command Peace", "Lay down your weapons against your neighboring worlds, or face judgment."],
		["Ask Their Story", "Tell me of your people, your fears, and what your historians say of my visits."]
	]:
		var b = Button.new(); b.text = pair[0]; b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var prompt_txt: String = pair[1]
		b.pressed.connect(func(): send_message(prompt_txt))
		chip_h.add_child(b)

	# Free-text input row
	var in_h = HBoxContainer.new(); in_h.add_theme_constant_override("separation", 8); vb.add_child(in_h)
	input_edit = LineEdit.new(); input_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_edit.placeholder_text = "Speak as the Biblical UAP to this civilization..."
	input_edit.text_submitted.connect(func(t): send_message(t))
	in_h.add_child(input_edit)
	var send_b = Button.new(); send_b.text = "TRANSMIT"
	send_b.pressed.connect(func(): send_message(input_edit.text))
	in_h.add_child(send_b)

	status_lbl = Label.new(); status_lbl.add_theme_font_size_override("font_size", 12); status_lbl.modulate = Color(0.65, 0.72, 0.82)
	vb.add_child(status_lbl)

func open_for_planet(p: Dictionary, stage_name: String) -> void:
	active_planet = p
	history_msgs.clear()
	panel.visible = true
	title_lbl.text = "COSMIC DISCOURSE — %s (%s)" % [p["name"], p["emissary"]]
	meta_lbl.text = "%s | Archetype: %s | Tech: %d | Faith: %d%% | Stability: %d%%" % [
		stage_name, p["persona"], int(p["tech"]), int(p["faith"]), int(p["stability"])
	]
	log_rtl.text = "[color=#7be8ff][i]Quantum comm-link established with %s of %s...[/i][/color]\n\n" % [p["emissary"], p["name"]]
	log_rtl.append_text("[color=#ffd86b][b]%s:[/b][/color] %s\n\n" % [p["emissary"], p["greeting"]])
	status_lbl.text = "Backend: Local llama-server (127.0.0.1:8080) with Offline Persona Fallback"
	input_edit.text = ""
	input_edit.grab_focus()

func close_chat() -> void:
	panel.visible = false
	closed.emit()

func send_message(text: String) -> void:
	var msg = text.strip_edges()
	if msg.is_empty() or busy or active_planet.is_empty(): return
	input_edit.text = ""
	log_rtl.append_text("[color=#55f2ff][b]BIBLICAL UAP (YOU):[/b][/color] %s\n\n" % msg)
	history_msgs.append({"role": "user", "content": msg})

	# Apply immediate semantic impact to the civilization
	var low = msg.to_lower()
	var dt := 85.0; var df := 6.0; var ds := 4.0; var tag := "Discourse recorded"
	if "fusion" in low or "science" in low or "math" in low or "equation" in low or "star" in low or "tech" in low:
		dt = 260.0; df = 8.0; ds = 8.0; tag = "UAP shared cosmic science (+260 Tech)"
	elif "faith" in low or "monument" in low or "worship" in low or "prophecy" in low or "wheel" in low or "angel" in low:
		dt = 110.0; df = 24.0; ds = 10.0; tag = "UAP delivered prophecy (+24% Faith)"
	elif "peace" in low or "unite" in low or "stop" in low or "mercy" in low:
		dt = 90.0; df = 12.0; ds = 28.0; tag = "UAP commanded peace (+28% Stability)"
	elif "destroy" in low or "burn" in low or "war" in low or "smite" in low or "fear" in low:
		dt = 60.0; df = 18.0; ds = -22.0; tag = "UAP issued wrathful warning (-22% Stability)"
	discourse_impact.emit(active_planet["name"], dt, df, ds, tag)

	# Web builds cannot reach 127.0.0.1:8080 directly -> use rich offline persona engine
	if OS.has_feature("web"):
		_reply_offline(msg)
		return

	busy = true
	status_lbl.text = "Channeling %s via local llama-server..." % active_planet["emissary"]

	var sys_prompt = (
		"You are %s, the voice of the civilization on %s (%s). "
		+ "Personality: %s. Current Tech: %d (Type 5 is tribal, Type 1 at 5000+ is Star-Forger). "
		+ "Faith in the Biblical UAP: %d%%. Stability: %d%%. "
		+ "You are speaking directly to the Biblical UAP (glowing wheels within wheels covered in eyes) hovering in your sky. "
		+ "Respond in 2-4 vivid, in-character sentences reflecting your era and personality."
	) % [
		active_planet["emissary"], active_planet["name"], active_planet["kind"],
		active_planet["persona"], int(active_planet["tech"]), int(active_planet["faith"]), int(active_planet["stability"])
	]

	var payload_msgs := [{"role": "system", "content": sys_prompt}]
	for m in history_msgs.slice(max(0, history_msgs.size() - 6)):
		payload_msgs.append(m)

	var body = JSON.stringify({
		"model": "local-model",
		"messages": payload_msgs,
		"temperature": 0.82,
		"max_tokens": 140
	})
	var err = http.request(LLAMA_URL, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	if err != OK:
		busy = false
		_reply_offline(msg)

func _on_http_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	busy = false
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		var parsed = JSON.parse_string(body.get_string_from_utf8())
		if parsed is Dictionary and parsed.has("choices") and parsed["choices"].size() > 0:
			var reply: String = str(parsed["choices"][0]["message"]["content"]).strip_edges()
			if not reply.is_empty():
				history_msgs.append({"role": "assistant", "content": reply})
				log_rtl.append_text("[color=#ffd86b][b]%s:[/b][/color] %s\n\n" % [active_planet["emissary"], reply])
				status_lbl.text = "Connected: Local llama-server (Live AI)"
				return
	status_lbl.text = "llama-server offline — using Built-in Era Persona Engine"
	var last_u = history_msgs[-1]["content"] if not history_msgs.is_empty() else ""
	_reply_offline(last_u)

func _reply_offline(user_msg: String) -> void:
	var p = active_planet
	var low = user_msg.to_lower()
	var reply := ""
	if "science" in low or "fusion" in low or "equation" in low or "star" in low:
		reply = "Our scholars on %s are transcribing your harmonic math right now! With %d Tech, we can already see how to bend plasma and build toward our own Artificial Star." % [p["name"], int(p["tech"])]
	elif "peace" in low or "war" in low:
		reply = "Your burning wheels silence even our warlords. %s pledges restraint—though if neighboring fleets cross our orbit, we will look to your eyes in the sky." % p["name"]
	elif "faith" in low or "monument" in low or "prophecy" in low:
		reply = "Our temples already carve the spinning rings you showed our children. As %s, I swear %s will raise megaliths in space worthy of your passage!" % [p["emissary"], p["name"]]
	else:
		reply = "We hear your resonance across %s's atmosphere, Architect. Our %s people watch your golden rings turn above us—guide our next era, or test our resolve." % [p["name"], p["persona"].to_lower()]
	history_msgs.append({"role": "assistant", "content": reply})
	log_rtl.append_text("[color=#ffd86b][b]%s:[/b][/color] %s\n\n" % [p["emissary"], reply])
