extends Node2D
const LAYERS = preload("res://ui/scene_layers.gd")
const SCENERY = preload("res://ui/outdoor_scenery.gd")
const WORLD = preload("res://core/world_layout.gd")
const WINDOW_VIEW := Rect2(790, 432, 310, 222)
const MOTION = preload("res://core/lobby_motion.gd")

func _ready() -> void:
	LAYERS.install(self, _draw_layer)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw_layer(canvas: Node2D, depth: int) -> void:
	var view := WORLD.visible_world(self).grow(4)
	if depth == LAYERS.Depth.FAR:
		SCENERY.draw_landscape(canvas, view)
		return
	if depth == LAYERS.Depth.NEAR:
		_draw_furniture(canvas)
		return
	_wall_region(canvas, view, Color("f3ecd9"))
	var x := floorf(view.position.x / 150) * 150
	while x < view.end.x:
		var end_y := WINDOW_VIEW.position.y if x >= WINDOW_VIEW.position.x and x <= WINDOW_VIEW.end.x else 578.0
		canvas.draw_line(Vector2(x, view.position.y), Vector2(x, end_y), Color("eae2cf"), 2)
		x += 150
	_wall_region(canvas, Rect2(view.position.x, 578, view.size.x, 302), Color("c9d4be"))
	canvas.draw_line(Vector2(view.position.x, 578), Vector2(790, 578), Color("a1b49a"), 8)
	canvas.draw_line(Vector2(1100, 578), Vector2(view.end.x, 578), Color("a1b49a"), 8)
	if view.end.y > WORLD.FLOOR_Y:
		canvas.draw_rect(Rect2(view.position.x, WORLD.FLOOR_Y, view.size.x, view.end.y - WORLD.FLOOR_Y), Color("b99874"))
		x = floorf(view.position.x / 110) * 110
		while x < view.end.x:
			canvas.draw_line(Vector2(x, WORLD.FLOOR_Y), Vector2(x, view.end.y), Color("987b61"), 3)
			x += 110
	canvas.draw_line(Vector2(view.position.x, 880), Vector2(view.end.x, 880), Color("695646"), 10)
	_window(canvas)
	_lamp(canvas, Vector2(570, 305))
	_lamp(canvas, Vector2(1320, 305))
	_picture(canvas, Rect2(312, 478, 142, 102))
	_clock(canvas, Vector2(1480, 480))
	_oval(canvas, Vector2(915, 943), Vector2(315, 31), Color("8eafa0"))
	_oval(canvas, Vector2(915, 943), Vector2(282, 24), Color("a7c2b1"))
	_oval(canvas, Vector2(1560, 911), Vector2(82, 15), Color("8eafa0"))

func _draw_furniture(canvas: Node2D) -> void:
	for key in ["crate_low", "crate_high"]: _crate(canvas, MOTION.SURFACES[key])
	_wardrobe(canvas)
	_sofa(canvas, MOTION.SURFACES["sofa"])
	_desk(canvas, MOTION.SURFACES["desk"])
	_shelf(canvas, MOTION.SURFACES["shelf_left"])
	_shelf(canvas, MOTION.SURFACES["shelf_right"])
	_bench(canvas, MOTION.SURFACES["bench"])
	_door(canvas)
	_plant(canvas, Vector2(170, 880), 1.0)
	_plant(canvas, Vector2(1132, 880), 0.85)

func _oval(canvas: Node2D, center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 48: points.append(center + Vector2(cos(i * TAU / 48), sin(i * TAU / 48)) * radius)
	canvas.draw_colored_polygon(points, color)

func _window(canvas: Node2D) -> void:
	var rect := Rect2(778, 420, 334, 246)
	canvas.draw_rect(rect.grow(-6), Color("78988b"), false, 12)
	canvas.draw_line(Vector2(945, 432), Vector2(945, 654), Color("eff0db"), 10)
	canvas.draw_line(Vector2(790, 544), Vector2(1100, 544), Color("eff0db"), 10)
	canvas.draw_rect(MOTION.SURFACES["window_ledge"], Color("a08460"))
	# Curtain panels leave the view open, with a hem and hanging rings.
	for side in [758.0, 1108.0]:
		canvas.draw_rect(Rect2(side, 426, 30, 220), Color("d9bc88"))
		canvas.draw_line(Vector2(side + 10, 432), Vector2(side + 10, 642), Color("b79a70"), 3)
	canvas.draw_line(Vector2(752, 415), Vector2(1146, 415), Color("806955"), 6)

func _lamp(canvas: Node2D, center: Vector2) -> void:
	canvas.draw_line(Vector2(center.x, minf(0, WORLD.visible_world(self).position.y)), center, Color("887b61"), 3)
	canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-18, 0), center + Vector2(18, 0), center + Vector2(36, 30), center + Vector2(-36, 30)]), Color("bd9c64"))
	_oval(canvas, center + Vector2(0, 30), Vector2(34, 7), Color("f2d991"))

func _picture(canvas: Node2D, rect: Rect2) -> void:
	canvas.draw_rect(rect, Color("9c7c59"))
	canvas.draw_rect(rect.grow(-7), Color("e8d6a6"))
	var center := rect.get_center()
	canvas.draw_colored_polygon(PackedVector2Array([rect.position + Vector2(8, 72), center + Vector2(-23, -12), center + Vector2(18, 24), center + Vector2(38, 6), rect.end - Vector2(8, 8), rect.position + Vector2(8, rect.size.y - 8)]), Color("83a38b"))

func _clock(canvas: Node2D, center: Vector2) -> void:
	canvas.draw_circle(center, 39, Color("9c7c59"))
	canvas.draw_circle(center, 32, Color("394c48"))
	var upper_half := PackedVector2Array([center])
	for point_index in range(33):
		var angle := PI + point_index * PI / 32.0
		upper_half.append(center + Vector2(cos(angle), sin(angle)) * 32)
	canvas.draw_colored_polygon(upper_half, Color("ffffff"))
	canvas.draw_line(center, center + Vector2(8, -24), Color("ad8b56"), 4, true)
	canvas.draw_circle(center, 4, Color("ad8b56"))
func _crate(canvas: Node2D, rect: Rect2) -> void:
	canvas.draw_rect(rect, Color("977651"))
	canvas.draw_rect(rect.grow(-5), Color("bb9564"))
	for y in range(int(rect.position.y) + 15, int(rect.end.y), 20):
		canvas.draw_line(Vector2(rect.position.x + 5, y), Vector2(rect.end.x - 5, y), Color("9f7e55"), 2)
	canvas.draw_line(rect.position + Vector2(8, 12), rect.end - Vector2(8, 8), Color("d1b27f"), 7)
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 9)), Color("d1b27f"))

func _wardrobe(canvas: Node2D) -> void:
	var rect: Rect2 = MOTION.OBJECT_BOUNDS["衣柜"]
	canvas.draw_rect(rect, Color("86674f"))
	canvas.draw_rect(rect.grow(-7), Color("b98e6b"))
	canvas.draw_line(Vector2(390, 730), Vector2(390, 871), Color("805f49"), 4)
	for x in [340, 400]: canvas.draw_rect(Rect2(x, 740, 40, 93), Color("c29b76"), false, 2)
	canvas.draw_circle(Vector2(380, 814), 4, Color("efcf83"))
	canvas.draw_circle(Vector2(400, 814), 4, Color("efcf83"))
	canvas.draw_rect(Rect2(MOTION.SURFACES["wardrobe"].position, Vector2(128, 10)), Color("b39068"))

func _sofa(canvas: Node2D, rect: Rect2) -> void:
	canvas.draw_style_box(_rounded(Color("728c78"), 13), Rect2(rect.position + Vector2(0, -40), Vector2(rect.size.x, 88)))
	canvas.draw_style_box(_rounded(Color("9bae91"), 8), Rect2(rect.position, Vector2(rect.size.x, 23)))
	for x in [rect.position.x + 8, rect.end.x - 18]: canvas.draw_rect(Rect2(x, rect.position.y + 48, 10, 28), Color("796549"))
	canvas.draw_line(rect.position + Vector2(rect.size.x * 0.5, 2), rect.position + Vector2(rect.size.x * 0.5, 20), Color("7c957c"), 2)
	canvas.draw_style_box(_rounded(Color("d2bd8a"), 5), Rect2(rect.position + Vector2(15, -30), Vector2(30, 28)))

func _desk(canvas: Node2D, rect: Rect2) -> void:
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 12)), Color("a18563"))
	for x in [rect.position.x + 9, rect.end.x - 18]: canvas.draw_rect(Rect2(x, rect.position.y + 12, 9, rect.size.y - 12), Color("846c54"))
	canvas.draw_rect(Rect2(950, 730, 60, 46), Color("34505b"))
	canvas.draw_rect(Rect2(956, 736, 48, 34), Color("8ee1cd"))
	canvas.draw_rect(Rect2(976, 776, 8, 16), Color("34505b"))
	canvas.draw_rect(Rect2(968, 786, 24, 6), Color("34505b"))
	canvas.draw_rect(Rect2(935, 788, 22, 4), Color("d1c4a6"))
	canvas.draw_rect(Rect2(1018, 778, 13, 14), Color("dfd1ab"))

func _shelf(canvas: Node2D, rect: Rect2) -> void:
	canvas.draw_rect(rect, Color("a08460"))
	for x in [rect.position.x + 14, rect.end.x - 23]:
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(x, rect.end.y), Vector2(x + 20, rect.end.y), Vector2(x, rect.end.y + 24)]), Color("7b6b51"))
	for i in 4:
		var height := 20 + (i % 3) * 5
		var color: Color = [Color("b68d68"), Color("899d7c"), Color("8aa9aa"), Color("d1b174")][i]
		canvas.draw_rect(Rect2(rect.position.x + 9 + i * 12, rect.position.y - height, 10, height), color)
		canvas.draw_line(Vector2(rect.position.x + 11 + i * 12, rect.position.y - 6), Vector2(rect.position.x + 16 + i * 12, rect.position.y - 6), Color("ebdec1"), 2)
	_plant(canvas, Vector2(rect.end.x - 20, rect.position.y), 0.36)

func _bench(canvas: Node2D, rect: Rect2) -> void:
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 12)), Color("ab8c63"))
	for x in [rect.position.x + 8, rect.end.x - 17]: canvas.draw_rect(Rect2(x, rect.position.y + 12, 9, rect.size.y - 12), Color("80694f"))
	canvas.draw_line(Vector2(rect.position.x + 9, 854), Vector2(rect.end.x - 9, 854), Color("987c59"), 7)

func _door(canvas: Node2D) -> void:
	var rect: Rect2 = MOTION.OBJECT_BOUNDS["门"]
	canvas.draw_rect(rect, Color("667d74"))
	canvas.draw_rect(rect.grow(-8), Color("99b6a5"))
	canvas.draw_rect(Rect2(1523, 711, 74, 53), Color("d3ead5"))
	canvas.draw_rect(Rect2(1523, 782, 74, 79), Color("8aa997"), false, 3)
	canvas.draw_circle(Vector2(1592, 797), 5, Color("ffe2a0"))

func _plant(canvas: Node2D, base: Vector2, factor: float) -> void:
	var leaf_color := Color("6c9773")
	for i in 5:
		var end := base + Vector2((i - 2) * 17, -48 - (2 - absi(i - 2)) * 12) * factor
		canvas.draw_line(base - Vector2(0, 19) * factor, end, Color("6b8763"), 3 * factor)
		_oval(canvas, end, Vector2(12, 20) * factor, leaf_color)
	canvas.draw_colored_polygon(PackedVector2Array([base + Vector2(-22, -27) * factor, base + Vector2(22, -27) * factor, base + Vector2(16, 0) * factor, base + Vector2(-16, 0) * factor]), Color("b08866"))
	canvas.draw_line(base + Vector2(-23, -27) * factor, base + Vector2(23, -27) * factor, Color("d0ad82"), 6 * factor)

func _rounded(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	return style

func _wall_region(canvas: Node2D, rect: Rect2, color: Color) -> void:
	var opening := rect.intersection(WINDOW_VIEW)
	if not opening.has_area():
		canvas.draw_rect(rect, color)
		return
	for piece in [Rect2(rect.position, Vector2(rect.size.x, opening.position.y - rect.position.y)), Rect2(rect.position.x, opening.end.y, rect.size.x, rect.end.y - opening.end.y), Rect2(rect.position.x, opening.position.y, opening.position.x - rect.position.x, opening.size.y), Rect2(opening.end.x, opening.position.y, rect.end.x - opening.end.x, opening.size.y)]:
		if piece.has_area(): canvas.draw_rect(piece, color)
