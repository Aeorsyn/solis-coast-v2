extends Node
class_name LLMBooter

var server_pid := -1
var is_ready := false
var is_booting := false
var endpoint := "http://127.0.0.1:9931/v1/chat/completions"
var health_url := "http://127.0.0.1:9931/health"
var active_model_name := ""

var ping_http: HTTPRequest
var poll_timer := 0.0

signal status_changed(status_text: String, live: bool)

func _ready() -> void:
	ping_http = HTTPRequest.new()
	ping_http.timeout = 2.0
	ping_http.request_completed.connect(_on_health_reply)
	add_child(ping_http)

	if OS.has_feature("web"):
		status_changed.emit("AI ENGINE: WEB OFFLINE MODE", false)
		return
	if OS.has_feature("mobile") or OS.has_feature("android"):
		# On phone, default to Envy LAN IP (editable in chat bar)
		endpoint = "http://10.0.0.92:9931/v1/chat/completions"
		health_url = "http://10.0.0.92:9931/health"
		ping_http.request(health_url)
	else:
		# On desktop, check if llama-server is already running; if not, auto-boot it
		ping_http.request(health_url)

func _process(delta: float) -> void:
	if is_booting and not is_ready:
		poll_timer -= delta
		if poll_timer <= 0.0:
			poll_timer = 1.5
			if ping_http.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
				ping_http.request(health_url)

func _on_health_reply(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		is_ready = true
		is_booting = false
		var m_lbl = (" (" + active_model_name + ")") if not active_model_name.is_empty() else ""
		status_changed.emit("AI ENGINE: LIVE" + m_lbl, true)
		return

	if not is_booting and not OS.has_feature("mobile") and not OS.has_feature("android"):
		_auto_launch_server()

func _find_binary() -> String:
	var home = OS.get_environment("HOME")
	var candidates = [
		home + "/llama.cpp/build/bin/llama-server",
		home + "/llama.cpp/llama-server",
		"/usr/local/bin/llama-server",
		"/usr/bin/llama-server"
	]
	for c in candidates:
		if FileAccess.file_exists(c):
			return c
	# Fallback to PATH lookup
	var out := []
	if OS.execute("which", ["llama-server"], out) == 0 and not out.is_empty():
		var p = str(out[0]).strip_edges()
		if not p.is_empty(): return p
	return ""

func _find_gguf_model() -> String:
	var home = OS.get_environment("HOME")
	var dirs = [
		ProjectSettings.globalize_path("res://models"),
		home + "/models",
		home + "/llama.cpp/models",
		home + "/Downloads",
		home
	]
	var found: Array[String] = []
	for dpath in dirs:
		var da = DirAccess.open(dpath)
		if da == null: continue
		da.list_dir_begin()
		var fn = da.get_next()
		while fn != "":
			if not da.current_is_dir() and fn.to_lower().ends_with(".gguf"):
				found.append(dpath.path_join(fn))
			fn = da.get_next()
		da.list_dir_end()
	if found.is_empty(): return ""
	# Prefer fast 4B/Gemma/Nemotron models first for low-latency NPC replies
	for f in found:
		var low = f.to_lower()
		if "nemotron" in low or "gemma" in low or "4b" in low or "3b" in low:
			return f
	return found[0]

func _auto_launch_server() -> void:
	var bin = _find_binary()
	var model = _find_gguf_model()
	if bin.is_empty() or model.is_empty():
		status_changed.emit("AI ENGINE: SMART OFFLINE (Drop any .gguf into ~/solis_coast_v2/models/)", false)
		return

	active_model_name = model.get_file()
	var args = PackedStringArray([
		"-m", model,
		"--host", "0.0.0.0",
		"--port", "9931",
		"-c", "4096",
		"-ngl", "99"
	])
	server_pid = OS.create_process(bin, args, false)
	if server_pid > 0:
		is_booting = true
		poll_timer = 1.5
		status_changed.emit("AI ENGINE: BOOTING " + active_model_name + "...", false)
	else:
		status_changed.emit("AI ENGINE: SMART OFFLINE", false)

func _exit_tree() -> void:
	# Cleanly stop the auto-launched llama-server when the game closes
	if server_pid > 0:
		OS.kill(server_pid)
		server_pid = -1
