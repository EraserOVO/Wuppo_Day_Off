extends RefCounted

const CONFIG = preload("res://data/player_movement_config.tres")
const WORLD = preload("res://core/world_layout.gd")
const STEP := 1.0 / 60.0
const FLOOR_Y := WORLD.FLOOR_Y
const ARENA_LEFT := WORLD.LEFT
const ARENA_RIGHT := WORLD.RIGHT
static var step_profiles: Dictionary = {}
# One-way decks shared by rendering, server authority and client prediction.
const PLATFORMS := [Rect2(300, 730, 320, 22), Rect2(770, 650, 440, 22), Rect2(1350, 730, 300, 22)]

static func ground_height(x: float) -> float:
	var central := exp(-pow((x - 990.0) / 410.0, 2.0))
	var left := exp(-pow((x - 310.0) / 220.0, 2.0))
	var right := exp(-pow((x - 1530.0) / 250.0, 2.0))
	return 914.0 - central * 104.0 - left * 48.0 - right * 42.0

static func spawn_position(x: float) -> Vector2:
	var y := ground_height(x)
	for deck in PLATFORMS:
		if x >= deck.position.x and x <= deck.end.x: y = minf(y, deck.position.y)
	return Vector2(x, y)

static func floor_height(x: float, flat_floor: bool = false) -> float:
	return FLOOR_Y if flat_floor else ground_height(x)

static func is_supported(pos: Vector2, platforms: Array = PLATFORMS, flat_floor: bool = false) -> bool:
	if absf(pos.y - floor_height(pos.x, flat_floor)) < 0.5: return true
	for deck in platforms:
		if pos.x >= deck.position.x and pos.x <= deck.end.x and absf(pos.y - deck.position.y) < 0.5: return true
	return false

static func jump(state: Dictionary) -> bool:
	if int(state.get("jumps", 0)) >= 2: return false
	var boosted := int(state.get("jumps", 0)) == 0 and is_grounded(state) and (bool(state.get("crouching", false)) or float(state.get("crouch_jump_remaining", 0.0)) > 0)
	state["jump_boosted"] = boosted
	state["crouch_jump_remaining"] = 0.0
	state["crouching"] = false
	state["grounded"] = false
	state["velocity_y"] = -CONFIG.crouch_jump_speed if boosted else -CONFIG.jump_speed
	state["jumps"] = int(state.get("jumps", 0)) + 1
	return true

static func is_grounded(state: Dictionary) -> bool:
	return bool(state.get("grounded", true)) and int(state.get("jumps", 0)) == 0 and absf(float(state.get("velocity_y", 0.0))) < 0.5

static func set_crouching(state: Dictionary, requested: bool) -> void:
	state["crouch_requested"] = requested
	state["crouching"] = requested and is_grounded(state)
	if state["crouching"]: state["crouch_jump_remaining"] = CONFIG.crouch_jump_window

static func double_jump_direction(state: Dictionary) -> float:
	var horizontal_move := int(state.get("move", 0))
	if horizontal_move < 0: return -1.0
	if horizontal_move > 0: return 1.0
	return -1.0 if randf() < 0.5 else 1.0

static func step(state: Dictionary, delta: float, platforms: Array = PLATFORMS, flat_floor: bool = false) -> void:
	var profile := str(state.get("movement_profile", state.get("court", "")))
	var stepper: Callable = step_profiles.get(profile, Callable())
	if stepper.is_valid():
		stepper.call(state, delta)
		return
	step_terrain(state, delta, platforms, flat_floor)

static func register_step_profile(profile: String, stepper: Callable) -> void:
	if profile.is_empty() or not stepper.is_valid(): return
	step_profiles[profile] = stepper

static func step_terrain(state: Dictionary, delta: float, platforms: Array = PLATFORMS, flat_floor: bool = false, left_bound: float = -1.0, right_bound: float = -1.0) -> void:
	var pos: Vector2 = state["position"]
	var previous := pos
	var velocity := float(state.get("velocity_y", 0.0))
	var horizontal_velocity := float(state.get("velocity_x", 0.0))
	var standing := is_zero_approx(velocity)
	var terrain_contact := standing and pos.y >= floor_height(pos.x, flat_floor) - 0.5
	var crouch_requested := bool(state.get("crouch_requested", state.get("crouching", false)))
	var crouching := crouch_requested and standing and (terrain_contact or is_supported(pos, platforms, flat_floor))
	state["crouching"] = crouching
	state["crouch_jump_remaining"] = CONFIG.crouch_jump_window if crouching else maxf(0, float(state.get("crouch_jump_remaining", 0.0)) - delta)
	var target_horizontal_velocity := 0.0 if crouching else float(int(state.get("move", 0))) * CONFIG.move_speed
	var reversing := not is_zero_approx(horizontal_velocity) and not is_zero_approx(target_horizontal_velocity) and signf(horizontal_velocity) != signf(target_horizontal_velocity)
	var horizontal_rate := CONFIG.move_deceleration if is_zero_approx(target_horizontal_velocity) or reversing else CONFIG.move_acceleration
	horizontal_velocity = move_toward(horizontal_velocity, target_horizontal_velocity, horizontal_rate * delta)
	var min_x := ARENA_LEFT if left_bound < 0.0 else left_bound
	var max_x := ARENA_RIGHT if right_bound < 0.0 else right_bound
	pos.x = clampf(pos.x + horizontal_velocity * delta, min_x, max_x)
	if (pos.x <= min_x and horizontal_velocity < 0.0) or (pos.x >= max_x and horizontal_velocity > 0.0): horizontal_velocity = 0.0
	var grounded := terrain_contact
	if terrain_contact:
		pos.y = floor_height(pos.x, flat_floor)
	elif standing:
		for deck in platforms:
			if previous.x >= deck.position.x and previous.x <= deck.end.x and absf(previous.y - deck.position.y) < 0.5 and pos.x >= deck.position.x and pos.x <= deck.end.x:
				grounded = true
				break
	if not grounded:
		velocity += CONFIG.gravity * delta
		pos.y += velocity * delta
		var landing_y := floor_height(pos.x, flat_floor)
		if velocity >= 0.0:
			for deck in platforms:
				if pos.x >= deck.position.x and pos.x <= deck.end.x and previous.y <= deck.position.y + 0.5 and pos.y >= deck.position.y:
					landing_y = minf(landing_y, deck.position.y)
		if pos.y >= landing_y:
			pos.y = landing_y
			grounded = true
	if grounded:
		velocity = 0.0
		state["jumps"] = 0
		state["jump_boosted"] = false
	else:
		state["crouching"] = false
		state["crouch_jump_remaining"] = 0.0
	state["grounded"] = grounded
	state["velocity_y"] = velocity
	state["velocity_x"] = horizontal_velocity
	state["position"] = pos
	state["crouching"] = grounded and crouch_requested
	if state["crouching"]: state["crouch_jump_remaining"] = CONFIG.crouch_jump_window
