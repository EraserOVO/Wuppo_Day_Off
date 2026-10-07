extends Node2D
const MOTION = preload("res://core/player_motion.gd")

const WORLD = preload("res://core/world_layout.gd")
const ACTOR = preload("res://actors/wum/wum.tscn")
const CONFIG = preload("res://modes/bubble_race/bubble_config.tres")
const RULES = preload("res://modes/bubble_race/bubble_rules.gd")
const BUFFER = preload("res://core/snapshot_buffer.gd")
const CIRCULAR_METER = preload("res://ui/circular_meter.gd")
const EXIT_DIALOG = preload("res://ui/rounded_exit_dialog.gd")
const PLAYER_INPUT = preload("res://core/match_player_input.gd")
@export var character_skin: WuppoCharacterSkin
@export var skin_catalog: WuppoSkinCatalog
@export var hat_catalog: WuppoHatCatalog
@export var floor_y: float = WORLD.FLOOR_Y
@export var stage_left: float = 220.0
@export var stage_right: float = 1580.0
var actors: Dictionary = {}
var remaining := 0.0
var pressed := false
var keyboard_held := false
var scores: Dictionary = {}
var last_tick := -1
var results_shown := false
var local_state: Dictionary = {}
var snapshot_age := 0.0
var local_held: Dictionary = {1: false, 2: false}
var second_meter: VBoxContainer
var circular_meters: Dictionary = {}
var circular_meter_sides: Dictionary = {}
var circular_meter_previous_positions: Dictionary = {}
var player_input = PLAYER_INPUT.new()
var position_buffers: Dictionary = {}
var snapshot_time := 0.0
var predicted_bubble_action_at := -1.0
var predicted_bubble_charge := 0.0
var predicted_bubble_last_time := 0.0
var predicted_bubble_rate := 1.0
var shown_epoch := -1
var network_status: Label
var score_labels: Dictionary = {}
var feedback_entries: Dictionary = {}
const FEEDBACK_LIFETIME := 2.3
const FEEDBACK_SPACING := 25.0
var audio_listener: AudioListener2D
var exit_confirmation

func _ready() -> void:
	AudioManager.play_music("match")
	get_viewport().size_changed.connect(_layout_display)
	NetworkSession.snapshot_received.connect(_snapshot)
	NetworkSession.phase_changed.connect(_phase)
	NetworkSession.gameplay_event.connect(_event)
	NetworkSession.prediction_changed.connect(_prediction)
	NetworkSession.pause_changed.connect(_network_pause)
	NetworkSession.bubble_input_changed.connect(_bubble_prediction)
	$HUD/Panel/ReturnButton.pressed.connect(_replay)
	$HUD/Panel/ExitButton.pressed.connect(_exit_match)
	$HUD/Panel/ExitButton.text = GameSettings.text("退出对局")
	exit_confirmation = EXIT_DIALOG.new()
	exit_confirmation.confirmed.connect(_confirm_exit)
	exit_confirmation.dismissed.connect(_resume_after_pause_dialog)
	$HUD.add_child(exit_confirmation)
	network_status = Label.new()
	network_status.position = Vector2(330, 56)
	network_status.size = Vector2(260, 22)
	network_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	network_status.add_theme_font_size_override("font_size", 16)
	$HUD.add_child(network_status)
	audio_listener = AudioListener2D.new()
	audio_listener.name = "PlayerAudioListener"
	add_child(audio_listener)
	audio_listener.make_current()
	_add_perfect_mark($HUD/Meter/Size)
	if NetworkSession.local_duel:
		$HUD/Meter.offset_left = 32.0
		$HUD/Meter.offset_top = 596.0
		$HUD/Meter.offset_right = 466.0
		$HUD/Meter.offset_bottom = 630.0
		second_meter = $HUD/Meter.duplicate()
		second_meter.name = "SecondMeter"
		$HUD.add_child(second_meter)
		second_meter.offset_left = 494.0
		second_meter.offset_top = 596.0
		second_meter.offset_right = 928.0
		second_meter.offset_bottom = 630.0
	_sync_charge_segment_corners($HUD/Meter)
	if is_instance_valid(second_meter):
		_sync_charge_segment_corners(second_meter)
	var ids: Array = NetworkSession.players.keys()
	var skins: Array[WuppoCharacterSkin] = []
	var hats: Array[WuppoCharacterHat] = []
	if skin_catalog != null: skins = skin_catalog.skins
	if hat_catalog != null: hats = hat_catalog.hats
	ids.sort()
	for index in ids.size():
		var peer_id: int = ids[index]
		var actor = ACTOR.instantiate()
		actor.scale = Vector2.ONE * WORLD.ACTOR_SCALE
		var skin_id := int(NetworkSession.players[peer_id].get("skin", 0))
		var hat_id := int(NetworkSession.players[peer_id].get("hat", 0))
		actor.skin = skins[clampi(skin_id, 0, skins.size() - 1)] if not skins.is_empty() else character_skin
		actor.hat = hats[clampi(hat_id, 0, hats.size() - 1)] if not hats.is_empty() else null
		actor.always_show_tube = true
		actor.is_local_player = NetworkSession.local_duel or peer_id == NetworkSession.local_player_id()
		actor.mouse_gaze_enabled = peer_id == NetworkSession.local_player_id()
		actor.externally_positioned = not NetworkSession.practice and not NetworkSession.local_duel
		position_buffers[peer_id] = BUFFER.new()
		actor.position = MOTION.spawn_position(lerpf(stage_left, stage_right, float(index) / maxf(1.0, ids.size() - 1.0)))
		$Players.add_child(actor)
		var player_name := str(NetworkSession.players[peer_id]["name"])
		if player_name in ["练习伙伴", "电脑伙伴"]: player_name = GameSettings.text(player_name)
		actor.set_player_name(player_name)
		actors[peer_id] = actor
	_setup_circular_meters()
	_update_circular_meter_positions()
	_update_audio_listener()
	_setup_score_labels()
	_phase(NetworkSession.phase)
	_layout_display()
	_confirm_scene_loaded.call_deferred()

func _layout_display() -> void:
	if not is_inside_tree(): return
	var view := get_viewport_rect().size
	# Keep the full shared arena visible using one scale on both axes.
	var zoom_factor := WORLD.fit_scale(view)
	$ArenaCamera.zoom = Vector2.ONE * zoom_factor
	$ArenaCamera.force_update_scroll()
	var timer: Label = $HUD/Timer
	if NetworkSession.phase == "COUNTDOWN":
		timer.position = Vector2.ZERO
		timer.size = view
	else:
		timer.position = Vector2((view.x - 180.0) * 0.5, 0.0)
		timer.size = Vector2(180, 40)
	network_status.position = Vector2((view.x - 260.0) * 0.5, 56)
	$HUD/Panel.position = (view - Vector2(780, 440)) * 0.5
	$HUD/Panel.size = Vector2(780, 440)
	if NetworkSession.local_duel:
		$HUD/Meter.position = Vector2(32, view.y - 44)
		$HUD/Meter.size.x = (view.x - 96.0) * 0.5
		if is_instance_valid(second_meter):
			second_meter.position = Vector2(view.x * 0.5 + 16, view.y - 44)
			second_meter.size.x = (view.x - 96.0) * 0.5
	else:
		$HUD/Meter.position = Vector2((view.x - 600.0) * 0.5, view.y - 44)
	if not score_labels.is_empty(): _update_score_labels()

func _exit_tree() -> void:
	# A removed scene remains alive until queue_free; stop callbacks immediately.
	if is_instance_valid(audio_listener) and audio_listener.is_current(): audio_listener.clear_current()
	if NetworkSession.snapshot_received.is_connected(_snapshot):
		NetworkSession.snapshot_received.disconnect(_snapshot)
	if NetworkSession.phase_changed.is_connected(_phase):
		NetworkSession.phase_changed.disconnect(_phase)
	if NetworkSession.gameplay_event.is_connected(_event):
		NetworkSession.gameplay_event.disconnect(_event)
	if NetworkSession.prediction_changed.is_connected(_prediction): NetworkSession.prediction_changed.disconnect(_prediction)
	if NetworkSession.pause_changed.is_connected(_network_pause): NetworkSession.pause_changed.disconnect(_network_pause)
	if NetworkSession.bubble_input_changed.is_connected(_bubble_prediction): NetworkSession.bubble_input_changed.disconnect(_bubble_prediction)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		if exit_confirmation.is_open:
			exit_confirmation.close_dialog()
		elif NetworkSession.phase == "PLAYING" and (NetworkSession.practice or NetworkSession.local_duel):
			NetworkSession.toggle_local_pause()
			exit_confirmation.show_dialog("游戏已暂停", "对局已暂停。继续游戏，或退出当前对局返回大厅。", "退出对局")
		else:
			exit_confirmation.show_dialog("退出对局？", "确定退出当前对局并返回大厅吗？", "退出对局")
		get_viewport().set_input_as_handled()
		return
	if exit_confirmation.is_open or NetworkSession.phase not in ["PLAYING", "COUNTDOWN"] or NetworkSession.paused or event.is_echo(): return
	player_input.handle(event, actors, NetworkSession.local_duel, Callable(self, "_handle_bubble_input"))

func _handle_bubble_input(slot: int, event: InputEvent) -> void:
	if NetworkSession.local_duel:
		if bool(local_held[slot]) == event.is_pressed(): return
		local_held[slot] = event.is_pressed()
		if NetworkSession.phase == "PLAYING": NetworkSession.submit_local_input(slot, event.is_pressed())
	else:
		keyboard_held = event.is_pressed()
		if NetworkSession.phase == "PLAYING": _update_input()

func _confirm_scene_loaded() -> void:
	var round_id: int = NetworkSession.match_id
	await get_tree().create_timer(2.0).timeout
	if not is_inside_tree() or NetworkSession.match_id != round_id or NetworkSession.phase != "LOADING": return
	NetworkSession.confirm_loaded()
func _update_input() -> void:
	var wanted := keyboard_held
	if wanted == pressed or NetworkSession.phase != "PLAYING": return
	pressed = wanted
	NetworkSession.submit_input(pressed)

func _confirm_exit() -> void:
	NetworkSession.leave()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		player_input.release(actors, NetworkSession.local_duel)
		for peer_id in local_held:
			if local_held[peer_id]: NetworkSession.submit_local_input(peer_id, false)
			local_held[peer_id] = false
		keyboard_held = false
		if pressed:
			pressed = false
			NetworkSession.submit_input(false)

func _phase(value: String) -> void:
	if not is_inside_tree(): return
	var timer_label: Label = $HUD/Timer
	if value == "COUNTDOWN":
		timer_label.position = Vector2.ZERO
		timer_label.size = get_viewport_rect().size
		timer_label.add_theme_font_size_override("font_size", 96)
		timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		timer_label.z_index = 10
	else:
		timer_label.position = Vector2(390.0, 0.0)
		timer_label.size = Vector2(180.0, 40.0)
		timer_label.add_theme_font_size_override("font_size", 24)
		timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		timer_label.z_index = 0
	for actor in actors.values():
		actor.warning_enabled = value == "PLAYING"
		if value == "RESULTS": actor.celebrate(false)
	for score_label in score_labels.values(): score_label.visible = value == "PLAYING"
	if value == "PLAYING":
		player_input.activate(actors, NetworkSession.local_duel)
		if NetworkSession.local_duel:
			for peer_id in local_held:
				if local_held[peer_id]: NetworkSession.submit_local_input(peer_id, true)
		else:
			_update_input()
	elif value in ["LOBBY", "LOADING", "RESULTS"]:
		player_input.clear()
		local_held = {1: false, 2: false}
		pressed = false
		keyboard_held = false
	$HUD/Panel.visible = value == "RESULTS"
	$HUD/Panel/ReturnButton.visible = value == "RESULTS" and (NetworkSession.practice or NetworkSession.local_duel or multiplayer.is_server())
	$HUD/Panel/ExitButton.visible = value == "RESULTS"
	$HUD/Panel/Result.visible = value == "RESULTS"
	$HUD/Panel/ReturnButton.text = GameSettings.text("再来一局" if NetworkSession.practice or NetworkSession.local_duel else "返回大厅，准备下一局")
	$HUD/Timer.visible = value in ["COUNTDOWN", "PLAYING", "RESULTS"]
	$HUD/OwnScore.visible = value == "PLAYING"
	$HUD/EnemyScore.visible = value == "PLAYING"
	var show_bars := value == "PLAYING" and not GameSettings.uses_circular(1)
	$HUD/Meter.visible = show_bars
	if is_instance_valid(second_meter): second_meter.visible = value == "PLAYING" and not GameSettings.uses_circular(2)
	for radial_meter in circular_meters.values(): radial_meter.visible = value == "PLAYING"
	if value == "LOADING": $HUD/Timer.text = GameSettings.text("等待所有玩家加载……")
	elif value == "RESULTS":
		$HUD/Timer.text = GameSettings.text("比赛结束")
	elif value == "PLAYING":
		AudioManager.play_cue("countdown")
	_layout_display()

func _snapshot(data: Dictionary) -> void:
	remaining = float(data.get("remaining", 0.0))
	snapshot_time = float(data.get("server_time", NetworkSession.server_now()))
	scores = data.get("players", {})
	if int(data.get("epoch", 0)) != shown_epoch:
		shown_epoch = int(data.get("epoch", 0))
		for id in actors:
			actors[id].last_event = int(scores.get(id, {}).get("event_id", 0))
			position_buffers[id].clear()
	for peer_id in actors.keys():
		if not NetworkSession.players.has(peer_id):
			actors[peer_id].queue_free()
			actors.erase(peer_id)
			position_buffers.erase(peer_id)
	for peer_id in scores:
		if not actors.has(peer_id): continue
		var presentation: Dictionary = scores[peer_id].duplicate(true)
		if not multiplayer.is_server() and peer_id == NetworkSession.local_player_id():
			for key in ["grounded", "crouching", "jumps", "velocity_y", "velocity_x"]:
				if NetworkSession.predictor.state.has(key): presentation[key] = NetworkSession.predictor.state[key]
		presentation["presentation_age"] = 0.0 if NetworkSession.paused else clampf(NetworkSession.server_now() - snapshot_time, 0.0, 0.25)
		if not multiplayer.is_server() and peer_id == NetworkSession.local_player_id() and int(presentation.get("input_ack", 0)) < NetworkSession.input_sequence:
			presentation["state"] = "blowing" if NetworkSession.bubble_pressed else "idle"
			var rate := CONFIG.crouch_blow_rate if bool(presentation.get("crouching", false)) else 1.0
			presentation["charge_rate"] = rate
			var predicted_charge := _advance_predicted_bubble_charge(rate) if NetworkSession.bubble_pressed else 0.0
			presentation["natural_charge"] = predicted_charge
			presentation["ratio"] = predicted_charge / maxf(0.1, float(presentation["limit"]))
			presentation["presentation_age"] = 0.0
		actors[peer_id].update_state(presentation, CONFIG.warning_ratio, CONFIG.danger_ratio, CONFIG.critical_ratio)
		if actors[peer_id].externally_positioned:
			if multiplayer.is_server(): actors[peer_id].position = presentation["position"]
			elif peer_id != NetworkSession.local_player_id(): position_buffers[peer_id].push(snapshot_time, presentation["position"])
	local_state = scores.get(NetworkSession.local_player_id(), {})
	_update_score_labels()
	snapshot_age = 0.0
	if data.get("phase", "") == "RESULTS": _show_results()

func _event(data: Dictionary) -> void:
	var peer_id := int(data.get("peer_id", 0))
	if actors.has(peer_id):
		_show_score_feedback(peer_id, data)
		actors[peer_id].play_event(data)
	if str(data.get("kind", "")) == "whistle":
		var whistle_position: Vector2 = data.get("position", Vector2.ZERO)
		for effect in $Players.get_children():
			if effect.has_method("whistle_pop"):
				effect.call("whistle_pop", whistle_position, CONFIG.whistle_radius)

func _process(delta: float) -> void:
	if NetworkSession.closing: return
	if not NetworkSession.paused:
		remaining = maxf(0.0, remaining - delta)
		snapshot_age += delta
	if not NetworkSession.practice and not NetworkSession.local_duel:
		network_status.text = GameSettings.text(NetworkSession.connection_text())
		if not multiplayer.is_server() and not NetworkSession.paused:
			for id in actors:
				if id == NetworkSession.local_player_id() or position_buffers[id].samples.is_empty(): continue
				position_buffers[id].delay = NetworkSession.interpolation_delay()
				actors[id].position = position_buffers[id].position_at(NetworkSession.server_now())
	_update_audio_listener()
	for peer_id in actors:
		if NetworkSession.local_duel or peer_id == NetworkSession.local_player_id():
			actors[peer_id].set_facing_direction(get_global_mouse_position().x - actors[peer_id].global_position.x)
	_update_score_feedback_entries()
	if NetworkSession.phase == "COUNTDOWN":
		var tick := ceili(remaining)
		$HUD/Timer.text = str(tick)
		if tick != last_tick and tick > 0:
			last_tick = tick
			AudioManager.play_cue("countdown")
	elif NetworkSession.phase == "PLAYING":
		_update_meter()
		_update_circular_meter_positions()
		$HUD/Timer.text = str(ceili(remaining))
		$HUD/Timer.modulate = Color(1, 0.7, 0.6) if remaining <= 10.0 else Color.WHITE

func _update_meter() -> void:
	if NetworkSession.local_duel:
		_update_player_meter($HUD/Meter, scores.get(1, {}), 1)
		_update_player_meter(second_meter, scores.get(2, {}), 2)
	else:
		_update_player_meter($HUD/Meter, local_state, NetworkSession.local_player_id())

func _update_audio_listener() -> void:
	if not is_instance_valid(audio_listener): return
	if NetworkSession.local_duel and actors.has(1) and actors.has(2):
		audio_listener.global_position = (actors[1].global_position + actors[2].global_position) * 0.5
	else:
		var local_id := NetworkSession.local_player_id()
		if actors.has(local_id): audio_listener.global_position = actors[local_id].global_position

func _update_player_meter(meter: VBoxContainer, state: Dictionary, peer_id: int) -> void:
	var blowing: bool = state.get("state", "") == "blowing"
	var held := float(state.get("natural_charge", state.get("held", 0.0)))
	var rate := float(state.get("charge_rate", 1.0))
	var limit := maxf(0.1, float(state.get("limit", CONFIG.bubble_seconds_min)))
	if blowing and not NetworkSession.paused:
		held += clampf(NetworkSession.server_now() - snapshot_time, 0.0, 0.25) * rate
	if not multiplayer.is_server() and peer_id == NetworkSession.local_player_id():
		rate = CONFIG.crouch_blow_rate if bool(NetworkSession.predictor.state.get("crouching", false)) else 1.0
		var input_pending := int(state.get("input_ack", 0)) < NetworkSession.input_sequence
		if input_pending: blowing = NetworkSession.bubble_pressed
		if blowing and NetworkSession.bubble_pressed:
			held = _advance_predicted_bubble_charge(rate)
		else:
			_reset_predicted_bubble_charge()
			if input_pending: held = 0.0
	var base_progress: float = RULES.ratio(held, limit) if blowing else 0.0
	var whistle_charge_addition: float = float(state.get("charge_bonus", 0.0)) if blowing else 0.0
	var progress := clampf(base_progress + whistle_charge_addition, 0.0, 1.0)
	var stage: int = RULES.warning_stage(progress, CONFIG.warning_ratio, CONFIG.danger_ratio, CONFIG.critical_ratio) if blowing else 0
	var charge_bar: ProgressBar = meter.get_node("Size")
	charge_bar.value = 0.0
	var own_region: Panel = charge_bar.get_node("OwnProgress")
	own_region.anchor_right = clampf(base_progress, 0.0, 1.0)
	own_region.self_modulate = [Color(0.65, 0.95, 1), Color(1, 0.95, 0.5), Color(1, 0.65, 0.4), Color(1, 0.4, 0.5)][stage]
	own_region.visible = blowing and base_progress > 0.0
	var bonus_region: Panel = charge_bar.get_node("WhistleBonus")
	bonus_region.anchor_left = clampf(base_progress - 0.01, 0.0, 1.0)
	bonus_region.anchor_right = progress
	bonus_region.visible = blowing and whistle_charge_addition > 0.0 and progress > base_progress
	var cooldown_duration := maxf(0.001, float(state.get("whistle_cooldown_duration", CONFIG.whistle_cooldown)))
	var cooldown_remaining := clampf(float(state.get("whistle_remaining", 0.0)), 0.0, cooldown_duration)
	if not NetworkSession.paused:
		cooldown_remaining = maxf(0.0, cooldown_remaining - clampf(NetworkSession.server_now() - snapshot_time, 0.0, 0.25))
	var whistle_bar: ProgressBar = meter.get_node("WhistleCooldown")
	var whistle_progress := 0.0 if blowing else (1.0 - cooldown_remaining / cooldown_duration)
	whistle_bar.value = whistle_progress * 100.0
	if circular_meters.has(peer_id):
		var radial_meter: Node = circular_meters[peer_id]
		radial_meter.call("set_values", base_progress, progress, whistle_progress, stage)

func _advance_predicted_bubble_charge(rate: float) -> float:
	var prediction_time := NetworkSession.server_now()
	var action_at := NetworkSession.bubble_action_at
	if not is_equal_approx(predicted_bubble_action_at, action_at):
		predicted_bubble_action_at = action_at
		predicted_bubble_charge = 0.0
		predicted_bubble_last_time = action_at
		predicted_bubble_rate = rate
	if not NetworkSession.paused:
		predicted_bubble_charge += maxf(0.0, prediction_time - predicted_bubble_last_time) * predicted_bubble_rate
	predicted_bubble_last_time = prediction_time
	predicted_bubble_rate = rate
	return predicted_bubble_charge

func _reset_predicted_bubble_charge() -> void:
	predicted_bubble_action_at = -1.0
	predicted_bubble_charge = 0.0
	predicted_bubble_last_time = 0.0
	predicted_bubble_rate = 1.0

func _setup_circular_meters() -> void:
	var peer_ids: Array = [1, 2] if NetworkSession.local_duel else [NetworkSession.local_player_id()]
	for peer_id_value in peer_ids:
		var peer_id := int(peer_id_value)
		var slot := peer_id if NetworkSession.local_duel else 1
		if not GameSettings.uses_circular(slot): continue
		if not actors.has(peer_id):
			continue
		var radial_meter: Node2D = CIRCULAR_METER.new()
		radial_meter.scale = Vector2.ONE * WORLD.WIDGET_SCALE * 1.1
		radial_meter.name = "CircularMeter_%s" % peer_id
		radial_meter.z_index = 10
		add_child(radial_meter)
		circular_meters[peer_id] = radial_meter
		circular_meter_sides[peer_id] = _initial_circular_meter_side(actors[peer_id].global_position)
		circular_meter_previous_positions[peer_id] = actors[peer_id].global_position

func _update_circular_meter_positions() -> void:
	for peer_id in circular_meters:
		var radial_meter: Node2D = circular_meters[peer_id]
		if actors.has(peer_id):
			var actor_position: Vector2 = actors[peer_id].global_position
			var previous_position: Vector2 = circular_meter_previous_positions.get(peer_id, actor_position)
			var movement_x := actor_position.x - previous_position.x
			if absf(movement_x) < 0.5:
				movement_x = float(scores.get(peer_id, {}).get("move", 0))
			var side := int(circular_meter_sides.get(peer_id, _initial_circular_meter_side(actor_position)))
			var meter_delta_x := radial_meter.global_position.x - actor_position.x
			# If the player is moving into the meter, switch immediately before
			# the ring can cover the character. The meter then moves there quickly
			# with its eased follow motion instead of teleporting.
			if side > 0 and movement_x > 0.5 and meter_delta_x > 0.0 and absf(meter_delta_x) < 172.0:
				side = -1
			elif side < 0 and movement_x < -0.5 and meter_delta_x < 0.0 and absf(meter_delta_x) < 172.0:
				side = 1
			circular_meter_sides[peer_id] = side
			var offset := _circular_meter_offset(side)
			if radial_meter.has_method("set_follow_target"):
				radial_meter.call("set_follow_target", actor_position + offset, false)
			else:
				radial_meter.global_position = actor_position + offset
			circular_meter_previous_positions[peer_id] = actor_position

func _initial_circular_meter_side(actor_position: Vector2) -> int:
	# Keep the meter above and to the outside of the player. This leaves the
	# face and hat unobstructed, while also avoiding the nearest screen edge.
	var viewport_width := WORLD.SIZE.x
	var prefer_right := actor_position.x < viewport_width * 0.5
	if actor_position.x < 184.0:
		prefer_right = true
	elif actor_position.x > viewport_width - 184.0:
		prefer_right = false
	return 1 if prefer_right else -1

func _circular_meter_offset(side: int) -> Vector2:
	return Vector2(70.0 if side > 0 else -70.0, -112.0)

func _update_score_labels() -> void:
	var own_id := NetworkSession.local_player_id()
	var own_info: Dictionary = NetworkSession.players.get(own_id, {"name": "你" if GameSettings.language == "zh" else "You"})
	var own_score: int = int(scores.get(own_id, {}).get("score", 0))
	var own_name := str(own_info.get("name", "你" if GameSettings.language == "zh" else "You"))
	if own_name.length() > 10: own_name = own_name.left(10) + "…"
	var own_label: Label = score_labels.get(own_id, $HUD/OwnScore)
	var scores_visible := NetworkSession.phase == "PLAYING"
	for score_label in score_labels.values(): score_label.visible = scores_visible
	own_label.position = Vector2(24.0, 14.0)
	own_label.size = Vector2(356.0, 40.0)
	own_label.add_theme_font_size_override("font_size", 34)
	own_label.text = "%s  %s" % [own_name, own_score]
	var opponent_ids: Array = scores.keys()
	opponent_ids.sort()
	var visible_opponents: Array = []
	for peer_id in opponent_ids:
		if peer_id == own_id or not score_labels.has(peer_id): continue
		visible_opponents.append(peer_id)
	for peer_id in score_labels:
		if peer_id != own_id: score_labels[peer_id].visible = scores_visible and visible_opponents.has(peer_id)
	for index in visible_opponents.size():
		var peer_id: int = visible_opponents[index]
		if not score_labels.has(peer_id): continue
		var fallback_name := "电脑伙伴" if peer_id == -1 else "对手"
		var info: Dictionary = NetworkSession.players.get(peer_id, {"name": fallback_name})
		var player_name := str(info.get("name", fallback_name))
		if player_name in ["电脑伙伴", "练习伙伴", "对手"]: player_name = GameSettings.text(player_name)
		if player_name.length() > 5: player_name = player_name.left(4) + "…"
		var label: Label = score_labels[peer_id]
		var row_top := 14.0 + 60.0 * index
		label.position = Vector2(get_viewport_rect().size.x - 370.0, row_top)
		label.size = Vector2(346.0, 40.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var opponent_score := int(scores[peer_id].get("score", 0))
		label.add_theme_font_size_override("font_size", 34)
		label.text = "%s  %s" % [opponent_score, player_name]
	var has_primary_opponent := false
	for peer_id in visible_opponents:
		if score_labels[peer_id] == $HUD/EnemyScore: has_primary_opponent = true
	$HUD/EnemyScore.visible = scores_visible and (visible_opponents.is_empty() or has_primary_opponent)
	if visible_opponents.is_empty(): $HUD/EnemyScore.text = GameSettings.text("等待对手")

func _show_results() -> void:
	if results_shown: return
	results_shown = true
	AudioManager.play_cue("finish")
	var ids: Array = scores.keys()
	ids.sort_custom(func(a, b):
		if int(scores[a]["score"]) == int(scores[b]["score"]): return int(a) < int(b)
		return int(scores[a]["score"]) > int(scores[b]["score"]))
	var highest := int(scores[ids[0]]["score"]) if not ids.is_empty() else 0
	var champions := PackedStringArray()
	var best := 0
	var largest := PackedStringArray()
	for index in ids.size():
		var peer_id: int = ids[index]
		var state: Dictionary = scores[peer_id]
		var player_name := str(NetworkSession.players.get(peer_id, {"name": GameSettings.text("已离开玩家")})["name"])
		if player_name in ["电脑伙伴", "练习伙伴"]: player_name = GameSettings.text(player_name)
		var score := int(state["score"])
		if score == highest and highest > 0:
			champions.append(player_name)
			if peer_id == NetworkSession.local_player_id() and actors.has(peer_id):
				var custom: AudioStream = actors[peer_id].skin.victory_sound
				if custom != null: AudioManager.play_cue("finish", custom)
		var value := int(state["best"])
		if value > best:
			best = value
			largest.clear()
		if value == best and best > 0: largest.append(player_name)
	var champion_names := ", ".join(champions) if GameSettings.language == "en" else "、".join(champions)
	var summary := GameSettings.text("本局优胜：") + champion_names if not champions.is_empty() else GameSettings.text("本局没有放出有效泡泡，下一局再试试！")
	if best > 0:
		if GameSettings.language == "en": summary += "\n" + GameSettings.text("最大泡泡奖：") + ", ".join(largest) + " (%s pts)" % best
		else: summary += "\n最大泡泡奖：%s（%s 分）" % ["、".join(largest), best]
	if not multiplayer.is_server(): summary += "\n" + GameSettings.text("等待房主返回大厅，再准备下一局。")
	$HUD/Panel/Result.text = summary
	_build_results_table(ids, highest, champions, best, largest)

func _build_results_table(ids: Array, highest: int, champions: PackedStringArray, best: int, largest: PackedStringArray) -> void:
	var table: GridContainer = $HUD/Panel/StatsTable
	for child in table.get_children(): child.queue_free()
	var headers := ["玩家", "得分", "放出", "爆裂", "结果"]
	for header in headers:
		table.add_child(_result_cell(GameSettings.text(header), HORIZONTAL_ALIGNMENT_CENTER, true))
	for peer_id in ids:
		var state: Dictionary = scores[peer_id]
		var player_name := str(NetworkSession.players.get(peer_id, {"name": GameSettings.text("已离开玩家")})["name"])
		if player_name in ["电脑伙伴", "练习伙伴"]: player_name = GameSettings.text(player_name)
		var score := int(state.get("score", 0))
		var result := PackedStringArray()
		if score == highest and highest > 0: result.append(GameSettings.text("优胜"))
		if best > 0 and int(state.get("best", 0)) == best: result.append(GameSettings.text("最大泡泡"))
		var values := [player_name, str(score), str(state.get("released", 0)), str(state.get("bursts", 0)), ", ".join(result) if GameSettings.language == "en" else ("、".join(result) if not result.is_empty() else "—")]
		for column in values:
			table.add_child(_result_cell(str(column), HORIZONTAL_ALIGNMENT_CENTER, false))

func _result_cell(value: String, alignment: int, heading: bool) -> Label:
	var cell := Label.new()
	cell.text = value
	cell.horizontal_alignment = alignment
	cell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cell.custom_minimum_size = Vector2(130.0 if heading else 130.0, 28.0)
	cell.add_theme_font_size_override("font_size", 18 if heading else 17)
	cell.add_theme_color_override("font_color", Color(1.0, 0.9, 0.58) if heading else Color.WHITE)
	return cell

func _replay() -> void:
	var practice := NetworkSession.practice
	var local_duel := NetworkSession.local_duel
	if local_duel:
		var first: Dictionary = NetworkSession.players[1].duplicate()
		var second: Dictionary = NetworkSession.players[2].duplicate()
		NetworkSession._close_session("正在开始下一局。")
		NetworkSession.start_local_duel.call_deferred(first["name"], second["name"], second["skin"], second["hat"])
	elif practice:
		var player_name: String = NetworkSession.players[1]["name"]
		NetworkSession._close_session("正在开始下一局。")
		NetworkSession.start_practice.call_deferred(player_name)
	else: NetworkSession.return_to_lobby()

func _exit_match() -> void:
	_exit_confirmation()

func _exit_confirmation() -> void:
	if exit_confirmation.is_open:
		exit_confirmation.close_dialog()
	else:
		exit_confirmation.show_dialog("退出对局？", "确定退出当前对局并返回大厅吗？", "退出对局")

func _resume_after_pause_dialog() -> void:
	if NetworkSession.paused and NetworkSession.phase == "PLAYING" and (NetworkSession.practice or NetworkSession.local_duel):
		NetworkSession.toggle_local_pause()

func _prediction(state: Dictionary) -> void:
	var id: int = NetworkSession.local_player_id()
	if NetworkSession.paused or multiplayer.is_server() or state.is_empty() or not actors.has(id): return
	actors[id].position = state["position"]
	actors[id].set_walking(float(state.get("velocity_x", 0.0)) / MOTION.CONFIG.move_speed, MOTION.is_grounded(state))
	actors[id].set_crouching(bool(state.get("crouching", false)))

func _bubble_prediction(value: bool) -> void:
	var id: int = NetworkSession.local_player_id()
	if not actors.has(id) or local_state.is_empty(): return
	var display := local_state.duplicate(true)
	display["state"] = "blowing" if value else "idle"
	display["ratio"] = 0.0
	actors[id].update_state(display, CONFIG.warning_ratio, CONFIG.danger_ratio, CONFIG.critical_ratio)

func _network_pause(value: bool) -> void:
	player_input.clear()
	keyboard_held = false
	pressed = false
	local_held = {1: false, 2: false}
	for buffer in position_buffers.values(): buffer.clear()
	for actor in actors.values(): actor.warning_enabled = not value and NetworkSession.phase == "PLAYING"
	if NetworkSession.practice or NetworkSession.local_duel:
		network_status.text = GameSettings.text("已暂停 · 按 Esc 继续") if value else ""
		network_status.visible = value

func _add_perfect_mark(bar: ProgressBar) -> void:
	var mark := ColorRect.new()
	mark.name = "PerfectBubbleMark"
	mark.anchor_left = CONFIG.perfect_bubble_ratio
	mark.anchor_right = CONFIG.perfect_bubble_ratio
	mark.anchor_top = 0.12
	mark.anchor_bottom = 0.88
	mark.offset_left = -1.0
	mark.offset_right = 1.0
	mark.color = Color(1.0, 0.86, 0.38, 0.95)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.z_index = 5
	bar.add_child(mark)

func _sync_charge_segment_corners(meter: VBoxContainer) -> void:
	var charge_bar: ProgressBar = meter.get_node("Size")
	var track_style: StyleBoxFlat = charge_bar.get_theme_stylebox("background") as StyleBoxFlat
	var top_left := 0
	var top_right := 0
	var bottom_right := 0
	var bottom_left := 0
	if track_style != null:
		top_left = track_style.corner_radius_top_left
		top_right = track_style.corner_radius_top_right
		bottom_right = track_style.corner_radius_bottom_right
		bottom_left = track_style.corner_radius_bottom_left
	var own_region: Panel = charge_bar.get_node("OwnProgress")
	var own_source: StyleBoxFlat = own_region.get_theme_stylebox("panel") as StyleBoxFlat
	var own_style: StyleBoxFlat = own_source.duplicate() as StyleBoxFlat
	# Rounded outer start matches the track; the join stays square so it covers
	# any contributor fill underneath without leaving a crescent-shaped gap.
	own_style.corner_radius_top_left = top_left
	own_style.corner_radius_bottom_left = bottom_left
	own_style.corner_radius_top_right = 0
	own_style.corner_radius_bottom_right = 0
	own_region.add_theme_stylebox_override("panel", own_style)
	var bonus_region: Panel = charge_bar.get_node("WhistleBonus")
	var bonus_source: StyleBoxFlat = bonus_region.get_theme_stylebox("panel") as StyleBoxFlat
	var bonus_style: StyleBoxFlat = bonus_source.duplicate() as StyleBoxFlat
	bonus_style.corner_radius_top_left = 0
	bonus_style.corner_radius_bottom_left = 0
	bonus_style.corner_radius_top_right = top_right
	bonus_style.corner_radius_bottom_right = bottom_right
	bonus_region.add_theme_stylebox_override("panel", bonus_style)

func _setup_score_labels() -> void:
	var own_id := NetworkSession.local_player_id()
	score_labels[own_id] = $HUD/OwnScore
	var ids: Array = NetworkSession.players.keys()
	ids.sort()
	var opponent_index := 0
	for peer_id in ids:
		if peer_id == own_id: continue
		var score_label: Label
		if opponent_index == 0:
			score_label = $HUD/EnemyScore
		else:
			score_label = Label.new()
			score_label.add_theme_color_override("font_color", Color.WHITE)
			score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			$HUD.add_child(score_label)
		score_label.visible = false
		score_labels[peer_id] = score_label
		opponent_index += 1

func _new_feedback_label() -> Label:
	var label := Label.new()
	label.visible = false
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.48))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(label)
	return label

func _show_score_feedback(peer_id: int, data: Dictionary) -> void:
	if not score_labels.has(peer_id): return
	var kind := str(data.get("kind", ""))
	var message := ""
	var color := Color(1.0, 0.88, 0.48)
	var gain_value := 0.0
	if kind == "release":
		var parts := PackedStringArray()
		if bool(data.get("perfect", false)): parts.append(GameSettings.text("完美泡泡"))
		var points := int(data.get("points", 0))
		gain_value = points
		if points > 0: parts.append("+%s pts" % points if GameSettings.language == "en" else "+%s分" % points)
		message = " · ".join(parts)
		if bool(data.get("perfect", false)): color = Color(1.0, 0.86, 0.38)
	elif kind == "whistle_hit":
		return
	elif kind == "whistle_score":
		gain_value = float(data.get("awarded_points", 0.0))
		message = "Whistle assist +%.1f pts" % gain_value if GameSettings.language == "en" else "口哨助攻 +%.1f分" % gain_value
		color = Color(0.65, 1.0, 0.82)
	elif kind == "whistle":
		var kills := int(data.get("kills", 0))
		var hits := int(data.get("points", 0))
		if kills > 0:
			gain_value = float(data.get("whistle_break_points", 0.0))
			message = "Whistle burst ×%s · +%.1f pts" % [kills, gain_value] if GameSettings.language == "en" else "口哨击破 ×%s · +%.1f分" % [kills, gain_value]
			color = Color(1.0, 0.82, 0.4)
		elif hits > 0:
			return
	elif kind == "burst" and str(data.get("cause", "")) == "whistle":
		return
	if message.is_empty(): return
	var label := _new_feedback_label()
	label.text = GameSettings.text(message)
	label.add_theme_font_size_override("font_size", _feedback_font_size(gain_value))
	label.add_theme_color_override("font_color", color)
	label.modulate.a = 1.0
	label.visible = true
	var entries: Array = feedback_entries.get(peer_id, [])
	entries.append({
		"label": label,
		"expires": Time.get_ticks_msec() / 1000.0 + FEEDBACK_LIFETIME,
	})
	feedback_entries[peer_id] = entries
	_update_score_feedback_entries()

func _update_score_feedback_entries() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var scores_visible := NetworkSession.phase == "PLAYING"
	for peer_id in feedback_entries.keys():
		var entries: Array = feedback_entries[peer_id]
		var remaining_entries: Array = []
		for entry in entries:
			var label: Label = entry["label"]
			var time_left := float(entry["expires"]) - now
			if time_left <= 0.0:
				if is_instance_valid(label): label.queue_free()
				continue
			if not is_instance_valid(label): continue
			var row := remaining_entries.size()
			if peer_id == NetworkSession.local_player_id():
				label.position = Vector2(24.0, 54.0 + FEEDBACK_SPACING * row)
				label.size = Vector2(356.0, 24.0)
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			else:
				var score_label: Label = score_labels.get(peer_id, $HUD/EnemyScore)
				label.position = Vector2(score_label.position.x, score_label.position.y + 38.0 + FEEDBACK_SPACING * row)
				label.size = Vector2(346.0, 22.0)
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			label.visible = scores_visible
			label.modulate.a = clampf(time_left / 0.3, 0.0, 1.0)
			remaining_entries.append(entry)
		if remaining_entries.is_empty():
			feedback_entries.erase(peer_id)
		else:
			feedback_entries[peer_id] = remaining_entries

func _feedback_font_size(gain: float) -> int:
	var digits := str(absi(roundi(gain))).length()
	return 22 + clampi(digits - 1, 0, 4) * 3



