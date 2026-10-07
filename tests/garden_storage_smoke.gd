extends Node

var failures: Array[String] = []
var base := "user://storage_regression_%s" % OS.get_process_id()
var garden

func _ready() -> void:
	if OS.get_name() == "Windows":
		var app_data := OS.get_environment("APPDATA").get_base_dir()
		base = app_data.path_join("LocalLow").path_join("Wuppo_Day_Off").path_join("storage_regression_%s" % OS.get_process_id())
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _write(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "Cannot create test fixture: " + path)
	if file != null:
		file.store_string(content)
		file.close()

func _use(path: String) -> void:
	garden.save_path = path
	garden.legacy_save_path = ""
	garden.load_save()
	garden.smurt = 100

func _remove_tree(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null: return
	for filename in directory.get_files(): DirAccess.remove_absolute(path.path_join(filename))
	for child in directory.get_directories(): _remove_tree(path.path_join(child))
	DirAccess.remove_absolute(path)

func _run() -> void:
	garden = get_node("/root/GardenSave")
	if OS.get_name() == "Windows":
		var app_data := OS.get_environment("APPDATA").get_base_dir()
		var expected := app_data.path_join("LocalLow").path_join("Wuppo_Day_Off").path_join("garden_save.json")
		_check(garden.save_path == expected, "Windows saves must use the low-integrity writable LocalLow folder")
		_check(garden.legacy_save_path == "user://garden_save.json", "Windows must keep the former user:// location as a migration source")

	# Existing Roaming AppData saves migrate on the first successful transaction.
	var migration_legacy := base + "/migration/legacy.json"
	var migration_target := base + "/migration/LocalLow/garden.json"
	_use(migration_legacy)
	_check(garden.save_profile(1, "Migration", 3, 0).is_empty(), "Migration fixture must be created")
	_check(garden.buy_seed("onion").is_empty(), "Migration fixture must contain inventory")
	var legacy_snapshot := FileAccess.get_file_as_string(migration_legacy)
	garden.save_path = migration_target
	garden.legacy_save_path = migration_legacy
	garden.load_save()
	_check(garden.smurt == 94 and garden.seeds["onion"] == 1 and garden.profiles[1]["name"] == "Migration", "Legacy save must load when LocalLow has no save")
	_check(not FileAccess.file_exists(migration_target), "Loading a legacy save alone must not alter either copy")
	_check(garden.buy_seed("blueberry").is_empty(), "First post-migration transaction must save to LocalLow")
	_check(FileAccess.file_exists(migration_target) and FileAccess.get_file_as_string(migration_legacy) == legacy_snapshot, "Migration must create the new save and preserve the old file")
	_write(migration_target, "{new save is corrupt")
	garden.load_save()
	_check(not garden.writable and garden.storage_error_path == ProjectSettings.globalize_path(migration_target), "A corrupt new save must not be replaced by an older legacy copy")
	_check(FileAccess.get_file_as_string(migration_target) == "{new save is corrupt" and FileAccess.get_file_as_string(migration_legacy) == legacy_snapshot, "Both migration copies must be preserved after a corrupt target")

	var path := base + "/nested/garden.json"
	_use(path)
	_check(garden.save_profile(1, "Storage probe", 2, 0).is_empty(), "First save must create missing directories")
	_check(garden.buy_seed("onion").is_empty(), "Purchase must persist")
	garden.load_save()
	_check(garden.smurt == 94 and garden.seeds["onion"] == 1 and garden.profiles[1]["name"] == "Storage probe", "Restart must restore wallet, inventory and profile")
	_check(not garden.has_profile(2), "A missing saved profile must not be mistaken for persisted defaults")
	_check(garden.buy_seed("blueberry").is_empty(), "Second purchase must persist")
	_check(int(garden._read_save(path + ".bak")["smurt"]) == 94, "Backup must contain the previous valid state")

	# A stale/locked legacy temporary path must not be used by new transactions.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path + ".tmp"))
	_check(garden.buy_seed("onion").is_empty(), "Legacy .tmp obstruction must not block saving")
	_check(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path + ".tmp")), "Do not delete another process's temporary path")

	var backup_text := FileAccess.get_file_as_string(path + ".bak")
	_write(path, "{broken")
	garden.load_save()
	_check(garden.recovered_backup and garden.writable, "Corrupt primary must recover the backup")
	_check(garden.buy_seed("onion").is_empty(), "Recovered save must allow a new transaction")
	_check(FileAccess.get_file_as_string(path + ".bak") == backup_text, "Recovery must preserve its valid backup")

	# Genuine filesystem failures must roll back spending and inventory changes.
	var obstruction := base + "/blocked-parent"
	_write(obstruction, "parent is a file")
	_use(obstruction + "/garden.json")
	_check(not garden.buy_seed("onion").is_empty(), "Unwritable parent must reject the purchase")
	_check(garden.smurt == 100 and garden.seeds["onion"] == 0, "Failed creation must not debit or grant items")
	_check(garden.storage_error_code != OK and not garden.storage_error_path.is_empty(), "Failure must expose its real error code and save location")
	DirAccess.remove_absolute(obstruction)
	_check(garden.buy_seed("onion").is_empty(), "A corrected path must allow retry without restarting")
	_check(garden.storage_error.is_empty() and garden.storage_error_path.is_empty() and garden.storage_error_code == OK, "Success must clear the previous failure")

	var backup_path := base + "/backup/garden.json"
	_use(backup_path)
	_check(garden.save(), "Backup test initialization failed")
	var original := FileAccess.get_file_as_string(backup_path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(backup_path + ".bak"))
	_check(not garden.buy_seed("onion").is_empty(), "Blocked backup replacement must reject purchase")
	_check(garden.smurt == 100 and garden.seeds["onion"] == 0 and FileAccess.get_file_as_string(backup_path) == original, "Backup failure must preserve the primary and roll back the purchase")

	var replace_path := base + "/replace/garden.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(replace_path))
	_use(replace_path)
	_check(not garden.buy_seed("onion").is_empty(), "Blocked primary replacement must reject purchase")
	_check(garden.smurt == 100 and garden.seeds["onion"] == 0, "Replacement failure must roll back the purchase")

	_use(path)
	_write(path, "{primary broken")
	_write(path + ".bak", "{backup broken")
	garden.load_save()
	_check(not garden.writable and not garden.buy_seed("onion").is_empty(), "Two corrupt saves must disable transactions")
	_check(FileAccess.get_file_as_string(path) == "{primary broken" and FileAccess.get_file_as_string(path + ".bak") == "{backup broken", "Corrupt saves must be preserved for recovery")
	for subdirectory in ["nested", "backup", "replace", "blocked-parent"]:
		var directory := DirAccess.open(base.path_join(subdirectory))
		if directory != null:
			for filename in directory.get_files():
				_check(not filename.contains(".tmp."), "Transaction left a temporary file: " + filename)

	# Ensure the shop exposes a useful location and relaunch hint after a failure.
	_use(base + "/ui/garden.json")
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	await get_tree().process_frame
	garden.save_path = replace_path
	garden.buy_seed("onion")
	menu._open("种子摊", 1)
	var has_path := false
	var has_help := false
	for label in menu.form.find_children("*", "Label", true, false):
		has_path = has_path or label.text.contains(garden.storage_error_path)
		has_help = has_help or label.text.contains("Windows")
	_check(has_path and has_help, "Shop must display the save location and a practical relaunch hint")
	menu.queue_free()
	await get_tree().process_frame
	_remove_tree(base)
	if failures.is_empty():
		print("GARDEN STORAGE PASSED: new directories, persisted transactions/profiles, backups, recovery, independent temporary files, rollback, retry and diagnostics")
	else:
		print("GARDEN STORAGE FAILED: ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
