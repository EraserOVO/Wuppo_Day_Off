extends SceneTree
var failed := false

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)
		quit(1)
		assert(value, message)

func _run() -> void:
	await process_frame
	await process_frame
	var prediction = load("res://core/motion_prediction.gd").new()
	var buffer = load("res://core/snapshot_buffer.gd").new()
	var initial := {"position": Vector2(400, 520), "velocity_y": 0.0, "move": 0, "jumps": 0, "motion_ack": 0}
	prediction.reconcile(initial)
	prediction.direction = 1
	prediction.jump_pending = true
	for i in 6: prediction.tick()
	_check(prediction.state["position"].x > 420 and prediction.state["position"].y < 500, "Prediction did not respond without a server reply")
	var predicted: Vector2 = prediction.state["position"]
	var authoritative := initial.duplicate()
	var motion = load("res://core/player_motion.gd")
	motion.jump(authoritative)
	authoritative["move"] = 1
	for i in 3: motion.step(authoritative, motion.STEP)
	authoritative["motion_ack"] = 3
	prediction.reconcile(authoritative)
	_check(prediction.pending.size() == 3 and prediction.state["position"].is_equal_approx(predicted), "Acknowledgement replay duplicated movement or jump")
	buffer.push(10.0, Vector2(100, 520))
	buffer.push(10.1, Vector2(120, 520))
	buffer.push(10.05, Vector2(999, 520))
	_check(buffer.position_at(10.15).is_equal_approx(Vector2(110, 520)), "Interpolation failed or accepted an old snapshot")
	_check(buffer.position_at(20).x == 120, "Lost snapshots caused unlimited position extrapolation")
	var session = root.get_node("NetworkSession")
	var controller = root.get_node("MatchController")
	session.active = true
	session.players = {1: {"ready": true}, 2: {"ready": true}}
	session.phase = "PLAYING"
	controller.prepare([1, 2], 42)
	controller.deadline = Time.get_ticks_msec() / 1000.0 + 60.0
	var now := Time.get_ticks_msec() / 1000.0
	controller.accept_input(2, 42, 1, true, now - 0.04)
	controller.states[2]["limit"] = 1.1
	# Unequal arrival delays must preserve the original 350 ms key hold.
	while Time.get_ticks_msec() / 1000.0 < now + 0.35: await process_frame
	controller.accept_input(2, 42, 2, false, now + 0.31)
	_check(controller.states[2]["released"] == 1, "Compensated valid hold did not score")
	controller.states[2]["last_input"] = -1.0
	controller.accept_input(2, 42, 3, true)
	controller.states[2]["start"] = Time.get_ticks_msec() / 1000.0 - 0.1
	controller.accept_input(2, 42, 4, false)
	_check(controller.states[2]["released"] == 1, "Compensation bypassed the minimum hold")
	var delayed: Dictionary = controller.states[2]
	var arrival := Time.get_ticks_msec() / 1000.0
	delayed["state"] = "blowing"
	delayed["limit"] = 1.1
	delayed["start"] = arrival - 1.11
	delayed["input_time"] = arrival - 1.11
	controller._process(0.001)
	_check(delayed["state"] == "blowing", "Natural burst did not wait for an in-flight release")
	controller.accept_input(2, 42, 5, false, arrival - 0.03)
	_check(delayed["released"] == 2, "In-time release arriving after the natural limit lost its score")
	delayed["state"] = "blowing"
	delayed["start"] = arrival - 0.35
	delayed["input_time"] = arrival - 0.35
	controller.deadline = arrival - 0.02
	controller.accept_input(2, 42, 6, false, arrival - 0.03)
	_check(delayed["released"] == 3, "In-flight pre-deadline release was rejected")
	controller.deadline = arrival + 60.0
	controller.accept_motion(2, 42, [PackedInt32Array([1, 1, 1]), PackedInt32Array([2, 1, 0])])
	controller.accept_motion(2, 42, [PackedInt32Array([2, 1, 0])])
	controller._remote_motion(2, controller.states[2], 1.0 / 30.0)
	_check(controller.states[2]["motion_ack"] == 2 and controller.states[2]["jumps"] == 1, "Duplicate movement packet repeated a jump")
	var recovery: Dictionary = controller.recovery_state()
	var expected: float = controller.bubble_pool.next_duration(2)
	controller.restore_recovery(recovery)
	_check(is_equal_approx(controller.bubble_pool.next_duration(2), expected), "Host recovery changed the paired random bubble pool")
	session.input_revision = 2
	session.last_snapshot_id = 100
	var stale := {"match_id": session.match_id, "epoch": session.epoch, "input_revision": 1, "serial": 101, "players": {}}
	session.state_snapshot(var_to_bytes(stale).compress(FileAccess.COMPRESSION_DEFLATE))
	_check(session.last_snapshot_id == 100, "A snapshot from before the pause reset the new input state")
	controller.prepare([1, 2, 3, 4], 42)
	controller._publish()
	_check(var_to_bytes(session.last_snapshot).compress(FileAccess.COMPRESSION_DEFLATE).size() < 1200, "Four-player snapshot exceeds the safe packet budget")
	session.practice = true
	session.leave()
	if not failed: print("LATENCY: prediction/replay, interpolation/loss, compensated hold, minimum hold, late release/deadline, motion deduplication, random-pool recovery, stale revision and four-player packet budget passed")
	quit(1 if failed else 0)
