extends SceneTree
const MOTION = preload("res://core/lobby_motion.gd")
const WORLD = preload("res://core/world_layout.gd")
const TEST_PATH := "res://.godot/garden_smoke.json"

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		quit(1)
		assert(ok, message)

func _write(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "Cannot write isolated test save")
	file.store_string(content)
	file.close()

func _clean() -> void:
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(TEST_PATH + suffix): DirAccess.remove_absolute(TEST_PATH + suffix)

func _run() -> void:
	var garden = root.get_node("GardenSave")
	_clean()
	garden.save_path = TEST_PATH
	garden.load_save()
	_check(garden.smurt == 60 and garden.plots.size() == 6, "New save needs a usable wallet and six plots")
	_check(garden.buy_seed("blueberry").is_empty(), "Cannot buy blueberry seed")
	_check(garden.smurt == 48 and garden.seeds["blueberry"] == 1, "Purchase did not debit exactly once")
	_check(not garden.buy_seed("blueberry", 99).is_empty() and garden.smurt == 48, "Insufficient balance must not debit")
	_check(not garden.buy_seed("unknown").is_empty() and not garden.buy_seed("onion", -1).is_empty(), "Invalid purchases must be rejected")
	_check(garden.plant_seed(0, "blueberry").is_empty() and garden.seeds["blueberry"] == 0, "Planting must consume one seed")
	_check(not garden.plant_seed(0, "onion").is_empty() and not garden.harvest(0).is_empty(), "Occupied/immature plots must reject action")
	garden.plots[0]["planted_at"] = Time.get_unix_time_from_system() - 181
	_check(garden.save(), "Offline timestamp could not save")
	garden.load_save()
	_check(garden.smurt == 48 and garden.growth(0) == 1.0, "Restart must restore wallet and offline growth")
	_check(garden.harvest(0).is_empty() and garden.produce["blueberry"] == 1, "Mature harvest missing")
	_check(not garden.harvest(0).is_empty(), "Repeated harvest must not duplicate produce")
	_check(garden.sell("blueberry").is_empty() and garden.smurt == 76, "Blueberry sale payout incorrect")
	_check(not garden.sell("blueberry").is_empty(), "Empty inventory must not pay twice")
	_check(garden.buy_seed("onion").is_empty() and garden.plant_seed(1, "onion").is_empty(), "Onion cycle failed")
	garden.plots[1]["planted_at"] = Time.get_unix_time_from_system() - 91
	_check(garden.save() and garden.harvest(1).is_empty() and garden.sell("onion").is_empty(), "Onion harvest/sale failed")
	_check(garden.smurt == 84, "Two crop cycles must result in expected profit")
	garden.load_save()
	_check(garden.smurt == 84 and garden.plots[1].is_empty(), "Sold crops/wallet not persisted")
	var backup: Dictionary = garden._read_save(TEST_PATH + ".bak")
	_write(TEST_PATH, "{broken")
	garden.load_save()
	_check(garden.recovered_backup and garden.smurt == int(backup["smurt"]), "Corrupt primary must recover backup")
	_check(garden.buy_seed("onion").is_empty() and not garden._read_save(TEST_PATH + ".bak").is_empty(), "Recovery must preserve valid backup on next transaction")
	_write(TEST_PATH, "{broken")
	_write(TEST_PATH + ".bak", "{broken")
	garden.load_save()
	_check(not garden.writable and not garden.buy_seed("onion").is_empty(), "Corrupt saves must be preserved without spending")
	_check(FileAccess.get_file_as_string(TEST_PATH) == "{broken", "Corrupt save was overwritten")
	_clean()
	garden.load_save()
	garden.save_path = "res://.godot/garden_missing_parent/save.json"
	_check(not garden.buy_seed("onion").is_empty() and garden.smurt == 60 and garden.seeds["onion"] == 0, "Failed disk write must roll back wallet/inventory")
	garden.save_path = TEST_PATH
	garden.load_save()
	var state := {"position": Vector2(1919, 780), "move": 1, "velocity_x": 460.0, "velocity_y": -100.0, "jumps": 1}
	MOTION.step(state, 1.0 / 60)
	_check(state.get("lobby_area") == "backyard" and state["position"] == Vector2(12, 880) and state["jumps"] == 0, "Right edge must enter backyard left edge with safe grounded state")
	state["position"] = Vector2(1, 880)
	state["move"] = -1
	state["velocity_x"] = -460.0
	MOTION.step(state, 1.0 / 60)
	_check(state["lobby_area"] == "room" and state["position"] == Vector2(1908, 880), "Left backyard edge must return to right room edge")
	state.merge({"lobby_area": "backyard", "position": Vector2(160, 880), "move": 1, "velocity_x": 460.0}, true)
	for _i in 12: MOTION.step(state, 1.0 / 60)
	_check(state["position"].x > 216, "Grounded player cannot walk through door")
	state.merge({"position": Vector2(165, 500), "move": 1, "velocity_x": 460.0, "velocity_y": -100.0}, true)
	for _i in 12: MOTION.step(state, 1.0 / 60)
	_check(state["position"].x <= 168, "Player jumped through upper wall")
	state.merge({"position": Vector2(192, 751), "move": 0, "velocity_x": 0.0, "velocity_y": -860.0}, true)
	MOTION.step(state, 1.0 / 60)
	_check(state["position"].y >= 750 and state["velocity_y"] >= 0, "Jumping inside door must hit lintel")
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu.states[1].merge({"lobby_area": "backyard", "position": Vector2(415, 880)}, true)
	menu._process(0.0)
	_check(menu.room_layers["backyard"].visible and not menu.room_layers["room"].visible and menu.actors[1].get_parent() == menu.backyard, "Local scene view did not follow player")
	_check(menu._nearby(1) == "种子摊", "Seed shop interaction missing")
	menu._open("种子摊", 1)
	var bought := false
	for button in menu.modal.find_children("*", "Button", true, false):
		if button.text == "购买 1 份种子 · 12 斯马特":
			button.pressed.emit()
			bought = true
			break
	_check(bought and garden.smurt == 48 and garden.seeds["blueberry"] == 1, "Shop button did not buy/persist seed")
	menu._close()
	menu.states[1]["position"] = Vector2(720, 880)
	_check(menu._nearby(1) == "种植地 1", "Plot interaction missing")
	menu._open("种植地 1", 1)
	for button in menu.modal.find_children("*", "Button", true, false):
		if button.text == "种下紫色大蓝莓":
			button.pressed.emit()
			break
	_check(not garden.plots[0].is_empty() and menu.garden_growth_label != null, "Planting button did not enter growth state")
	garden.plots[0]["planted_at"] = Time.get_unix_time_from_system() - 181
	menu._process(0.0)
	_check(menu.garden_growth_label == null, "Maturity must refresh open plot controls")
	menu._close()
	menu._change_mode(1)
	menu.states[2]["lobby_area"] = "room"
	menu._process(0.0)
	_check(menu.room_layers["room"].visible and menu.room_layers["backyard"].visible, "Separated local duo needs both scenes")
	_check(is_equal_approx(menu.room_layers["room"].size.x, menu.size.x * 0.5), "Split scene width incorrect")
	for dimensions in [Vector2i(1920, 1080), Vector2i(2560, 1080), Vector2i(900, 1600)]:
		root.size = dimensions
		await process_frame
		await process_frame
		for scene in [menu.room, menu.backyard]:
			var visible := WORLD.visible_world(scene)
			_check(visible.size.x >= 1920 - 1 and visible.size.y >= 1080 - 1, "Split screen cropped playable world")
			_check(is_equal_approx(scene.scale.x, scene.scale.y), "Split screen stretched scene")
	menu.queue_free()
	await process_frame
	_clean()
	print("GARDEN PASSED: transactions, rollback, growth after restart, backups, edge travel, doorway, shop/plot UI and local split view")
	quit(0)
