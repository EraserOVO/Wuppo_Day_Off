extends RefCounted
const WORLD = preload("res://core/world_layout.gd")
const MOTION = preload("res://core/player_motion.gd")
const BACKYARD = preload("res://core/backyard_layout.gd")
# Furniture tops and wall shelves are real one-way surfaces, shared with drawing.
const SURFACES := {
	"crate_low": Rect2(200, 825, 74, 55),
	"crate_high": Rect2(274, 770, 62, 110),
	"wardrobe": Rect2(326, 720, 128, 160),
	"shelf_left": Rect2(490, 658, 180, 12),
	"window_ledge": Rect2(764, 660, 362, 14),
	"sofa": Rect2(650, 804, 160, 76),
	"desk": Rect2(914, 792, 132, 88),
	"shelf_right": Rect2(1170, 704, 160, 12),
	"bench": Rect2(1340, 818, 110, 62),
}
const OBJECT_BOUNDS := {
	"衣柜": Rect2(330, 720, 120, 160),
	"电脑": Rect2(914, 730, 132, 150),
	"门": Rect2(1506, 690, 108, 190),
}
const SPAWNS := [Vector2(730, 804), Vector2(1090, 880), Vector2(1460, 880), Vector2(560, 880)]

static func jump(state: Dictionary) -> bool:
	return MOTION.jump(state)

static func set_crouching(state: Dictionary, requested: bool) -> void:
	MOTION.set_crouching(state, requested)

static func double_jump_direction(state: Dictionary) -> float:
	return MOTION.double_jump_direction(state)

static func is_supported(pos: Vector2) -> bool:
	return MOTION.is_supported(pos, SURFACES.values(), true)

static func nearby(pos: Vector2, area: String = "room") -> String:
	if area == "backyard": return BACKYARD.nearby(pos)
	var body_center := pos - Vector2(0, 30)
	for object in OBJECT_BOUNDS:
		var rect: Rect2 = OBJECT_BOUNDS[object]
		var closest := body_center.clamp(rect.position, rect.end)
		if closest.distance_to(body_center) <= 64: return object
	return ""

static func step(state: Dictionary, delta: float) -> void:
	var area := str(state.get("lobby_area", "room"))
	var previous: Vector2 = state["position"]
	var surfaces: Array = BACKYARD.SURFACES if area == "backyard" else SURFACES.values()
	MOTION.step_terrain(state, delta, surfaces, true, 0.0, WORLD.SIZE.x)
	var pos: Vector2 = state["position"]
	if area == "backyard" and pos.y < BACKYARD.DOOR_TOP + 60:
		# The wall above the doorway is solid even while double jumping.
		if previous.x <= BACKYARD.DOOR_X - 24 and pos.x > BACKYARD.DOOR_X - 24:
			pos.x = BACKYARD.DOOR_X - 24
			state["velocity_x"] = 0.0
		elif previous.x >= BACKYARD.DOOR_X + 24 and pos.x < BACKYARD.DOOR_X + 24:
			pos.x = BACKYARD.DOOR_X + 24
			state["velocity_x"] = 0.0
		elif pos.x > BACKYARD.DOOR_X - 24 and pos.x < BACKYARD.DOOR_X + 24:
			if previous.y >= BACKYARD.DOOR_TOP + 60:
				# Jumping inside the doorway hits the lintel rather than entering the wall.
				pos.y = BACKYARD.DOOR_TOP + 60
				state["velocity_y"] = 0.0
			else:
				pos.x = BACKYARD.DOOR_X - 24 if previous.x < BACKYARD.DOOR_X else BACKYARD.DOOR_X + 24
				state["velocity_x"] = 0.0
		state["position"] = pos
	var direction := int(state.get("move", 0))
	if area == "room" and pos.x >= WORLD.SIZE.x and direction > 0:
		_enter_area(state, "backyard", 12.0)
	elif area == "backyard" and pos.x <= 0 and direction < 0:
		_enter_area(state, "room", WORLD.SIZE.x - 12.0)

static func _enter_area(state: Dictionary, area: String, x: float) -> void:
	state["lobby_area"] = area
	state["position"] = Vector2(x, WORLD.FLOOR_Y)
	state["velocity_y"] = 0.0
	state["velocity_x"] = 0.0
	state["jumps"] = 0
	state["grounded"] = true
	state["crouching"] = false
	state["jump_boosted"] = false
	state["crouch_jump_remaining"] = 0.0
