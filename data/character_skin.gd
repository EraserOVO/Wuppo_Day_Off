class_name WuppoCharacterSkin
extends Resource

@export var display_name: String = "占位角色"
@export var animations: SpriteFrames
@export var visual_scale: Vector2 = Vector2.ONE
@export var visual_offset: Vector2 = Vector2(0, -42)
@export var mouth_offset: Vector2 = Vector2(24, 11)
@export var bubble_offset: Vector2 = Vector2(44, -56)
@export var bubble_texture: Texture2D
@export var body_tint: Color = Color.WHITE
@export var release_sound: AudioStream
@export var burst_sound: AudioStream
@export var victory_sound: AudioStream
@export_range(16.0, 200.0) var bubble_max_size: float = 108.0
@export_range(0.0, 40.0) var release_hop_height: float = 14.0
@export_range(0.1, 0.5) var release_hop_duration: float = 0.18
