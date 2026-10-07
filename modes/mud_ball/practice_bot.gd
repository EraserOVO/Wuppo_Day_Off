extends RefCounted

const MOTION = preload("res://core/player_motion.gd")
const COURT = preload("res://modes/mud_ball/court.gd")
const DT := 1.0 / 60.0
var rng := RandomNumberGenerator.new()
var rethink := 0.0
var style_time := 0.0
var aim_error := 0.0
var waypoint := 1360.0
var first_jump := -1.0
var second_jump := -1.0
var mistake_offset := 0.0
var mistake_active := false
var mistake_plan_ready := false
var mistake_skip_jump := false
var reaction_wait := 0.0
var seen_hit := -1
var seen_rally := -1
var events: Array[Dictionary] = []

func _init() -> void:
	rng.randomize()

func step(ball, state: Dictionary, difficulty: int, delta: float) -> void:
	var level := clampi(difficulty, 0, 2)
	rethink -= delta
	style_time -= delta
	reaction_wait = maxf(0.0, reaction_wait - delta)
	if first_jump >= 0.0: first_jump = maxf(0.0, first_jump - delta)
	if second_jump >= 0.0: second_jump = maxf(0.0, second_jump - delta)
	if style_time <= 0.0:
		# Variation affects the return angle, never whether an incoming ball is noticed.
		aim_error = rng.randf_range(-1.0, 1.0) * [48.0, 28.0, 16.0][level]
		style_time = rng.randf_range(0.8, 1.4)
	var team := int(state["team"])
	var new_rally: bool = seen_rally != int(ball.rally)
	var incoming_event := false
	if new_rally:
		seen_rally = int(ball.rally)
		seen_hit = int(ball.hit_id)
		incoming_event = ball.active and _is_incoming(ball, team)
	elif seen_hit != int(ball.hit_id):
		seen_hit = int(ball.hit_id)
		incoming_event = _is_incoming(ball, team)
	if incoming_event:
		# Fallibility is sampled for every incoming shot, not once per serve.
		# The selected imperfect plan stays locked until this shot is returned or scores,
		# so the full-trajectory optimizer cannot silently correct it next frame.
		var reaction: float = [0.48, 0.34, 0.22][level]
		var mistake_chance: float = [0.35, 0.20, 0.10][level]
		mistake_active = rng.randf() < mistake_chance
		mistake_plan_ready = false
		mistake_offset = rng.randf_range(-1.0, 1.0) * [350.0, 280.0, 220.0][level] if mistake_active else 0.0
		mistake_skip_jump = mistake_active and rng.randf() < [0.65, 0.50, 0.35][level]
		var extra_delay: float = [0.28, 0.18, 0.10][level] if mistake_active else 0.0
		reaction_wait = maxf(reaction_wait, rng.randf_range(reaction * 0.75, reaction) + extra_delay)
		rethink = 0.0
	elif not _is_incoming(ball, team):
		mistake_active = false
		mistake_plan_ready = false
		mistake_offset = 0.0
	if reaction_wait > 0.0:
		state["move"] = 0
		first_jump = -1.0
		second_jump = -1.0
		if reaction_wait <= delta: rethink = 0.0
		return
	if mistake_active and not mistake_plan_ready:
		var bad_plan := _choose_mistake_plan(ball, state, level)
		waypoint = float(bad_plan["x"])
		first_jump = float(bad_plan["first"])
		second_jump = float(bad_plan["second"])
		mistake_plan_ready = true
	elif not mistake_active and (rethink <= 0.0 or new_rally):
		var plan := _choose_plan(ball, state, level)
		waypoint = float(plan["x"])
		first_jump = float(plan["first"])
		second_jump = float(plan["second"])
		rethink = [0.48, 0.34, 0.22][level]
	var distance := waypoint - float(state["position"].x)
	var stop_radius: float = [18.0, 11.0, 8.0][level]
	# A settled target and a dead band prevent frame-to-frame left/right twitching.
	if absf(distance) <= stop_radius:
		state["move"] = 0
	elif absf(distance) > stop_radius + 6.0 or int(state.get("move", 0)) != 0:
		state["move"] = int(signf(distance))
	if not ball.active:
		first_jump = -1.0
		second_jump = -1.0
		return
	if first_jump == 0.0 and int(state.get("jumps", 0)) == 0:
		if MOTION.jump(state): events.append({"kind": "jump"})
		first_jump = -1.0
	if second_jump == 0.0 and int(state.get("jumps", 0)) == 1:
		if MOTION.jump(state):
			var direction := MOTION.double_jump_direction(state)
			state["double_jump_direction"] = direction
			events.append({"kind": "double_jump", "spin_direction": direction})
		second_jump = -1.0

func _is_incoming(ball, team: int) -> bool:
	if not ball.active: return false
	return ball.velocity.x < -12.0 if team == 0 else ball.velocity.x > 12.0

func _choose_mistake_plan(ball, state: Dictionary, level: int) -> Dictionary:
	# A deliberately rough ground projection ignores the wall, platforms and second
	# jumps. Combined with the locked wrong target this creates visible, recoverable
	# reading errors instead of an imperceptible adjustment to an otherwise perfect plan.
	var team := int(state["team"])
	var lo := 210.0 if team == 0 else COURT.WALL.end.x + COURT.PLAYER_HALF_WIDTH
	var hi := COURT.WALL.position.x - COURT.PLAYER_HALF_WIDTH if team == 0 else 1710.0
	var target_y := COURT.FLOOR - COURT.RADIUS
	var discriminant := float(ball.velocity.y * ball.velocity.y + 1520.0 * (target_y - ball.position.y))
	var fall_time := 0.35
	if discriminant > 0.0:
		var root: float = (-float(ball.velocity.y) + sqrt(discriminant)) / 760.0
		if root > 0.0: fall_time = root
	var projected_x: float = float(ball.position.x) + float(ball.velocity.x) * fall_time
	var wrong_x: float
	if mistake_skip_jump:
		# On the strongest mistake type the partner commits to the far end of its
		# half-court, away from the estimated drop point, and never jumps for the shot.
		wrong_x = lo if absf(projected_x - lo) > absf(projected_x - hi) else hi
	else:
		wrong_x = clampf(projected_x + mistake_offset, lo, hi)
	var first := -1.0
	var second := -1.0
	if not mistake_skip_jump:
		var late_by := rng.randf_range([0.24, 0.18, 0.12][level], [0.42, 0.32, 0.24][level])
		var late_jump := maxf(0.0, fall_time - late_by)
		if int(state.get("jumps", 0)) == 0:
			first = late_jump
		elif int(state.get("jumps", 0)) == 1:
			second = late_jump
	return {"x": wrong_x, "first": first, "second": second}

func _forecast(ball) -> Array:
	# Reuse authoritative ball physics, including wall and stand rebounds.
	var ghost = ball.get_script().new()
	ghost.position = ball.position
	ghost.velocity = ball.velocity
	ghost.active = true
	var samples: Array = []
	for frame in 144:
		ghost.step(DT, {})
		if not ghost.active: break
		samples.append({"position": ghost.position, "velocity": ghost.velocity, "time": (frame + 1) * DT})
	return samples

func _choose_plan(ball, state: Dictionary, level: int) -> Dictionary:
	var team := int(state["team"])
	var attack := 1.0 if team == 0 else -1.0
	var lo := 210.0 if team == 0 else COURT.WALL.end.x + COURT.PLAYER_HALF_WIDTH
	var hi := COURT.WALL.position.x - COURT.PLAYER_HALF_WIDTH if team == 0 else 1710.0
	var fallback := {"x": 560.0 if team == 0 else 1360.0, "first": -1.0, "second": -1.0}
	if not ball.active: return fallback
	var path := _forecast(ball)
	var best := fallback
	var best_score := INF
	var lowest := -INF
	for index in range(2, path.size(), 6):
		var sample: Dictionary = path[index]
		var point: Vector2 = sample["position"]
		if (point.x > 970.0 if team == 0 else point.x < 950.0): continue
		var target_x := clampf(point.x - attack * 48.0 + aim_error, lo, hi)
		if point.y > lowest:
			lowest = point.y
			fallback["x"] = target_x
		if point.y < 455.0: continue
		var time: float = sample["time"]
		if absf(target_x - float(state["position"].x)) > MOTION.CONFIG.move_speed * time + 75.0: continue
		var schedules: Array = [Vector2(-1.0, -1.0)]
		var jumps := int(state.get("jumps", 0))
		if jumps == 0:
			var height := maxf(0.0, float(state["position"].y) - (point.y + 82.0))
			var rise := _rise_time(height)
			if rise >= 0.0: schedules.append(Vector2(maxf(0.0, time - rise), -1.0))
			schedules.append(Vector2(0.0, -1.0))
			if level > 0:
				var launch_gap := 0.25
				var first_height := MOTION.CONFIG.jump_speed * launch_gap - 0.5 * MOTION.CONFIG.gravity * launch_gap * launch_gap
				var second_rise := _rise_time(maxf(0.0, height - first_height))
				if second_rise >= 0.0:
					var delay := maxf(0.0, time - launch_gap - second_rise)
					schedules.append(Vector2(delay, delay + launch_gap))
		elif jumps == 1 and level > 0:
			schedules.append(Vector2(-1.0, 0.0))
			schedules.append(Vector2(-1.0, maxf(0.0, time - 0.22)))
		for schedule: Vector2 in schedules:
			var score := _evaluate(ball, state, path, index, target_x, schedule, attack)
			if score < best_score:
				best_score = score
				best = {"x": target_x, "first": schedule.x, "second": schedule.y}
	return fallback if is_inf(best_score) else best

func _rise_time(height: float) -> float:
	var discriminant := MOTION.CONFIG.jump_speed * MOTION.CONFIG.jump_speed - 2.0 * MOTION.CONFIG.gravity * height
	if discriminant < 0.0: return -1.0
	return (MOTION.CONFIG.jump_speed - sqrt(discriminant)) / MOTION.CONFIG.gravity

func _evaluate(ball, state: Dictionary, path: Array, end_index: int, target_x: float, schedule: Vector2, attack: float) -> float:
	var player := state.duplicate()
	var first_done := schedule.x < 0.0
	var second_done := schedule.y < 0.0
	for index in mini(path.size(), end_index + 4):
		var time := float(index) * DT
		if not first_done and time >= schedule.x:
			if int(player.get("jumps", 0)) == 0: MOTION.jump(player)
			first_done = true
		if not second_done and time >= schedule.y:
			if int(player.get("jumps", 0)) == 1: MOTION.jump(player)
			second_done = true
		var distance := target_x - float(player["position"].x)
		player["move"] = int(signf(distance)) if absf(distance) > 8.0 else 0
		COURT.step_player(player, DT)
		var sample: Dictionary = path[index]
		var separation: Vector2 = sample["position"] - (player["position"] - Vector2(0, 30))
		if separation.length() >= COURT.RADIUS + 39.0: continue
		var normal := separation.normalized()
		var player_velocity := Vector2(float(player.get("velocity_x", 0.0)), float(player["velocity_y"]))
		var incoming: Vector2 = sample["velocity"]
		var approach := (incoming - player_velocity).dot(normal)
		if approach >= 0.0: continue
		var outgoing: Vector2 = ball.player_hit_response(incoming, player_velocity, normal)
		var contact: Vector2 = player["position"] - Vector2(0, 30) + normal * (COURT.RADIUS + 40.0)
		var flight_time := (-outgoing.y + sqrt(outgoing.y * outgoing.y + 1520.0 * maxf(0.0, COURT.FLOOR - COURT.RADIUS - contact.y))) / 760.0
		var wall_edge := COURT.WALL.position.x - COURT.RADIUS if attack > 0.0 else COURT.WALL.end.x + COURT.RADIUS
		var clears := false
		if outgoing.x * attack > 1.0:
			var crossing_time := (wall_edge - contact.x) / outgoing.x
			var crossing_y := contact.y + outgoing.y * crossing_time + 380.0 * crossing_time * crossing_time
			clears = crossing_time >= 0.0 and crossing_time < flight_time and crossing_y < COURT.WALL.position.y - COURT.RADIUS - 3.0
		# Reward a complete return over the wall, rather than a touch that drops at home.
		var progress := clampf(outgoing.x * attack * flight_time, -800.0, 800.0)
		return float(sample["time"]) * 120.0 - clampf(outgoing.x * attack, -620.0, 620.0) * 0.09 - progress * 0.03 - (100.0 if clears else 0.0) + normal.y * 8.0
	return INF

func snapshot() -> Dictionary:
	return {"rethink": rethink, "style_time": style_time, "aim_error": aim_error, "waypoint": waypoint, "first_jump": first_jump, "second_jump": second_jump, "mistake_offset": mistake_offset, "mistake_active": mistake_active, "mistake_plan_ready": mistake_plan_ready, "mistake_skip_jump": mistake_skip_jump, "reaction_wait": reaction_wait, "seen_hit": seen_hit, "seen_rally": seen_rally, "rng_state": rng.state}

func restore(data: Dictionary) -> void:
	for key in ["rethink", "style_time", "aim_error", "waypoint", "first_jump", "second_jump", "mistake_offset", "mistake_active", "mistake_plan_ready", "mistake_skip_jump", "reaction_wait", "seen_hit", "seen_rally"]:
		if data.has(key): set(key, data[key])
	if data.has("rng_state"): rng.state = data["rng_state"]

func take_events() -> Array:
	var pending := events.duplicate(true)
	events.clear()
	return pending
