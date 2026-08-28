extends RefCounted
# PathGenerator - deterministic seeded random walk on a 2D grid (x/z axes).
# Faithful to the original: LCG rand, no revisits, no U-turns, turn bias.

const DIRS := [
	Vector2i(0, -1),  # up (away from viewer)
	Vector2i(0, 1),   # down
	Vector2i(-1, 0),  # left
	Vector2i(1, 0),   # right
]

var _s: int = 1

func _init(p_seed: int = 1) -> void:
	_seed(p_seed)

# LCG matching the original: seed = (seed*1664525+1013904223) & 0xFFFFFFFF
# next float = (seed>>>0) / 0xFFFFFFFF
func _seed(v: int) -> void:
	_s = v

func _rand() -> float:
	_s = (_s * 1664525 + 1013904223) & 0xFFFFFFFF
	# >>> is not GDScript; emulate with unsigned 32-bit shift
	var u := _s & 0xFFFFFFFF
	return float(u) / 4294967295.0

func _randi(max_exclusive: int) -> int:
	return int(_rand() * max_exclusive)

func key(x: int, z: int) -> String:
	return "%d,%d" % [x, z]

func count_turns(path: Array) -> int:
	var turns := 0
	for i in range(2, path.size()):
		var d1: Vector2i = path[i] - path[i - 1]
		var d2: Vector2i = path[i - 1] - path[i - 2]
		if d1 != d2:
			turns += 1
	return turns

func generate(length: int, seed_value: int, turn_bias: float, min_turns: int, avoid: Array = [], start_pos := Vector2i.ZERO) -> Array:
	var last_path: Array = []
	for attempt in range(40):
		var bias := minf(turn_bias + attempt * 0.08, 0.9)
		var result := try_generate(length, seed_value + attempt * 7919, bias, avoid, start_pos)
		if result.is_empty():
			continue
		last_path = result
		if count_turns(result) >= min_turns:
			return result
	return last_path

func try_generate(length: int, seed_value: int, turn_bias: float, avoid: Array, start_pos := Vector2i.ZERO) -> Array:
	_seed(seed_value)
	var avoid_set := {}
	for a in avoid:
		avoid_set[str(a)] = true

	var path: Array = [start_pos]
	var visited := {}
	visited[key(start_pos.x, start_pos.y)] = true
	var last_dir := Vector2i.ZERO
	var has_dir := false

	for i in range(1, length):
		var cur: Vector2i = path[path.size() - 1]
		var candidates: Array = []
		for d in DIRS:
			if has_dir and d + last_dir == Vector2i.ZERO:
				continue  # no uturn
			var nx: Vector2i = cur + d
			var k := key(nx.x, nx.y)
			if visited.has(k):
				continue
			if avoid_set.has(k):
				continue
			candidates.append(d)
		if candidates.is_empty():
			return []  # dead end, retry
		var chosen: Vector2i = _choose(candidates, last_dir, has_dir, turn_bias)
		var nxt := cur + chosen
		path.append(nxt)
		visited[key(nxt.x, nxt.y)] = true
		last_dir = chosen
		has_dir = true
	return path

func _choose(candidates: Array, last_dir: Vector2i, has_dir: bool, turn_bias: float) -> Vector2i:
	var straight: Array = []
	var turning: Array = []
	for d in candidates:
		if has_dir and d == last_dir:
			straight.append(d)
		else:
			turning.append(d)
	if has_dir and not straight.is_empty():
		if _rand() < turn_bias and not turning.is_empty():
			return turning[_randi(turning.size())]
		return straight[_randi(straight.size())]
	return candidates[_randi(candidates.size())]
