extends Node2D

var phase := 0.0
var stride := 0.0

func _draw() -> void:
	# Local coordinates belong to Visual: the roots overlap the body outline.
	for index in 4:
		var x := -24.0 + float(index) * 16.0
		var swing := sin(phase) * 3.0 * absf(stride)
		var root := Vector2(x, 32.0)
		var tip := Vector2(x + swing, 43.0 - maxf(0.0, swing) * 0.35)
		var ink := Color("57483c")
		draw_line(root, tip, ink, 6.0, true)
		draw_circle(root, 3.0, ink)
		draw_circle(tip, 3.0, ink)
