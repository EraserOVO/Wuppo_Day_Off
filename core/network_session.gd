extends Node

signal room_changed
signal status_changed(message: String)
signal phase_changed(phase: String)
signal snapshot_received(snapshot: Dictionary)
signal gameplay_event(event: Dictionary)
signal prediction_changed(state: Dictionary)
signal pause_changed(value: bool)
signal bubble_input_changed(pressed: bool)

const PREDICTION = preload("res://core/motion_prediction.gd")
const WORLD = preload("res://core/world_layout.gd")
const LOBBY_MOTION = preload("res://core/lobby_motion.gd")
const PORT := 7000
const MAX_PLAYERS := 4
const PROTOCOL := 29
const BUILD := "0.35.3"
const SKIN_COUNT := 8
const HAT_COUNT := 5
const DURATIONS := [30, 60, 90]
const MUD_BALL_TARGETS := [5, 7, 10, 15]
const PRACTICE_DIFFICULTY_NAMES := ["简单", "普通", "困难"]
var game_mode := "bubble_race"
var room_duration := 60
var mud_ball_target_score := 10
var practice_difficulty := 1
var settings_revision := 0
var connection_state := "OFFLINE"
var joined_address := ""
var connection_deadline := 0.0
var practice := false
var local_duel := false
var local_sequences: Dictionary = {}
var control_sequences: Dictionary = {}
var selected_skin := 0
var selected_hat := 0
var active := false
var phase := "LOBBY"
var players: Dictionary = {}
var loaded: Dictionary = {}
var match_id := 0
var local_name := "玩家"
var input_sequence := 0
var last_snapshot_id := -1
var paused := false
var host_player_id := 1
var player_id := 1
var peer_players: Dictionary = {}
var credentials: Dictionary = {}
var disconnected: Dictionary = {}
var local_token := ""
var room_key := ""
var epoch := 0
var input_revision := 0
var successor := 0
var checkpoint: Dictionary = {}
var backup_elapsed := 0.0
var reconnect_until := 0.0
var reconnect_next := 0.0
var reconnect_original_until := 0.0
var reconnect_target := ""
var closing := false
var planned_departure := false
var clock_offset := 0.0
var clock_ready := false
var clock_samples: Array = []
var clock_requests: Dictionary = {}
var clock_elapsed := 0.0
var clock_serial := 0
var last_server_message := 0.0
var last_snapshot: Dictionary = {}
var predictor = PREDICTION.new()
var motion_ticks := 0
var snapshot_sent: Dictionary = {}
var bubble_pressed := false
var bubble_action_at := 0.0
signal lobby_updated(states: Dictionary)
signal lobby_whistled(id: int)
var lobby_states: Dictionary = {}
var lobby_elapsed := 0.0

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func local_player_id() -> int:
	return player_id

func is_remote_player(id: int) -> bool:
	return not practice and not local_duel and id != player_id

func _ready() -> void:
	(multiplayer as SceneMultiplayer).server_relay = false
	phase_changed.connect(_lock_player_controls_outside_match)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(_connection_failed)
	multiplayer.server_disconnected.connect(_server_lost)
	multiplayer.peer_disconnected.connect(_peer_left)
	multiplayer.peer_connected.connect(_peer_connected)

func _connected() -> void:
	if not active: return
	connection_state = "JOINING"
	room_changed.emit()
	status_changed.emit("网络已连接，正在加入房间……")
	join_request.rpc_id(1, PROTOCOL, BUILD, local_name, selected_skin, selected_hat, local_token, room_key)

func _process(delta: float) -> void:
	if not active or practice or local_duel or closing: return
	var now := _now()
	if reconnect_until > 0.0:
		if now >= reconnect_until:
			_close_session("恢复连接超时，请检查 VPN / 防火墙后重新加入。")
			return
		if now >= reconnect_next:
			reconnect_next = now + 1.0
			_attempt_reconnect()
		return
	if connection_state in ["CONNECTING", "JOINING"] and now >= connection_deadline:
		_close_session("连接超时，请确认房主地址、网络连接和游戏版本。")
		return
	if multiplayer.is_server():
		for id in disconnected.keys():
			if now >= float(disconnected[id]): _remove_player(id)
		backup_elapsed += delta
		if backup_elapsed >= 0.5:
			backup_elapsed = 0.0
			_send_checkpoint()
	else:
		clock_elapsed += delta
		if connection_state == "CONNECTED" and clock_elapsed >= (0.2 if clock_samples.size() < 5 else 2.0):
			clock_elapsed = 0.0
			clock_serial += 1
			clock_requests[clock_serial] = now
			while clock_requests.size() > 16: clock_requests.erase(clock_requests.keys()[0])
			clock_probe.rpc_id(1, clock_serial)
		if connection_state == "CONNECTED" and now - last_server_message > 5.0: _server_lost()

func _physics_process(_delta: float) -> void:
	_tick_lobby(_delta)
	if not active or closing or paused or reconnect_until > 0.0 or phase != "PLAYING" or multiplayer.is_server(): return
	predictor.tick()
	prediction_changed.emit(predictor.state)
	motion_ticks += 1
	if motion_ticks % 2 == 0 and not predictor.pending.is_empty():
		motion_request.rpc_id(1, match_id, input_revision, predictor.packet())

func host(player_name: String, bind_address := "*") -> void:
	if active: return
	var peer := ENetMultiplayerPeer.new()
	peer.set_bind_ip(bind_address)
	var error := peer.create_server(PORT, MAX_PLAYERS - 1)
	if error != OK:
		status_changed.emit("创建失败：%s" % error)
		return
	multiplayer.multiplayer_peer = peer
	active = true
	connection_state = "HOSTING"
	player_id = 1
	host_player_id = 1
	epoch = 0
	local_token = Crypto.new().generate_random_bytes(24).hex_encode()
	room_key = Crypto.new().generate_random_bytes(16).hex_encode()
	credentials = {local_token.sha256_text(): 1}
	peer_players = {1: 1}
	local_name = _safe_name(player_name)
	settings_revision = 0
	players = {1: {"name": local_name, "ready": false, "skin": selected_skin, "hat": selected_hat, "address": "", "connected": true}}
	_publish_room()
	status_changed.emit("房间已创建，最多 4 人。")

func join(address: String, player_name: String) -> void:
	if active: return
	local_name = _safe_name(player_name)
	local_token = Crypto.new().generate_random_bytes(24).hex_encode()
	room_key = ""
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address.strip_edges(), PORT)
	if error != OK:
		status_changed.emit("连接失败：%s" % error)
		return
	multiplayer.multiplayer_peer = peer
	active = true
	joined_address = address.strip_edges()
	connection_state = "CONNECTING"
	connection_deadline = Time.get_ticks_msec() / 1000.0 + 12.0
	status_changed.emit("正在连接……")
	room_changed.emit()

func leave(message := "已离开房间。") -> void:
	if closing: return
	if active and not practice and not local_duel and reconnect_until <= 0.0:
		if multiplayer.is_server() and successor != 0:
			closing = true
			_set_paused(true)
			_send_checkpoint()
			handoff_checkpoint.rpc_id(_transport_for(successor), _checkpoint_data())
			host_departure.rpc(host_player_id, successor, players.get(successor, {}).get("address", ""))
			await get_tree().create_timer(0.25).timeout
		elif not multiplayer.is_server() and connection_state == "CONNECTED":
			closing = true
			depart_request.rpc_id(1)
			await get_tree().create_timer(0.15).timeout
	_close_session(message)

func _close_session(message: String) -> void:
	active = false
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	connection_state = "OFFLINE"
	connection_deadline = 0.0
	joined_address = ""
	practice = false
	local_duel = false
	local_sequences.clear()
	control_sequences.clear()
	players.clear()
	loaded.clear()
	peer_players.clear()
	credentials.clear()
	disconnected.clear()
	checkpoint.clear()
	successor = 0
	closing = false
	planned_departure = false
	room_key = ""
	local_token = ""
	player_id = 1
	host_player_id = 1
	reconnect_until = 0.0
	paused = false
	predictor.reset()
	bubble_pressed = false
	_reset_clock()
	phase = "LOBBY"
	MatchController.reset()
	phase_changed.emit(phase)
	AudioManager.stop_all()
	room_changed.emit()
	status_changed.emit(message)

func _safe_name(value: String) -> String:
	var result := value.strip_edges().left(24)
	return result if not result.is_empty() else "玩家"

@rpc("any_peer", "call_remote", "reliable", 0)
func join_request(version: int, build: String, player_name: String, skin_id: int, hat_id: int, token: String, expected_room: String) -> void:
	if not multiplayer.is_server(): return
	var sender := multiplayer.get_remote_sender_id()
	if peer_players.has(sender): return
	if version != PROTOCOL or build != BUILD or token.length() != 48 or (not expected_room.is_empty() and expected_room != room_key):
		reject_join.rpc_id(sender, "版本或房间不匹配，请使用相同版本重新加入。")
		return
	var id := int(credentials.get(token.sha256_text(), 0))
	var resumed := id != 0
	if resumed and id in peer_players.values():
		reject_join.rpc_id(sender, "该玩家已经在线。")
		return
	if not resumed and (phase != "LOBBY" or players.size() >= MAX_PLAYERS):
		reject_join.rpc_id(sender, "版本不匹配、房间已满或比赛已开始。")
		return
	if not resumed:
		id = sender
		while players.has(id): id += 1
		credentials[token.sha256_text()] = id
		players[id] = {"name": _safe_name(player_name), "ready": false, "skin": clampi(skin_id, 0, SKIN_COUNT - 1), "hat": clampi(hat_id, 0, HAT_COUNT - 1)}
	peer_players[sender] = id
	players[id]["connected"] = true
	players[id]["address"] = (multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_peer(sender).get_remote_address()
	disconnected.erase(id)
	if resumed: MatchController.reset_peer_inputs(id)
	if disconnected.is_empty(): _set_paused(false)
	welcome.rpc_id(sender, id, room_key, epoch, input_revision, resumed)
	_publish_room()
	if phase != "LOBBY": MatchController._publish(phase == "RESULTS")
	_send_checkpoint()

@rpc("authority", "call_remote", "reliable", 0)
func welcome(id: int, key: String, new_epoch: int, revision: int, resumed: bool) -> void:
	player_id = id
	room_key = key
	epoch = new_epoch
	input_revision = revision
	reconnect_until = 0.0
	connection_state = "CONNECTED"
	connection_deadline = 0.0
	last_server_message = _now()
	if resumed:
		_reset_inputs()
		_reset_clock()
		status_changed.emit("连接已恢复，分数和角色外观已保留。")

@rpc("authority", "call_remote", "reliable", 0)
func reject_join(message: String) -> void:
	_close_session(message)

func set_ready(value: bool) -> void:
	if not active: return
	if multiplayer.is_server(): _set_ready(player_id, value, settings_revision)
	else: ready_request.rpc_id(1, value, settings_revision)

@rpc("any_peer", "call_remote", "reliable", 0)
func ready_request(value: bool, revision: int) -> void:
	if multiplayer.is_server(): _set_ready(_sender_player(), value, revision)

func _set_ready(peer_id: int, value: bool, revision: int) -> void:
	if phase != "LOBBY" or not players.has(peer_id): return
	if revision != settings_revision:
		_publish_room()
		return
	players[peer_id]["ready"] = value
	_publish_room()

func can_start() -> bool:
	if not active or not multiplayer.is_server() or paused or phase != "LOBBY" or players.size() < 2: return false
	for info in players.values():
		if not info["ready"]: return false
	return true

func start_match() -> void:
	if not can_start(): return
	match_id += 1
	loaded.clear()
	if practice: loaded[-1] = true
	if local_duel: loaded[2] = true
	local_sequences.clear()
	MatchController.prepare(players.keys(), match_id)
	change_phase("LOADING")

func confirm_loaded() -> void:
	_reset_inputs()
	if reconnect_until > 0.0: return
	if multiplayer.is_server(): _loaded(player_id, match_id)
	else: loaded_request.rpc_id(1, match_id)

@rpc("any_peer", "call_remote", "reliable", 0)
func loaded_request(round_id: int) -> void:
	if multiplayer.is_server(): _loaded(_sender_player(), round_id)

func _loaded(peer_id: int, round_id: int) -> void:
	if phase != "LOADING" or round_id != match_id or not players.has(peer_id): return
	loaded[peer_id] = true
	room_changed.emit()
	if not practice and not local_duel: loading_status.rpc(match_id, loaded)
	if loaded.size() == players.size(): MatchController.begin_countdown()

@rpc("authority", "call_remote", "reliable", 0)
func loading_status(round_id: int, ready_players: Dictionary) -> void:
	if round_id != match_id: return
	loaded = ready_players
	room_changed.emit()

func submit_input(pressed: bool) -> void:
	if phase != "PLAYING" or paused or closing: return
	input_sequence += 1
	bubble_pressed = pressed
	bubble_action_at = server_now()
	if multiplayer.is_server(): MatchController.accept_input(player_id, match_id, input_sequence, pressed)
	else: input_request.rpc_id(1, match_id, input_revision, input_sequence, pressed, bubble_action_at)
	if not multiplayer.is_server(): bubble_input_changed.emit(pressed)

func submit_local_input(peer_id: int, pressed: bool) -> void:
	if not local_duel or phase != "PLAYING" or peer_id not in [1, 2]: return
	var sequence := int(local_sequences.get(peer_id, 0)) + 1
	local_sequences[peer_id] = sequence
	MatchController.accept_input(peer_id, match_id, sequence, pressed)

@rpc("any_peer", "call_remote", "reliable", 0)
func input_request(round_id: int, revision: int, sequence: int, pressed: bool, action_time: float) -> void:
	if multiplayer.is_server():
		if revision != input_revision: return
		if not is_finite(action_time): return
		if action_time > _now() + 0.05 or action_time < _now() - input_allowance(_sender_player()) - 0.1: return
		MatchController.accept_input(_sender_player(), round_id, sequence, pressed, action_time)

func submit_control(action: String, value := 0, local_peer_id := 1) -> void:
	if phase != "PLAYING" or paused or closing: return
	var peer_id: int = local_peer_id if local_duel else player_id
	if local_duel and peer_id not in [1, 2]: return
	var sequence := int(control_sequences.get(peer_id, 0)) + 1
	control_sequences[peer_id] = sequence
	if multiplayer.is_server(): MatchController.accept_control(peer_id, match_id, sequence, action, value)
	elif action == "move": predictor.direction = clampi(value, -1, 1)
	elif action == "jump": predictor.jump_pending = true
	elif action == "crouch":
		predictor.crouching = value != 0
		control_request.rpc_id(1, match_id, input_revision, sequence, action, value)
	else: control_request.rpc_id(1, match_id, input_revision, sequence, action, value)

@rpc("any_peer", "call_remote", "reliable", 0)
func control_request(round_id: int, revision: int, sequence: int, action: String, value: int) -> void:
	if multiplayer.is_server() and revision == input_revision and action in ["crouch", "whistle"]: MatchController.accept_control(_sender_player(), round_id, sequence, action, value)

@rpc("any_peer", "call_remote", "unreliable_ordered", 2)
func motion_request(round_id: int, revision: int, frames: Array) -> void:
	if multiplayer.is_server() and revision == input_revision: MatchController.accept_motion(_sender_player(), round_id, frames)

func change_phase(value: String) -> void:
	phase = value
	_publish_room()
	phase_changed.emit(phase)

func _lock_player_controls_outside_match(value: String) -> void:
	if value == "PLAYING": return
	predictor.direction = 0
	predictor.jump_pending = false
	predictor.crouching = false
	predictor.pending.clear()
	motion_ticks = 0
	if bubble_pressed:
		bubble_pressed = false
		bubble_input_changed.emit(false)
	bubble_action_at = 0.0
	if MatchController.has_method("stop_player_controls"):
		MatchController.stop_player_controls()

func return_to_lobby() -> void:
	if not active or not multiplayer.is_server() or phase != "RESULTS": return
	MatchController.reset()
	for peer_id in players: players[peer_id]["ready"] = practice and int(peer_id) < 0
	change_phase("LOBBY")

func _publish_room() -> void:
	room_changed.emit()
	if active and multiplayer.is_server() and not practice and not local_duel:
		_elect_successor()
		room_state.rpc(players, phase, match_id, room_duration, settings_revision, host_player_id, successor, paused, epoch, input_revision, game_mode, mud_ball_target_score)

@rpc("authority", "call_remote", "reliable", 0)
func room_state(roster: Dictionary, new_phase: String, round_id: int, duration: int, revision: int, host_id: int, backup_id: int, is_paused: bool, new_epoch: int, control_revision: int, selected_game := "bubble_race", selected_ball_target := 10) -> void:
	var previous := phase
	var previous_revision := settings_revision
	players = roster
	phase = new_phase
	match_id = round_id
	game_mode = selected_game
	room_duration = duration
	mud_ball_target_score = selected_ball_target if selected_ball_target in MUD_BALL_TARGETS else 10
	settings_revision = revision
	host_player_id = host_id
	successor = backup_id
	epoch = new_epoch
	input_revision = control_revision
	last_server_message = _now()
	if paused != is_paused:
		paused = is_paused
		_reset_inputs()
		pause_changed.emit(paused)
	connection_state = "CONNECTED"
	connection_deadline = 0.0
	room_changed.emit()
	if revision != previous_revision and phase == "LOBBY": status_changed.emit("房主调整了玩法或比赛设置，请重新准备。")
	if phase != previous: phase_changed.emit(phase)

func publish_snapshot(snapshot: Dictionary, final := false) -> void:
	snapshot["epoch"] = epoch
	snapshot["input_revision"] = input_revision
	last_snapshot = snapshot.duplicate(true)
	snapshot_received.emit(snapshot)
	if practice or local_duel: return
	if final: final_snapshot.rpc(snapshot)
	else:
		var packet := var_to_bytes(snapshot).compress(FileAccess.COMPRESSION_DEFLATE)
		for peer_id in multiplayer.get_peers():
			if not peer_players.has(peer_id): continue
			var rate := 30.0 if peer_latency(int(peer_players[peer_id])) < 180 else 20.0
			if _now() - float(snapshot_sent.get(peer_id, 0.0)) >= 1.0 / rate - 0.001:
				snapshot_sent[peer_id] = _now()
				state_snapshot.rpc_id(peer_id, packet)

@rpc("authority", "call_remote", "unreliable_ordered", 1)
func state_snapshot(packet: PackedByteArray) -> void:
	if packet.size() > 4096: return
	var raw := packet.decompress_dynamic(32768, FileAccess.COMPRESSION_DEFLATE)
	if raw.is_empty(): return
	var decoded: Variant = bytes_to_var(raw)
	if not decoded is Dictionary: return
	var snapshot: Dictionary = decoded
	if int(snapshot.get("epoch", -1)) == epoch and int(snapshot.get("input_revision", -1)) == input_revision and int(snapshot.get("match_id", -1)) == match_id:
		_deliver_snapshot(snapshot)

@rpc("authority", "call_remote", "reliable", 0)
func final_snapshot(snapshot: Dictionary) -> void:
	if int(snapshot.get("epoch", -1)) == epoch and int(snapshot.get("input_revision", -1)) == input_revision and int(snapshot.get("match_id", -1)) == match_id: _deliver_snapshot(snapshot)

func _deliver_snapshot(snapshot: Dictionary) -> void:
	var serial := int(snapshot.get("serial", -1))
	if serial <= last_snapshot_id: return
	last_snapshot_id = serial
	last_server_message = _now()
	last_snapshot = snapshot.duplicate(true)
	var state: Dictionary = snapshot.get("players", {}).get(player_id, {})
	if not state.is_empty():
		predictor.reconcile(state)
		prediction_changed.emit(predictor.state)
	snapshot_received.emit(snapshot)

func _peer_left(peer_id: int) -> void:
	if not active or closing or not multiplayer.is_server(): return
	var id := int(peer_players.get(peer_id, 0))
	peer_players.erase(peer_id)
	if id == 0 or not players.has(id): return
	players[id]["connected"] = false
	players[id]["ready"] = false
	disconnected[id] = _now() + 15.0
	_set_paused(phase in ["LOADING", "COUNTDOWN", "PLAYING"])
	status_changed.emit("玩家断线，等待自动重连（最多 15 秒）。")
	_publish_room()
	_send_checkpoint()

func choose_skin(skin_id: int) -> void:
	selected_skin = clampi(skin_id, 0, SKIN_COUNT - 1)
	if not active: return
	if multiplayer.is_server(): _choose_skin(player_id, selected_skin)
	else: skin_request.rpc_id(1, selected_skin)

@rpc("any_peer", "call_remote", "reliable", 0)
func skin_request(skin_id: int) -> void:
	if multiplayer.is_server(): _choose_skin(_sender_player(), skin_id)

func _choose_skin(peer_id: int, skin_id: int) -> void:
	if phase != "LOBBY" or not players.has(peer_id): return
	players[peer_id]["skin"] = clampi(skin_id, 0, SKIN_COUNT - 1)
	players[peer_id]["ready"] = false
	_publish_room()

func choose_hat(hat_id: int) -> void:
	selected_hat = clampi(hat_id, 0, HAT_COUNT - 1)
	if not active: return
	if multiplayer.is_server(): _choose_hat(player_id, selected_hat)
	else: hat_request.rpc_id(1, selected_hat)

@rpc("any_peer", "call_remote", "reliable", 0)
func hat_request(hat_id: int) -> void:
	if multiplayer.is_server(): _choose_hat(_sender_player(), hat_id)

func _choose_hat(peer_id: int, hat_id: int) -> void:
	if phase != "LOBBY" or not players.has(peer_id): return
	players[peer_id]["hat"] = clampi(hat_id, 0, HAT_COUNT - 1)
	players[peer_id]["ready"] = false
	_publish_room()

func start_practice(player_name: String, difficulty := 1) -> void:
	if active: return
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	active = true
	practice = true
	practice_difficulty = clampi(difficulty, 0, PRACTICE_DIFFICULTY_NAMES.size() - 1)
	connection_state = "PRACTICE"
	settings_revision = 0
	players = {1: {"name": _safe_name(player_name), "ready": true, "skin": selected_skin, "hat": selected_hat}, -1: {"name": "练习伙伴", "ready": true, "skin": (selected_skin + 1) % SKIN_COUNT, "hat": 0}}
	start_match()

func publish_event(event: Dictionary) -> void:
	event["epoch"] = epoch
	event["input_revision"] = input_revision
	gameplay_event.emit(event)
	if not practice and not local_duel: event_message.rpc(event)

func start_local_duel(first_name: String, second_name: String, second_skin: int, second_hat := 0) -> void:
	if active: return
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	active = true
	local_duel = true
	connection_state = "LOCAL_DUEL"
	settings_revision = 0
	players = {1: {"name": _safe_name(first_name), "ready": true, "skin": selected_skin, "hat": selected_hat}, 2: {"name": _safe_name(second_name), "ready": true, "skin": clampi(second_skin, 0, SKIN_COUNT - 1), "hat": clampi(second_hat, 0, HAT_COUNT - 1)}}
	start_match()

@rpc("authority", "call_remote", "reliable", 0)
func event_message(event: Dictionary) -> void:
	if int(event.get("epoch", -1)) == epoch and int(event.get("input_revision", -1)) == input_revision and int(event.get("match_id", -1)) == match_id and phase == "PLAYING":
		gameplay_event.emit(event)

func set_game_mode(value: String) -> void:
	if value not in ["bubble_race", "mud_ball"] or value == game_mode: return
	if active and (not multiplayer.is_server() or phase != "LOBBY"): return
	game_mode = value
	if active:
		settings_revision += 1
		for info in players.values(): info["ready"] = false
	_publish_room()

func set_duration(value: int) -> void:
	if value not in DURATIONS or value == room_duration: return
	if active and (not multiplayer.is_server() or phase != "LOBBY"): return
	room_duration = value
	if active:
		settings_revision += 1
		for peer_id in players: players[peer_id]["ready"] = practice and int(peer_id) < 0
		status_changed.emit("比赛时长改为 %s 秒，请重新准备。" % value)
	_publish_room()

func set_mud_ball_target_score(value: int) -> void:
	if value not in MUD_BALL_TARGETS or value == mud_ball_target_score: return
	if active and (not multiplayer.is_server() or phase != "LOBBY"): return
	mud_ball_target_score = value
	if active:
		settings_revision += 1
		for peer_id in players: players[peer_id]["ready"] = practice and int(peer_id) < 0
		status_changed.emit("弗纳克球获胜分数改为 %s 分，请重新准备。" % value)
	_publish_room()

func start_block_reason() -> String:
	if not active: return "可直接单人练习，或创建 / 加入联机房间。"
	if connection_state in ["CONNECTING", "JOINING"]: return "正在连接，可点击离开取消。"
	if players.size() < 2: return "等待另一位玩家加入（%s / %s 人）。" % [players.size(), MAX_PLAYERS]
	var waiting := PackedStringArray()
	for info in players.values():
		if not info["ready"]: waiting.append(str(info["name"]))
	if not waiting.is_empty(): return "等待准备：%s" % "、".join(waiting)
	return "全部准备好了，房主可以开始 %s 分球赛。" % mud_ball_target_score if game_mode == "mud_ball" else "全部准备好了，房主可以开始 %s 秒比赛。" % room_duration

func peer_latency(peer_id: int) -> int:
	if practice or local_duel or not active or closing or reconnect_until > 0.0: return -1
	if not multiplayer.is_server() and peer_id != host_player_id: return -1
	var transport_id := 1
	if multiplayer.is_server():
		transport_id = _transport_for(peer_id)
	if transport_id not in multiplayer.get_peers(): return -1
	var transport := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if transport == null: return -1
	var remote: ENetPacketPeer = transport.get_peer(transport_id)
	if remote == null or not remote.is_active(): return -1
	return roundi(remote.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))

func server_now() -> float:
	if closing: return _now()
	if multiplayer.is_server(): return _now()
	if clock_ready: return _now() + clock_offset
	return float(last_snapshot.get("server_time", _now())) + maxf(0.0, _now() - last_server_message)

func input_allowance(id: int) -> float:
	if not is_remote_player(id): return 0.0
	var rtt := peer_latency(id)
	return clampf(maxf(0.0, rtt) / 2000.0 + 0.04, 0.04, 0.25)

func maximum_input_allowance() -> float:
	var allowance := 0.0
	for id in players: allowance = maxf(allowance, input_allowance(id))
	return allowance

func interpolation_delay() -> float:
	var rtt := maxi(0, peer_latency(host_player_id))
	return clampf(0.08 + rtt / 4000.0, 0.08, 0.15)

@rpc("any_peer", "call_remote", "unreliable", 3)
func clock_probe(serial: int) -> void:
	if multiplayer.is_server() and _sender_player() != 0:
		clock_reply.rpc_id(multiplayer.get_remote_sender_id(), serial, _now())

@rpc("authority", "call_remote", "unreliable", 3)
func clock_reply(serial: int, host_time: float) -> void:
	if not clock_requests.has(serial) or not is_finite(host_time): return
	var sent := float(clock_requests[serial])
	clock_requests.erase(serial)
	var now := _now()
	var rtt := now - sent
	if rtt > 1.0: return
	clock_samples.append([rtt, host_time - (sent + now) * 0.5])
	if clock_samples.size() > 12: clock_samples.pop_front()
	var best: Array = clock_samples[0]
	for sample in clock_samples:
		if float(sample[0]) < float(best[0]): best = sample
	clock_offset = float(best[1]) if not clock_ready else move_toward(clock_offset, float(best[1]), 0.02)
	clock_ready = true
	last_server_message = now

func _reset_clock() -> void:
	clock_ready = false
	clock_offset = 0.0
	clock_samples.clear()
	clock_requests.clear()
	clock_elapsed = 0.2

func _reset_inputs() -> void:
	control_sequences.clear()
	input_sequence = 0
	last_snapshot_id = -1
	predictor.reset()
	motion_ticks = 0
	bubble_pressed = false
	if active and (connection_state == "HOSTING" or practice or local_duel):
		for id in MatchController.states: MatchController.reset_peer_inputs(id)

func _sender_player() -> int:
	return int(peer_players.get(multiplayer.get_remote_sender_id(), 0))

func _transport_for(id: int) -> int:
	for transport_id in peer_players:
		if int(peer_players[transport_id]) == id: return int(transport_id)
	return 0

func _peer_connected(id: int) -> void:
	if closing or (not multiplayer.is_server() and id != 1): return
	var transport := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if transport == null: return
	var peer := transport.get_peer(id)
	if peer != null:
		peer.set_timeout(4, 2000, 5000)
		peer.ping_interval(250)

func _set_paused(value: bool) -> void:
	if paused == value: return
	paused = value
	input_revision += 1
	_reset_inputs()
	if value:
		for state in MatchController.states.values():
			state["state"] = "idle"
			state["held"] = 0.0
			state["ratio"] = 0.0
			state["move"] = 0
	pause_changed.emit(value)
	if phase != "LOBBY": MatchController._publish(phase == "RESULTS")

func toggle_local_pause() -> void:
	if not active or (not practice and not local_duel) or phase != "PLAYING": return
	_set_paused(not paused)

@rpc("any_peer", "call_remote", "reliable", 0)
func depart_request() -> void:
	if not multiplayer.is_server(): return
	var sender := multiplayer.get_remote_sender_id()
	var id := _sender_player()
	peer_players.erase(sender)
	if id != 0: _remove_player(id)

func _remove_player(id: int) -> void:
	players.erase(id)
	loaded.erase(id)
	disconnected.erase(id)
	for credential in credentials.keys():
		if credentials[credential] == id: credentials.erase(credential)
	MatchController.states.erase(id)
	if players.size() < 2 and phase in ["LOADING", "COUNTDOWN", "PLAYING"]:
		MatchController.reset()
		for info in players.values(): info["ready"] = false
		change_phase("LOBBY")
	if disconnected.is_empty(): _set_paused(false)
	_publish_room()
	if phase != "LOBBY": MatchController._publish(phase == "RESULTS")
	_send_checkpoint()

func _elect_successor() -> void:
	var candidates: Array = []
	for id in players:
		if id != host_player_id and players[id].get("connected", true) and not str(players[id].get("address", "")).is_empty(): candidates.append(id)
	candidates.sort()
	successor = int(candidates[0]) if not candidates.is_empty() else 0

func _send_checkpoint() -> void:
	_elect_successor()
	if successor == 0: return
	var target := _transport_for(successor)
	if target == 0: return
	backup_state.rpc_id(target, _checkpoint_data())

func _checkpoint_data() -> Dictionary:
	return {"roster": players.duplicate(true), "credentials": credentials.duplicate(true), "room": room_key, "epoch": epoch, "input_revision": input_revision, "host": host_player_id, "successor": successor, "phase": phase, "match_id": match_id, "duration": room_duration, "game_mode": game_mode, "mud_ball_target_score": mud_ball_target_score, "revision": settings_revision, "loaded": loaded.duplicate(true), "controller": MatchController.recovery_state()}

@rpc("authority", "call_remote", "reliable", 0)
func handoff_checkpoint(data: Dictionary) -> void:
	backup_state(data)

@rpc("authority", "call_remote", "reliable", 4)
func backup_state(data: Dictionary) -> void:
	if str(data.get("room", "")) != room_key or int(data.get("epoch", -1)) != epoch: return
	checkpoint = data.duplicate(true)
	last_server_message = _now()

@rpc("authority", "call_remote", "reliable", 0)
func host_departure(old_host: int, next_host: int, address: String) -> void:
	if old_host != host_player_id or next_host != successor: return
	planned_departure = true
	reconnect_target = address
	reconnect_original_until = 0.0
	await get_tree().create_timer(0.35).timeout
	_server_lost(true)

func _connection_failed() -> void:
	if reconnect_until > 0.0:
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		return
	_close_session("连接失败，请检查主机地址与网络。")

func _server_lost(departed := false) -> void:
	if not active or closing or practice or local_duel or reconnect_until > 0.0: return
	departed = departed or planned_departure
	planned_departure = false
	paused = true
	_reset_inputs()
	pause_changed.emit(true)
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	connection_state = "RECONNECTING"
	reconnect_until = _now() + 15.0
	reconnect_next = _now() + 0.35
	if not departed:
		reconnect_target = joined_address
		reconnect_original_until = _now() + 3.0
	status_changed.emit("连接中断，正在自动恢复……")
	room_changed.emit()

func _attempt_reconnect() -> void:
	if _now() >= reconnect_original_until and successor != 0:
		if successor == player_id and not checkpoint.is_empty():
			_promote()
			return
		reconnect_target = str(players.get(successor, {}).get("address", ""))
	if reconnect_target.is_empty(): return
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(reconnect_target, PORT) != OK: return
	multiplayer.multiplayer_peer = peer
	joined_address = reconnect_target
	connection_state = "RECONNECTING"

func _promote() -> void:
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(PORT, MAX_PLAYERS - 1) != OK: return
	multiplayer.multiplayer_peer = peer
	players = checkpoint["roster"].duplicate(true)
	credentials = checkpoint["credentials"].duplicate(true)
	room_key = checkpoint["room"]
	epoch = int(checkpoint["epoch"]) + 1
	input_revision = int(checkpoint.get("input_revision", 0)) + 1
	host_player_id = player_id
	match_id = checkpoint["match_id"]
	game_mode = checkpoint.get("game_mode", "bubble_race")
	mud_ball_target_score = int(checkpoint.get("mud_ball_target_score", 10))
	room_duration = checkpoint["duration"]
	settings_revision = checkpoint["revision"]
	phase = checkpoint["phase"]
	loaded = checkpoint["loaded"].duplicate(true)
	MatchController.restore_recovery(checkpoint["controller"])
	peer_players = {1: player_id}
	disconnected.clear()
	var former_host: int = checkpoint["host"]
	players.erase(former_host)
	MatchController.states.erase(former_host)
	loaded.erase(former_host)
	for credential in credentials.keys():
		if credentials[credential] == former_host: credentials.erase(credential)
	for id in players:
		players[id]["connected"] = id == player_id
		if id != player_id: disconnected[id] = _now() + 15.0
	reconnect_until = 0.0
	connection_state = "HOSTING"
	_reset_clock()
	_reset_inputs()
	paused = not disconnected.is_empty()
	if players.size() < 2 and phase in ["LOADING", "COUNTDOWN", "PLAYING"]:
		MatchController.reset()
		phase = "LOBBY"
		paused = false
	phase_changed.emit(phase)
	pause_changed.emit(paused)
	_publish_room()
	if phase != "LOBBY": MatchController._publish(phase == "RESULTS")
	status_changed.emit("已接替房主，等待其他玩家恢复连接。" if paused else "已接替房主。")

func connection_text() -> String:
	if reconnect_until > 0.0: return "正在恢复连接 · 最多等待 %s 秒" % ceili(reconnect_until - _now())
	if paused: return "比赛暂停 · 等待断线玩家恢复"
	match connection_state:
		"HOSTING": return "房间已创建 · %s / %s 人" % [players.size(), MAX_PLAYERS]
		"CONNECTING": return "正在连接主机……"
		"JOINING": return "已连接网络 · 正在加入房间……"
		"CONNECTED":
			var latency := peer_latency(host_player_id)
			return "已连接 · 延迟 %s ms%s" % [latency, "（较高）" if latency > 150 else ""] if latency >= 0 else "已连接 · 正在测量延迟"
		"PRACTICE": return "单人练习 · 不需要网络"
		"LOCAL_DUEL": return "本地双人 · P1 K / L · P2 小键盘 0 / ."
	return "未连接"

# The lobby is a separate authority simulation; whistle never reaches match rules.
func lobby_control(action: String, value := 0) -> void:
	if phase != "LOBBY" or not active or practice or local_duel: return
	if multiplayer.is_server(): _lobby_control(player_id, action, value)
	else: lobby_control_request.rpc_id(1, action, value)

@rpc("any_peer", "call_remote", "reliable", 0)
func lobby_control_request(action: String, value: int) -> void:
	if multiplayer.is_server(): _lobby_control(_sender_player(), action, value)

func _lobby_control(id: int, action: String, value: int) -> void:
	if phase != "LOBBY" or not players.has(id): return
	_ensure_lobby_player(id)
	var state: Dictionary = lobby_states[id]
	if action == "move":
		state["move"] = clampi(value, -1, 1)
		state["last_input"] = _now()
	elif action == "crouch":
		LOBBY_MOTION.set_crouching(state, value != 0)
		state["last_input"] = _now()
	elif action == "jump":
		var was_double_jump := int(state.get("jumps", 0)) == 1
		if LOBBY_MOTION.jump(state) and was_double_jump:
			state["double_jump_direction"] = LOBBY_MOTION.double_jump_direction(state)
	elif action == "whistle" and _now() >= float(state.get("whistle_ready", 0.0)):
		state["whistle_ready"] = _now() + 0.5
		lobby_whistled.emit(id)
		lobby_whistle_message.rpc(id)

func _ensure_lobby_player(id: int) -> void:
	if lobby_states.has(id): return
	lobby_states[id] = {"position": LOBBY_MOTION.SPAWNS[players.keys().find(id) % LOBBY_MOTION.SPAWNS.size()], "move": 0, "velocity_x": 0.0, "velocity_y": 0.0, "crouching": false, "jumps": 0, "last_input": _now()}

func _tick_lobby(delta: float) -> void:
	if not active:
		lobby_states.clear()
		return
	if phase != "LOBBY" or closing or practice or local_duel or paused or reconnect_until > 0.0 or not multiplayer.is_server(): return
	for id in lobby_states.keys():
		if not players.has(id): lobby_states.erase(id)
	for id in players:
		_ensure_lobby_player(id)
		var state: Dictionary = lobby_states[id]
		if _now() - float(state["last_input"]) > 0.4:
			state["move"] = 0
			state["crouching"] = false
		LOBBY_MOTION.step(state, delta)
	lobby_elapsed += delta
	if lobby_elapsed >= 0.05:
		lobby_elapsed = 0.0
		lobby_updated.emit(lobby_states)
		lobby_state_message.rpc(lobby_states)

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func lobby_state_message(states: Dictionary) -> void:
	if phase != "LOBBY": return
	lobby_states = states
	lobby_updated.emit(states)

@rpc("authority", "call_remote", "reliable", 0)
func lobby_whistle_message(id: int) -> void:
	if phase == "LOBBY": lobby_whistled.emit(id)
