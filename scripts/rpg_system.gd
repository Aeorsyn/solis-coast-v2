extends CanvasLayer
class_name RPGSystem

const TIERS = [
	{"name": "COMMON",    "col": Color(0.76, 0.78, 0.82), "mult": 1.0},
	{"name": "RARE",      "col": Color(0.22, 0.70, 1.00), "mult": 1.35},
	{"name": "EPIC",      "col": Color(0.74, 0.30, 1.00), "mult": 1.75},
	{"name": "LEGENDARY", "col": Color(1.00, 0.66, 0.14), "mult": 2.30},
	{"name": "MYTHIC",    "col": Color(1.00, 0.22, 0.34), "mult": 3.00}
]

var level := 1
var xp := 0
var xp_next := 120

var equipped := {
	"weapon": {"name": "MK-I Carbine", "slot": "weapon", "tier": 0, "atk": 0.0, "crit": 0.05, "hp": 0.0, "spd": 0.0, "cdr": 0.0},
	"armor":  {"name": "Street Raglan", "slot": "armor",  "tier": 0, "atk": 0.0, "crit": 0.0,  "hp": 0.0, "spd": 0.0, "cdr": 0.0},
	"cyber":  {"name": "Basic Neural Link", "slot": "cyber", "tier": 0, "atk": 0.0, "crit": 0.0, "hp": 0.0, "spd": 0.0, "cdr": 0.0}
}
var inventory: Array[Dictionary] = []

# Computed Live Stats
var atk_mult := 1.0
var crit_chance := 0.08
var bonus_hp := 0.0
var speed_mult := 1.0
var cdr_mult := 1.0

# Cyberpunk Cyberware Timers & Cooldowns
var sandy_timer := 0.0; var sandy_cd := 0.0
var dash_cd := 0.0
var hack_cd := 0.0
var cloak_timer := 0.0; var cloak_cd := 0.0
var shield_hp := 0.0

var panel: PanelContainer
var stats_lbl: Label
var inv_box: VBoxContainer
var ab_labels: Array[Label] = []
var sandy_overlay: ColorRect

signal toast(msg: String)
signal stats_changed()
signal closed()

func _ready() -> void:
	_recalc_stats()
	_build_ui()

func _build_ui() -> void:
	# Subtle Sandevistan reflex screen tint
	sandy_overlay = ColorRect.new()
	sandy_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	sandy_overlay.color = Color(0.10, 0.85, 0.95, 0.0)
	sandy_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sandy_overlay)

	# Bottom-Center Cyberpunk Cyberware Hotbar ([1] [2] [3] [4])
	var bar_p = PanelContainer.new()
	bar_p.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar_p.offset_left = -290; bar_p.offset_right = 290; bar_p.offset_top = -62; bar_p.offset_bottom = -12
	var bsb = StyleBoxFlat.new()
	bsb.bg_color = Color(0.04, 0.06, 0.12, 0.82); bsb.border_color = Color(0.22, 0.88, 1.0, 0.72)
	bsb.set_border_width_all(2); bsb.set_corner_radius_all(8)
	bsb.content_margin_left = 10; bsb.content_margin_right = 10; bsb.content_margin_top = 6; bsb.content_margin_bottom = 6
	bar_p.add_theme_stylebox_override("panel", bsb)
	bar_p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar_p)

	var hbox = HBoxContainer.new(); hbox.add_theme_constant_override("separation", 14); hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bar_p.add_child(hbox)
	for title in ["[1] SANDEVISTAN", "[2] PLASMA DASH", "[3] SHORT CIRCUIT", "[4] AEGIS CLOAK"]:
		var l = Label.new(); l.text = title; l.add_theme_font_size_override("font_size", 13)
		hbox.add_child(l); ab_labels.append(l)

	# Toggleable [I] MMORPG Loadout & Stats Panel
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	panel.offset_left = -410; panel.offset_right = -18; panel.offset_top = -255; panel.offset_bottom = 255
	var psb = StyleBoxFlat.new()
	psb.bg_color = Color(0.05, 0.06, 0.12, 0.94); psb.border_color = Color(1.0, 0.68, 0.18, 0.88)
	psb.set_border_width_all(2); psb.set_corner_radius_all(12)
	psb.content_margin_left = 14; psb.content_margin_right = 14; psb.content_margin_top = 12; psb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", psb)
	panel.visible = false
	add_child(panel)

	var vb = VBoxContainer.new(); vb.add_theme_constant_override("separation", 8); panel.add_child(vb)
	var hdr = Label.new(); hdr.text = "CYBERWARE & GEAR LOADOUT [I]"
	hdr.add_theme_font_size_override("font_size", 18); hdr.modulate = Color(1.0, 0.78, 0.25); vb.add_child(hdr)

	stats_lbl = Label.new(); stats_lbl.add_theme_font_size_override("font_size", 13); vb.add_child(stats_lbl)

	var sc = ScrollContainer.new(); sc.size_flags_vertical = Control.SIZE_EXPAND_FILL; vb.add_child(sc)
	inv_box = VBoxContainer.new(); inv_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv_box.add_theme_constant_override("separation", 5); sc.add_child(inv_box)

	var close_b = Button.new(); close_b.text = "CLOSE [I / ESC]"
	close_b.pressed.connect(func(): panel.visible = false; closed.emit())
	vb.add_child(close_b)
	_refresh_panel()

func toggle_panel() -> bool:
	panel.visible = not panel.visible
	if panel.visible: _refresh_panel()
	return panel.visible

func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_next:
		xp -= xp_next
		level += 1
		xp_next = int(xp_next * 1.35)
		_recalc_stats()
		toast.emit("LEVEL UP! REACHED LEVEL %d (+ATK / +HP)!" % level)
	_refresh_panel()

func roll_loot_drop(high_tier_bias := false) -> void:
	var r = randf()
	var tier := 0
	if high_tier_bias:
		tier = 4 if r > 0.90 else (3 if r > 0.68 else (2 if r > 0.38 else 1))
	else:
		tier = 4 if r > 0.96 else (3 if r > 0.85 else (2 if r > 0.62 else (1 if r > 0.30 else 0)))

	var m: float = TIERS[tier]["mult"] * (1.0 + (level - 1) * 0.08)
	var slots = ["weapon", "armor", "cyber"]
	var slot: String = slots[randi() % slots.size()]
	var item := {"slot": slot, "tier": tier, "atk": 0.0, "crit": 0.0, "hp": 0.0, "spd": 0.0, "cdr": 0.0}

	match slot:
		"weapon":
			var wnames = ["Pulse Rifle", "Hellfire Carbine", "Void Lance", "Smart-AR", "Thermal Repeater"]
			item["name"] = "%s %s" % [TIERS[tier]["name"].capitalize(), wnames[randi() % wnames.size()]]
			item["atk"] = snappedf(0.18 * m, 0.01)
			item["crit"] = snappedf(0.04 * m, 0.01)
		"armor":
			var anames = ["Subdermal Weave", "Arasaka Plate", "Infernal Exo-Vest", "Carbon Chassis"]
			item["name"] = "%s %s" % [TIERS[tier]["name"].capitalize(), anames[randi() % anames.size()]]
			item["hp"] = round(22.0 * m)
			item["spd"] = snappedf(0.05 * m, 0.01)
		"cyber":
			var cnames = ["Militech Sandevistan", "NetDriver Deck", "Synaptic Accelerator", "Kereznikov Core"]
			item["name"] = "%s %s" % [TIERS[tier]["name"].capitalize(), cnames[randi() % cnames.size()]]
			item["cdr"] = snappedf(0.07 * m, 0.01)
			item["atk"] = snappedf(0.10 * m, 0.01)
			item["spd"] = snappedf(0.06 * m, 0.01)

	inventory.insert(0, item)
	if inventory.size() > 18: inventory.pop_back()

	# Auto-equip if strictly higher tier than current slot
	if tier > int(equipped[slot]["tier"]):
		equipped[slot] = item
		_recalc_stats()
		toast.emit("AUTO-EQUIPPED [%s] %s!" % [TIERS[tier]["name"], item["name"]])
	else:
		toast.emit("LOOT DROP: [%s] %s (Press [I] to equip)" % [TIERS[tier]["name"], item["name"]])
	_refresh_panel()

func _recalc_stats() -> void:
	atk_mult = 1.0 + (level - 1) * 0.08
	crit_chance = 0.08
	bonus_hp = (level - 1) * 12.0
	speed_mult = 1.0
	var cdr_sum := 0.0
	for slot in equipped.keys():
		var it: Dictionary = equipped[slot]
		atk_mult += float(it["atk"])
		crit_chance += float(it["crit"])
		bonus_hp += float(it["hp"])
		speed_mult += float(it["spd"])
		cdr_sum += float(it["cdr"])
	crit_chance = minf(crit_chance, 0.85)
	cdr_mult = maxf(0.35, 1.0 - cdr_sum)
	stats_changed.emit()

func _refresh_panel() -> void:
	if stats_lbl == null: return
	stats_lbl.text = "LVL %d (%d/%d XP) | ATK: %.2fx | CRIT: %d%% | +HP: %d | SPD: %.2fx | CDR: %d%%" % [
		level, xp, xp_next, atk_mult, int(crit_chance * 100), int(bonus_hp), speed_mult, int((1.0 - cdr_mult) * 100)
	]
	for c in inv_box.get_children(): c.queue_free()

	var eq_hdr = Label.new(); eq_hdr.text = "EQUIPPED GEAR:"; eq_hdr.modulate = Color(0.35, 0.92, 1.0); inv_box.add_child(eq_hdr)
	for slot in ["weapon", "armor", "cyber"]:
		var it: Dictionary = equipped[slot]
		var l = Label.new()
		l.text = "  %s: [%s] %s" % [slot.to_upper(), TIERS[it["tier"]]["name"], it["name"]]
		l.modulate = TIERS[it["tier"]]["col"]; l.add_theme_font_size_override("font_size", 13)
		inv_box.add_child(l)

	var bag_hdr = Label.new(); bag_hdr.text = "\nLOOT BAG (Click to Equip):"; bag_hdr.modulate = Color(1.0, 0.84, 0.35); inv_box.add_child(bag_hdr)
	for it in inventory:
		var b = Button.new()
		b.text = "[%s] %s (%s)" % [TIERS[it["tier"]]["name"], it["name"], it["slot"].to_upper()]
		b.modulate = TIERS[it["tier"]]["col"]
		b.pressed.connect(func(): equipped[it["slot"]] = it; _recalc_stats(); _refresh_panel(); toast.emit("Equipped " + it["name"]))
		inv_box.add_child(b)

func calc_shot_damage(base_dmg: float) -> Dictionary:
	var is_crit = randf() < crit_chance
	var dmg = base_dmg * atk_mult * (1.85 if is_crit else 1.0)
	return {"dmg": dmg, "crit": is_crit}

func absorb_damage(raw_dmg: float) -> float:
	var dmg = raw_dmg * (0.5 if cloak_timer > 0.0 else 1.0)
	if shield_hp > 0.0:
		var absorbed = minf(shield_hp, dmg)
		shield_hp -= absorbed
		dmg -= absorbed
	return dmg

func activate_sandevistan() -> bool:
	if sandy_cd > 0.0: return false
	sandy_timer = 6.0
	sandy_cd = 16.0 * cdr_mult
	toast.emit("SANDEVISTAN ENGAGED! Hyper-Reflex Time Dilation (6s)!")
	return true

func activate_dash(player: CharacterBody3D, dir: Vector3) -> bool:
	if dash_cd > 0.0: return false
	dash_cd = 6.0 * cdr_mult
	player.velocity = dir.normalized() * 44.0
	toast.emit("PLASMA DASH! Shockwave Impact!")
	return true

func activate_short_circuit(origin: Vector3, hell_mgr: HellfireManager, abyss_mgr: AbyssManager, host: Node3D) -> int:
	if hack_cd > 0.0: return 0
	hack_cd = 12.0 * cdr_mult
	var hits := 0
	var dmg = 68.0 * atk_mult
	var targets: Array = []
	if hell_mgr:
		for d in hell_mgr.demons.duplicate():
			if is_instance_valid(d["body"]) and d["body"].global_position.distance_to(origin) < 32.0:
				targets.append([hell_mgr, d["body"], d["body"].global_position])
	if abyss_mgr:
		for d in abyss_mgr.demons.duplicate():
			if is_instance_valid(d["body"]) and d["body"].global_position.distance_to(origin) < 36.0:
				targets.append([abyss_mgr, d["body"], d["body"].global_position])

	for t in targets:
		var p_end: Vector3 = t[2] + Vector3(0, 0.8, 0)
		t[0].try_hit_demon(t[1], dmg, p_end)
		# Draw glowing cyan cyber-arc beam
		var mi = MeshInstance3D.new()
		var bm = BoxMesh.new(); bm.size = Vector3(0.09, 0.09, maxf(0.2, origin.distance_to(p_end)))
		var mat = StandardMaterial3D.new(); mat.albedo_color = Color(0.2, 0.95, 1.0)
		mat.emission_enabled = true; mat.emission = Color(0.15, 0.88, 1.0); mat.emission_energy_multiplier = 7.0
		bm.material = mat; mi.mesh = bm; host.add_child(mi)
		mi.global_position = (origin + Vector3(0, 1.2, 0) + p_end) * 0.5; mi.look_at(p_end, Vector3.UP)
		host.get_tree().create_timer(0.28).timeout.connect(mi.queue_free)
		hits += 1

	toast.emit("SHORT CIRCUIT QUICKHACK! Fried %d enemies!" % hits if hits > 0 else "SHORT CIRCUIT PULSE: No enemies in 32m range!")
	return hits

func activate_aegis() -> bool:
	if cloak_cd > 0.0: return false
	cloak_timer = 8.0
	shield_hp = 75.0 + bonus_hp * 0.35
	cloak_cd = 18.0 * cdr_mult
	toast.emit("AEGIS CLOAK ACTIVE! +%d Overshield & 50%% Damage Reduction!" % int(shield_hp))
	return true

func update_rpg(u_delta: float) -> void:
	sandy_timer = maxf(0.0, sandy_timer - u_delta)
	sandy_cd    = maxf(0.0, sandy_cd - u_delta)
	dash_cd     = maxf(0.0, dash_cd - u_delta)
	hack_cd     = maxf(0.0, hack_cd - u_delta)
	cloak_timer = maxf(0.0, cloak_timer - u_delta)
	cloak_cd    = maxf(0.0, cloak_cd - u_delta)

	var target_a = 0.14 if sandy_timer > 0.0 else 0.0
	sandy_overlay.color.a = lerpf(sandy_overlay.color.a, target_a, clampf(u_delta * 10.0, 0.0, 1.0))

	if ab_labels.size() == 4:
		var specs = [
			["[1] SANDEVISTAN", sandy_timer, sandy_cd, Color(0.20, 0.96, 1.0)],
			["[2] PLASMA DASH", 0.0, dash_cd, Color(1.0, 0.52, 0.15)],
			["[3] SHORT CIRCUIT", 0.0, hack_cd, Color(0.75, 0.38, 1.0)],
			["[4] AEGIS CLOAK", cloak_timer, cloak_cd, Color(0.25, 1.0, 0.55)]
		]
		for i in 4:
			var sp = specs[i]
			if sp[1] > 0.0:
				ab_labels[i].text = "%s (%.1fs)" % [sp[0], sp[1]]
				ab_labels[i].modulate = sp[3]
			elif sp[2] > 0.0:
				ab_labels[i].text = "%s [%.0fs]" % [sp[0], ceil(sp[2])]
				ab_labels[i].modulate = Color(0.45, 0.48, 0.55)
			else:
				ab_labels[i].text = sp[0]
				ab_labels[i].modulate = sp[3]
