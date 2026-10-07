extends SceneTree

const RULES = preload("res://modes/mud_ball/ball_rules.gd")
const MOTION = preload("res://core/player_motion.gd")

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		quit(1)
		assert(ok, message)

func _trial(point: Vector2, speed: Vector2, spawn_x: float, team: int, seed_value: int, level := 2) -> Dictionary:
	var ball = RULES.new()
	ball.active = true
	ball.position = point
	ball.velocity = speed
	ball.bot_brain.rng.seed = seed_value
	var player := {"position": Vector2(spawn_x, 880), "velocity_y": 0.0, "jumps": 0, "move": 0, "team": team, "court": "mud_ball"}
	var reversals := 0
	var previous_move := 0
	var planning_us := 0
	var frames := 0
	for frame in 180:
		var before := Time.get_ticks_usec()
		ball.bot(player, level)
		planning_us += Time.get_ticks_usec() - before
		frames += 1
		var move := int(player["move"])
		if move != 0:
			if previous_move != 0 and move != previous_move: reversals += 1
			previous_move = move
		MOTION.step(player, 1.0 / 60.0)
		ball.step(1.0 / 60.0, {-1: player})
		if ball.hit_id > 0 or not ball.active: break
	var clears := false
	var forward_return: bool = ball.hit_id > 0 and ball.velocity.x * (1 if team == 0 else -1) > 0
	if ball.hit_id > 0:
		var flight = RULES.new()
		flight.position = ball.position
		flight.velocity = ball.velocity
		flight.active = true
		for frame in 180:
			flight.step(1.0 / 60.0, {})
			if (flight.position.x > 992.0 if team == 0 else flight.position.x < 928.0):
				clears = true
				break
			if not flight.active: break
	var rally_clear := clears
	if ball.hit_id > 0 and not clears:
		for frame in 180:
			ball.bot(player, level)
			MOTION.step(player, 1.0 / 60.0)
			ball.step(1.0 / 60.0, {-1: player})
			if (ball.position.x > 992.0 if team == 0 else ball.position.x < 928.0):
				rally_clear = true
				break
			if not ball.active: break
	return {"hit": ball.hit_id > 0, "return": forward_return, "clears": clears, "rally_clear": rally_clear, "reversals": reversals, "mean_ms": float(planning_us) / maxf(1, frames) / 1000.0}

func _run() -> void:
	var cases := [
		[Vector2(1100, 760), Vector2(400, 80), 1360.0],
		[Vector2(1120, 650), Vector2(600, 180), 1410.0],
		[Vector2(1050, 460), Vector2(390, -140), 1400.0],
		[Vector2(1500, 530), Vector2(0, 70), 1350.0],
		[Vector2(1040, 810), Vector2(-400, -90), 1150.0],
		[Vector2(1670, 650), Vector2(420, 50), 1500.0],
		[Vector2(1450, 720), Vector2(-250, -430), 1410.0],
		[Vector2(1560, 500), Vector2(0, 0), 1360.0]
	]
	var hits := 0
	var direct_clears := 0
	var completed_rallies := 0
	var max_mean := 0.0
	for index in cases.size():
		for team in [0, 1]:
			var point: Vector2 = cases[index][0]
			var speed: Vector2 = cases[index][1]
			var spawn_x: float = cases[index][2]
			if team == 0:
				point.x = 1920.0 - point.x
				speed.x = -speed.x
				spawn_x = 1920.0 - spawn_x
			var result := _trial(point, speed, spawn_x, team, index + 1)
			print("BOT case=", index, " team=", team, " ", result)
			_check(result["reversals"] <= 4, "Partner twitched repeatedly while receiving")
			hits += int(result["hit"])
			direct_clears += int(result["clears"])
			completed_rallies += int(result["rally_clear"])
			max_mean = maxf(max_mean, result["mean_ms"])
	# Hard mode should still make useful returns, but selected receiving errors must
	# occasionally turn into a missed ball or a weak rally instead of perfect play.
	_check(hits >= 10 and hits < 16, "Hard partner's receiving errors were not visible or it missed too many balls")
	_check(completed_rallies >= 7, "Hard partner failed too many routine returns")
	_check(direct_clears >= 4, "Hard partner rarely completes a clean return")
	var random_hits := 0
	for seed_value in 12:
		var result := _trial(Vector2(1100, 760), Vector2(400, 80), 1360, 1, seed_value)
		random_hits += int(result["hit"])
	_check(random_hits >= 3 and random_hits <= 10, "Hard receiving mistakes were not noticeable or occurred too often: %s/12" % random_hits)
	var original = RULES.new()
	original.active = true
	original.position = Vector2(1300, 600)
	original.velocity = Vector2(300, 200)
	original.spin_angle = 0.4
	original.bot({"position": Vector2(1360, 880), "velocity_y": 0.0, "jumps": 0, "move": 0, "team": 1, "court": "mud_ball"}, 2)
	var recovered = RULES.new()
	recovered.restore(original.snapshot())
	_check(recovered.bot_brain.snapshot() == original.bot_brain.snapshot() and is_equal_approx(recovered.spin_angle, original.spin_angle), "Recovery lost the bot plan or ball rotation")
	var actor = load("res://actors/wum/wum.tscn").instantiate()
	root.add_child(actor)
	await process_frame
	var visual: Node2D = actor.get_node("Visual")
	var feet: Node2D = actor.get_node("Visual/Feet")
	actor.hop_elapsed = 0.0
	actor.trigger_double_jump(1.0, Vector2.ZERO)
	actor._process(0.08)
	_check(feet.get_parent() == visual and feet.global_position.is_equal_approx(visual.global_position), "Feet detached during body hop or spin")
	_check(is_equal_approx(feet.global_rotation, visual.global_rotation), "Feet did not rotate with the body")
	actor.set_facing_direction(-1)
	_check(feet.scale.x == -1, "Feet did not follow the flipped body")
	actor.set_walking(1, true)
	actor._process(0.1)
	_check(feet.stride == 1.0, "Ground walking did not animate feet")
	actor.set_walking(1, false)
	actor._process(0.1)
	_check(feet.stride == 0.0, "Airborne feet continued walking")
	actor.queue_free()
	await process_frame
	print("BOT AND FEET PASSED: ", hits, "/16 receives, ", completed_rallies, " completed rallies, ", direct_clears, " direct clears, ", random_hits, "/12 seeded routine receives, recovery, body attachment; max mean planning ms=", max_mean)
	quit(0)
