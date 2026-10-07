extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	var session = root.get_node("NetworkSession")
	session.start_practice("显示测试")
	await process_frame
	await process_frame
	await create_timer(0.2).timeout
	var game = menu.match_view
	game.scores = {1: {"score": 120, "best": 20, "released": 8, "bursts": 1}, -1: {"score": 100, "best": 18, "released": 7, "bursts": 2}}
	for dimensions in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(2560, 1080), Vector2i(720, 1280)]:
		root.size = dimensions
		await process_frame
		await process_frame
		session.change_phase("PLAYING")
		game._layout_display()
		await process_frame
		var view := root.get_visible_rect().size
		var scale_xy := root.get_final_transform().get_scale()
		assert(absf(scale_xy.x - scale_xy.y) < 0.001, "Nonuniform window scale")
		var canvas := root.get_canvas_transform()
		var center := canvas * Vector2(960, 540)
		assert(center.distance_to(view * 0.5) < 1.0, "Arena must be centered")
		assert(canvas.get_scale().x == canvas.get_scale().y, "Nonuniform arena scale")
		var arena := Rect2(canvas * Vector2.ZERO, Vector2(1920, 1080) * canvas.get_scale())
		assert(arena.position.x >= -1.0 and arena.position.y >= -1.0, "Arena clipped at origin")
		assert(arena.end.x <= view.x + 1 and arena.end.y <= view.y + 1, "Arena clipped at end")
		var right: Label = game.get_node("HUD/EnemyScore")
		assert(absf(right.position.x + right.size.x - (view.x - 24)) < 1, "Score not at right edge")
		session.change_phase("COUNTDOWN")
		game._update_score_labels()
		assert(not right.visible, "Opponent score visible during countdown")
		assert(game.get_node("HUD/Timer").size == view, "Countdown not viewport centered")
		session.change_phase("RESULTS")
		game._show_results()
		await process_frame
		var panel: Control = game.get_node("HUD/Panel")
		assert(panel.position.x >= 0 and panel.position.y >= 0, "Results clipped")
		assert(panel.get_rect().end.x <= view.x and panel.get_rect().end.y <= view.y, "Results exceed viewport")
		print("DISPLAY PASS ", dimensions, " logical=", view, " arena=", arena)
		if "--render-check" in OS.get_cmdline_user_args() and dimensions == Vector2i(1280, 720):
			session.change_phase("PLAYING")
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://tests/display_widescreen.png")
	session.leave()
	await process_frame
	await process_frame
	assert(menu.room.visible and menu.room.scale.x == menu.room.scale.y, "Menu room must return without distortion")
	print("DISPLAY: all aspect ratios passed")
	quit(0)


