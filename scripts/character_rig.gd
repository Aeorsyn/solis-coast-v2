extends Node3D
class_name CharacterRig

var hips: Node3D; var torso: Node3D; var head: Node3D
var arm_l: Node3D; var fore_l: Node3D
var arm_r: Node3D; var fore_r: Node3D
var leg_l: Node3D; var shin_l: Node3D
var leg_r: Node3D; var shin_r: Node3D
var gun_root: Node3D; var rifle_mesh: Node3D
var torso_mat: StandardMaterial3D; var sleeve_mat: StandardMaterial3D
var skin_mat_ref: StandardMaterial3D; var pants_mat_ref: StandardMaterial3D; var hair_mat_ref: StandardMaterial3D
var shades_node: MeshInstance3D = null; var aura_light: OmniLight3D = null
var custom_glb_node: Node3D = null
var custom_anim: AnimationPlayer = null
var custom_clips := {}
var anim_phase := 0.0; var idle_time := 0.0
var is_detailed_hero := false

static func _make_raglan_tex(base_col: Color, detailed := false) -> ImageTexture:
	var img = Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(base_col)
	var accent = Color(0.68, 0.24, 0.16)
	var ink = Color(0.24, 0.14, 0.12)
	for y in range(12, 36):
		for x in range(20, 44):
			var d = Vector2(x - 32, y - 24).length()
			if d < 10.0 and d > 5.5:
				img.set_pixel(x, y, base_col.lerp(accent, 0.72))
			elif d <= 5.5:
				img.set_pixel(x, y, base_col.lerp(Color(0.85, 0.56, 0.32), 0.60))
	for row in [38, 42, 46, 50]:
		for x in range(22, 42):
			if (x + row) % 3 != 0:
				img.set_pixel(x, row, base_col.lerp(ink, 0.62))
	if detailed:
		# Subtle tactical stitching & shoulder seam lines for hero detail
		for y in range(64):
			img.set_pixel(14, y, base_col.darkened(0.22))
			img.set_pixel(49, y, base_col.darkened(0.22))
	return ImageTexture.create_from_image(img)

func setup(shirt_col: Color, pants_col: Color, with_shades := false, glb_path := "", sleeve_col := Color(-1, -1, -1), detailed := false) -> void:
	is_detailed_hero = detailed
	if not glb_path.is_empty() and FileAccess.file_exists(glb_path):
		var gltf = GLTFDocument.new(); var st = GLTFState.new()
		if gltf.append_from_buffer(FileAccess.get_file_as_bytes(glb_path), "", st) == OK:
			custom_glb_node = gltf.generate_scene(st)
			if custom_glb_node != null:
				add_child(custom_glb_node)
				_normalize_glb_avatar(custom_glb_node)
				return

	var s_col = sleeve_col if sleeve_col.r >= 0.0 else shirt_col.darkened(0.68)
	torso_mat = StandardMaterial3D.new()
	torso_mat.albedo_texture = _make_raglan_tex(shirt_col, detailed)
	torso_mat.roughness = 0.68
	sleeve_mat = StandardMaterial3D.new(); sleeve_mat.albedo_color = s_col; sleeve_mat.roughness = 0.72
	var pants_mat = StandardMaterial3D.new(); pants_mat_ref = pants_mat; pants_mat.albedo_color = pants_col; pants_mat.roughness = 0.78
	var skin_mat = StandardMaterial3D.new(); skin_mat_ref = skin_mat; skin_mat.albedo_color = Color(0.84, 0.64, 0.52); skin_mat.roughness = 0.50
	var shoe_mat = StandardMaterial3D.new(); shoe_mat.albedo_color = Color(0.09, 0.09, 0.11); shoe_mat.roughness = 0.36
	var hair_mat = StandardMaterial3D.new(); hair_mat_ref = hair_mat; hair_mat.albedo_color = Color(0.16, 0.12, 0.10); hair_mat.roughness = 0.80

	hips = Node3D.new(); add_child(hips)

	var pelv = MeshInstance3D.new(); var pm = SphereMesh.new(); pm.radius = 0.205; pm.height = 0.29; pm.material = pants_mat
	pelv.mesh = pm; pelv.scale = Vector3(1.08, 0.84, 0.76); pelv.position = Vector3(0, 0.02, 0); hips.add_child(pelv)

	if detailed:
		# Tactical belt & holster on hero
		var belt = MeshInstance3D.new(); var bm = CylinderMesh.new(); bm.top_radius = 0.195; bm.bottom_radius = 0.19; bm.height = 0.07
		var bmat = StandardMaterial3D.new(); bmat.albedo_color = Color(0.12, 0.12, 0.14); bmat.roughness = 0.4; bm.material = bmat
		belt.mesh = bm; belt.scale = Vector3(1.06, 1.0, 0.74); belt.position = Vector3(0, 0.09, 0); hips.add_child(belt)

	torso = Node3D.new(); torso.position = Vector3(0, 0.08, 0); hips.add_child(torso)
	var waist = MeshInstance3D.new(); var wm = CylinderMesh.new(); wm.top_radius = 0.215; wm.bottom_radius = 0.178; wm.height = 0.28; wm.material = torso_mat
	waist.mesh = wm; waist.scale = Vector3(1.06, 1.0, 0.72); waist.position = Vector3(0, 0.14, 0); torso.add_child(waist)

	var chest = MeshInstance3D.new(); var chm = SphereMesh.new(); chm.radius = 0.252; chm.height = 0.46; chm.material = torso_mat
	chest.mesh = chm; chest.scale = Vector3(1.16, 0.98, 0.70); chest.position = Vector3(0, 0.39, 0.01); torso.add_child(chest)

	if detailed:
		# Pectoral / upper chest & shoulder armor/strap detail
		var strap = MeshInstance3D.new(); var stm = BoxMesh.new(); stm.size = Vector3(0.055, 0.58, 0.36)
		var stmat = StandardMaterial3D.new(); stmat.albedo_color = Color(0.14, 0.14, 0.16); stmat.roughness = 0.45; stm.material = stmat
		strap.mesh = stm; strap.position = Vector3(0.06, 0.34, 0.0); strap.rotation_degrees.z = 26.0; torso.add_child(strap)

	var traps = MeshInstance3D.new(); var trm = CylinderMesh.new(); trm.top_radius = 0.11; trm.bottom_radius = 0.245; trm.height = 0.14; trm.material = sleeve_mat
	traps.mesh = trm; traps.scale = Vector3(1.14, 1.0, 0.68); traps.position = Vector3(0, 0.58, -0.01); torso.add_child(traps)

	for sx in [-0.275, 0.275]:
		var sh = MeshInstance3D.new(); var sm = SphereMesh.new(); sm.radius = 0.108; sm.height = 0.216; sm.material = sleeve_mat
		sh.mesh = sm; sh.scale = Vector3(1.02, 1.06, 0.96); sh.position = Vector3(sx, 0.51, 0.0); torso.add_child(sh)

	var neck = MeshInstance3D.new(); var nm = CylinderMesh.new(); nm.top_radius = 0.066; nm.bottom_radius = 0.078; nm.height = 0.15; nm.material = skin_mat
	neck.mesh = nm; neck.position = Vector3(0, 0.64, 0.01); torso.add_child(neck)

	head = Node3D.new(); head.position = Vector3(0, 0.71, 0.01); torso.add_child(head)
	var skull = MeshInstance3D.new(); var skm = SphereMesh.new(); skm.radius = 0.15; skm.height = 0.32; skm.material = skin_mat
	skull.mesh = skm; skull.scale = Vector3(0.88, 1.04, 0.98); skull.position = Vector3(0, 0.14, 0.01); head.add_child(skull)
	var jaw = MeshInstance3D.new(); var jm = SphereMesh.new(); jm.radius = 0.106; jm.height = 0.18; jm.material = skin_mat
	jaw.mesh = jm; jaw.scale = Vector3(0.86, 0.95, 0.95); jaw.position = Vector3(0, 0.06, 0.045); head.add_child(jaw)

	var h_top = MeshInstance3D.new(); var ht = SphereMesh.new(); ht.radius = 0.165; ht.height = 0.25; ht.material = hair_mat
	h_top.mesh = ht; h_top.scale = Vector3(0.98, 0.88, 1.08); h_top.position = Vector3(0, 0.20, -0.02); head.add_child(h_top)
	var h_back = MeshInstance3D.new(); var hb = SphereMesh.new(); hb.radius = 0.15; hb.height = 0.22; hb.material = hair_mat
	h_back.mesh = hb; h_back.scale = Vector3(1.02, 0.95, 0.88); h_back.position = Vector3(0, 0.12, -0.065); head.add_child(h_back)
	for ex in [-0.128, 0.128]:
		var side_h = MeshInstance3D.new(); var shm = CapsuleMesh.new(); shm.radius = 0.048; shm.height = 0.18; shm.material = hair_mat
		side_h.mesh = shm; side_h.position = Vector3(ex, 0.15, -0.01); side_h.rotation_degrees.x = 18.0; head.add_child(side_h)

	if with_shades:
		var g = MeshInstance3D.new(); var gm = BoxMesh.new(); gm.size = Vector3(0.22, 0.052, 0.07)
		var gmat = StandardMaterial3D.new(); gmat.albedo_color = Color(0.04, 0.05, 0.08); gmat.metallic = 0.9; gmat.roughness = 0.08; gm.material = gmat
		g.mesh = gm; g.position = Vector3(0, 0.15, 0.13); head.add_child(g); shades_node = g

	var l_arm = _make_arm(Vector3(-0.285, 0.50, 0), sleeve_mat, skin_mat)
	arm_l = l_arm[0]; fore_l = l_arm[1]; torso.add_child(arm_l)
	var r_arm = _make_arm(Vector3( 0.285, 0.50, 0), sleeve_mat, skin_mat)
	arm_r = r_arm[0]; fore_r = r_arm[1]; torso.add_child(arm_r)

	# Detailed 30-Round Assault Rifle mounted in hands
	gun_root = Node3D.new(); gun_root.position = Vector3(-0.02, -0.27, 0.06); fore_r.add_child(gun_root)
	rifle_mesh = _build_30rnd_rifle(detailed)
	gun_root.add_child(rifle_mesh)

	var l_leg = _make_leg(Vector3(-0.115, -0.04, 0), pants_mat, shoe_mat)
	leg_l = l_leg[0]; shin_l = l_leg[1]; hips.add_child(leg_l)
	var r_leg = _make_leg(Vector3( 0.115, -0.04, 0), pants_mat, shoe_mat)
	leg_r = r_leg[0]; shin_r = r_leg[1]; hips.add_child(leg_r)

func _build_30rnd_rifle(detailed: bool) -> Node3D:
	var r = Node3D.new()
	var dark = StandardMaterial3D.new(); dark.albedo_color = Color(0.11, 0.12, 0.14); dark.metallic = 0.88; dark.roughness = 0.24
	var tan = StandardMaterial3D.new(); tan.albedo_color = Color(0.58, 0.45, 0.34); tan.roughness = 0.50
	var mag_mat = StandardMaterial3D.new(); mag_mat.albedo_color = Color(0.16, 0.17, 0.20); mag_mat.metallic = 0.75; mag_mat.roughness = 0.32
	var scale_f = 1.18 if detailed else 0.85

	# Upper/Lower Receiver + Stock + Handguard + Barrel + 30-Round Curved Mag + Red-Dot Optic
	_part(r, Vector3(0.068, 0.105, 0.42) * scale_f, Vector3(0, 0.03, 0.14) * scale_f, tan)
	_part(r, Vector3(0.058, 0.095, 0.24) * scale_f, Vector3(0, 0.035, -0.14) * scale_f, dark) # Buttstock
	_part(r, Vector3(0.062, 0.075, 0.28) * scale_f, Vector3(0, 0.04, 0.42) * scale_f, dark)  # Quad-rail handguard
	_part(r, Vector3(0.028, 0.028, 0.22) * scale_f, Vector3(0, 0.045, 0.62) * scale_f, dark)  # Barrel & flash hider
	_part(r, Vector3(0.046, 0.19, 0.075) * scale_f,  Vector3(0, -0.08, 0.20) * scale_f, mag_mat) # 30-round magazine
	_part(r, Vector3(0.048, 0.052, 0.085) * scale_f, Vector3(0, 0.105, 0.12) * scale_f, dark)  # Holographic optic
	if detailed:
		_part(r, Vector3(0.032, 0.032, 0.08) * scale_f, Vector3(0.042, 0.04, 0.46) * scale_f, dark) # Side laser/light module
	return r

func _part(p: Node3D, sz: Vector3, pos: Vector3, mat: Material) -> void:
	var mi = MeshInstance3D.new(); var bm = BoxMesh.new(); bm.size = sz; bm.material = mat
	mi.mesh = bm; mi.position = pos; p.add_child(mi)

func _make_arm(piv_pos: Vector3, slv_mat: Material, sk_mat: Material) -> Array[Node3D]:
	var upper = Node3D.new(); upper.position = piv_pos
	var um = MeshInstance3D.new(); var uc = CapsuleMesh.new(); uc.radius = 0.068; uc.height = 0.31; uc.material = slv_mat
	um.mesh = uc; um.position = Vector3(0, -0.14, 0); upper.add_child(um)

	var elbow = Node3D.new(); elbow.position = Vector3(0, -0.28, 0); upper.add_child(elbow)
	var cuff = MeshInstance3D.new(); var cc = CylinderMesh.new(); cc.top_radius = 0.064; cc.bottom_radius = 0.056; cc.height = 0.11; cc.material = slv_mat
	cuff.mesh = cc; cuff.position = Vector3(0, -0.04, 0); elbow.add_child(cuff)
	var fm = MeshInstance3D.new(); var fc = CapsuleMesh.new(); fc.radius = 0.050; fc.height = 0.24; fc.material = sk_mat
	fm.mesh = fc; fm.position = Vector3(0, -0.16, 0); elbow.add_child(fm)
	var hand = MeshInstance3D.new(); var hm = SphereMesh.new(); hm.radius = 0.050; hm.height = 0.10; hm.material = sk_mat
	hand.mesh = hm; hand.scale = Vector3(0.85, 1.15, 0.95); hand.position = Vector3(0, -0.29, 0.02); elbow.add_child(hand)
	return [upper, elbow]

func _make_leg(piv_pos: Vector3, p_mat: Material, sh_mat: Material) -> Array[Node3D]:
	var thigh = Node3D.new(); thigh.position = piv_pos
	var tm = MeshInstance3D.new(); var tc = CapsuleMesh.new(); tc.radius = 0.094; tc.height = 0.44; tc.material = p_mat
	tm.mesh = tc; tm.position = Vector3(0, -0.20, 0); thigh.add_child(tm)

	var knee = Node3D.new(); knee.position = Vector3(0, -0.40, 0); thigh.add_child(knee)
	var sm = MeshInstance3D.new(); var sc = CapsuleMesh.new(); sc.radius = 0.074; sc.height = 0.42; sc.material = p_mat
	sm.mesh = sc; sm.position = Vector3(0, -0.19, 0); knee.add_child(sm)
	var shoe = MeshInstance3D.new(); var bm = BoxMesh.new(); bm.size = Vector3(0.118, 0.098, 0.24); bm.material = sh_mat
	shoe.mesh = bm; shoe.position = Vector3(0, -0.40, 0.045); knee.add_child(shoe)
	return [thigh, knee]

func set_shirt_color(col: Color) -> void:
	if torso_mat: torso_mat.albedo_texture = _make_raglan_tex(col, is_detailed_hero)
	if sleeve_mat: sleeve_mat.albedo_color = col.darkened(0.68)

func animate(move_speed: float, is_sprinting: bool, is_aiming: bool, delta: float) -> void:
	if custom_glb_node != null:
		idle_time += delta
		if custom_anim != null and not custom_clips.is_empty():
			var target_clip = custom_clips.get("idle", "")
			if is_aiming and custom_clips.has("aim"): target_clip = custom_clips["aim"]
			elif move_speed > 8.0 and custom_clips.has("run"): target_clip = custom_clips["run"]
			elif move_speed > 0.3 and custom_clips.has("walk"): target_clip = custom_clips["walk"]
			if not target_clip.is_empty() and custom_anim.current_animation != target_clip:
				custom_anim.play(target_clip, 0.2)
		else:
			var bob = abs(sin(idle_time * (10.0 if is_sprinting else 7.0))) * 0.045 if move_speed > 0.3 else sin(idle_time * 2.2) * 0.01
			custom_glb_node.position.y = custom_glb_node.get_meta("base_y", -0.84) + bob
		return

	idle_time += delta
	var spd_l = clampf(delta * 12.0, 0.0, 1.0)

	if move_speed > 0.3:
		var freq = 11.2 if is_sprinting else 7.6
		var amp = 0.78 if is_sprinting else 0.48
		anim_phase += delta * freq
		var sw = sin(anim_phase) * amp
		leg_l.rotation.x = sw; leg_r.rotation.x = -sw
		shin_l.rotation.x = maxf(0.0, -sw * 0.95)
		shin_r.rotation.x = maxf(0.0,  sw * 0.95)
		hips.position.y = abs(cos(anim_phase)) * (0.07 if is_sprinting else 0.04)
	else:
		leg_l.rotation.x = lerpf(leg_l.rotation.x, 0.0, spd_l)
		leg_r.rotation.x = lerpf(leg_r.rotation.x, 0.0, spd_l)
		shin_l.rotation.x = lerpf(shin_l.rotation.x, 0.0, spd_l)
		shin_r.rotation.x = lerpf(shin_r.rotation.x, 0.0, spd_l)
		hips.position.y = sin(idle_time * 2.2) * 0.015

	if is_aiming:
		torso.rotation.x = lerpf(torso.rotation.x, 0.12, spd_l)
		torso.rotation.y = lerpf(torso.rotation.y, 0.26, spd_l)
		head.rotation.y  = lerpf(head.rotation.y, -0.24, spd_l)
		head.rotation.z  = lerpf(head.rotation.z, 0.08, spd_l)
		arm_r.rotation   = arm_r.rotation.lerp(Vector3(-1.32, -0.22, 0.14), spd_l)
		fore_r.rotation  = fore_r.rotation.lerp(Vector3(-0.36, 0.0, 0.0), spd_l)
		arm_l.rotation   = arm_l.rotation.lerp(Vector3(-1.12, 0.68, -0.28), spd_l)
		fore_l.rotation  = fore_l.rotation.lerp(Vector3(-0.82, 0.0, 0.0), spd_l)
		gun_root.rotation = gun_root.rotation.lerp(Vector3(1.54, 0.16, 0.0), spd_l)
	else:
		var sw = sin(anim_phase) * (0.65 if is_sprinting else 0.42) if move_speed > 0.3 else 0.0
		torso.rotation.x = lerpf(torso.rotation.x, 0.14 if is_sprinting else 0.03, spd_l)
		torso.rotation.y = lerpf(torso.rotation.y, sw * 0.12, spd_l)
		head.rotation.y  = lerpf(head.rotation.y, 0.0, spd_l)
		head.rotation.z  = lerpf(head.rotation.z, 0.0, spd_l)
		arm_l.rotation   = arm_l.rotation.lerp(Vector3(-sw, 0.0, -0.06), spd_l)
		fore_l.rotation  = fore_l.rotation.lerp(Vector3(-0.22 - maxf(0.0, sw * 0.5), 0.0, 0.0), spd_l)
		arm_r.rotation   = arm_r.rotation.lerp(Vector3( sw, 0.0,  0.06), spd_l)
		fore_r.rotation  = fore_r.rotation.lerp(Vector3(-0.22 - maxf(0.0, -sw * 0.5), 0.0, 0.0), spd_l)
		gun_root.rotation = gun_root.rotation.lerp(Vector3(0.0, 0.0, 0.0), spd_l)

func apply_profile(prof: Dictionary) -> void:
	if custom_glb_node != null: return
	if torso_mat and prof.has("shirt"): torso_mat.albedo_texture = _make_raglan_tex(Color.html(prof["shirt"]), is_detailed_hero)
	if sleeve_mat and prof.has("sleeve"): sleeve_mat.albedo_color = Color.html(prof["sleeve"])
	if pants_mat_ref and prof.has("pants"): pants_mat_ref.albedo_color = Color.html(prof["pants"])
	if skin_mat_ref and prof.has("skin"): skin_mat_ref.albedo_color = Color.html(prof["skin"])
	if hair_mat_ref and prof.has("hair"): hair_mat_ref.albedo_color = Color.html(prof["hair"])
	if shades_node != null and prof.has("shades"): shades_node.visible = bool(prof["shades"])
	var h_sc = float(prof.get("height", 1.0))
	var b_sc = float(prof.get("build", 1.0))
	scale = Vector3(b_sc, h_sc, b_sc)

func set_infernal_aura(enabled: bool) -> void:
	if aura_light == null:
		aura_light = OmniLight3D.new(); aura_light.position = Vector3(0, 0.5, 0)
		aura_light.light_color = Color(1.0, 0.38, 0.08); aura_light.light_energy = 3.2; aura_light.omni_range = 6.5
		add_child(aura_light)
	aura_light.visible = enabled

func _normalize_glb_avatar(root: Node3D) -> void:
	var has_skel := false
	var bounds := AABB(); var has_b := false
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var pair = stack.pop_back()
		var n: Node = pair[0]; var xf: Transform3D = pair[1]
		if n != root and n is Node3D: xf = xf * (n as Node3D).transform
		if n is Skeleton3D: has_skel = true
		if n is AnimationPlayer and custom_anim == null:
			custom_anim = n
			for aname in custom_anim.get_animation_list():
				var low = str(aname).to_lower()
				if "idle" in low or "stand" in low: custom_clips["idle"] = aname
				elif "run" in low or "sprint" in low: custom_clips["run"] = aname
				elif "walk" in low: custom_clips["walk"] = aname
				elif "aim" in low or "rifle" in low or "shoot" in low: custom_clips["aim"] = aname
		if n is MeshInstance3D and n.mesh != null:
			var a = xf * n.mesh.get_aabb()
			bounds = a if not has_b else bounds.merge(a)
			has_b = true
		for c in n.get_children(): stack.append([c, xf])

	# Rigged Mixamo/glTF characters (Xbot, Michelle) are already authored upright in meters
	if has_skel:
		root.rotation = Vector3.ZERO
		root.scale = Vector3.ONE
		root.position = Vector3(0.0, -0.86, 0.0)
		root.set_meta("base_y", -0.86)
		return

	# Static 3D scans (TripoSR / Polycam): scale safely to 1.78m
	if has_b and bounds.size.y > 0.05:
		var sc = clampf(1.78 / bounds.size.y, 0.01, 4.0)
		root.scale = Vector3.ONE * sc
		var base_y = -0.86 - (bounds.position.y * sc)
		root.position = Vector3(0.0, base_y, 0.0)
		root.set_meta("base_y", base_y)
