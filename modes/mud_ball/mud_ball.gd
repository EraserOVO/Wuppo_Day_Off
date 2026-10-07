extends Node2D
const LAYERS = preload("res://ui/scene_layers.gd")

const WORLD = preload("res://core/world_layout.gd")
const MOTION = preload("res://core/player_motion.gd")
const COURT = preload("res://modes/mud_ball/court.gd")
const ACTOR = preload("res://actors/wum/wum.tscn")
const SKINS = preload("res://assets/characters/skin_catalog.tres")
const HATS = preload("res://assets/hats/hat_catalog.tres")
const BUFFER = preload("res://core/snapshot_buffer.gd")
const EXIT_DIALOG = preload("res://ui/rounded_exit_dialog.gd")
const PLAYER_INPUT = preload("res://core/match_player_input.gd")
var actors := {}
var buffers := {}
var ball_buffer = BUFFER.new()
var ball_data := {}
var displayed_ball := Vector2.ZERO
var displayed_ball_rotation := 0.0
var last_ball_hit_id := 0
var has_seen_ball_snapshot := false
var player_input = PLAYER_INPUT.new()
var camera: Camera2D
var audio_listener: AudioListener2D
var hud: Control
var left_score: Label
var right_score: Label
var status: Label
var results: PanelContainer
var summary: Label
var replay: Button
var snapshot_time := 0.0
var countdown := 0.0
var shown_epoch := -1
var exit_confirmation

func _ready() -> void:
	LAYERS.install(self, _draw_layer)
	MOTION.register_step_profile("mud_ball", Callable(COURT, "step_player"))
	AudioManager.play_music("match")
	camera = Camera2D.new()
	camera.position = WORLD.CENTER
	add_child(camera)
	audio_listener = AudioListener2D.new()
	audio_listener.name = "PlayerAudioListener"
	add_child(audio_listener)
	audio_listener.make_current()
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	layer.add_child(hud)
	left_score = _label(Vector2(38, 28), Vector2(520, 72), 42)
	left_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	right_score = _label(Vector2(1362, 28), Vector2(520, 72), 42)
	right_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status = _label(Vector2(600, 482), Vector2(720, 90), 38)
	status.visible = false
	results = PanelContainer.new()
	results.position = Vector2(560, 330)
	results.size = Vector2(800, 360)
	hud.add_child(results)
	var column := VBoxContainer.new()
	results.add_child(column)
	summary = Label.new()
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.add_theme_font_size_override("font_size", 36)
	column.add_child(summary)
	replay = Button.new()
	replay.text = GameSettings.text("再来一局" if NetworkSession.practice or NetworkSession.local_duel else "返回大厅")
	replay.custom_minimum_size.y = 70
	replay.pressed.connect(_replay)
	column.add_child(replay)
	var exit := Button.new()
	exit.text = GameSettings.text("退出对局")
	exit.custom_minimum_size.y = 70
	exit.pressed.connect(_show_exit_dialog)
	column.add_child(exit)
	exit_confirmation = EXIT_DIALOG.new()
	exit_confirmation.confirmed.connect(func(): NetworkSession.leave("已退出对局。"))
	exit_confirmation.dismissed.connect(_resume_after_pause_dialog)
	layer.add_child(exit_confirmation)
	for id in NetworkSession.players:
		var actor = ACTOR.instantiate()
		var info: Dictionary = NetworkSession.players[id]
		actor.skin = SKINS.skins[int(info.get("skin", 0))]
		actor.hat = HATS.hats[int(info.get("hat", 0))]
		actor.scale = Vector2.ONE * WORLD.ACTOR_SCALE
		actor.mouse_gaze_enabled = int(id) == NetworkSession.local_player_id()
		actor.externally_positioned = true
		add_child(actor)
		var player_name := str(info["name"])
		if player_name in ["练习伙伴", "电脑伙伴"]: player_name = GameSettings.text(player_name)
		actor.set_player_name(player_name)
		actors[id] = actor
		buffers[id] = BUFFER.new()
	NetworkSession.snapshot_received.connect(_snapshot)
	NetworkSession.gameplay_event.connect(_event)
	NetworkSession.phase_changed.connect(_phase)
	NetworkSession.pause_changed.connect(_pause)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_phase(NetworkSession.phase)
	if not NetworkSession.last_snapshot.is_empty() and int(NetworkSession.last_snapshot.get("match_id", -1)) == NetworkSession.match_id: _snapshot(NetworkSession.last_snapshot)
	_update_audio_listener()
	_loaded.call_deferred()

func _label(pos: Vector2, dimensions: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = dimensions
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("51391d"))
	hud.add_child(label)
	return label

func _layout() -> void:
	var view := get_viewport_rect().size
	var fit := WORLD.fit_scale(view)
	camera.zoom = Vector2.ONE * fit
	camera.force_update_scroll()
	hud.scale = Vector2.ONE * fit
	hud.position = (view - WORLD.SIZE * fit) * 0.5

func _loaded() -> void:
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = 2.0
	timer.timeout.connect(_confirm_loaded)
	add_child(timer)
	timer.start()

func _confirm_loaded() -> void:
	if NetworkSession.phase == "LOADING": NetworkSession.confirm_loaded()

func _phase(value: String) -> void:
	if not is_inside_tree(): return
	results.visible = value == "RESULTS"
	replay.disabled = not multiplayer.is_server()
	if value == "PLAYING": player_input.activate(actors, NetworkSession.local_duel)
	elif value == "RESULTS": _release_movement()
	elif value in ["LOBBY", "LOADING"]: player_input.clear()

func _show_exit_dialog() -> void:
	exit_confirmation.show_dialog("退出对局？", "确定退出当前对局并返回大厅吗？", "退出对局")

func _resume_after_pause_dialog() -> void:
	if NetworkSession.paused and NetworkSession.phase == "PLAYING" and (NetworkSession.practice or NetworkSession.local_duel):
		NetworkSession.toggle_local_pause()

func _snapshot(data: Dictionary) -> void:
	if not data.has("ball"): return
	snapshot_time = float(data["server_time"])
	countdown = float(data["remaining"])
	var next: Dictionary = data["ball"]
	var epoch := int(data.get("epoch", 0))
	if shown_epoch != epoch or int(next["rally"]) != int(ball_data.get("rally", -1)) or bool(next["active"]) != bool(ball_data.get("active", false)):
		ball_buffer.clear()
		for buffer in buffers.values(): buffer.clear()
		if shown_epoch != epoch:
			for id in actors:
				actors[id].last_event = int(data.get("players", {}).get(id, {}).get("event_id", 0))
	shown_epoch = epoch
	var next_hit_id := int(next.get("hit_id", 0))
	if has_seen_ball_snapshot and next_hit_id > last_ball_hit_id:
		var pitch := 1.0 + float((next_hit_id % 5) - 2) * 0.035
		AudioManager.play_positional_cue("ball_hit", next.get("hit_position", next["position"]), null, 0.42, pitch)
	last_ball_hit_id = next_hit_id
	has_seen_ball_snapshot = true
	ball_data = next
	if displayed_ball == Vector2.ZERO: displayed_ball_rotation = float(ball_data.get("rotation", 0.0))
	ball_buffer.push(snapshot_time, ball_data["position"])
	for id in data["players"]:
		if not actors.has(id): continue
		var state: Dictionary = data["players"][id].duplicate()
		if not multiplayer.is_server() and id == NetworkSession.local_player_id():
			for key in ["grounded", "crouching", "jumps", "velocity_y", "velocity_x"]:
				if NetworkSession.predictor.state.has(key): state[key] = NetworkSession.predictor.state[key]
		buffers[id].push(snapshot_time, state["position"])
		actors[id].update_state(state, 0.5, 0.7, 0.9)
		actors[id].modulate = Color(1, 0.92, 0.72) if int(state["team"]) == 0 else Color(0.8, 0.9, 1)
	for id in actors:
		actors[id].visible = data["players"].has(id)
	var scores: Array = ball_data["scores"]
	left_score.text = GameSettings.text("左队  %s" % scores[0])
	right_score.text = GameSettings.text("%s  右队" % scores[1])
	if int(ball_data["winner"]) >= 0: summary.text = GameSettings.text("%s获胜！\n%s : %s" % ["左队" if int(ball_data["winner"]) == 0 else "右队", scores[0], scores[1]])

func _process(_delta: float) -> void:
	var time := NetworkSession.server_now()
	if NetworkSession.paused: time = snapshot_time
	for id in actors:
		if buffers[id].samples.is_empty(): continue
		actors[id].position = buffers[id].position_at(time)
		if multiplayer.is_server() and MatchController.states.has(id): actors[id].position = MatchController.states[id]["position"]
		elif id == NetworkSession.local_player_id() and not NetworkSession.predictor.state.is_empty():
			var predicted: Dictionary = NetworkSession.predictor.state
			actors[id].position = predicted["position"]
			actors[id].set_walking(float(predicted.get("velocity_x", 0.0)) / MOTION.CONFIG.move_speed, MOTION.is_grounded(predicted))
			actors[id].set_crouching(bool(predicted.get("crouching", false)))
	_update_audio_listener()
	if not ball_data.is_empty():
		displayed_ball = ball_buffer.position_at(time)
		displayed_ball_rotation = lerp_angle(displayed_ball_rotation, float(ball_data.get("rotation", 0.0)), 1.0 - exp(-18.0 * _delta))
		if multiplayer.is_server() and MatchController.ball != null:
			displayed_ball = MatchController.ball.position
			displayed_ball_rotation = MatchController.ball.spin_angle
	status.visible = NetworkSession.paused or NetworkSession.phase == "COUNTDOWN"
	if NetworkSession.paused:
		status.text = GameSettings.text("已暂停 · 按 Esc 继续" if NetworkSession.practice or NetworkSession.local_duel else "暂停 · 等待连接恢复")
	elif NetworkSession.phase == "COUNTDOWN": status.text = GameSettings.text("准备  %s" % maxi(1, ceili(countdown - maxf(0, time - snapshot_time))))
	queue_redraw()

func _update_audio_listener() -> void:
	if not is_instance_valid(audio_listener): return
	if NetworkSession.local_duel and actors.has(1) and actors.has(2):
		audio_listener.global_position = (actors[1].global_position + actors[2].global_position) * 0.5
	else:
		var local_id := NetworkSession.local_player_id()
		if actors.has(local_id): audio_listener.global_position = actors[local_id].global_position

func _event(data: Dictionary) -> void:
	var peer_id := int(data.get("peer_id", 0))
	if actors.has(peer_id): actors[peer_id].play_event(data)

func _draw() -> void:
	if ball_data.is_empty(): return
	if bool(ball_data["active"]):
		_draw_mud_ball(self, displayed_ball, displayed_ball_rotation)
	elif NetworkSession.phase == "PLAYING":
		_draw_burst(self, ball_data)

func _draw_layer(canvas: Node2D, depth: int) -> void:
	var visible := WORLD.visible_world(self)
	if depth == LAYERS.Depth.FAR:
		_draw_ceiling(canvas, visible)
	elif depth == LAYERS.Depth.MIDDLE:
		_draw_stadium_arches(canvas)
		_draw_court(canvas)
		_draw_stadium_rope_lights(canvas)
	else:
		_draw_spectator_stands(canvas)
		_draw_central_wall(canvas)

func _draw_ceiling(canvas: Node2D, visible: Rect2) -> void:
	canvas.draw_rect(Rect2(visible.position.x, 0, visible.size.x, 286), Color("e8d18f"))
	canvas.draw_rect(Rect2(visible.position.x, 0, visible.size.x, 18), Color("aa7737"))
	canvas.draw_rect(Rect2(visible.position.x, 18, visible.size.x, 8), Color("d7ae59"))
	# Repeating timber ribs close off the arena above the court.
	for beam_x in range(-80, 2000, 400):
		var center := Vector2(beam_x + 200.0, -88.0)
		canvas.draw_arc(center, 310.0, 0.34, PI - 0.34, 32, Color("b1813b"), 18.0, true)
		canvas.draw_arc(center, 295.0, 0.36, PI - 0.36, 32, Color("f2dfa4"), 5.0, true)
	canvas.draw_rect(Rect2(visible.position.x, 270, visible.size.x, 18), Color("bd8840"))
	canvas.draw_line(Vector2(visible.position.x, 270), Vector2(visible.end.x, 270), Color("f5df9e"), 5.0, true)

func _draw_stadium_arches(canvas: Node2D) -> void:
	var dark := Color("9b6530")
	var mid := Color("bf8435")
	for side in [-1, 1]:
		var x := 196.0 if side < 0 else 1724.0
		for beam in 5:
			var top := 294.0 + beam * 112.0
			var foot := 770.0 - beam * 18.0
			canvas.draw_line(Vector2(x, top), Vector2(96.0 if side < 0 else 1824.0, foot), dark, 13.0, true)
			canvas.draw_line(Vector2(x - side * 4, top), Vector2(96.0 if side < 0 else 1824.0, foot), Color("dda94b"), 4.0, true)
		for crossbar in 4:
			var y := 356.0 + crossbar * 116.0
			canvas.draw_line(Vector2(20 if side < 0 else 1900, y), Vector2(194 if side < 0 else 1726, y), mid, 7.0, true)
		canvas.draw_rect(Rect2(15 if side < 0 else 1865, 230, 40, 540), Color(dark, 0.22))

func _draw_spectator_stands(canvas: Node2D) -> void:
	var decks := COURT.platforms()
	for tier in 5:
		var y := COURT.FLOOR - 110.0 * (tier + 1)
		var left: Rect2 = decks[1 + tier * 2]
		var right: Rect2 = decks[2 + tier * 2]
		_draw_seating_row(canvas, left, tier, -1)
		_draw_seating_row(canvas, right, tier, 1)
		# A diagonal riser links the lower inner shelf to the higher outer shelf.
		if tier < 4:
			var inner_left: Vector2 = left.position + Vector2(left.size.x * 0.76, 18)
			var outer_left: Vector2 = decks[1 + (tier + 1) * 2].position + Vector2(decks[1 + (tier + 1) * 2].size.x * 0.9, 18)
			canvas.draw_line(inner_left + Vector2(0, 16), outer_left + Vector2(0, 16), Color("ad7934"), 10.0, true)
			var inner_right: Vector2 = right.position + Vector2(right.size.x * 0.24, 18)
			var outer_right: Vector2 = decks[2 + (tier + 1) * 2].position + Vector2(decks[2 + (tier + 1) * 2].size.x * 0.1, 18)
			canvas.draw_line(inner_right + Vector2(0, 16), outer_right + Vector2(0, 16), Color("ad7934"), 10.0, true)
	# A broad, softly lit band separates the seats from the field.
	canvas.draw_rect(Rect2(0, 826, 1920, 42), Color("ca963c"))
	canvas.draw_line(Vector2(0, 828), Vector2(1920, 828), Color("f6d57a"), 5.0, true)

func _draw_seating_row(canvas: Node2D, deck: Rect2, tier: int, side: int) -> void:
	var shadow := Color("916025")
	var wood := Color("c58a36")
	canvas.draw_rect(Rect2(deck.position + Vector2(0, 14), Vector2(deck.size.x, 20)), shadow)
	canvas.draw_rect(Rect2(deck.position + Vector2(6, 23), Vector2(deck.size.x - 12, 7)), Color(Color("784d28"), 0.62))
	canvas.draw_rect(Rect2(deck.position + Vector2(0, 6), Vector2(deck.size.x, 12)), wood)
	canvas.draw_rect(Rect2(deck.position + Vector2(2, 2), Vector2(deck.size.x - 4, 5)), Color("ffe49a"))
	for seat in 5:
		var x := deck.position.x + 10 + seat * 31
		var seat_color: Color = [Color("bb7552"), Color("718b8c"), Color("d1a34e"), Color("8574a0"), Color("78905f")][(seat + tier + (0 if side < 0 else 1)) % 5]
		canvas.draw_rect(Rect2(x, deck.position.y - 2, 24, 8), Color("80542d"))
		canvas.draw_rect(Rect2(x + 2, deck.position.y - 7, 20, 7), Color("e7bd6b"))
		canvas.draw_rect(Rect2(x + 4, deck.position.y - 6, 16, 4), seat_color)
		canvas.draw_line(Vector2(x + 3, deck.position.y + 2), Vector2(x + 3, deck.position.y + 9), Color("704a2c"), 2.0, true)
		canvas.draw_line(Vector2(x + 21, deck.position.y + 2), Vector2(x + 21, deck.position.y + 9), Color("704a2c"), 2.0, true)

func _draw_stadium_rope_lights(canvas: Node2D) -> void:
	var points := PackedVector2Array()
	for index in 17:
		var x := 218.0 + index * 93.0
		var y := 277.0 + sin(float(index) * PI / 16.0) * 20.0
		points.append(Vector2(x, y))
	canvas.draw_polyline(points, Color("9c7039"), 2.0, true)
	for index in 17:
		var point: Vector2 = points[index]
		canvas.draw_line(point, point + Vector2(0, 8), Color("a47a43"), 2.0, true)
		canvas.draw_circle(point + Vector2(0, 13), 4.2, Color("c8913d"))
		canvas.draw_circle(point + Vector2(-1, 12), 1.5, Color("fff1bd"))
	# Small emblem boards mark each end of the court.
	for side in [-1, 1]:
		var sign_x := 270.0 if side < 0 else 1650.0
		var sign_color := Color("ba6746") if side < 0 else Color("557d9a")
		canvas.draw_rect(Rect2(sign_x, 365, 22, 96), Color("8c5b31"))
		canvas.draw_rect(Rect2(sign_x - 7, 357, 36, 74), Color("fff0c2"))
		canvas.draw_rect(Rect2(sign_x - 3, 361, 28, 66), sign_color)
		canvas.draw_circle(Vector2(sign_x + 11, 394), 17, Color("ffe4a3"))
		canvas.draw_arc(Vector2(sign_x + 11, 394), 12, 0.2, 2.3, 18, sign_color, 3.0, true)
		canvas.draw_arc(Vector2(sign_x + 11, 394), 12, 3.2, 5.4, 18, sign_color, 3.0, true)
		canvas.draw_circle(Vector2(sign_x + 11, 394), 3, sign_color)

func _draw_court(canvas: Node2D) -> void:
	# The playing area has a painted sand texture and layered wooden boundary trim.
	canvas.draw_rect(Rect2(0, 864, 1920, 216), Color("81572d"))
	canvas.draw_rect(Rect2(0, 874, 1920, 206), Color("ad7835"))
	canvas.draw_rect(Rect2(170, 277, 1580, 588), Color("bf8e41"))
	canvas.draw_rect(Rect2(184, 287, 1552, 568), Color("f0cf73"))
	canvas.draw_rect(Rect2(195, 298, 1530, 540), Color("f7df96"))
	for grain in 220:
		var x := 202.0 + fmod(grain * 271.0, 1510.0)
		var y := 304.0 + fmod(grain * 97.0, 525.0)
		var length := 7.0 + fmod(grain * 13.0, 19.0)
		canvas.draw_line(Vector2(x, y), Vector2(x + length, y + (fmod(grain * 3.0, 5.0) - 2.0)), Color(Color("d5ae59"), 0.27), 1.6, true)
	# Soft shaded end zones, center marks, service lines and edge dashes.
	canvas.draw_rect(Rect2(205, 310, 700, 516), Color(Color("f7ce70"), 0.22))
	canvas.draw_rect(Rect2(1015, 310, 700, 516), Color(Color("e9c36b"), 0.24))
	canvas.draw_line(Vector2(960, 316), Vector2(960, 815), Color(Color("bf8e45"), 0.7), 3.0, true)
	canvas.draw_circle(Vector2(960, 565), 70, Color(1.0, 0.94, 0.73, 0.18))
	canvas.draw_arc(Vector2(960, 565), 66, 0, TAU, 64, Color(Color("fff0bd"), 0.48), 3.0, true)
	canvas.draw_arc(Vector2(960, 565), 49, 0, TAU, 48, Color(Color("dfb65f"), 0.52), 2.0, true)
	canvas.draw_line(Vector2(214, 310), Vector2(1706, 310), Color("fff1c2"), 5.0, true)
	canvas.draw_line(Vector2(198, 846), Vector2(1722, 846), Color("9b672e"), 8.0, true)
	canvas.draw_line(Vector2(204, 840), Vector2(1716, 840), Color("fff0b6"), 5.0, true)
	for side in [-1, 1]:
		var x := 221.0 if side < 0 else 1699.0
		for mark in 5:
			var y := 384.0 + mark * 92.0
			canvas.draw_line(Vector2(x, y), Vector2(x + (24 if side < 0 else -24), y), Color(Color("a67a3d"), 0.48), 3.0, true)
	# Floorboards and clipped decorative inlays make the front lip feel hand built.
	for plank in 30:
		var x := float(plank) * 66.0
		canvas.draw_line(Vector2(x, 885), Vector2(x - 8, 1076), Color(Color("f0c46b"), 0.30), 3.0, true)
		canvas.draw_line(Vector2(x + 32, 910), Vector2(x + 38, 920), Color(Color("704c2b"), 0.5), 2.0, true)
	canvas.draw_line(Vector2(0, 877), Vector2(1920, 877), Color("ffe8a2"), 7.0, true)

func _draw_central_wall(canvas: Node2D) -> void:
	var wall := COURT.WALL
	canvas.draw_rect(Rect2(wall.position + Vector2(-15, 8), wall.size + Vector2(30, 18)), Color(Color("9b682f"), 0.30))
	canvas.draw_rect(Rect2(wall.position + Vector2(-8, 7), wall.size + Vector2(16, 9)), Color("a96932"))
	canvas.draw_rect(Rect2(wall.position + Vector2(-6, 2), wall.size + Vector2(12, 10)), Color("fff0b4"))
	canvas.draw_rect(Rect2(wall.position, wall.size), Color("c5813d"))
	canvas.draw_rect(Rect2(wall.position + Vector2(5, 8), Vector2(6, wall.size.y - 9)), Color("e5a34f"))
	for stripe in 4:
		var y := wall.position.y + 17 + stripe * 12
		canvas.draw_line(Vector2(wall.position.x + 14, y), Vector2(wall.end.x - 5, y + 5), Color(Color("854f2d"), 0.68), 3.0, true)
	for stud in 3:
		canvas.draw_circle(Vector2(wall.position.x + 23, wall.position.y + 15 + stud * 20), 2.0, Color("ffdfa0"))

func _draw_mud_ball(canvas: Node2D, center: Vector2, rotation: float) -> void:
	# Flat clay colour, an uneven silhouette and a few dents; no layered gloss.
	_ellipse(canvas, Vector2(center.x + 10, 884), Vector2(42, 9), Color(0.35, 0.22, 0.08, 0.20))
	var outline := PackedVector2Array()
	for index in 48:
		var angle := TAU * float(index) / 48.0
		var radius := COURT.RADIUS + sin(angle * 5.0 + 0.4) * 1.3 + sin(angle * 9.0) * 0.65
		outline.append(center + Vector2.from_angle(angle + rotation) * radius)
	canvas.draw_colored_polygon(outline, Color("d7aa53"))
	outline.append(outline[0])
	canvas.draw_polyline(outline, Color("73552f"), 3.2, true)
	var dents := [Vector2(-8, -16), Vector2(15, -6), Vector2(-14, 9), Vector2(9, 16), Vector2(-24, -3)]
	for index in dents.size():
		var dent: Vector2 = center + dents[index].rotated(rotation)
		var radius: float = [6.0, 3.5, 4.0, 5.0, 2.5][index]
		var tilt := rotation + float(index) * 1.7 + 0.4
		canvas.draw_arc(dent, radius, tilt, tilt + 4.4, 16, Color("73552f"), 2.3, true)

func _ellipse(canvas: Node2D, center: Vector2, radii: Vector2, tint: Color) -> void:
	var points := PackedVector2Array()
	for index in 24:
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	canvas.draw_colored_polygon(points, tint)

func _draw_burst(canvas: Node2D, data: Dictionary) -> void:
	var remaining := float(data["serve_wait"]) - maxf(0.0, NetworkSession.server_now() - snapshot_time)
	var age := clampf(1.2 - remaining, 0.0, 1.2)
	var origin: Vector2 = data["burst_position"]
	for shard in 12:
		var angle := TAU * float(shard) / 12.0
		var direction := Vector2(cos(angle), sin(angle))
		var distance := age * (78.0 + float(shard % 4) * 18.0)
		var size := maxf(0.0, (10.0 - age * 8.2) * (1.0 if shard % 3 else 1.35))
		var color: Color = [Color("a66b42"), Color("e3b16b"), Color("895433")][shard % 3]
		canvas.draw_circle(origin + direction * distance, size, color)
		canvas.draw_line(origin + direction * (distance + size), origin + direction * (distance + size + 11.0 * (1.0 - age / 1.2)), Color(color, 0.66), 2.5, true)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		if exit_confirmation.is_open:
			exit_confirmation.close_dialog()
		elif NetworkSession.phase == "PLAYING" and (NetworkSession.practice or NetworkSession.local_duel):
			NetworkSession.toggle_local_pause()
			exit_confirmation.show_dialog("游戏已暂停", "对局已暂停。继续游戏，或退出当前对局返回大厅。", "退出对局")
		else:
			_release_movement()
			_show_exit_dialog()
		get_viewport().set_input_as_handled()
		return
	if exit_confirmation.is_open or NetworkSession.phase not in ["PLAYING", "COUNTDOWN"] or NetworkSession.paused or event.is_echo(): return
	player_input.handle(event, actors, NetworkSession.local_duel)

func _release_movement() -> void:
	player_input.release(actors, NetworkSession.local_duel)

func _pause(_value: bool) -> void:
	_release_movement()
	ball_buffer.clear()
	for buffer in buffers.values(): buffer.clear()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: _release_movement()

func _exit_tree() -> void:
	if NetworkSession.snapshot_received.is_connected(_snapshot): NetworkSession.snapshot_received.disconnect(_snapshot)
	if NetworkSession.gameplay_event.is_connected(_event): NetworkSession.gameplay_event.disconnect(_event)
	if NetworkSession.phase_changed.is_connected(_phase): NetworkSession.phase_changed.disconnect(_phase)
	if NetworkSession.pause_changed.is_connected(_pause): NetworkSession.pause_changed.disconnect(_pause)
	if is_instance_valid(audio_listener) and audio_listener.is_current(): audio_listener.clear_current()

func _replay() -> void:
	if NetworkSession.local_duel:
		var first: Dictionary = NetworkSession.players[1].duplicate()
		var second: Dictionary = NetworkSession.players[2].duplicate()
		NetworkSession._close_session("正在开始下一局。")
		NetworkSession.start_local_duel.call_deferred(first["name"], second["name"], second["skin"], second["hat"])
	elif NetworkSession.practice:
		var player_name: String = NetworkSession.players[1]["name"]
		var difficulty: int = NetworkSession.practice_difficulty
		NetworkSession._close_session("正在开始下一局。")
		NetworkSession.start_practice.call_deferred(player_name, difficulty)
	else: NetworkSession.return_to_lobby()
