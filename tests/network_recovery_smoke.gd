extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	var role := "host" if "host" in arguments else "client"
	var migration := "migration" in arguments
	var crash := "crash" in arguments
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	var session = root.get_node("NetworkSession")
	var controller = root.get_node("MatchController")
	if role == "host":
		session.host("Recovery host")
		session.set_ready(true)
	else:
		await create_timer(0.5).timeout
		session.selected_hat = 3
		session.selected_skin = 6
		session.join("127.0.0.1", "Recovery client")
	var press_at := 0.0
	var released := false
	var score_before := 0
	var original_id := 0
	var disrupted := false
	var observed_pause := false
	var ready_to_disrupt := 0.0
	var end_at := Time.get_ticks_msec() / 1000.0 + 35.0
	while Time.get_ticks_msec() / 1000.0 < end_at:
		await process_frame
		var now := Time.get_ticks_msec() / 1000.0
		observed_pause = observed_pause or session.paused
		if session.phase == "LOBBY":
			if role == "host" and session.players.size() == (3 if migration else 2) and session.can_start(): session.start_match()
			elif role != "host" and session.connection_state == "CONNECTED": session.set_ready(true)
		if session.phase != "PLAYING": continue
		if role != "host" and not session.paused:
			var own: Dictionary = menu.match_view.local_state
			if press_at == 0.0:
				original_id = session.local_player_id()
				session.submit_input(true)
				press_at = now
			elif not released and now - press_at > 0.4:
				session.submit_input(false)
				released = true
			if released and int(own.get("score", 0)) > 0: score_before = maxi(score_before, int(own["score"]))
			if score_before > 0 and not migration and not disrupted:
				disrupted = true
				session.multiplayer.multiplayer_peer.close()
				session._server_lost()
				continue
			var recovered: bool = session.epoch > 0 if migration else disrupted and observed_pause and session.connection_state == "CONNECTED"
			if recovered and session.local_player_id() == original_id and int(own.get("score", 0)) >= score_before and score_before > 0:
				if session.players[original_id]["hat"] != 3 or session.players[original_id]["skin"] != 6:
					push_error("Recovery lost appearance")
					quit(1)
					return
				print("RECOVERY CLIENT: %s, stable identity, score, appearance and active match passed" % ("host migration" if migration else "reconnect"))
				await create_timer(1.5).timeout
				await session.leave()
				quit(0)
				return
		if role == "host":
			var clients_scored := true
			for id in controller.states:
				if id != 1 and int(controller.states[id]["score"]) <= 0: clients_scored = false
			if clients_scored and ready_to_disrupt == 0.0: ready_to_disrupt = now
			if migration and ready_to_disrupt > 0.0 and now - ready_to_disrupt > 1.0:
				print("RECOVERY HOST: scored state replicated; %s" % ("crash" if crash else "handover"))
				if crash:
					# The runner kills this process tree, without a graceful network shutdown.
					await create_timer(60.0).timeout
				else: await session.leave()
				quit(0)
				return
			if not migration and observed_pause and not session.paused and not session.disconnected.is_empty(): continue
			if not migration and observed_pause and not session.paused and ready_to_disrupt > 0.0:
				print("RECOVERY HOST: paused timer and preserved match resumed")
				await create_timer(2.0).timeout
				await session.leave()
				quit(0)
				return
	push_error("Recovery test timed out: %s phase=%s connected=%s paused=%s epoch=%s" % [role, session.phase, session.connection_state, session.paused, session.epoch])
	quit(1)

