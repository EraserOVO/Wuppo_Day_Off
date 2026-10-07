extends SceneTree

const RULES = preload("res://modes/mud_ball/ball_rules.gd")
const MOTION = preload("res://core/player_motion.gd")
const COURT = preload("res://modes/mud_ball/court.gd")

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		quit(1)
		assert(value, message)

func _tap_key(code: int) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = code
	down.pressed = true
	root.push_input(down, true)
	var up := InputEventKey.new()
	up.physical_keycode = code
	up.pressed = false
	root.push_input(up, true)

func _run() -> void:
	var session = root.get_node("NetworkSession")
	var controller = root.get_node("MatchController")
	for count in [2, 3, 4]:
		var states := {}
		for id in count: states[id + 1] = {}
		var rules = RULES.new()
		rules.prepare(states)
		var left := 0
		for state in states.values(): left += int(state["team"] == 0)
		_check(left == (1 if count < 4 else 2), "Wrong team allocation")
	var configurable = RULES.new()
	configurable.target_score = 5
	configurable.active = true
	for _point in 5:
		configurable.active = true
		configurable.point(0, {})
	_check(configurable.winner == 0 and configurable.target_score == 5, "Selected target score did not end the game")
	var target_recovery = RULES.new()
	target_recovery.restore(configurable.snapshot())
	_check(target_recovery.target_score == 5, "Recovery lost the selected target score")
	session.set_game_mode("mud_ball")
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu._open("门", 1)
	var target_option: OptionButton
	for option in menu.section_grid.find_children("*", "OptionButton", true, false):
		if option.item_count == 4 and option.get_item_text(0) == "5 分": target_option = option
	_check(target_option != null, "Mud-ball target score was not offered in the game settings")
	if target_option != null:
		target_option.item_selected.emit(0)
		_check(session.mud_ball_target_score == 5, "Selected target score was not applied")
		session.set_mud_ball_target_score(10)
		menu._close()
	menu._change_mode(1)
	menu._launch()
	await create_timer(5.3).timeout
	_check(session.phase == "PLAYING" and controller.ball != null, "Ball scene failed to start")
	_tap_key(KEY_ESCAPE)
	_check(session.paused, "Escape did not pause local-duel mud-ball gameplay")
	_tap_key(KEY_ESCAPE)
	_check(not session.paused, "Escape did not resume local-duel mud-ball gameplay")
	_check(menu.match_view.name == "MudBall", "Wrong scene")
	controller.set_physics_process(false)
	var player_state: Dictionary = controller.states[1]
	var player_actor: Node2D = menu.match_view.actors[1]
	_tap_key(KEY_W)
	_tap_key(KEY_W)
	_check(int(player_state["jumps"]) == 2 and player_actor.double_jump_spin > 0.0, "Mud-ball double-jump spin event was not played")
	_tap_key(KEY_L)
	_check(player_actor.whistle_time > 0.0, "Mud-ball whistle feedback was not played")
	var ball = controller.ball
	var states: Dictionary = controller.states
	states[1]["position"] = Vector2(300, 880)
	states[2]["position"] = Vector2(1600, 880)
	ball.active = true
	ball.position = Vector2(910, 835)
	ball.velocity = Vector2(700, 0)
	ball.step(1.0 / 60, states)
	_check(ball.velocity.x < 0, "Ball did not bounce off wall")
	ball.position = Vector2(224, 500)
	ball.velocity = Vector2(-600, 0)
	ball.step(1.0 / 60, states)
	_check(ball.velocity.x > 0, "Ball did not bounce off court boundary")
	states[1]["position"] = Vector2(400, 880)
	states[1]["move"] = 1
	ball.position = Vector2(455, 835)
	ball.velocity = Vector2(-200, 0)
	ball.step(1.0 / 60, states)
	_check(ball.velocity.x > 0 and ball.hit_id > 0 and not is_zero_approx(ball.spin_speed), "Moving player did not hit and spin the ball")
	var unforced_hit: Vector2 = ball.player_hit_response(Vector2(300, 0), Vector2.ZERO, Vector2.UP)
	_check(unforced_hit.x > 0 and unforced_hit.y <= -229.0, "Player hit did not gain lift or preserved collision direction")
	states[1]["position"] = Vector2(400, 880)
	states[1]["move"] = 0
	states[1]["velocity_y"] = 0.0
	ball.position = Vector2(455, 835)
	ball.velocity = Vector2(-1, 0)
	ball.step(1.0 / 60, states)
	_check(ball.hit_id > 1 and ball.velocity.length() >= 359.0, "Slow body contact did not give the ball enough pace")
	states[1]["position"] = Vector2(400, 750)
	states[1]["move"] = 0
	states[1]["velocity_y"] = -700.0
	ball.position = Vector2(400, 665)
	ball.velocity = Vector2(0, 100)
	ball.step(1.0 / 60, states)
	_check(ball.velocity.y < 0, "Jumping player did not hit ball up")
	ball.position = Vector2(650, 849)
	ball.velocity = Vector2(0, 100)
	ball.step(1.0 / 60, states)
	_check(ball.scores == [0, 1] and ball.serving_team == 1 and not ball.active, "Left landing scored incorrectly")
	ball.step(1.3, states)
	_check(ball.active and ball.position.x > 960 and ball.velocity.x < 0, "Scorer did not serve toward opposite court")
	ball.position = Vector2(1300, 849)
	ball.velocity = Vector2(0, 100)
	ball.step(1.0 / 60, states)
	_check(ball.scores == [1, 1] and ball.serving_team == 0, "Right landing scored incorrectly")
	for index in 9:
		ball.serve()
		ball.position = Vector2(1300, 849)
		ball.velocity = Vector2(0, 100)
		ball.step(1.0 / 60, states)
	controller.set_physics_process(true)
	await physics_frame
	await process_frame
	_check(session.phase == "RESULTS" and ball.winner == 0, "Ten-point victory failed")
	var restored = RULES.new()
	restored.restore(controller.recovery_state()["ball"])
	_check(restored.scores == ball.scores and restored.winner == 0, "Ball recovery lost state")
	var state := {"position": Vector2(880, 880), "move": 1, "velocity_y": 0.0, "jumps": 0, "court": "mud_ball"}
	MOTION.step(state, 0.2)
	_check(state["position"].x <= 906, "Player walked through center wall")
	MOTION.jump(state)
	for index in 40: MOTION.step(state, 1.0 / 60)
	_check(state["position"].x > 980, "Player could not jump over wall")
	var wall_landing := {"position": Vector2(906, 880), "move": 1, "velocity_y": 0.0, "jumps": 0, "court": "mud_ball"}
	MOTION.jump(wall_landing)
	for index in 4: MOTION.step(wall_landing, 1.0 / 60)
	_check(wall_landing["position"].x > COURT.WALL.position.x - COURT.PLAYER_HALF_WIDTH and wall_landing["position"].y > COURT.WALL.position.y and wall_landing["position"].y <= COURT.WALL.position.y + COURT.WALL_ENTRY_HEIGHT, "Player could not enter wall through its upper third")
	for index in 5: MOTION.step(wall_landing, 1.0 / 60)
	wall_landing["move"] = 0
	for index in 3: MOTION.step(wall_landing, 1.0 / 60)
	for index in 55: MOTION.step(wall_landing, 1.0 / 60)
	_check(is_equal_approx(float(wall_landing["position"].y), COURT.WALL.position.y), "Player could not land on wall through its upper third")
	for ratio in [Vector2(1920, 1080), Vector2(2560, 1080), Vector2(1280, 1024)]:
		root.size = Vector2i(ratio)
		await process_frame
		menu.match_view._layout()
		_check(is_equal_approx(menu.match_view.camera.zoom.x, menu.match_view.camera.zoom.y), "Court stretched")
	menu.match_view._replay()
	await process_frame
	await process_frame
	_check(session.phase == "LOADING" and session.game_mode == "mud_ball", "Ball replay failed")
	session.leave()
	menu._change_mode(0)
	menu._launch()
	await create_timer(5.3).timeout
	_check(session.practice and controller.states.has(-1) and controller.states[-1]["team"] == 1, "Practice partner missing")
	_tap_key(KEY_ESCAPE)
	_check(session.paused, "Escape did not pause single-player mud-ball practice")
	_tap_key(KEY_ESCAPE)
	_check(not session.paused, "Escape did not resume single-player mud-ball practice")
	controller.ball.active = true
	controller.ball.position = Vector2(1650, 660)
	controller.ball.velocity = Vector2(0, 0)
	controller.ball.bot_brain.rethink = 0.0
	controller.ball.bot_brain.rng.seed = 7
	await physics_frame
	await physics_frame
	_check(controller.states[-1]["move"] == 1, "Practice partner did not move toward the predicted interception")
	session.leave()
	menu.queue_free()
	await process_frame
	root.get_node("AudioManager").stop_all()
	await process_frame
	print("MUD BALL: teams, scene, wall, body hits, gravity, scoring, serve, selected-target victory, recovery, replay and layout passed")
	quit()
