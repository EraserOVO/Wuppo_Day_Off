extends "res://modes/bubble_race/bubble_controller.gd"

const BALL_RULES = preload("res://modes/mud_ball/ball_rules.gd")
var ball: RefCounted

func reset() -> void:
	super.reset()
	ball = null

func prepare(peer_ids: Array, new_round_id: int) -> void:
	super.prepare(peer_ids, new_round_id)
	if NetworkSession.game_mode == "mud_ball":
		bubble_pool = null
		ball = BALL_RULES.new()
		ball.prepare(states, NetworkSession.mud_ball_target_score)

func accept_input(peer_id: int, input_round: int, sequence: int, pressed: bool, action_time := -1.0) -> void:
	if ball == null: super.accept_input(peer_id, input_round, sequence, pressed, action_time)

func accept_control(peer_id: int, input_round: int, sequence: int, action: String, value: int) -> void:
	super.accept_control(peer_id, input_round, sequence, action, value)

func _physics_process(delta: float) -> void:
	if ball == null:
		super._physics_process(delta)
		return
	if not NetworkSession.active or NetworkSession.closing or not multiplayer.is_server() or NetworkSession.paused or NetworkSession.phase != "PLAYING": return
	if NetworkSession.practice and states.has(-1):
		ball.bot(states[-1], NetworkSession.practice_difficulty, delta)
		for action: Dictionary in ball.take_bot_events():
			var kind := str(action.get("kind", "jump"))
			var details := {}
			if kind == "double_jump": details["spin_direction"] = float(action.get("spin_direction", 1.0))
			_emit_event(-1, states[-1], kind, 0.0, 0, details)
	for peer_id in states:
		if NetworkSession.is_remote_player(peer_id): _remote_motion(peer_id, states[peer_id], delta)
		else: MOTION.step(states[peer_id], delta)
	ball.step(delta, states)
	if ball.winner >= 0:
		NetworkSession.change_phase("RESULTS")
		_publish(true)

func _process(delta: float) -> void:
	if ball == null:
		super._process(delta)
		return
	if not NetworkSession.active or NetworkSession.closing or not multiplayer.is_server(): return
	if NetworkSession.paused:
		deadline += delta
		return
	if NetworkSession.phase == "LOADING" and _now() >= deadline:
		reset()
		for info in NetworkSession.players.values(): info["ready"] = false
		NetworkSession.change_phase("LOBBY")
		return
	if NetworkSession.phase == "COUNTDOWN" and _now() >= deadline:
		deadline = INF
		NetworkSession.change_phase("PLAYING")
	if NetworkSession.phase in ["COUNTDOWN", "PLAYING", "RESULTS"]:
		publish_elapsed += delta
		if publish_elapsed >= 1.0 / 30.0:
			publish_elapsed = 0.0
			_publish()

func _publish(final := false) -> void:
	if ball == null:
		super._publish(final)
		return
	snapshot_serial += 1
	NetworkSession.publish_snapshot({"match_id": round_id, "serial": snapshot_serial, "server_time": _now(), "phase": NetworkSession.phase, "paused": NetworkSession.paused, "remaining": maxf(0, deadline - _now()) if NetworkSession.phase == "COUNTDOWN" else 0.0, "players": states.duplicate(true), "ball": ball.snapshot()}, final)

func recovery_state() -> Dictionary:
	var data := super.recovery_state()
	if ball != null: data["ball"] = ball.snapshot()
	return data

func restore_recovery(data: Dictionary) -> void:
	super.restore_recovery(data)
	if data.has("ball"):
		ball = BALL_RULES.new()
		ball.restore(data["ball"])
