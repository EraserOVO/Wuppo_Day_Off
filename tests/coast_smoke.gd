extends SceneTree
const MOTION = preload("res://core/player_motion.gd")
const WORLD = preload("res://core/world_layout.gd")

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		quit(1)
		assert(ok, message)

func _run() -> void:
	for deck in MOTION.PLATFORMS:
		var x: float = deck.get_center().x
		var state := {"position": Vector2(x, MOTION.ground_height(x)), "velocity_y": 0.0, "move": 0, "jumps": 0}
		MOTION.jump(state)
		var passed_up := false
		for frame in 120:
			MOTION.step(state, MOTION.STEP)
			if state["position"].y < deck.position.y and state["velocity_y"] < 0: passed_up = true
		_check(passed_up, "Jump must pass through the deck underside")
		_check(is_equal_approx(state["position"].y, deck.position.y) and state["jumps"] == 0, "Descending player must land on the visible deck and reset jumps")
		state["position"].x = deck.end.x - 1
		state["move"] = 1
		MOTION.step(state, MOTION.STEP)
		_check(state["velocity_y"] > 0 and state["position"].y < MOTION.ground_height(state["position"].x), "Walking off must fall rather than teleport to sand")
		state["move"] = 0
		for frame in 120: MOTION.step(state, MOTION.STEP)
		_check(is_equal_approx(state["position"].y, MOTION.ground_height(state["position"].x)), "Falling player must land on sand")
	var prediction = preload("res://core/motion_prediction.gd").new()
	var authoritative := {"position": MOTION.spawn_position(790), "velocity_y": 0.0, "move": 1, "jumps": 0, "motion_ack": 0}
	prediction.reconcile(authoritative)
	prediction.direction = 1
	for frame in 100:
		prediction.jump_pending = frame == 15 or frame == 35
		if prediction.jump_pending: MOTION.jump(authoritative)
		MOTION.step(authoritative, MOTION.STEP)
		prediction.tick()
	_check(prediction.state["position"].is_equal_approx(authoritative["position"]), "Client prediction must agree across platform edges and double jumps")
	var actor = load("res://actors/wum/wum.tscn").instantiate()
	actor.scale = Vector2.ONE * WORLD.ACTOR_SCALE
	root.add_child(actor)
	await process_frame
	actor.set_process(false)
	actor.is_local_player = true
	actor.warning_enabled = false
	actor.current_state = "blowing"
	actor.target_ratio = 0.5
	actor.shown_ratio = 0.5
	actor.state_age = 0
	for skin in preload("res://assets/characters/skin_catalog.tres").skins:
		actor.skin = skin
		actor.apply_skin()
		for facing in [-1, 1]:
			actor.set_facing_direction(facing)
			actor._process(0)
			var size := lerpf(20, skin.bubble_max_size, 0.5)
			_check(actor.get_node("Bubble").position.is_equal_approx(actor.bubble_origin(size)), "Charging bubble must attach to the tube outlet for every skin and facing")
			_check(is_equal_approx(absf(actor.bubble_origin(size).x - actor.tube_point(actor.TUBE_LENGTH).x), size * 0.5 - 2), "Bubble must touch the outlet rather than cover the cone")
	actor.position = Vector2(500, 650)
	var emission: Vector2 = actor.position + actor.bubble_origin(64) * actor.scale
	actor.play_event({"event_id": 1, "kind": "release", "ratio": 0.5, "position": actor.position})
	var effect = root.get_child(root.get_child_count() - 1)
	_check(effect != actor and effect.position.distance_to(emission) < 0.01, "Released bubble must start at the same outlet")
	actor.queue_free()
	effect.queue_free()
	await process_frame
	print("COAST PASSED: three one-way platforms, sand landing, walk-off gravity, deterministic prediction, eight skins, mirrored cone and release origin")
	if "render" in OS.get_cmdline_user_args():
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1920, 1080)
		var settings = root.get_node("GameSettings")
		settings.preferences_path = "res://.godot/coast_test_preferences.cfg"
		settings.profiles[1]["keys"] = settings.DEFAULT_KEYS[0].duplicate()
		settings.profiles[2]["keys"] = settings.DEFAULT_KEYS[1].duplicate()
		var menu = load("res://scenes/main_menu.tscn").instantiate()
		root.add_child(menu)
		await process_frame
		menu._change_mode(1)
		menu._launch()
		await create_timer(5.3).timeout
		var controller = root.get_node("MatchController")
		for id in [1, 2]:
			controller.states[id]["position"] = Vector2(870 if id == 1 else 1040, 650)
			controller.states[id]["move"] = 0
		controller.accept_input(1, controller.round_id, 1, true)
		controller.accept_input(2, controller.round_id, 1, true)
		await create_timer(0.65).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/previews/coast_blowing_1920x1080.png")
		root.get_node("NetworkSession").leave()
		menu.queue_free()
	await process_frame
	await process_frame
	quit(0)

