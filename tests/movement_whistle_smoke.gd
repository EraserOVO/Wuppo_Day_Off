extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _key(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	root.push_input(event, true)

func _check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		quit(1)
		assert(value, message)

func _tap(code: int) -> void:
	_key(code, true)
	_key(code, false)

func _run() -> void:
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	var session = root.get_node("NetworkSession")
	var controller = root.get_node("MatchController")
	menu._change_mode(1)
	menu._launch()
	await create_timer(5.3).timeout
	_check(session.phase == "PLAYING", "Match did not begin")
	var first: Dictionary = controller.states[1]
	var second: Dictionary = controller.states[2]
	var initial_x: float = first["position"].x
	_key(KEY_D, true)
	_key(KEY_LEFT, true)
	await create_timer(0.15).timeout
	_key(KEY_D, false)
	_key(KEY_LEFT, false)
	_check(first["position"].x > initial_x and second["position"].x < 1580.0, "Independent movement failed")
	_check(first["move"] == 0 and second["move"] == 0, "Movement release failed")
	_tap(KEY_W)
	await create_timer(0.081428571).timeout
	_check(first["jumps"] == 1 and first["position"].y < 880.0, "First jump failed")
	_tap(KEY_W)
	_check(first["jumps"] == 2 and first["velocity_y"] < -400.0, "Second jump failed")
	first["velocity_y"] = -100.0
	_tap(KEY_W)
	_check(first["jumps"] == 2 and first["velocity_y"] == -100.0, "Third jump was incorrectly allowed")
	await create_timer(0.8).timeout
	_check(preload("res://core/player_motion.gd").is_supported(first["position"]) and first["jumps"] == 0, "Landing did not reset jumps")
	first["position"] = Vector2(1775, 880)
	_key(KEY_D, true)
	await create_timer(0.05).timeout
	_check(first["position"].x <= 1776.0, "Player escaped stage")
	menu.match_view._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(first["move"] == 0, "Focus loss did not stop movement")
	first["position"] = Vector2(800, 880)
	second["position"] = Vector2(1000, 880)
	_key(KEY_K, true)
	_key(KEY_KP_0, true)
	_tap(KEY_L)
	_check(second["charge_bonus"] == 0.0, "Blowing player was allowed to whistle")
	_key(KEY_K, false)
	_tap(KEY_L)
	_check(is_equal_approx(second["charge_bonus"], 0.081428571), "Nearby whistle did not add distance-weighted charge")
	_tap(KEY_L)
	_check(is_equal_approx(second["charge_bonus"], 0.081428571), "Whistle cooldown failed")
	first["whistle_ready"] = 0.0
	second["position"] = Vector2(800, 280)
	_tap(KEY_L)
	_check(is_equal_approx(second["charge_bonus"], 0.081428571), "Whistle ignored vertical distance")
	_key(KEY_KP_0, false)
	_check(second["score"] == 0, "Whistle bonus bypassed minimum actual hold time")
	second["position"] = Vector2(1000, 880)
	second["last_input"] = -1.0
	_key(KEY_KP_0, true)
	second["start"] = Time.get_ticks_msec() / 1000.0 - float(second["limit"]) * 0.96
	first["whistle_ready"] = 0.0
	_tap(KEY_L)
	_check(second["state"] == "burst" and second["score"] == 0, "Whistle did not burst a near-full bubble")
	_key(KEY_KP_0, false)
	controller._publish()
	_check(menu.match_view.scores[2].has("position") and menu.match_view.scores[2].has("charge_bonus"), "Snapshot missing mechanics")
	session.leave()
	await process_frame
	await process_frame
	session.start_practice("Solo controls")
	await create_timer(5.3).timeout
	first = controller.states[1]
	var bot: Dictionary = controller.states[-1]
	_key(KEY_A, true)
	_check(first["move"] == -1, "Single-player movement binding failed")
	_key(KEY_A, false)
	_tap(KEY_W)
	_check(first["jumps"] == 1, "Single-player jump binding failed")
	bot["position"] = first["position"] + Vector2(160, 0)
	bot["state"] = "blowing"
	bot["start"] = Time.get_ticks_msec() / 1000.0
	bot["limit"] = 2.0
	bot["charge_bonus"] = 0.0
	controller.bot_release_time = bot["start"] + 1.0
	_tap(KEY_L)
	_check(is_equal_approx(bot["charge_bonus"], 0.087142857), "Single-player whistle binding failed")
	_key(KEY_K, true)
	_check(first["state"] == "blowing", "Single-player bubble binding failed")
	_key(KEY_K, false)
	session.leave()
	menu.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.1).timeout
	print("MECHANICS: movement, double jump, landing, stage bounds, focus loss, whistle eligibility/radius/cooldown/charge/burst and snapshots passed")
	quit(0)



