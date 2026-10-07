extends RefCounted

static func earned_points(seconds: float, points_per_second: float, limit: float, charge_bonus := 0.0, natural_charge: float = -1.0) -> float:
	# Equal risk ratios earn the same points per second, regardless of lifespan.
	var progress := clampf(ratio(seconds if natural_charge < 0 else natural_charge, limit) + charge_bonus, 0.0, 1.0)
	return maxf(0.0, seconds) * points_per_second * (0.6 + 0.4 * progress * progress)

static func score(seconds: float, points_per_second: float, limit: float) -> int:
	return roundi(earned_points(seconds, points_per_second, limit))

static func ratio(seconds: float, burst_seconds: float) -> float:
	return clampf(seconds / burst_seconds, 0.0, 1.0)

static func warning_stage(progress: float, warm: float, danger: float, critical: float) -> int:
	if progress >= maxf(critical, maxf(danger, warm)): return 3
	if progress >= maxf(danger, warm): return 2
	if progress >= warm: return 1
	return 0
