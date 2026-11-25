extends Control
class_name TouchHUD

var move_vec := Vector2.ZERO
var joy_vec: Vector2:
	get: return move_vec
var look_vec := Vector2.ZERO
var hold_fire := false
var hold_aim := false
var hold_focus := false
var hold_brake := false
var hold_accel := false
var hell_enabled := false
var abyss_enabled := false
var noclip_enabled := false
var in_vehicle := false
var ghost_enabled := false
var input_mode := "PC"
var on_action: Callable

var _move_idx := -1
var _look_idx := -1
var _fire_idx := -1
var _aim_idx := -1
var _focus_idx := -1
var _move_origin := Vector2.ZERO
var _look_origin := Vector2.ZERO
var _stick_r := 76.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS

func _left_center() -> Vector2:
	var s = get_viewport_rect().size
	return Vector2(128.0, s.y - 142.0)

func _right_center() -> Vector2:
	var s = get_viewport_rect().size
	return Vector2(s.x - 156.0, s.y - 146.0)

func _fire_center() -> Vector2:
	var r = _right_center()
	return Vector2(r.x - 134.0, r.y - 26.0)

func _aim_center() -> Vector2:
	var r = _right_center()
	return Vector2(r.x - 102.0, r.y - 128.0)

func _focus_center() -> Vector2:
	var r = _right_center()
	return Vector2(r.x + 12.0, r.y - 156.0)

func _hail_center() -> Vector2:
	var r = _right_center()
	return Vector2(r.x - 208.0, r.y + 42.0)

func _mode_rect() -> Rect2:
	var s = get_viewport_rect().size
	return Rect2(s.x - 160.0, 16.0, 146.0, 38.0)

func _uap_rect() -> Rect2:
	var s = get_viewport_rect().size
	return Rect2(s.x - 314.0, 16.0, 146.0, 38.0)

func _hell_rect() -> Rect2:
	var s = get_viewport_rect().size
	return Rect2(s.x - 468.0, 16.0, 146.0, 38.0)

func _abyss_rect() -> Rect2:
	var s = get_viewport_rect().size
	return Rect2(s.x - 622.0, 16.0, 146.0, 38.0)

func _noclip_rect() -> Rect2:
	var s = get_viewport_rect().size
	return Rect2(s.x - 752.0, 16.0, 122.0, 38.0)

func _input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventScreenTouch:
		var p: Vector2 = event.position
		var idx: int = event.index
		if event.pressed:
			if _handle_top_pills(p): return
			if p.distance_to(_fire_center()) <= 52.0:
				_fire_idx = idx; hold_fire = true; queue_redraw(); return
			if p.distance_to(_aim_center()) <= 44.0:
				_aim_idx = idx; hold_aim = true; queue_redraw(); return
			if p.distance_to(_focus_center()) <= 40.0:
				_focus_idx = idx; hold_focus = true; queue_redraw(); return
			if p.distance_to(_hail_center()) <= 40.0:
				if on_action.is_valid(): on_action.call("hail")
				return

			var half_x = get_viewport_rect().size.x * 0.45
			if p.x < half_x and _move_idx == -1:
				_move_idx = idx
				_move_origin = _left_center() if p.distance_to(_left_center()) < 140.0 else p
				_update_move(p)
			elif p.x >= half_x and _look_idx == -1:
				_look_idx = idx
				_look_origin = _right_center() if p.distance_to(_right_center()) < 130.0 else p
				_update_look(p)
		else:
			if idx == _move_idx:
				_move_idx = -1; move_vec = Vector2.ZERO; hold_accel = false; hold_brake = false
			elif idx == _look_idx:
				_look_idx = -1; look_vec = Vector2.ZERO
			elif idx == _fire_idx:
				_fire_idx = -1; hold_fire = false
			elif idx == _aim_idx:
				_aim_idx = -1; hold_aim = false
			elif idx == _focus_idx:
				_focus_idx = -1; hold_focus = false
			queue_redraw()

	elif event is InputEventScreenDrag:
		if event.index == _move_idx:
			_update_move(event.position)
		elif event.index == _look_idx:
			_update_look(event.position)

	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_top_pills(event.position)

func _handle_top_pills(p: Vector2) -> bool:
	if _hell_rect().has_point(p):
		if on_action.is_valid(): on_action.call("hell")
		return true
	if _noclip_rect().has_point(p):
		if on_action.is_valid(): on_action.call("noclip")
		return true
	if _abyss_rect().has_point(p):
		if on_action.is_valid(): on_action.call("abyss")
		return true
	if _mode_rect().has_point(p):
		if on_action.is_valid(): on_action.call("mode")
		return true
	if _uap_rect().has_point(p):
		if on_action.is_valid(): on_action.call("uap")
		return true
	return false

func _update_move(p: Vector2) -> void:
	var d = p - _move_origin
	if d.length() > _stick_r: d = d.normalized() * _stick_r
	move_vec = d / _stick_r
	hold_accel = move_vec.y < -0.35
	hold_brake = move_vec.y > 0.45
	queue_redraw()

func _update_look(p: Vector2) -> void:
	var d = p - _look_origin
	if d.length() > _stick_r: d = d.normalized() * _stick_r
	# Apply gentle exponential curve for fine aiming near center & fast turns at edge
	var raw = d / _stick_r
	look_vec = raw * (0.45 + 0.55 * raw.length())
	queue_redraw()

func _draw_pill(r: Rect2, bg: Color, border: Color, txt: String) -> void:
	draw_rect(r, bg, true)
	draw_rect(r, border, false, 2.0)
	var f = ThemeDB.fallback_font
	draw_string(f, Vector2(r.position.x + 12.0, r.position.y + 24.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

func _draw_btn(c: Vector2, rad: float, active: bool, col: Color, label: String) -> void:
	draw_circle(c, rad, Color(col.r, col.g, col.b, 0.58 if active else 0.24))
	draw_arc(c, rad, 0.0, TAU, 28, col, 2.5)
	var f = ThemeDB.fallback_font
	draw_string(f, Vector2(c.x - rad * 0.55, c.y + 5.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)

func _draw() -> void:
	_draw_pill(_hell_rect(), Color(0.92, 0.24, 0.06, 0.90) if hell_enabled else Color(0.18, 0.20, 0.28, 0.78), Color(1.0, 0.55, 0.15, 0.88), "HELL: ON" if hell_enabled else "HELL: OFF")
	_draw_pill(_noclip_rect(), Color(0.16, 0.82, 0.42, 0.92) if noclip_enabled else Color(0.18, 0.20, 0.28, 0.78), Color(0.35, 1.0, 0.65, 0.88), "NOCLIP: ON" if noclip_enabled else "NOCLIP [F6]")
	_draw_pill(_abyss_rect(), Color(0.42, 0.14, 0.88, 0.92) if abyss_enabled else Color(0.18, 0.20, 0.28, 0.78), Color(0.42, 0.90, 1.0, 0.88), "ABYSS: ON" if abyss_enabled else "ABYSS: OFF")
	_draw_pill(_uap_rect(), Color(0.88, 0.66, 0.14, 0.88), Color(1.0, 0.92, 0.45, 0.92), "UAP FORM [U]")
	var m_col = Color(0.14, 0.52, 0.95, 0.92) if input_mode == "PS5" else (Color(0.14, 0.72, 0.56, 0.92) if input_mode == "TOUCH" else Color(0.24, 0.28, 0.38, 0.86))
	_draw_pill(_mode_rect(), m_col, Color(0.55, 0.95, 1.0, 0.92), "CTRL: " + input_mode)

	# Only draw virtual dual sticks & combat buttons on touch/web or when touched
	var show_sticks = (input_mode == "TOUCH") or _move_idx != -1 or _look_idx != -1
	if not show_sticks: return

	# Left Move Stick
	var lc = _move_origin if _move_idx != -1 else _left_center()
	draw_circle(lc, _stick_r, Color(0.10, 0.16, 0.24, 0.30))
	draw_arc(lc, _stick_r, 0.0, TAU, 32, Color(0.30, 0.92, 1.0, 0.65), 2.0)
	draw_circle(lc + move_vec * _stick_r, 28.0, Color(0.30, 0.92, 1.0, 0.68))

	# Right Look / Aim Stick Emulation
	var rc = _look_origin if _look_idx != -1 else _right_center()
	draw_circle(rc, _stick_r, Color(0.14, 0.10, 0.26, 0.30))
	draw_arc(rc, _stick_r, 0.0, TAU, 32, Color(1.0, 0.78, 0.28, 0.72), 2.0)
	draw_circle(rc + look_vec * _stick_r, 28.0, Color(1.0, 0.82, 0.32, 0.72))

	# Ergonomic Combat Arc around Right Stick
	_draw_btn(_fire_center(),  46.0, hold_fire,  Color(1.00, 0.32, 0.14), "FIRE")
	_draw_btn(_aim_center(),   38.0, hold_aim,   Color(0.22, 0.95, 1.00), "AIM")
	_draw_btn(_focus_center(), 34.0, hold_focus, Color(0.76, 0.36, 1.00), "SLOW")
	_draw_btn(_hail_center(),  34.0, false,      Color(1.00, 0.86, 0.30), "HAIL")

func set_input_mode(m: String) -> void:
	input_mode = m
	visible = true
	queue_redraw()
