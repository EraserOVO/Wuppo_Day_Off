extends SceneTree
const MOTION = preload("res://core/player_motion.gd")

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
		session.host("Crouch host", "127.0.0.1")
		session.set_ready(true)
	else:
		await create_timer(0.5).timeout
		session.join("127.0.0.1", "Crouch client")
	var prepared := false
	var jumped_at := 0
	var doubled := false
	var saw_boost := false
	var saw_double := false
	var blowing := false
	var sent_whistle := false
	var resisted := false
	var released := false
	var finished := false
	var timeout := Time.get_ticks_msec() + 22000
	while Time.get_ticks_msec() < timeout:
		await process_frame
		if session.phase == "LOBBY":
			if host_role and session.can_start(): session.start_match()
			elif not host_role and session.connection_state == "CONNECTED": session.set_ready(true)
		if session.phase == "PLAYING":
			if host_role:
				var ids: Array = controller.states.keys()
				ids.erase(1)
				if ids.is_empty(): continue
				var remote: Dictionary = controller.states[ids[0]]
				var local: Dictionary = controller.states[1]
				saw_boost = saw_boost or bool(remote.get("jump_boosted", false))
				saw_double = saw_double or (int(remote["jumps"]) == 2 and not bool(remote.get("jump_boosted", false)))
				if not MOTION.is_grounded(remote) and bool(remote.get("crouching", false)):
					push_error("Host accepted airborne crouch")
					quit(1)
					return
				if saw_double and remote["state"] == "blowing" and remote.get("crouching", false) and not sent_whistle:
					local["position"] = MOTION.spawn_position(float(remote["position"].x) - 160)
					var distance: float = local["position"].distance_to(remote["position"])
					var expected: float = lerpf(controller.CONFIG.whistle_charge_near, controller.CONFIG.whistle_charge_far, distance / controller.CONFIG.whistle_radius) * 0.65
					session.submit_control("whistle")
					sent_whistle = true
					resisted = is_equal_approx(float(remote["charge_bonus"]), expected)
				if int(remote["released"]) > 0 and saw_boost and saw_double and resisted and not finished:
					controller.deadline = controller._now() - 0.1
					finished = true
			else:
				var own: Dictionary = menu.match_view.local_state
				if own.is_empty(): continue
				if not prepared:
					session.submit_control("crouch", 1)
					prepared = true
				if jumped_at == 0 and own.get("crouching", false):
					session.submit_control("jump")
					jumped_at = Time.get_ticks_msec()
				if jumped_at > 0:
					saw_boost = saw_boost or bool(own.get("jump_boosted", false))
					if Time.get_ticks_msec() - jumped_at > 120 and not doubled:
						session.submit_control("crouch", 1) # Must be rejected while airborne.
						session.submit_control("jump")
						doubled = true
					saw_double = saw_double or (int(own["jumps"]) == 2 and not bool(own.get("jump_boosted", false)))
					if saw_double and MOTION.is_grounded(own) and not blowing:
						session.submit_control("crouch", 1)
						if own.get("crouching", false):
							session.submit_input(true)
							blowing = true
				resisted = resisted or (blowing and float(own.get("charge_bonus", 0)) > 0 and is_equal_approx(float(own.get("charge_rate", 1)), 0.8))
				if resisted and float(own["held"]) > 0.4 and not released:
					if absf(float(own["natural_charge"]) - float(own["held"]) * 0.8) > 0.01:
						push_error("Remote natural charge does not use crouched rate")
						quit(1)
						return
					session.submit_input(false)
					released = true
		if session.phase == "RESULTS" and saw_boost and saw_double and resisted and (finished if host_role else released):
			print("NETWORK CROUCH %s PASSED: boosted first jump, ordinary double jump, air rejection, slower bubble and whistle resistance synchronized" % ("HOST" if host_role else "CLIENT"))
			await create_timer(0.5).timeout
			quit(0)
			return
	push_error("Network crouch test timed out: boost=%s double=%s resisted=%s phase=%s" % [saw_boost, saw_double, resisted, session.phase])
	quit(1)
