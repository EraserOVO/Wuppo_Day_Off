extends Node2D
const LAYERS = preload("res://ui/scene_layers.gd")
const SCENERY = preload("res://ui/outdoor_scenery.gd")
const WORLD = preload("res://core/world_layout.gd")
const MOTION = preload("res://core/player_motion.gd")
var time := 0.0

func _ready() -> void:
	LAYERS.install(self, _draw_layer)

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw_layer(canvas: Node2D, depth: int) -> void:
	var view := WORLD.visible_world(self).grow(8)
	if depth == LAYERS.Depth.FAR:
		canvas.draw_rect(view, Color("65dbe2"))
		SCENERY.draw_clouds(canvas, view)
		return
	if depth == LAYERS.Depth.NEAR:
		for deck in MOTION.PLATFORMS: _deck(canvas, deck)
		_torch(canvas, Vector2(340, 730), 85)
		_torch(canvas, Vector2(1160, 650), 95)
		_torch(canvas, Vector2(1598, 730), 80)
		return
	canvas.draw_rect(Rect2(view.position.x, 852, view.size.x, maxf(0, view.end.y - 852)), Color("54aaba"))
	for i in range(18):
		var x := view.position.x + i * view.size.x / 17.0
		canvas.draw_line(Vector2(x, 878 + sin(i * 1.8 + time) * 3), Vector2(x + 48, 878 + sin(i * 1.8 + time) * 3), Color("98ddd7"), 3)
	_palm(canvas, Vector2(1630, MOTION.ground_height(1630) + 22), 495, 1.0)
	_palm(canvas, Vector2(235, MOTION.ground_height(235) + 30), 280, -0.75)
	_bush(canvas, Vector2(660, 865), 145)
	_bush(canvas, Vector2(1270, 871), 110)
	var ground := PackedVector2Array()
	var ridge := PackedVector2Array()
	var steps := maxi(2, ceili(view.size.x / 10))
	for i in range(steps + 1):
		var x := lerpf(view.position.x, view.end.x, float(i) / steps)
		var point := Vector2(x, MOTION.ground_height(x))
		ground.append(point)
		ridge.append(point)
	ground.append(Vector2(view.end.x, maxf(1000, view.end.y)))
	ground.append(Vector2(view.position.x, maxf(1000, view.end.y)))
	canvas.draw_colored_polygon(ground, Color("dca535"))
	canvas.draw_polyline(ridge, Color("f4cf58"), 20, true)
	for i in range(125):
		var x := fposmod(i * 193.0 + 41, view.size.x) + view.position.x
		var y := MOTION.ground_height(x) + 26 + fposmod(i * 73.0, 140)
		canvas.draw_rect(Rect2(x, y, 4 + i % 5, 3 + i % 3), Color("eabd48") if i % 3 else Color("bf892b"))
	# Sea foreground stays below every playable surface.
	var sea := PackedVector2Array()
	for i in range(steps + 1):
		var x := lerpf(view.position.x, view.end.x, float(i) / steps)
		sea.append(Vector2(x, 973 + sin(x * 0.028 + time * 1.2) * 4 + sin(x * 0.061 - time) * 2))
	var foam := sea.duplicate()
	sea.append(Vector2(view.end.x, maxf(view.end.y, 1000)))
	sea.append(Vector2(view.position.x, maxf(view.end.y, 1000)))
	canvas.draw_colored_polygon(sea, Color("5b9fc6"))
	canvas.draw_polyline(foam, Color("e1f8ed"), 6, true)
	for i in range(24):
		var x := view.position.x + fposmod(i * 239.0 + time * 12, view.size.x)
		var y := 1002 + i % 5 * 36
		if y < view.end.y: canvas.draw_line(Vector2(x, y), Vector2(x + 28 + i % 4 * 14, y), Color("79b9d7"), 3)

func _deck(canvas: Node2D, rect: Rect2) -> void:
	var top := rect.position.y
	for x in [rect.position.x + 24, rect.end.x - 30]:
		var bottom := MOTION.ground_height(x) + 16
		canvas.draw_rect(Rect2(x, top + 12, 17, bottom - top), Color("775539"))
		canvas.draw_line(Vector2(x + 4, top + 24), Vector2(x + 4, bottom), Color("a77c4e"), 4)
	canvas.draw_line(Vector2(rect.position.x + 32, MOTION.ground_height(rect.position.x + 32)), Vector2(rect.end.x - 32, top + 22), Color("775539"), 12)
	canvas.draw_line(Vector2(rect.position.x + 32, top + 20), Vector2(rect.end.x - 32, MOTION.ground_height(rect.end.x - 32)), Color("775539"), 12)
	canvas.draw_rect(Rect2(rect.position + Vector2(-6, 0), rect.size + Vector2(12, 0)), Color("6b4a33"))
	var count := ceili(rect.size.x / 46)
	for i in range(count):
		var x := rect.position.x + i * rect.size.x / count
		var width := rect.size.x / count - 3
		canvas.draw_rect(Rect2(x, top, width, 15), Color("b38a59") if i % 3 else Color("c29a65"))
		canvas.draw_line(Vector2(x + 5, top + 10), Vector2(x + width - 5, top + 10), Color("987044"), 2)
		canvas.draw_circle(Vector2(x + 6, top + 5), 1.7, Color("624631"))

func _bush(canvas: Node2D, base: Vector2, size: float) -> void:
	for i in range(7):
		var center := base + Vector2((i - 3) * size * 0.23, -size * (0.25 + 0.18 * sin(i * 2.1)))
		canvas.draw_circle(center, size * 0.38, Color("3d7550"))
		canvas.draw_arc(center, size * 0.34, PI, TAU - 0.3, 12, Color("71a95b"), 9, true)
		if i % 2: canvas.draw_circle(center + Vector2(14, -5), 4, Color("6581ae"))

func _palm(canvas: Node2D, base: Vector2, height: float, lean: float) -> void:
	var trunk := PackedVector2Array()
	for i in range(13):
		var t := float(i) / 12
		trunk.append(base + Vector2(sin(t * 2.2) * 48 * lean, -height * t))
	canvas.draw_polyline(trunk, Color("866645"), 38, true)
	canvas.draw_polyline(trunk, Color("b69b68"), 25, true)
	for i in range(1, 12): canvas.draw_line(trunk[i] + Vector2(-12, 7), trunk[i] + Vector2(12, -1), Color("957b51"), 5)
	var crown := trunk[-1]
	for i in range(7):
		var direction := -2.95 + i * 0.45
		var length := height * (0.38 + 0.08 * sin(i * 1.9))
		var tip := crown + Vector2(cos(direction) * length, sin(direction) * length + 48)
		var axis := tip - crown
		var bend := Vector2(-axis.y, axis.x).normalized() * axis.length() * 0.18
		var mid := crown.lerp(tip, 0.5) + bend
		var leaf := PackedVector2Array([crown])
		var rib := PackedVector2Array()
		var underside := PackedVector2Array()
		for segment in range(19):
			var t := segment / 18.0
			var point := crown * pow(1 - t, 2) + mid * 2 * (1 - t) * t + tip * t * t
			var tangent := ((mid - crown) * (1 - t) + (tip - mid) * t).normalized()
			var normal := Vector2(-tangent.y, tangent.x)
			var width := sin(PI * t) * height * 0.07
			if segment > 0 and segment < 18:
				leaf.append(point + normal * width)
				underside.append(point - normal * width)
			rib.append(point)
		leaf.append(tip)
		underside.reverse()
		leaf.append_array(underside)
		canvas.draw_colored_polygon(leaf, Color("397d46") if i % 2 else Color("4d9450"))
		canvas.draw_polyline(rib, Color("79b45b"), 4, true)
	canvas.draw_circle(crown + Vector2(-9, 12), 13, Color("7d6941"))
	canvas.draw_circle(crown + Vector2(13, 8), 10, Color("947d47"))

func _torch(canvas: Node2D, base: Vector2, height: float) -> void:
	var head := base - Vector2(0, height)
	canvas.draw_line(base, head, Color("654c36"), 9)
	canvas.draw_line(base + Vector2(-2, 0), head + Vector2(-2, 0), Color("a78956"), 3)
	canvas.draw_rect(Rect2(head - Vector2(9, 7), Vector2(18, 12)), Color("765b37"))
	var sway := sin(time * 7 + base.x) * 4
	var flame := PackedVector2Array([head + Vector2(-10, -7), head + Vector2(-12, -24), head + Vector2(sway, -58), head + Vector2(14, -27), head + Vector2(9, -8)])
	canvas.draw_colored_polygon(flame, Color("f69236"))
	canvas.draw_colored_polygon(PackedVector2Array([head + Vector2(-5, -9), head + Vector2(sway * 0.5, -39), head + Vector2(7, -12)]), Color("ffe17b"))
