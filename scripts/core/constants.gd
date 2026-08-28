extends RefCounted
class_name Constants

# Block type identifiers (match the web game's BLOCK_TYPES)
const GRASS = "grass"
const ICE = "ice"
const FIRE = "fire"
const TNT = "tnt"
const HEART = "heart"
const START = "start"
const END = "end"

# Direction vectors (grid space: x right, z "down"/+z; up = -z)
const DIR_VECTORS = {
	"up": Vector3i(0, 0, -1),
	"down": Vector3i(0, 0, 1),
	"left": Vector3i(-1, 0, 0),
	"right": Vector3i(1, 0, 0),
}

# Timing constants (seconds)
const ICE_SLIDE_TIME = 2.0
const FIRE_BUDGET = 3.0
const TNT_FUSE_TIME = 3.0

const TOTAL_LEVELS = 200
const GRID_SIZE = 15

# Difficulty tiers (level ranges + spawn chances)
const LEVEL_TIERS = [
	{"start": 1, "end": 20, "ice": 0.0, "fire": 0.0, "tnt": 0.0, "heart": 0.0},
	{"start": 21, "end": 50, "ice": [0.12, 0.20], "fire": 0.0, "tnt": 0.5, "heart": 0.0},
	{"start": 51, "end": 100, "ice": [0.20, 0.30], "fire": [0.10, 0.25], "tnt": 0.4, "heart": 0.0},
	{"start": 101, "end": 200, "ice": [0.30, 0.40], "fire": [0.25, 0.40], "tnt": 0.35, "heart": 0.08},
]

# Linear congruential generator matching the web game's SeededRandom
class SeededRandom:
	var seed: int
	func _init(s: int):
		seed = s & 0xffffffff
	func next() -> float:
		seed = (seed * 1664525 + 1013904223) & 0xffffffff
		return float(seed) / 4294967296

static func mulberry32(seed: int) -> Callable:
	var t = seed & 0xffffffff
	var next = func() -> float:
		t = (t + 0x6D2B79F5) | 0
		var r = (t ^ (t >> 15)) * (1 | t)
		r = (r + ((r ^ (r >> 7)) * (61 | r))) ^ r
		return float((r ^ (r >> 14)) & 0xffffffff) / 4294967296.0
	return next

static func hash2(x: int, z: int) -> int:
	var h = (int(x) * 73856093) ^ (int(z) * 19349663)
	h = h & 0xffffffff
	h = (h ^ (h >> 13)) * 0x7feb352d
	h = h & 0xffffffff
	return h & 0xffffffff

# Resolve a tier chance: null -> 0, number -> that, [lo,hi] -> ramped by level
static func ramp(chance, level: int, tier: Dictionary) -> float:
	if chance == null:
		return 0.0
	if typeof(chance) == TYPE_FLOAT or typeof(chance) == TYPE_INT:
		return float(chance)
	var t = clamp(float(level - tier["start"]) / float(tier["end"] - tier["start"]), 0.0, 1.0)
	return float(chance[0]) + (float(chance[1]) - float(chance[0])) * t

static func tier_for(level: int) -> Dictionary:
	for t in LEVEL_TIERS:
		if level <= t["end"]:
			return t
	return LEVEL_TIERS[LEVEL_TIERS.size() - 1]
