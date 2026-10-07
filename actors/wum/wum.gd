extends Node2D

@export var skin: WuppoCharacterSkin
@export var hat: WuppoCharacterHat
@export var player_tint: Color = Color.WHITE
@export var always_show_tube := false
var is_local_player := false
var mouse_gaze_enabled := false
var warning_enabled := true
const EFFECT = preload("res://actors/bubble/bubble_effect.tscn")
const RULES = preload("res://modes/bubble_race/bubble_rules.gd")
const MOTION = preload("res://core/player_motion.gd")
var last_event := 0
var effect_animation := ""
var effect_time := 0.0
var winner := false
var shown_ratio := 0.0
var target_ratio := 0.0
var current_state := "idle"
var visual_time := 0.0
var hop_elapsed := 1.0
var state_age := 0.0
var bubble_limit := 1.8
var warning_level := 0
var warning_thresholds := Vector3(0.5, 0.72, 0.88)
var target_position := Vector2.ZERO
var has_position := false
var externally_positioned := false
var whistle_time := 0.0
var bubble_tremble_time := 0.0
var bubble_tremble_elapsed := 0.0
var bubble_tremble_strength := 0.0
const BUBBLE_TREMBLE_DURATION := 0.24
var double_jump_spin := 0.0
var double_jump_spin_direction := 1.0
static var texture_visible_bounds: Dictionary = {}
var facing_direction := 1
var walk_motion := 0.0
var walk_phase := 0.0
var walk_grounded := true
var crouching := false
var charge_rate := 1.0
var has_motion_sample := false
var previous_motion_airborne := false
const CONFIG = preload("res://modes/bubble_race/bubble_config.tres")
const TUBE_LENGTH := 36.0
const CHARGE_TONE_START_RATIO := 0.1

func _ready() -> void:
	apply_skin()
	apply_hat()
	$ScoreLabel.visible = false

func apply_skin() -> void:
	if skin == null: return
	$Visual.sprite_frames = skin.animations
	$Visual.scale = skin.visual_scale
	$Visual.position = skin.visual_offset
	$Visual.modulate = player_tint * skin.body_tint
	$CrouchVisual.fill_color = Color("f4e3bb") * player_tint * skin.body_tint
	$Bubble.texture = skin.bubble_texture
	$Bubble.position = skin.bubble_offset
	_play("idle")

func apply_hat() -> void:
	if not is_instance_valid($Hat): return
	if hat == null or hat.texture == null:
		$Hat.visible = false
		return
	$Hat.texture = hat.texture
	$Hat.position = hat.offset
	$Hat.scale = hat.scale
	$Hat.modulate = hat.tint
	$Hat.visible = true

func set_player_name(value: String) -> void:
	$NameLabel.text = value

func head_position() -> Vector2:
	var top := global_position.y
	if crouching:
		top = minf(top, ($CrouchVisual.global_transform * Vector2(0, -14)).y)
	var frames: SpriteFrames = $Visual.sprite_frames
	if not crouching and frames != null and frames.has_animation($Visual.animation):
		var texture := frames.get_frame_texture($Visual.animation, $Visual.frame)
		if texture != null:
			var half := texture.get_size() * 0.5
			for corner in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(-half.x, half.y), half]:
				top = minf(top, ($Visual.global_transform * corner).y)
	if $Hat.visible and $Hat.texture != null:
		var rect: Rect2 = $Hat.get_rect()
		for corner in [rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), rect.end]:
			top = minf(top, ($Hat.global_transform * corner).y)
	return Vector2(global_position.x, top)

# The carry contact follows visible pixels, with the same pivot as body and hat.
func held_item_pose() -> Transform2D:
	var anchor: Vector2
	var angle: float = $Visual.rotation
	if $Hat.visible and $Hat.texture != null:
		var bounds := _visible_texture_rect($Hat.texture)
		var point: Vector2 = Vector2(bounds.get_center().x, bounds.position.y) - $Hat.texture.get_size() * 0.5
		if $Hat.flip_h: point.x = -point.x
		anchor = $Hat.transform * point
		angle = $Hat.rotation
	elif crouching:
		anchor = $CrouchVisual.transform * Vector2(0, -14)
	else:
		var texture: Texture2D = $Visual.sprite_frames.get_frame_texture($Visual.animation, $Visual.frame)
		var bounds := _visible_texture_rect(texture)
		anchor = $Visual.transform * Vector2(0, bounds.position.y - texture.get_size().y * 0.5)
	return Transform2D(angle, anchor)

static func _visible_texture_rect(texture: Texture2D) -> Rect2:
	var key := texture.get_instance_id()
	if not texture_visible_bounds.has(key):
		var image := texture.get_image()
		texture_visible_bounds[key] = Rect2(image.get_used_rect()) if image != null else Rect2(Vector2.ZERO, texture.get_size())
	return texture_visible_bounds[key]

func _exit_tree() -> void:
	AudioManager.update_charge_tone(get_instance_id(), 0.0, false, global_position)

func set_facing_direction(direction: float) -> void:
	if absf(direction) < 0.01: return
	facing_direction = -1 if direction < 0.0 else 1
	$Visual.flip_h = facing_direction < 0
	$Visual/Feet.scale.x = float(facing_direction)
	$Hat.flip_h = facing_direction < 0
	_sync_crouch_visual()

func set_walking(direction: float, grounded := true) -> void:
	walk_motion = 0.0 if crouching else clampf(direction, -1.0, 1.0)
	walk_grounded = grounded

func set_crouching(value: bool) -> void:
	crouching = value and walk_grounded
	$Visual.visible = not crouching
	$Visual/Feet.visible = not crouching
	$CrouchVisual.visible = crouching
	if crouching: walk_motion = 0.0

	_sync_crouch_visual()

func _sync_crouch_visual() -> void:
	if skin == null: return
	$CrouchVisual.position = Vector2($Visual.position.x, -$CrouchVisual.BOTTOM * skin.visual_scale.y)
	$CrouchVisual.scale = Vector2(absf(skin.visual_scale.x) * float(facing_direction), skin.visual_scale.y)
	$CrouchVisual.rotation = 0.0
	$CrouchVisual.fill_color = Color("f4e3bb") * player_tint * skin.body_tint

func update_state(data: Dictionary, warm: float, danger := 0.72, critical := 0.88) -> void:
	if int(data.get("event_id", 0)) < last_event: return
	var velocity_y := float(data.get("velocity_y", 0.0))
	var motion_airborne := int(data.get("jumps", 0)) > 0 or absf(velocity_y) > 0.5
	walk_grounded = bool(data.get("grounded", not motion_airborne)) and not motion_airborne
	set_crouching(bool(data.get("crouching", false)))
	charge_rate = float(data.get("charge_rate", CONFIG.crouch_blow_rate if crouching else 1.0))
	if has_motion_sample and previous_motion_airborne and not motion_airborne:
		AudioManager.play_positional_cue("land", data.get("position", global_position), null, 0.28)
	previous_motion_airborne = motion_airborne
	has_motion_sample = true
	if data.has("position"):
		target_position = data["position"]
		if not has_position: position = target_position
		has_position = true
	var previous := current_state
	current_state = str(data.get("state", "idle"))
	var horizontal_velocity := float(data.get("velocity_x", int(data.get("move", 0)) * MOTION.CONFIG.move_speed))
	set_walking(horizontal_velocity / maxf(1.0, MOTION.CONFIG.move_speed), not motion_airborne)
	if not is_local_player and int(data.get("move", 0)) != 0:
		set_facing_direction(float(data["move"]))
	bubble_limit = maxf(0.1, float(data.get("limit", 1.8)))
	target_ratio = float(data.get("ratio", 0.0)) + float(data.get("presentation_age", 0.0)) * charge_rate / bubble_limit if current_state == "blowing" else 0.0
	state_age = 0.0
	warning_thresholds = Vector3(warm, danger, critical)
	if current_state != "blowing" or previous != "blowing":
		warning_level = 0
	$ScoreLabel.text = GameSettings.text("%s 分 · 最大 %s" % [data.get("score", 0), data.get("best", 0)])
	$Bubble.visible = current_state == "blowing"

func _play(animation: String) -> void:
	var frames: SpriteFrames = $Visual.sprite_frames
	if frames == null: return
	if not frames.has_animation(animation):
		animation = "warning" if animation in ["danger", "critical"] and frames.has_animation("warning") else "idle"
	if frames.has_animation(animation) and $Visual.animation != animation: $Visual.play(animation)
	elif not $Visual.is_playing() and frames.has_animation(animation) and frames.get_animation_loop(animation): $Visual.play(animation)

func _process(delta: float) -> void:
	if skin == null: return
	if mouse_gaze_enabled:
		var pointer_direction: Vector2 = $Visual.to_local(get_global_mouse_position())
		$Visual/Eyes.gaze = pointer_direction.normalized() if pointer_direction.length_squared() > 0.001 else Vector2.ZERO
		var crouch_pointer: Vector2 = $CrouchVisual.to_local(get_global_mouse_position())
		$CrouchVisual/Eyes.gaze = crouch_pointer.normalized() if crouch_pointer.length_squared() > 0.001 else Vector2.ZERO
	else:
		$Visual/Eyes.gaze = Vector2.ZERO
		$CrouchVisual/Eyes.gaze = Vector2.ZERO
	visual_time += delta
	if walk_grounded and absf(walk_motion) > 0.05: walk_phase += delta * 15.0 * absf(walk_motion)
	$Visual/Feet.phase = walk_phase
	$Visual/Feet.stride = walk_motion if walk_grounded else 0.0
	$Visual/Feet.queue_redraw()
	if has_position and not externally_positioned: position = position.lerp(target_position, 1.0 - exp(-25.0 * delta))
	whistle_time = maxf(0.0, whistle_time - delta)
	bubble_tremble_time = maxf(0.0, bubble_tremble_time - delta)
	if bubble_tremble_time > 0.0: bubble_tremble_elapsed += delta
	double_jump_spin = maxf(0.0, double_jump_spin - delta)
	var spin_progress := 1.0 - double_jump_spin / maxf(0.01, MOTION.CONFIG.double_jump_spin_duration)
	var spin_angle := double_jump_spin_direction * TAU * spin_progress if double_jump_spin > 0.0 and not crouching else 0.0
	$Visual.rotation = spin_angle
	$Hat.rotation = spin_angle
	var bubble_jitter := Vector2.ZERO
	var bubble_tremble_rotation := 0.0
	if bubble_tremble_time > 0.0 and $Bubble.visible:
		var tremble_fade := bubble_tremble_time / BUBBLE_TREMBLE_DURATION
		var tremble_phase := bubble_tremble_elapsed * TAU * 10.0
		bubble_jitter = Vector2(sin(tremble_phase) * 3.5, sin(tremble_phase * 0.73) * 2.4) * tremble_fade * bubble_tremble_strength
		bubble_tremble_rotation = sin(tremble_phase) * 0.10 * tremble_fade * bubble_tremble_strength
	$Bubble.rotation = spin_angle + bubble_tremble_rotation
	queue_redraw()
	state_age += delta
	hop_elapsed += delta
	effect_time = maxf(0.0, effect_time - delta)
	var progress := target_ratio
	if current_state == "blowing" and warning_enabled:
		# Extrapolate presentation between authoritative snapshots; never decide a burst here.
		progress = clampf(target_ratio + minf(state_age, 0.15) * charge_rate / bubble_limit, 0.0, 1.0)
		var stage: int = RULES.warning_stage(progress, warning_thresholds.x, warning_thresholds.y, warning_thresholds.z)
		if stage > warning_level:
			warning_level = stage
	else:
		warning_level = 0
	AudioManager.update_charge_tone(get_instance_id(), progress, is_local_player and current_state == "blowing" and warning_enabled and progress >= CHARGE_TONE_START_RATIO, global_position)
	var animation := "idle"
	if current_state == "blowing": animation = ["blow", "warning", "danger", "critical"][warning_level]
	elif current_state == "burst": animation = "burst"
	if winner: _play("celebrate")
	elif effect_time > 0.0: _play(effect_animation)
	else: _play(animation)
	shown_ratio = lerpf(shown_ratio, progress, 1.0 - exp(-22.0 * delta))
	var size := lerpf(20.0, skin.bubble_max_size, shown_ratio)
	var pulse := 1.0 + sin(visual_time * (8.0 + warning_level * 8.0)) * warning_level * 0.015
	if $Bubble.texture != null:
		$Bubble.scale = Vector2.ONE * size * pulse / maxf(1.0, float($Bubble.texture.get_width()))
	$Bubble.modulate = [Color.WHITE, Color(1, 0.95, 0.7), Color(1, 0.7, 0.55), Color(1, 0.45, 0.5)][warning_level]
	if current_state == "blowing" and progress >= CONFIG.perfect_bubble_ratio:
		$Bubble.modulate = Color(1.0, 0.88, 0.12)
	elif warning_level == 3:
		$Bubble.modulate = $Bubble.modulate.lerp(Color.WHITE, (sin(visual_time * 26.0) + 1.0) * 0.35)
	if bubble_tremble_time > 0.0 and $Bubble.visible:
		var tint_fade := bubble_tremble_time / BUBBLE_TREMBLE_DURATION
		var tint_phase := bubble_tremble_elapsed * TAU * 5.0
		var tint_amount := 0.14 * bubble_tremble_strength * tint_fade * (0.5 + 0.5 * sin(tint_phase))
		$Bubble.modulate = $Bubble.modulate.lerp(Color("e5fff0"), tint_amount)
	$Visual.position = Vector2(skin.visual_offset.x * facing_direction, skin.visual_offset.y)
	if current_state == "blowing": $Visual.position.x += sin(visual_time * (16.0 + warning_level * 9.0)) * warning_level * 1.2
	var hop_progress := clampf(hop_elapsed / maxf(0.01, skin.release_hop_duration), 0.0, 1.0)
	var hop_offset := Vector2(0.0, -sin(PI * hop_progress) * skin.release_hop_height)
	$Visual.position += hop_offset
	_sync_crouch_visual()
	var body_center: Vector2 = $Visual.position
	if hat != null and $Hat.visible:
		var hat_position := Vector2(hat.offset.x * facing_direction, hat.offset.y + (17.0 if crouching else 0.0)) + (Vector2.ZERO if crouching else hop_offset)
		$Hat.position = body_center + (hat_position - body_center).rotated(spin_angle)
	$Bubble.position = bubble_origin(size * pulse) + bubble_jitter

# The mouth sits at (24, 11) relative to the current sprite's centre.
# Keep the bubble tangent to the cone outlet, including flip, hop and spin.
func tube_point(distance: float, vertical: float = 0.0) -> Vector2:
	var mouth := skin.mouth_offset * skin.visual_scale
	var origin: Vector2 = $CrouchVisual.position if crouching else $Visual.position
	return origin + Vector2((mouth.x + distance) * facing_direction, mouth.y + vertical).rotated($Visual.rotation)

func bubble_origin(diameter: float) -> Vector2:
	return tube_point(TUBE_LENGTH + diameter * 0.5 - 2.0)

func play_event(data: Dictionary) -> void:
	var event_id := int(data.get("event_id", 0))
	if event_id <= last_event or skin == null: return
	last_event = event_id
	var kind := str(data.get("kind", "release"))
	var event_position: Vector2 = data.get("position", global_position)
	if data.has("position") and not externally_positioned:
		target_position = data["position"]
		position = target_position
		has_position = true
	if kind == "whistle":
		whistle_time = 0.35
		AudioManager.play_positional_cue("whistle", event_position, null, 0.48)
		if int(data.get("kills", 0)) > 0:
			AudioManager.play_positional_cue("finish", event_position)
		return
	if kind == "whistle_hit":
		whistle_time = 0.35
		if $Bubble.visible:
			bubble_tremble_time = BUBBLE_TREMBLE_DURATION
			bubble_tremble_elapsed = 0.0
			bubble_tremble_strength = clampf(float(data.get("points", 0)) / maxf(1.0, CONFIG.whistle_charge_near * 100.0), 0.0, 1.0)
		return
	if kind == "whistle_score": return
	if kind == "jump":
		AudioManager.play_positional_cue("jump", event_position, null, 0.38)
		return
	if kind == "double_jump":
		trigger_double_jump(float(data.get("spin_direction", 1.0)), event_position)
		return
	if kind == "release": hop_elapsed = 0.0
	current_state = "burst" if kind == "burst" else "idle"
	warning_level = 0
	$Bubble.visible = false
	var effect = EFFECT.instantiate()
	effect.kind = kind
	effect.texture = skin.bubble_texture
	effect.size = lerpf(20.0, skin.bubble_max_size, float(data.get("ratio", 0.0)))
	effect.points = int(data.get("points", 0))
	effect.perfect = bool(data.get("perfect", false))
	effect.cause = str(data.get("cause", ""))
	var source_peer := int(data.get("peer_id", 0))
	effect.effect_seed = abs(source_peer) * 1000003 + event_id + (1000000007 if source_peer < 0 else 0)
	effect.horizontal_direction = float(facing_direction)
	effect.scale = scale
	effect.position = event_position + bubble_origin(effect.size) * scale
	get_parent().add_child(effect)
	effect_animation = "burst" if kind == "burst" else "release"
	effect_time = 0.4
	_play(effect_animation)
	$Visual.frame = 0
	if kind != "release":
		AudioManager.play_positional_cue(kind, event_position)
	if effect.perfect:
		AudioManager.play_positional_cue("perfect", event_position, null, 0.9)

func trigger_double_jump(direction: float, event_position: Vector2, audible: bool = true) -> void:
	double_jump_spin = MOTION.CONFIG.double_jump_spin_duration
	double_jump_spin_direction = -1.0 if direction < 0.0 else 1.0
	if audible: AudioManager.play_positional_cue("double_jump", event_position, null, 0.42)

func celebrate(value: bool) -> void:
	winner = value
	if value: _play("celebrate")

func _draw() -> void:
	if skin != null and (always_show_tube or current_state == "blowing" or (effect_animation == "release" and effect_time > 0.0)):
		var cone := PackedVector2Array([tube_point(0, -3), tube_point(TUBE_LENGTH, -11), tube_point(TUBE_LENGTH, 11), tube_point(0, 3)])
		draw_colored_polygon(cone, Color("a8844e"))
		cone.append(cone[0])
		draw_polyline(cone, Color("574a36"), 3, true)
		draw_line(tube_point(4, -1), tube_point(TUBE_LENGTH - 3, -7), Color("ddc18b"), 3, true)
		draw_line(tube_point(TUBE_LENGTH, -11), tube_point(TUBE_LENGTH, 11), Color("4c4533"), 5, true)


