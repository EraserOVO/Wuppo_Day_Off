extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _capture(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func _run() -> void:
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await create_timer(0.3).timeout
	await _capture("res://docs/previews/menu_room.png")
	menu._change_mode(1)
	await _capture("res://docs/previews/menu_room_duo.png")
	menu._open("电脑", 2)
	await _capture("res://docs/previews/menu_room_settings.png")
	menu._close()
	menu._launch()
	await create_timer(0.2).timeout
	await _capture("res://docs/previews/menu_room_loading.png")
	quit(0)
