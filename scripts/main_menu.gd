extends Control

const BALL_SCENE = preload("res://modes/mud_ball/mud_ball.tscn")
const MATCH_SCENE = preload("res://modes/bubble_race/bubble_race.tscn")
const ACTOR = preload("res://actors/wum/wum.tscn")
const WORLD = preload("res://core/world_layout.gd")
const LOBBY_MOTION = preload("res://core/lobby_motion.gd")
const MOTION = preload("res://core/player_motion.gd")
const PROMPT = preload("res://ui/interaction_prompt.gd")
const ROOM = preload("res://ui/menu_room.gd")
const BACKYARD_SCENE = preload("res://scenes/backyard.tscn")
const BACKYARD_LAYOUT = preload("res://core/backyard_layout.gd")
const GARDEN_ICON = preload("res://ui/garden_icon.gd")
const DYE_BUBBLE_ICON = preload("res://ui/dye_bubble_icon.gd")
const HELD_ITEM_VISUAL = preload("res://ui/held_item_visual.gd")
const SMURT_INDICATOR = preload("res://ui/smurt_change_indicator.gd")
const PLANTS = preload("res://data/plant_catalog.gd")
const ECONOMY = preload("res://data/hat_catalog.gd")
const EXIT_DIALOG = preload("res://ui/rounded_exit_dialog.gd")
const SKINS = preload("res://assets/characters/skin_catalog.tres")
const HATS = preload("res://assets/hats/hat_catalog.tres")
const TIPS := ["蓄力达到 92% 可以吹出完美泡泡。", "跳跃键再按一次，就能在空中二段跳。", "口哨能干扰附近正在吹泡泡的对手。", "吹得太久会爆裂，及时松开吹泡泡键。", "休息室里的口哨只有声音，不会影响别人。"]
const OBJECTS := WORLD.OBJECTS
const INVENTORY_SLOT_SIZE := 68.0
const INVENTORY_ITEM_SLOTS := 27
const INVENTORY_APPAREL_SLOTS := 9
var mode := 0
var actors: Dictionary = {}
var states: Dictionary = {}
var held: Dictionary = {}
var crouch_keys: Dictionary = {KEY_S: false, KEY_DOWN: false}
var match_view: Node2D
var room: Node2D
var backyard: Node2D
var room_layers: Dictionary = {}
var view_key := ""
var inventory_panel: PanelContainer
var inventory_grid: GridContainer
var apparel_hat_grid: GridContainer
var apparel_dye_grid: GridContainer
var inventory_wallet_button: Button
var inventory_balance: Label
var inventory_selection: Label
var inventory_open := false
var inventory_owner := 1
var active_player_id := 1
var held_items: Dictionary = {1: "", 2: ""}
var selected_item: String:
	get:
		return str(held_items.get(inventory_owner, ""))
	set(value):
		held_items[inventory_owner] = value
var held_item_order: Array[String] = []
var held_item_order_owner := 1
var held_visuals: Dictionary = {}
var garden_actor_id := 1
var smurt_indicators: Dictionary = {}
var match_smurt_indicator: Node2D
var match_smurt_actor: Node2D
var trial_hats: Dictionary = {}
var trial_skins: Dictionary = {}
var last_rewarded_match_id := -1
var prompts: Dictionary = {}
var status_message := ""
var status_label: Label
var modal: PanelContainer
var form: VBoxContainer
var section_grid: GridContainer
var modal_heading: Label
var item_hover_panel: PanelContainer
var item_hover_title: Label
var item_hover_description: Label
var item_hover_text := ""
var shop_grid: GridContainer
var shop_selection := ""
var shop_tab := "hats"
var shop_quantity := 1
var quit_confirmation
var modal_owner := 1
var modal_kind := ""
var capture_action := -1
var capture_button: Button
var loading: PanelContainer
var loading_text: Label
var loading_roster: Label
var loading_column: VBoxContainer
var remote_input_elapsed := 0.0
var profile_names := ["P1", "P2"]
var audio_listener: AudioListener2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	AudioManager.play_music("lobby")
	for slot in [1, 2]:
		if GardenSave.has_profile(slot):
			var saved_profile: Dictionary = GardenSave.profiles[slot]
			profile_names[slot - 1] = str(saved_profile.get("name", "P%s" % slot))
			GameSettings.profiles[slot]["skin"] = int(saved_profile.get("skin", GameSettings.profiles[slot]["skin"]))
			GameSettings.profiles[slot]["hat"] = int(saved_profile.get("hat", GameSettings.profiles[slot]["hat"]))
		else:
			GardenSave.save_profile(slot, profile_names[slot - 1], int(GameSettings.profiles[slot]["skin"]), int(GameSettings.profiles[slot]["hat"]))
	room = ROOM.new()
	backyard = BACKYARD_SCENE.instantiate()
	for area in ["room", "backyard"]:
		var layer := Control.new()
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.clip_contents = true
		add_child(layer)
		room_layers[area] = layer
		layer.add_child(room if area == "room" else backyard)
	GardenSave.changed.connect(_garden_changed)
	GardenSave.currency_changed.connect(_currency_changed)
	_build_inventory()
	_garden_changed()
	audio_listener = AudioListener2D.new()
	audio_listener.name = "PlayerAudioListener"
	room.add_child(audio_listener)
	audio_listener.make_current()
	modal = PanelContainer.new()
	modal.visible = false
	modal.z_index = 20
	var dialog_style := StyleBoxFlat.new()
	dialog_style.bg_color = Color("263b3d")
	dialog_style.set_corner_radius_all(12)
	modal.add_theme_stylebox_override("panel", dialog_style)
	add_child(modal)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 28)
	modal.add_child(margin)
	var modal_column := VBoxContainer.new()
	modal_column.add_theme_constant_override("separation", 16)
	margin.add_child(modal_column)
	var header := HBoxContainer.new()
	modal_column.add_child(header)
	modal_heading = _add_text(header, "", 27)
	modal_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close_button := Button.new()
	close_button.text = "×"
	close_button.tooltip_text = GameSettings.text("关闭窗口")
	close_button.custom_minimum_size = Vector2(56, 48)
	close_button.add_theme_font_size_override("font_size", 30)
	close_button.pressed.connect(_close)
	header.add_child(close_button)
	status_label = _add_text(modal_column, status_message)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.visible = not status_message.is_empty()
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	modal_column.add_child(scroll)
	section_grid = GridContainer.new()
	section_grid.columns = 2
	section_grid.add_theme_constant_override("h_separation", 18)
	section_grid.add_theme_constant_override("v_separation", 18)
	section_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(section_grid)
	quit_confirmation = EXIT_DIALOG.new()
	quit_confirmation.confirmed.connect(func(): get_tree().quit())
	add_child(quit_confirmation)
	loading = PanelContainer.new()
	loading.z_index = 40
	loading.visible = false
	var loading_style := StyleBoxFlat.new()
	loading_style.bg_color = Color("172a2d")
	loading.add_theme_stylebox_override("panel", loading_style)
	add_child(loading)
	var center := CenterContainer.new()
	loading.add_child(center)
	var column := VBoxContainer.new()
	loading_column = column
	column.custom_minimum_size.x = 620
	column.add_theme_constant_override("separation", 24)
	center.add_child(column)
	var loading_title := _add_text(column, "正在前往吹泡泡比赛……", 30)
	loading_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	loading_text = _add_text(column, "", 18)
	loading_roster = _add_text(column, "", 20)
	loading_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	loading_roster.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_build_item_hover()
	NetworkSession.room_changed.connect(_refresh)
	NetworkSession.status_changed.connect(_status)
	NetworkSession.phase_changed.connect(_phase)
	NetworkSession.lobby_updated.connect(_lobby_snapshot)
	NetworkSession.lobby_whistled.connect(_whistle)
	NetworkSession.selected_skin = int(GameSettings.profiles[1]["skin"])
	NetworkSession.selected_hat = int(GameSettings.profiles[1]["hat"])
	resized.connect(_layout)
	_layout()
	_refresh()

func _add_text(parent: Node, text: String, font_size := 18, protected_names: Array = []) -> Label:
	var label := Label.new()
	label.text = GameSettings.text_with_names(text, protected_names) if not protected_names.is_empty() else GameSettings.text(text)
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _build_item_hover() -> void:
	item_hover_panel = PanelContainer.new()
	item_hover_panel.visible = false
	item_hover_panel.z_index = 100
	item_hover_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_hover_panel.custom_minimum_size = Vector2(290, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("263b3d")
	style.set_corner_radius_all(12)
	style.set_border_width_all(2)
	style.border_color = Color("b5c9ad")
	item_hover_panel.add_theme_stylebox_override("panel", style)
	add_child(item_hover_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 12)
	item_hover_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	margin.add_child(column)
	item_hover_title = _add_text(column, "", 19)
	item_hover_title.add_theme_color_override("font_color", Color("ffe7ae"))
	item_hover_description = _add_text(column, "", 15)
	item_hover_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item_hover_description.custom_minimum_size = Vector2(250, 38)
	item_hover_description.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _bind_item_hover(control: Control, title: String, description: String) -> void:
	control.mouse_entered.connect(func(): _show_item_hover(title, description))
	control.mouse_exited.connect(_hide_item_hover)

func _show_item_hover(title: String, description: String) -> void:
	if not is_instance_valid(item_hover_panel): return
	item_hover_title.text = GameSettings.text(title)
	item_hover_description.text = description
	item_hover_text = title
	item_hover_panel.visible = true
	_update_item_hover_position()

func _hide_item_hover() -> void:
	item_hover_text = ""
	if is_instance_valid(item_hover_panel): item_hover_panel.visible = false

func _update_item_hover_position() -> void:
	if not is_instance_valid(item_hover_panel) or not item_hover_panel.visible: return
	var panel_size := item_hover_panel.get_combined_minimum_size()
	item_hover_panel.size = panel_size
	var position := get_local_mouse_position() + Vector2(18, 18)
	if position.x + panel_size.x > size.x - 8: position.x = get_local_mouse_position().x - panel_size.x - 18
	if position.y + panel_size.y > size.y - 8: position.y = get_local_mouse_position().y - panel_size.y - 18
	item_hover_panel.position = Vector2(clampf(position.x, 8, maxf(8, size.x - panel_size.x - 8)), clampf(position.y, 8, maxf(8, size.y - panel_size.y - 8)))

func _item_description(kind: String, item_id := "") -> String:
	if kind == "seed" and PLANTS.PLANTS.has(item_id):
		return GameSettings.text("种下后约 %s 分钟成熟，可收获出售。") % int(float(PLANTS.PLANTS[item_id]["grow_seconds"]) / 60.0)
	if kind == "produce": return GameSettings.text("成熟作物，可在种子摊出售。")
	if kind == "remove_hat": return GameSettings.text("移除当前佩戴的帽子。")
	if kind == "hat": return GameSettings.text("装饰帽子，可在物品栏中穿戴。")
	if kind == "dye": return GameSettings.text("食用后改变角色颜色。")
	if kind == "currency": return GameSettings.text("本地货币，可用于购买种子和装扮。")
	return ""

func _build_inventory() -> void:
	if is_instance_valid(inventory_panel):
		inventory_panel.visible = false
		inventory_panel.queue_free()
	inventory_panel = PanelContainer.new()
	inventory_panel.visible = inventory_open
	inventory_panel.z_index = 18
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("263b3d")
	panel_style.set_corner_radius_all(16)
	panel_style.set_border_width_all(2)
	panel_style.border_color = Color("91b29e")
	inventory_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(inventory_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 22)
	inventory_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := _add_text(header, "物品栏", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close_button := Button.new()
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(52, 44)
	close_button.add_theme_font_size_override("font_size", 28)
	close_button.pressed.connect(func(): _set_inventory_open(false))
	header.add_child(close_button)
	_add_text(column, "斯马特", 17)
	inventory_wallet_button = Button.new()
	inventory_wallet_button.custom_minimum_size.y = 56
	inventory_wallet_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(inventory_wallet_button)
	var wallet_row := HBoxContainer.new()
	wallet_row.add_theme_constant_override("separation", 12)
	wallet_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wallet_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inventory_wallet_button.add_child(wallet_row)
	var coin := GARDEN_ICON.new()
	coin.custom_minimum_size = Vector2(52, 52)
	wallet_row.add_child(coin)
	inventory_balance = _add_text(wallet_row, "", 25)
	inventory_balance.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_add_text(wallet_row, "斯马特（smurt）", 19)
	inventory_wallet_button.pressed.connect(func(): selected_item = "currency:smurt"; _refresh_inventory())
	_bind_item_hover(inventory_wallet_button, "斯马特", _item_description("currency"))
	inventory_wallet_button.disabled = GardenSave.smurt <= 0
	inventory_selection = _add_text(column, "手持：无", 18)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var item_sections := VBoxContainer.new()
	item_sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_sections.add_theme_constant_override("separation", 10)
	scroll.add_child(item_sections)
	inventory_grid = _inventory_grid_section(item_sections, "物品")
	apparel_hat_grid = _inventory_grid_section(item_sections, "服饰 · 帽子")
	apparel_dye_grid = _inventory_grid_section(item_sections, "服饰 · 染色泡泡")
	_refresh_inventory()

func _inventory_grid_section(parent: Node, title: String) -> GridContainer:
	var section := PanelContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var section_style := StyleBoxFlat.new()
	section_style.bg_color = Color("304a46")
	section_style.set_corner_radius_all(10)
	section_style.set_border_width_all(1)
	section_style.border_color = Color("607e72")
	section.add_theme_stylebox_override("panel", section_style)
	parent.add_child(section)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 8)
	section.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	_add_text(column, title, 17)
	var grid := GridContainer.new()
	grid.columns = 9
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	column.add_child(grid)
	return grid

func _inventory_empty_slot(parent: GridContainer) -> void:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(INVENTORY_SLOT_SIZE, INVENTORY_SLOT_SIZE)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("263e3c")
	style.set_corner_radius_all(6)
	style.set_border_width_all(1)
	style.border_color = Color("526a62")
	slot.add_theme_stylebox_override("panel", style)
	parent.add_child(slot)

func _set_inventory_open(open: bool) -> void:
	if not open: _hide_item_hover()
	inventory_open = open
	if is_instance_valid(inventory_panel): inventory_panel.visible = open
	if open:
		inventory_owner = active_player_id if mode == 1 else 1
		_refresh_inventory()
		held.clear()
		crouch_keys[KEY_S] = false
		crouch_keys[KEY_DOWN] = false
		if mode == 2 and NetworkSession.active: NetworkSession.lobby_control("crouch", 0)
	_layout()

func _refresh_inventory() -> void:
	if not is_instance_valid(inventory_grid): return
	inventory_balance.text = "%s" % GardenSave.smurt
	var wallet_style := _inventory_tile_style(selected_item == "currency:smurt")
	inventory_wallet_button.disabled = GardenSave.smurt <= 0
	inventory_wallet_button.add_theme_stylebox_override("normal", wallet_style)
	inventory_wallet_button.add_theme_stylebox_override("hover", wallet_style)
	inventory_wallet_button.add_theme_stylebox_override("pressed", wallet_style)
	var held_name := "无"
	var parts := selected_item.split(":", false, 1)
	if parts.size() == 2:
		if parts[0] == "currency": held_name = "斯马特"
		elif parts[0] == "dye": held_name = "染色泡泡：" + str(SKINS.skins[int(parts[1])].display_name)
		elif PLANTS.PLANTS.has(parts[1]): held_name = ("种子：" if parts[0] == "seed" else "收获物：") + str(PLANTS.PLANTS[parts[1]]["name"])
	inventory_selection.text = GameSettings.text("手持：%s" % GameSettings.text(held_name))
	held_item_order.clear()
	if GardenSave.smurt > 0: held_item_order.append("currency:smurt")
	for child in inventory_grid.get_children():
		inventory_grid.remove_child(child)
		child.queue_free()
	for category in ["seed", "produce"]:
		var inventory: Dictionary = GardenSave.seeds if category == "seed" else GardenSave.produce
		for id in PLANTS.PLANTS:
			var plant_id := str(id)
			var count := int(inventory.get(plant_id, 0))
			if count <= 0: continue
			held_item_order.append("%s:%s" % [category, plant_id])
			_inventory_tile(category, plant_id, count)
	while inventory_grid.get_child_count() < INVENTORY_ITEM_SLOTS:
		_inventory_empty_slot(inventory_grid)
	for child in apparel_hat_grid.get_children():
		apparel_hat_grid.remove_child(child)
		child.queue_free()
	var slot := inventory_owner if mode == 1 else 1
	var equipped_hat := int(GameSettings.profiles[slot].get("hat", 0))
	if equipped_hat > 0:
		_inventory_apparel_tile("不戴帽子", null, Color.WHITE, false, func(): _equip_inventory_hat(slot, 0))
	for hat_id in GardenSave.owned_hats:
		if hat_id <= 0 or hat_id >= HATS.hats.size(): continue
		var inventory_hat_id := int(hat_id)
		var hat: WuppoCharacterHat = HATS.hats[inventory_hat_id]
		_inventory_apparel_tile(hat.display_name, hat.texture, hat.tint, equipped_hat == inventory_hat_id, func(): _equip_inventory_hat(slot, inventory_hat_id))
	for child in apparel_dye_grid.get_children():
		apparel_dye_grid.remove_child(child)
		child.queue_free()
	for index in SKINS.skins.size():
		var dye_count := int(GardenSave.dyes.get(str(index), 0))
		if dye_count <= 0: continue
		held_item_order.append("dye:%s" % index)
		_inventory_dye_tile(index, dye_count)
	while apparel_hat_grid.get_child_count() < INVENTORY_APPAREL_SLOTS:
		_inventory_empty_slot(apparel_hat_grid)
	while apparel_dye_grid.get_child_count() < INVENTORY_APPAREL_SLOTS:
		_inventory_empty_slot(apparel_dye_grid)
	if not selected_item.is_empty() and not held_item_order.has(selected_item): selected_item = ""
	held_item_order_owner = inventory_owner
	_sync_held_visuals()

func _inventory_tile_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("45685e")
	style.set_corner_radius_all(10)
	style.set_border_width_all(3 if selected else 1)
	style.border_color = Color("ffd16f") if selected else Color("769187")
	return style

func _inventory_tile(category: String, plant_id: String, count: int) -> void:
	var item_key := "%s:%s" % [category, plant_id]
	var button := Button.new()
	button.custom_minimum_size = Vector2(INVENTORY_SLOT_SIZE, INVENTORY_SLOT_SIZE)
	button.tooltip_text = ""
	var style := _inventory_tile_style(item_key == selected_item)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	var body := Control.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(body)
	var icon = GARDEN_ICON.new()
	icon.kind = "seed:" + plant_id if category == "seed" else plant_id
	icon.position = Vector2(8, 5)
	icon.size = Vector2(52, 52)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(icon)
	var category_label := Label.new()
	category_label.text = GameSettings.text("种" if category == "seed" else "收")
	category_label.position = Vector2(3, 1)
	category_label.size = Vector2(18, 16)
	category_label.add_theme_font_size_override("font_size", 11)
	category_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(category_label)
	var count_label := Label.new()
	count_label.text = "%s" % count
	count_label.position = Vector2(34, 47)
	count_label.size = Vector2(30, 18)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.add_theme_font_size_override("font_size", 15)
	count_label.add_theme_color_override("font_color", Color.WHITE)
	count_label.add_theme_color_override("font_outline_color", Color("263b3d"))
	count_label.add_theme_constant_override("outline_size", 3)
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(count_label)
	button.pressed.connect(func(): selected_item = item_key; _refresh_inventory())
	var category_title := "种子：" if category == "seed" else "收获物："
	var item_title := GameSettings.text(category_title) + GameSettings.text(str(PLANTS.PLANTS[plant_id]["name"]))
	_bind_item_hover(button, item_title, _item_description(category, plant_id))
	inventory_grid.add_child(button)

func _inventory_apparel_tile(title: String, texture: Texture2D, tint: Color, selected: bool, callback: Callable) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(INVENTORY_SLOT_SIZE, INVENTORY_SLOT_SIZE)
	button.tooltip_text = ""
	button.add_theme_stylebox_override("normal", _inventory_tile_style(selected))
	button.add_theme_stylebox_override("hover", _inventory_tile_style(selected))
	var body := Control.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(body)
	if texture != null:
		var sprite := TextureRect.new()
		sprite.texture = texture
		sprite.modulate = tint
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.position = Vector2(7, 7)
		sprite.size = Vector2(54, 50)
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(sprite)
	else:
		var no_hat := Label.new()
		no_hat.text = "×"
		no_hat.position = Vector2(7, 7)
		no_hat.size = Vector2(54, 50)
		no_hat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_hat.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		no_hat.add_theme_font_size_override("font_size", 30)
		no_hat.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(no_hat)
	button.pressed.connect(callback)
	_bind_item_hover(button, title, _item_description("remove_hat") if title == "不戴帽子" else _item_description("hat"))
	apparel_hat_grid.add_child(button)

func _inventory_dye_tile(skin_id: int, count: int) -> void:
	var item_key := "dye:%s" % skin_id
	var button := Button.new()
	button.custom_minimum_size = Vector2(INVENTORY_SLOT_SIZE, INVENTORY_SLOT_SIZE)
	button.tooltip_text = ""
	button.add_theme_stylebox_override("normal", _inventory_tile_style(item_key == selected_item))
	button.add_theme_stylebox_override("hover", _inventory_tile_style(item_key == selected_item))
	var body := Control.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(body)
	var bubble = DYE_BUBBLE_ICON.new()
	bubble.bubble_color = SKINS.skins[skin_id].body_tint
	bubble.position = Vector2(8, 5)
	bubble.size = Vector2(52, 52)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(bubble)
	var count_label := Label.new()
	count_label.text = str(count)
	count_label.position = Vector2(34, 47)
	count_label.size = Vector2(30, 18)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.add_theme_font_size_override("font_size", 15)
	count_label.add_theme_color_override("font_color", Color.WHITE)
	count_label.add_theme_color_override("font_outline_color", Color("263b3d"))
	count_label.add_theme_constant_override("outline_size", 3)
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(count_label)
	button.pressed.connect(func(): selected_item = item_key; _refresh_inventory())
	_bind_item_hover(button, GameSettings.text("%s染色泡泡") % GameSettings.text(str(SKINS.skins[skin_id].display_name)), _item_description("dye"))
	apparel_dye_grid.add_child(button)

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = GameSettings.text(text)
	button.custom_minimum_size.y = 36
	button.pressed.connect(callback)
	form.add_child(button)
	return button

func _shop_action_button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = GameSettings.text(text)
	button.custom_minimum_size.y = 32
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _option(label: String, items: Array, selected: int, callback: Callable) -> OptionButton:
	_add_text(form, label)
	var option := OptionButton.new()
	for item in items: option.add_item(GameSettings.text(str(item)))
	option.select(selected)
	option.item_selected.connect(callback)
	form.add_child(option)
	return option

func _layout() -> void:
	if not is_instance_valid(room): return
	var local_ids := _local_ids()
	var first_area := str(states.get(local_ids[0], {}).get("lobby_area", "room"))
	var second_area := str(states.get(2, {}).get("lobby_area", "room"))
	var split := mode == 1 and first_area != second_area
	for area in room_layers:
		var layer: Control = room_layers[area]
		layer.visible = NetworkSession.phase == "LOBBY" and (split or area == first_area)
		layer.size = Vector2(size.x * 0.5, size.y) if split else size
		layer.position = Vector2(size.x * 0.5, 0) if split and area == second_area else Vector2.ZERO
		var scene: Node2D = room if area == "room" else backyard
		var zoom_factor := WORLD.fit_scale(layer.size)
		scene.scale = Vector2.ONE * zoom_factor
		scene.position = (layer.size - WORLD.SIZE * zoom_factor) * 0.5
		scene.queue_redraw()
	var modal_width := size.x * 0.92
	if modal_kind in ["衣柜", "种子摊"]: modal_width = minf(modal_width, 900)
	modal.position = Vector2((size.x - modal_width) * 0.5, size.y * 0.045)
	modal.size = Vector2(modal_width, size.y * 0.91)
	if is_instance_valid(inventory_panel):
		var inventory_size := Vector2(minf(820, size.x - 40), minf(700, size.y - 40))
		inventory_panel.size = inventory_size
		inventory_panel.position = (size - inventory_size) * 0.5
		var slot_columns := 9 if inventory_size.x >= 724 else (8 if inventory_size.x >= 648 else (6 if inventory_size.x >= 500 else (4 if inventory_size.x >= 334 else 3)))
		if is_instance_valid(inventory_grid): inventory_grid.columns = slot_columns
		if is_instance_valid(apparel_hat_grid): apparel_hat_grid.columns = inventory_grid.columns
		if is_instance_valid(apparel_dye_grid): apparel_dye_grid.columns = inventory_grid.columns
		if is_instance_valid(shop_grid): shop_grid.columns = clampi(int((modal.size.x * 0.84) / (INVENTORY_SLOT_SIZE + 6)), 3, 9)
	loading.position = Vector2.ZERO
	loading.size = size
	loading_column.custom_minimum_size.x = minf(620, size.x - 48)

func _status(message: String) -> void:
	status_message = message
	if is_instance_valid(status_label):
		status_label.text = GameSettings.text(message)
		status_label.visible = not message.is_empty()

func _refresh() -> void:
	if NetworkSession.active and not NetworkSession.practice and not NetworkSession.local_duel: mode = 2
	if NetworkSession.phase == "LOADING":
		var lines := PackedStringArray()
		for id in NetworkSession.players:
			var player_name := str(NetworkSession.players[id]["name"])
			if player_name in ["练习伙伴", "电脑伙伴"]: player_name = GameSettings.text(player_name)
			lines.append(GameSettings.text_with_names("%s：%s" % [player_name, "已加载" if NetworkSession.loaded.has(id) else "加载中……"], [player_name]))
		loading_roster.text = GameSettings.text("等待所有参赛玩家") + "\n" + "\n".join(lines)
	if NetworkSession.phase != "LOBBY": return
	var roster: Dictionary = NetworkSession.players.duplicate(true) if NetworkSession.active and mode == 2 else {}
	if roster.is_empty():
		for slot in ([1, 2] if mode == 1 else [1]):
			roster[slot] = {"name": profile_names[slot - 1], "skin": GameSettings.profiles[slot]["skin"], "hat": GameSettings.profiles[slot]["hat"]}
	for id in actors.keys():
		if not roster.has(id):
			actors[id].queue_free()
			if smurt_indicators.has(id):
				smurt_indicators[id].queue_free()
				smurt_indicators.erase(id)
			prompts[id].queue_free()
			prompts.erase(id)
			actors.erase(id)
			states.erase(id)
	for id in roster:
		var info: Dictionary = roster[id]
		if not actors.has(id):
			var actor = ACTOR.instantiate()
			actor.warning_enabled = false
			actor.externally_positioned = true
			actor.scale = Vector2.ONE * WORLD.ACTOR_SCALE
			room.add_child(actor)
			actor.get_node("NameLabel").add_theme_color_override("font_color", Color("314b48"))
			actors[id] = actor
			var indicator = SMURT_INDICATOR.new()
			indicator.visible = false
			room.add_child(indicator)
			smurt_indicators[id] = indicator
			var prompt = PROMPT.new()
			prompt.scale = Vector2.ONE * WORLD.WIDGET_SCALE
			prompt.z_index = 10
			prompt.visible = false
			room.add_child(prompt)
			prompts[id] = prompt
			states[id] = {"position": LOBBY_MOTION.SPAWNS[(actors.size() - 1) % LOBBY_MOTION.SPAWNS.size()], "move": 0, "velocity_y": 0.0, "jumps": 0}
		var actor = actors[id]
		actor.skin = SKINS.skins[clampi(int(info.get("skin", 0)), 0, SKINS.skins.size() - 1)]
		actor.hat = HATS.hats[clampi(int(info.get("hat", 0)), 0, HATS.hats.size() - 1)]
		actor.mouse_gaze_enabled = int(id) == NetworkSession.local_player_id()
		actor.apply_skin()
		actor.apply_hat()
		actor.set_player_name(str(info["name"]))
		actor.position = states[id]["position"]
	GameSettings.apply_volume(mode == 1)
	_process(0.0)
	if modal.visible and modal_kind == "门": _open("门", modal_owner)

func _local_ids() -> Array:
	return [1, 2] if mode == 1 else [NetworkSession.local_player_id() if NetworkSession.active else 1]

func _physics_process(delta: float) -> void:
	if NetworkSession.phase != "LOBBY": return
	remote_input_elapsed += delta
	for id in _local_ids():
		if not states.has(id): continue
		var slot: int = id if mode == 1 else 1
		var moving := int(bool(held.get("%s:1" % slot, false))) - int(bool(held.get("%s:0" % slot, false)))
		var freeze_local := inventory_open or (modal.visible and modal_owner == slot)
		var crouching := _crouching_for_slot(slot) and not freeze_local
		if freeze_local: moving = 0
		if mode == 2 and NetworkSession.active:
			if remote_input_elapsed >= 0.1:
				NetworkSession.lobby_control("move", moving)
				NetworkSession.lobby_control("crouch", int(crouching))
		else:
			var state: Dictionary = states[id]
			state["move"] = moving
			MOTION.set_crouching(state, crouching)
			var previous_velocity_y := float(state.get("velocity_y", 0.0))
			LOBBY_MOTION.step(state, delta)
			actors[id].position = state["position"]
			actors[id].set_walking(float(state.get("velocity_x", 0.0)) / maxf(1.0, MOTION.CONFIG.move_speed), int(state.get("jumps", 0)) == 0 and absf(float(state.get("velocity_y", 0.0))) < 0.5)
			actors[id].set_crouching(bool(state.get("crouching", false)))
			if absf(previous_velocity_y) > 0.5 and absf(float(state.get("velocity_y", 0.0))) <= 0.5:
				AudioManager.play_positional_cue("land", actors[id].global_position, null, 0.28)
			if moving != 0: actors[id].set_facing_direction(moving)
	if remote_input_elapsed >= 0.1: remote_input_elapsed = 0.0

func _process(_delta: float) -> void:
	_update_item_hover_position()
	_sync_lobby_views()
	_update_audio_listener()
	_follow_smurt_indicators()
	_sync_held_visuals()
	for id in prompts:
		var prompt: Node2D = prompts[id]
		var furniture := _nearby(id)
		var should_show := NetworkSession.phase == "LOBBY" and not modal.visible and not inventory_open and _local_ids().has(id) and not furniture.is_empty() and not furniture.begins_with("种植地 ")
		if should_show:
			var slot: int = id if mode == 1 else 1
			var code := int(GameSettings.keys(slot)[3])
			if mode != 1 and code == KEY_K: code = -MOUSE_BUTTON_LEFT
			var held_key := str(held_items.get(int(id) if mode == 1 else 1, ""))
			var held_plant_id := held_key.get_slice(":", 1) if held_key.begins_with("produce:") else ""
			var can_sell_held_plant := not held_plant_id.is_empty() and int(GardenSave.produce.get(held_plant_id, 0)) > 0
			var prompt_name := "售出" if furniture == "种子摊" and can_sell_held_plant else furniture
			if furniture.begins_with("种植地 "): prompt.set_target(-MOUSE_BUTTON_LEFT, "")
			else: prompt.set_target(code, prompt_name)
			var bottom := (86.0 if code >= 0 else 61.0) * prompt.global_scale.y
			var head: Vector2 = actors[id].head_position()
			prompt.set_follow_target(head - Vector2(0, bottom + 24 * room.scale.y), not prompt.visible)
		prompt.visible = should_show

func _update_audio_listener() -> void:
	if not is_instance_valid(audio_listener): return
	if mode == 1 and actors.has(1) and actors.has(2):
		audio_listener.global_position = (actors[1].global_position + actors[2].global_position) * 0.5
	else:
		var local_id := NetworkSession.local_player_id() if NetworkSession.active else 1
		if actors.has(local_id): audio_listener.global_position = actors[local_id].global_position
func _nearby(id: int) -> String:
	if not states.has(id): return ""
	return LOBBY_MOTION.nearby(states[id]["position"], str(states[id].get("lobby_area", "room")))

func _handle_garden_click(screen_position: Vector2) -> bool:
	if not room_layers.has("backyard"): return false
	var layer: Control = room_layers["backyard"]
	if not layer.visible or not layer.get_global_rect().has_point(screen_position): return false
	var world_position: Vector2 = backyard.get_global_transform_with_canvas().affine_inverse() * screen_position
	var player_id := -1
	var nearest_distance := INF
	for id in _local_ids():
		if states.has(id) and str(states[id].get("lobby_area", "room")) == "backyard":
			var actor_position: Vector2 = states[id]["position"]
			var distance := actor_position.distance_to(world_position)
			if distance < nearest_distance:
				player_id = int(id)
				nearest_distance = distance
	if player_id < 0: return true
	garden_actor_id = player_id
	modal_owner = player_id if mode == 1 else 1
	inventory_owner = player_id if mode == 1 else 1
	active_player_id = player_id
	if selected_item.begins_with("dye:"):
		_use_selected_dye(inventory_owner)
		return true
	for index in BACKYARD_LAYOUT.PLOTS.size():
		var plot_rect := Rect2(BACKYARD_LAYOUT.PLOTS[index] - 91.0, 790.0, 182.0, 150.0)
		if plot_rect.has_point(world_position):
			_interact_with_plot(player_id, index)
			return true
	if _nearby(player_id) == "种子摊":
		if selected_item.begins_with("produce:"):
			var plant_id := selected_item.get_slice(":", 1)
			var count := int(GardenSave.produce.get(plant_id, 0))
			if count > 0:
				var error := GardenSave.sell(plant_id, count)
				if error.is_empty():
					selected_item = ""
					_refresh_inventory()
			else:
				selected_item = ""
				_refresh_inventory()
				_open("种子摊", modal_owner)
		else:
			_open("种子摊", modal_owner)
		return true
	return true

func _handle_room_click(screen_position: Vector2) -> bool:
	if not room_layers.has("room"): return false
	var layer: Control = room_layers["room"]
	if not layer.visible or not layer.get_global_rect().has_point(screen_position): return false
	var world_position: Vector2 = room.get_global_transform_with_canvas().affine_inverse() * screen_position
	var target := ""
	for object in LOBBY_MOTION.OBJECT_BOUNDS:
		var object_bounds: Rect2 = LOBBY_MOTION.OBJECT_BOUNDS[object]
		if object_bounds.has_point(world_position):
			target = str(object)
			break
	if target.is_empty(): return false
	var player_id := -1
	var nearest_distance := INF
	for id in _local_ids():
		if not states.has(id) or str(states[id].get("lobby_area", "room")) != "room": continue
		if _nearby(int(id)) != target: continue
		var actor_position: Vector2 = states[id]["position"]
		var distance := actor_position.distance_to(world_position)
		if distance < nearest_distance:
			player_id = int(id)
			nearest_distance = distance
	if player_id < 0: return true
	active_player_id = player_id
	garden_actor_id = player_id
	var slot := player_id if mode == 1 else 1
	inventory_owner = slot
	_open(target, slot)
	return true

func _interact_with_plot(player_id: int, index: int) -> void:
	if index < 0 or index >= GardenSave.plots.size(): return
	garden_actor_id = player_id
	modal_owner = player_id if mode == 1 else 1
	inventory_owner = player_id if mode == 1 else 1
	active_player_id = player_id
	if _nearby(player_id) != "种植地 %s" % (index + 1): return
	var entry: Dictionary = GardenSave.plots[index]
	if entry.is_empty():
		if not selected_item.begins_with("seed:"): return
		var plant_id := selected_item.get_slice(":", 1)
		if GardenSave.plant_seed(index, plant_id).is_empty():
			if int(GardenSave.seeds.get(plant_id, 0)) <= 0: selected_item = ""
			_refresh_inventory()
	elif GardenSave.growth(index) >= 1.0:
		GardenSave.harvest(index)

func _smurt_indicator_target(actor: Node2D) -> Vector2:
	var side := signf(float(actor.get("facing_direction")))
	if is_zero_approx(side): side = 1.0
	return actor.head_position() + Vector2(70.0 * side, -12.0)

func _follow_smurt_indicators() -> void:
	for id in smurt_indicators:
		if not actors.has(id): continue
		var indicator: Node2D = smurt_indicators[id]
		if indicator.visible:
			indicator.set_follow_target(_smurt_indicator_target(actors[id]))
	if is_instance_valid(match_smurt_indicator) and is_instance_valid(match_smurt_actor) and match_smurt_indicator.visible:
		match_smurt_indicator.set_follow_target(_smurt_indicator_target(match_smurt_actor))

func _currency_changed(_delta: int, total: int) -> void:
	if NetworkSession.phase != "LOBBY" and is_instance_valid(match_view):
		var match_actors: Variant = match_view.get("actors")
		var match_player_id := NetworkSession.local_player_id() if NetworkSession.active and not NetworkSession.local_duel else 1
		if match_actors is Dictionary and match_actors.has(match_player_id):
			match_smurt_actor = match_actors[match_player_id]
			if not is_instance_valid(match_smurt_indicator):
				match_smurt_indicator = SMURT_INDICATOR.new()
				match_smurt_indicator.visible = false
				match_view.add_child(match_smurt_indicator)
			match_smurt_indicator.set_follow_target(_smurt_indicator_target(match_smurt_actor), true)
			match_smurt_indicator.show_change(total)
			return
	var player_id := garden_actor_id
	if not actors.has(player_id):
		var local_ids := _local_ids()
		if local_ids.is_empty(): return
		player_id = int(local_ids[0])
	if not smurt_indicators.has(player_id): return
	var indicator: Node2D = smurt_indicators[player_id]
	var actor: Node2D = actors[player_id]
	if indicator.get_parent() != actor.get_parent(): indicator.reparent(actor.get_parent(), false)
	indicator.set_follow_target(_smurt_indicator_target(actor), true)
	indicator.show_change(total)

func _sync_held_visuals() -> void:
	for id in actors:
		var slot := int(id) if mode == 1 else 1
		var visible_to_local := mode == 1 or not NetworkSession.active or int(id) == NetworkSession.local_player_id()
		_attach_held_visual(actors[id], "lobby:%s" % id, str(held_items.get(slot, "")) if visible_to_local else "")
	if not is_instance_valid(match_view): return
	var match_actors: Variant = match_view.get("actors")
	if not match_actors is Dictionary: return
	for id in match_actors:
		var player_id := int(id)
		# Backyard inventory is a lobby-only feature; never transfer held seeds or crops into a match.
		_attach_held_visual(match_actors[id], "match:%s" % player_id, "")

func _attach_held_visual(actor: Node2D, visual_key: String, item_key: String) -> void:
	var visual: Node2D
	if is_instance_valid(held_visuals.get(visual_key)):
		visual = held_visuals[visual_key]
	else:
		visual = HELD_ITEM_VISUAL.new()
		visual.z_index = 5
		actor.add_child(visual)
		held_visuals[visual_key] = visual
	var character_size := 96.0
	var sprite := actor.get_node_or_null("Visual") as AnimatedSprite2D
	if sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(sprite.animation):
		var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		if texture != null: character_size = texture.get_size().y * absf(sprite.scale.y)
	visual.transform = actor.held_item_pose()
	visual.set_item(item_key, character_size)

func _cycle_held_item(direction: int) -> void:
	if held_item_order_owner != inventory_owner or held_item_order.is_empty(): _refresh_inventory()
	if held_item_order.is_empty(): return
	var current_index := held_item_order.find(selected_item)
	if current_index < 0: current_index = -1 if direction > 0 else 0
	var next_index := posmod(current_index + direction, held_item_order.size())
	selected_item = held_item_order[next_index]
	_refresh_inventory()

func _use_selected_dye(slot: int) -> void:
	if not selected_item.begins_with("dye:"): return
	var skin_id := int(selected_item.get_slice(":", 1))
	var error := GardenSave.use_dye(slot, skin_id)
	if not error.is_empty(): return
	GameSettings.profiles[slot]["skin"] = skin_id
	GameSettings.save()
	if slot == 1: NetworkSession.choose_skin(skin_id)
	_refresh_inventory()
	_refresh()

func _equip_inventory_hat(slot: int, hat_id: int) -> void:
	var target_hat := 0 if int(GameSettings.profiles[slot].get("hat", 0)) == hat_id else hat_id
	var error := GardenSave.equip_hat(slot, target_hat)
	if not error.is_empty(): return
	GameSettings.profiles[slot]["hat"] = target_hat
	GameSettings.save()
	if slot == 1: NetworkSession.choose_hat(target_hat)
	_refresh_inventory()
	_refresh()

func _try_hat(slot: int, hat_id: int) -> void:
	trial_hats[slot] = hat_id
	var player_id := slot if mode == 1 else (NetworkSession.local_player_id() if NetworkSession.active else 1)
	if not actors.has(player_id): return
	actors[player_id].hat = HATS.hats[hat_id]
	actors[player_id].apply_hat()
	if modal.visible and modal_kind == "衣柜": _open("衣柜", slot)

func _try_skin(slot: int, skin_id: int) -> void:
	trial_skins[slot] = skin_id
	var player_id := slot if mode == 1 else (NetworkSession.local_player_id() if NetworkSession.active else 1)
	if not actors.has(player_id): return
	actors[player_id].skin = SKINS.skins[skin_id]
	actors[player_id].apply_skin()
	if modal.visible and modal_kind == "衣柜": _open("衣柜", slot)

func _restore_trial_appearance() -> void:
	if modal_kind != "衣柜": return
	var trial_slots: Array[int] = []
	for slot in trial_skins:
		if int(slot) not in trial_slots: trial_slots.append(int(slot))
	for slot in trial_hats:
		if int(slot) not in trial_slots: trial_slots.append(int(slot))
	for slot in trial_slots:
		var player_id := slot if mode == 1 else (NetworkSession.local_player_id() if NetworkSession.active else 1)
		if not actors.has(player_id): continue
		var skin_id := clampi(int(GameSettings.profiles[slot].get("skin", 0)), 0, SKINS.skins.size() - 1)
		var hat_id := clampi(int(GameSettings.profiles[slot].get("hat", 0)), 0, HATS.hats.size() - 1)
		actors[player_id].skin = SKINS.skins[skin_id]
		actors[player_id].apply_skin()
		actors[player_id].hat = HATS.hats[hat_id]
		actors[player_id].apply_hat()
	trial_skins.clear()
	trial_hats.clear()

func _sync_lobby_views() -> void:
	for id in actors:
		var area := str(states[id].get("lobby_area", "room"))
		var scene: Node2D = backyard if area == "backyard" else room
		if actors[id].get_parent() != scene:
			actors[id].reparent(scene, false)
			actors[id].position = states[id]["position"]
			prompts[id].reparent(scene, false)
			smurt_indicators[id].reparent(scene, false)
			prompts[id].visible = false
	var local_ids := _local_ids()
	var key := "%s:%s:%s:%s" % [mode, NetworkSession.phase, states.get(local_ids[0], {}).get("lobby_area", "room"), states.get(2, {}).get("lobby_area", "room") if mode == 1 else ""]
	if key != view_key:
		view_key = key
		_layout()

func _crouching_for_slot(slot: int) -> bool:
	if mode == 1: return bool(crouch_keys[KEY_S]) if slot == 1 else bool(crouch_keys[KEY_DOWN])
	return bool(crouch_keys[KEY_S]) or bool(crouch_keys[KEY_DOWN])

func _input(event: InputEvent) -> void:
	if NetworkSession.phase != "LOBBY": return
	if capture_action >= 0:
		if not event.is_pressed() or event.is_echo(): return
		if event is InputEventKey and event.physical_keycode == KEY_ESCAPE:
			capture_action = -1
			_open("电脑", modal_owner)
			get_viewport().set_input_as_handled()
			return
		var code := 0
		if event is InputEventKey: code = event.physical_keycode
		elif event is InputEventMouseButton: code = -event.button_index
		if code == 0: return
		for slot in ([1, 2] if mode == 1 else [modal_owner]):
			for action in 5:
				if slot == modal_owner and action == capture_action: continue
				if int(GameSettings.keys(slot)[action]) == code:
					capture_button.text = GameSettings.text("这个按键已被占用，请换一个（Esc 取消）")
					get_viewport().set_input_as_handled()
					return
		GameSettings.keys(modal_owner)[capture_action] = code
		GameSettings.save()
		capture_action = -1
		_open("电脑", modal_owner)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		if quit_confirmation.is_open: quit_confirmation.close_dialog()
		elif inventory_open: _set_inventory_open(false)
		elif modal.visible: _close()
		else: quit_confirmation.show_dialog("退出游戏", "确定要退出游戏吗？", "退出游戏")
		get_viewport().set_input_as_handled()
		return
	if quit_confirmation.is_open: return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_TAB and not modal.visible:
		_set_inventory_open(not inventory_open)
		get_viewport().set_input_as_handled()
		return
	if inventory_open: return
	if event is InputEventMouseButton and event.pressed and not modal.visible and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		inventory_owner = active_player_id if mode == 1 else 1
		_cycle_held_item(-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not modal.visible:
		if _handle_garden_click(event.position):
			get_viewport().set_input_as_handled()
			return
		if _handle_room_click(event.position):
			get_viewport().set_input_as_handled()
			return
	if modal.visible: return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and selected_item.begins_with("dye:"):
		_use_selected_dye(inventory_owner)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.physical_keycode in [KEY_S, KEY_DOWN]:
		if event.echo: return
		var key_code := int(event.physical_keycode)
		crouch_keys[key_code] = event.is_pressed()
		var slot := 2 if mode == 1 and key_code == KEY_DOWN else (1 if mode == 1 else NetworkSession.local_player_id() if NetworkSession.active else 1)
		active_player_id = slot
		inventory_owner = slot if mode == 1 else 1
		var crouching := _crouching_for_slot(slot)
		if mode == 2 and NetworkSession.active: NetworkSession.lobby_control("crouch", int(crouching))
		elif states.has(slot): MOTION.set_crouching(states[slot], crouching)
		if actors.has(slot): actors[slot].set_crouching(crouching)
		return
	for id in _local_ids():
		var slot: int = id if mode == 1 else 1
		for action in 5:
			if not GameSettings.matches(event, slot, action, mode == 1) or event.is_echo(): continue
			active_player_id = int(id)
			inventory_owner = slot
			if action < 2: held["%s:%s" % [slot, action]] = event.is_pressed()
			elif event.is_pressed() and states.has(id):
				if action == 2:
					if mode == 2 and NetworkSession.active:
						NetworkSession.lobby_control("jump")
						actors[id].walk_grounded = false
						actors[id].set_crouching(false)
					else:
						var was_double_jump := int(states[id].get("jumps", 0)) == 1
						if LOBBY_MOTION.jump(states[id]):
							actors[id].walk_grounded = false
							actors[id].set_crouching(false)
							if was_double_jump:
								var spin_direction := MOTION.double_jump_direction(states[id])
								states[id]["double_jump_direction"] = spin_direction
								if actors.has(id): actors[id].trigger_double_jump(spin_direction, actors[id].global_position)
							elif actors.has(id):
								AudioManager.play_positional_cue("jump", actors[id].global_position, null, 0.38)
				elif action == 3:
					var nearby := _nearby(id)
					garden_actor_id = int(id)
					if nearby.begins_with("种植地 "): _interact_with_plot(id, int(nearby.get_slice(" ", 1)) - 1)
					elif not nearby.is_empty(): _open(nearby, slot)
				elif action == 4:
					if mode == 2 and NetworkSession.active: NetworkSession.lobby_control("whistle")
					elif Time.get_ticks_msec() >= int(states[id].get("whistle_at", 0)):
						states[id]["whistle_at"] = Time.get_ticks_msec() + 500
						_whistle(id)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		held.clear()
		crouch_keys[KEY_S] = false
		crouch_keys[KEY_DOWN] = false
		if NetworkSession.active:
			NetworkSession.lobby_control("move", 0)
			NetworkSession.lobby_control("crouch", 0)

func _lobby_snapshot(snapshot: Dictionary) -> void:
	if NetworkSession.phase != "LOBBY": return
	for id in snapshot:
		var previous_jumps := int(states.get(id, {}).get("jumps", 0))
		var previous_velocity_y := float(states.get(id, {}).get("velocity_y", 0.0))
		states[id] = snapshot[id].duplicate()
		if actors.has(id):
			var audible := bool(room_layers[str(states[id].get("lobby_area", "room"))].visible)
			if audible and previous_jumps == 0 and int(states[id].get("jumps", 0)) == 1:
				AudioManager.play_positional_cue("jump", actors[id].global_position, null, 0.38)
			if audible and absf(previous_velocity_y) > 0.5 and absf(float(states[id].get("velocity_y", 0.0))) <= 0.5:
				AudioManager.play_positional_cue("land", actors[id].global_position, null, 0.28)
			if previous_jumps == 1 and int(states[id].get("jumps", 0)) >= 2:
				actors[id].trigger_double_jump(float(states[id].get("double_jump_direction", 1.0)), actors[id].global_position, audible)
			actors[id].position = states[id]["position"]
			actors[id].set_walking(float(states[id].get("velocity_x", 0.0)) / maxf(1.0, MOTION.CONFIG.move_speed), int(states[id].get("jumps", 0)) == 0 and absf(float(states[id].get("velocity_y", 0.0))) < 0.5)
			actors[id].set_crouching(bool(states[id].get("crouching", false)))
			actors[id].set_facing_direction(float(states[id]["move"]))

func _whistle(id: int) -> void:
	if not actors.has(id): return
	actors[id].whistle_time = 0.35
	if actors[id].is_visible_in_tree(): AudioManager.play_positional_cue("whistle", actors[id].global_position, null, 0.48)

func _exit_tree() -> void:
	if is_instance_valid(audio_listener) and audio_listener.is_current(): audio_listener.clear_current()

func _close() -> void:
	_hide_item_hover()
	_restore_trial_appearance()
	modal.visible = false
	capture_action = -1
	held.clear()
	crouch_keys[KEY_S] = false
	crouch_keys[KEY_DOWN] = false
	for id in states: states[id]["crouching"] = false
	if mode == 2 and NetworkSession.active: NetworkSession.lobby_control("crouch", 0)

func _section(title: String) -> VBoxContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color("345653")
	style.set_corner_radius_all(12)
	style.set_border_width_all(1)
	style.border_color = Color("68877c")
	card.add_theme_stylebox_override("panel", style)
	section_grid.add_child(card)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 18)
	card.add_child(margin)
	form = VBoxContainer.new()
	form.add_theme_constant_override("separation", 10)
	margin.add_child(form)
	var heading := _add_text(form, title, 22)
	heading.add_theme_color_override("font_color", Color("ffe7ae"))
	return form

func _open(kind: String, slot: int) -> void:
	_hide_item_hover()
	var is_new_interaction := not modal.visible or modal_kind != kind
	if is_new_interaction and kind in ["衣柜", "种子摊"]:
		shop_selection = ""
		shop_quantity = 1
	for child in section_grid.get_children():
		section_grid.remove_child(child)
		child.queue_free()
	modal.visible = true
	modal_owner = slot
	inventory_owner = slot if mode == 1 else 1
	modal_kind = kind
	held.clear()
	crouch_keys[KEY_S] = false
	crouch_keys[KEY_DOWN] = false
	for id in states: states[id]["crouching"] = false
	if mode == 2 and NetworkSession.active: NetworkSession.lobby_control("crouch", 0)
	if is_new_interaction: AudioManager.play_cue("interact", null, 0.7)
	modal_heading.text = "P%s · %s" % [slot, GameSettings.text(kind)]
	status_label.text = GameSettings.text(status_message)
	status_label.visible = not status_message.is_empty()
	if kind == "衣柜":
		_wardrobe(slot)
	elif kind == "电脑": _computer(slot)
	elif kind == "种子摊": _seed_shop()
	elif kind.begins_with("种植地 "):
		modal.visible = false
		_interact_with_plot(garden_actor_id, int(kind.get_slice(" ", 1)) - 1)
	else: _door()
	section_grid.columns = 1 if section_grid.get_child_count() == 1 or size.x < 1120 else 2
	_layout()

func _garden_changed() -> void:
	_refresh_inventory()
	if is_instance_valid(backyard): backyard.queue_redraw()
	for id in _local_ids():
		if actors.has(id):
			var slot: int = id if mode == 1 else 1
			actors[id].set_player_name(profile_names[slot - 1])
	if is_instance_valid(modal): _layout()

func _garden_notice() -> void:
	if not GardenSave.storage_error.is_empty():
		var error_label := _add_text(form, GardenSave.storage_error)
		error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	elif GardenSave.recovered_backup:
		_add_text(form, "已读取上一份有效存档备份。")

func _plant_icon(parent: Node, id: String) -> void:
	var icon = GARDEN_ICON.new()
	icon.kind = id
	icon.custom_minimum_size = Vector2(120, 112)
	parent.add_child(icon)

func _garden_action(action: Callable, success: String, select_after := "") -> void:
	garden_actor_id = modal_owner if mode == 1 else (NetworkSession.local_player_id() if NetworkSession.active else 1)
	inventory_owner = modal_owner if mode == 1 else 1
	var error := str(action.call())
	_status(success if error.is_empty() else error)
	if error.is_empty() and not select_after.is_empty(): selected_item = select_after
	_open(modal_kind, modal_owner)

func _shop_grid(parent: VBoxContainer) -> GridContainer:
	shop_grid = GridContainer.new()
	shop_grid.columns = 9
	shop_grid.add_theme_constant_override("h_separation", 6)
	shop_grid.add_theme_constant_override("v_separation", 6)
	shop_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(shop_grid)
	return shop_grid

func _shop_item_tile(parent: GridContainer, title: String, description: String, icon_type: String, icon_value: Variant, tint: Color, count_text: String, selected: bool, callback: Callable) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(INVENTORY_SLOT_SIZE, INVENTORY_SLOT_SIZE)
	button.add_theme_stylebox_override("normal", _inventory_tile_style(selected))
	button.add_theme_stylebox_override("hover", _inventory_tile_style(selected))
	button.add_theme_stylebox_override("pressed", _inventory_tile_style(true))
	var body := Control.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(body)
	if icon_type in ["plant", "seed"]:
		var icon = GARDEN_ICON.new()
		icon.kind = "seed:" + str(icon_value) if icon_type == "seed" else str(icon_value)
		icon.position = Vector2(8, 5)
		icon.size = Vector2(52, 52)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(icon)
	elif icon_type == "dye":
		var bubble = DYE_BUBBLE_ICON.new()
		bubble.bubble_color = tint
		bubble.position = Vector2(8, 5)
		bubble.size = Vector2(52, 52)
		bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(bubble)
	else:
		var sprite := TextureRect.new()
		sprite.texture = icon_value as Texture2D
		sprite.modulate = tint
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.position = Vector2(7, 7)
		sprite.size = Vector2(54, 50)
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(sprite)
	if not count_text.is_empty():
		var count_label := Label.new()
		count_label.text = count_text
		count_label.position = Vector2(34, 47)
		count_label.size = Vector2(30, 18)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.add_theme_font_size_override("font_size", 14)
		count_label.add_theme_color_override("font_color", Color.WHITE)
		count_label.add_theme_color_override("font_outline_color", Color("263b3d"))
		count_label.add_theme_constant_override("outline_size", 3)
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(count_label)
	button.pressed.connect(callback)
	_bind_item_hover(button, title, description)
	parent.add_child(button)

func _fill_shop_slots(grid: GridContainer) -> void:
	while grid.get_child_count() < INVENTORY_ITEM_SLOTS:
		_inventory_empty_slot(grid)

func _select_shop_item(key: String) -> void:
	shop_selection = key
	_open(modal_kind, modal_owner)

func _seed_shop() -> void:
	_section("种子与斯马特")
	_add_text(form, "当前余额：%s 斯马特" % GardenSave.smurt, 20)
	_garden_notice()
	var grid := _shop_grid(form)
	if not shop_selection.begins_with("seed:") or not PLANTS.PLANTS.has(shop_selection.get_slice(":", 1)):
		shop_selection = ""
	for id in PLANTS.PLANTS:
		var shop_plant_id := str(id)
		var shop_plant_info: Dictionary = PLANTS.PLANTS[id]
		var shop_item_key := "seed:%s" % shop_plant_id
		var shop_plant_name := str(shop_plant_info["name"])
		var shop_seed_count := int(GardenSave.seeds.get(shop_plant_id, 0))
		_shop_item_tile(grid, GameSettings.text("种子：") + GameSettings.text(shop_plant_name), _item_description("seed", shop_plant_id), "seed", shop_plant_id, Color.WHITE, str(shop_seed_count) if shop_seed_count > 0 else "", shop_selection == shop_item_key, Callable(self, "_select_shop_item").bind(shop_item_key))
	_fill_shop_slots(grid)
	if shop_selection.is_empty():
		var no_selection_purchase := _button("确认购买", func(): pass)
		no_selection_purchase.disabled = true
		return
	var selected_plant_id := shop_selection.get_slice(":", 1)
	var selected_plant_info: Dictionary = PLANTS.PLANTS[selected_plant_id]
	var selected_plant_name := str(selected_plant_info["name"])
	_add_text(form, selected_plant_name, 20)
	var quantity_row := HBoxContainer.new()
	quantity_row.add_theme_constant_override("separation", 12)
	form.add_child(quantity_row)
	_add_text(quantity_row, "购买数量", 17)
	var quantity := OptionButton.new()
	quantity.add_item(GameSettings.text("1 个"))
	quantity.add_item(GameSettings.text("5 个"))
	quantity.select(0 if shop_quantity == 1 else 1)
	quantity.item_selected.connect(func(index: int): shop_quantity = 1 if index == 0 else 5; _open("种子摊", modal_owner))
	quantity_row.add_child(quantity)
	var total_price := int(selected_plant_info["seed_price"]) * shop_quantity
	_add_text(form, "价格：%s 斯马特" % total_price, 16)
	var success_template := "已购买一份%s种子。" if shop_quantity == 1 else "已购买五份%s种子。"
	var success := GameSettings.text(success_template) % GameSettings.text(selected_plant_name)
	var purchase := _button("确认购买 · %s 斯马特" % total_price, func(): _garden_action(func(): return GardenSave.buy_seed(selected_plant_id, shop_quantity), success, "seed:%s" % selected_plant_id))
	purchase.disabled = not GardenSave.writable or GardenSave.smurt < total_price

func _wardrobe(slot: int) -> void:
	if shop_tab not in ["hats", "dyes"]: shop_tab = "hats"
	if shop_tab == "hats" and (not shop_selection.begins_with("hat:") or int(shop_selection.get_slice(":", 1)) <= 0 or int(shop_selection.get_slice(":", 1)) >= HATS.hats.size()): shop_selection = ""
	if shop_tab == "dyes" and (not shop_selection.begins_with("dye:") or int(shop_selection.get_slice(":", 1)) < 0 or int(shop_selection.get_slice(":", 1)) >= SKINS.skins.size()): shop_selection = ""
	_section("衣柜")
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	form.add_child(header)
	var hats_button := Button.new()
	hats_button.text = GameSettings.text("帽子")
	hats_button.add_theme_stylebox_override("normal", _inventory_tile_style(shop_tab == "hats"))
	hats_button.add_theme_stylebox_override("hover", _inventory_tile_style(shop_tab == "hats"))
	hats_button.pressed.connect(func(): shop_tab = "hats"; shop_selection = ""; _open("衣柜", slot))
	header.add_child(hats_button)
	var dyes_button := Button.new()
	dyes_button.text = GameSettings.text("染色泡泡")
	dyes_button.add_theme_stylebox_override("normal", _inventory_tile_style(shop_tab == "dyes"))
	dyes_button.add_theme_stylebox_override("hover", _inventory_tile_style(shop_tab == "dyes"))
	dyes_button.pressed.connect(func(): shop_tab = "dyes"; shop_selection = ""; _open("衣柜", slot))
	header.add_child(dyes_button)
	_add_text(form, "当前余额：%s 斯马特" % GardenSave.smurt, 18)
	_garden_notice()
	var grid := _shop_grid(form)
	if shop_tab == "hats":
		for hat_index in range(1, HATS.hats.size()):
			var shop_hat_id := hat_index
			var shop_hat: WuppoCharacterHat = HATS.hats[shop_hat_id]
			var shop_hat_key := "hat:%s" % shop_hat_id
			var shop_hat_owned := shop_hat_id in GardenSave.owned_hats
			_shop_item_tile(grid, str(shop_hat.display_name), _item_description("hat"), "hat", shop_hat.texture, shop_hat.tint, "✓" if shop_hat_owned else "", shop_selection == shop_hat_key, Callable(self, "_select_shop_item").bind(shop_hat_key))
	else:
		for skin_index in SKINS.skins.size():
			var shop_skin_id := skin_index
			var shop_skin: WuppoCharacterSkin = SKINS.skins[shop_skin_id]
			var shop_dye_key := "dye:%s" % shop_skin_id
			var shop_dye_count := int(GardenSave.dyes.get(str(shop_skin_id), 0))
			_shop_item_tile(grid, GameSettings.text("%s染色泡泡") % GameSettings.text(str(shop_skin.display_name)), _item_description("dye"), "dye", shop_skin_id, shop_skin.body_tint, str(shop_dye_count) if shop_dye_count > 0 else "", shop_selection == shop_dye_key, Callable(self, "_select_shop_item").bind(shop_dye_key))
	_fill_shop_slots(grid)
	if shop_selection.is_empty():
		var no_selection_purchase := _button("确认购买", func(): pass)
		no_selection_purchase.disabled = true
		return
	var item_id := int(shop_selection.get_slice(":", 1))
	var divider := HSeparator.new()
	form.add_child(divider)
	if shop_tab == "hats":
		item_id = clampi(item_id, 1, HATS.hats.size() - 1)
		var selected_hat: WuppoCharacterHat = HATS.hats[item_id]
		var is_owned := item_id in GardenSave.owned_hats
		_add_text(form, str(selected_hat.display_name), 19)
		_add_text(form, "已购买" if is_owned else "价格：%s 斯马特" % ECONOMY.PRICES[item_id], 16)
		_button("试戴", func(): _try_hat(slot, item_id))
		var hat_purchase := _button("已购买" if is_owned else "确认购买 · %s 斯马特" % ECONOMY.PRICES[item_id], func(): _garden_action(func(): return GardenSave.buy_hat(item_id), GameSettings.text("买下了%s。") % GameSettings.text(str(selected_hat.display_name))))
		hat_purchase.disabled = is_owned or not GardenSave.writable or GardenSave.smurt < int(ECONOMY.PRICES[item_id])
	else:
		item_id = clampi(item_id, 0, SKINS.skins.size() - 1)
		var selected_skin: WuppoCharacterSkin = SKINS.skins[item_id]
		var selected_dye_count := int(GardenSave.dyes.get(str(item_id), 0))
		_add_text(form, GameSettings.text("%s染色泡泡") % GameSettings.text(str(selected_skin.display_name)), 19)
		_add_text(form, "价格：%s 斯马特 · 库存：%s" % [ECONOMY.DYE_BUBBLE_PRICE, selected_dye_count], 16)
		_button("试色", func(): _try_skin(slot, item_id))
		var dye_purchase := _button("确认购买 · %s 斯马特" % ECONOMY.DYE_BUBBLE_PRICE, func(): _garden_action(func(): return GardenSave.buy_dye(item_id), GameSettings.text("买下了%s染色泡泡。") % GameSettings.text(str(selected_skin.display_name)), "dye:%s" % item_id))
		dye_purchase.disabled = not GardenSave.writable or GardenSave.smurt < ECONOMY.DYE_BUBBLE_PRICE

func _appearance_grid(parent: VBoxContainer, columns: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(grid)
	return grid

func _appearance_tile(parent: GridContainer, texture: Texture2D, tint: Color, title: String, selected: bool, callback: Callable) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(132, 122)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = GameSettings.text(title)
	button.add_theme_stylebox_override("normal", _appearance_tile_style(selected, false))
	button.add_theme_stylebox_override("hover", _appearance_tile_style(selected, true))
	button.add_theme_stylebox_override("pressed", _appearance_tile_style(true, true))
	button.add_theme_stylebox_override("focus", _appearance_tile_style(selected, true))
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_theme_constant_override("separation", 2)
	button.add_child(content)
	var preview_area := CenterContainer.new()
	preview_area.custom_minimum_size.y = 78
	preview_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(preview_area)
	if texture != null:
		var preview := TextureRect.new()
		preview.texture = texture
		preview.modulate = tint
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.custom_minimum_size = Vector2(64, 68)
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview_area.add_child(preview)
	else:
		var no_hat := Label.new()
		no_hat.text = GameSettings.text("无")
		no_hat.add_theme_font_size_override("font_size", 32)
		no_hat.add_theme_color_override("font_color", Color("f4e7c8"))
		no_hat.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview_area.add_child(no_hat)
	var caption := Label.new()
	caption.text = GameSettings.text(title) + ("  ✓" if selected else "")
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 16)
	caption.add_theme_color_override("font_color", Color("fff4d8"))
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(caption)
	button.pressed.connect(callback)
	parent.add_child(button)

func _appearance_tile_style(selected: bool, hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("45685e") if hovered else Color("34554d")
	style.set_corner_radius_all(12)
	style.set_border_width_all(4 if selected else 1)
	style.border_color = Color("ffd16f") if selected else Color("769187")
	return style

func _profile_name_changed(slot: int, value: String) -> void:
	profile_names[slot - 1] = value.strip_edges().left(24)
	var error := GardenSave.save_profile(slot, profile_names[slot - 1], int(GameSettings.profiles[slot]["skin"]), int(GameSettings.profiles[slot]["hat"]))
	if not error.is_empty(): _status(error)
	var player_id := slot if mode == 1 else (NetworkSession.local_player_id() if NetworkSession.active else 1)
	if actors.has(player_id): actors[player_id].set_player_name(profile_names[slot - 1])

func _is_host(slot := 1) -> bool:
	return slot == 1 and (not NetworkSession.active or multiplayer.is_server())

func _computer(slot: int) -> void:
	var key_section: VBoxContainer
	_section("语言")
	_option("界面语言", ["中文", "英文"], 0 if GameSettings.language == "zh" else 1, func(index: int): _change_language("zh" if index == 0 else "en", slot))
	_section("游玩模式")
	if _is_host(slot):
		_option("当前房间模式", ["单人", "本地双人", "多人"], mode, _change_mode)
	else: _add_text(form, "房间模式由房主 P1 设置。")
	if mode == 2:
		_section("联机房间")
		_add_text(form, NetworkSession.connection_text())
		if not NetworkSession.active:
			_button("创建联机房间（最多 4 人）", func(): NetworkSession.host(profile_names[0]); _open("电脑", slot))
			var address := LineEdit.new()
			address.placeholder_text = GameSettings.text("房主 LAN / VPN 地址，同电脑用 127.0.0.1")
			form.add_child(address)
			_button("加入房间", func():
				if address.text.strip_edges().is_empty(): _status("请输入房主地址。")
				else: NetworkSession.join(address.text, profile_names[0]); _close())
		else:
			_add_text(form, GameSettings.text("房间状态：") + GameSettings.text(NetworkSession.phase) + (" · %s / 4 players" % NetworkSession.players.size() if GameSettings.language == "en" else " · %s / 4 人" % NetworkSession.players.size()))
			for id in NetworkSession.players:
				var info: Dictionary = NetworkSession.players[id]
				_add_text(form, "%s · %s" % [info["name"], "已准备" if info.get("ready", false) else "未准备"], 18, [str(info["name"])])
			_button("准备 / 取消准备", func():
				var info: Dictionary = NetworkSession.players.get(NetworkSession.local_player_id(), {})
				NetworkSession.set_ready(not bool(info.get("ready", false)))
				_open("电脑", slot))
			if multiplayer.is_server():
				if NetworkSession.game_mode == "bubble_race":
					_option("房间比赛时长", ["30 秒", "60 秒", "90 秒"], NetworkSession.DURATIONS.find(NetworkSession.room_duration), func(index: int): NetworkSession.set_duration(NetworkSession.DURATIONS[index]))
				var addresses := PackedStringArray()
				for address in IP.get_local_addresses():
					if not address.contains(":") and not address.begins_with("127."): addresses.append(address)
				var addresses_label := _add_text(form, "主机地址：" + ", ".join(addresses) + "\nUDP 7000 · 请确认使用双方可访问的网卡地址")
				addresses_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_button("离开联机房间", func(): NetworkSession.leave(); _close())
	_section("玩家资料")
	var name_edit := LineEdit.new()
	name_edit.text = profile_names[slot - 1]
	name_edit.placeholder_text = GameSettings.text("玩家昵称")
	name_edit.editable = not NetworkSession.active
	name_edit.text_changed.connect(func(value: String): _profile_name_changed(slot, value))
	form.add_child(name_edit)
	key_section = _section("操作键位")
	_add_text(form, "个人键位（点击后按键或点击鼠标，Esc 取消）")
	for action in 5:
		var button := _button("%s：%s" % [GameSettings.text(GameSettings.ACTION_NAMES[action]), GameSettings.key_name(GameSettings.keys(slot)[action])], func(): pass)
		button.pressed.connect(func(): capture_action = action; capture_button = button; button.text = GameSettings.text("请按新键位……"))
	_button("恢复自己的默认键位", func(): GameSettings.profiles[slot]["keys"] = GameSettings.DEFAULT_KEYS[slot - 1].duplicate(); GameSettings.save(); _open("电脑", slot))
	_section("蓄力显示")
	_option("自己的蓄力显示", ["圆形 · 跟随角色", "条形 · 屏幕下方"], 0 if GameSettings.uses_circular(slot) else 1, func(index: int): GameSettings.profiles[slot]["circular"] = index == 0; GameSettings.circular_meters = GameSettings.uses_circular(1); GameSettings.save())
	_section("声音")
	_add_text(form, "音量（本地双人共用音响，取两人设置平均值）")
	var volume := HSlider.new()
	volume.min_value = 0
	volume.max_value = 1
	volume.step = 0.05
	volume.value = float(GameSettings.profiles[slot]["volume"])
	volume.value_changed.connect(func(value: float): GameSettings.profiles[slot]["volume"] = value; GameSettings.apply_volume(mode == 1); GameSettings.save())
	form.add_child(volume)
	var mute := CheckButton.new()
	mute.text = GameSettings.text("本机静音")
	mute.button_pressed = AudioManager.muted
	mute.toggled.connect(AudioManager.set_muted)
	form.add_child(mute)
	# Keep `form` pointing at the key controls for existing room tooling.
	form = key_section

func _change_language(value: String, slot: int) -> void:
	GameSettings.set_language(value)
	_build_inventory()
	_refresh_inventory()
	_open("电脑", slot)

func _change_mode(value: int) -> void:
	if not _is_host(): return
	_close()
	if NetworkSession.active: await NetworkSession.leave()
	mode = value
	active_player_id = 1
	inventory_owner = 1
	_refresh()

func _door() -> void:
	_section("玩法和赛制")
	var game := _option("可玩的游戏", ["吹泡泡比赛", "弗纳克球 / 布里克球"], 1 if NetworkSession.game_mode == "mud_ball" else 0, func(index: int): NetworkSession.set_game_mode("mud_ball" if index == 1 else "bubble_race"); _open("门", modal_owner))
	game.disabled = not _is_host(modal_owner)
	if NetworkSession.game_mode == "mud_ball":
		var target_score := _option("获胜目标分数", ["5 分", "7 分", "10 分", "15 分"], NetworkSession.MUD_BALL_TARGETS.find(NetworkSession.mud_ball_target_score), func(index: int): NetworkSession.set_mud_ball_target_score(NetworkSession.MUD_BALL_TARGETS[index]); _open("门", modal_owner))
		target_score.disabled = not _is_host(modal_owner)
		_add_text(form, "身体顶球 · 落在对方半场得分 · 得分方发球 · 先到 %s 分获胜\n2 人 1v1 / 3 人 1v2 / 4 人 2v2" % NetworkSession.mud_ball_target_score)
	_add_text(form, "单人：与电脑伙伴练习\n本地双人：P1 与 P2 同屏对战\n多人：2–4 人，全部准备后由房主启动")
	if mode == 0:
		_option("练习伙伴难度", NetworkSession.PRACTICE_DIFFICULTY_NAMES, NetworkSession.practice_difficulty, func(index: int): NetworkSession.practice_difficulty = index)
		if NetworkSession.game_mode == "mud_ball":
			_add_text(form, "简单：反应稍慢，主要单跳接球\n普通：预判反弹，尝试二段跳救球\n困难：提前抢接落点，调整顶球方向回击")
		else:
			_add_text(form, "简单：较常蓄力失误，容易错过口哨，较少追跳\n普通：偶尔早放或迟哨，也会尝试完美泡泡\n困难：失误较少，快速反击并积极追上平台")
	if NetworkSession.game_mode == "bubble_race":
		var duration := _option("对局时长", ["30 秒", "60 秒", "90 秒"], NetworkSession.DURATIONS.find(NetworkSession.room_duration), func(index: int): NetworkSession.set_duration(NetworkSession.DURATIONS[index]))
		duration.disabled = not _is_host(modal_owner)
	if mode != 2: _button("启动比赛", _launch)
	if mode == 2:
		_section("联机房间")
		if not NetworkSession.active:
			_add_text(form, "先到电脑创建或加入联机房间。")
			return
		for id in NetworkSession.players:
			var info: Dictionary = NetworkSession.players[id]
			_add_text(form, "%s · %s" % [info["name"], "已准备" if info.get("ready", false) else "未准备"], 18, [str(info["name"])])
		_button("准备 / 取消准备", func():
			var info: Dictionary = NetworkSession.players.get(NetworkSession.local_player_id(), {})
			NetworkSession.set_ready(not bool(info.get("ready", false)))
			_open("门", modal_owner))
		var player_names: Array = []
		for info in NetworkSession.players.values(): player_names.append(str(info.get("name", "")))
		_add_text(form, NetworkSession.start_block_reason(), 18, player_names)
		if _is_host(): _button("启动比赛", _launch).disabled = not NetworkSession.can_start()

func _launch() -> void:
	_close()
	if mode == 0:
		NetworkSession.start_practice(profile_names[0], NetworkSession.practice_difficulty)
	elif mode == 1:
		NetworkSession.start_local_duel(profile_names[0], profile_names[1], int(GameSettings.profiles[2]["skin"]), int(GameSettings.profiles[2]["hat"]))
	else: NetworkSession.start_match()

func _phase(value: String) -> void:
	if value == "RESULTS" and last_rewarded_match_id != NetworkSession.match_id:
		last_rewarded_match_id = NetworkSession.match_id
		GardenSave.award_match_reward(NetworkSession.match_id)
	var in_match := value != "LOBBY"
	if inventory_open: _set_inventory_open(false)
	room.visible = not in_match
	backyard.visible = not in_match
	_layout()
	_close()
	loading.visible = value == "LOADING"
	if value == "LOADING":
		match_smurt_indicator = null
		match_smurt_actor = null
		loading_text.text = GameSettings.controls_text(1)
		if NetworkSession.local_duel: loading_text.text += "\n" + GameSettings.controls_text(2)
		var tip: String = ("Hit the ball with your body. The scoring team serves from its side. First to %s points wins." % NetworkSession.mud_ball_target_score if GameSettings.language == "en" else "用身体顶球，得分方从自己半场上方发球，先到 %s 分获胜。" % NetworkSession.mud_ball_target_score) if NetworkSession.game_mode == "mud_ball" else TIPS.pick_random()
		loading_text.text += "\n\n" + GameSettings.text("小提示：") + GameSettings.text(tip)
		_refresh()
		if not is_instance_valid(match_view): _create_match.call_deferred(NetworkSession.match_id)
	elif value == "LOBBY":
		AudioManager.play_music("lobby")
		if is_instance_valid(match_view):
			remove_child(match_view)
			match_view.queue_free()
			match_view = null
		# Offline participants remain in the room; the practice bot belongs to matches only.
		if NetworkSession.active and (NetworkSession.practice or NetworkSession.local_duel):
			NetworkSession._close_session("已返回休息室。")
		_refresh()

func _create_match(round_id: int) -> void:
	await get_tree().process_frame
	if NetworkSession.phase != "LOADING" or NetworkSession.match_id != round_id or is_instance_valid(match_view): return
	match_view = (BALL_SCENE if NetworkSession.game_mode == "mud_ball" else MATCH_SCENE).instantiate()
	add_child(match_view)
	move_child(loading, get_child_count() - 1)


