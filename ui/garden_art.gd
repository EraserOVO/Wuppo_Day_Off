extends RefCounted

static func ellipse(canvas: CanvasItem, center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 40: points.append(center + Vector2(cos(i * TAU / 40), sin(i * TAU / 40)) * radius)
	canvas.draw_colored_polygon(points, color)

static func coin(canvas: CanvasItem, center: Vector2, radius: float) -> void:
	canvas.draw_circle(center + Vector2(0, radius * 0.12), radius, Color("98662c"))
	canvas.draw_circle(center, radius, Color("e9ac3e"))
	canvas.draw_arc(center, radius * 0.82, 0, TAU, 64, Color("ffe095"), radius * 0.22, true)
	canvas.draw_circle(center, radius * 0.63, Color("efbd54"))
	canvas.draw_arc(center, radius * 0.62, 0.25, PI, 32, Color("bc802f"), radius * 0.07, true)
	canvas.draw_arc(center, radius * 0.9, PI + 0.15, TAU - 0.4, 32, Color("fff1b7"), radius * 0.065, true)
	# A small embossed sprout identifies the local currency without tiny text.
	canvas.draw_line(center + Vector2(0, radius * 0.34), center + Vector2(0, -radius * 0.2), Color("b67c2f"), radius * 0.1, true)
	ellipse(canvas, center + Vector2(-radius * 0.16, -radius * 0.12), Vector2(radius * 0.2, radius * 0.1), Color("b67c2f"))
	ellipse(canvas, center + Vector2(radius * 0.16, -radius * 0.22), Vector2(radius * 0.2, radius * 0.1), Color("fff0ad"))

static func dye_bubble(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	canvas.draw_circle(center + Vector2(0, radius * 0.1), radius, Color(0.12, 0.2, 0.2, 0.48))
	canvas.draw_circle(center, radius * 0.94, color.darkened(0.32))
	canvas.draw_circle(center, radius * 0.82, color)
	canvas.draw_arc(center, radius * 0.78, 0, TAU, 48, Color(1, 1, 1, 0.72), maxf(2, radius * 0.1), true)
	ellipse(canvas, center + Vector2(-radius * 0.3, -radius * 0.34), Vector2(radius * 0.24, radius * 0.13), Color(1, 1, 1, 0.86))
	ellipse(canvas, center + Vector2(radius * 0.29, radius * 0.29), Vector2(radius * 0.12, radius * 0.07), Color(1, 1, 1, 0.5))

# All garden visuals share bottom-center anchors, including the printed packet art.
static func seed(canvas: CanvasItem, id: String, base: Vector2, factor: float = 1.0) -> void:
	var outline := PackedVector2Array()
	for point in [Vector2(-22, 0), Vector2(-24, -54), Vector2(-18, -64), Vector2(18, -64), Vector2(24, -54), Vector2(22, 0)]:
		outline.append(base + point * factor)
	canvas.draw_colored_polygon(outline, Color("987650"))
	var paper := PackedVector2Array()
	for point in [Vector2(-20, -2), Vector2(-22, -53), Vector2(-17, -62), Vector2(17, -62), Vector2(22, -53), Vector2(20, -2)]:
		paper.append(base + point * factor)
	canvas.draw_colored_polygon(paper, Color("e5c994"))
	canvas.draw_rect(Rect2(base + Vector2(-19, -54) * factor, Vector2(38, 7) * factor), Color("c5a473"))
	canvas.draw_line(base + Vector2(-17, -56) * factor, base + Vector2(17, -56) * factor, Color("f3dfb3"), 2 * factor, true)
	canvas.draw_rect(Rect2(base + Vector2(-17, -43) * factor, Vector2(34, 35) * factor), Color("f5e7c8"))
	produce(canvas, id, base + Vector2(0, -11) * factor, factor * 0.27)
	canvas.draw_line(base + Vector2(-16, -5) * factor, base + Vector2(16, -5) * factor, Color("bc9766"), factor, true)

static func plant(canvas: CanvasItem, id: String, base: Vector2, factor: float = 1.0, growth: float = 1.0) -> void:
	var progress := clampf(growth, 0.0, 1.0)
	if id == "blueberry":
		var bush_scale := factor * lerpf(0.38, 1.0, progress)
		# Dense foliage stays close to the soil, instead of berries on bare tripod stems.
		canvas.draw_line(base, base + Vector2(0, -40) * bush_scale, Color("68784d"), 7 * bush_scale, true)
		for side in [-1.0, 1.0]:
			canvas.draw_line(base + Vector2(0, -9) * bush_scale, base + Vector2(side * 27, -39) * bush_scale, Color("68784d"), 4 * bush_scale, true)
		for offset in [Vector2(-25, -28), Vector2(25, -28), Vector2(-28, -48), Vector2(28, -48), Vector2(-13, -65), Vector2(13, -65), Vector2(0, -42)]:
			ellipse(canvas, base + offset * bush_scale, Vector2(20, 15) * bush_scale, Color("648451"))
			ellipse(canvas, base + (offset + Vector2(-2, -4)) * bush_scale, Vector2(17, 11) * bush_scale, Color("89a66b"))
		var fruit_growth := clampf((progress - 0.25) / 0.75, 0.0, 1.0)
		if fruit_growth > 0:
			# The central berry becomes the single oversized ripe fruit.
			var fruit_radius := lerpf(4, 32, fruit_growth)
			_berry(canvas, base + Vector2(0, -37) * bush_scale, fruit_radius * bush_scale)
			if progress < 0.85:
				for side in [-1.0, 1.0]:
					_berry(canvas, base + Vector2(side * 27, -43) * bush_scale, 6 * bush_scale * minf(1.0, fruit_growth * 4) * clampf((0.85 - progress) / 0.15, 0.0, 1.0))
			_leaf(canvas, base + Vector2(0, -37 - fruit_radius) * bush_scale, Vector2(-20, -8) * bush_scale, 7 * bush_scale, Color("547d48"))
			_leaf(canvas, base + Vector2(0, -37 - fruit_radius) * bush_scale, Vector2(19, -11) * bush_scale, 7 * bush_scale, Color("88ad61"))
	else:
		var leaf_scale := factor * lerpf(0.22, 1.0, progress)
		# The planted bulb remains underground; only a green shoulder emerges late.
		if progress > 0.7:
			var reveal := (progress - 0.7) / 0.3
			ellipse(canvas, base + Vector2(0, -6 * reveal) * factor, Vector2(24, 6 * reveal) * factor, Color("638c4d"))
			ellipse(canvas, base + Vector2(-2, -7 * reveal) * factor, Vector2(20, 4 * reveal) * factor, Color("a9c778"))
		_onion_leaves(canvas, base + Vector2(0, -7) * leaf_scale, leaf_scale)

static func produce(canvas: CanvasItem, id: String, base: Vector2, factor: float = 1.0) -> void:
	if id == "blueberry":
		_berry(canvas, base + Vector2(0, -40) * factor, 39 * factor)
		var crown := base + Vector2(0, -77) * factor
		_leaf(canvas, crown, Vector2(-29, -16) * factor, 11 * factor, Color("5c844b"))
		_leaf(canvas, crown, Vector2(27, -22) * factor, 10 * factor, Color("8bad63"))
		_leaf(canvas, crown, Vector2(2, -29) * factor, 7 * factor, Color("739a54"))
	else:
		# One continuous green bulb: no garlic lobes or dividing seams.
		ellipse(canvas, base + Vector2(0, -27) * factor, Vector2(33, 27) * factor, Color("567c48"))
		ellipse(canvas, base + Vector2(0, -29) * factor, Vector2(30, 25) * factor, Color("a5c577"))
		ellipse(canvas, base + Vector2(5, -24) * factor, Vector2(22, 19) * factor, Color("bad68b"))
		ellipse(canvas, base + Vector2(-14, -36) * factor, Vector2(7, 5) * factor, Color("d6e6a8"))
		_onion_leaves(canvas, base + Vector2(0, -48) * factor, factor * 0.62)

static func _berry(canvas: CanvasItem, center: Vector2, radius: float) -> void:
	canvas.draw_circle(center, radius, Color("51416f"))
	canvas.draw_circle(center + Vector2(0, -0.035) * radius, radius * 0.93, Color("8261ad"))
	ellipse(canvas, center + Vector2(0.15, 0.16) * radius, Vector2(0.7, 0.66) * radius, Color("9472bd"))
	ellipse(canvas, center + Vector2(-0.32, -0.35) * radius, Vector2(0.24, 0.15) * radius, Color("c4a5dd"))
	var blossom := PackedVector2Array()
	for i in 10:
		blossom.append(center + Vector2(0.06, 0.52) * radius + Vector2.from_angle(-PI * 0.5 + i * TAU / 10) * radius * (0.17 if i % 2 == 0 else 0.075))
	canvas.draw_colored_polygon(blossom, Color("624781"))

static func _onion_leaves(canvas: CanvasItem, crown: Vector2, factor: float) -> void:
	var tips := [Vector2(-40, -62), Vector2(37, -72), Vector2(-25, -94), Vector2(22, -105), Vector2(-5, -111)]
	for i in tips.size():
		_leaf(canvas, crown + Vector2((i - 2) * 2, 0) * factor, tips[i] * factor, (10 if i < 2 else 9) * factor, Color("5f874c") if i % 2 == 0 else Color("86aa59"))

static func _leaf(canvas: CanvasItem, root: Vector2, direction: Vector2, width: float, color: Color) -> void:
	var points := PackedVector2Array()
	var underside := PackedVector2Array()
	var rib := PackedVector2Array()
	var normal := Vector2(-direction.y, direction.x).normalized()
	for i in 17:
		var t := i / 16.0
		var center := root + direction * t + normal * sin(t * PI) * width * 0.45
		var half_width := sin(PI * t) * width
		points.append(center + normal * half_width)
		underside.append(center - normal * half_width)
		rib.append(center)
	underside.reverse()
	points.append_array(underside)
	canvas.draw_colored_polygon(points, color)
	canvas.draw_polyline(rib, color.lightened(0.22), maxf(0.6, width * 0.14), true)
