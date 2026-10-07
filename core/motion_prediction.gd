extends RefCounted

const MOTION = preload("res://core/player_motion.gd")
var state: Dictionary = {}
var pending: Array = []
var sequence := 0
var direction := 0
var jump_pending := false
var crouching := false

func reset() -> void:
	state.clear()
	pending.clear()
	sequence = 0
	direction = 0
	jump_pending = false
	crouching = false

func reconcile(authoritative: Dictionary) -> void:
	var ack := int(authoritative.get("motion_ack", 0))
	sequence = maxi(sequence, ack)
	while not pending.is_empty() and int(pending[0][0]) <= ack: pending.pop_front()
	state = authoritative.duplicate(true)
	for frame in pending:
		state["move"] = frame[1]
		MOTION.set_crouching(state, frame.size() >= 4 and frame[3] == 1)
		if frame[2] == 1: MOTION.jump(state)
		MOTION.step(state, MOTION.STEP)

func tick() -> void:
	if state.is_empty(): return
	sequence += 1
	var frame := PackedInt32Array([sequence, direction, int(jump_pending), int(crouching)])
	pending.append(frame)
	if pending.size() > 120: pending.pop_front()
	state["move"] = direction
	MOTION.set_crouching(state, crouching)
	if jump_pending: MOTION.jump(state)
	jump_pending = false
	MOTION.step(state, MOTION.STEP)

func packet() -> Array:
	return pending.slice(maxi(0, pending.size() - 36))
