extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- INSPECTING UI LAYOUT & SIZING AT MULTIPLE RESOLUTIONS ---")
	
	var menu_script: GDScript = load("res://scripts/ui/MainMenu.gd")
	var menu: WarMenu = menu_script.new()
	root.add_child(menu)
	
	for i in 5:
		await process_frame
		
	var test_res := [
		Vector2i(1280, 720),
		Vector2i(1920, 1080),
		Vector2i(2560, 1440),
		Vector2i(1440, 900)
	]
	
	for res in test_res:
		root.size = res
		menu._on_window_resized()
		for i in 2:
			await process_frame
			
		print("\n=== Testing resolution: %s ===" % res)
		print("Viewport visible rect: ", root.get_viewport().get_visible_rect())
		print("LobbyRoot size: ", menu.root.size, " pos: ", menu.root.position)
		print("MainLayout size: ", menu.main_layout.size, " pos: ", menu.main_layout.position)
		
		var footer := menu.main_layout.get_child(menu.main_layout.get_child_count() - 1) as Control
		print("Footer panel size: ", footer.size, " global_pos: ", footer.global_position)
		print("Join btn size: ", menu.join_btn.size, " global_pos: ", menu.join_btn.global_position)
		
		var is_footer_visible: bool = (footer.global_position.y + footer.size.y <= res.y + 2)
		var is_join_on_screen: bool = (menu.join_btn.global_position.y >= 0 and (menu.join_btn.global_position.y + menu.join_btn.size.y) <= res.y + 2)
		print("Footer visible inside window? ", is_footer_visible, " (Bottom Y: %.1f vs Window H: %d)" % [footer.global_position.y + footer.size.y, res.y])
		print("Join button on screen? ", is_join_on_screen, " (Join Y: %.1f)" % menu.join_btn.global_position.y)
		
		# Test hover check at Join button center
		var join_center := menu.join_btn.global_position + menu.join_btn.size * 0.5
		var hovered := root.get_viewport().gui_get_hovered_control()
		print("Hovered control at join center (%s): %s" % [join_center, hovered.name if hovered else "NONE"])
		
	quit()
