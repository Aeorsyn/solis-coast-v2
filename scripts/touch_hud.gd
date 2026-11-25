extends Control
class_name TouchHUD

var input_mode := "PC" # "PC", "PS5", "TOUCH"
var touch_enabled := false
var ghost_enabled := false
var hell_enabled := false
var abyss_enabled := false

var joy_vec := Vector2.ZERO
var joy_touch_idx := -1
var joy_radius := 76.0
var joy_knob_radius := 32.0

var hold_focus := false
var hold_brake := false
var hold_fire := false
var on_action: Callable

var buttons := [
	{"id": "fire",  "label": "FIRE",  "ox": -105, "oy": -115, "r": 46.0, "col": Color(0.95, 0.22, 0.25, 0.78), "hold": true,  "idx": -1},
	{"id": "act",   "label": "ACT",   "ox": -105, "oy": -225, "r": 38.0, "col": Color(0.15, 0.85, 0.45, 0.72), "hold": false, "idx": -1},
	{"id": "car",   "label": "CAR",   "ox": -205, "oy": -175, "r": 38.0, "col": Color(0.15, 0.65, 0.95, 0.72), "hold": false, "idx": -1},
	{"id": "trunk", "label": "TRUNK", "ox": -205, "oy": -75,  "r": 35.0, "col": Color(0.95, 0.65, 0.15, 0.72), "hold": false, "idx": -1},
	{"id": "focus", "label": "FOCUS", "ox": -295, "oy": -115, "r": 36.0, "col": Color(0.70, 0.30, 0.95, 0.72), "hold": true,  "idx": -1},
	{"id": "brake", "label": "DRIFT", "ox": -295, "oy": -205, "r": 33.0, "col": Color(0.90, 0.45, 0.20, 0.70), "hold": true,  "idx": -1},
	{"id": "swap",  "label": "SWAP",  "ox": -105, "oy": -310, "r": 30.0, "col": Color(0.85, 0.25, 0.65, 0.68), "hold": false, "idx": -1},
	{"id": "scan",  "label": "SCAN",  "ox": -205, "oy": -275, "r": 32.0, "col": Color(0.10, 0.90, 0.95, 0.72), "hold": false, "idx": -1}
]

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_input_mode(mode: String) -> void:
	input_mode = mode
	touch_enabled = (mode == "TOUCH")
	if not touch_enabled:
		joy_touch_idx = -1; joy_vec = Vector2.ZERO
		hold_focus = false; hold_brake = false; hold_fire = false
		for b in buttons: b["idx"] = -1
	queue_redraw()

func set_touch_enabled(state: bool) -> void:
	set_input_mode("TOUCH" if state else "PC")

func _mode_rect() -> Rect2:
	var s = get_viewport_rect().size
	return Rect2(s.x - 164.0, 16.0, 148.0, 38.0)

func _ghost_rect() -> Rect2:
	var s = get_viewport_rect().size
	return Rect2(s.x - 322.0, 16.0, 148.0, 38.0)

func _hell_rect() -> Rect2:
	var s = get_viewport_rect().size
	return Rect2(s.x - 480.0, 16.0, 148.0, 38.0)

func _abyss_rect() -> Rect2:
	var s = get_viewport_rect().size
	return Rect2(s.x - 638.0, 16.0, 148.0, 38.0)

func _joy_center() -> Vector2:
	var s = get_viewport_rect().size
	return Vector2(130.0, s.y - 135.0)

func _btn_pos(b: Dictionary) -> Vector2:
	var s = get_viewport_rect().size
	return Vector2(s.x + b["ox"], s.y + b["oy"])

func _hit_top_pill(p: Vector2) -> bool:
	if _mode_rect().has_point(p):
		if on_action.is_valid(): on_action.call("cycle_mode")
		return true
	if _ghost_rect().has_point(p):
		if on_action.is_valid(): on_action.call("ghost")
		return true
	if _hell_rect().has_point(p):
		if on_action.is_valid(): on_action.call("hell")
		return true
	if _abyss_rect().has_point(p):
		if on_action.is_valid(): on_action.call("abyss")
		return true
	return false

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			if _hit_top_pill(event.position):
				get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenTouch:
		var p: Vector2 = event.position
		if event.pressed and _hit_top_pill(p):
			return
		if not touch_enabled: return
		if event.pressed:
			for b in buttons:
				if p.distance_to(_btn_pos(b)) <= b["r"] + 12.0:
					b["idx"] = event.index
					if b["hold"]: _sync_holds()
					elif on_action.is_valid(): on_action.call(b["id"])
					queue_redraw(); return
			if p.x < get_viewport_rect().size.x * 0.45 and p.y > get_viewport_rect().size.y * 0.40:
				if joy_touch_idx == -1:
					joy_touch_idx = event.index; _update_joy(p); queue_redraw()
		else:
			if event.index == joy_touch_idx:
				joy_touch_idx = -1; joy_vec = Vector2.ZERO; queue_redraw()
			for b in buttons:
				if b["idx"] == event.index:
					b["idx"] = -1; _sync_holds(); queue_redraw()
	elif event is InputEventScreenDrag and touch_enabled:
		if event.index == joy_touch_idx:
			_update_joy(event.position); queue_redraw()

func _update_joy(pos: Vector2) -> void:
	var d = pos - _joy_center()
	if d.length() > joy_radius: d = d.normalized() * joy_radius
	joy_vec = d / joy_radius

func _sync_holds() -> void:
	hold_focus = false; hold_brake = false; hold_fire = false
	for b in buttons:
		if b["id"] == "focus" and b["idx"] != -1: hold_focus = true
		if b["id"] == "brake" and b["idx"] != -1: hold_brake = true
		if b["id"] == "fire"  and b["idx"] != -1: hold_fire = true

func _draw_pill(r: Rect2, bg: Color, border: Color, txt: String) -> void:
	var font = ThemeDB.fallback_font
	draw_rect(r, bg, true)
	draw_rect(r, border, false, 2.0)
	var sz = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 15)
	draw_string(font, r.position + Vector2((r.size.x - sz.x) * 0.5, 24.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)

func _draw() -> void:
	var mode_col = Color(0.14, 0.50, 0.85, 0.86) if input_mode == "PC" else (Color(0.32, 0.24, 0.86, 0.88) if input_mode == "PS5" else Color(0.10, 0.62, 0.45, 0.86))
	_draw_pill(_mode_rect(), mode_col, Color(0.35, 0.90, 1.0, 0.85), "MODE: " + input_mode)
	_draw_pill(_ghost_rect(), Color(0.75, 0.25, 0.92, 0.88) if ghost_enabled else Color(0.18, 0.20, 0.28, 0.78), Color(0.85, 0.55, 1.0, 0.85), "GHOST: ON" if ghost_enabled else "GHOST: OFF")
	_draw_pill(_hell_rect(), Color(0.92, 0.24, 0.06, 0.90) if hell_enabled else Color(0.18, 0.20, 0.28, 0.78), Color(1.0, 0.55, 0.15, 0.88), "HELL: ON" if hell_enabled else "HELL: OFF")
	_draw_pill(_abyss_rect(), Color(0.42, 0.14, 0.88, 0.92) if abyss_enabled else Color(0.18, 0.20, 0.28, 0.78), Color(0.42, 0.90, 1.0, 0.88), "ABYSS: ON" if abyss_enabled else "ABYSS: OFF")

	if not touch_enabled: return
	var font = ThemeDB.fallback_font
	var jc = _joy_center()
	draw_circle(jc, joy_radius, Color(0.06, 0.08, 0.14, 0.48))
	draw_arc(jc, joy_radius, 0, TAU, 40, Color(0.35, 0.85, 1.0, 0.65), 2.5)
	var kp = jc + joy_vec * (joy_radius - 14.0)
	draw_circle(kp, joy_knob_radius, Color(0.25, 0.80, 0.98, 0.78))
	draw_arc(kp, joy_knob_radius, 0, TAU, 32, Color(1, 1, 1, 0.8), 2.0)

	for b in buttons:
		var bp = _btn_pos(b)
		var col: Color = b["col"]
		if b["idx"] != -1: col = col.lightened(0.28); col.a = 0.96
		draw_circle(bp, b["r"], col)
		draw_arc(bp, b["r"], 0, TAU, 32, Color(1, 1, 1, 0.78), 2.0)
		var txt: String = b["label"]
		var sz = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
		draw_string(font, bp + Vector2(-sz.x * 0.5, 5.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
