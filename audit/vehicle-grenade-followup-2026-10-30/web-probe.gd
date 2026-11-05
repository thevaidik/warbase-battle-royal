extends Node
const SDK = preload("res://addons/colyseus/colyseus.gd")
const Types = preload("res://Schema.gd")
var client
var room
var predictor
var input_handle
var controller
var channels: Array = []
var elapsed := 0.0
var rejected: Array[String] = []
func _ready() -> void:
 Engine.max_fps=60
 client=SDK.Client.new("ws://127.0.0.1:18195")
 room=client.join_or_create("battle",{"room":"industrial-public","username":"WebExpiryProbe"})
 room.set_state_type(Types.RoomState)
 room.error.connect(func(code,message): finish(false,"room error %s %s" % [code,message]))
 await run()
func _process(delta: float) -> void:
 elapsed+=delta
 if elapsed>20: finish(false,"deadline")
 if predictor==null:return
 var steps: int=predictor.tick()
 for i in steps:
  input_handle.data.move_x=0.0
  input_handle.data.move_z=0.0
  input_handle.data.vehicle_index=-1.0
  input_handle.data.vehicle_generation=0.0
  input_handle.send()
func run() -> void:
 while not room.connected or room.get_state()==null or not room.get_state().players.has("WebExpiryProbe"):
  await get_tree().process_frame
 predictor=SDK.Predict.of(room)
 input_handle=room.input()
 var state=room.get_state()
 controller=predictor.sim({"world":{"player":state.players["WebExpiryProbe"],"CAR_0":state.vehicles["CAR_0"]},"input":input_handle,"step":func(_ctx,_world,_cmd):pass})
 for ttl in [150.0,0.0,5000.0]:
  rejected.clear()
  var channel=predictor.define_event({"ttl_ms":ttl,"on_reject":func(key):rejected.append(str(key))})
  channels.append(channel)
  if not channel.predict("expire"):finish(false,"predict refused");return
  var deadline=Time.get_ticks_msec()+int(maxf(2000,ttl+1500))
  while rejected.is_empty() and Time.get_ticks_msec()<deadline:await get_tree().process_frame
  if rejected!=["expire"] or channel.pending_count!=0:finish(false,"expiry ttl=%s rejected=%s pending=%s" % [ttl,rejected,channel.pending_count]);return
  print("SDK_WEB_EXPIRY_STEP_OK ttl=",ttl)
  channel.predict("accepted")
  if channel.confirm("accepted")!=1 or channel.confirm("accepted")!=0:finish(false,"duplicate confirmation");return
  channel.predict("refused")
  channel.reject("refused")
  channel.predict("clear")
  channel.clear()
  if channel.pending_count!=0:finish(false,"clear left pending");return
 finish(true,"short/default/production TTL; confirm; duplicate; reject; clear; composite active")
func finish(ok: bool, detail: String) -> void:
 print("SDK_EVENT_EXPIRY_WEB_%s %s" % ["OK" if ok else "FAILED",detail])
 if room!=null:room.leave()
 set_process(false)
 var label=Label.new();label.text="SDK_EVENT_EXPIRY_WEB_%s\n%s" % ["OK" if ok else "FAILED",detail];add_child(label)
