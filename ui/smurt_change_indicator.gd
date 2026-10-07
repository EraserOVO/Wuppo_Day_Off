extends "res://ui/smooth_follower.gd"

const ART = preload("res://ui/garden_art.gd")

var amount_text := ""
var time_left := 0.0
var opacity := 0.0

func show_change(current_balance: int) -> void:
	amount_text = str(current_balance)
	time_left = 3.5
	opacity = 1.0
	modulate = Color(1, 1, 1, opacity)
	scale = Vector2.ONE * 0.72
	visible = true
	queue_redraw()

func _process(delta: float) -> void:
	super._process(delta)
	if time_left <= 0.0: return
	time_left = maxf(0.0, time_left - delta)
	var fade_start := 0.5
	opacity = clampf(time_left / fade_start, 0.0, 1.0)
	modulate = Color(1, 1, 1, opacity)
	scale = scale.lerp(Vector2.ONE, 1.0 - exp(-9.0 * delta))
	if time_left == 0.0: visible = false
	queue_redraw()

func _draw() -> void:
	if opacity <= 0.0: return
	ART.coin(self, Vector2.ZERO, 31)
	var font := ThemeDB.fallback_font
	if font == null: return
	var font_size := 19 if amount_text.length() <= 4 else 16
	var width := font.get_string_size(amount_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
	draw_string_outline(font, Vector2(-width * 0.5, 7), amount_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0.17, 0.21, 0.19, opacity))
	draw_string(font, Vector2(-width * 0.5, 7), amount_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
