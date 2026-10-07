extends RefCounted

const SIZE := Vector2(1920, 1080)
const CENTER := SIZE * 0.5
const FLOOR_Y := 880.0
const LEFT := 144.0
const RIGHT := 1776.0
const ACTOR_SCALE := 0.8
const WIDGET_SCALE := 1.0
const OBJECTS := {"衣柜": 390.0, "电脑": 980.0, "门": 1560.0}

static func fit_scale(view: Vector2) -> float:
	return minf(view.x / SIZE.x, view.y / SIZE.y)

static func visible_world(node: Node2D) -> Rect2:
	var parent := node.get_parent()
	if parent is Control and parent.clip_contents:
		var local_inverse := node.transform.affine_inverse()
		return Rect2(local_inverse * Vector2.ZERO, (local_inverse * parent.size) - (local_inverse * Vector2.ZERO))
	var inverse := node.get_global_transform_with_canvas().affine_inverse()
	var view := node.get_viewport_rect().size
	return Rect2(inverse * Vector2.ZERO, (inverse * view) - (inverse * Vector2.ZERO))
