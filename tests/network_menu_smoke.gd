extends SceneTree

var whistles := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		quit(1)
		assert(ok, message)

func _run() -> void:
	var session = root.get_node("NetworkSession")
	var host_role := "host" in OS.get_cmdline_user_args()
	session.lobby_whistled.connect(func(_id: int): whistles += 1)
	if host_role: session.host("Menu host", "127.0.0.1")
	else:
		await create_timer(0.4).timeout
		session.join("127.0.0.1", "Menu client")
	var timeout := Time.get_ticks_msec() + 12000
	var setup_done := false
	var moved := false
	var jumped := false
	var loading_since := 0
	var confirmed := false
	while Time.get_ticks_msec() < timeout:
		await process_frame
		if session.players.size() < 2: continue
		if session.phase == "LOBBY":
			if not setup_done:
				setup_done = true
				if not host_role:
					session.choose_skin(4)
					session.choose_hat(3)
					session.lobby_control("jump")
					session.lobby_control("whistle")
			if host_role:
				for id in session.lobby_states:
					if id == 1: continue
					moved = moved or session.lobby_states[id]["position"].x > 970
					jumped = jumped or session.lobby_states[id]["position"].y < 850
					if moved and jumped and whistles > 0:
						_check(session.players[id]["skin"] == 4 and session.players[id]["hat"] == 3, "Remote appearance did not sync")
						session.set_ready(true)
						if session.can_start(): session.start_match()
			else:
				session.lobby_control("move", 1)
				if not session.players[session.local_player_id()].get("ready", false): session.set_ready(true)
		elif session.phase == "LOADING":
			if loading_since == 0: loading_since = Time.get_ticks_msec()
			if not confirmed and Time.get_ticks_msec() - loading_since > (100 if host_role else 1800):
				confirmed = true
				session.confirm_loaded()
		elif session.phase == "COUNTDOWN":
			_check(loading_since != 0 and Time.get_ticks_msec() - loading_since >= 1600, "Match started before the slow client loaded")
			_check(whistles > 0, "Lobby whistle did not reach all peers")
			_check(session.loaded.size() == 2, "All-player loading status did not synchronize")
			print("NETWORK MENU %s PASSED: lobby movement, jump, harmless whistle, appearance, readiness and delayed loading barrier" % ("HOST" if host_role else "CLIENT"))
			await create_timer(0.2).timeout
			quit(0)
			return
	_check(false, "Network lobby test timed out: phase=%s moved=%s jumped=%s whistles=%s" % [session.phase, moved, jumped, whistles])

