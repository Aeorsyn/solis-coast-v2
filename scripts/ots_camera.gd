extends Node3D
class_name OTSCamera

var yaw_pivot: Node3D
var arm: SpringArm3D
var cam: Camera3D

var input_mode := "PC" # "PC", "PS5", "TOUCH"
var yaw := 0.0
var pitch := -0.22
var shoulder_side := 1.0
var is_aiming := false
var look_touch_idx := -1
var free_look_timer := 0.0

var deadzone := 0.16
var stick_sens := 2.75
var stick_aim_sens := 1.55
var mouse_sens := 0.0032
var mouse_aim_sens := 0.0018

func _ready() -> void:
	yaw_pivot = Node3D.new(); add_child(yaw_pivot)
	arm = SpringArm3D.new()
	var sp = SphereShape3D.new(); sp.radius = 0.28
	arm.shape = sp; arm.collision_mask = 3; arm.spring_length = 5.2; arm.margin = 0.25
	yaw_pivot.add_child(arm)
	cam = Camera3D.new(); cam.fov = 74.0; arm.add_child(cam)

func swap_shoulder() -> void:
	shoulder_side = -shoulder_side

func _get_right_stick() -> Vector2:
	if input_mode != "PS5": return Vector2.ZERO
	var pads = Input.get_connected_joypads()
	if pads.is_empty(): return Vector2.ZERO
	var raw = Vector2(Input.get_joy_axis(pads[0], JOY_AXIS_RIGHT_X), Input.get_joy_axis(pads[0], JOY_AXIS_RIGHT_Y))
	var mag = raw.length()
	if mag < deadzone: return Vector2.ZERO
	var scaled = clampf((mag - deadzone) / (1.0 - deadzone), 0.0, 1.0)
	return raw.normalized() * pow(scaled, 1.55)

func _input(event: InputEvent) -> void:
	if input_mode == "PC":
		if event is InputEventMouseMotion and (Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):
			var s = mouse_aim_sens if is_aiming else mouse_sens
			yaw -= event.relative.x * s
			pitch = clampf(pitch - event.relative.y * s * 0.9, -1.05, 0.55)
			free_look_timer = 1.4
	elif input_mode == "TOUCH":
		if event is InputEventScreenTouch:
			var sz = get_viewport().get_visible_rect().size
			if event.pressed and event.position.x > sz.x * 0.45 and event.position.y < sz.y * 0.55 and look_touch_idx == -1:
				look_touch_idx = event.index
			elif not event.pressed and event.index == look_touch_idx:
				look_touch_idx = -1
		elif event is InputEventScreenDrag and event.index == look_touch_idx:
			yaw -= event.relative.x * 0.0055
			pitch = clampf(pitch - event.relative.y * 0.0045, -1.05, 0.55)
			free_look_timer = 1.4

func update_cam(delta: float, target: Node3D, in_vehicle: bool, aiming: bool) -> void:
	is_aiming = aiming and not in_vehicle
	var u_delta = delta / maxf(Engine.time_scale, 0.08)

	var rs = _get_right_stick()
	if rs.length() > 0.001:
		var sens = stick_aim_sens if is_aiming else stick_sens
		yaw -= rs.x * sens * u_delta
		pitch = clampf(pitch - rs.y * sens * 0.78 * u_delta, -1.05, 0.55)
		free_look_timer = 1.4
	elif free_look_timer > 0.0:
		free_look_timer -= u_delta

	var desired_pos = target.global_position + (Vector3(0, 2.2, 0) if in_vehicle else Vector3(0, 1.52, 0))
	global_position = global_position.lerp(desired_pos, clampf(u_delta * 14.0, 0.0, 1.0))

	if in_vehicle and free_look_timer <= 0.0:
		var veh_yaw = atan2(-target.global_transform.basis.z.x, -target.global_transform.basis.z.z)
		yaw = lerp_angle(yaw, veh_yaw, clampf(u_delta * 5.0, 0.0, 1.0))

	yaw_pivot.rotation.y = yaw
	arm.rotation.x = pitch

	var target_x = (0.68 * shoulder_side) if is_aiming else (0.34 * shoulder_side if not in_vehicle else 0.0)
	var target_len = 2.15 if is_aiming else (8.8 if in_vehicle else 4.9)
	var target_fov = 48.0 if is_aiming else (78.0 if in_vehicle else 72.0)

	arm.position.x = lerpf(arm.position.x, target_x, clampf(u_delta * 12.0, 0.0, 1.0))
	arm.spring_length = lerpf(arm.spring_length, target_len, clampf(u_delta * 10.0, 0.0, 1.0))
	cam.fov = lerpf(cam.fov, target_fov, clampf(u_delta * 10.0, 0.0, 1.0))
