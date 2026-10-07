extends Node2D

const ART = preload("res://ui/garden_art.gd")
const PLANTS = preload("res://data/plant_catalog.gd")
const SKINS = preload("res://assets/characters/skin_catalog.tres")

var item_key := ""
var dye_color := Color.WHITE
var avatar_size := 96.0

func _process(_delta: float) -> void:
	if visible and get_parent().has_method("held_item_pose"):
		transform = get_parent().held_item_pose()

func set_item(value: String, character_size := 96.0) -> void:
	item_key = value
	avatar_size = maxf(1.0, character_size)
	if value.begins_with("dye:"):
		var skin_id := int(value.get_slice(":", 1))
		if skin_id >= 0 and skin_id < SKINS.skins.size(): dye_color = SKINS.skins[skin_id].body_tint
	visible = not value.is_empty()
	queue_redraw()

func _draw() -> void:
	if item_key.is_empty(): return
	var item_size := avatar_size * 0.8
	if item_key == "currency:smurt":
		ART.coin(self, Vector2(0, -item_size * 0.56), item_size * 0.5)
	elif item_key.begins_with("dye:"):
		ART.dye_bubble(self, Vector2(0, -item_size * 0.55), item_size * 0.5, dye_color)
	else:
		var plant_id := item_key.get_slice(":", 1)
		if PLANTS.PLANTS.has(plant_id):
			var is_seed := item_key.begins_with("seed:")
			var source_size := Vector2(48, 64) if is_seed else Vector2(88, 112)
			# Seeds use their actual icon size; harvested plants scale to a readable carry size.
			var factor := 1.0 if is_seed else item_size / maxf(source_size.x, source_size.y)
			if is_seed: ART.seed(self, plant_id, Vector2.ZERO, factor)
			else: ART.produce(self, plant_id, Vector2.ZERO, factor)
