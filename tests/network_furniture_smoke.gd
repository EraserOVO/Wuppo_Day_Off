extends SceneTree
const MOTION = preload("res://core/lobby_motion.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var session = root.get_node("NetworkSession")
	var host_role := "host" in OS.get_cmdline_user_args()
	if host_role: session.host("Furniture host", "127.0.0.1")
	else:
		await create_timer(0.4).timeout
		session.join("127.0.0.1", "Furniture client")
	var started := false
	var crossed := false
	var stopped := false
	var second_jump := false
	var landed := false
	var finish_at := 0
	var timeout := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < timeout:
		await process_frame
		if session.players.size() < 2: continue
		if not host_role and not started:
			started = true
			session.lobby_control("jump")
			session.lobby_control("move", -1)
		for id in session.lobby_states:
			if id == 1: continue
			var state: Dictionary = session.lobby_states[id]
			var pos: Vector2 = state["position"]
			crossed = crossed or pos.y < 660
			if not host_role and not second_jump and int(state["jumps"]) == 1 and pos.y < 780:
				second_jump = true
				session.lobby_control("jump")
			if not host_role and not stopped:
				if pos.x <= 990:
					stopped = true
					session.lobby_control("move", 0)
				else: session.lobby_control("move", -1)
			if crossed and is_equal_approx(pos.y, 660) and MOTION.is_supported(pos) and int(state["jumps"]) == 0:
				landed = true
				if finish_at == 0: finish_at = Time.get_ticks_msec() + 500
		if landed and Time.get_ticks_msec() >= finish_at:
			print("NETWORK FURNITURE %s PASSED: remote double jump and window-ledge landing agree with shared surfaces" % ("HOST" if host_role else "CLIENT"))
			session.leave()
			await process_frame
			quit(0)
			return
	push_error("Network furniture test timed out: crossed=%s landed=%s" % [crossed, landed])
	quit(1)
