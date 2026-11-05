class_name WarAdmissionSession
extends RefCounted
## Shared anonymous-admission ticket cache for lobby and battle-room clients.
## Colyseus owns bearer-token transport; this class only acquires and caches tickets.

const ADMISSION_PATH := "/api/admission"
const REFRESH_MARGIN_SECONDS := 60

static var _tickets: Dictionary = {}
static var _pending: Dictionary = {}

## Callback contract: callback.call(token: String, error: Variant).
## A successful call has a non-empty token and null error. On an editor-only
## legacy fixture's HTTP 404, it returns an empty token and the HTTP error so
## the caller may explicitly choose the unsigned test path.
static func ensure(client: Colyseus.Client, endpoint: String, callback: Callable) -> void:
	if client == null or callback == null or not callback.is_valid():
		if callback != null and callback.is_valid(): callback.call_deferred("", {"code": -1, "message": "invalid admission client"})
		return
	var key := canonical_endpoint(endpoint)
	var now := int(Time.get_unix_time_from_system())
	var cached: Dictionary = _tickets.get(key, {})
	var token := String(cached.get("token", ""))
	var expires_at := int(cached.get("expires_at", 0))
	if not token.is_empty() and expires_at - now > REFRESH_MARGIN_SECONDS:
		client.auth.set_token(token)
		callback.call_deferred(token, null)
		return
	if cached.size() > 0: _tickets.erase(key)
	if _pending.has(key):
		_pending[key].append({"client": client, "callback": callback})
		return
	_pending[key] = [{"client": client, "callback": callback}]
	client.http.post(ADMISSION_PATH, {}, func(error: Variant, data: Variant) -> void:
		_complete(key, error, data)
	)

static func canonical_endpoint(endpoint: String) -> String:
	var value := endpoint.strip_edges().trim_suffix("/")
	var separator := value.find("://")
	if separator < 0: return value.to_lower()
	var scheme := value.substr(0, separator).to_lower()
	if scheme == "ws": scheme = "http"
	elif scheme == "wss": scheme = "https"
	var remainder := value.substr(separator + 3)
	var path_start := remainder.find("/")
	var authority := remainder if path_start < 0 else remainder.substr(0, path_start)
	var path := "" if path_start < 0 else remainder.substr(path_start).trim_suffix("/")
	return scheme + "://" + authority.to_lower() + path

static func is_loopback_endpoint(endpoint: String) -> bool:
	var canonical := canonical_endpoint(endpoint)
	var scheme_end := canonical.find("://")
	if scheme_end < 0: return false
	var remainder := canonical.substr(scheme_end + 3)
	var path_start := remainder.find("/")
	var authority := remainder if path_start < 0 else remainder.substr(0, path_start)
	var host := authority
	if host.begins_with("["):
		var closing := host.find("]")
		if closing < 0: return false
		host = host.substr(1, closing - 1)
	elif host.contains(":"):
		host = host.substr(0, host.rfind(":"))
	host = host.to_lower()
	if host in ["localhost", "::1"]: return true
	var octets := host.split(".")
	if octets.size() != 4 or octets[0] != "127": return false
	for octet in octets:
		if not octet.is_valid_int() or int(octet) < 0 or int(octet) > 255: return false
	return true

static func invalidate(endpoint: String, rejected_token := "") -> void:
	var key := canonical_endpoint(endpoint)
	var cached: Dictionary = _tickets.get(key, {})
	if not cached.is_empty() and (rejected_token.is_empty() or String(cached.get("token", "")) == rejected_token):
		_tickets.erase(key)

static func _complete(key: String, error: Variant, data: Variant) -> void:
	var result_error: Variant = error
	var result_token := ""
	var ticket_expiry := 0
	if result_error == null:
		if data is Dictionary:
			result_token = String(data.get("token", ""))
			var player_id := String(data.get("playerId", ""))
			var expires_in := int(data.get("expiresIn", 0))
			if result_token.is_empty() or player_id.is_empty() or expires_in <= REFRESH_MARGIN_SECONDS:
				result_error = {"code": -1, "message": "invalid admission response"}
				result_token = ""
			else:
				ticket_expiry = int(Time.get_unix_time_from_system()) + expires_in
		else:
			result_error = {"code": -1, "message": "invalid admission response"}
	if result_error == null:
		_tickets[key] = {"token": result_token, "expires_at": ticket_expiry}
	var waiters: Array = _pending.get(key, [])
	_pending.erase(key)
	for waiter in waiters:
		var target = waiter.get("client")
		var done: Callable = waiter.get("callback", Callable())
		if target != null and result_error == null:
			target.auth.set_token(result_token)
		if done.is_valid(): done.call_deferred(result_token, result_error)
