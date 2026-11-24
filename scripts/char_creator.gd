extends PanelContainer
class_name CharacterCreatorUI

var profile := {
	"name": "VANCE", "shirt": "#e0ded6", "sleeve": "#1f1f24",
	"pants": "#242938", "skin": "#d6a385", "hair": "#291f1a",
	"height": 1.0, "build": 1.0, "shades": true
}
const SAVE_PATH := "user://character_profile.json"
signal profile_updated(prof: Dictionary)
signal closed()

var name_edit: LineEdit

func _ready() -> void:
	_load_profile()
	set_anchors_preset(Control.PRESET_CENTER_LEFT)
	offset_left = 18; offset_top = -255; offset_right = 330; offset_bottom = 255
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.13, 0.92); sb.border_color = Color(0.28, 0.88, 1.0, 0.85)
	sb.set_border_width_all(2); sb.set_corner_radius_all(12)
	sb.content_margin_left = 14; sb.content_margin_right = 14; sb.content_margin_top = 12; sb.content_margin_bottom = 12
	add_theme_stylebox_override("panel", sb)
	visible = false

	var vb = VBoxContainer.new(); vb.add_theme_constant_override("separation", 8); add_child(vb)
	var hdr = Label.new(); hdr.text = "CHARACTER CREATOR [K]"; hdr.add_theme_font_size_override("font_size", 18); hdr.modulate = Color(0.35, 0.92, 1.0); vb.add_child(hdr)

	# Name
	name_edit = LineEdit.new(); name_edit.text = profile["name"]; name_edit.placeholder_text = "Hero Name"
	name_edit.text_changed.connect(func(t): profile["name"] = t.strip_edges().to_upper() if not t.strip_edges().is_empty() else "VANCE"; _emit_save())
	vb.add_child(name_edit)

	# Swatch Rows
	_add_swatches(vb, "Skin Tone", "skin", ["#f2cbb4", "#d6a385", "#a87050", "#6e422c", "#3e2418"])
	_add_swatches(vb, "Hair Color", "hair", ["#291f1a", "#0e0e12", "#8f5c2c", "#d6b868", "#a82822", "#d8dce4"])
	_add_swatches(vb, "Shirt Body", "shirt", ["#e0ded6", "#1f98d4", "#d9304f", "#24b86a", "#e8a825", "#1c1e24"])
	_add_swatches(vb, "Raglan Sleeves", "sleeve", ["#1f1f24", "#7a1c24", "#1b3b66", "#234a34", "#d6d4cc"])
	_add_swatches(vb, "Pants", "pants", ["#242938", "#18181c", "#423a2c", "#2d4a6e", "#595c64"])

	# Height & Build Sliders
	_add_slider(vb, "Height", "height", 0.88, 1.15)
	_add_slider(vb, "Athletic Build", "build", 0.85, 1.25)

	# Shades Toggle + Done Button
	var sh_cb = CheckButton.new(); sh_cb.text = "Tactical Shades"; sh_cb.button_pressed = bool(profile["shades"])
	sh_cb.toggled.connect(func(on): profile["shades"] = on; _emit_save())
	vb.add_child(sh_cb)

	var done = Button.new(); done.text = "SAVE & PLAY [ESC / K]"
	done.pressed.connect(func(): visible = false; closed.emit())
	vb.add_child(done)

func _add_swatches(parent: VBoxContainer, title: String, key: String, hexes: Array) -> void:
	var row = HBoxContainer.new(); parent.add_child(row)
	var l = Label.new(); l.text = title; l.custom_minimum_size = Vector2(105, 0); l.add_theme_font_size_override("font_size", 13); row.add_child(l)
	for hx in hexes:
		var b = Button.new(); b.custom_minimum_size = Vector2(26, 24)
		var s = StyleBoxFlat.new(); s.bg_color = Color.html(hx); s.set_corner_radius_all(4)
		b.add_theme_stylebox_override("normal", s); b.add_theme_stylebox_override("hover", s)
		b.pressed.connect(func(): profile[key] = hx; _emit_save())
		row.add_child(b)

func _add_slider(parent: VBoxContainer, title: String, key: String, mn: float, mx: float) -> void:
	var row = HBoxContainer.new(); parent.add_child(row)
	var l = Label.new(); l.text = title; l.custom_minimum_size = Vector2(105, 0); l.add_theme_font_size_override("font_size", 13); row.add_child(l)
	var sl = HSlider.new(); sl.min_value = mn; sl.max_value = mx; sl.step = 0.02; sl.value = float(profile[key]); sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.value_changed.connect(func(v): profile[key] = v; _emit_save())
	row.add_child(sl)

func _emit_save() -> void:
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(profile))
	profile_updated.emit(profile)

func _load_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH): return
	var d = JSON.parse_string(FileAccess.open(SAVE_PATH, FileAccess.READ).get_as_text())
	if typeof(d) == TYPE_DICTIONARY:
		for k in d.keys(): profile[k] = d[k]
