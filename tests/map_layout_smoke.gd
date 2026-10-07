extends SceneTree
const WORLD = preload("res://core/world_layout.gd")

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		quit(1)
		assert(ok, message)

func _capture(path: String) -> void:
	if not "render" in OS.get_cmdline_user_args(): return
	await create_timer(0.9).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func _run() -> void:
	root.mode = Window.MODE_WINDOWED
	var settings = root.get_node("GameSettings")
	settings.profiles[1]["keys"] = settings.DEFAULT_KEYS[0].duplicate()
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	for child in menu.room.get_children(): _check(not child is Label, "Room must not contain object names or decorative headings")
	menu.states[1]["position"] = Vector2(390, WORLD.FLOOR_Y)
	menu.actors[1].position = menu.states[1]["position"]
	await process_frame
	_check(menu.prompts[1].visible and menu.prompts[1].code == -MOUSE_BUTTON_LEFT, "Default solo interaction must show the mouse-left icon above the player")
	_check(menu.prompts[1].follow_target.y < menu.actors[1].head_position().y, "Interaction prompt must sit above the hat")
	var prompt = menu.prompts[1]
	var meter = load("res://ui/circular_meter.gd").new()
	menu.room.add_child(meter)
	meter.set_process(false)
	prompt.set_process(false)
	var origin: Vector2 = prompt.global_position
	prompt.set_follow_target(origin, true)
	meter.set_follow_target(origin, true)
	prompt.set_follow_target(origin + Vector2(160, -60))
	meter.set_follow_target(origin + Vector2(160, -60))
	for step in 30:
		prompt._process(1.0 / 60)
		meter._process(1.0 / 60)
		_check(prompt.global_position.is_equal_approx(meter.global_position), "Interaction prompt and circular meter must use identical eased follow motion")
	meter.queue_free()
	prompt.set_process(true)
	settings.keys(1)[3] = KEY_E
	await process_frame
	_check(prompt.code == KEY_E, "Interaction icon must update to the player's rebound key")
	menu._change_mode(1)
	menu.states[2]["position"] = Vector2(1560, WORLD.FLOOR_Y)
	menu.actors[2].position = menu.states[2]["position"]
	await process_frame
	_check(menu.prompts[2].visible and menu.prompts[2].code == KEY_KP_0, "P2 must see its own interaction key")
	for dimensions in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(2560, 1080), Vector2i(1600, 1200), Vector2i(900, 1600)]:
		root.size = dimensions
		await process_frame
		await process_frame
		var visible := WORLD.visible_world(menu.room)
		var transform: Transform2D = menu.room.get_global_transform_with_canvas()
		var painted := Rect2(transform * visible.position, visible.size * transform.get_scale())
		_check(painted.position.length() < 1 and painted.size.distance_to(root.get_visible_rect().size) < 1, "Room background must cover every screen edge")
		_check(is_equal_approx(transform.get_scale().x, transform.get_scale().y), "Room must preserve aspect ratio")
		var arena := Rect2(transform * Vector2.ZERO, WORLD.SIZE * transform.get_scale())
		_check(arena.position.x >= -1 and arena.position.y >= -1 and arena.end.x <= painted.end.x + 1 and arena.end.y <= painted.end.y + 1, "Room furniture and playable area must remain visible")
		await _capture("res://docs/previews/room_%sx%s.png" % [dimensions.x, dimensions.y])
	menu._launch()
	await create_timer(5.3).timeout
	var session = root.get_node("NetworkSession")
	_check(session.phase == "PLAYING", "Match must still start after map refactor")
	for dimensions in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(2560, 1080), Vector2i(1600, 1200), Vector2i(900, 1600)]:
		root.size = dimensions
		await process_frame
		await process_frame
		var visible := WORLD.visible_world(menu.match_view.get_node("Background"))
		_check(visible.has_point(Vector2(0, 0)) and visible.end.x >= WORLD.SIZE.x - 1 and visible.end.y >= WORLD.SIZE.y - 1, "Entire 1920x1080 arena must stay visible")
		var canvas: Transform2D = root.get_canvas_transform()
		_check(is_equal_approx(canvas.get_scale().x, canvas.get_scale().y), "Match camera must preserve aspect ratio")
		await _capture("res://docs/previews/match_%sx%s.png" % [dimensions.x, dimensions.y])
	print("MAP LAYOUT PASSED: native 1920x1080, screen-edge coverage, no stretching/cropping, solo/P2/rebound prompts and shared eased following")
	session.leave()
	await process_frame
	_check(menu.room.visible, "Map must return after the match camera exits")
	quit(0)
