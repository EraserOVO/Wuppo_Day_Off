extends RefCounted

var samples: Array = []
var delay := 0.1

func clear() -> void:
	samples.clear()

func push(time: float, position: Vector2) -> void:
	if not samples.is_empty() and time <= float(samples.back()[0]): return
	samples.append([time, position])
	while samples.size() > 32: samples.pop_front()

func position_at(server_time: float) -> Vector2:
	if samples.is_empty(): return Vector2.ZERO
	var target := server_time - delay
	while samples.size() > 2 and float(samples[1][0]) <= target: samples.pop_front()
	if samples.size() == 1 or target <= float(samples[0][0]): return samples[0][1]
	if target >= float(samples.back()[0]): return samples.back()[1]
	var weight := inverse_lerp(float(samples[0][0]), float(samples[1][0]), target)
	return (samples[0][1] as Vector2).lerp(samples[1][1], clampf(weight, 0.0, 1.0))
