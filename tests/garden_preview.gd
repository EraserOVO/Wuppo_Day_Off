extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _capture(path: String) -> void:
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func _run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var garden = root.get_node("GardenSave")
	garden.save_path = "res://.godot/garden_preview_unused.json"
	garden.load_save()
	garden.seeds = {"blueberry": 3, "onion": 4}
	garden.produce = {"blueberry": 2, "onion": 1}
	var now := Time.get_unix_time_from_system()
	garden.plots[0] = {"plant": "blueberry", "planted_at": now - 181}
	garden.plots[1] = {"plant": "onion", "planted_at": now - 91}
	garden.plots[2] = {"plant": "blueberry", "planted_at": now - 25}
	garden.plots[3] = {"plant": "onion", "planted_at": now - 48}
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu.set_physics_process(false)
	menu.states[1].merge({"lobby_area": "backyard", "position": Vector2(640, 880)}, true)
	menu.actors[1].position = menu.states[1]["position"]
	menu._process(0)
	await _capture("res://docs/previews/backyard.png")
	menu._open("种子摊", 1)
	await _capture("res://docs/previews/backyard_shop.png")
	menu._close()
	menu._open("种植地 1", 1)
	await _capture("res://docs/previews/backyard_harvest.png")
	menu._close()
	menu._change_mode(1)
	menu.states[2]["position"] = Vector2(1090, 880)
	menu.states[2]["lobby_area"] = "room"
	menu._process(0)
	await _capture("res://docs/previews/backyard_split.png")
	print("USER_DATA_DIRECTORY: " + OS.get_user_data_dir())
	quit(0)
