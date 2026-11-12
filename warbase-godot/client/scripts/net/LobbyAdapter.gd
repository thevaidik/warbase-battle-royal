extends Node
const AdmissionSession = preload("res://scripts/net/AdmissionSession.gd")
## Subscribes to Colyseus' official LobbyRoom listing. This is a menu-only
## connection and never joins a battle room.
signal listing_changed(rooms: Array)
signal availability_changed(available: bool)

var client
var lobby
var available := false
var _retry_timer: Timer
var _retry_attempt := 0
var _stopping := false
var _generation := 0

func _ready() -> void:
	_retry_timer = Timer.new()
	_retry_timer.one_shot = true
	_retry_timer.timeout.connect(_join_lobby)
	add_child(_retry_timer)

func start() -> void:
	_stopping = false
	_retry_attempt = 0
	_join_lobby()

func stop() -> void:
	_stopping = true
	_generation += 1
	_retry_timer.stop()
	_set_available(false)
	if lobby != null:
		lobby.left.disconnect(_on_left)
		lobby.dropped.disconnect(_on_dropped)
		lobby.error.disconnect(_on_error)
		lobby.message_received.disconnect(_on_message)
		lobby.joined.disconnect(_on_joined)
		lobby.leave()
	lobby = null
	client = null

func request_refresh() -> void:
	if available and lobby != null:
		lobby.send_message("filter", {})

func ensure_admission(callback: Callable) -> void:
	if client == null:
		client = Colyseus.Client.new(_endpoint())
	AdmissionSession.ensure(client, _endpoint(), callback)

func _endpoint() -> String:
	var host := GameState.server_host.trim_prefix("https://").trim_prefix("http://").trim_prefix("wss://").trim_prefix("ws://").trim_suffix("/")
	var scheme := "wss"
	if host.begins_with("localhost") or host.begins_with("127."):
		scheme = "ws"
	if not host.contains(":") and (host == "localhost" or host.begins_with("127.")):
		host += ":8081"
	var path := ""
	if OS.has_feature("web"):
		var web_host = JavaScriptBridge.eval("window.location.host")
		var web_proto = JavaScriptBridge.eval("window.location.protocol")
		var web_path = String(JavaScriptBridge.eval("window.location.pathname"))
		var backend = String(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('backend') || ''")).to_lower()
		var qa_colyseus = String(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('qa_colyseus') || ''"))
		if web_host != null and not String(web_host).is_empty():
			host = String(web_host)
			scheme = "wss" if String(web_proto) == "https:" else "ws"
			if web_path.begins_with("/colyseus") or backend in ["colyseus", "qa_colyseus"] or qa_colyseus == "1":
				path = "/colyseus"
	return "%s://%s%s" % [scheme, host, path]

func _join_lobby() -> void:
	if _stopping:
		return
	if not ResourceLoader.exists("res://addons/colyseus/colyseus.gd"):
		_retry_later()
		return
	_generation += 1
	var generation := _generation
	var endpoint := _endpoint()
	client = Colyseus.Client.new(endpoint)
	AdmissionSession.ensure(client, endpoint, _on_admission_issued.bind(generation))

func _on_admission_issued(token: String, error: Variant, generation: int) -> void:
	if _stopping or generation != _generation:
		return
	if error != null or token.is_empty():
		client = null
		_set_available(false)
		_retry_later()
		return
	lobby = client.join_or_create("lobby")
	if lobby == null:
		client = null
		_retry_later()
		return
	lobby.message_received.connect(_on_message)
	lobby.left.connect(_on_left)
	lobby.dropped.connect(_on_dropped)
	lobby.error.connect(_on_error)
	lobby.joined.connect(_on_joined)

func _on_joined() -> void:
	_retry_attempt = 0
	_set_available(true)

func _on_message(type: Variant, data: Variant) -> void:
	if type == "rooms" and data is Array:
		listing_changed.emit(data)
	elif type == "+" and data is Array and data.size() >= 2:
		listing_changed.emit(["+", data[0], data[1]])
	elif type == "-":
		listing_changed.emit(["-", data])

func _on_left(_code: int, _reason: String) -> void:
	_set_available(false)
	_schedule_resubscribe()

func _on_error(code: int, _message: String) -> void:
	if code == 401 and client != null:
		AdmissionSession.invalidate(_endpoint(), client.auth.get_token())
	_set_available(false)
	_schedule_resubscribe()

func _on_dropped(_code: int, _reason: String) -> void:
	_set_available(false)
	_schedule_resubscribe()

func _schedule_resubscribe() -> void:
	if lobby != null:
		lobby.message_received.disconnect(_on_message)
		lobby.left.disconnect(_on_left)
		lobby.dropped.disconnect(_on_dropped)
		lobby.error.disconnect(_on_error)
		lobby.joined.disconnect(_on_joined)
		lobby = null
	_generation += 1
	client = null
	_retry_later()

func _retry_later() -> void:
	if _stopping:
		return
	if not _retry_timer.is_stopped():
		return
	_retry_attempt += 1
	var delay := minf(1.0 * pow(2.0, minf(float(_retry_attempt - 1), 4.0)), 16.0)
	_retry_timer.start(delay)

func _set_available(value: bool) -> void:
	if available == value:
		return
	available = value
	availability_changed.emit(value)
