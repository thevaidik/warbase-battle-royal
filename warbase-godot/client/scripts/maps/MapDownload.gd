class_name WarMapDownload
extends RefCounted
## Optional content is fetched only before joining its map; native builds include it.
static func ensure_loaded(parent: Node, map_id: String, progress: Callable) -> bool:
	if not OS.has_feature("web") or map_id != "football": return true
	if ResourceLoader.exists("res://assets/maps/football.glb"): return true
	var base := str(JavaScriptBridge.eval("window.location.href.split('#')[0].split('?')[0].replace(/[^/]*$/, '')"))
	progress.call("Checking Stadium download…")
	var request := HTTPRequest.new()
	request.timeout = 30
	parent.add_child(request)
	if request.request(base + "optional-maps.json") != OK:
		request.queue_free()
		return false
	var response: Array = await request.request_completed
	if response[0] != HTTPRequest.RESULT_SUCCESS or response[1] != 200:
		request.queue_free()
		return false
	var manifest = JSON.parse_string(response[3].get_string_from_utf8())
	if not manifest is Dictionary or not manifest.has(map_id):
		request.queue_free()
		return false
	var entry: Dictionary = manifest[map_id]
	var filename := str(entry.get("file", ""))
	if not filename.begins_with("map-football-") or filename.get_file() != filename or not filename.ends_with(".pck"):
		request.queue_free()
		return false
	var path := "user://" + filename
	var expected_hash := str(entry.get("sha256", ""))
	if FileAccess.file_exists(path) and FileAccess.get_sha256(path) == expected_hash:
		request.queue_free()
		return _mount(path, entry)
	progress.call("Downloading Stadium…")
	request.queue_free()
	request = HTTPRequest.new()
	request.timeout = 300
	parent.add_child(request)
	if request.request(base + filename) != OK:
		request.queue_free()
		return false
	var timer := Timer.new()
	timer.wait_time = 0.25
	parent.add_child(timer)
	timer.timeout.connect(func() -> void:
		var total := maxi(int(entry.get("bytes", 1)), 1)
		progress.call("Downloading Stadium… %d%%" % clampi(int(100.0 * request.get_downloaded_bytes() / total), 0, 99))
	)
	timer.start()
	response = await request.request_completed
	timer.queue_free()
	request.queue_free()
	if response[0] == HTTPRequest.RESULT_SUCCESS and response[1] == 200:
		var output := FileAccess.open(path, FileAccess.WRITE)
		if output:
			output.store_buffer(response[3])
			output.close()
	if response[0] != HTTPRequest.RESULT_SUCCESS or response[1] != 200 or FileAccess.get_sha256(path) != expected_hash:
		print("MAP DOWNLOAD FAILED: result=", response[0], " http=", response[1], " hash=", FileAccess.get_sha256(path), " expected=", expected_hash)
		DirAccess.remove_absolute(path)
		return false
	return _mount(path, entry)

static func _mount(path: String, entry: Dictionary) -> bool:
	if not ProjectSettings.load_resource_pack(path):
		print("MAP MOUNT FAILED: ", path)
		return false
	for uid_text in entry.get("uids", {}):
		var uid := ResourceUID.text_to_id(str(uid_text))
		var resource_path: String = entry.uids[uid_text]
		if ResourceUID.has_id(uid): ResourceUID.set_id(uid, resource_path)
		else: ResourceUID.add_id(uid, resource_path)
	return ResourceLoader.exists("res://assets/maps/football.glb")
