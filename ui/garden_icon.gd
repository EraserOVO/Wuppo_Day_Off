extends Control
const ART = preload("res://ui/garden_art.gd")
var kind := "coin"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	if kind == "coin": ART.coin(self, size * 0.5, minf(size.x, size.y) * 0.4)
	elif kind.begins_with("seed:"):
		ART.seed(self, kind.get_slice(":", 1), Vector2(size.x * 0.5, size.y * 0.94), minf(size.x / 64, size.y / 72))
	else: ART.produce(self, kind, Vector2(size.x * 0.5, size.y * 0.94), minf(size.x / 100, size.y / 120))
