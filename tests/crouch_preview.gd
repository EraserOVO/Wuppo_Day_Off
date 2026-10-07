extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _capture(path: String) -> void:
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().get_region(Rect2i(850, 435, 260, 200)).save_png(path)

func _run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu.set_physics_process(false)
	menu.states[1].merge({"position": Vector2(1390, 818), "grounded": true}, true)
	var actor = menu.actors[1]
	actor.position = menu.states[1]["position"]
	actor.skin = menu.SKINS.skins[0]
	actor.hat = menu.HATS.hats[3]
	actor.apply_skin()
	actor.apply_hat()
	actor.set_walking(0, true)
	await _capture("res://docs/previews/crouch_standing.png")
	actor.set_crouching(true)
	await _capture("res://docs/previews/crouch_grounded.png")
	quit(0)
