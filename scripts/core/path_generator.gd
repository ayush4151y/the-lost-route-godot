extends RefCounted
class_name PathGenerator

const DIRS = [
	{"x": 0, "z": -1, "name": "up"},
	{"x": 0, "z": 1, "name": "down"},
	{"x": -1, "z": 0, "name": "left"},
	{"x": 1, "z": 0, "name": "right"},
]

func generate(length: int, seed: int, turn_bias: float, min_turns: int, avoid = null, start_pos: Vector2i = Vector2i.ZERO, pull: Vector2i = Vector2i.ZERO) -> Array:
	var last = null
	for attempt in range(40):
		var bias = min(turn_bias + attempt * 0.08, 0.9)
		var result = try_generate(length, seed + attempt * 7919, bias, avoid, start_pos, pull)
		if result != null and count_turns(result) >= min_turns:
			return result
		if result != null:
			last = result
	return last

func count_turns(path: Array) -> int:
	var turns = 0
	for i in range(2, path.size()):
		var d1 = path[i] - path[i-1]
		var d2 = path[i-1] - path[i-2]
		if d1 != d2:
			turns += 1
	return turns

func try_generate(length: int, seed: int, turn_bias: float, avoid, start_pos: Vector2i, pull: Vector2i) -> Array:
	var rng = Constants.SeededRandom.new(seed)
	var path: Array = []
	var visited = {}
	var sp = start_pos
	if avoid != null:
		for k in avoid:
			visited[k] = true
	path.append(sp)
	visited[_k(sp.x, sp.y)] = true
	var last_dir = null

	for i in range(length):
		var current = path[path.size() - 1]
		var available = []
		for d in DIRS:
			if last_dir != null and d.x == -last_dir.x and d.z == -last_dir.z:
				continue
			var nx = current.x + d.x
			var nz = current.y + d.z
			if visited.has(_k(nx, nz)):
				continue
			available.append(d)
		if available.is_empty():
			return []

		var chosen = null
		if last_dir != null and turn_bias > 0 and available.size() > 1:
			var straight = null
			var turns = []
			for d in available:
				if d.x == last_dir.x and d.z == last_dir.z:
					straight = d
				else:
					turns.append(d)
			if turns.size() > 0 and rng.next() < turn_bias:
				chosen = weighted(turns, path, pull, rng)
			elif straight != null:
				chosen = straight
		if chosen == null:
			chosen = weighted(available, path, pull, rng)
		last_dir = chosen

		var nxt = Vector2i(current.x + chosen.x, current.y + chosen.z)
		path.append(nxt)
		visited[_k(nxt.x, nxt.y)] = true
	return path

func _k(x: int, z: int) -> String:
	return str(x) + "," + str(z)

func weighted(candidates: Array, path: Array, pull: Vector2i, rng: Constants.SeededRandom):
	if pull != Vector2i.ZERO and candidates.size() > 1:
		var best = candidates[0]
		var best_d = -INF
		for c in candidates:
			var nx = path[path.size() - 1].x + c.x
			var nz = path[path.size() - 1].y + c.z
			var d = (nx - pull.x) * (nx - pull.x) + (nz - pull.y) * (nz - pull.y)
			if d > best_d:
				best_d = d
				best = c
		return best
	return candidates[int(rng.next() * candidates.size())]

func get_direction(from: Vector2i, to: Vector2i) -> String:
	var dx = to.x - from.x
	var dz = to.y - from.y
	if dx == 1 and dz == 0:
		return "right"
	if dx == -1 and dz == 0:
		return "left"
	if dx == 0 and dz == -1:
		return "up"
	if dx == 0 and dz == 1:
		return "down"
	return ""
