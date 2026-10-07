extends RefCounted

const COURT = preload("res://modes/mud_ball/court.gd")
const MOTION = preload("res://core/player_motion.gd")
const GRAVITY := 760.0
const SERVE_START_Y := 320.0
var position := Vector2.ZERO
var velocity := Vector2.ZERO
var scores := [0, 0]
var target_score := 10
var serving_team := 0
var active := false
var serve_wait := 0.0
var rally := 0
var winner := -1
var burst_position := Vector2.ZERO
var spin_angle := 0.0
var spin_speed := 0.0
var hit_id := 0
var hit_position := Vector2.ZERO
var bot_rng := RandomNumberGenerator.new()
var bot_brain = preload("res://modes/mud_ball/practice_bot.gd").new()

func _init() -> void:
	MOTION.register_step_profile("mud_ball", Callable(COURT, "step_player"))

func prepare(states: Dictionary, selected_target := 10) -> void:
	target_score = selected_target if selected_target in [5, 7, 10, 15] else 10
	var ids: Array = states.keys()
	ids.sort()
	if ids.has(-1):
		ids.erase(-1)
		ids.append(-1)
	for index in ids.size():
		var state: Dictionary = states[ids[index]]
		var team := 0 if index < ids.size() / 2 else 1
		state["team"] = team
		state["movement_profile"] = "mud_ball"
		state["court"] = "mud_ball"
		state["position"] = Vector2(520 + index * 100 if team == 0 else 1360 + (index % 2) * 100, COURT.FLOOR)
	serving_team = randi_range(0, 1)
	serve_wait = 0.7
	bot_rng.randomize()

func serve() -> void:
	position = Vector2(COURT.LEFT + COURT.RADIUS + 12.0 if serving_team == 0 else COURT.RIGHT - COURT.RADIUS - 12.0, SERVE_START_Y)
	spin_speed = 0.0
	var direction := 1.0 if serving_team == 0 else -1.0
	var target_x: float
	var target_y: float
	if bot_rng.randf() < 0.24:
		# Some serves drop onto the raised center wall, like a short net serve.
		target_x = COURT.WALL.get_center().x
		target_y = COURT.WALL.position.y - COURT.RADIUS
	else:
		# The remaining serves clear the wall and land in the receiver's near court.
		var landing_x := bot_rng.randf_range(1020.0, 1240.0)
		target_x = landing_x if serving_team == 0 else 1920.0 - landing_x
		target_y = COURT.FLOOR - COURT.RADIUS
	var flight_time := sqrt(2.0 * (target_y - position.y) / GRAVITY)
	var horizontal_speed := absf(target_x - position.x) / flight_time
	# Launch level, with gravity alone creating the downward arc.
	velocity = Vector2(horizontal_speed * direction, 0.0)
	active = true
	rally += 1

func point(team: int, states: Dictionary) -> void:
	if not active or winner >= 0: return
	scores[team] += 1
	serving_team = team
	burst_position = position
	active = false
	serve_wait = 1.2
	for state in states.values(): state["score"] = scores[int(state["team"])]
	if scores[team] >= target_score: winner = team

func step(delta: float, states: Dictionary) -> void:
	if winner >= 0: return
	if not active:
		serve_wait -= delta
		if serve_wait <= 0: serve()
		return
	# Substeps prevent fast balls passing through the central wall or players.
	var count := maxi(1, ceili(velocity.length() * delta / 18.0))
	for _sub in count:
		var dt := delta / count
		spin_angle = wrapf(spin_angle + spin_speed * dt, -TAU, TAU)
		spin_speed *= exp(-1.0 * dt)
		velocity.y += GRAVITY * dt
		position += velocity * dt
		if position.x < COURT.LEFT + COURT.RADIUS:
			position.x = COURT.LEFT + COURT.RADIUS
			velocity.x = absf(velocity.x) * 0.76
		elif position.x > COURT.RIGHT - COURT.RADIUS:
			position.x = COURT.RIGHT - COURT.RADIUS
			velocity.x = -absf(velocity.x) * 0.76
		if position.y < COURT.RADIUS:
			position.y = COURT.RADIUS
			velocity.y = absf(velocity.y) * 0.76
		var previous := position - velocity * dt
		if _bounce_from_solid(COURT.WALL, previous):
			# A flat, low-speed collision can no longer leave the ball balanced on the wall.
			pass
		for deck in COURT.platforms():
			if deck == COURT.WALL: continue
			if previous.y + COURT.RADIUS <= deck.position.y and velocity.y > 0 and position.y + COURT.RADIUS >= deck.position.y and position.x + COURT.RADIUS > deck.position.x and position.x - COURT.RADIUS < deck.end.x:
				position.y = deck.position.y - COURT.RADIUS
				velocity.y = -maxf(absf(velocity.y) * 0.82, 185.0)
				# Stands sit beside the arena bounds. Send slow or outward-moving balls
				# back toward the court so they cannot bounce in place at a seat edge.
				var toward_court := 1.0 if deck.get_center().x < 960.0 else -1.0
				if velocity.x * toward_court < 140.0:
					velocity.x = toward_court * maxf(145.0, absf(velocity.x) * 0.45)
		for state in states.values():
			var center: Vector2 = state["position"] - Vector2(0, 30)
			var separation := position - center
			if separation.length() >= COURT.RADIUS + 40: continue
			var normal := separation.normalized() if separation.length() > 0.001 else Vector2.UP
			var player_velocity := Vector2(float(state.get("velocity_x", 0.0)), float(state["velocity_y"]))
			position = center + normal * (COURT.RADIUS + 40)
			var approach := (velocity - player_velocity).dot(normal)
			if approach < 0:
				var boosted := bool(state.get("jump_boosted", false)) and int(state.get("jumps", 0)) == 1 and player_velocity.y < -0.5
				velocity = player_hit_response(velocity, player_velocity, normal, boosted)
				spin_speed = signf(velocity.x) * bot_rng.randf_range(2.0, 4.2)
				if is_zero_approx(velocity.x): spin_speed = bot_rng.randf_range(-3.0, 3.0)
				hit_id += 1
				hit_position = position
		if position.y + COURT.RADIUS >= COURT.FLOOR:
			point(1 if position.x < 960 else 0, states)
			return

func player_hit_response(incoming: Vector2, player_velocity: Vector2, normal: Vector2, crouch_jump: bool = false) -> Vector2:
	var outgoing := incoming - normal * (incoming - player_velocity).dot(normal) * 1.15
	outgoing += player_velocity * 0.20
	# Give contacts a clear upward lift while leaving horizontal direction to the
	# actual collision normal, incoming ball and player movement.
	outgoing.y = minf(outgoing.y, -230.0 - minf(absf(player_velocity.y) * 0.11, 110.0))
	outgoing = outgoing.limit_length(620.0)
	if outgoing.length() < 360.0: outgoing = outgoing.normalized() * 360.0
	if crouch_jump:
		outgoing.y -= 160.0
		outgoing = outgoing.limit_length(760.0)
	return outgoing

func _bounce_from_solid(rect: Rect2, previous: Vector2) -> bool:
	var closest := Vector2(clampf(position.x, rect.position.x, rect.end.x), clampf(position.y, rect.position.y, rect.end.y))
	var offset := position - closest
	if offset.length() >= COURT.RADIUS: return false
	var normal: Vector2
	if offset.length() > 0.001:
		normal = offset.normalized()
	elif previous.y + COURT.RADIUS <= rect.position.y:
		normal = Vector2.UP
	else:
		normal = Vector2.LEFT if velocity.x > 0 else Vector2.RIGHT
	position = closest + normal * COURT.RADIUS
	if velocity.dot(normal) < 0:
		velocity = velocity.bounce(normal) * 0.8
		if normal.y < -0.48 and velocity.y > -165.0: velocity.y = -165.0
		if absf(normal.x) > 0.48 and absf(velocity.x) < 140.0: velocity.x = signf(normal.x) * 140.0
		if velocity.length() < 190.0: velocity += normal * (190.0 - velocity.length())
		return true
	return false

func bot(state: Dictionary, difficulty := 1, delta := 1.0 / 60.0) -> void:
	bot_brain.step(self, state, difficulty, delta)

func take_bot_events() -> Array:
	return bot_brain.take_events()

func snapshot() -> Dictionary:
	return {"position": position, "velocity": velocity, "scores": scores.duplicate(), "target_score": target_score, "serving_team": serving_team, "active": active, "serve_wait": serve_wait, "rally": rally, "winner": winner, "burst_position": burst_position, "rotation": spin_angle, "spin_speed": spin_speed, "hit_id": hit_id, "hit_position": hit_position, "bot_rng_state": bot_rng.state, "bot": bot_brain.snapshot()}

func restore(data: Dictionary) -> void:
	for key in data:
		if key in ["position", "velocity", "scores", "target_score", "serving_team", "active", "serve_wait", "rally", "winner", "burst_position", "spin_angle", "spin_speed", "hit_id", "hit_position"]: set(key, data[key])
	if data.has("bot_rng_state"): bot_rng.state = data["bot_rng_state"]
	if data.has("rotation"): spin_angle = float(data["rotation"])
	if data.has("bot"): bot_brain.restore(data["bot"])
