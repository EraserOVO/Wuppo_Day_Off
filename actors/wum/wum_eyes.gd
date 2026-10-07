extends Node2D

var gaze := Vector2.ZERO:
	set(value):
		gaze = value.limit_length(1.0)
		queue_redraw()

func _draw() -> void:
	_draw_eye(Vector2(-13.0, -4.0))
	_draw_eye(Vector2(15.0, -4.0))

func _draw_eye(center: Vector2) -> void:
	draw_circle(center + gaze * 2.8, 4.0, Color("272522"))
