extends Node2D
const LAYERS = preload("res://ui/scene_layers.gd")
const SCENERY = preload("res://ui/outdoor_scenery.gd")
const WORLD = preload("res://core/world_layout.gd")
const LAYOUT = preload("res://core/backyard_layout.gd")
const ART = preload("res://ui/garden_art.gd")
var redraw_elapsed := 0.0

func _ready() -> void:
	LAYERS.install(self, _draw_layer)

func _process(delta: float) -> void:
	redraw_elapsed += delta
	if redraw_elapsed >= 0.5:
		redraw_elapsed = 0.0
		queue_redraw()

func _draw_layer(canvas: Node2D, depth: int) -> void:
	var view := WORLD.visible_world(self).grow(4)
	if depth == LAYERS.Depth.FAR:
		SCENERY.draw_landscape(canvas, view)
		return
	if depth == LAYERS.Depth.NEAR:
		_draw_garden(canvas)
		return
	canvas.draw_rect(Rect2(view.position.x, 780, view.size.x, maxf(300, view.end.y - 780)), Color("b8ca8e"))
	canvas.draw_rect(Rect2(view.position.x, 880, view.size.x, maxf(200, view.end.y - 880)), Color("a4b87c"))
	_fence(canvas, view)
	# Only the first tenth is the house interior; the doorway is walkable at floor level.
	canvas.draw_rect(Rect2(view.position.x, view.position.y, LAYOUT.DOOR_X - view.position.x, 880 - view.position.y), Color("f3ecd9"))
	canvas.draw_rect(Rect2(view.position.x, 578, LAYOUT.DOOR_X - view.position.x, 302), Color("c9d4be"))
	canvas.draw_rect(Rect2(view.position.x, 880, LAYOUT.DOOR_X - view.position.x, maxf(200, view.end.y - 880)), Color("b99874"))
	canvas.draw_line(Vector2(view.position.x, 880), Vector2(192, 880), Color("695646"), 10)
	canvas.draw_rect(Rect2(174, view.position.y, 36, 690 - view.position.y), Color("a98a6c"))
	for y in range(100, 690, 60):
		canvas.draw_line(Vector2(176, y), Vector2(208, y), Color("c6ae8b"), 3)
	canvas.draw_rect(Rect2(163, 678, 58, 15), Color("775f4c"))
	canvas.draw_line(Vector2(169, 690), Vector2(169, 880), Color("c6ac83"), 10)
	canvas.draw_line(Vector2(215, 690), Vector2(215, 880), Color("775f4c"), 7)
	# The leaf is swung open against the outside of the wall.
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(220, 697), Vector2(243, 709), Vector2(243, 870), Vector2(220, 881)]), Color("749680"))
	canvas.draw_line(Vector2(230, 717), Vector2(230, 863), Color("a1b697"), 3)
	canvas.draw_circle(Vector2(239, 800), 3, Color("ffe2a0"))
	canvas.draw_line(Vector2(160, 880), Vector2(224, 880), Color("d6bd8f"), 12)

func _draw_garden(canvas: Node2D) -> void:
	# Plants, plots and the seed cart belong to the near layer.
	for x in [550.0, 600.0, 1810.0, 1860.0]:
		canvas.draw_line(Vector2(x, 876), Vector2(x - 7, 837), Color("6f9256"), 3)
		for i in 5: canvas.draw_circle(Vector2(x - 7, 837) + Vector2.from_angle(i * TAU / 5) * 7, 6, Color("efcb89"))
		canvas.draw_circle(Vector2(x - 7, 837), 4, Color("c19154"))
	_shop(canvas)
	for index in LAYOUT.PLOTS.size(): _plot(canvas, index)

func _fence(canvas: Node2D, view: Rect2) -> void:
	for y in [748.0, 810.0]: canvas.draw_line(Vector2(220, y), Vector2(view.end.x, y), Color("cfb990"), 11)
	var x := 244.0
	while x < view.end.x:
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(x - 9, 836), Vector2(x - 9, 726), Vector2(x, 713), Vector2(x + 9, 726), Vector2(x + 9, 836)]), Color("e5d3a8"))
		x += 46

func _shop(canvas: Node2D) -> void:
	ART.ellipse(canvas, Vector2(415, 898), Vector2(110, 15), Color("91a16e"))
	# A plain wooden seed cart with a striped awning and open counter.
	for wheel_x in [360.0, 470.0]:
		canvas.draw_circle(Vector2(wheel_x, 871), 16, Color("655c48"))
		canvas.draw_circle(Vector2(wheel_x, 871), 9, Color("a38b67"))
		canvas.draw_circle(Vector2(wheel_x, 871), 3, Color("e0c797"))
	canvas.draw_rect(Rect2(336, 814, 158, 43), Color("977651"))
	canvas.draw_rect(Rect2(343, 820, 144, 30), Color("bd996c"))
	for seam_x in [378.0, 415.0, 452.0]:
		canvas.draw_line(Vector2(seam_x, 821), Vector2(seam_x, 848), Color("a9855c"), 2)
	canvas.draw_rect(Rect2(330, 804, 170, 12), Color("dfc392"))
	for post_x in [344.0, 486.0]:
		canvas.draw_rect(Rect2(post_x - 4, 711, 8, 93), Color("977959"))
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(327, 719), Vector2(349, 679), Vector2(481, 679), Vector2(503, 719)]), Color("739773"))
	for stripe_x in [350.0, 398.0, 446.0]:
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(stripe_x, 679), Vector2(stripe_x + 20, 679), Vector2(stripe_x + 25, 719), Vector2(stripe_x - 5, 719)]), Color("e6d9b6"))
	canvas.draw_rect(Rect2(327, 719, 176, 10), Color("739773"))
	for stripe_x in [345.0, 393.0, 441.0]:
		canvas.draw_rect(Rect2(stripe_x, 719, 30, 10), Color("e6d9b6"))
	canvas.draw_line(Vector2(494, 831), Vector2(519, 811), Color("977651"), 7, true)
func _plot(canvas: Node2D, index: int) -> void:
	var x: float = LAYOUT.PLOTS[index]
	ART.ellipse(canvas, Vector2(x, 919), Vector2(91, 16), Color("93a571"))
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(x - 74, 872), Vector2(x + 74, 872), Vector2(x + 86, 918), Vector2(x - 86, 918)]), Color("8a694e"))
	for y in [883, 896, 910]: canvas.draw_line(Vector2(x - 66, y), Vector2(x + 67, y), Color("a08058"), 4)
	canvas.draw_line(Vector2(x - 80, 921), Vector2(x + 82, 921), Color("c2a075"), 8)
	var entry: Dictionary = GardenSave.plots[index]
	if not entry.is_empty():
		var progress := GardenSave.growth(index)
		ART.plant(canvas, str(entry["plant"]), Vector2(x, 882), 0.88, progress)
		if progress >= 1.0:
			var star := Vector2(x + 55, 802)
			canvas.draw_line(star - Vector2(0, 8), star + Vector2(0, 8), Color("fff3ae"), 3, true)
			canvas.draw_line(star - Vector2(8, 0), star + Vector2(8, 0), Color("fff3ae"), 3, true)
