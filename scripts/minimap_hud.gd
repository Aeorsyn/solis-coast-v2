extends Control
class_name MiniMapHUD

var host: Node3D

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -164; offset_top = 62; offset_right = -16; offset_bottom = 210
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if host == null: return
	var r = size.x * 0.5
	var c = Vector2(r, r)
	draw_circle(c, r, Color(0.04, 0.07, 0.13, 0.80))
	draw_arc(c, r, 0, TAU, 48, Color(0.25, 0.88, 1.0, 0.78), 2.5)

	var ppos: Vector3 = host._ppos()
	var sc := 0.52

	# Draw Vehicles (Cyan Squares)
	for v in host.vehicles:
		var d = Vector2(v.global_position.x - ppos.x, v.global_position.z - ppos.z) * sc
		if d.length() < r - 6:
			draw_rect(Rect2(c + d - Vector2(3, 3), Vector2(6, 6)), Color(0.95, 0.25, 0.42))

	# Draw AI NPCs (Blue Dots)
	for n in host.npcs:
		var d = Vector2(n.global_position.x - ppos.x, n.global_position.z - ppos.z) * sc
		if d.length() < r - 6:
			draw_circle(c + d, 3.5, Color(0.35, 0.85, 1.0))

	# Draw Active Emergent Event (Pulsing Gold/Red Beacon clamped to edge)
	if host.event_dir != null and not host.event_dir.active_event.is_empty():
		var ev = host.event_dir.active_event
		var d = Vector2(ev["pos"].x - ppos.x, ev["pos"].z - ppos.z) * sc
		if d.length() > r - 8: d = d.normalized() * (r - 8)
		var pulse = 5.0 + sin(Time.get_ticks_msec() * 0.01) * 1.8
		draw_circle(c + d, pulse, ev["col"])

	# Player Center Dot
	draw_circle(c, 4.2, Color.WHITE)
