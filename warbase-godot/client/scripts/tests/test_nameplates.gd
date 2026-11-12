extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1
	print("PASS: " if ok else "FAIL: ",message)
func run() -> void:
	var state=root.get_node("GameState");state.selected_mode="CONQUEST";state.local_team="A"
	var camera:=Camera3D.new();root.add_child(camera);camera.current=true
	var packed:PackedScene=load("res://scenes/RemotePlayer.tscn")
	var actor=packed.instantiate();actor.player_id="[BOT] VIPER-01"
	actor.set_meta("init_state",{"health":100,"team":"B","weapon":"ak47","x":0,"y":0,"z":-10})
	actor.use_server_authoritative_remote_pose();root.add_child(actor);actor.set_process(false);actor.global_position=Vector3(0,0,-10)
	var root_spheres := 0
	for child in actor.get_children():
		if child is MeshInstance3D and child.mesh is SphereMesh: root_spheres += 1
	check(actor.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF,"render-owned actor does not receive a second physics interpolation pass")
	check(root_spheres == 0,"identity uses the nameplate without shoulder marker spheres")
	check(actor.name_label.text=="VIPER-01  / AI","bot ID becomes a compact callsign and AI tag")
	check(actor.name_label.font==WarUI.DISPLAY_FONT and actor.name_label.outline_size==6,"3D label uses HUD font and restrained outline")
	check(not actor.name_label.no_depth_test,"nameplates retain wall occlusion")
	check(actor.name_label.modulate==WarUI.DANGER,"opponent uses the shared danger colour")
	actor.push_state({"health":25,"team":"B","weapon":"ak47","x":0,"y":0,"z":-10})
	check(actor.name_label.text=="VIPER-01  / AI","health changes do not replace the styled name with raw HP")
	actor.global_position=Vector3(0,0,-70);actor._update_distance_lod()
	actor.push_state({"health":25,"team":"B","weapon":"ak47","x":0,"y":0,"z":-70})
	check(not actor.name_label.visible,"state updates cannot reveal labels beyond the visibility limit")
	actor.global_position=Vector3(0,0,-1);actor._update_nameplate_visibility()
	check(not actor.name_label.visible,"intersecting close labels stay hidden")
	actor.global_position=Vector3(0,0,-10);actor._update_nameplate_visibility()
	check(actor.name_label.visible,"living visible-range actor retains its label")
	actor.take_damage(100)
	check(not actor.name_label.visible,"dead actor label disappears immediately")
	var human:=Label3D.new();WarUI.configure_nameplate(human);WarUI.refresh_nameplate(human,"Raven_01",true)
	check(human.text=="RAVEN_01" and human.modulate==WarUI.CYAN,"human teammates get the same theme without an AI tag")
	human.free();actor.free();camera.free()
	print("NAMEPLATE_TEST failures=",failures)
	quit(failures)
