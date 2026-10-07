extends RefCounted

const ART = preload("res://ui/garden_art.gd")
const CLOUDS := [Vector2(350, 280), Vector2(870, 170), Vector2(1030, 470), Vector2(1960, 310), Vector2(2390, 130)]

static func draw_landscape(canvas: CanvasItem, view: Rect2) -> void:
	canvas.draw_rect(view, Color("c6e3da"))
	draw_clouds(canvas, view)
	_draw_mountains(canvas, view, 1040.0, 810.0, 340.0, Color("a9c99e"), 0.0)
	_draw_mountains(canvas, view, 880.0, 830.0, 440.0, Color("8db690"), 430.0)

static func _draw_mountains(canvas: CanvasItem, view: Rect2, spacing: float, base_y: float, peak_y: float, color: Color, offset: float) -> void:
	var start := floori((view.position.x - offset) / spacing) - 1
	var end := ceili((view.end.x - offset) / spacing) + 1
	for mountain_index in range(start, end + 1):
		var left := mountain_index * spacing + offset
		var peak := Vector2(left + spacing * (0.46 if posmod(mountain_index, 2) == 0 else 0.58), peak_y + posmod(mountain_index, 3) * 55)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(left - 90, base_y), peak, Vector2(left + spacing + 90, base_y)]), color)

static func cloud_position(index: int, seconds: float) -> Vector2:
	var seed: Vector2 = CLOUDS[index]
	return Vector2(fposmod(seed.x - seconds * (5.0 + index * 0.65) + 300.0, 2800.0) - 300.0, seed.y)

static func draw_clouds(canvas: CanvasItem, view: Rect2, vertical_scale := 1.0) -> void:
	var seconds := Time.get_ticks_msec() / 1000.0
	for index in CLOUDS.size():
		var center := cloud_position(index, seconds)
		center.y *= vertical_scale
		for repeat in range(-2, 3):
			var position := center + Vector2(repeat * 2800.0, 0)
			if position.x + 180 < view.position.x or position.x - 180 > view.end.x: continue
			_draw_cloud(canvas, position, index % 4, 0.85 + (index % 3) * 0.16)

static func _draw_cloud(canvas: CanvasItem, center: Vector2, shape: int, factor: float) -> void:
	var lobes: Array = [
		[Vector4(-57, -8, 30, 24), Vector4(-24, -25, 36, 34), Vector4(20, -24, 42, 37), Vector4(66, -6, 29, 22)],
		[Vector4(-103, -4, 39, 15), Vector4(-63, -13, 40, 22), Vector4(-12, -22, 48, 29), Vector4(46, -14, 48, 23), Vector4(104, -3, 35, 16)],
		[Vector4(-49, -9, 32, 25), Vector4(-21, -37, 36, 35), Vector4(17, -40, 42, 42), Vector4(55, -12, 35, 28)],
		[Vector4(-83, -10, 34, 25), Vector4(-48, -28, 38, 33), Vector4(1, -9, 39, 24), Vector4(50, -34, 43, 38), Vector4(91, -8, 30, 24)]
	][shape]
	for lobe: Vector4 in lobes:
		ART.ellipse(canvas, center + Vector2(lobe.x, lobe.y) * factor, Vector2(lobe.z, lobe.w) * factor, Color("eef4e3"))
	var base_width: float = [101.0, 147.0, 93.0, 126.0][shape]
	ART.ellipse(canvas, center + Vector2(0, 2) * factor, Vector2(base_width, 18) * factor, Color("eef4e3"))
