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
		session.host("Network host", "127.0.0.1")
		session.set_ready(true)
	else:
		await create_timer(0.5).timeout
		var address := "127.0.0.1"
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("address="): address = argument.trim_prefix("address=")
		session.join(address, "Network client")
	var started := false
	var playing_since := 0.0
	var jumped_twice := false
	var observed_jump := false
	var observed_double := false
	var observed_move := false
	var started_bubble := false
	var whistle_received := false
	var released := false
	var whistled := false
	var finished := false
	var results_seen := false
	var timeout := Time.get_ticks_msec() / 1000.0 + 20.0
	while Time.get_ticks_msec() / 1000.0 < timeout:
		await process_frame
		var now := Time.get_ticks_msec() / 1000.0
		if session.phase == "LOBBY":
			if host_role and session.can_start(): session.start_match()
			elif not host_role and session.connection_state == "CONNECTED": session.set_ready(true)
		if session.phase == "PLAYING":
			if not started:
				started = true
				playing_since = now
				if not host_role:
					session.submit_control("move", -1)
					session.submit_control("jump")
			if host_role:
				var ids: Array = controller.states.keys()
				ids.erase(1)
				if ids.is_empty(): continue
				var remote: Dictionary = controller.states[ids[0]]
				var local: Dictionary = controller.states[1]
				var distance: float = remote["position"].x - local["position"].x
				session.submit_control("move", int(signf(distance)) if absf(distance) > 190.0 else 0)
				if remote["state"] == "blowing" and not whistled:
					session.submit_control("whistle")
					whistled = remote["charge_bonus"] > 0.0
				if remote["score"] > 0 and whistled and not finished:
					controller.deadline = now - 0.1
					finished = true
			else:
				var own: Dictionary = menu.match_view.local_state
				if own.is_empty(): continue
				observed_jump = observed_jump or own["position"].y < 860.0
				observed_double = observed_double or own["jumps"] == 2
				observed_move = observed_move or own["position"].x < 1520.0
				if now - playing_since > 0.12 and not jumped_twice:
					session.submit_control("jump")
					jumped_twice = true
				if now - playing_since > 0.65: session.submit_control("move", 0)
				var host_state: Dictionary = menu.match_view.scores.get(1, {})
				if not host_state.is_empty() and own["position"].distance_to(host_state["position"]) < 240.0 and not started_bubble:
					session.submit_input(true)
					started_bubble = true
				whistle_received = whistle_received or float(own.get("charge_bonus", 0.0)) >= 0.06
				if whistle_received and float(own["held"]) >= 0.4 and not released:
					session.submit_input(false)
					released = true
		if session.phase == "RESULTS":
			results_seen = true
			if host_role and finished:
				print("NETWORK HOST: authoritative remote controls, whistle and scoring passed")
				break
			if not host_role and observed_jump and observed_double and observed_move and whistle_received and released:
				print("NETWORK CLIENT: movement, double jump, whistle bonus and final results synchronized")
				finished = true
				break
	finished = finished and results_seen
	if not finished:
		push_error("Network mechanics test timed out or failed: host=%s phase=%s" % [host_role, session.phase])
	await session.leave()
	menu.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.1).timeout
	quit(0 if finished else 1)

