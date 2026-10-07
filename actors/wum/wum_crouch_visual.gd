extends Node2D
const BOTTOM := 39.0 # Contour bottom (37) plus half the outline width (2).

var fill_color := Color("f4e3bb"):
	set(value):
		fill_color = value
		queue_redraw()

func _draw() -> void:
	var anchors := PackedVector2Array([
		Vector2(-35, 10), Vector2(-34, 1), Vector2(-29, -6), Vector2(-21, -10),
		Vector2(-11, -12), Vector2(0, -12), Vector2(11, -11), Vector2(22, -8),
		Vector2(30, -2), Vector2(35, 7), Vector2(35, 17), Vector2(31, 27),
		Vector2(24, 33), Vector2(13, 36), Vector2(0, 37), Vector2(-13, 36),
		Vector2(-24, 33), Vector2(-31, 26), Vector2(-35, 18)
	])
	var contour := PackedVector2Array()
	for index in anchors.size():
		var p0: Vector2 = anchors[(index - 1 + anchors.size()) % anchors.size()]
		var p1: Vector2 = anchors[index]
		var p2: Vector2 = anchors[(index + 1) % anchors.size()]
		var p3: Vector2 = anchors[(index + 2) % anchors.size()]
		for sample in 4:
			var t := float(sample) / 4.0
			var t2 := t * t
			var t3 := t2 * t
			contour.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	draw_colored_polygon(contour, fill_color)
	contour.append(contour[0])
	draw_polyline(contour, Color("57483c"), 4.0, true)
