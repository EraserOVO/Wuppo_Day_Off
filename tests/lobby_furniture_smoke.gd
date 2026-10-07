extends SceneTree
const MOTION = preload("res://core/lobby_motion.gd")

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		quit(1)
		assert(ok, message)

func _run() -> void:
	for key in MOTION.SURFACES:
		var rect: Rect2 = MOTION.SURFACES[key]
		var x := rect.get_center().x
		var state := {"position": Vector2(x, rect.position.y + 40), "velocity_y": 0.0, "move": 0, "jumps": 0}
		MOTION.jump(state)
		var crossed_up := false
		for frame in 15:
			MOTION.step(state, 1.0 / 60)
			if state["position"].y < rect.position.y and state["velocity_y"] < 0: crossed_up = true
		_check(crossed_up, "Furniture must allow jumping through from below: " + key)
		state["position"] = Vector2(x, rect.position.y - 20)
		state["velocity_y"] = 120.0
		state["jumps"] = 2
		for frame in 120: MOTION.step(state, 1.0 / 60)
		_check(is_equal_approx(state["position"].y, rect.position.y), "Furniture must catch descending players: " + key)
		_check(state["jumps"] == 0 and MOTION.is_supported(state["position"]), "Landing must restore jumps: " + key)
		state["position"].x = rect.end.x - 1
		state["move"] = 1
		MOTION.step(state, 1.0 / 60)
		_check(state["velocity_y"] > 0 and state["position"].y < 880, "Walk-off must fall naturally: " + key)
	_check(MOTION.nearby(Vector2(390, 720)) == "衣柜", "Wardrobe interaction must work from its roof")
	_check(MOTION.nearby(Vector2(980, 792)) == "电脑", "Computer interaction must work while standing on desk")
	_check(MOTION.nearby(Vector2(1560, 880)) == "门", "Resized door must remain interactive")
	_check(MOTION.nearby(Vector2(580, 658)).is_empty(), "Decorative shelves must not open distant furniture")
	var settings = root.get_node("GameSettings")
	settings.preferences_path = "res://.godot/furniture_test_preferences.cfg"
	for slot in [1, 2]: settings.profiles[slot]["keys"] = settings.DEFAULT_KEYS[slot - 1].duplicate()
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu._change_mode(1)
	menu.states[1]["position"] = Vector2(390, 720)
	menu.states[2]["position"] = Vector2(980, 792)
	await create_timer(0.05).timeout
	_check(menu._nearby(1) == "衣柜" and menu._nearby(2) == "电脑", "Players must independently interact from furniture platforms")
	_check(menu.prompts[1].visible and menu.prompts[2].visible, "Platform interaction prompts must use each player's key")
	_check(menu.prompts[1].follow_target.y < menu.actors[1].head_position().y, "Platform prompt must follow above hat")
	menu.queue_free()
	await process_frame
	print("LOBBY FURNITURE PASSED: nine real furniture surfaces, jump-through, landing, walk-off gravity and independent elevated interactions")
	quit(0)
