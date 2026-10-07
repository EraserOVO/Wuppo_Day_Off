extends SceneTree

const BUBBLE_CONFIG = preload("res://modes/bubble_race/bubble_config.tres")

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		quit(1)
		assert(value, message)

func _run() -> void:
	_check(BUBBLE_CONFIG.bubble_seconds_min < 1.1 and BUBBLE_CONFIG.bubble_seconds_max > 2.5, "Bubble duration range was not expanded")
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	var session = root.get_node("NetworkSession")
	menu._open("门", 1)
	var button: Button
	for child in menu.form.get_children():
		if child is Button and child.text == "启动比赛": button = child
	await process_frame
	await process_frame
	var center := button.get_global_rect().get_center()
	print("PRACTICE: clicking button at ", center)
	var motion := InputEventMouseMotion.new()
	motion.position = center
	motion.global_position = center
	root.push_input(motion, true)
	await process_frame
	print("PRACTICE: hovered control=", root.gui_get_hovered_control())
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = center
	down.global_position = center
	down.pressed = true
	root.push_input(down, true)
	await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = center
	up.global_position = center
	up.pressed = false
	root.push_input(up, true)
	await process_frame
	print("PRACTICE: phase=", session.phase, " active=", session.active)
	if session.phase not in ["LOADING", "COUNTDOWN"]:
		push_error("Practice did not start")
		quit(1)
		return
	await create_timer(5.3).timeout
	print("PRACTICE: phase after countdown=", session.phase)
	if session.phase != "PLAYING":
		push_error("Practice did not enter PLAYING")
		quit(1)
		return
	var escape_down := InputEventKey.new()
	escape_down.physical_keycode = KEY_ESCAPE
	escape_down.pressed = true
	root.push_input(escape_down, true)
	_check(session.paused, "Escape did not pause single-player practice")
	var escape_up := InputEventKey.new()
	escape_up.physical_keycode = KEY_ESCAPE
	escape_up.pressed = false
	root.push_input(escape_up, true)
	var escape_resume := InputEventKey.new()
	escape_resume.physical_keycode = KEY_ESCAPE
	escape_resume.pressed = true
	root.push_input(escape_resume, true)
	_check(not session.paused, "Escape did not resume single-player practice")
	var controller = root.get_node("MatchController")
	session.submit_input(true)
	await create_timer(0.35).timeout
	session.submit_input(false)
	await process_frame
	if int(controller.states[1]["score"]) <= 0:
		push_error("Released bubble did not score")
		quit(1)
		return
	var actor = menu.match_view.actors[1]
	if actor.hop_elapsed >= actor.skin.release_hop_duration:
		push_error("Release hop did not start")
		quit(1)
		return
	print("PRACTICE: score and release hop passed")
	session.submit_input(true)
	controller.states[1]["start"] = Time.get_ticks_msec() / 1000.0 - float(controller.states[1]["limit"]) - 0.1
	await process_frame
	await process_frame
	if controller.states[1]["state"] != "burst":
		push_error("Bubble did not burst at assigned duration")
		quit(1)
		return
	session.submit_input(false)
	controller.deadline = Time.get_ticks_msec() / 1000.0 - 0.1
	await process_frame
	await process_frame
	if session.phase != "RESULTS":
		push_error("Round did not finish")
		quit(1)
		return
	menu.match_view.get_node("HUD/Panel/ReturnButton").pressed.emit()
	await process_frame
	await process_frame
	if session.phase != "LOADING":
		push_error("Replay did not start")
		quit(1)
		return
	print("PRACTICE: burst, results and replay passed")
	session.leave()
	await process_frame
	menu.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.1).timeout
	quit(0)

