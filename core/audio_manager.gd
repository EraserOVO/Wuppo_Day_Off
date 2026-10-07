extends Node

const COUNTDOWN = preload("res://assets/audio/countdown.wav")
const FINISH = preload("res://assets/audio/finish.wav")
const LOBBY_MUSIC = preload("res://assets/audio/lobby_bgm.wav")
const MATCH_MUSIC = preload("res://assets/audio/match_bgm.wav")
var muted := false
var volume := 0.45
var voices: Array[AudioStreamPlayer] = []
var positional_voices: Array[AudioStreamPlayer2D] = []
var next_voice := 0
var whistle_stream: AudioStreamWAV
var charge_tone_stream: AudioStreamWAV
var perfect_stream: AudioStreamWAV
var jump_stream: AudioStreamWAV
var double_jump_stream: AudioStreamWAV
var landing_stream: AudioStreamWAV
var ball_hit_stream: AudioStreamWAV
var interact_stream: AudioStreamWAV
var charge_tones: Dictionary = {}
var music_player: AudioStreamPlayer
var lobby_music_stream: AudioStreamWAV
var match_music_stream: AudioStreamWAV
var music_fade: Tween
var current_music := ""
var requested_music := ""
var music_fading := false

func _ready() -> void:
	whistle_stream = _make_whistle_stream()
	charge_tone_stream = AudioStreamWAV.new()
	charge_tone_stream.format = AudioStreamWAV.FORMAT_16_BITS
	charge_tone_stream.mix_rate = 22050
	charge_tone_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	charge_tone_stream.loop_end = 2205
	var tone_samples := PackedByteArray()
	for index in 2205:
		var phase := TAU * 440.0 * float(index) / 22050.0
		var sample := roundi((sin(phase) * 0.82 + sin(phase * 2.0) * 0.18) * 6200.0)
		tone_samples.append(sample & 255)
		tone_samples.append((sample >> 8) & 255)
	charge_tone_stream.data = tone_samples
	perfect_stream = AudioStreamWAV.new()
	perfect_stream.format = AudioStreamWAV.FORMAT_16_BITS
	perfect_stream.mix_rate = 22050
	var perfect_samples := PackedByteArray()
	for index in 3969:
		var time := float(index) / 22050.0
		var envelope := clampf(time / 0.003, 0.0, 1.0) * exp(-22.0 * time) * clampf((0.18 - time) / 0.025, 0.0, 1.0)
		var phase := TAU * 1760.0 * time
		var sample := roundi((sin(phase) * 0.9 + sin(phase * 2.0) * 0.1) * envelope * 13500.0)
		perfect_samples.append(sample & 255)
		perfect_samples.append((sample >> 8) & 255)
	perfect_stream.data = perfect_samples
	jump_stream = _make_action_stream("jump")
	double_jump_stream = _make_action_stream("double_jump")
	landing_stream = _make_action_stream("land")
	ball_hit_stream = _make_action_stream("ball_hit")
	interact_stream = _make_action_stream("interact")
	lobby_music_stream = LOBBY_MUSIC
	lobby_music_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	lobby_music_stream.loop_end = -1
	match_music_stream = MATCH_MUSIC
	match_music_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	match_music_stream.loop_end = -1
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.volume_db = -60.0
	add_child(music_player)
	var config := ConfigFile.new()
	if config.load("user://preferences.cfg") == OK:
		muted = bool(config.get_value("audio", "muted", false))
	for index in 8:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)

func _make_whistle_stream() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var samples := PackedByteArray()
	for index in 4410:
		var time := float(index) / 22050.0
		var sample := roundi(sin(TAU * (1120.0 * time + 300.0 * time * time)) * sin(PI * index / 4410.0) * 6800.0)
		samples.append(sample & 255)
		samples.append((sample >> 8) & 255)
	stream.data = samples
	return stream

func _make_action_stream(kind: String) -> AudioStreamWAV:
	const SAMPLE_RATE := 22050
	var duration := 0.13 if kind == "ball_hit" else (0.16 if kind != "double_jump" else 0.22)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	var rng := RandomNumberGenerator.new()
	rng.seed = 529103 + absi(kind.hash())
	var noise_state := 0.0
	var samples := PackedByteArray()
	var sample_count := int(SAMPLE_RATE * duration)
	for index in sample_count:
		var time := float(index) / SAMPLE_RATE
		var frequency := 240.0
		var wave := 0.0
		var envelope := 0.0
		if kind == "jump":
			envelope = (1.0 - exp(-220.0 * time)) * exp(-14.0 * time)
			var jump_phase := TAU * (270.0 * time + 190.0 * time * time)
			wave = sin(jump_phase) * 0.82 + sin(jump_phase * 2.0) * 0.18
		elif kind == "double_jump":
			envelope = (1.0 - exp(-150.0 * time)) * exp(-10.0 * time)
			var spin_phase := TAU * (390.0 * time + 330.0 * time * time)
			wave = sin(spin_phase) * 0.74 + sin(spin_phase * 2.0) * 0.26
		elif kind == "land":
			frequency = lerpf(115.0, 52.0, time / duration)
			envelope = exp(-34.0 * time)
			var noise := rng.randf_range(-1.0, 1.0)
			noise_state = lerpf(noise_state, noise, 0.18)
			wave = sin(TAU * frequency * time) * 0.68 + (noise - noise_state) * 0.32 * exp(-45.0 * time)
		elif kind == "ball_hit":
			frequency = lerpf(205.0, 92.0, time / duration)
			envelope = exp(-25.0 * time)
			var thump_phase := TAU * (frequency * time + 110.0 * time * time)
			var noise := rng.randf_range(-1.0, 1.0)
			noise_state = lerpf(noise_state, noise, 0.22)
			wave = sin(thump_phase) * 0.78 + (noise - noise_state) * 0.16 * exp(-65.0 * time)
		else:
			envelope = exp(-18.0 * time)
			var phase := TAU * 720.0 * time
			var second_phase := TAU * 960.0 * maxf(0.0, time - 0.07)
			wave = sin(phase) * 0.62 + (sin(second_phase) * 0.38 if time >= 0.07 else 0.0)
		var attack := 1.0 - exp(-180.0 * time)
		var amplitude := 6800.0 if kind in ["jump", "double_jump", "land"] else (9200.0 if kind == "ball_hit" else 8000.0)
		var sample := clampi(roundi(wave * envelope * attack * amplitude), -32768, 32767)
		samples.append(sample & 255)
		samples.append((sample >> 8) & 255)
	stream.data = samples
	return stream

func set_muted(value: bool) -> void:
	muted = value
	if muted:
		stop_all()
		if is_instance_valid(music_fade): music_fade.kill()
		music_fading = false
		if is_instance_valid(music_player): music_player.stop()
	else:
		play_music(requested_music)
	var config := ConfigFile.new()
	config.load("user://preferences.cfg")
	config.set_value("audio", "muted", value)
	config.save("user://preferences.cfg")

func stop_all() -> void:
	for voice in voices:
		voice.stop()
		voice.stream = null
	for voice in positional_voices:
		voice.stop()
		voice.queue_free()
	positional_voices.clear()
	for state in charge_tones.values():
		var player: AudioStreamPlayer2D = state["player"]
		player.stop()
		player.queue_free()
	charge_tones.clear()

func play_music(track: String) -> void:
	if track not in ["lobby", "match"]: return
	if requested_music == track and music_fading: return
	requested_music = track
	if muted or not is_instance_valid(music_player): return
	if current_music == track and music_player.playing: return
	if is_instance_valid(music_fade): music_fade.kill()
	if music_player.playing:
		music_fading = true
		music_fade = create_tween()
		music_fade.tween_property(music_player, "volume_db", -60.0, 0.24)
		music_fade.tween_callback(_start_requested_music)
	else:
		_start_requested_music()

func _start_requested_music() -> void:
	if muted or requested_music.is_empty() or not is_instance_valid(music_player): return
	current_music = requested_music
	music_player.stream = lobby_music_stream if current_music == "lobby" else match_music_stream
	music_player.volume_db = -60.0
	music_player.play()
	music_fading = true
	music_fade = create_tween()
	music_fade.tween_property(music_player, "volume_db", _music_target_db(), 0.7)
	music_fade.tween_callback(func(): music_fading = false)

func _music_target_db() -> float:
	# Music files have a much lower RMS level than the generated sound cues.
	# Let the user's volume setting control the music directly, with a safe ceiling.
	return linear_to_db(maxf(0.0001, minf(1.0, volume * 1.4)))

func update_charge_tone(source_id: int, progress: float, active: bool, source_position: Vector2) -> void:
	if not active or muted:
		if charge_tones.has(source_id): charge_tones[source_id]["stopping"] = true
		return
	if not charge_tones.has(source_id):
		var player := AudioStreamPlayer2D.new()
		player.stream = charge_tone_stream
		player.volume_db = -60.0
		player.max_distance = 2000.0
		player.attenuation = 1.0
		player.panning_strength = 1.0
		add_child(player)
		player.global_position = source_position
		player.play()
		charge_tones[source_id] = {"player": player, "progress": progress, "level": 0.0, "stopping": false}
	else:
		charge_tones[source_id]["progress"] = clampf(progress, 0.0, 1.0)
		charge_tones[source_id]["stopping"] = false
		var player: AudioStreamPlayer2D = charge_tones[source_id]["player"]
		player.global_position = source_position

func _process(delta: float) -> void:
	if is_instance_valid(music_player) and music_player.playing and not muted and not music_fading:
		music_player.volume_db = _music_target_db()
	for source_id in charge_tones.keys():
		var tone: Dictionary = charge_tones[source_id]
		var player: AudioStreamPlayer2D = tone["player"]
		if not is_instance_valid(player):
			charge_tones.erase(source_id)
			continue
		var progress := float(tone["progress"])
		var urgency := clampf((progress - 0.1) / 0.9, 0.0, 1.0)
		var stopping := bool(tone["stopping"])
		var target_level := 0.0 if stopping else lerpf(0.38, 0.68, urgency)
		var blend := 1.0 - exp(-12.0 * delta)
		var level := lerpf(float(tone["level"]), target_level, blend)
		tone["level"] = level
		if not stopping:
			player.pitch_scale = lerpf(player.pitch_scale, 0.88 + urgency * 1.35, 1.0 - exp(-7.0 * delta))
		player.volume_db = linear_to_db(maxf(0.0001, volume * level))
		if stopping and level < 0.002:
			player.stop()
			player.queue_free()
			charge_tones.erase(source_id)

func _exit_tree() -> void:
	stop_all()
	if is_instance_valid(music_player): music_player.stop()

func play_cue(kind: String, custom: AudioStream = null, gain: float = 1.0, pitch: float = 1.0) -> void:
	if muted or voices.is_empty(): return
	var stream := _get_cue_stream(kind, custom)
	if stream == null: return
	var voice := voices[next_voice]
	next_voice = (next_voice + 1) % voices.size()
	voice.stream = stream
	voice.volume_db = linear_to_db(maxf(0.001, volume * gain))
	voice.pitch_scale = pitch
	voice.play()

func play_positional_cue(kind: String, source_position: Vector2, custom: AudioStream = null, gain: float = 1.0, pitch: float = 1.0) -> void:
	if muted: return
	var stream := _get_cue_stream(kind, custom)
	if stream == null: return
	var voice := AudioStreamPlayer2D.new()
	voice.stream = stream
	voice.max_distance = 2000.0
	voice.attenuation = 1.0
	voice.panning_strength = 1.0
	voice.volume_db = linear_to_db(maxf(0.001, volume * gain))
	voice.pitch_scale = pitch
	add_child(voice)
	voice.global_position = source_position
	positional_voices.append(voice)
	voice.finished.connect(_on_positional_voice_finished.bind(voice))
	voice.play()

func _get_cue_stream(kind: String, custom: AudioStream = null) -> AudioStream:
	if custom != null: return custom
	match kind:
		"countdown": return COUNTDOWN
		"finish": return FINISH
		"whistle": return whistle_stream
		"perfect": return perfect_stream
		"jump": return jump_stream
		"double_jump": return double_jump_stream
		"land": return landing_stream
		"ball_hit": return ball_hit_stream
		"interact": return interact_stream
	return null

func _on_positional_voice_finished(voice: AudioStreamPlayer2D) -> void:
	positional_voices.erase(voice)
	if is_instance_valid(voice): voice.queue_free()


