extends Control

const ART = preload("res://ui/garden_art.gd")

var bubble_color := Color.WHITE

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	ART.dye_bubble(self, size * 0.5, minf(size.x, size.y) * 0.38, bubble_color)
