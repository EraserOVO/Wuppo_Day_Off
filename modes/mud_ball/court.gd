extends RefCounted

const MOTION = preload("res://core/player_motion.gd")
const FLOOR := 880.0
const LEFT := 192.0
const RIGHT := 1728.0
const WALL := Rect2(944, 816, 32, 64)
const PLAYER_HALF_WIDTH := 38.0
const PLAYER_LEFT_BOUND := 38.0
const PLAYER_RIGHT_BOUND := 1882.0
const WALL_ENTRY_HEIGHT := 64.0 / 3.0
const RADIUS := 32.0

static func platforms() -> Array:
	var decks: Array = [WALL]
	for tier in 5:
		var y := FLOOR - 110.0 * (tier + 1)
		var outward_x := 10.0 + float(4 - tier) * 24.0
		decks.append(Rect2(outward_x, y, 166, 18))
		decks.append(Rect2(1744.0 - float(4 - tier) * 24.0, y, 166, 18))
	return decks

static func step_player(state: Dictionary, delta: float) -> void:
	var previous: Vector2 = state["position"]
	# Shared movement handles gravity, jumping and the one-way stand decks.
	MOTION.step_terrain(state, delta, platforms(), true, PLAYER_LEFT_BOUND, PLAYER_RIGHT_BOUND)
	var pos: Vector2 = state["position"]
	# Let a jumping Wum overlap the wall's top third. On the way down, the
	# shared one-way platform catches them on the wall top instead of wedging
	# their body against an invisible full-height side barrier.
	var wall_top := WALL.position.y
	var entry_limit := wall_top + WALL_ENTRY_HEIGHT
	var falling := float(state.get("velocity_y", 0.0)) >= 0.0
	if falling and pos.x >= WALL.position.x and pos.x <= WALL.end.x and previous.y <= entry_limit and pos.y > wall_top and pos.y <= entry_limit:
		pos.y = wall_top
		state["velocity_y"] = 0.0
		state["jumps"] = 0
		state["grounded"] = true
		state["jump_boosted"] = false
	if pos.y > entry_limit:
		var left_clearance := WALL.position.x - PLAYER_HALF_WIDTH
		var right_clearance := WALL.end.x + PLAYER_HALF_WIDTH
		if previous.x <= left_clearance:
			pos.x = minf(pos.x, left_clearance)
		elif previous.x >= right_clearance:
			pos.x = maxf(pos.x, right_clearance)
		else:
			# Recover a player who was already overlapping the wall when falling
			# below the entry zone by moving them out through the nearer side.
			pos.x = left_clearance if pos.x < WALL.get_center().x else right_clearance
	state["position"] = pos
	if bool(state.get("crouch_requested", false)) and MOTION.is_grounded(state):
		MOTION.set_crouching(state, true)

