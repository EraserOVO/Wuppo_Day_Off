extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var garden = root.get_node("GardenSave")
	# A unique probe next to the real save; never read/write the player's garden file.
	var probe := "user://garden_storage_probe_%s.json" % OS.get_process_id()
	garden.save_path = probe
	garden.load_save()
	# Seed a test wallet; production saves correctly start with zero currency.
	garden.smurt = 60
	var error: String = garden.buy_seed("onion")
	if not error.is_empty():
		push_error("Actual user directory cannot save: " + error)
		quit(1)
		return
	garden.load_save()
	var passed: bool = garden.smurt == 54 and garden.seeds["onion"] == 1
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(probe + suffix): DirAccess.remove_absolute(probe + suffix)
	if not passed:
		push_error("Actual user directory save did not reload")
		quit(1)
		return
	print("USER DIRECTORY PASSED: persistent wallet and seed inventory in " + OS.get_user_data_dir())
	quit(0)
