extends Node3D
class_name CosmosManager

const STAGE_NAMES = [
	"BARREN / EXTINCT",
	"TYPE 5: PRIMORDIAL TRIBES",
	"TYPE 4: MEGALITHIC ERA",
	"TYPE 3: INDUSTRIAL / ATOMIC",
	"TYPE 2: ORBITAL DYSON ERA",
	"TYPE 1: STAR-FORGER"
]

var active := false
var planets: Array[Dictionary] = []
var stars: Array[Dictionary] = []
var beams: Array[Dictionary] = []
var war_fleets: Array[Dictionary] = []
var signal_rings: Array[Dictionary] = []
var ejection_streams: Array[Dictionary] = []

# Pooled GPU-instanced Katamari debris (chunks + mote dust = 2 draw calls total)
const MAX_CHUNKS := 900
const MAX_MOTES  := 1400
var mm_chunks: MultiMeshInstance3D
var mm_motes: MultiMeshInstance3D
var debris_chunks: Array[Dictionary] = []
var debris_motes: Array[Dictionary] = []

var stored_mass := 0.0
var nearest_idx := -1
var nearest_dist := 99999.0

# Incoming Civilization Communication State
var active_comm: Dictionary = {}

# HUD Elements
var hud_layer: CanvasLayer
var planet_bar: Label
var mass_bar: Label
var comm_panel: PanelContainer
var comm_hdr: Label
var comm_body: Label
var chron_panel: PanelContainer
var chron_title: Label
var chron_stats: Label
var chron_log: RichTextLabel

signal chronicle_event(msg: String)
signal reward_granted(cash: int, xp: int, roll_loot: bool)

func setup() -> void:
	_build_hud()
	_init_debris_pools()
	visible = false
	hud_layer.visible = false

	# 8 Diverse Planet Types (Terran, Desert, Ocean, Volcanic, Ringed Gas Giant, Storm Gas Giant, Ice Giant, Cryo)
	var specs = [
		{"name": "AETHELGARD", "kind": "TERRAN WORLD",    "emissary": "Archivist Lyra",    "persona": "Curious & Philosophical",    "greeting": "Wheels of golden fire, our observatories have awaited your voice. What truths do you bring to Aethelgard?", "ptype": 0, "rings": false, "offset": Vector3(-230, 195, -180), "r": 34.0, "seed": 1.4, "land": Color(0.16, 0.48, 0.18), "ocean": Color(0.04, 0.26, 0.58), "atmo": Color(0.28, 0.76, 1.0)},
		{"name": "KHEPRI",     "kind": "DESERT WORLD",    "emissary": "Pharaoh Amenhotep", "persona": "Monumental & Devout",        "greeting": "Great Chariot of Eyes! Tell us the sacred ratios so our pyramids may touch your orbit!", "ptype": 0, "rings": false, "offset": Vector3( 245, 210, -205), "r": 30.0, "seed": 4.2, "land": Color(0.72, 0.52, 0.26), "ocean": Color(0.06, 0.36, 0.48), "atmo": Color(1.00, 0.72, 0.32)},
		{"name": "THALASSA",   "kind": "OCEAN WORLD",     "emissary": "Tide-Oracle Nerissa","persona": "Poetic & Pacifist",         "greeting": "Your golden reflection ripples across our endless seas. Speak softly, luminous one—our oceans listen.", "ptype": 0, "rings": false, "offset": Vector3(-190, 285,  215), "r": 36.0, "seed": 7.8, "land": Color(0.14, 0.54, 0.38), "ocean": Color(0.02, 0.16, 0.54), "atmo": Color(0.16, 0.94, 0.85)},
		{"name": "VULCANIS",   "kind": "VOLCANIC WORLD",  "emissary": "Forgemaster Kael",  "persona": "Fierce & Ambitious",         "greeting": "We forged cities from magma without fear! Grant us star-fire weapons, or watch us claim the void ourselves!", "ptype": 0, "rings": false, "offset": Vector3( 220, 255,  205), "r": 28.0, "seed": 9.5, "land": Color(0.42, 0.22, 0.18), "ocean": Color(0.22, 0.08, 0.06), "atmo": Color(1.00, 0.40, 0.18)},
		{"name": "JOVIAN-IX",  "kind": "RINGED GAS GIANT","emissary": "Sky-Captain Vael",  "persona": "Bold Cloud-Barons",          "greeting": "Ahoy, spinning halo! Our floating aerostats rode the red cyclone just to hail you—what lies beyond our rings?", "ptype": 1, "rings": true,  "offset": Vector3(-430, 290, -340), "r": 54.0, "seed": 2.9, "land": Color(0.84, 0.66, 0.44), "ocean": Color(0.58, 0.34, 0.22), "atmo": Color(0.95, 0.76, 0.48)},
		{"name": "TEMPESTUS",  "kind": "STORM GAS GIANT", "emissary": "The Storm-Choir",   "persona": "Electric Hive-Mind",         "greeting": "WE SING IN LIGHTNING. YOUR EYES PULSE ON OUR FREQUENCY. SPEAK TO THE CHOIR OF TEMPESTUS.", "ptype": 1, "rings": false, "offset": Vector3( 450, 320, -300), "r": 48.0, "seed": 6.1, "land": Color(0.32, 0.44, 0.78), "ocean": Color(0.16, 0.18, 0.46), "atmo": Color(0.48, 0.68, 1.00)},
		{"name": "GLACIES",    "kind": "ICE GIANT",       "emissary": "Logician Solon",    "persona": "Skeptical & Analytical",     "greeting": "Anomalous toroidal craft detected. State your propulsion physics—we do not worship what we have not measured.", "ptype": 2, "rings": true,  "offset": Vector3(-390, 350,  360), "r": 42.0, "seed": 3.3, "land": Color(0.55, 0.88, 0.96), "ocean": Color(0.12, 0.42, 0.68), "atmo": Color(0.38, 0.92, 1.00)},
		{"name": "EREBUS",     "kind": "CRYO WORLD",      "emissary": "Deep-Seer Moros",   "persona": "Mystical & Prophetic",       "greeting": "Beneath miles of frozen crust, our ancestors dreamed of your burning wheels. Has the Great Thaw finally arrived?", "ptype": 2, "rings": false, "offset": Vector3( 390, 330,  350), "r": 31.0, "seed": 8.4, "land": Color(0.76, 0.82, 0.92), "ocean": Color(0.16, 0.22, 0.42), "atmo": Color(0.68, 0.56, 1.00)}
	]
	for sp in specs:
		_create_planet(sp)

	# 4 Distinct Star Types orbiting the outer cosmos (White Dwarf, Red Giant, Blue Supergiant, Neutron Pulsar)
	var star_specs = [
		{"name": "SIRIUS-B (WHITE DWARF)",      "offset": Vector3(   0, 440, -560), "r": 16.0, "core": Color(0.92, 0.98, 1.00), "flare": Color(0.45, 0.82, 1.00), "pulsar": false, "energy": 9.5},
		{"name": "BETEL-PRIME (RED GIANT)",     "offset": Vector3(-620, 460,  -40), "r": 74.0, "core": Color(1.00, 0.55, 0.16), "flare": Color(0.95, 0.14, 0.04), "pulsar": false, "energy": 5.5},
		{"name": "RIGEL-X (BLUE SUPERGIANT)",   "offset": Vector3( 620, 480,   40), "r": 46.0, "core": Color(0.78, 0.92, 1.00), "flare": Color(0.16, 0.46, 1.00), "pulsar": false, "energy": 8.0},
		{"name": "VELA-0 (NEUTRON PULSAR)",     "offset": Vector3(   0, 500,  580), "r": 12.0, "core": Color(0.88, 0.96, 1.00), "flare": Color(0.62, 0.28, 1.00), "pulsar": true,  "energy": 10.5}
	]
	for ss in star_specs:
		_create_star(ss)

func _create_star(ss: Dictionary) -> void:
	var root = Node3D.new(); add_child(root)
	var sph = SphereMesh.new(); sph.radius = ss["r"]; sph.height = ss["r"] * 2.0; sph.radial_segments = 28; sph.rings = 14
	var mat = ShaderMaterial.new(); mat.shader = load("res://shaders/stellar_star.gdshader")
	mat.set_shader_parameter("core_color", ss["core"])
	mat.set_shader_parameter("flare_color", ss["flare"])
	mat.set_shader_parameter("energy", ss["energy"])
	sph.material = mat
	var mi = MeshInstance3D.new(); mi.mesh = sph; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)

	var l = OmniLight3D.new(); l.light_color = ss["core"]; l.light_energy = 7.0; l.omni_range = 380.0
	root.add_child(l)

	var lbl = Label3D.new(); lbl.text = ss["name"]
	lbl.position = Vector3(0, ss["r"] + 18.0, 0); lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.font_size = 110; lbl.pixel_size = 0.10; lbl.modulate = ss["core"]
	root.add_child(lbl)

	# Relativistic Polar Jets for Neutron Pulsar
	var jet_piv: Node3D = null
	if ss["pulsar"]:
		jet_piv = Node3D.new(); root.add_child(jet_piv)
		var jmat = StandardMaterial3D.new(); jmat.albedo_color = Color(0.55, 0.92, 1.0)
		jmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; jmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		jmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD; jmat.emission_enabled = true
		jmat.emission = Color(0.45, 0.85, 1.0); jmat.emission_energy_multiplier = 8.0
		var cone = CylinderMesh.new(); cone.top_radius = 16.0; cone.bottom_radius = 1.4; cone.height = 175.0; cone.radial_segments = 12
		cone.material = jmat
		for sy in [-1.0, 1.0]:
			var jm = MeshInstance3D.new(); jm.mesh = cone; jm.position = Vector3(0, sy * 92.0, 0)
			if sy < 0.0: jm.rotation_degrees.x = 180.0
			jm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			jet_piv.add_child(jm)
		jet_piv.rotation_degrees = Vector3(26, 0, 18)

	stars.append({"root": root, "offset": ss["offset"], "pulsar": ss["pulsar"], "jet_piv": jet_piv})

func _init_debris_pools() -> void:
	var c_mesh = PrismMesh.new(); c_mesh.size = Vector3(2.4, 2.8, 2.0)
	var c_mat = StandardMaterial3D.new()
	c_mat.vertex_color_use_as_albedo = true; c_mat.roughness = 0.75
	c_mat.emission_enabled = true; c_mat.emission = Color(1.0, 0.36, 0.06); c_mat.emission_energy_multiplier = 1.4
	c_mesh.material = c_mat
	var mmc = MultiMesh.new(); mmc.transform_format = MultiMesh.TRANSFORM_3D; mmc.use_colors = true
	mmc.mesh = c_mesh; mmc.instance_count = MAX_CHUNKS; mmc.visible_instance_count = 0
	mm_chunks = MultiMeshInstance3D.new(); mm_chunks.multimesh = mmc; mm_chunks.extra_cull_margin = 1200.0
	mm_chunks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mm_chunks)

	var m_mesh = SphereMesh.new(); m_mesh.radius = 0.72; m_mesh.height = 1.44; m_mesh.radial_segments = 6; m_mesh.rings = 3
	var m_mat = StandardMaterial3D.new()
	m_mat.vertex_color_use_as_albedo = true; m_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m_mesh.material = m_mat
	var mmm = MultiMesh.new(); mmm.transform_format = MultiMesh.TRANSFORM_3D; mmm.use_colors = true
	mmm.mesh = m_mesh; mmm.instance_count = MAX_MOTES; mmm.visible_instance_count = 0
	mm_motes = MultiMeshInstance3D.new(); mm_motes.multimesh = mmm; mm_motes.extra_cull_margin = 1200.0
	mm_motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mm_motes)

func _create_planet(sp: Dictionary) -> void:
	var body = StaticBody3D.new()
	body.collision_layer = 2; body.collision_mask = 0
	add_child(body)

	var mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/living_planet.gdshader")
	mat.set_shader_parameter("planet_type", sp["ptype"])
	mat.set_shader_parameter("planet_seed", sp["seed"])
	mat.set_shader_parameter("land_color", sp["land"])
	mat.set_shader_parameter("ocean_color", sp["ocean"])
	mat.set_shader_parameter("atmo_color", sp["atmo"])

	var sph = SphereMesh.new()
	sph.radius = sp["r"]; sph.height = sp["r"] * 2.0; sph.radial_segments = 40; sph.rings = 20
	sph.material = mat
	var mi = MeshInstance3D.new(); mi.mesh = sph; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mi)

	# Concentric Holographic & Parallax Atmosphere Depth Shells (2 layers)
	var holo_sh = load("res://shaders/planet_holo_shell.gdshader")
	var h_in_mat = ShaderMaterial.new(); h_in_mat.shader = holo_sh
	h_in_mat.set_shader_parameter("planet_seed", sp["seed"])
	h_in_mat.set_shader_parameter("shell_layer", 0.0)
	h_in_mat.set_shader_parameter("atmo_color", sp["atmo"])
	var h_in_m = SphereMesh.new(); h_in_m.radius = sp["r"] * 1.038; h_in_m.height = sp["r"] * 2.076; h_in_m.radial_segments = 32; h_in_m.rings = 16; h_in_m.material = h_in_mat
	var h_in = MeshInstance3D.new(); h_in.mesh = h_in_m; h_in.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(h_in)

	var h_out_mat = ShaderMaterial.new(); h_out_mat.shader = holo_sh
	h_out_mat.set_shader_parameter("planet_seed", sp["seed"] + 3.1)
	h_out_mat.set_shader_parameter("shell_layer", 1.0)
	h_out_mat.set_shader_parameter("atmo_color", sp["atmo"])
	var h_out_m = SphereMesh.new(); h_out_m.radius = sp["r"] * 1.088; h_out_m.height = sp["r"] * 2.176; h_out_m.radial_segments = 32; h_out_m.rings = 16; h_out_m.material = h_out_mat
	var h_out = MeshInstance3D.new(); h_out.mesh = h_out_m; h_out.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(h_out)

	var col = CollisionShape3D.new(); var cs = SphereShape3D.new(); cs.radius = sp["r"]
	col.shape = cs; body.add_child(col)

	# Natural Saturn-style Planetary Dust/Ice Rings for Gas & Ice Giants
	if sp["rings"]:
		var pr_piv = Node3D.new(); pr_piv.rotation_degrees = Vector3(22, 0, -14); body.add_child(pr_piv)
		for band_i in 2:
			var r_in = sp["r"] * (1.35 if band_i == 0 else 1.72)
			var r_out = sp["r"] * (1.66 if band_i == 0 else 2.02)
			var ptor = TorusMesh.new(); ptor.inner_radius = r_in; ptor.outer_radius = r_out; ptor.rings = 40; ptor.ring_segments = 6
			var pmat = StandardMaterial3D.new()
			var rc: Color = sp["atmo"].lerp(Color(0.95, 0.88, 0.72), 0.45)
			pmat.albedo_color = Color(rc.r, rc.g, rc.b, 0.58 if band_i == 0 else 0.36)
			pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; pmat.cull_mode = BaseMaterial3D.CULL_DISABLED
			pmat.emission_enabled = true; pmat.emission = rc; pmat.emission_energy_multiplier = 0.45
			ptor.material = pmat
			var pmi = MeshInstance3D.new(); pmi.mesh = ptor; pmi.scale = Vector3(1.0, 0.04, 1.0)
			pmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pr_piv.add_child(pmi)

	var lbl = Label3D.new()
	lbl.text = "%s (%s)\n[BARREN — PRESS Z TO SEED]" % [sp["name"], sp["kind"]]
	lbl.position = Vector3(0, sp["r"] + 13.0, 0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.font_size = 96; lbl.pixel_size = 0.08
	lbl.modulate = Color(0.86, 0.95, 1.0)
	body.add_child(lbl)

	# Visible Orbiting Civilization Emissary Probes / Ships (appear as soon as life is seeded!)
	var fleet_piv = Node3D.new(); fleet_piv.visible = false; body.add_child(fleet_piv)
	var sh_m = PrismMesh.new(); sh_m.size = Vector3(1.8, 3.6, 1.2)
	var sh_mat = StandardMaterial3D.new(); sh_mat.albedo_color = Color.WHITE; sh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sh_mat.emission_enabled = true; sh_mat.emission = sp["atmo"]; sh_mat.emission_energy_multiplier = 6.5
	sh_m.material = sh_mat
	for fi in 8:
		var fa = TAU * float(fi) / 8.0
		var fr = sp["r"] * (1.18 + float(fi % 3) * 0.08)
		var fmi = MeshInstance3D.new(); fmi.mesh = sh_m
		fmi.position = Vector3(cos(fa) * fr, sin(fa * 2.0) * (sp["r"] * 0.28), sin(fa) * fr)
		fmi.rotation_degrees = Vector3(0, rad_to_deg(-fa), 90)
		fmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fleet_piv.add_child(fmi)

	# Type 2 Orbital Dyson Ring
	var ring_piv = Node3D.new(); ring_piv.visible = false; body.add_child(ring_piv)
	var tor = TorusMesh.new(); tor.inner_radius = sp["r"] * 1.32; tor.outer_radius = sp["r"] * 1.40; tor.rings = 32; tor.ring_segments = 8
	var rmat = StandardMaterial3D.new(); rmat.albedo_color = Color(1.0, 0.85, 0.35); rmat.metallic = 0.9; rmat.roughness = 0.2
	rmat.emission_enabled = true; rmat.emission = Color(0.25, 0.95, 1.0); rmat.emission_energy_multiplier = 3.2
	tor.material = rmat
	var rmi = MeshInstance3D.new(); rmi.mesh = tor; rmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rmi.rotation_degrees = Vector3(18, 0, 12); ring_piv.add_child(rmi)

	# Type 1 Forged Artificial Star
	var star_piv = Node3D.new(); star_piv.visible = false; body.add_child(star_piv)
	var star_m = SphereMesh.new(); star_m.radius = 6.5; star_m.height = 13.0; star_m.radial_segments = 16; star_m.rings = 8
	var smat = StandardMaterial3D.new(); smat.albedo_color = Color(1.0, 0.98, 0.86); smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.emission_enabled = true; smat.emission = Color(1.0, 0.86, 0.42); smat.emission_energy_multiplier = 9.5
	star_m.material = smat
	var smi = MeshInstance3D.new(); smi.mesh = star_m; smi.position = Vector3(sp["r"] * 1.85, 14.0, 0)
	smi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; star_piv.add_child(smi)
	var slight = OmniLight3D.new(); slight.light_color = Color(1.0, 0.92, 0.65); slight.light_energy = 8.0; slight.omni_range = 160.0
	smi.add_child(slight)

	# Space Megalithic Architecture (Tech >= 5000 + Faith >= 70%)
	var mega_piv = Node3D.new(); mega_piv.visible = false; mega_piv.scale = Vector3.ONE * 0.05; body.add_child(mega_piv)
	var gold_stone = StandardMaterial3D.new()
	gold_stone.albedo_color = Color(0.14, 0.12, 0.16); gold_stone.metallic = 0.78; gold_stone.roughness = 0.22
	gold_stone.emission_enabled = true; gold_stone.emission = Color(1.0, 0.78, 0.25); gold_stone.emission_energy_multiplier = 1.65
	var gate_glow = StandardMaterial3D.new()
	gate_glow.albedo_color = Color(1.0, 0.94, 0.68); gate_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gate_glow.emission_enabled = true; gate_glow.emission = Color(1.0, 0.82, 0.28); gate_glow.emission_energy_multiplier = 6.5

	var pyr_m = PrismMesh.new(); pyr_m.size = Vector3(11.0, 14.0, 11.0); pyr_m.material = gold_stone
	var ob_m  = BoxMesh.new(); ob_m.size = Vector3(3.2, 22.0, 3.2); ob_m.material = gold_stone
	var arch_m = TorusMesh.new(); arch_m.inner_radius = 9.0; arch_m.outer_radius = 10.6; arch_m.rings = 20; arch_m.ring_segments = 8; arch_m.material = gate_glow

	for k in 4:
		var ang = TAU * float(k) / 4.0
		var orb_r = sp["r"] * 1.62
		var pos = Vector3(cos(ang) * orb_r, sin(ang * 2.0) * 14.0, sin(ang) * orb_r)
		var m_inst = MeshInstance3D.new()
		m_inst.mesh = pyr_m if (k % 2 == 0) else ob_m
		m_inst.position = pos; m_inst.rotation_degrees = Vector3(0, rad_to_deg(-ang), 18 if k % 2 == 0 else -12)
		m_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mega_piv.add_child(m_inst)
		if k == 0 or k == 2:
			var g_inst = MeshInstance3D.new(); g_inst.mesh = arch_m
			g_inst.position = pos + Vector3(0, 12.0, 0); g_inst.rotation_degrees = Vector3(90, rad_to_deg(-ang), 0)
			g_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mega_piv.add_child(g_inst)

	planets.append({
		"name": sp["name"], "kind": sp["kind"], "emissary": sp["emissary"], "persona": sp["persona"], "greeting": sp["greeting"], "ptype": sp["ptype"], "fleet_piv": fleet_piv,
		"offset": sp["offset"], "r": sp["r"], "atmo": sp["atmo"], "land": sp["land"],
		"body": body, "col": col, "mesh": mi, "mat": mat, "label": lbl, "holo_inner": h_in, "holo_outer": h_out, "holo_in_mat": h_in_mat, "holo_out_mat": h_out_mat,
		"ring_piv": ring_piv, "star_piv": star_piv, "mega_piv": mega_piv,
		"shattered": false, "reform_scale": 1.0, "megalith_built": false,
		"stage": 0, "year": 0.0, "pop": 0.0, "tech": 0.0, "faith": 0.0, "stability": 100.0,
		"life_v": 0.0, "civ_v": 0.0, "ruin_v": 0.0,
		"sighting_cd": 0.0, "crisis_cd": 16.0, "war_cd": randf_range(6.0, 12.0),
		"comm_cd": randf_range(9.0, 18.0),
		"history": ["%s (%s) drifts silent in the Abyss." % [sp["name"], sp["kind"]]]
	})

func _build_hud() -> void:
	hud_layer = CanvasLayer.new(); add_child(hud_layer)

	planet_bar = Label.new()
	planet_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	planet_bar.offset_left = 18; planet_bar.offset_top = -134; planet_bar.offset_right = 880; planet_bar.offset_bottom = -92
	planet_bar.add_theme_font_size_override("font_size", 15)
	planet_bar.modulate = Color(0.55, 0.96, 1.0)
	hud_layer.add_child(planet_bar)

	mass_bar = Label.new()
	mass_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	mass_bar.offset_left = 18; mass_bar.offset_top = -104; mass_bar.offset_right = 880; mass_bar.offset_bottom = -70
	mass_bar.add_theme_font_size_override("font_size", 14)
	mass_bar.modulate = Color(1.0, 0.84, 0.35)
	hud_layer.add_child(mass_bar)

	# Top-Center Incoming Civilization Communication Transceiver
	comm_panel = PanelContainer.new()
	comm_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	comm_panel.offset_left = -335; comm_panel.offset_right = 335; comm_panel.offset_top = 66; comm_panel.offset_bottom = 178
	var csb = StyleBoxFlat.new()
	csb.bg_color = Color(0.03, 0.06, 0.14, 0.92); csb.border_color = Color(0.28, 0.96, 1.0, 0.92)
	csb.set_border_width_all(2); csb.set_corner_radius_all(10)
	csb.content_margin_left = 14; csb.content_margin_right = 14; csb.content_margin_top = 10; csb.content_margin_bottom = 10
	comm_panel.add_theme_stylebox_override("panel", csb)
	comm_panel.visible = false; comm_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(comm_panel)

	var cvb = VBoxContainer.new(); cvb.add_theme_constant_override("separation", 4); comm_panel.add_child(cvb)
	comm_hdr = Label.new(); comm_hdr.add_theme_font_size_override("font_size", 15); comm_hdr.modulate = Color(1.0, 0.88, 0.38); cvb.add_child(comm_hdr)
	comm_body = Label.new(); comm_body.add_theme_font_size_override("font_size", 13); comm_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; cvb.add_child(comm_body)
	var comm_hint = Label.new()
	comm_hint.text = "[Y] Reveal & Guide (+Tech +Faith)  |  [T] Cryptic Prophecy (++Faith)  |  [P] Remain Silent (+Science)"
	comm_hint.add_theme_font_size_override("font_size", 12); comm_hint.modulate = Color(0.45, 0.98, 1.0); cvb.add_child(comm_hint)

	# Toggleable [H] Cosmic Chronicle Panel
	chron_panel = PanelContainer.new()
	chron_panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	chron_panel.offset_left = 18; chron_panel.offset_top = -230; chron_panel.offset_right = 445; chron_panel.offset_bottom = 230
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.11, 0.92); sb.border_color = Color(1.0, 0.85, 0.35, 0.85)
	sb.set_border_width_all(2); sb.set_corner_radius_all(12)
	sb.content_margin_left = 14; sb.content_margin_right = 14; sb.content_margin_top = 12; sb.content_margin_bottom = 12
	chron_panel.add_theme_stylebox_override("panel", sb)
	chron_panel.visible = false
	hud_layer.add_child(chron_panel)

	var vb = VBoxContainer.new(); vb.add_theme_constant_override("separation", 6); chron_panel.add_child(vb)
	chron_title = Label.new(); chron_title.add_theme_font_size_override("font_size", 18); chron_title.modulate = Color(1.0, 0.88, 0.40); vb.add_child(chron_title)
	chron_stats = Label.new(); chron_stats.add_theme_font_size_override("font_size", 13); chron_stats.modulate = Color(0.75, 0.92, 1.0); vb.add_child(chron_stats)
	chron_log = RichTextLabel.new(); chron_log.size_flags_vertical = Control.SIZE_EXPAND_FILL; chron_log.scroll_following = true
	chron_log.add_theme_font_size_override("normal_font_size", 13); vb.add_child(chron_log)

func set_active(state: bool, origin: Vector3) -> void:
	active = state
	visible = state
	hud_layer.visible = state
	if state:
		for p in planets:
			if not p["shattered"]:
				p["body"].global_position = Vector3(origin.x, 0.0, origin.z) + p["offset"]
		for st in stars:
			st["root"].global_position = Vector3(origin.x, 0.0, origin.z) + st["offset"]

func toggle_chronicle() -> void:
	chron_panel.visible = not chron_panel.visible
	if chron_panel.visible: _refresh_chronicle()

func _record(p: Dictionary, entry: String, announce := true) -> void:
	var line = "Yr %d: %s" % [int(p["year"]), entry]
	p["history"].append(line)
	if p["history"].size() > 26: p["history"].pop_front()
	if announce: chronicle_event.emit("[%s] %s" % [p["name"], entry])
	if chron_panel.visible: _refresh_chronicle()

func _spawn_beam(from_p: Vector3, to_p: Vector3, col: Color, width := 2.8) -> void:
	var mi = MeshInstance3D.new()
	var d = maxf(1.0, from_p.distance_to(to_p))
	var cyl = CylinderMesh.new(); cyl.top_radius = 0.55; cyl.bottom_radius = width; cyl.height = d; cyl.radial_segments = 10
	var mat = StandardMaterial3D.new(); mat.albedo_color = col; mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.emission_enabled = true; mat.emission = col; mat.emission_energy_multiplier = 7.5
	cyl.material = mat; mi.mesh = cyl; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = (from_p + to_p) * 0.5
	mi.look_at(to_p, Vector3.UP)
	mi.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	beams.append({"node": mi, "t": 0.95})

func _spawn_signal_ring(origin: Vector3, target: Vector3, col: Color) -> void:
	var mi = MeshInstance3D.new()
	var tor = TorusMesh.new(); tor.inner_radius = 8.0; tor.outer_radius = 9.4; tor.rings = 24; tor.ring_segments = 6
	var mat = StandardMaterial3D.new(); mat.albedo_color = col; mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.emission_enabled = true; mat.emission = col; mat.emission_energy_multiplier = 6.5
	tor.material = mat; mi.mesh = tor; mi.global_position = origin
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.look_at(target, Vector3.UP); mi.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	var dir = (target - origin).normalized()
	signal_rings.append({"node": mi, "vel": dir * 75.0, "t": 2.4})

func _trigger_comm_attempt(p_idx: int, player_pos: Vector3) -> void:
	var p = planets[p_idx]
	var st: int = p["stage"]
	var hdr := ""
	var body := ""
	match st:
		1:
			hdr = "CONTACT SIGNAL — %s (TYPE 5: BONFIRE GEOMETRY)" % p["name"]
			body = "Tribes carved colossal Nazca-style eye-wheels into the plains and lit mile-wide signal fires chanting to the sky."
		2:
			hdr = "CONTACT SIGNAL — %s (TYPE 4: SKY-TEMPLE ALIGNMENT)" % p["name"]
			body = "High priests aligned polished bronze mirrors atop their Great Pyramid to flash prime-ratio light pulses toward your UAP."
		3:
			hdr = "ARECIBO RADIO HAIL — %s (TYPE 3: BINARY TRANSMISSION)" % p["name"]
			body = "Radio telescopes beamed '2, 3, 5, 7, 11, 13...' plus a Golden Record greeting: 'We see your Wheels on radar. Are we alone?'"
		4:
			hdr = "LASER INTERFEROMETER HAIL — %s (TYPE 2: DYSON ARRAY)" % p["name"]
			body = "Orbital Ring relays locked onto your signature: 'Architect of Eyes, share the ignition harmonic so we may forge our own Star.'"
		5:
			hdr = "GRAVITATIONAL COMMUNION — %s (TYPE 1: STAR-FORGERS)" % p["name"]
			body = "Their artificial sun hums in resonance with your rings: 'We have transcended dependency. Shall we seed the next galaxy together?'"

	active_comm = {"p_idx": p_idx, "timer": 22.0, "hdr": hdr}
	comm_hdr.text = hdr
	comm_body.text = body
	comm_panel.visible = true
	_spawn_signal_ring(p["body"].global_position, player_pos, Color(0.25, 0.96, 1.0))
	_record(p, "TRANSMISSION SENT TO UAP: " + hdr, false)

func respond_comm(choice: String, player_pos: Vector3) -> void:
	if active_comm.is_empty(): return
	var p = planets[active_comm["p_idx"]]
	active_comm.clear()
	comm_panel.visible = false
	if p["shattered"] or p["stage"] == 0: return

	var target: Vector3 = p["body"].global_position
	match choice:
		"reveal":
			_spawn_beam(player_pos, target, Color(1.0, 0.90, 0.35), 3.6)
			p["tech"] += 420.0; p["faith"] = minf(100.0, p["faith"] + 22.0); p["stability"] = minf(100.0, p["stability"] + 25.0)
			_record(p, "UAP RESPONDED WITH REVELATION! Golden harmonic wave decoded (+420 Tech, +22% Faith, Peace restored).")
			reward_granted.emit(450, 85, false)
		"riddle":
			_spawn_beam(player_pos, target, Color(0.74, 0.28, 1.0), 3.2)
			p["faith"] = minf(100.0, p["faith"] + 36.0); p["tech"] += 180.0
			_record(p, "UAP ANSWERED IN CRYPTIC PROPHECY! Scholars debate your sacred geometry for centuries (+36% Faith).")
			reward_granted.emit(350, 70, false)
		"silence":
			p["tech"] += 260.0; p["faith"] = maxf(0.0, p["faith"] - 14.0)
			_record(p, "UAP REMAINED SILENT! Determined to prove themselves, scientists double down on independent tech (+260 Tech).")
			reward_granted.emit(200, 45, false)

func shatter_nearest(player_pos: Vector3) -> void:
	if not active or nearest_idx < 0: return
	var p = planets[nearest_idx]
	if p["shattered"]:
		chronicle_event.emit("%s is already shattered! Hold [G] to siphon its debris!" % p["name"])
		return
	var surf_dist = nearest_dist - float(p["r"])
	if surf_dist > 175.0:
		chronicle_event.emit("Fly closer to %s (%dm away) to Shatter it!" % [p["name"], int(surf_dist)])
		return

	var center: Vector3 = p["body"].global_position
	var rad: float = p["r"]
	_spawn_beam(player_pos, center, Color(1.0, 0.18, 0.04), 5.5)

	p["shattered"] = true; p["stage"] = 0; p["tech"] = 0.0; p["pop"] = 0.0; p["megalith_built"] = false
	p["body"].visible = false; p["col"].disabled = true
	p["ring_piv"].visible = false; p["star_piv"].visible = false; p["mega_piv"].visible = false

	for i in 180:
		if debris_chunks.size() >= MAX_CHUNKS: debris_chunks.pop_front()
		var dir = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var col = p["land"].lerp(Color(1.0, 0.35, 0.06), randf() * 0.65)
		debris_chunks.append({
			"pos": center + dir * randf_range(4.0, rad * 0.95),
			"vel": dir * randf_range(14.0, 44.0),
			"rot": Vector3(randf() * TAU, randf() * TAU, randf() * TAU),
			"spin": Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2)),
			"sc": randf_range(0.7, 2.5), "col": col
		})
	for i in 280:
		if debris_motes.size() >= MAX_MOTES: debris_motes.pop_front()
		var dir = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var col = p["atmo"].lerp(Color(1.0, 0.85, 0.32), randf() * 0.6)
		debris_motes.append({
			"pos": center + dir * randf_range(2.0, rad * 1.1),
			"vel": dir * randf_range(16.0, 52.0),
			"sc": randf_range(0.5, 1.8), "col": col
		})

	_record(p, "PLANET ANNIHILATED! %s shattered into drifting crust and cosmic mote dust! Hold [G] to siphon!" % p["name"])
	reward_granted.emit(1200, 180, true)

func reforge_planet(player_pos: Vector3, cam_fwd: Vector3) -> void:
	if not active: return
	if stored_mass < 50.0:
		chronicle_event.emit("Need at least 50%% Planetary Mass to Re-Forge! Hold [G] near shattered debris (%d%% stored)." % int(stored_mass))
		return

	var target_p: Dictionary = {}
	for p in planets:
		if p["shattered"]:
			target_p = p; break
	if target_p.is_empty():
		chronicle_event.emit("All 8 worlds are intact! Shatter a planet [B] first to re-forge it.")
		return

	var expelled_mass = stored_mass
	var mass_mult = clampf(0.95 + (expelled_mass / 100.0) * 0.22, 1.0, 2.05)
	var spawn_dist = 110.0 + (expelled_mass / 100.0) * 28.0
	var spawn_pos = player_pos + cam_fwd.normalized() * spawn_dist
	spawn_pos.y = maxf(spawn_pos.y, 95.0)
	_spawn_beam(player_pos, spawn_pos, Color(1.0, 0.88, 0.35), 4.6)

	# Clear ALL stored mass and any straggling nearby debris so ZERO leftovers float around the UAP
	stored_mass = 0.0
	debris_chunks.clear()
	debris_motes.clear()
	mm_chunks.multimesh.visible_instance_count = 0
	mm_motes.multimesh.visible_instance_count = 0

	target_p["shattered"] = false
	target_p["body"].global_position = spawn_pos
	target_p["body"].visible = true
	target_p["col"].disabled = false
	target_p["reform_scale"] = 0.08
	target_p["target_scale"] = mass_mult
	target_p["mesh"].scale = Vector3.ONE * 0.08
	target_p["ruin_v"] = 1.0
	target_p["stage"] = 0; target_p["tech"] = 0.0; target_p["year"] = 0.0; target_p["stability"] = 100.0

	# Coalescing golden stream that fires FROM the UAP straight INTO the new planet and vanishes on impact
	for i in 18:
		var mi = MeshInstance3D.new()
		var sm = SphereMesh.new(); sm.radius = randf_range(1.1, 2.4); sm.height = sm.radius * 2.0; sm.radial_segments = 6; sm.rings = 3
		var emat = StandardMaterial3D.new(); emat.albedo_color = Color(1.0, 0.86, 0.34); emat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		emat.emission_enabled = true; emat.emission = Color(1.0, 0.72, 0.22); emat.emission_energy_multiplier = 4.5
		sm.material = emat; mi.mesh = sm; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var offset = Vector3(randf_range(-10, 10), randf_range(-10, 10), randf_range(-10, 10))
		mi.global_position = player_pos + offset
		add_child(mi)
		ejection_streams.append({"node": mi, "from": player_pos + offset, "to": spawn_pos, "t": 0.0, "spd": randf_range(1.2, 2.1)})

	_record(target_p, "WORLD RE-FORGED! Planetary dust ejected from UAP core — %s coalesces anew! Press [Z] to Seed!" % target_p["name"])
	reward_granted.emit(800, 140, false)

func interact_nearest(action: String, player_pos: Vector3) -> void:
	if not active or nearest_idx < 0: return
	var p = planets[nearest_idx]
	if p["shattered"]:
		chronicle_event.emit("%s is shattered! Hold [G] to vacuum its debris, then [N] to rebuild!" % p["name"])
		return
	var surf_dist = nearest_dist - float(p["r"])
	if surf_dist > 165.0:
		chronicle_event.emit("Fly closer to %s (%dm away) to intervene!" % [p["name"], int(surf_dist)])
		return

	var target = p["body"].global_position
	match action:
		"seed":
			_spawn_beam(player_pos, target, Color(0.25, 1.0, 0.55))
			if p["stage"] == 0:
				p["stage"] = 1; p["year"] = 1.0; p["pop"] = 1200.0; p["tech"] = 120.0; p["faith"] = 45.0; p["stability"] = 92.0; p["ruin_v"] = 0.0
				var bio = "Floating Sky-Colonies" if p["ptype"] == 1 else ("Sub-Ice Bioluminescent Tribes" if p["ptype"] == 2 else "Biosphere & First Tribes")
				_record(p, "LIFE SEEDED! %s awaken on %s (Type 5)." % [bio, p["name"]])
				reward_granted.emit(300, 60, false)
			else:
				p["tech"] += 480.0; p["stability"] = minf(100.0, p["stability"] + 15.0); p["faith"] = minf(100.0, p["faith"] + 14.0)
				_record(p, "GOLDEN MONOLITH BUILT! Tech surges +480 (Total: %d)." % int(p["tech"]))
				reward_granted.emit(250, 50, false)
		"teach":
			if p["stage"] == 0:
				chronicle_event.emit("%s is barren — press [Z] to Seed Life first!" % p["name"])
				return
			_spawn_beam(player_pos, target, Color(0.25, 0.92, 1.0))
			p["tech"] += 340.0; p["stability"] = minf(100.0, p["stability"] + 30.0); p["faith"] = minf(100.0, p["faith"] + 22.0)
			_record(p, "COSMIC GEOMETRY TAUGHT! Tech +340, Faith +22%%, Stability restored.")
			reward_granted.emit(200, 45, false)
		"smite":
			_spawn_beam(player_pos, target, Color(1.0, 0.22, 0.05))
			p["ruin_v"] = minf(1.0, p["ruin_v"] + 0.45)
			p["stability"] = maxf(0.0, p["stability"] - 48.0)
			p["pop"] *= 0.52
			p["faith"] = minf(100.0, p["faith"] + 30.0)
			if p["stage"] > 0 and p["stability"] <= 0.0:
				_trigger_extinction(p, "SMITTEN BY WRATHFUL UAP! Civilization reduced to ash.")
				reward_granted.emit(900, 140, true)
			else:
				_record(p, "HELLFIRE SMITE! Cities burn in terror (-48 Stability).")
				reward_granted.emit(350, 55, false)

func _trigger_extinction(p: Dictionary, reason: String) -> void:
	p["stage"] = 0; p["pop"] = 0.0; p["tech"] = 0.0; p["ruin_v"] = 1.0; p["megalith_built"] = false
	p["ring_piv"].visible = false; p["star_piv"].visible = false; p["mega_piv"].visible = false
	_record(p, "EXTINCTION: " + reason)

func _trigger_apparition(p: Dictionary) -> void:
	p["sighting_cd"] = 24.0
	var st: int = p["stage"]
	var msg := ""
	match st:
		1:
			p["faith"] = minf(100.0, p["faith"] + 26.0); p["tech"] += 220.0
			msg = "APPARITION: Children witnessed Burning Wheels of Eyes in the sky — Prophetic Faith founded!"
		2:
			p["faith"] = minf(100.0, p["faith"] + 22.0); p["tech"] += 280.0
			msg = "APPARITION: Sky-Chariot seen over the Great Temple — Megalithic astronomers carve your likeness!"
		3:
			p["tech"] += 340.0; p["stability"] = clampf(p["stability"] + (14.0 if p["faith"] > 50.0 else -10.0), 0.0, 100.0)
			msg = "MASS UAP SIGHTING: Millions film the Ophanim over the capital — Reverse-Engineering Race begins!"
		4:
			p["tech"] += 380.0; p["faith"] = minf(100.0, p["faith"] + 18.0)
			msg = "ORBITAL VISITATION: Dyson Ring sensors lock onto your Wheels — Stellar Ignition blueprint unlocked!"
		5:
			p["stability"] = 100.0; p["faith"] = minf(100.0, p["faith"] + 15.0)
			msg = "RETURN OF THE CREATOR: Star-Forger fleet salutes your passage (+$500 Tribute)!"
			reward_granted.emit(500, 90, true)
	_record(p, msg)

func _launch_war_fleet(attacker: Dictionary, defender: Dictionary) -> void:
	var start_p: Vector3 = attacker["body"].global_position
	var end_p: Vector3 = defender["body"].global_position
	var mi = MeshInstance3D.new()
	var m = SphereMesh.new(); m.radius = 2.4; m.height = 4.8; m.radial_segments = 8; m.rings = 4
	var mat = StandardMaterial3D.new(); mat.albedo_color = Color(1.0, 0.16, 0.25); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true; mat.emission = Color(1.0, 0.12, 0.35); mat.emission_energy_multiplier = 7.5
	m.material = mat; mi.mesh = m; mi.global_position = start_p
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

	var mid = (start_p + end_p) * 0.5 + Vector3(0, randf_range(35.0, 75.0), 0)
	war_fleets.append({"node": mi, "from": start_p, "mid": mid, "to": end_p, "attacker": attacker, "defender": defender, "t": 0.0})
	_record(attacker, "INTERPLANETARY WAR! %s launched orbital strike fleet at %s!" % [attacker["name"], defender["name"]], false)
	chronicle_event.emit("INTERPLANETARY WAR: %s fired plasma fleet at %s!" % [attacker["name"], defender["name"]])

func _stage_for_tech(t: float) -> int:
	if t >= 5000.0: return 5
	if t >= 3000.0: return 4
	if t >= 1500.0: return 3
	if t >= 500.0:  return 2
	return 1

func update_cosmos(delta: float, player_pos: Vector3, is_uap: bool, siphon_held := false) -> void:
	for i in range(beams.size() - 1, -1, -1):
		beams[i]["t"] -= delta
		if beams[i]["t"] <= 0.0: beams[i]["node"].queue_free(); beams.remove_at(i)

	for i in range(signal_rings.size() - 1, -1, -1):
		var sr = signal_rings[i]; sr["t"] -= delta
		sr["node"].global_position += sr["vel"] * delta
		sr["node"].scale += Vector3.ONE * delta * 1.4
		if sr["t"] <= 0.0: sr["node"].queue_free(); signal_rings.remove_at(i)

	for i in range(ejection_streams.size() - 1, -1, -1):
		var es = ejection_streams[i]
		es["t"] += delta * es["spd"]
		if es["t"] >= 1.0:
			es["node"].queue_free(); ejection_streams.remove_at(i)
		else:
			var et = es["t"] * es["t"]
			es["node"].global_position = es["from"].lerp(es["to"], et)
			es["node"].scale = Vector3.ONE * (1.0 - et * 0.65)

	if not active: return

	# Spin Neutron Pulsar polar jets
	for st in stars:
		if st["pulsar"] and st["jet_piv"]:
			st["jet_piv"].rotate_y(delta * 4.8)

	# Handle Active Incoming Communication Timer
	if not active_comm.is_empty():
		active_comm["timer"] -= delta
		if active_comm["timer"] <= 0.0:
			respond_comm("silence", player_pos)

	# 1. Update Katamari Debris & Mote Dust
	for list_idx in 2:
		var arr: Array[Dictionary] = debris_chunks if list_idx == 0 else debris_motes
		var mm: MultiMesh = mm_chunks.multimesh if list_idx == 0 else mm_motes.multimesh
		var mass_gain := 0.85 if list_idx == 0 else 0.38

		for i in range(arr.size() - 1, -1, -1):
			var d = arr[i]
			var to_uap = player_pos - d["pos"]
			var dist = to_uap.length()

			if siphon_held and dist < 2500.0:
				var pull_dir = to_uap.normalized() if dist > 0.1 else Vector3.UP
				var swirl = pull_dir.cross(Vector3.UP)
				if swirl.length() < 0.1: swirl = Vector3.RIGHT
				var pull_spd = lerpf(320.0, 110.0, clampf(dist / 900.0, 0.0, 1.0))
				d["vel"] = d["vel"].lerp(pull_dir * pull_spd + swirl.normalized() * (42.0 * clampf(dist / 120.0, 0.0, 1.0)), clampf(delta * 7.5, 0.0, 1.0))
				var cap_r = 9.5 + (stored_mass / 100.0) * 6.0
				if dist < cap_r:
					stored_mass = minf(500.0, stored_mass + mass_gain)
					arr.remove_at(i); continue
			else:
				d["vel"] = d["vel"].lerp(Vector3.ZERO, clampf(delta * 0.45, 0.0, 1.0))

			d["pos"] += d["vel"] * delta
			if list_idx == 0:
				d["rot"] += d["spin"] * delta
				mm.set_instance_transform(i, Transform3D(Basis.from_euler(d["rot"]).scaled(Vector3.ONE * d["sc"]), d["pos"]))
			else:
				mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * d["sc"]), d["pos"]))
			mm.set_instance_color(i, d["col"])
		mm.visible_instance_count = arr.size()

	# 2. Update Interplanetary War Fleets
	for i in range(war_fleets.size() - 1, -1, -1):
		var wf = war_fleets[i]
		wf["t"] += delta * 0.24
		var t: float = wf["t"]
		if t >= 1.0:
			var def: Dictionary = wf["defender"]
			if not def["shattered"] and def["stage"] > 0:
				def["stability"] = maxf(0.0, def["stability"] - 16.0)
				def["ruin_v"] = minf(0.85, def["ruin_v"] + 0.18)
				def["pop"] *= 0.88
				_record(def, "ORBITAL BOMBARDMENT from %s! Stability now %d%%." % [wf["attacker"]["name"], int(def["stability"])], false)
				if def["stability"] <= 0.0:
					_trigger_extinction(def, "CONQUERED & GLASSED by %s in Interplanetary War!" % wf["attacker"]["name"])
			wf["node"].queue_free(); war_fleets.remove_at(i)
		else:
			var a = wf["from"].lerp(wf["mid"], t)
			var b = wf["mid"].lerp(wf["to"], t)
			wf["node"].global_position = a.lerp(b, t)

	# 3. Update All 8 Worlds, Communications, Wars & Space Megaliths
	nearest_idx = -1; nearest_dist = 99999.0

	for i in planets.size():
		var p = planets[i]
		if p["shattered"]: continue

		var tgt_sc: float = p.get("target_scale", 1.0)
		if p["reform_scale"] < tgt_sc:
			p["reform_scale"] = minf(tgt_sc, p["reform_scale"] + delta * 0.85)
			p["mesh"].scale = Vector3.ONE * p["reform_scale"]

		p["mesh"].rotate_y(delta * 0.04)
		p["holo_inner"].rotate_y(-delta * 0.065)
		p["holo_outer"].rotate_y(delta * 0.028)
		p["holo_outer"].rotate_x(delta * 0.012)
		p["holo_inner"].scale = p["mesh"].scale
		p["holo_outer"].scale = p["mesh"].scale
		p["fleet_piv"].visible = (p["stage"] > 0 and not p["shattered"])
		if p["fleet_piv"].visible: p["fleet_piv"].rotate_y(delta * (0.28 + float(p["stage"]) * 0.12))
		if p["ring_piv"].visible: p["ring_piv"].rotate_y(delta * 0.16)
		if p["star_piv"].visible: p["star_piv"].rotate_y(delta * 0.28)
		if p["mega_piv"].visible:
			p["mega_piv"].rotate_y(-delta * 0.10)
			if p["mega_piv"].scale.x < 1.0:
				p["mega_piv"].scale = p["mega_piv"].scale.lerp(Vector3.ONE, clampf(delta * 0.9, 0.0, 1.0))

		if p["sighting_cd"] > 0.0: p["sighting_cd"] -= delta
		if p["stage"] == 0: p["ruin_v"] = maxf(0.0, p["ruin_v"] - delta * 0.14)

		var dist = player_pos.distance_to(p["body"].global_position)
		if dist < nearest_dist:
			nearest_dist = dist; nearest_idx = i

		var st: int = p["stage"]
		if st > 0:
			p["year"] += delta * 6.0
			var growth = (36.0 + float(st) * 26.0) * (0.55 + p["stability"] / 150.0)
			p["tech"] += delta * growth
			p["pop"] = minf(99000000000.0, p["pop"] * (1.0 + delta * 0.05))
			p["ruin_v"] = maxf(0.0, p["ruin_v"] - delta * 0.03)

			# Passive Apparition Sighting when swinging by in Biblical UAP form
			if is_uap and dist < (float(p["r"]) + 68.0) and p["sighting_cd"] <= 0.0:
				_trigger_apparition(p)

			# Civilization Communication Attempt (Earth-History Style Hails)
			p["comm_cd"] -= delta
			if p["comm_cd"] <= 0.0 and active_comm.is_empty():
				p["comm_cd"] = randf_range(26.0, 42.0)
				_trigger_comm_attempt(i, player_pos)

			# Tech 2000+ Interplanetary Warfare
			if p["tech"] >= 2000.0:
				p["war_cd"] -= delta
				if p["war_cd"] <= 0.0:
					p["war_cd"] = randf_range(12.0, 20.0)
					var rivals: Array[Dictionary] = []
					for other in planets:
						if other != p and not other["shattered"] and other["stage"] > 0:
							rivals.append(other)
					if not rivals.is_empty():
						_launch_war_fleet(p, rivals[randi() % rivals.size()])

			# Atomic Extinction Crisis (Type 3)
			if st == 3:
				p["stability"] = maxf(0.0, p["stability"] - delta * 1.15)
				p["crisis_cd"] -= delta
				if p["stability"] < 28.0 and p["crisis_cd"] <= 0.0:
					p["crisis_cd"] = 14.0
					_record(p, "WARNING: Atomic Tension critical! Swing by or Teach [X] to prevent Extinction!")
				if p["stability"] <= 0.0:
					_trigger_extinction(p, "ATOMIC SELF-DESTRUCTION! They failed the Great Filter.")

			var target_st = _stage_for_tech(p["tech"])
			if target_st > st:
				p["stage"] = target_st
				if target_st == 4:
					p["ring_piv"].visible = true
					_record(p, "ASCENDED TO TYPE 2! Orbital Dyson Ring constructed around %s!" % p["name"])
					reward_granted.emit(600, 120, true)
				elif target_st == 5:
					p["star_piv"].visible = true
					_record(p, "TYPE 1 STAR-FORGER ACHIEVED! %s ignited its own Artificial Star!" % p["name"])
					reward_granted.emit(1500, 260, true)
				else:
					_record(p, "ERA ADVANCE: Reached %s!" % STAGE_NAMES[target_st])
					reward_granted.emit(350, 80, false)

			if p["tech"] >= 5000.0 and p["faith"] >= 70.0 and not p["megalith_built"]:
				p["megalith_built"] = true
				p["mega_piv"].visible = true
				p["mega_piv"].scale = Vector3.ONE * 0.08
				_record(p, "SPACE MEGALITHS CONSTRUCTED! Devout Star-Forgers raised Cosmic Pyramids & Astral Gates in orbit!")
				reward_granted.emit(2000, 350, true)

		var t_life = 0.0 if p["stage"] == 0 else clampf(0.35 + float(p["stage"]) * 0.16, 0.0, 1.0)
		var t_civ  = 0.0 if p["stage"] < 2 else clampf(float(p["stage"] - 1) * 0.25, 0.0, 1.0)
		p["life_v"] = lerpf(p["life_v"], t_life, clampf(delta * 1.4, 0.0, 1.0))
		p["civ_v"]  = lerpf(p["civ_v"],  t_civ,  clampf(delta * 1.4, 0.0, 1.0))
		p["mat"].set_shader_parameter("life_level", p["life_v"])
		p["mat"].set_shader_parameter("civ_level",  p["civ_v"])
		p["mat"].set_shader_parameter("ruin_level", p["ruin_v"])

		var war_tag = " [WAR]" if p["tech"] >= 2000.0 else ""
		var mega_tag = " [MEGALITHS]" if p["megalith_built"] else ""
		p["label"].text = "%s (%s)\n%s%s%s%s" % [
			p["name"], p["kind"], STAGE_NAMES[p["stage"]], war_tag, mega_tag,
			("\nTech:%d  Stab:%d%%  Faith:%d%%" % [int(p["tech"]), int(p["stability"]), int(p["faith"])]) if p["stage"] > 0 else "\n[Press Z to Seed | B to Shatter]"
		]

	if nearest_idx >= 0:
		var np = planets[nearest_idx]
		var sd = maxf(0.0, nearest_dist - float(np["r"]))
		if sd <= 165.0:
			planet_bar.text = "ORBITING %s (%s) — [C] Discourse | [Z] %s | [X] Teach | [V] Smite | [B] Shatter | [H] Log" % [
				np["name"], np["kind"], "Seed Life" if np["stage"] == 0 else "Build Monolith"
			]
		else:
			planet_bar.text = "NEAREST WORLD: %s (%s, %dm) — Fly closer in Biblical UAP form | [H] Chronicle" % [np["name"], np["kind"], int(sd)]
	else:
		planet_bar.text = "ALL WORLDS SHATTERED! Hold [G] to vacuum planetary dust, then press [N] to Re-Forge!"

	var ready_str = " [PRESS N TO SPIT OUT & RE-FORGE PLANET!]" if stored_mass >= 50.0 else " (Hold [G] near shattered debris to Katamari-siphon)"
	mass_bar.text = "UAP CORE MASS: %d%% / 500%% (%.1f PLANETS) | DEBRIS: %d%s" % [int(stored_mass), stored_mass / 100.0, debris_chunks.size() + debris_motes.size(), ready_str]

	if chron_panel.visible: _refresh_chronicle()

func _refresh_chronicle() -> void:
	if nearest_idx < 0: return
	var p = planets[nearest_idx]
	chron_title.text = "%s (%s) — %s" % [p["name"], p["kind"], STAGE_NAMES[p["stage"]]]
	chron_stats.text = "Year: %d | Tech: %d | Stab: %d%% | Faith: %d%% | Megaliths: %s" % [
		int(p["year"]), int(p["tech"]), int(p["stability"]), int(p["faith"]),
		"BUILT IN ORBIT" if p["megalith_built"] else "Need 5000 Tech + 70% Faith"
	]
	chron_log.text = "\n".join(p["history"])

func get_nearest_inhabited() -> Dictionary:
	if nearest_idx >= 0:
		var p = planets[nearest_idx]
		if not p["shattered"] and p["stage"] > 0:
			return p
	for p in planets:
		if not p["shattered"] and p["stage"] > 0:
			return p
	return {}

func apply_discourse_impact(p_name: String, d_tech: float, d_faith: float, d_stab: float, note: String) -> void:
	for p in planets:
		if p["name"] == p_name and not p["shattered"] and p["stage"] > 0:
			p["tech"] += d_tech
			p["faith"] = clampf(p["faith"] + d_faith, 0.0, 100.0)
			p["stability"] = clampf(p["stability"] + d_stab, 0.0, 100.0)
			_record(p, "DISCOURSE: " + note)
			break

func regenerate_sector(u_id: int, s_seed: int, origin: Vector3) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = u_id * 9973 + s_seed * 31
	var prefixes = ["AURA", "ZION", "KAIROS", "HYPER", "NEXUS", "SOLIS", "ASTRA", "ORION", "VALA", "CHRONO", "ELYS", "VEX"]
	var suffixes = ["PRIME", "IX", "VII", "MAJOR", "OMEGA", "NOVA", "CORE", "REACH", "V", "ALPHA", "DRIFT", "CROWN"]
	for i in planets.size():
		var p = planets[i]
		p["name"] = "%s-%s-%d" % [prefixes[rng.randi() % prefixes.size()], suffixes[rng.randi() % suffixes.size()], u_id]
		p["shattered"] = false
		p["body"].visible = true; p["col"].disabled = false
		p["stage"] = 0; p["tech"] = 0.0; p["year"] = 0.0; p["faith"] = 0.0; p["stability"] = 100.0
		p["life_v"] = 0.0; p["civ_v"] = 0.0; p["ruin_v"] = 0.0; p["megalith_built"] = false
		p["ring_piv"].visible = false; p["star_piv"].visible = false; p["mega_piv"].visible = false; p["fleet_piv"].visible = false
		var ang = (TAU * float(i) / float(planets.size())) + rng.randf_range(-0.25, 0.25)
		var rad_d = rng.randf_range(210.0, 520.0)
		var y_h = rng.randf_range(175.0, 360.0)
		p["body"].global_position = Vector3(origin.x + cos(ang) * rad_d, y_h, origin.z + sin(ang) * rad_d)
		var n_atmo = Color.from_hsv(rng.randf(), 0.78, 1.0)
		var n_land = Color.from_hsv(rng.randf(), 0.62, 0.65)
		var n_sea  = Color.from_hsv(rng.randf(), 0.74, 0.45)
		p["atmo"] = n_atmo; p["land"] = n_land
		p["mat"].set_shader_parameter("planet_seed", rng.randf_range(1.0, 48.0))
		p["mat"].set_shader_parameter("atmo_color", n_atmo)
		p["holo_in_mat"].set_shader_parameter("atmo_color", n_atmo)
		p["holo_out_mat"].set_shader_parameter("atmo_color", n_atmo)
		p["mat"].set_shader_parameter("land_color", n_land)
		p["mat"].set_shader_parameter("ocean_color", n_sea)
		p["history"] = ["%s discovered in Universe #%d." % [p["name"], u_id]]
