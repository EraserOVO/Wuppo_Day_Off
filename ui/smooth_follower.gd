extends Node2D

const FOLLOW_MIN_SPEED := 68.0
const FOLLOW_MAX_SPEED := 1240.0
const FOLLOW_ACCELERATION := 4400.0
const FOLLOW_EASE_DISTANCE := 240.0
var follow_target := Vector2.ZERO
var follow_velocity := Vector2.ZERO
var follow_initialized := false

func set_follow_target(target: Vector2, snap := false) -> void:
	follow_target = target
	if snap or not follow_initialized:
		global_position = target
		follow_velocity = Vector2.ZERO
		follow_initialized = true

func _process(delta: float) -> void:
	if not follow_initialized: return
	var offset := follow_target - global_position
	var distance := offset.length()
	if distance <= 1.0:
		follow_velocity = Vector2.ZERO
		return
	var ease_ratio := clampf(distance / FOLLOW_EASE_DISTANCE, 0.0, 1.0)
	var eased_distance := ease_ratio * ease_ratio * (3.0 - 2.0 * ease_ratio)
	var desired_speed := lerpf(FOLLOW_MIN_SPEED, FOLLOW_MAX_SPEED, eased_distance)
	var desired_velocity := offset.normalized() * minf(desired_speed, distance / maxf(delta, 0.001))
	follow_velocity = follow_velocity.move_toward(desired_velocity, FOLLOW_ACCELERATION * delta)
	global_position += follow_velocity * delta
