extends Node2D

var kind := "release"
var texture: Texture2D
var size := 64.0
var points := 0
var perfect := false
var cause := ""
var horizontal_direction := 1.0
var effect_seed := 1
var elapsed := 0.0
var lifetime := 1.6
var flight_origin := Vector2.ZERO
var piece_flights: Array[Dictionary] = []
var lifetime_tween: Tween

const RELEASE_HORIZONTAL_SPEED := 50.0
const RELEASE_UPWARD_SPEED := 55.0
const RELEASE_UPWARD_ACCELERATION := 55.0
const SCREEN_EXIT_MARGIN := 96.0

func _ready() -> void:
	flight_origin = position
	$Image.texture = texture
	if texture != null: $Image.scale = Vector2.ONE * size / maxf(1.0, float(texture.get_width()))
	if kind == "release":
		$Points.visible = false
	if kind == "burst":
		_play_bubble_split()
		$Points.visible = false
		return
	if perfect:
		$Image.modulate = Color(1.0, 0.88, 0.12)
	lifetime_tween = create_tween().set_parallel(true)
	if kind == "release":
		lifetime_tween.tween_property($Image, "rotation", 0.2, lifetime)
	else:
		lifetime_tween.tween_property($Points, "position:y", $Points.position.y - 35, lifetime)

func whistle_pop(source_position: Vector2, radius: float) -> void:
	if kind != "release": return
	if global_position.distance_to(source_position) > radius: return
	if is_instance_valid(lifetime_tween): lifetime_tween.kill()
	kind = "burst"
	cause = "whistle"
	modulate.a = 1.0
	$Points.visible = false
	_play_bubble_split(source_position)

func _process(delta: float) -> void:
	if kind == "release":
		elapsed += delta
		var t := elapsed
		var upward_distance := RELEASE_UPWARD_SPEED * t + 0.5 * RELEASE_UPWARD_ACCELERATION * t * t
		position = flight_origin + Vector2(horizontal_direction * RELEASE_HORIZONTAL_SPEED * t, -upward_distance) * scale
		if not _inside_screen(global_position): queue_free()
	elif kind == "burst":
		for index in piece_flights.size():
			var flight: Dictionary = piece_flights[index]
			var age := float(flight["elapsed"]) + delta
			var bubble: Sprite2D = flight["bubble"]
			bubble.position = flight["velocity"] * age + 0.5 * flight["acceleration"] * age * age
			flight["elapsed"] = age
			piece_flights[index] = flight

func _inside_screen(point: Vector2) -> bool:
	var screen_point := get_canvas_transform() * point
	return get_viewport_rect().grow(SCREEN_EXIT_MARGIN).has_point(screen_point)

func _play_bubble_split(source_position: Vector2 = Vector2.ZERO) -> void:
	var original_scale: Vector2 = $Image.scale
	var pop := create_tween().set_parallel(true)
	pop.tween_property($Image, "scale", original_scale * 0.08, 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	pop.tween_property($Image, "modulate:a", 0.0, 0.1)
	pop.chain().tween_callback($Image.hide)
	if cause == "whistle":
		_play_whistle_bubbles(original_scale, source_position)
		var cleanup := create_tween()
		cleanup.tween_interval(2.05)
		cleanup.tween_callback(queue_free)
	else:
		pop.tween_callback(queue_free)

func _play_whistle_bubbles(original_scale: Vector2, source_position: Vector2) -> void:
	if texture == null: return
	var rng := RandomNumberGenerator.new()
	rng.seed = maxi(1, effect_seed)
	var piece_count := rng.randi_range(2, 4)
	var outward := global_position - source_position
	if outward.length_squared() < 0.001:
		outward = Vector2(horizontal_direction, -0.5)
	outward = outward.normalized()
	for index in piece_count:
		var bubble := Sprite2D.new()
		bubble.texture = texture
		bubble.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		bubble.position = Vector2.ZERO
		bubble.scale = original_scale * 0.035
		bubble.modulate = Color(1.0, 0.88, 0.12, 0.0) if perfect else Color(1.0, 1.0, 1.0, 0.0)
		add_child(bubble)
		var direction := outward.rotated(rng.randf_range(-0.58, 0.58))
		var velocity := direction * rng.randf_range(82.0, 138.0)
		var acceleration := direction * rng.randf_range(10.0, 24.0) + Vector2(0.0, -12.0)
		piece_flights.append({
			"bubble": bubble,
			"elapsed": 0.0,
			"velocity": velocity,
			"acceleration": acceleration
		})
		var target_scale: Vector2 = original_scale * rng.randf_range(0.2, 0.5)
		var grow := create_tween()
		grow.tween_property(bubble, "scale", target_scale, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var appear := create_tween()
		appear.tween_property(bubble, "modulate:a", 1.0, 0.08)
		var fade := create_tween()
		fade.tween_interval(rng.randf_range(1.2, 1.45))
		fade.tween_property(bubble, "modulate:a", 0.0, 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

