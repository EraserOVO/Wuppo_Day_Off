extends SceneTree

const SCENERY = preload("res://ui/outdoor_scenery.gd")
const MOTION = preload("res://core/player_motion.gd")
const GARDEN = preload("res://core/backyard_layout.gd")
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _layers(scene: Node) -> void:
	_check(scene.has_node("FarLayer") and scene.has_node("MiddleLayer") and scene.has_node("NearLayer"), "Scene must contain three actual drawing layers")
	_check(scene.get_node("FarLayer").z_index < scene.get_node("MiddleLayer").z_index and scene.get_node("MiddleLayer").z_index < scene.get_node("NearLayer").z_index, "Scenery depth order is incorrect")

func _capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/previews/" + filename)

func _run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var garden = root.get_node("GardenSave")
	garden.save_path = "res://.godot/scenery_carry_save.json"
	garden.load_save()
	garden.seeds = {"blueberry": 5, "onion": 5}
	garden.produce = {"blueberry": 2, "onion": 1}
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu.set_physics_process(false)
	_layers(menu.room)
	_layers(menu.backyard)
	_check(not menu.has_method("_show_toast"), "Bottom subtitle messages must be removed")
	for index in SCENERY.CLOUDS.size():
		_check(SCENERY.cloud_position(index, 1).x < SCENERY.cloud_position(index, 0).x, "Every cloud must drift left")
	menu.states[1]["position"] = Vector2(1450, 880)
	var actor = menu.actors[1]
	actor.position = menu.states[1]["position"]
	actor.hat = null
	actor.apply_hat()
	menu.selected_item = "produce:blueberry"
	menu._sync_held_visuals()
	var carried = menu.held_visuals["lobby:1"]
	actor.set_process(false)
	actor._process(0)
	carried._process(0)
	var standing_y: float = carried.position.y
	_check(standing_y > -85 and standing_y < -60, "Carry contact must use visible body contour, excluding texture padding")
	await _capture("scenery_room.png")
	actor.walk_grounded = true
	actor.set_crouching(true)
	actor._process(0)
	carried._process(0)
	_check(carried.position.y > standing_y + 15, "Carry contact must descend with crouching body")
	actor.set_crouching(false)
	actor.walk_grounded = false
	actor.trigger_double_jump(1, actor.global_position, false)
	actor._process(MOTION.CONFIG.double_jump_spin_duration * 0.25)
	carried._process(0)
	_check(is_equal_approx(carried.rotation, PI * 0.5), "Item must rotate by a quarter turn with the Wum")
	_check(carried.position.x > 25, "Item contact must orbit the body pivot during the spin")
	await _capture("carry_spin.png")
	actor.double_jump_spin = 0
	actor.hat = menu.HATS.hats[3]
	actor.apply_hat()
	actor._process(0)
	carried._process(0)
	_check(carried.position.y < standing_y - 25, "Equipped hat must support the carried item above its crown")
	actor.trigger_double_jump(-1, actor.global_position, false)
	actor._process(MOTION.CONFIG.double_jump_spin_duration * 0.25)
	carried._process(0)
	_check(is_equal_approx(carried.rotation, -PI * 0.5) and carried.position.x < -25, "Item must orbit the hat in the opposite spin direction")
	actor.double_jump_spin = 0
	actor._process(0)
	menu.states[1]["lobby_area"] = "backyard"
	menu.states[1]["position"] = Vector2(GARDEN.PLOTS[0], 880)
	actor.position = menu.states[1]["position"]
	menu._process(0)
	menu.selected_item = "seed:blueberry"
	menu._interact_with_plot(1, 0)
	_check(not garden.plots[0].is_empty(), "Planting must still work without subtitles")
	garden.plots[0]["planted_at"] = Time.get_unix_time_from_system() - 2000
	menu._interact_with_plot(1, 0)
	_check(garden.plots[0].is_empty(), "Mature crops must still harvest without subtitles")
	menu.selected_item = "produce:onion"
	menu._sync_held_visuals()
	carried._process(0)
	await _capture("scenery_backyard.png")
	actor.set_process(true)
	var session = root.get_node("NetworkSession")
	for game in ["bubble_race", "mud_ball"]:
		session.game_mode = game
		menu._launch()
		await create_timer(2.3).timeout
		_check(is_instance_valid(menu.match_view), "Match must still launch after scenery split")
		if is_instance_valid(menu.match_view):
			_layers(menu.match_view.get_node("Background") if game == "bubble_race" else menu.match_view)
			await _capture("scenery_" + game + ".png")
		await session.leave()
		await process_frame
	print("SCENERY_AND_CARRY_CHECKS: " + ("PASS" if failures == 0 else "FAIL"))
	menu.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
