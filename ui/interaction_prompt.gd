extends "res://ui/smooth_follower.gd"

var code := KEY_K
var caption: Label
var key_style: StyleBoxFlat
var key_width := 48.0
var target_name := ""
var displayed_language := ""

func _ready() -> void:
	key_style = StyleBoxFlat.new()
	key_style.bg_color = Color("253b3d")
	key_style.border_color = Color("d2eee3")
	key_style.set_border_width_all(2)
	key_style.set_corner_radius_all(12)
	caption = Label.new()
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 22)
	add_child(caption)
	set_key(code)

func set_key(value: int) -> void:
	set_target(value, "")

func set_target(value: int, name: String) -> void:
	var changed := code != value or target_name != name or displayed_language != GameSettings.language or not is_instance_valid(caption) or caption.text.is_empty()
	code = value
	target_name = name
	if not is_instance_valid(caption): return
	if not changed: return
	caption.text = GameSettings.key_name(code)
	if code == -1: caption.text = GameSettings.text("左键")
	elif code == -2: caption.text = GameSettings.text("右键")
	if not target_name.is_empty(): caption.text = GameSettings.text(target_name)
	displayed_language = GameSettings.language
	caption.add_theme_color_override("font_color", Color("253b3d") if code < 0 else Color.WHITE)
	caption.add_theme_font_size_override("font_size", 18 if not target_name.is_empty() else 22)
	key_width = clampf(caption.text.length() * 15.0 + 22, 48, 160)
	if target_name.is_empty():
		caption.position = Vector2(-55, 27) if code < 0 else Vector2(-key_width * 0.5, -24)
		caption.size = Vector2(110, 34) if code < 0 else Vector2(key_width, 48)
	else:
		caption.position = Vector2(-key_width * 0.5, 27 if code < 0 else 34)
		caption.size = Vector2(key_width, 34)
	queue_redraw()

func _draw() -> void:
	if key_style == null: return
	if code < 0:
		draw_style_box(key_style, Rect2(-23, -33, 46, 62))
		if code == -1: draw_rect(Rect2(-19, -26, 17, 23), Color("8ee1cd"))
		elif code == -2: draw_rect(Rect2(2, -26, 17, 23), Color("8ee1cd"))
		else: draw_circle(Vector2(0, -15), 5, Color("8ee1cd"))
		draw_line(Vector2(0, -30), Vector2(0, -3), Color("d2eee3"), 2)
		draw_line(Vector2(-21, -2), Vector2(21, -2), Color("d2eee3"), 2)
	else:
		draw_style_box(key_style, Rect2(-key_width * 0.5, -28, key_width, 56))
