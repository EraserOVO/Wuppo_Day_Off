extends Node

const CONFIG = preload("res://modes/bubble_race/bubble_config.tres")
const RULES = preload("res://modes/bubble_race/bubble_rules.gd")
const BALANCED_BUBBLES = preload("res://modes/bubble_race/balanced_bubbles.gd")
const MOTION = preload("res://core/player_motion.gd")
const BOT_DIFFICULTIES := [
	{
		"charge_min": 0.56, "charge_max": 0.70, "charge_floor": 0.50,
		"bubble_mistake_rate": 0.34, "bubble_burst_share": 0.24, "bubble_early_min": 0.16, "bubble_early_max": 0.28,
		"whistle_mistake_rate": 0.45, "whistle_late_min": 0.35, "whistle_late_max": 0.70,
		"platform_jump_chance": 0.65,
		"threat_charge_start": 0.58, "threat_charge_end": 0.44,
		"first_min": 1.0, "first_max": 1.8, "recovery_min": 1.8, "recovery_max": 3.2,
		"idle_blow_chance": 0.34, "idle_blow_min": 0.9, "idle_blow_max": 1.8,
		"urgent_min": 0.35, "urgent_max": 0.55,
		"whistle_delay_min": 0.35, "whistle_delay_max": 0.65, "whistle_threshold": 0.88,
		"whistle_confidence": 0.12, "whistle_range": 0.72, "clutch_bonus": 0.02,
		"lookahead": 0.08, "desired_gap": 390.0, "move_min": 0.40, "move_max": 0.72,
		"decision_min": 0.30, "decision_max": 0.58, "pause_chance": 0.32,
		"move_rest_chance": 0.50, "move_rest_min": 0.35, "move_rest_max": 0.8,
		"jump_ground_chance": 0.12, "jump_high_chance": 0.25, "jump_delay_min": 0.38,
		"jump_delay_max": 0.70, "jump_ready_min": 1.0, "jump_ready_max": 1.45,
		"double_jump_min": 0.40, "double_jump_max": 0.62, "second_jump_ready_min": 1.1,
		"second_jump_ready_max": 1.5, "escape_charge": 0.65
	},
	{
		"charge_min": 0.80, "charge_max": 0.985, "charge_floor": 0.64,
		"bubble_mistake_rate": 0.18, "bubble_burst_share": 0.25, "bubble_early_min": 0.14, "bubble_early_max": 0.26,
		"whistle_mistake_rate": 0.24, "whistle_late_min": 0.24, "whistle_late_max": 0.52,
		"platform_jump_chance": 0.88,
		"threat_charge_start": 0.84, "threat_charge_end": 0.64,
		"first_min": 0.7, "first_max": 1.2, "recovery_min": 1.3, "recovery_max": 2.4,
		"idle_blow_chance": 0.24, "idle_blow_min": 0.7, "idle_blow_max": 1.5,
		"urgent_min": 0.12, "urgent_max": 0.26,
		"whistle_delay_min": 0.16, "whistle_delay_max": 0.42, "whistle_threshold": 0.64,
		"whistle_confidence": 0.42, "whistle_range": 1.0, "clutch_bonus": 0.12,
		"lookahead": 0.24, "desired_gap": 255.0, "move_min": 0.19, "move_max": 0.43,
		"decision_min": 0.11, "decision_max": 0.31, "pause_chance": 0.13,
		"move_rest_chance": 0.36, "move_rest_min": 0.25, "move_rest_max": 0.65,
		"jump_ground_chance": 0.38, "jump_high_chance": 0.62, "jump_delay_min": 0.16,
		"jump_delay_max": 0.43, "jump_ready_min": 0.64, "jump_ready_max": 1.05,
		"double_jump_min": 0.20, "double_jump_max": 0.36, "second_jump_ready_min": 0.75,
		"second_jump_ready_max": 1.2, "escape_charge": 0.34
	},
	{
		"charge_min": 0.93, "charge_max": 0.97, "charge_floor": 0.85,
		"bubble_mistake_rate": 0.07, "bubble_burst_share": 0.18, "bubble_early_min": 0.10, "bubble_early_max": 0.20,
		"whistle_mistake_rate": 0.10, "whistle_late_min": 0.12, "whistle_late_max": 0.30,
		"platform_jump_chance": 0.97,
		"threat_charge_start": 0.94, "threat_charge_end": 0.76,
		"first_min": 0.45, "first_max": 0.9, "recovery_min": 0.8, "recovery_max": 1.7,
		"idle_blow_chance": 0.16, "idle_blow_min": 0.45, "idle_blow_max": 1.1,
		"urgent_min": 0.04, "urgent_max": 0.12,
		"whistle_delay_min": 0.05, "whistle_delay_max": 0.16, "whistle_threshold": 0.52,
		"whistle_confidence": 0.80, "whistle_range": 1.0, "clutch_bonus": 0.16,
		"lookahead": 0.40, "desired_gap": 185.0, "move_min": 0.18, "move_max": 0.40,
		"decision_min": 0.04, "decision_max": 0.12, "pause_chance": 0.02,
		"move_rest_chance": 0.22, "move_rest_min": 0.18, "move_rest_max": 0.48,
		"jump_ground_chance": 0.80, "jump_high_chance": 0.95, "jump_delay_min": 0.06,
		"jump_delay_max": 0.18, "jump_ready_min": 0.38, "jump_ready_max": 0.65,
		"double_jump_min": 0.10, "double_jump_max": 0.19, "second_jump_ready_min": 0.48,
		"second_jump_ready_max": 0.75, "escape_charge": 0.20
	}
]
var bubble_pool: BalancedBubblePool
var states: Dictionary = {}
var round_id := 0
var deadline := 0.0
var publish_elapsed := 0.0
var bot_next_action := 0.0
var bot_release_time := 0.0
var snapshot_serial := 0
var bot_jump_ready := 0.0
var bot_next_move_decision := 0.0
var bot_move_until := 0.0
var bot_move_direction := 0
var bot_human_airborne := false
var bot_jump_pending_at := 0.0
var bot_second_jump_pending_at := 0.0
var bot_platform_jump_next_attempt := 0.0
var bot_human_blowing := false
var bot_pending_whistle_at := 0.0
var bot_whistle_attempt_at := 0.0
var bot_whistle_decided := false
var bot_whistle_wants_to_attempt := false
var bot_overcharge_mistake := false
var bot_human_sample_time := -1.0
var bot_human_sample_x := 0.0
var bot_human_velocity_x := 0.0
var motion_queues: Dictionary = {}
var motion_credit: Dictionary = {}
var motion_received: Dictionary = {}

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func reset() -> void:
	states.clear()
	deadline = 0.0
	publish_elapsed = 0.0
	bot_next_action = 0.0
	bot_release_time = 0.0
	snapshot_serial = 0
	bot_jump_ready = 0.0
	bot_next_move_decision = 0.0
	bot_move_until = 0.0
	bot_move_direction = 0
	bot_human_airborne = false
	bot_jump_pending_at = 0.0
	bot_second_jump_pending_at = 0.0
	bot_platform_jump_next_attempt = 0.0
	bot_human_blowing = false
	bot_pending_whistle_at = 0.0
	bot_whistle_attempt_at = 0.0
	bot_whistle_decided = false
	bot_whistle_wants_to_attempt = false
	bot_overcharge_mistake = false
	bot_human_sample_time = -1.0
	bot_human_sample_x = 0.0
	bot_human_velocity_x = 0.0
	bubble_pool = null
	motion_queues.clear()
	motion_credit.clear()
	motion_received.clear()

func prepare(peer_ids: Array, new_round_id: int) -> void:
	reset()
	round_id = new_round_id
	bubble_pool = BALANCED_BUBBLES.new(CONFIG.bubble_seconds_min, CONFIG.bubble_seconds_max)
	peer_ids = peer_ids.duplicate()
	peer_ids.sort()
	for peer_id in peer_ids:
		states[peer_id] = {"state": "idle", "start": 0.0, "ratio": 0.0, "score": 0, "exact_score": 0.0, "best": 0, "sequence": 0, "last_input": -1.0, "event_id": 0, "released": 0, "bursts": 0, "limit": CONFIG.bubble_seconds_min, "held": 0.0}
		var index := peer_ids.find(peer_id)
		states[peer_id].merge({"position": MOTION.spawn_position(lerpf(220.0, 1580.0, float(index) / maxf(1.0, peer_ids.size() - 1.0))), "velocity_x": 0.0, "velocity_y": 0.0, "move": 0, "crouching": false, "crouch_requested": false, "jumps": 0, "control_sequence": 0, "charge_bonus": 0.0, "whistle_contributions": {}, "whistle_ready": 0.0, "whistle_cooldown_duration": CONFIG.whistle_cooldown})
		states[peer_id].merge({"motion_ack": 0, "input_time": 0.0})
		states[peer_id].merge({"grounded": true, "jump_boosted": false, "crouch_jump_remaining": 0.0})
	deadline = _now() + 15.0

func begin_countdown() -> void:
	deadline = _now() + CONFIG.countdown
	NetworkSession.change_phase("COUNTDOWN")
	_publish()

func _blow_rate(state: Dictionary) -> float:
	return CONFIG.crouch_blow_rate if bool(state.get("crouching", false)) else 1.0

func _record_bubble_posture(state: Dictionary, at: float) -> void:
	var rate := _blow_rate(state)
	if state.get("state", "idle") == "blowing" and not is_equal_approx(rate, float(state.get("charge_rate", 1.0))):
		var segments: Array = state.get("charge_segments", [])
		segments.append({"at": at, "rate": rate})
		state["charge_segments"] = segments
	state["charge_rate"] = rate

func _natural_charge_at(state: Dictionary, at: float) -> float:
	# Integrate each posture interval; backdated releases use the posture at that time.
	var start := float(state["start"])
	var finish := maxf(start, at)
	var cursor := start
	var rate := float(state.get("charge_initial_rate", 1.0))
	var charge := 0.0
	for segment: Dictionary in state.get("charge_segments", []):
		var boundary := clampf(float(segment["at"]), start, finish)
		charge += maxf(0, boundary - cursor) * rate
		cursor = boundary
		rate = float(segment["rate"])
		if boundary >= finish: break
	return charge + maxf(0, finish - cursor) * rate

func _refresh_charge(state: Dictionary, at: float) -> float:
	state["held"] = maxf(0, at - float(state["start"]))
	state["natural_charge"] = _natural_charge_at(state, at)
	var charge := float(state["natural_charge"]) + float(state["charge_bonus"]) * float(state["limit"])
	state["ratio"] = RULES.ratio(charge, float(state["limit"]))
	return charge

func accept_input(peer_id: int, input_round: int, sequence: int, pressed: bool, action_time := -1.0) -> void:
	var now := _now()
	var phase := NetworkSession.phase
	if input_round != round_id or phase != "PLAYING" or NetworkSession.paused or not states.has(peer_id): return
	var effective := now if action_time < 0.0 else clampf(action_time, now - NetworkSession.input_allowance(peer_id), now)
	if phase == "PLAYING" and (effective >= deadline or now > deadline + NetworkSession.input_allowance(peer_id)): return
	var state: Dictionary = states[peer_id]
	if sequence <= int(state["sequence"]): return
	state["sequence"] = sequence
	effective = maxf(effective, float(state.get("input_time", 0.0)))
	state["input_time"] = effective
	# Reject rapid new presses; always allow a release to clear a held action.
	if pressed:
		if effective - float(state["last_input"]) < 0.08 or state["state"] != "idle": return
		state["last_input"] = effective
		state["start"] = effective
		state["limit"] = bubble_pool.next_duration(peer_id) if phase == "PLAYING" else CONFIG.bubble_seconds_min
		state["held"] = 0.0
		state["natural_charge"] = 0.0
		state["charge_initial_rate"] = _blow_rate(state)
		state["charge_rate"] = _blow_rate(state)
		state["charge_segments"] = []
		state["charge_bonus"] = 0.0
		state["whistle_contributions"] = {}
		state["state"] = "blowing"
	else:
		if state["state"] == "blowing":
			var held := maxf(0.0, effective - float(state["start"]))
			state["held"] = held
			var limit := float(state["limit"])
			var charge := _refresh_charge(state, effective)
			if charge >= limit:
				_burst(peer_id, state)
			elif held >= CONFIG.minimum_hold:
				var progress := RULES.ratio(charge, limit)
				var perfect := progress >= CONFIG.perfect_bubble_ratio
				var points := 0
				if phase == "PLAYING":
					var exact: float = RULES.earned_points(held, CONFIG.points_per_second, limit, float(state["charge_bonus"]), float(state["natural_charge"]))
					if perfect: exact += CONFIG.perfect_bubble_bonus
					var previous := int(state["score"])
					state["exact_score"] += exact
					state["score"] = roundi(float(state["exact_score"]))
					points = int(state["score"]) - previous
					state["best"] = maxi(int(state["best"]), roundi(exact))
					state["released"] += 1
				state["whistle_contributions"] = {}
				_emit_event(peer_id, state, "release", progress, points, {"perfect": perfect})
				state["whistle_cooldown_duration"] = CONFIG.whistle_cooldown * 0.5
				state["whistle_ready"] = now + float(state["whistle_cooldown_duration"])
			else:
				state["whistle_contributions"] = {}
		state["state"] = "idle"
		state["ratio"] = 0.0
		state["held"] = 0.0
	_publish()

func accept_control(peer_id: int, input_round: int, sequence: int, action: String, value: int) -> void:
	var now := _now()
	if input_round != round_id or NetworkSession.phase != "PLAYING" or NetworkSession.paused or not states.has(peer_id): return
	if action not in ["move", "jump", "crouch", "whistle"]: return
	if now >= deadline: return
	var state: Dictionary = states[peer_id]
	if sequence <= int(state["control_sequence"]): return
	state["control_sequence"] = sequence
	if action == "move": state["move"] = clampi(value, -1, 1)
	elif action == "crouch":
		MOTION.set_crouching(state, value != 0)
		_record_bubble_posture(state, now)
		if state["state"] == "blowing": _refresh_charge(state, now)
	elif action == "jump":
		_accept_jump(peer_id, state)
	elif action == "whistle":
		if state["state"] == "blowing" or now < float(state["whistle_ready"]): return
		state["whistle_cooldown_duration"] = CONFIG.whistle_cooldown
		state["whistle_ready"] = now + float(state["whistle_cooldown_duration"])
		var hit_count := 0
		var kill_count := 0
		var whistle_break_points := 0.0
		var assisted_points: Dictionary = {}
		for other_id in states:
			if other_id == peer_id: continue
			var other: Dictionary = states[other_id]
			if other["state"] != "blowing": continue
			var distance := (state["position"] as Vector2).distance_to(other["position"])
			if distance > CONFIG.whistle_radius: continue
			var distance_ratio := clampf(distance / maxf(1.0, CONFIG.whistle_radius), 0.0, 1.0)
			var charge_impact := lerpf(CONFIG.whistle_charge_near, CONFIG.whistle_charge_far, distance_ratio)
			if bool(other.get("crouching", false)): charge_impact *= CONFIG.crouch_whistle_multiplier
			other["charge_bonus"] += charge_impact
			var contributions: Dictionary = other.get("whistle_contributions", {})
			contributions[peer_id] = float(contributions.get(peer_id, 0.0)) + charge_impact
			other["whistle_contributions"] = contributions
			_refresh_charge(other, now)
			hit_count += 1
			_emit_event(other_id, other, "whistle_hit", other["ratio"], roundi(charge_impact * 100.0))
			if other["ratio"] >= 1.0:
				kill_count += 1
				var rewards: Dictionary = _burst(other_id, other, "whistle", peer_id)
				whistle_break_points += float(rewards.get(peer_id, 0.0))
				for contributor_id in rewards:
					if contributor_id == peer_id: continue
					assisted_points[contributor_id] = float(assisted_points.get(contributor_id, 0.0)) + float(rewards[contributor_id])
		_emit_whistle_score_events(assisted_points)
		_emit_event(peer_id, state, "whistle", 0.0, hit_count, {"kills": kill_count, "whistle_break_points": whistle_break_points})
	_publish()

func accept_motion(peer_id: int, input_round: int, frames: Array) -> void:
	if input_round != round_id or NetworkSession.phase != "PLAYING" or NetworkSession.paused or not states.has(peer_id): return
	if frames.is_empty() or frames.size() > 36: return
	var ack := int(states[peer_id]["motion_ack"])
	var queue: Dictionary = motion_queues.get(peer_id, {})
	for frame in frames:
		if not frame is PackedInt32Array or frame.size() not in [3, 4]: return
		if frame[0] <= ack or frame[0] > ack + 180: continue
		if abs(frame[1]) > 1 or frame[2] not in [0, 1] or (frame.size() == 4 and frame[3] not in [0, 1]): continue
		queue[frame[0]] = frame
	motion_queues[peer_id] = queue
	motion_received[peer_id] = _now()

func _remote_motion(peer_id: int, state: Dictionary, delta: float) -> void:
	var queue: Dictionary = motion_queues.get(peer_id, {})
	var credit := minf(0.25, float(motion_credit.get(peer_id, 0.0)) + delta)
	var steps := 0
	while not queue.is_empty() and credit >= MOTION.STEP and steps < 4:
		var keys: Array = queue.keys()
		keys.sort()
		var next: int = keys[0]
		# A long loss can exceed the redundant history. Skip the gap, never simulate free extra time.
		var frame: PackedInt32Array = queue[next]
		queue.erase(next)
		state["move"] = frame[1]
		MOTION.set_crouching(state, frame.size() == 4 and frame[3] == 1)
		if frame[2] == 1: _accept_jump(peer_id, state)
		MOTION.step(state, MOTION.STEP)
		_record_bubble_posture(state, _now())
		state["motion_ack"] = next
		credit -= MOTION.STEP
		steps += 1
	if _now() - float(motion_received.get(peer_id, _now())) > 0.25:
		state["move"] = 0
		state["crouching"] = false
		state["crouch_requested"] = false
		if steps == 0: MOTION.step(state, delta)
	motion_credit[peer_id] = credit

func _accept_jump(peer_id: int, state: Dictionary) -> void:
	var is_double_jump := int(state.get("jumps", 0)) == 1
	if not MOTION.jump(state): return
	_record_bubble_posture(state, _now())
	if is_double_jump:
		var spin_direction := MOTION.double_jump_direction(state)
		_emit_event(peer_id, state, "double_jump", 0.0, 0, {"spin_direction": spin_direction})
	else:
		_emit_event(peer_id, state, "jump", 0.0, 0)

func reset_peer_inputs(peer_id: int) -> void:
	if not states.has(peer_id): return
	states[peer_id]["sequence"] = 0
	states[peer_id]["control_sequence"] = 0
	states[peer_id]["motion_ack"] = 0
	states[peer_id]["move"] = 0
	states[peer_id]["crouching"] = false
	states[peer_id]["crouch_requested"] = false
	states[peer_id]["crouch_jump_remaining"] = 0.0
	motion_queues.erase(peer_id)
	motion_credit.erase(peer_id)
	motion_received.erase(peer_id)

func _move_player(state: Dictionary, delta: float) -> void:
	MOTION.step(state, delta)
	_record_bubble_posture(state, _now())

func stop_player_controls() -> void:
	for state in states.values():
		state["move"] = 0
		state["crouching"] = false
		state["crouch_requested"] = false
		state["crouch_jump_remaining"] = 0.0
	motion_queues.clear()
	motion_credit.clear()
	motion_received.clear()

func _physics_process(delta: float) -> void:
	if not NetworkSession.active or NetworkSession.closing or not multiplayer.is_server() or NetworkSession.paused or NetworkSession.phase != "PLAYING": return
	if _now() >= deadline: return
	for peer_id in states:
		if NetworkSession.is_remote_player(peer_id): _remote_motion(peer_id, states[peer_id], delta)
		else: _move_player(states[peer_id], delta)

func _process(delta: float) -> void:
	if not NetworkSession.active or NetworkSession.closing or not multiplayer.is_server(): return
	var phase: String = NetworkSession.phase
	var now := _now()
	if NetworkSession.paused:
		deadline += delta
		for state in states.values():
			state["start"] += delta
			state["last_input"] += delta
			state["input_time"] = float(state.get("input_time", 0.0)) + delta
			state["whistle_ready"] += delta
			for segment: Dictionary in state.get("charge_segments", []): segment["at"] += delta
		return
	if phase == "LOADING" and now >= deadline:
		reset()
		for info in NetworkSession.players.values(): info["ready"] = false
		NetworkSession.change_phase("LOBBY")
		NetworkSession.status_changed.emit("场景加载超时，请重新准备。")
		return
	if phase == "COUNTDOWN" and now >= deadline:
		deadline = now + NetworkSession.room_duration
		NetworkSession.change_phase("PLAYING")
		_publish()
		return
	if phase == "RESULTS":
		for peer_id in states:
			var state: Dictionary = states[peer_id]
			if state["state"] != "blowing": continue
			var held := maxf(0.0, now - float(state["start"]))
			state["held"] = held
			var charge := _refresh_charge(state, now)
			if charge >= float(state["limit"]): _burst(peer_id, state)
		publish_elapsed += delta
		if publish_elapsed >= 1.0 / 30.0:
			publish_elapsed = fmod(publish_elapsed, 1.0 / 30.0)
			_publish()
		return
	if phase != "PLAYING" and phase != "COUNTDOWN": return
	if phase == "PLAYING":
		if NetworkSession.practice and now < deadline: _update_bot(now)
		for peer_id in states:
			var state: Dictionary = states[peer_id]
			if state["state"] == "blowing":
				var held := minf(now, deadline) - float(state["start"])
				state["held"] = held
				var charge := _refresh_charge(state, minf(now, deadline))
				var compensated_charge := _natural_charge_at(state, minf(now - NetworkSession.input_allowance(peer_id), deadline)) + float(state["charge_bonus"]) * float(state["limit"])
				if charge >= float(state["limit"]) and compensated_charge >= float(state["limit"]): _burst(peer_id, state)
		if now >= deadline + NetworkSession.maximum_input_allowance():
			for state in states.values():
				state["state"] = "idle"
				state["ratio"] = 0.0
				state["held"] = 0.0
				state["move"] = 0
			NetworkSession.change_phase("RESULTS")
			_publish(true)
			return
	publish_elapsed += delta
	if publish_elapsed >= 1.0 / 30.0:
		publish_elapsed = fmod(publish_elapsed, 1.0 / 30.0)
		_publish()

func _publish(final := false) -> void:
	snapshot_serial += 1
	var public_states: Dictionary = {}
	for peer_id in states:
		var state: Dictionary = states[peer_id]
		public_states[peer_id] = {"state": state["state"], "ratio": state["ratio"], "score": state["score"], "best": state["best"], "event_id": state["event_id"], "released": state["released"], "bursts": state["bursts"], "held": state["held"], "limit": state["limit"], "exact_score": state["exact_score"]}
		public_states[peer_id].merge({"position": state["position"], "velocity_x": state.get("velocity_x", 0.0), "velocity_y": state["velocity_y"], "move": state["move"], "crouching": state.get("crouching", false), "jumps": state["jumps"], "charge_bonus": state["charge_bonus"], "whistle_remaining": maxf(0.0, float(state["whistle_ready"]) - _now()), "whistle_cooldown_duration": float(state.get("whistle_cooldown_duration", CONFIG.whistle_cooldown))})
		public_states[peer_id].merge({"motion_ack": state.get("motion_ack", 0), "input_ack": state["sequence"]})
		for key in ["grounded", "jump_boosted", "crouch_jump_remaining"]: public_states[peer_id][key] = state.get(key, false if key != "crouch_jump_remaining" else 0.0)
		public_states[peer_id]["natural_charge"] = state.get("natural_charge", state["held"])
		public_states[peer_id]["charge_rate"] = _blow_rate(state)
	NetworkSession.publish_snapshot({"match_id": round_id, "serial": snapshot_serial, "server_time": _now(), "phase": NetworkSession.phase, "paused": NetworkSession.paused, "remaining": maxf(0.0, deadline - _now()), "players": public_states}, final)

func recovery_state() -> Dictionary:
	var now := _now()
	var copy: Dictionary = states.duplicate(true)
	for state in copy.values():
		for key in ["start", "last_input", "input_time", "whistle_ready"]:
			state[key] = float(state.get(key, 0.0)) - now
		for segment: Dictionary in state.get("charge_segments", []): segment["at"] -= now
	var pool := {}
	if bubble_pool != null:
		pool = {"bags": bubble_pool.bags.duplicate(true), "queues": bubble_pool.queues.duplicate(true), "turns": bubble_pool.turns.duplicate(true), "seed": bubble_pool.rng.seed, "rng_state": bubble_pool.rng.state}
	return {"states": copy, "round_id": round_id, "remaining": maxf(0.0, deadline - now), "serial": snapshot_serial, "pool": pool}

func restore_recovery(data: Dictionary) -> void:
	reset()
	var now := _now()
	states = data.get("states", {}).duplicate(true)
	round_id = int(data.get("round_id", 0))
	deadline = now + float(data.get("remaining", 0.0))
	snapshot_serial = int(data.get("serial", 0))
	for peer_id in states:
		for key in ["start", "last_input", "input_time", "whistle_ready"]: states[peer_id][key] += now
		for segment: Dictionary in states[peer_id].get("charge_segments", []): segment["at"] += now
		reset_peer_inputs(peer_id)
	var pool: Dictionary = data.get("pool", {})
	if not pool.is_empty():
		bubble_pool = BALANCED_BUBBLES.new(CONFIG.bubble_seconds_min, CONFIG.bubble_seconds_max)
		bubble_pool.bags = pool["bags"]
		bubble_pool.queues = pool["queues"]
		bubble_pool.turns = pool["turns"]
		bubble_pool.rng.seed = pool["seed"]
		bubble_pool.rng.state = pool["rng_state"]

func _award_whistle_contributors(bubble_peer_id: int, bubble_state: Dictionary, direct_killer_id := 0) -> Dictionary:
	var contributions: Dictionary = bubble_state.get("whistle_contributions", {})
	var total_contribution := 0.0
	for value in contributions.values():
		total_contribution += maxf(0.0, float(value))
	var awards: Dictionary = {}
	var limit := maxf(0.1, float(bubble_state.get("limit", CONFIG.bubble_seconds_min)))
	var natural_progress := RULES.ratio(float(bubble_state.get("natural_charge", bubble_state.get("held", 0.0))), limit)
	var visible_whistle_ratio := minf(float(bubble_state.get("charge_bonus", 0.0)), maxf(0.0, 1.0 - natural_progress))
	if total_contribution > 0.0 and visible_whistle_ratio > 0.0:
		var original_max_score := limit * CONFIG.points_per_second + CONFIG.perfect_bubble_bonus
		for contributor_id in contributions:
			if contributor_id == bubble_peer_id or not states.has(contributor_id): continue
			var contribution := maxf(0.0, float(contributions[contributor_id]))
			if contribution <= 0.0: continue
			var contribution_ratio := visible_whistle_ratio * contribution / total_contribution
			var multiplier := 3.0 if contributor_id == direct_killer_id else 1.0
			var awarded_points := original_max_score * contribution_ratio * multiplier * CONFIG.whistle_reward_multiplier
			if awarded_points <= 0.0: continue
			var contributor: Dictionary = states[contributor_id]
			contributor["exact_score"] += awarded_points
			contributor["score"] = roundi(float(contributor["exact_score"]))
			awards[contributor_id] = awarded_points
	bubble_state["whistle_contributions"] = {}
	return awards

func _emit_whistle_score_events(awards: Dictionary) -> void:
	for contributor_id in awards:
		if not states.has(contributor_id): continue
		_emit_event(contributor_id, states[contributor_id], "whistle_score", 0.0, 0, {"awarded_points": float(awards[contributor_id])})

func _burst(peer_id: int, state: Dictionary, cause := "", direct_killer_id := 0) -> Dictionary:
	var awards: Dictionary = {}
	if NetworkSession.phase == "PLAYING":
		awards = _award_whistle_contributors(peer_id, state, direct_killer_id)
		if direct_killer_id == 0: _emit_whistle_score_events(awards)
	else:
		state["whistle_contributions"] = {}
	state["state"] = "burst"
	state["whistle_cooldown_duration"] = CONFIG.whistle_cooldown * 0.5
	state["whistle_ready"] = _now() + float(state["whistle_cooldown_duration"])
	if NetworkSession.phase == "PLAYING": state["bursts"] += 1
	_emit_event(peer_id, state, "burst", 1.0, 0, {"cause": cause})
	return awards

func _emit_event(peer_id: int, state: Dictionary, kind: String, ratio: float, points: int, details: Dictionary = {}) -> void:
	state["event_id"] += 1
	var event := {"match_id": round_id, "peer_id": peer_id, "event_id": state["event_id"], "kind": kind, "ratio": ratio, "points": points, "position": state["position"]}
	event.merge(details)
	NetworkSession.publish_event(event)

func _platform_index_at(position: Vector2) -> int:
	for index in MOTION.PLATFORMS.size():
		var platform: Rect2 = MOTION.PLATFORMS[index]
		if position.x >= platform.position.x and position.x <= platform.end.x and absf(position.y - platform.position.y) < 0.5:
			return index
	return -1

func _update_bot(now: float) -> void:
	if not states.has(-1): return
	var bot_profile: Dictionary = BOT_DIFFICULTIES[clampi(NetworkSession.practice_difficulty, 0, BOT_DIFFICULTIES.size() - 1)]
	var bot: Dictionary = states[-1]
	var human: Dictionary = states.get(1, {})
	if human.is_empty(): return

	var bot_position: Vector2 = bot["position"]
	var human_position: Vector2 = human["position"]
	var bot_platform_index := _platform_index_at(bot_position)
	var human_platform_index := _platform_index_at(human_position)
	var platform_goal_index := -1
	if human_platform_index >= 0 and human_platform_index != bot_platform_index:
		var human_platform: Rect2 = MOTION.PLATFORMS[human_platform_index]
		var bot_support_y := float(MOTION.PLATFORMS[bot_platform_index].position.y) if bot_platform_index >= 0 else MOTION.ground_height(bot_position.x)
		if human_platform.position.y < bot_support_y - 35.0: platform_goal_index = human_platform_index
	var gap := bot_position.distance_to(human_position)
	var human_x: float = human_position.x
	if bot_human_sample_time < 0.0:
		bot_human_sample_time = now
		bot_human_sample_x = human_x
	elif now - bot_human_sample_time >= 0.14:
		var sample_delta := now - bot_human_sample_time
		var observed_velocity := clampf((human_x - bot_human_sample_x) / sample_delta, -900.0, 900.0)
		bot_human_velocity_x = lerpf(bot_human_velocity_x, observed_velocity, 0.58)
		bot_human_sample_time = now
		bot_human_sample_x = human_x

	var human_blowing: bool = human["state"] == "blowing"
	var human_charge := 0.0
	if human_blowing:
		human_charge = clampf((now - float(human["start"])) / maxf(0.1, float(human["limit"])) + float(human["charge_bonus"]), 0.0, 1.0)
	var human_can_whistle := not human_blowing and now >= float(human.get("whistle_ready", 0.0))
	var match_seconds_left := maxf(0.0, deadline - now) if NetworkSession.phase == "PLAYING" else 60.0
	var trailing := int(bot["score"]) < int(human["score"])

	# Watch the opponent's charge and cooldown, then decide once per breath rather
	# than playing a fixed, perfectly timed whistle script.
	if human_blowing and not bot_human_blowing:
		bot_pending_whistle_at = now + randf_range(float(bot_profile["whistle_delay_min"]), float(bot_profile["whistle_delay_max"]))
		bot_whistle_attempt_at = bot_pending_whistle_at
		if randf() < float(bot_profile["whistle_mistake_rate"]):
			bot_whistle_attempt_at += randf_range(float(bot_profile["whistle_late_min"]), float(bot_profile["whistle_late_max"]))
		bot_whistle_decided = false
		bot_whistle_wants_to_attempt = false
	elif not human_blowing:
		bot_pending_whistle_at = 0.0
		bot_whistle_attempt_at = 0.0
		bot_whistle_decided = false
		bot_whistle_wants_to_attempt = false
	var clutch := float(bot_profile["clutch_bonus"]) if trailing and match_seconds_left < 18.0 else 0.0
	var reaction_threshold := float(bot_profile["whistle_threshold"]) - clutch
	var whistle_distance := bot_position.distance_to(human_position)
	if human_blowing and not bot_whistle_decided and bot_pending_whistle_at > 0.0 and now >= bot_whistle_attempt_at and human_charge >= reaction_threshold and whistle_distance < CONFIG.whistle_radius * float(bot_profile["whistle_range"]):
		if not bot_whistle_wants_to_attempt:
			var timing := clampf((human_charge - reaction_threshold) * 1.4, 0.0, 0.42)
			var proximity := 1.0 - whistle_distance / CONFIG.whistle_radius
			var decision_confidence := clampf(float(bot_profile["whistle_confidence"]) + timing + proximity * 0.18 + clutch, 0.0, 0.97)
			bot_whistle_wants_to_attempt = randf() < decision_confidence
			if not bot_whistle_wants_to_attempt: bot_whistle_decided = true
		if bot_whistle_wants_to_attempt:
			if bot["state"] == "blowing":
				# Finish the current bubble quickly, then reconsider while the opponent's
				# bubble is still active instead of consuming this whistle opportunity.
				bot_release_time = minf(bot_release_time, now + randf_range(0.08, 0.17))
			elif now >= float(bot["whistle_ready"]):
				bot_whistle_decided = true
				bot_whistle_wants_to_attempt = false
				accept_control(-1, round_id, int(bot["control_sequence"]) + 1, "whistle", 0)
	bot_human_blowing = human_blowing

	# Select a spacing goal. The opponent's recent direction and elevation give
	# the bot something to follow or contest instead of choosing random strafes.
	if now >= bot_next_move_decision:
		var predicted_human_x := clampf(human_x + bot_human_velocity_x * float(bot_profile["lookahead"]), MOTION.ARENA_LEFT, MOTION.ARENA_RIGHT)
		var approach_side := int(signf(predicted_human_x - bot_position.x))
		if approach_side == 0: approach_side = 1 if bot_position.x < 960.0 else -1
		var bot_charge := 0.0
		if bot["state"] == "blowing":
			bot_charge = clampf((now - float(bot["start"])) / maxf(0.1, float(bot["limit"])) + float(bot["charge_bonus"]), 0.0, 1.0)
		var opponent_threatens_with_whistle: bool = bot["state"] == "blowing" and human_can_whistle and gap < CONFIG.whistle_radius * 1.12 and bot_charge > float(bot_profile["escape_charge"])
		var desired_gap := float(bot_profile["desired_gap"])
		if absf(bot_human_velocity_x) > 360.0: desired_gap += 45.0
		if trailing and match_seconds_left < 18.0: desired_gap -= 45.0
		if gap > CONFIG.whistle_radius * 1.3: desired_gap = 410.0
		var target_x := predicted_human_x - float(approach_side) * desired_gap
		if opponent_threatens_with_whistle:
			var escape_side := -approach_side
			var escape_distance := CONFIG.whistle_radius + 115.0
			# If one arena edge is close, use the open side instead of retreating into it.
			if escape_side < 0 and bot_position.x < MOTION.ARENA_LEFT + 150.0: escape_side = 1
			elif escape_side > 0 and bot_position.x > MOTION.ARENA_RIGHT - 150.0: escape_side = -1
			target_x = predicted_human_x + float(escape_side) * escape_distance
		var desired_direction := int(signf(target_x - bot_position.x))
		if gap < desired_gap - 70.0: desired_direction = -approach_side
		elif gap <= desired_gap + 65.0 and not opponent_threatens_with_whistle:
			# Circle briefly or pause when already in a useful range.
			var choice := randf()
			if choice < float(bot_profile["pause_chance"]):
				desired_direction = bot_move_direction if bot_move_direction != 0 else approach_side
			elif choice < float(bot_profile["pause_chance"]) + 0.14: desired_direction = -approach_side
			elif absf(bot_human_velocity_x) > 110.0 and choice < 0.68: desired_direction = int(signf(bot_human_velocity_x))
		if platform_goal_index >= 0 and not opponent_threatens_with_whistle:
			var movement_platform: Rect2 = MOTION.PLATFORMS[platform_goal_index]
			var landing_x := clampf(predicted_human_x, movement_platform.position.x + 55.0, movement_platform.end.x - 55.0)
			var approach_x := landing_x
			if bot_position.x < movement_platform.position.x: approach_x = movement_platform.position.x - 40.0
			elif bot_position.x > movement_platform.end.x: approach_x = movement_platform.end.x + 40.0
			desired_direction = int(signf(approach_x - bot_position.x))
			if desired_direction == 0: desired_direction = approach_side
		if bot_position.x <= MOTION.ARENA_LEFT + 8.0 and desired_direction < 0: desired_direction = 1
		if bot_position.x >= MOTION.ARENA_RIGHT - 8.0 and desired_direction > 0: desired_direction = -1
		# Keep the current direction between replanning moments so horizontal motion
		# flows continuously instead of stopping at the end of each short input.
		bot_move_direction = desired_direction
		if randf() < float(bot_profile["move_rest_chance"]):
			bot_move_direction = 0
			bot_move_until = now + randf_range(float(bot_profile["move_rest_min"]), float(bot_profile["move_rest_max"]))
			bot_next_move_decision = bot_move_until
		else:
			bot_move_until = now + randf_range(float(bot_profile["move_min"]), float(bot_profile["move_max"]))
			bot_next_move_decision = bot_move_until + randf_range(float(bot_profile["decision_min"]), float(bot_profile["decision_max"]))
	bot["move"] = bot_move_direction

	# React to a nearby jump or someone reaching a higher surface. The response
	# has a variable delay, and the bot sometimes decides the jump is not needed.
	var human_elevated := human_position.y < bot_position.y - 90.0
	var human_airborne := not MOTION.is_supported(human_position) or human_elevated or platform_goal_index >= 0
	if human_airborne and not bot_human_airborne:
		var response_chance := float(bot_profile["jump_high_chance"]) if human_elevated or platform_goal_index >= 0 else float(bot_profile["jump_ground_chance"])
		bot_jump_pending_at = now + randf_range(float(bot_profile["jump_delay_min"]), float(bot_profile["jump_delay_max"])) if randf() < response_chance else 0.0
	elif not human_airborne:
		bot_jump_pending_at = 0.0
		bot_second_jump_pending_at = 0.0
		bot_human_airborne = false
	if platform_goal_index >= 0:
		var jump_platform: Rect2 = MOTION.PLATFORMS[platform_goal_index]
		var horizontal_gap := 0.0
		if bot_position.x < jump_platform.position.x: horizontal_gap = jump_platform.position.x - bot_position.x
		elif bot_position.x > jump_platform.end.x: horizontal_gap = bot_position.x - jump_platform.end.x
		if MOTION.is_supported(bot_position) and int(bot["jumps"]) == 0 and bot_jump_pending_at <= 0.0 and now >= bot_jump_ready and now >= bot_platform_jump_next_attempt and horizontal_gap <= 245.0:
			bot_platform_jump_next_attempt = now + randf_range(float(bot_profile["jump_ready_min"]), float(bot_profile["jump_ready_max"]))
			if randf() < float(bot_profile["platform_jump_chance"]):
				bot_jump_pending_at = now + randf_range(float(bot_profile["jump_delay_min"]), float(bot_profile["jump_delay_max"]))
	else:
		bot_platform_jump_next_attempt = 0.0
	if bot_jump_pending_at > 0.0 and now >= bot_jump_pending_at and now >= bot_jump_ready:
		accept_control(-1, round_id, int(bot["control_sequence"]) + 1, "jump", 0)
		bot_jump_pending_at = 0.0
		bot_jump_ready = now + randf_range(float(bot_profile["jump_ready_min"]), float(bot_profile["jump_ready_max"]))
		if human_position.y < bot_position.y - 145.0:
			bot_second_jump_pending_at = now + randf_range(float(bot_profile["double_jump_min"]), float(bot_profile["double_jump_max"]))
	if bot_second_jump_pending_at > 0.0 and now >= bot_second_jump_pending_at and now >= bot_jump_ready and int(bot["jumps"]) == 1 and human_position.y < bot_position.y - 150.0:
		accept_control(-1, round_id, int(bot["control_sequence"]) + 1, "jump", 0)
		bot_second_jump_pending_at = 0.0
		bot_jump_ready = now + randf_range(float(bot_profile["second_jump_ready_min"]), float(bot_profile["second_jump_ready_max"]))
	bot_human_airborne = human_airborne

	if bot["state"] == "idle":
		if bot_next_action <= 0.0: bot_next_action = now + randf_range(float(bot_profile["first_min"]), float(bot_profile["first_max"]))
		if human_blowing and gap < CONFIG.whistle_radius * 1.15:
			bot_next_action = minf(bot_next_action, now + randf_range(float(bot_profile["urgent_min"]), float(bot_profile["urgent_max"])))
		if now >= bot_next_action and now >= float(bot["whistle_ready"]):
			if randf() < float(bot_profile["idle_blow_chance"]):
				bot_next_action = now + randf_range(float(bot_profile["idle_blow_min"]), float(bot_profile["idle_blow_max"]))
			else:
				bot_overcharge_mistake = false
				accept_input(-1, round_id, int(bot["sequence"]) + 1, true)
				if bot["state"] == "blowing":
					var urgency := human_charge if human_blowing and gap < CONFIG.whistle_radius else 0.0
					var charge_goal := randf_range(float(bot_profile["charge_min"]), float(bot_profile["charge_max"]))
					if urgency > 0.0: charge_goal = minf(charge_goal, lerpf(float(bot_profile["threat_charge_start"]), float(bot_profile["threat_charge_end"]), urgency))
					if int(human["score"]) > int(bot["score"]) and match_seconds_left < 16.0:
						charge_goal = minf(float(bot_profile["charge_max"]), charge_goal + 0.06)
					elif int(bot["score"]) > int(human["score"]) and match_seconds_left < 12.0:
						charge_goal = maxf(float(bot_profile["charge_floor"]), charge_goal - 0.08)
					charge_goal = clampf(charge_goal, float(bot_profile["charge_floor"]), float(bot_profile["charge_max"]))
					if randf() < float(bot_profile["bubble_mistake_rate"]):
						if randf() < float(bot_profile["bubble_burst_share"]):
							bot_overcharge_mistake = true
							bot_release_time = now + float(bot["limit"]) * randf_range(1.025, 1.12)
						else:
							charge_goal = maxf(float(bot_profile["charge_floor"]), charge_goal - randf_range(float(bot_profile["bubble_early_min"]), float(bot_profile["bubble_early_max"])))
							bot_release_time = now + maxf(CONFIG.minimum_hold + 0.12, float(bot["limit"]) * charge_goal)
					else:
						bot_release_time = now + maxf(CONFIG.minimum_hold + 0.12, float(bot["limit"]) * charge_goal)
	elif bot["state"] == "blowing":
		var bot_progress := clampf((now - float(bot["start"])) / maxf(0.1, float(bot["limit"])) + float(bot["charge_bonus"]), 0.0, 1.0)
		var player_can_interrupt := human_can_whistle and gap < CONFIG.whistle_radius * 1.12
		if player_can_interrupt and bot_progress > 0.38:
			# Take the points when the player closes in with a whistle ready.
			bot_release_time = minf(bot_release_time, now + randf_range(0.08, 0.2))
		elif bot_progress >= 0.96 and not bot_overcharge_mistake:
			bot_release_time = minf(bot_release_time, now + randf_range(0.04, 0.11))
		if now >= bot_release_time:
			accept_input(-1, round_id, int(bot["sequence"]) + 1, false)
			bot_overcharge_mistake = false
			bot_next_action = now + randf_range(float(bot_profile["recovery_min"]), float(bot_profile["recovery_max"]))
	elif bot["state"] == "burst":
		# Clear the held action after a burst so the bot can reset.
		accept_input(-1, round_id, int(bot["sequence"]) + 1, false)
		bot_overcharge_mistake = false
		bot_next_action = now + randf_range(0.7, 1.4)

