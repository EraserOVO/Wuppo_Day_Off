extends "res://ui/smooth_follower.gd"

const CHARGE_RADIUS := 18.0
const WHISTLE_RADIUS := 25.5
const WHISTLE_RING_WIDTH := 5.0
const ARC_STEPS := 72
const PERFECT_RATIO := 0.92
const WHISTLE_COLOR := Color(0.9, 0.24, 1.0, 0.96)

var own_progress := 0.0
var total_progress := 0.0
var whistle_ready := 0.0
var warning_stage := 0
var stage_colors: Array[Color] = [
	Color(0.65, 0.95, 1.0),
	Color(1.0, 0.95, 0.5),
	Color(1.0, 0.65, 0.4),
	Color(1.0, 0.4, 0.5)
]

func set_values(own_value: float, total_value: float, whistle_value: float, stage: int) -> void:
	own_progress = clampf(own_value, 0.0, 1.0)
	total_progress = clampf(total_value, own_progress, 1.0)
	whistle_ready = clampf(whistle_value, 0.0, 1.0)
	warning_stage = clampi(stage, 0, stage_colors.size() - 1)
	queue_redraw()

func _draw() -> void:
	var center := Vector2.ZERO
	draw_arc(center, WHISTLE_RADIUS, 0.0, TAU, ARC_STEPS, Color(0.11, 0.16, 0.22, 0.72), WHISTLE_RING_WIDTH, true)
	_draw_arc_segment(WHISTLE_RADIUS, 0.0, whistle_ready, WHISTLE_COLOR, WHISTLE_RING_WIDTH)

	draw_circle(center, CHARGE_RADIUS, Color(0.11, 0.16, 0.22, 0.72))
	_draw_sector(CHARGE_RADIUS, 0.0, total_progress, WHISTLE_COLOR)
	# Paint natural charge last so it fully masks the left part of whistle-added charge.
	_draw_sector(CHARGE_RADIUS, 0.0, own_progress, stage_colors[warning_stage])
	var perfect_angle := -PI * 0.5 + TAU * PERFECT_RATIO
	var mark_start := Vector2(cos(perfect_angle), sin(perfect_angle)) * (CHARGE_RADIUS - 2.0)
	var mark_end := Vector2(cos(perfect_angle), sin(perfect_angle)) * (CHARGE_RADIUS + 1.5)
	draw_line(mark_start, mark_end, Color(1.0, 0.86, 0.38, 0.98), 2.0, true)

func _draw_arc_segment(radius: float, from_ratio: float, to_ratio: float, color: Color, width: float) -> void:
	var start := clampf(from_ratio, 0.0, 1.0)
	var finish := clampf(to_ratio, start, 1.0)
	if finish <= start:
		return
	draw_arc(Vector2.ZERO, radius, -PI * 0.5 + TAU * start, -PI * 0.5 + TAU * finish, maxi(2, ceili((finish - start) * ARC_STEPS)), color, width, true)

func _draw_sector(radius: float, from_ratio: float, to_ratio: float, color: Color) -> void:
	var start := clampf(from_ratio, 0.0, 1.0)
	var finish := clampf(to_ratio, start, 1.0)
	if finish <= start:
		return
	var steps := maxi(2, ceili((finish - start) * ARC_STEPS))
	var points := PackedVector2Array()
	points.append(Vector2.ZERO)
	for step in range(steps + 1):
		var ratio := lerpf(start, finish, float(step) / float(steps))
		var angle := -PI * 0.5 + TAU * ratio
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, color)

