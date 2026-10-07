extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

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
	root.get_node("GameSettings").preferences_path = "res://.godot/appearance_test_preferences.cfg"
	menu._change_mode(1)
	_check(menu.SKINS.skins.size() == 8, "Expected eight character colors")
	_check(menu.HATS.hats.size() == 5, "Expected five hats")
	menu._appearance(1, "skin", 6)
	menu._appearance(1, "hat", 3)
	menu._appearance(2, "skin", 7)
	menu._appearance(2, "hat", 2)
	menu._launch()
	await create_timer(0.2).timeout
	_check(session.local_duel, "Appearance local duel did not start")
	var actors: Dictionary = menu.match_view.actors
	_check(actors[1].skin.display_name == "珊瑚红", "Player 1 color did not reach match")
	_check(actors[1].hat.display_name == "小皇冠" and actors[1].hat.texture != null, "Player 1 hat did not reach match")
	_check(actors[2].skin.display_name == "深海蓝", "Player 2 color did not reach match")
	_check(actors[2].hat.display_name == "叶子帽" and actors[2].hat.texture != null, "Player 2 hat did not reach match")
	_check(actors[1].get_node("Hat").visible and actors[2].get_node("Hat").visible, "Hat sprites are not visible")
	var crouching_actor: Node2D = actors[1]
	crouching_actor.set_crouching(true)
	_check(not crouching_actor.get_node("Visual").visible and crouching_actor.get_node("CrouchVisual").visible, "Crouch did not switch to its redrawn body")
	_check(not crouching_actor.get_node("Visual/Feet").visible and crouching_actor.get_node("CrouchVisual/Eyes") != null, "Crouch should hide legs and keep its eyes")
	_check(is_equal_approx(crouching_actor.get_node("CrouchVisual").scale.y, crouching_actor.skin.visual_scale.y), "Crouch still squashes the normal sprite")
	crouching_actor.set_crouching(false)
	session.leave()
	menu.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.1).timeout
	print("APPEARANCE: eight colors, five hats, local duel roster and hat sprites passed")
	quit(0)

