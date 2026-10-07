extends SceneTree

const LOBBY_MOTION = preload("res://core/lobby_motion.gd")

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		quit(1)
		assert(ok, message)

func _key(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	root.push_input(event, true)

func _run() -> void:
	var settings = root.get_node("GameSettings")
	settings.preferences_path = "res://.godot/menu_test_preferences.cfg"
	for slot in [1, 2]: settings.profiles[slot]["keys"] = settings.DEFAULT_KEYS[slot - 1].duplicate()
	var session = root.get_node("NetworkSession")
	var controller = root.get_node("MatchController")
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	_check(menu.mode == 0 and menu.actors.size() == 1 and not session.active, "Startup must enter single-player interactive room")
	var edge_state := {"position": Vector2(150, 880), "move": -1, "velocity_x": 0.0, "velocity_y": 0.0, "jumps": 0}
	for frame in 60: LOBBY_MOTION.step(edge_state, 1.0 / 60.0)
	_check(float(edge_state["position"].x) < 144.0, "Left room air wall still blocks movement")
	edge_state["position"] = Vector2(1770, 880)
	edge_state["velocity_x"] = 0.0
	edge_state["move"] = 1
	for frame in 60: LOBBY_MOTION.step(edge_state, 1.0 / 60.0)
	_check(edge_state.get("lobby_area") == "backyard", "Right room edge must lead into the backyard")
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	menu._input(escape)
	_check(menu.quit_confirmation.visible, "Escape must open the quit confirmation")
	menu.quit_confirmation.close_dialog()
	menu._open("衣柜", 1)
	_check(menu.modal.size.x >= root.size.x * 0.9 and menu.modal.size.y >= root.size.y * 0.89, "Furniture window must cover most of the screen")
	_check(menu.section_grid.get_child_count() == 2, "Wardrobe must show separate skin and hat sections")
	var has_close_button := false
	for node in menu.modal.find_children("*", "Button", true, false):
		if node.text == "×": has_close_button = true
	_check(has_close_button, "Furniture window close button is missing")
	menu._close()
	var before: float = menu.states[1]["position"].x
	_key(KEY_D, true)
	await create_timer(0.2).timeout
	_key(KEY_D, false)
	_check(menu.states[1]["position"].x > before + 20, "Room movement failed")
	menu.states[1]["position"] = Vector2(390, 880)
	_key(KEY_K, true)
	_key(KEY_K, false)
	_check(menu.modal.visible and menu.modal_kind == "衣柜", "Bubble key must interact with wardrobe")
	menu._appearance(1, "skin", 3)
	menu._appearance(1, "hat", 2)
	_check(menu.actors[1].skin == menu.SKINS.skins[3] and menu.actors[1].hat == menu.HATS.hats[2], "Appearance preview failed")
	menu._close()
	_key(KEY_L, true)
	_key(KEY_L, false)
	_check(menu.actors[1].whistle_time > 0 and controller.states.is_empty(), "Lobby whistle must only play effects")
	menu._change_mode(1)
	_check(menu.actors.size() == 2 and menu.states.has(2), "Local duo must spawn both humans before a match")
	menu._appearance(2, "skin", 5)
	menu._appearance(2, "hat", 3)
	_check(menu.actors[1].skin != menu.actors[2].skin, "P2 wardrobe changed P1")
	menu.states[2]["position"] = Vector2(980, 880)
	_key(KEY_KP_0, true)
	_key(KEY_KP_0, false)
	_check(menu.modal_owner == 2 and menu.modal_kind == "电脑", "P2 cannot open own settings")
	menu._open("电脑", 1)
	for child in menu.form.get_children():
		if child is Button and child.text.begins_with("吹泡泡 / 大厅交互"):
			child.pressed.emit()
	_key(KEY_F, true)
	_key(KEY_F, false)
	_check(settings.keys(1)[3] == KEY_F and menu.capture_action == -1, "Computer key capture did not save the new binding")
	settings.profiles[1]["circular"] = false
	settings.profiles[2]["circular"] = true
	settings.circular_meters = false
	settings.profiles[1]["volume"] = 0.8
	settings.profiles[2]["volume"] = 0.2
	settings.apply_volume(true)
	_check(is_equal_approx(root.get_node("AudioManager").volume, 0.5), "Shared speaker volume did not respect both player settings")
	settings.save()
	var saved := ConfigFile.new()
	_check(saved.load(settings.preferences_path) == OK and saved.get_value("p1", "keys")[3] == KEY_F and saved.get_value("p2", "hat") == 3, "Player preferences did not persist independently")
	menu._close()
	menu._launch()
	_check(session.phase == "LOADING" and menu.loading.visible, "Launch must show a loading screen")
	await create_timer(0.5).timeout
	_check(session.phase == "LOADING" and not session.loaded.has(1), "Loading tips must remain visible before acknowledgement")
	_check(menu.loading_text.text.contains("F") and menu.loading_text.text.contains("小提示"), "Loading must show actual bindings and a tip")
	await create_timer(4.9).timeout
	_check(session.phase == "PLAYING", "Local match failed to finish loading/countdown")
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	_check(session.paused, "Escape did not pause local-duel gameplay")
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	_check(not session.paused, "Escape did not resume local-duel gameplay")
	_check(menu.match_view.get_node("HUD/Meter").visible and not menu.match_view.second_meter.visible, "Per-player meter styles were not applied")
	_check(not menu.match_view.circular_meters.has(1) and menu.match_view.circular_meters.has(2), "P2 circular meter must exist even when P1 uses bars")
	_key(KEY_F, true)
	_key(KEY_KP_0, true)
	await create_timer(0.4).timeout
	_key(KEY_F, false)
	_check(controller.states[1]["score"] > 0 and controller.states[2]["state"] == "blowing", "Rebound controls must score independently")
	_key(KEY_KP_0, false)
	_check(controller.states[2]["score"] > 0, "P2 did not score")
	controller.deadline = Time.get_ticks_msec() / 1000.0 - 0.1
	await create_timer(0.2).timeout
	_check(session.phase == "RESULTS", "Results failed")
	menu.match_view._replay()
	await create_timer(0.2).timeout
	_check(session.phase == "LOADING" and menu.loading.visible, "Replay must load again")
	session.leave()
	await process_frame
	_check(menu.room.visible and menu.actors.size() == 2 and not is_instance_valid(menu.match_view), "Exit must restore the local duo room")
	menu.queue_free()
	await process_frame
	print("MENU ROOM PASSED: startup, movement, interaction, appearance, P2 settings, remapped gameplay, independent meters, loading, replay, exit")
	quit(0)

