extends Node

signal changed
signal currency_changed(delta: int, total: int)
const CATALOG = preload("res://data/plant_catalog.gd")
const HATS = preload("res://data/hat_catalog.gd")
const LAYOUT = preload("res://core/backyard_layout.gd")
const SAVE_PATH := "user://garden_save.json"
const STARTING_SMURT := 0
const SKIN_COUNT := 8
const MATCH_REWARD := 1
const SAVE_VERSION := 3
var save_path := SAVE_PATH
var smurt := STARTING_SMURT
var seeds: Dictionary = {}
var produce: Dictionary = {}
var dyes: Dictionary = {}
var owned_hats: Array[int] = []
var plots: Array = []
var profiles: Dictionary = {}
var rewarded_matches: Dictionary = {}
var storage_error := ""
var recovered_backup := false
var writable := true

func _ready() -> void:
	load_save()

func load_save() -> void:
	smurt = STARTING_SMURT
	seeds = {"blueberry": 0, "onion": 0}
	produce = {"blueberry": 0, "onion": 0}
	dyes = {}
	for index in SKIN_COUNT: dyes[str(index)] = 0
	owned_hats = []
	plots = []
	for _index in LAYOUT.PLOTS.size(): plots.append({})
	profiles = {}
	storage_error = ""
	recovered_backup = false
	writable = true
	var found := FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".bak")
	var loaded := _read_save(save_path)
	if loaded.is_empty():
		loaded = _read_save(save_path + ".bak")
		recovered_backup = not loaded.is_empty()
	if loaded.is_empty():
		if found:
			writable = false
			storage_error = "种植存档无法读取，已保留原文件；请恢复存档备份后重启游戏。"
		changed.emit()
		return
	var loaded_version := int(loaded["version"])
	smurt = int(loaded["smurt"])
	if loaded_version < SAVE_VERSION and smurt == 60 and _save_has_no_economy_activity(loaded): smurt = STARTING_SMURT
	for id in CATALOG.PLANTS:
		seeds[id] = int(loaded["seeds"].get(id, 0))
		produce[id] = int(loaded["produce"].get(id, 0))
	var saved_dyes: Dictionary = loaded.get("dyes", {})
	for index in SKIN_COUNT: dyes[str(index)] = int(saved_dyes.get(str(index), 0))
	var saved_hats: Array = loaded.get("owned_hats", [])
	for hat_id in saved_hats:
		if int(hat_id) not in owned_hats: owned_hats.append(int(hat_id))
	for index in mini(plots.size(), loaded["plots"].size()):
		var entry: Dictionary = loaded["plots"][index]
		if not entry.is_empty(): plots[index] = entry.duplicate()
	var saved_profiles: Variant = loaded.get("profiles", {})
	if saved_profiles is Dictionary:
		for slot in [1, 2]:
			var entry: Variant = saved_profiles.get(str(slot), {})
			if entry is Dictionary:
				profiles[slot] = {"name": str(entry.get("name", "P%s" % slot)).strip_edges().left(24), "skin": clampi(int(entry.get("skin", 0)), 0, 7), "hat": clampi(int(entry.get("hat", 0)), 0, 4)}
	if loaded_version < SAVE_VERSION:
		for profile in profiles.values():
			var legacy_hat := int(profile.get("hat", 0))
			if legacy_hat > 0 and legacy_hat not in owned_hats: owned_hats.append(legacy_hat)
	changed.emit()

func _save_has_no_economy_activity(data: Dictionary) -> bool:
	for inventory_name in ["seeds", "produce"]:
		var inventory: Dictionary = data.get(inventory_name, {})
		for id in CATALOG.PLANTS:
			if int(inventory.get(id, 0)) > 0: return false
	for entry in data.get("plots", []):
		if entry is Dictionary and not entry.is_empty(): return false
	return true

func _read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	file.close()
	if parse_error != OK: return {}
	var parsed: Variant = json.data
	if not parsed is Dictionary: return {}
	var data: Dictionary = parsed
	if not _valid_count(data.get("version")) or int(data["version"]) not in [1, 2, SAVE_VERSION]: return {}
	if not _valid_count(data.get("smurt")) or not data.get("seeds") is Dictionary or not data.get("produce") is Dictionary or not data.get("plots") is Array: return {}
	if data.has("dyes"):
		if not data["dyes"] is Dictionary: return {}
		for index in SKIN_COUNT:
			if not _valid_count(data["dyes"].get(str(index), 0)): return {}
	if data.has("owned_hats"):
		if not data["owned_hats"] is Array: return {}
		var seen_hats: Array[int] = []
		for hat_id in data["owned_hats"]:
			if not _valid_count(hat_id) or int(hat_id) < 1 or int(hat_id) >= HATS.PRICES.size() or int(hat_id) in seen_hats: return {}
			seen_hats.append(int(hat_id))
	if data.has("profiles"):
		if not data["profiles"] is Dictionary: return {}
		for slot in ["1", "2"]:
			if not data["profiles"].has(slot): continue
			var profile: Variant = data["profiles"][slot]
			if not profile is Dictionary or not profile.get("name", "") is String: return {}
			if not _valid_count(profile.get("skin", 0)) or int(profile.get("skin", 0)) > 7: return {}
			if not _valid_count(profile.get("hat", 0)) or int(profile.get("hat", 0)) > 4: return {}
	for inventory in [data["seeds"], data["produce"]]:
		for id in CATALOG.PLANTS:
			if not _valid_count(inventory.get(id, 0)): return {}
	for entry in data["plots"]:
		if not entry is Dictionary: return {}
		if entry.is_empty(): continue
		if not CATALOG.PLANTS.has(str(entry.get("plant", ""))): return {}
		var planted_at: Variant = entry.get("planted_at")
		if not (planted_at is int or planted_at is float): return {}
		if not is_finite(float(planted_at)) or float(planted_at) < 0: return {}
		if entry.has("grow_seconds"):
			var grow_seconds: Variant = entry["grow_seconds"]
			var base_seconds := float(CATALOG.PLANTS[str(entry["plant"])]["grow_seconds"])
			if not (grow_seconds is int or grow_seconds is float) or not is_finite(float(grow_seconds)): return {}
			if float(grow_seconds) < base_seconds * 0.95 or float(grow_seconds) > base_seconds * 1.05: return {}
	return data

func _valid_count(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0 and float(value) <= 2000000000 and float(value) == floorf(float(value))

func _snapshot() -> Dictionary:
	return {"version": SAVE_VERSION, "smurt": smurt, "seeds": seeds.duplicate(), "produce": produce.duplicate(), "dyes": dyes.duplicate(), "owned_hats": owned_hats.duplicate(), "plots": plots.duplicate(true), "profiles": profiles.duplicate(true)}

func _save_data() -> Dictionary:
	var result := _snapshot()
	var encoded_profiles := {}
	for slot in profiles: encoded_profiles[str(slot)] = profiles[slot].duplicate(true)
	result["profiles"] = encoded_profiles
	return result

func save() -> bool:
	if not writable: return false
	var temporary := save_path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		storage_error = "无法保存种植存档，请检查磁盘空间和存档目录权限。"
		return false
	file.store_string(JSON.stringify(_save_data(), "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		storage_error = "种植存档写入失败，本次操作未扣款。"
		return false
	# Keep the previous valid save; never replace a recovered backup with corrupt data.
	if not _read_save(save_path).is_empty():
		if DirAccess.copy_absolute(save_path, save_path + ".bak") != OK:
			storage_error = "无法创建种植存档备份，本次操作未扣款。"
			return false
	if DirAccess.rename_absolute(temporary, save_path) != OK:
		storage_error = "无法更新种植存档，本次操作未扣款。"
		return false
	storage_error = ""
	recovered_backup = false
	return true

func _commit(before: Dictionary) -> String:
	if not save():
		smurt = int(before["smurt"])
		seeds = before["seeds"]
		produce = before["produce"]
		dyes = before.get("dyes", dyes)
		owned_hats.clear()
		for hat_id in before.get("owned_hats", []): owned_hats.append(int(hat_id))
		plots = before["plots"]
		profiles = before.get("profiles", {})
		return storage_error
	changed.emit()
	var currency_delta := smurt - int(before["smurt"])
	if currency_delta != 0: currency_changed.emit(currency_delta, smurt)
	return ""

func has_profile(slot: int) -> bool:
	return profiles.has(slot)

func save_profile(slot: int, player_name: String, skin: int, hat: int) -> String:
	if not writable: return storage_error
	if slot not in [1, 2]: return "无效的玩家资料。"
	var before := _snapshot()
	profiles[slot] = {"name": player_name.strip_edges().left(24), "skin": clampi(skin, 0, 7), "hat": clampi(hat, 0, 4)}
	return _commit(before)

func buy_seed(id: String, amount: int = 1) -> String:
	if not writable: return storage_error
	if not CATALOG.PLANTS.has(id) or amount < 1 or amount > 99: return "无效的种子数量。"
	var cost := int(CATALOG.PLANTS[id]["seed_price"]) * amount
	if smurt < cost: return "斯马特不足，先收获并出售成熟植物。"
	if int(seeds[id]) + amount > 2000000000: return "种子库存已满。"
	var before := _snapshot()
	smurt -= cost
	seeds[id] = int(seeds[id]) + amount
	return _commit(before)

func plant_seed(index: int, id: String) -> String:
	if not writable: return storage_error
	if index < 0 or index >= plots.size() or not CATALOG.PLANTS.has(id): return "无效的种植地。"
	if not plots[index].is_empty(): return "这块地已经种了植物。"
	if int(seeds[id]) < 1: return "没有这种种子，请先到种子摊购买。"
	var before := _snapshot()
	seeds[id] = int(seeds[id]) - 1
	var base_seconds := float(CATALOG.PLANTS[id]["grow_seconds"])
	plots[index] = {
		"plant": id,
		"planted_at": Time.get_unix_time_from_system(),
		"grow_seconds": randf_range(base_seconds * 0.95, base_seconds * 1.05)
	}
	return _commit(before)

func growth(index: int, now: float = -1.0) -> float:
	if index < 0 or index >= plots.size() or plots[index].is_empty(): return 0.0
	var entry: Dictionary = plots[index]
	if now < 0: now = Time.get_unix_time_from_system()
	var duration := float(entry.get("grow_seconds", CATALOG.PLANTS[entry["plant"]]["grow_seconds"]))
	return clampf((now - float(entry["planted_at"])) / duration, 0, 1)

func seconds_remaining(index: int) -> int:
	if index < 0 or index >= plots.size() or plots[index].is_empty(): return 0
	var duration := float(plots[index].get("grow_seconds", CATALOG.PLANTS[plots[index]["plant"]]["grow_seconds"]))
	return int(ceil((1.0 - growth(index)) * duration))

func harvest(index: int) -> String:
	if not writable: return storage_error
	if index < 0 or index >= plots.size() or plots[index].is_empty(): return "这块地还没有植物。"
	if growth(index) < 1.0: return "植物还未成熟，请再等一会儿。"
	if int(produce[plots[index]["plant"]]) >= 2000000000: return "收获库存已满。"
	var before := _snapshot()
	var id := str(plots[index]["plant"])
	produce[id] = int(produce[id]) + 1
	plots[index] = {}
	return _commit(before)

func sell(id: String, amount: int = 1) -> String:
	if not writable: return storage_error
	if not CATALOG.PLANTS.has(id) or amount < 1 or amount > int(produce.get(id, 0)): return "没有足够的成熟植物可出售。"
	var income := int(CATALOG.PLANTS[id]["sell_price"]) * amount
	if smurt + income > 2000000000: return "钱包已满。"
	var before := _snapshot()
	produce[id] = int(produce[id]) - amount
	smurt += income
	return _commit(before)

func buy_hat(hat_id: int) -> String:
	if not writable: return storage_error
	if hat_id < 1 or hat_id >= HATS.PRICES.size(): return "无效的帽子。"
	if hat_id in owned_hats: return "这顶帽子已经在物品栏里了。"
	var cost := int(HATS.PRICES[hat_id])
	if smurt < cost: return "斯马特不足，先种植并出售作物。"
	var before := _snapshot()
	smurt -= cost
	owned_hats.append(hat_id)
	return _commit(before)

func buy_dye(skin_id: int, amount: int = 1) -> String:
	if not writable: return storage_error
	if skin_id < 0 or skin_id >= SKIN_COUNT or amount < 1 or amount > 99: return "无效的染色泡泡数量。"
	var cost := HATS.DYE_BUBBLE_PRICE * amount
	if smurt < cost: return "斯马特不足，先种植并出售作物。"
	if int(dyes.get(str(skin_id), 0)) + amount > 2000000000: return "染色泡泡库存已满。"
	var before := _snapshot()
	smurt -= cost
	dyes[str(skin_id)] = int(dyes.get(str(skin_id), 0)) + amount
	return _commit(before)

func use_dye(slot: int, skin_id: int) -> String:
	if not writable: return storage_error
	if slot not in [1, 2] or skin_id < 0 or skin_id >= SKIN_COUNT: return "无效的染色泡泡。"
	if not profiles.has(slot): return "没有找到这个角色的本地资料。"
	if int(profiles[slot].get("skin", 0)) == skin_id: return "角色已经是这个颜色了。"
	if int(dyes.get(str(skin_id), 0)) < 1: return "没有这款染色泡泡，请先到衣柜购买。"
	var before := _snapshot()
	dyes[str(skin_id)] = int(dyes[str(skin_id)]) - 1
	profiles[slot]["skin"] = skin_id
	return _commit(before)

func equip_hat(slot: int, hat_id: int) -> String:
	if not writable: return storage_error
	if slot not in [1, 2] or hat_id < 0 or hat_id >= HATS.PRICES.size(): return "无效的帽子选择。"
	if not profiles.has(slot): return "没有找到这个角色的本地资料。"
	if hat_id > 0 and hat_id not in owned_hats: return "这顶帽子还没有购买。"
	if int(profiles[slot].get("hat", 0)) == hat_id: return ""
	var before := _snapshot()
	profiles[slot]["hat"] = hat_id
	return _commit(before)

func award_match_reward(match_id: int) -> String:
	if not writable: return storage_error
	if rewarded_matches.has(match_id): return ""
	if smurt + MATCH_REWARD > 2000000000: return "钱包已满。"
	var before := _snapshot()
	smurt += MATCH_REWARD
	var error := _commit(before)
	if error.is_empty(): rewarded_matches[match_id] = true
	return error
