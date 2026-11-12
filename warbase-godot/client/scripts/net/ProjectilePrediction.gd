extends RefCounted
## Colyseus owns stable spawn IDs and the predicted-to-authoritative handoff.

const Ballistics = preload("res://scripts/weapons/GrenadeBallistics.gd")
const GRENADES := "grenade_projectiles"
const MISSILES := "missile_projectiles"
const FIELDS := ["x", "y", "z", "vx", "vy", "vz", "active"]

var _stores: Dictionary = {}
var _pending: Dictionary = {}
var _owner: String
var _viewport: Viewport

func _init(predictor: Variant, owner: String, viewport: Viewport) -> void:
	_owner = owner
	_viewport = viewport
	for collection in [GRENADES, MISSILES]:
		var settings := {
			"owned": _matches_prediction.bind(collection),
			"fields": FIELDS,
			"step": _step_local.bind(collection),
			"ttl_ms": 850.0,
		}
		var store = predictor.spawns(collection, settings)
		if store != null: _stores[collection] = store

func has_store(collection: String) -> bool:
	return _stores.has(collection)

func spawn(collection: String, request_id: int, kind: String, position: Vector3, velocity: Vector3) -> bool:
	if not has_store(collection) or request_id <= 0 or not position.is_finite() or not velocity.is_finite(): return false
	var store = _stores[collection]
	_refresh_pending(collection, store.entries())
	# The SDK pairs one pending spawn with the next owned server spawn. Match
	# the exact request and allow one outstanding visual per projectile type.
	if _pending.has(collection): return false
	var id: int = store.spawn({
		"x": position.x, "y": position.y, "z": position.z,
		"vx": velocity.x, "vy": velocity.y, "vz": velocity.z,
		"active": 1.0, "age": 0.0, "impact": kind == "impact",
	})
	if id <= 0: return false
	_pending[collection] = {"id": id, "request_id": request_id, "kind": kind, "rejected": false}
	return true

func reject(collection: String, request_id: int) -> void:
	var pending: Dictionary = _pending.get(collection, {})
	if int(pending.get("request_id", 0)) == request_id and request_id > 0:
		pending["rejected"] = true

func _matches_prediction(server: Variant, collection: String) -> bool:
	var pending: Dictionary = _pending.get(collection, {})
	return not pending.is_empty() and not pending["rejected"] and String(server.owner) == _owner and int(server.request_id) == int(pending["request_id"])

func _refresh_pending(collection: String, entries: Array) -> void:
	if not _pending.has(collection): return
	var id: int = _pending[collection]["id"]
	for entry in entries:
		if int(entry["id"]) == id and not bool(entry["confirmed"]): return
	_pending.erase(collection)

func views() -> Array:
	var result: Array = []
	for collection in _stores:
		var store = _stores[collection]
		var entries: Array = store.entries()
		_refresh_pending(collection, entries)
		var pending: Dictionary = _pending.get(collection, {})
		for entry in entries:
			var id: int = entry["id"]
			var confirmed: bool = entry["confirmed"]
			if not confirmed and (int(pending.get("id", 0)) != id or pending.get("rejected", false)): continue
			if store.value(id, "active") < 0.5: continue
			var position := Vector3(store.value(id, "x"), store.value(id, "y"), store.value(id, "z"))
			var velocity := Vector3(store.value(id, "vx"), store.value(id, "vy"), store.value(id, "vz"))
			if not position.is_finite() or not velocity.is_finite(): continue
			result.append({
				"key": "%s:%d" % [collection, id], "collection": collection,
				"server_id": int(store.server_string(id, "id")) if confirmed else 0,
				"kind": store.server_string(id, "kind") if confirmed else pending["kind"],
				"position": position, "velocity": velocity,
			})
	return result

func clear() -> void:
	for store in _stores.values(): store.clear()
	_stores.clear()
	_pending.clear()

func _step_local(local: Variant, dt: float, collection: String) -> void:
	if collection == MISSILES:
		_advance_linear(local, dt)
		return
	var world := _viewport.find_world_3d() if is_instance_valid(_viewport) else null
	if world == null: return
	var elapsed := clampf(dt, 0.0, 0.05)
	var steps := maxi(1, ceili(elapsed / Ballistics.STEP))
	var step := elapsed / float(steps)
	var position := Vector3(local.x, local.y, local.z)
	var velocity := Vector3(local.vx, local.vy, local.vz)
	for i in steps:
		local.age += step
		var result := Ballistics.step(world.direct_space_state, position, velocity, step, local.impact and local.age >= 0.18)
		position = result.position
		velocity = result.velocity
		if result.contact and local.impact and local.age >= 0.18: break
	local.x = position.x
	local.y = position.y
	local.z = position.z
	local.vx = velocity.x
	local.vy = velocity.y
	local.vz = velocity.z

func _advance_linear(state: Variant, dt: float) -> void:
	state.x += state.vx * dt
	state.y += state.vy * dt
	state.z += state.vz * dt
