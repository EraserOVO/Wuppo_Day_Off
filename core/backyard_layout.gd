extends RefCounted

const DOOR_X := 192.0 # Left 10% of the 1920-wide scene remains indoors.
const DOOR_TOP := 690.0
const SHOP := Rect2(340, 728, 150, 152)
const PLOTS := [720.0, 920.0, 1120.0, 1320.0, 1520.0, 1720.0]
const SURFACES := [Rect2(340, 816, 150, 16)]

static func nearby(pos: Vector2) -> String:
	var center := pos - Vector2(0, 30)
	if center.distance_to(center.clamp(SHOP.position, SHOP.end)) <= 64:
		return "种子摊"
	for index in PLOTS.size():
		if absf(pos.x - PLOTS[index]) <= 74 and absf(pos.y - 880.0) <= 75:
			return "种植地 %s" % (index + 1)
	return ""
