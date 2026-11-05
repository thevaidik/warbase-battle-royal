extends Node

const Colyseus := preload("res://addons/colyseus/colyseus.gd")

class PlayerState extends Colyseus.Schema:
	static func definition() -> Array:
		return [Colyseus.Schema.Field.new("x", Colyseus.Schema.NUMBER), Colyseus.Schema.Field.new("z", Colyseus.Schema.NUMBER), Colyseus.Schema.Field.new("username", Colyseus.Schema.STRING), Colyseus.Schema.Field.new("mode", Colyseus.Schema.STRING), Colyseus.Schema.Field.new("ack_input_sequence", Colyseus.Schema.NUMBER)]

class CarState extends Colyseus.Schema:
	static func definition() -> Array:
		return [Colyseus.Schema.Field.new("x", Colyseus.Schema.NUMBER), Colyseus.Schema.Field.new("z", Colyseus.Schema.NUMBER), Colyseus.Schema.Field.new("yaw", Colyseus.Schema.NUMBER), Colyseus.Schema.Field.new("speed", Colyseus.Schema.NUMBER), Colyseus.Schema.Field.new("gear", Colyseus.Schema.NUMBER), Colyseus.Schema.Field.new("serial", Colyseus.Schema.INT32), Colyseus.Schema.Field.new("label", Colyseus.Schema.STRING)]

class RootState extends Colyseus.Schema:
	static func definition() -> Array:
		return [Colyseus.Schema.Field.new("players", Colyseus.Schema.MAP, PlayerState), Colyseus.Schema.Field.new("vehicles", Colyseus.Schema.MAP, CarState)]

var client
var room
var input_handle
var predictor
var composite
var player
var car
var elapsed := 0.0
var started := false
var finish_elapsed := 0.0
var call_count := 0
var saw_no_patch_prediction := false
var start_server_z := 0.0
var error_text := ""

func _ready() -> void:
	Engine.max_fps = 60
	client = Colyseus.Client.new("ws://127.0.0.1:18193")
	room = client.join_or_create("composite_probe", {"username": "probe"})
	room.set_state_type(RootState)
	room.joined.connect(_on_joined)
	room.state_changed.connect(_on_state_changed)
	room.error.connect(func(code: int, message: String) -> void: _fail("room error %d: %s" % [code, message]))
	room.set_latency(180.0, 0.0)

func _on_joined() -> void:
	_try_bind()

func _on_state_changed() -> void:
	_try_bind()

func _try_bind() -> void:
	if composite != null: return
	var state = room.get_state()
	if state == null: return
	var players = state.players
	var vehicles = state.vehicles
	if players is Dictionary:
		if not players.has("probe") or not vehicles.has("CAR_0"): return
		player = players.get("probe")
		car = vehicles.get("CAR_0")
	else:
		if not players.has("probe") or not vehicles.has("CAR_0"): return
		player = players.get_item("probe")
		car = vehicles.get_item("CAR_0")
	input_handle = room.input()
	predictor = Colyseus.Predict.of(room)
	if player == null or car == null or input_handle == null:
		_fail("decoded player/car/input missing player=%s car=%s input=%s" % [player, car, input_handle])
		return
	start_server_z = float(car.get("z"))
	composite = predictor.sim({
		"world": {"player": player, "CAR_0": car},
		"input": input_handle,
		"step": Callable(self, "_step"),
	})
	if composite == null:
		_fail("Predict.sim returned null")
		return
	print("SDK_COMPOSITE_JOIN_OK player_type=%s vehicle_type=%s string_field=%s initial_z=%.4f" % [player.get_class(), car.get_class(), str(player.get("username")), start_server_z])

func _process(delta: float) -> void:
	if error_text != "" or room == null or not room.connected: return
	if composite == null:
		_try_bind()
		return
	elapsed += delta
	if elapsed < 0.5: return
	if not started:
		started = true
		room.set_latency(180.0, 0.0)
	if finish_elapsed >= 5.0:
		_finish()
		return
	var steps: int = predictor.tick()
	for _i in steps:
		input_handle.data.throttle = 1.0 if finish_elapsed < 3.0 else 0.0
		input_handle.data.steer = 0.0
		input_handle.data.gear = 2.0
		input_handle.send()
	finish_elapsed += delta
	if finish_elapsed < 0.7:
		var rendered_z: float = composite.value("CAR_0.z")
		if is_finite(rendered_z) and rendered_z < start_server_z - 0.002 and absf(float(car.get("z")) - start_server_z) < 0.002:
			saw_no_patch_prediction = true

func _step(ctx, w, cmd) -> void:
	call_count += 1
	var p = w.get("player")
	var v = w.get("CAR_0")
	if call_count == 1:
		print("SDK_COMPOSITE_MIRROR dynamic_car=%s username=%s label=%s gear_type=%s serial=%s serial_type=%s" % [v != null, str(p.get("username")), str(v.get("label")), type_string(typeof(v.get("gear"))), str(v.get("serial")), type_string(typeof(v.get("serial")))])
	v.gear = cmd.gear
	v.speed += cmd.throttle * 0.24
	v.yaw += cmd.steer * 0.02
	v.x += sin(v.yaw) * v.speed * ctx.dt
	v.z -= cos(v.yaw) * v.speed * ctx.dt
	p.x = v.x
	p.z = v.z

func _finish() -> void:
	var decoded_z := float(car.get("z"))
	var rendered_z: float = composite.value("CAR_0.z")
	var state_z: float = composite.world.get("CAR_0").z
	var outstanding: int = input_handle.sent_count - input_handle.last_processed
	var expected_lead := float(car.get("speed")) * float(outstanding) / 60.0
	var observed_lead := decoded_z - rendered_z
	var integer_mirror_ok: bool = typeof(composite.world.get("CAR_0").serial) == TYPE_INT and composite.world.get("CAR_0").serial == 37
	var result := "OK" if call_count > 60 and saw_no_patch_prediction and absf(observed_lead - expected_lead) < 2.0 and integer_mirror_ok else "FAILED"
	print("SDK_COMPOSITE_%s callbacks=%d sent=%d ack=%d server_ack=%.0f client_predicted_before_patch=%s integer_mirror=%s string_mirror=%s start_z=%.4f decoded_z=%.4f rendered_z=%.4f mirror_z=%.4f lead=%.3f expected_lead=%.3f correction=%.5f decoded_username=%s" % [result, call_count, input_handle.sent_count, input_handle.last_processed, float(player.get("ack_input_sequence")), saw_no_patch_prediction, integer_mirror_ok, str(composite.world.get("CAR_0").label), start_server_z, decoded_z, rendered_z, state_z, observed_lead, expected_lead, composite.last_correction_mag, str(player.get("username"))])
	room.leave()
	get_tree().quit(0 if result == "OK" else 1)

func _fail(message: String) -> void:
	if error_text != "": return
	error_text = message
	push_error("SDK_COMPOSITE_FAILED " + message)
	if room != null: room.leave()
	get_tree().quit(1)
