extends SceneTree
const MOTION = preload("res://core/player_motion.gd")
const LOBBY = preload("res://core/lobby_motion.gd")
const PREDICTION = preload("res://core/motion_prediction.gd")
const BALL = preload("res://modes/mud_ball/ball_rules.gd")

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		quit(1)
		assert(ok, message)

func _state() -> Dictionary:
	return {"position": Vector2(1390, 818), "move": 0, "velocity_x": 0.0, "velocity_y": 0.0, "jumps": 0, "grounded": true}

func _key(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	root.push_input(event, true)

func _run() -> void:
	var normal := _state()
	_check(MOTION.jump(normal) and normal["velocity_y"] == -820.0, "Ordinary first jump speed incorrect")
	_check(MOTION.jump(normal) and normal["velocity_y"] == -820.0, "Ordinary second jump speed incorrect")
	MOTION.set_crouching(normal, true)
	_check(not normal["crouching"], "Crouching must be rejected while airborne")
	var apex := _state()
	apex["grounded"] = false
	apex["jumps"] = 1
	MOTION.set_crouching(apex, true)
	_check(not apex["crouching"], "Zero vertical velocity at apex must not allow crouching")
	var boosted := _state()
	MOTION.set_crouching(boosted, true)
	_check(MOTION.jump(boosted) and boosted["velocity_y"] == -940.0 and boosted["jump_boosted"] and not boosted["crouching"], "Immediate crouch jump boost or stand-up missing")
	_check(MOTION.jump(boosted) and boosted["velocity_y"] == -820.0 and not boosted["jump_boosted"], "Second jump must not inherit crouch boost")
	var grace := _state()
	MOTION.set_crouching(grace, true)
	MOTION.set_crouching(grace, false)
	LOBBY.step(grace, 0.1)
	MOTION.jump(grace)
	_check(grace["jump_boosted"], "Releasing crouch shortly before jumping must preserve boost")
	var expired := _state()
	MOTION.set_crouching(expired, true)
	MOTION.set_crouching(expired, false)
	LOBBY.step(expired, 0.2)
	MOTION.jump(expired)
	_check(not expired["jump_boosted"], "Expired crouch preparation must not boost jump")
	var falling := _state()
	falling.merge({"position": Vector2(700, 550), "velocity_y": 25.0, "velocity_x": 200.0, "move": 1, "crouching": true}, true)
	LOBBY.step(falling, MOTION.STEP)
	_check(not falling["crouching"] and falling["velocity_x"] > 200, "Air crouch must not stop horizontal movement")
	var predictor = PREDICTION.new()
	predictor.state = {"position": MOTION.spawn_position(500), "move": 0, "velocity_x": 0.0, "velocity_y": 0.0, "jumps": 0, "grounded": true}
	var authoritative: Dictionary = predictor.state.duplicate(true)
	predictor.crouching = true
	predictor.tick()
	MOTION.set_crouching(authoritative, true)
	MOTION.step(authoritative, MOTION.STEP)
	predictor.jump_pending = true
	predictor.tick()
	MOTION.set_crouching(authoritative, true)
	MOTION.jump(authoritative)
	MOTION.step(authoritative, MOTION.STEP)
	_check(predictor.state["position"].is_equal_approx(authoritative["position"]) and predictor.state["jump_boosted"], "Prediction must use the same crouch-before-jump ordering as authority")
	authoritative["motion_ack"] = 1
	var first_ack := {"position": MOTION.spawn_position(500), "move": 0, "velocity_x": 0.0, "velocity_y": 0.0, "jumps": 0, "grounded": true, "crouching": true, "crouch_jump_remaining": 0.18, "motion_ack": 1}
	predictor.reconcile(first_ack)
	_check(predictor.state["position"].is_equal_approx(authoritative["position"]) and predictor.state["jump_boosted"] and not predictor.state["crouching"], "Replayed prediction must retain first-jump boost without midair crouch")
	var ball = BALL.new()
	var regular_hit: Vector2 = ball.player_hit_response(Vector2(110, 300), Vector2(0, -820), Vector2.UP)
	var powered_hit: Vector2 = ball.player_hit_response(Vector2(110, 300), Vector2(0, -820), Vector2.UP, true)
	_check(powered_hit.y < regular_hit.y - 100 and powered_hit.length() <= 760.01, "Crouch jump must add upward ball lift without unlimited speed")
	var contact_speeds: Array = []
	for power in [false, true]:
		var rally = BALL.new()
		rally.active = true
		rally.position = Vector2(400, 790)
		rally.velocity = Vector2(110, 300)
		var player := {"position": Vector2(400, 880), "velocity_x": 0.0, "velocity_y": -820.0, "jumps": 1, "jump_boosted": power, "team": 0, "score": 0}
		rally.step(0.01, {1: player})
		_check(rally.hit_id == 1, "Test ball must actually collide with rising player")
		contact_speeds.append(rally.velocity.y)
	_check(float(contact_speeds[1]) < float(contact_speeds[0]) - 100, "Real ball collision must consume crouch jump flag")
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu.states[1] = _state()
	menu.actors[1].position = menu.states[1]["position"]
	_key(KEY_S, true)
	menu._physics_process(MOTION.STEP)
	var actor = menu.actors[1]
	actor._process(0)
	var visual: Node2D = actor.get_node("CrouchVisual")
	var bottom: Vector2 = visual.global_transform * Vector2(0, visual.BOTTOM)
	_check(actor.crouching and absf(bottom.y - actor.global_position.y) < 0.1, "Crouching body must touch the bench instead of floating")
	_key(KEY_W, true)
	_key(KEY_W, false)
	_check(menu.states[1]["jump_boosted"] and not actor.crouching, "Lobby keyboard crouch jump must boost and immediately stand")
	_key(KEY_S, false)
	_key(KEY_S, true)
	_check(not actor.crouching and not menu.states[1]["crouching"], "Lobby airborne crouch input must be ignored")
	_key(KEY_S, false)
	menu._change_mode(1)
	menu._launch()
	await create_timer(5.3).timeout
	var session = root.get_node("NetworkSession")
	var controller = root.get_node("MatchController")
	_check(session.phase == "PLAYING", "Bubble match did not launch")
	controller.set_process(false)
	controller.set_physics_process(false)
	var first: Dictionary = controller.states[1]
	var second: Dictionary = controller.states[2]
	first.merge({"position": MOTION.spawn_position(600), "velocity_y": 0.0, "jumps": 0, "grounded": true}, true)
	second.merge({"position": MOTION.spawn_position(760), "velocity_y": 0.0, "jumps": 0, "grounded": true}, true)
	controller._publish()
	_key(KEY_S, true)
	_key(KEY_W, true)
	_key(KEY_W, false)
	_check(first["jump_boosted"] and not menu.match_view.actors[1].crouching, "Match keyboard crouch jump must boost without floating body")
	_key(KEY_S, false)
	second.merge({"position": MOTION.spawn_position(760), "velocity_y": 0.0, "jumps": 0, "grounded": true}, true)
	controller.accept_control(2, controller.round_id, 10, "crouch", 1)
	controller.accept_input(2, controller.round_id, 10, true)
	second["limit"] = 4.0
	var now: float = controller._now()
	second["start"] = now - 1.0
	_check(is_equal_approx(controller._natural_charge_at(second, now), 0.8), "Crouched bubble must grow 20% slower")
	first["whistle_ready"] = 0.0
	first["state"] = "idle"
	controller.accept_control(1, controller.round_id, 20, "whistle", 0)
	var distance: float = first["position"].distance_to(second["position"])
	var expected: float = lerpf(controller.CONFIG.whistle_charge_near, controller.CONFIG.whistle_charge_far, distance / controller.CONFIG.whistle_radius) * 0.65
	_check(is_equal_approx(second["charge_bonus"], expected), "Crouched target must receive 35% less whistle charge")
	second["charge_segments"] = [{"at": now - 0.5, "rate": 1.0}]
	_check(is_equal_approx(controller._natural_charge_at(second, now), 0.9), "Mixed posture charge must integrate both intervals")
	_check(is_equal_approx(controller._natural_charge_at(second, now - 0.6), 0.32), "Backdated release must use past posture rather than current posture")
	second["charge_segments"] = []
	second["start"] = now - 4.1
	second["charge_bonus"] = 0.0
	controller.deadline = now + 60
	controller._process(0)
	_check(second["state"] == "blowing", "Crouched bubble must not burst on ordinary hold duration")
	second["start"] = controller._now() - 5.1
	controller._process(0)
	_check(second["state"] == "burst", "Crouched bubble must still burst at effective charge limit")
	controller._publish()
	_check(session.last_snapshot["players"][2].has("charge_rate") and session.last_snapshot["players"][1].has("jump_boosted"), "Snapshots must carry effective charge and crouch-jump state")
	session.leave()
	menu.queue_free()
	await process_frame
	await process_frame
	print("CROUCH PASSED: grounded visual, airborne rejection, both jump speeds, boost expiry, prediction/replay, ball lift, posture-integrated bubbles, whistle resistance and real input")
	quit(0)
