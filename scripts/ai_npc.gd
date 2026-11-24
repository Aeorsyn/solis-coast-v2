extends CharacterBody3D
class_name AINPC

var npc_name := "Marcus"
var npc_role := "Street Mechanic"
var persona := "You are Marcus, a street-smart mechanic. Keep replies under 2 sentences."
var history: Array[Dictionary] = []
var rig: CharacterRig
var wander_dir := Vector3.ZERO
var wander_timer := 0.0
var is_talking := false

func setup(p_name: String, p_role: String, p_persona: String, shirt_col: Color, glb_path := "") -> void:
	npc_name = p_name; npc_role = p_role; persona = p_persona
	rig = CharacterRig.new()
	rig.setup(shirt_col, Color(0.16, 0.17, 0.22), false, glb_path)
	add_child(rig)
	var col = CollisionShape3D.new()
	var cs = CapsuleShape3D.new(); cs.radius = 0.36; cs.height = 1.72
	col.shape = cs; add_child(col)
	var lbl = Label3D.new()
	lbl.text = "%s\n(%s)" % [npc_name, npc_role]
	lbl.position = Vector3(0, 1.32, 0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.font_size = 28; lbl.outline_size = 6; lbl.modulate = Color(0.75, 0.96, 1.0)
	add_child(lbl)

func update_ai(delta: float, player_pos: Vector3) -> void:
	if is_talking:
		velocity.x = 0.0; velocity.z = 0.0
		var to_p = player_pos - global_position
		if to_p.length() > 0.1:
			rig.rotation.y = lerp_angle(rig.rotation.y, atan2(to_p.x, to_p.z), clampf(delta * 8.0, 0.0, 1.0))
	else:
		wander_timer -= delta
		if wander_timer <= 0.0:
			wander_timer = randf_range(2.5, 6.0)
			wander_dir = Vector3.ZERO if randf() < 0.45 else Vector3(cos(randf() * TAU), 0.0, sin(randf() * TAU))
		velocity.x = wander_dir.x * 1.9; velocity.z = wander_dir.z * 1.9
		if wander_dir.length() > 0.1:
			rig.rotation.y = lerp_angle(rig.rotation.y, atan2(wander_dir.x, wander_dir.z), clampf(delta * 6.0, 0.0, 1.0))
	velocity.y = 0.0 if is_on_floor() else velocity.y - 20.0 * delta
	move_and_slide()
	rig.animate(Vector2(velocity.x, velocity.z).length(), false, false, delta)

func build_messages(user_msg: String, world_context: String) -> Array[Dictionary]:
	var msgs: Array[Dictionary] = [{
		"role": "system",
		"content": "%s\nLive World State: %s\nStay in character. Reply in 1-2 short sentences." % [persona, world_context]
	}]
	for i in range(max(0, history.size() - 6), history.size()):
		msgs.append(history[i])
	msgs.append({"role": "user", "content": user_msg})
	return msgs
