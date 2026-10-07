extends RefCounted
const MOTION = preload("res://core/player_motion.gd")

var movement_keys: Dictionary = {}
var crouch_keys: Dictionary = {KEY_S: false, KEY_DOWN: false}
var queued_jumps: Dictionary = {1: false, 2: false}

func handle(event: InputEvent, actors: Dictionary, local_duel: bool, bubble_handler := Callable()) -> bool:
	if event.is_echo(): return false
	var can_apply := NetworkSession.phase == "PLAYING" and not NetworkSession.paused
	if not can_apply and NetworkSession.phase != "COUNTDOWN": return false
	if _update_crouch(event, actors, local_duel, can_apply): return true
	var slots := [1, 2] if local_duel else [1]
	for slot in slots:
		for action in 5:
			if action == 3 and not bubble_handler.is_valid(): continue
			if not GameSettings.matches(event, slot, action, local_duel): continue
			if action < 2:
				movement_keys["%s:%s" % [slot, action]] = event.is_pressed()
				var direction := int(bool(movement_keys.get("%s:1" % slot, false))) - int(bool(movement_keys.get("%s:0" % slot, false)))
				if can_apply: NetworkSession.submit_control("move", direction, slot)
			elif action == 2 and event.is_pressed() and can_apply:
				if _crouching_for_slot(slot, local_duel): queued_jumps[slot] = true
				else: _trigger_jump(slot, actors, local_duel)
			elif action == 4 and event.is_pressed():
				if can_apply: NetworkSession.submit_control("whistle", 0, slot)
			elif action == 3:
				bubble_handler.call(slot, event)
	return false

func _update_crouch(event: InputEvent, actors: Dictionary, local_duel: bool, can_apply: bool) -> bool:
	if not event is InputEventKey or event.physical_keycode not in [KEY_S, KEY_DOWN]: return false
	var key_code := int(event.physical_keycode)
	var slot := 2 if local_duel and key_code == KEY_DOWN else 1
	var was_crouching := _crouching_for_slot(slot, local_duel)
	crouch_keys[key_code] = event.is_pressed()
	var crouching := _crouching_for_slot(slot, local_duel)
	if can_apply:
		var actor_id := slot if local_duel else NetworkSession.local_player_id()
		var state: Dictionary = MatchController.states.get(actor_id, {}) if NetworkSession.multiplayer.is_server() else NetworkSession.predictor.state
		if actors.has(actor_id):
			if not state.is_empty(): actors[actor_id].walk_grounded = MOTION.is_grounded(state)
			actors[actor_id].set_crouching(crouching)
		NetworkSession.submit_control("crouch", int(crouching), slot)
		if was_crouching and not crouching and bool(queued_jumps.get(slot, false)):
			_trigger_jump(slot, actors, local_duel)
	return true

func _trigger_jump(slot: int, actors: Dictionary, local_duel: bool) -> void:
	queued_jumps[slot] = false
	NetworkSession.submit_control("jump", 0, slot)
	var actor_id: int = slot if local_duel else NetworkSession.local_player_id()
	if actors.has(actor_id):
		actors[actor_id].walk_grounded = false
		actors[actor_id].set_crouching(false)

func activate(actors: Dictionary, local_duel: bool) -> void:
	if NetworkSession.phase != "PLAYING": return
	for slot in ([1, 2] if local_duel else [1]):
		var direction := int(bool(movement_keys.get("%s:1" % slot, false))) - int(bool(movement_keys.get("%s:0" % slot, false)))
		NetworkSession.submit_control("move", direction, slot)
		var crouching := _crouching_for_slot(slot, local_duel)
		NetworkSession.submit_control("crouch", int(crouching), slot)
		var actor_id: int = slot if local_duel else NetworkSession.local_player_id()
		if actors.has(actor_id):
			var state: Dictionary = MatchController.states.get(actor_id, {}) if NetworkSession.multiplayer.is_server() else NetworkSession.predictor.state
			if not state.is_empty(): actors[actor_id].walk_grounded = MOTION.is_grounded(state)
			actors[actor_id].set_crouching(crouching)

func _crouching_for_slot(slot: int, local_duel: bool) -> bool:
	if local_duel: return bool(crouch_keys[KEY_S]) if slot == 1 else bool(crouch_keys[KEY_DOWN])
	return bool(crouch_keys[KEY_S]) or bool(crouch_keys[KEY_DOWN])

func release(actors: Dictionary, local_duel: bool) -> void:
	clear()
	for slot in ([1, 2] if local_duel else [1]):
		NetworkSession.submit_control("move", 0, slot)
		NetworkSession.submit_control("crouch", 0, slot)
	var local_id := NetworkSession.local_player_id()
	if local_duel:
		for id in [1, 2]:
			if actors.has(id): actors[id].set_crouching(false)
	elif actors.has(local_id):
		actors[local_id].set_crouching(false)

func clear() -> void:
	movement_keys.clear()
	crouch_keys[KEY_S] = false
	crouch_keys[KEY_DOWN] = false
	queued_jumps[1] = false
	queued_jumps[2] = false
