class_name BubbleRaceConfig
extends Resource

@export_range(1.0, 10.0) var countdown: float = 3.0
@export_range(0.5, 4.0) var bubble_seconds_min: float = 1.5
@export_range(0.5, 4.0) var bubble_seconds_max: float = 4.0
@export_range(0.1, 0.95) var warning_ratio: float = 0.5
@export_range(0.1, 0.99) var danger_ratio: float = 0.72
@export_range(0.1, 0.99) var critical_ratio: float = 0.88
@export_range(1.0, 100.0) var points_per_second: float = 10.0
@export_range(0.1, 1.0) var minimum_hold: float = 0.3
@export var whistle_radius: float = 560.0
@export_range(0.0, 1.0) var whistle_charge_near: float = 0.132
@export_range(0.0, 1.0) var whistle_charge_far: float = 0.036
@export_range(1.0, 3.0) var whistle_reward_multiplier: float = 1.2
@export var whistle_cooldown: float = 0.5
@export_range(0.1, 1.0) var crouch_blow_rate: float = 0.7
@export_range(0.0, 1.0) var crouch_whistle_multiplier: float = 0.6
@export_range(0.5, 1.0) var perfect_bubble_ratio: float = 0.92
@export var perfect_bubble_bonus: float = 2.0

