class_name BalancedBubblePool
extends RefCounted

var rng := RandomNumberGenerator.new()
var bags: Dictionary = {}
var queues: Dictionary = {}
var turns: Dictionary = {}
var minimum := 1.5
var maximum := 4.0

func _init(low: float, high: float) -> void:
	minimum = minf(low, high)
	maximum = maxf(low, high)
	rng.randomize()

func next_duration(peer_id: int) -> float:
	var turn := int(turns.get(peer_id, 0))
	var bag_index := floori(turn / 6.0)
	if not bags.has(bag_index): bags[bag_index] = _make_bag()
	if turn % 6 == 0:
		# Each player gets the same three complementary pairs in a different order.
		var order: Array = [0, 1, 2]
		for index in range(2, 0, -1):
			var swap := rng.randi_range(0, index)
			var temporary: int = order[index]
			order[index] = order[swap]
			order[swap] = temporary
		var queue: Array[float] = []
		for pair_index in order:
			var pair: Array = bags[bag_index][pair_index]
			var flipped := rng.randi_range(0, 1)
			queue.append(float(pair[flipped]))
			queue.append(float(pair[1 - flipped]))
		queues[peer_id] = queue
	turns[peer_id] = turn + 1
	return float(queues[peer_id][turn % 6])

func _make_bag() -> Array:
	var mean := (minimum + maximum) * 0.5
	var width := maximum - minimum
	var short_a := rng.randf_range(minimum, minimum + width * 0.25)
	var short_b := rng.randf_range(minimum, minimum + width * 0.25)
	var middle := rng.randf_range(mean - width * 0.125, mean + width * 0.125)
	return [[short_a, 2.0 * mean - short_a], [short_b, 2.0 * mean - short_b], [middle, 2.0 * mean - middle]]
