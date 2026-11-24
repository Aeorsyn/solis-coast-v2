extends Node
class_name AudioManager

var player: AudioStreamPlayer
var pb: AudioStreamGeneratorPlayback
var mix_rate := 22050.0
var muted := false

var eng_phase := 0.0
var sub_phase := 0.0
var bird_phase := 0.0
var bird_timer := 2.5
var bird_env := 0.0
var bird_freq := 2600.0

var gun_env := 0.0
var step_env := 0.0
var step_timer := 0.0
var chime_env := 0.0
var chime_phase := 0.0
var lp_noise := 0.0

var in_veh := false
var veh_speed := 0.0
var walk_speed := 0.0
var is_raining := false
var is_daytime := true

func _ready() -> void:
	player = AudioStreamPlayer.new()
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = mix_rate
	gen.buffer_length = 0.10
	player.stream = gen
	player.volume_db = -4.0
	add_child(player)
	player.play()
	pb = player.get_stream_playback()

func toggle_mute() -> bool:
	muted = not muted
	player.stream_paused = muted
	return muted

func play_gunshot() -> void:
	gun_env = 1.0

func play_chime() -> void:
	chime_env = 1.0
	chime_phase = 0.0

func update_audio(delta: float, p_in_veh: bool, p_veh_spd: float, p_walk_spd: float, p_rain: bool, time_of_day: float) -> void:
	in_veh = p_in_veh
	veh_speed = p_veh_spd
	walk_speed = p_walk_spd
	is_raining = p_rain
	is_daytime = (time_of_day >= 6.5 and time_of_day <= 19.0)

	# Footstep cadence on foot
	if not in_veh and walk_speed > 1.2:
		step_timer -= delta * (walk_speed / 5.5)
		if step_timer <= 0.0:
			step_env = 0.75
			step_timer = 0.38
	else:
		step_timer = 0.08

	# Occasional daytime wildlife bird chirps
	if is_daytime and not is_raining:
		bird_timer -= delta
		if bird_timer <= 0.0:
			bird_timer = randf_range(2.2, 6.0)
			bird_env = 0.85
			bird_freq = randf_range(2200.0, 3400.0)

	if muted or pb == null: return
	var frames = pb.get_frames_available()
	if frames <= 0: return

	var inv_sr = 1.0 / mix_rate
	var rpm_hz = 46.0 + clampf(veh_speed, 0.0, 42.0) * 3.1

	for i in frames:
		var s := 0.0
		var rnd = randf_range(-1.0, 1.0)
		lp_noise = lp_noise * 0.84 + rnd * 0.16

		# 1. Dynamic V8 Engine Hum (Sawtooth + Sub-Sine)
		if in_veh:
			eng_phase = fmod(eng_phase + rpm_hz * inv_sr, 1.0)
			sub_phase = fmod(sub_phase + (rpm_hz * 0.5) * inv_sr, 1.0)
			var saw = (eng_phase * 2.0 - 1.0) * 0.14
			var sub = sin(sub_phase * TAU) * 0.18
			s += (saw + sub) * (0.55 + clampf(veh_speed / 30.0, 0.0, 0.65))

		# 2. Rain & Subtle City Ambience
		if is_raining:
			s += (rnd * 0.12 + lp_noise * 0.16)
		else:
			s += lp_noise * 0.045

		# 3. Wildlife Bird Chirp
		if bird_env > 0.002:
			var f_mod = bird_freq + sin(bird_env * 28.0) * 420.0
			bird_phase = fmod(bird_phase + f_mod * inv_sr, 1.0)
			s += sin(bird_phase * TAU) * bird_env * 0.09
			bird_env *= 0.9992

		# 4. Crisp Gunshot Crack
		if gun_env > 0.002:
			var punch = sin(gun_env * 90.0) * 0.35
			s += (rnd * 0.65 + punch) * gun_env
			gun_env *= 0.9965

		# 5. Soft Footstep Thud
		if step_env > 0.002:
			s += lp_noise * step_env * 0.38
			step_env *= 0.992

		# 6. Event Reward Chime
		if chime_env > 0.002:
			var cf = 523.25 if chime_env > 0.66 else (659.25 if chime_env > 0.33 else 783.99)
			chime_phase = fmod(chime_phase + cf * inv_sr, 1.0)
			s += sin(chime_phase * TAU) * chime_env * 0.22
			chime_env *= 0.9997

		s = clampf(s, -0.85, 0.85)
		pb.push_frame(Vector2(s, s))
