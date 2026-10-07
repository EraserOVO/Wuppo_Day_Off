extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var session = root.get_node("NetworkSession")
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	menu.set_physics_process(false)
	var host_role := "host" in OS.get_cmdline_user_args()
	if host_role: session.host("Garden host", "127.0.0.1")
	else:
		await create_timer(0.5).timeout
		session.join("127.0.0.1", "Garden visitor")
	var seen_backyard := false
	var seen_backyard_view := false
	var entered_at := 0
	var timeout := Time.get_ticks_msec() + 18000
	var next_send := 0
	while Time.get_ticks_msec() < timeout:
		await process_frame
		if session.players.size() < 2: continue
		var id: int = session.local_player_id() if not host_role else 0
		if host_role:
			for candidate in session.players:
				if candidate != 1: id = candidate
		if not session.lobby_states.has(id): continue
		var area := str(session.lobby_states[id].get("lobby_area", "room"))
		if area == "backyard":
			if not seen_backyard: entered_at = Time.get_ticks_msec()
			seen_backyard = true
			# The host's scene consumes 20 Hz snapshots, rather than raw physics state.
			if str(menu.states.get(id, {}).get("lobby_area", "room")) == "backyard":
				menu._sync_lobby_views()
				seen_backyard_view = menu.actors.has(id) and menu.actors[id].get_parent() == menu.backyard
				if not host_role: seen_backyard_view = seen_backyard_view and menu.room_layers["backyard"].visible
		if not host_role:
			if Time.get_ticks_msec() >= next_send:
				next_send = Time.get_ticks_msec() + 80
				session.lobby_control("move", (-1 if Time.get_ticks_msec() - entered_at > 350 else 0) if seen_backyard else 1)
		if seen_backyard and area == "room":
			if not seen_backyard_view:
				push_error("Network backyard view never synchronized")
				quit(1)
				return
			if not host_role: session.lobby_control("move", 0)
			print("GARDEN NETWORK %s PASSED: authoritative right-edge travel and reverse travel synchronized" % ("HOST" if host_role else "CLIENT"))
			await create_timer(0.6 if host_role else 1.0).timeout
			quit(0)
			return
	push_error("Backyard network travel timed out")
	quit(1)
