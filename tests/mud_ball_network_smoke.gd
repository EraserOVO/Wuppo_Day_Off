extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var host_role := "host" in OS.get_cmdline_user_args()
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	var session = root.get_node("NetworkSession")
	var controller = root.get_node("MatchController")
	if host_role:
		session.set_game_mode("mud_ball")
		session.set_mud_ball_target_score(5)
		session.host("Ball host", "127.0.0.1")
		session.set_ready(true)
	else:
		await create_timer(0.5).timeout
		session.join("127.0.0.1", "Ball client")
	var until := Time.get_ticks_msec() / 1000.0 + 22
	var moved := false
	var synchronized := false
	var completed := false
	var start := 0.0
	while Time.get_ticks_msec() / 1000.0 < until:
		await process_frame
		if session.phase == "LOBBY":
			if host_role and session.can_start(): session.start_match()
			elif not host_role and session.connection_state == "CONNECTED": session.set_ready(true)
		if session.phase == "PLAYING":
			if not host_role and session.mud_ball_target_score != 5: break
			if host_role and controller.ball != null and controller.ball.target_score != 5: break
			if start == 0: start = Time.get_ticks_msec() / 1000.0
			if not host_role:
				if session.game_mode != "mud_ball" or menu.match_view.name != "MudBall": break
				if not moved:
					session.submit_control("move", -1)
					session.submit_control("jump")
					moved = true
				if session.last_snapshot.has("ball"):
					var own: Dictionary = session.last_snapshot["players"].get(session.local_player_id(), {})
					synchronized = synchronized or (int(own.get("motion_ack", 0)) > 0 and not menu.match_view.ball_buffer.samples.is_empty() and session.last_snapshot["ball"]["velocity"] is Vector2)
			else:
				var ids: Array = controller.states.keys()
				ids.erase(1)
				if ids.is_empty(): continue
				var remote: Dictionary = controller.states[ids[0]]
				if int(remote["motion_ack"]) > 5 and Time.get_ticks_msec() / 1000.0 - start > 1.2:
					moved = remote["position"].x < 1460
					controller.ball.scores = [4, 0]
					controller.ball.active = true
					controller.ball.position = Vector2(1200, 849)
					controller.ball.velocity = Vector2(0, 100)
		if session.phase == "RESULTS":
			if host_role: completed = moved and controller.ball.scores == [5, 0]
			else: completed = synchronized and session.last_snapshot.get("ball", {}).get("scores", []) == [5, 0] and menu.match_view.results.visible
			if completed: break
	if completed: print("BALL NETWORK ", "HOST" if host_role else "CLIENT", ": mode, remote movement, ball snapshots and final scores passed")
	else: push_error("Ball network failed host=%s phase=%s sync=%s" % [host_role, session.phase, synchronized])
	if host_role: await create_timer(0.8).timeout
	await session.leave()
	menu.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.1).timeout
	quit(0 if completed else 1)
