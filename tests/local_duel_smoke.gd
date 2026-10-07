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

func _run() -> void:
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	var session = root.get_node("NetworkSession")
	var controller = root.get_node("MatchController")
	root.get_node("GameSettings").profiles[1]["circular"] = false
	root.get_node("GameSettings").profiles[2]["circular"] = false
	menu._change_mode(1)
	menu._launch()
	await create_timer(5.3).timeout
	_check(session.local_duel and session.phase == "PLAYING", "Local duel did not start")
	_check(not session.practice and controller.states.size() == 2, "Local duel must have two humans")
	_check(menu.match_view.second_meter.visible, "Second meter is missing")
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	_check(session.paused, "Escape did not pause a local-duel match")
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	_check(not session.paused, "Escape did not resume a local-duel match")
	_key(KEY_K, true)
	_key(KEY_KP_0, true)
	await create_timer(0.4).timeout
	_key(KEY_K, false)
	await process_frame
	_check(controller.states[1]["score"] > 0, "Player 1 did not score")
	_check(controller.states[2]["state"] == "blowing" and controller.states[2]["score"] == 0, "Player 1 release affected player 2")
	_key(KEY_KP_0, false)
	await process_frame
	_check(controller.states[2]["score"] > 0, "Player 2 did not score")
	var previous: int = controller.states[1]["score"]
	_key(KEY_K, true)
	await create_timer(0.1).timeout
	_key(KEY_K, false)
	_check(controller.states[1]["score"] == previous, "Short press incorrectly scored")
	_key(KEY_KP_0, true)
	menu.match_view._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(controller.states[2]["state"] == "idle", "Focus loss did not release player 2")
	controller.deadline = Time.get_ticks_msec() / 1000.0 - 0.1
	await process_frame
	await process_frame
	_check(session.phase == "RESULTS", "Local duel did not finish")
	menu.match_view.get_node("HUD/Panel/ReturnButton").pressed.emit()
	await process_frame
	await process_frame
	_check(session.phase == "LOADING" and session.local_duel, "Local duel replay failed")
	session.leave()
	_check(not session.local_duel and session.players.is_empty(), "Local duel did not clean up")
	menu.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.1).timeout
	print("LOCAL DUEL: simultaneous keys, independent scoring, minimum hold, focus loss, results, replay and exit passed")
	quit(0)


