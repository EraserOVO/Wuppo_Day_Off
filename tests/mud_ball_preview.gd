extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	root.get_node("NetworkSession").set_game_mode("mud_ball")
	menu._change_mode(1)
	menu._launch()
	await create_timer(5.8).timeout
	var controller = root.get_node("MatchController")
	controller.set_physics_process(false)
	controller.ball.active = true
	controller.ball.position = Vector2(1200, 650)
	controller.ball.velocity = Vector2.ZERO
	await create_timer(0.1).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/mud_ball_preview.png")
	# Close-up rendered by the actual scene and actor nodes, not duplicate artwork.
	var view = menu.match_view
	var actor: Node2D = view.actors[1]
	controller.ball.position = actor.position + Vector2(125, -70)
	view.hud.visible = false
	view.camera.position = actor.position + Vector2(60, -50)
	view.camera.zoom = Vector2.ONE * 3.0
	view.camera.force_update_scroll()
	await create_timer(0.1).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/previews/mud_ball_character_detail.png")
	root.get_node("NetworkSession").leave()
	menu.queue_free()
	await process_frame
	await process_frame
	quit()
