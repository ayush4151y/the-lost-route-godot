extends Node
# BlockManager - assigns block types along the path per difficulty tier,
# places decoy TNT barrels at path corners, and tracks cube nodes.
# Faithful to the original LEVEL_TIERS distribution and decoy placement.

signal block_revealed(cell: Vector2i, kind: String)
signal decoy_activated(cell: Vector2i)

const CubeFactory = preload("res://scripts/world/cube_factory.gd")

# difficulty tiers: [min_level, max_level, ice_pct, fire_pct, tnt_pct, heart_pct]
# pct values are the top of the ramp; bottom is interpolated from previous tier
const TIERS := [
	[1, 20, 0.0, 0.0, 0.0, 0.0],
	[21, 50, 0.20, 0.0, 0.5, 0.0],
	[51, 100, 0.30, 0.25, 0.4, 0.0],
	[101, 200, 0.40, 0.40, 0.35, 0.08],
]
const TIER_BASES := {
	"ice": 0.12, "fire": 0.10, "heart": 0.0, "tnt": 0.5,
}

var blocks := {}   # String key "x,z" -> {kind, node, revealed, cell}
var decoys := {}   # key -> {node, active, fuse}

var no_hearts := false

func clear() -> void:
	blocks.clear()
	decoys.clear()

# Get interpolated probabilities for a given level (campaign-level 1..200)
func tier_for_level(level: int) -> Dictionary:
	var ice := 0.0
	var fire := 0.0
	var tnt := 0.0
	var heart := 0.0
	for t in TIERS:
		var lo: int = t[0]
		var hi: int = t[1]
		if level >= lo and level <= hi:
			var span := maxi(hi - lo, 1)
			var progress := float(level - lo) / span
			ice = lerpf(TIER_BASES["ice"], t[2], progress)
			fire = lerpf(TIER_BASES["fire"], t[3], progress)
			tnt = lerpf(TIER_BASES["tnt"] if level > 20 else 0.0, t[4], progress)
			heart = t[5]
			break
	if no_hearts:
		heart = 0.0
	return {"ice": ice, "fire": fire, "tnt": tnt, "heart": heart}


# Assign kinds to a path (array of Vector2i). Returns array parallel to path
# of kind strings. Cell 0 always grass/start. Uses its own rng seeded.
func assign_kinds(path: Array, level: int, seed_value: int) -> Array:
	var kinds := []
	kinds.resize(path.size())
	var tier := tier_for_level(level)
	var s := seed_value
	var r := func():
		s = (s * 1664525 + 1013904223) & 0xFFFFFFFF
		return float(s & 0xFFFFFFFF) / 4294967295.0
	for i in path.size():
		if i == 0:
			kinds[i] = CubeFactory.GRASS
			continue
		var roll: float = r.call()
		var p := 0.0
		var kind := CubeFactory.GRASS
		if roll < tier.heart:
			kind = CubeFactory.HEART
		elif roll < tier.heart + tier.fire:
			kind = CubeFactory.FIRE
		elif roll < tier.heart + tier.fire + tier.ice:
			kind = CubeFactory.ICE
		kinds[i] = kind
	return kinds


func _dir_of(a: Vector2i, b: Vector2i) -> Vector2i:
	return b - a

# Find corner cells along the path -> list of shoulder cell positions (Vector2i)
func corner_cells(path: Array) -> Array:
	var cells := []
	for i in range(1, path.size() - 1):
		var prev: Vector2i = path[i - 1]
		var cur: Vector2i = path[i]
		var nxt: Vector2i = path[i + 1]
		var in_dir := _dir_of(prev, cur)
		var out_dir := _dir_of(cur, nxt)
		if in_dir != out_dir:
			var shoulder := cur + in_dir
			cells.append(shoulder)
	return cells


# Place decoys at corner shoulders with given probability tier.
# Returns positions placed.
func place_decoys(path: Array, tier: Dictionary, seed_value: int) -> Array:
	if not path or path.size() < 3:
		return []
	var path_set := {}
	for p in path:
		path_set["%d,%d" % [p.x, p.y]] = true
	var candidates := corner_cells(path)
	var placed := []
	var s := seed_value
	var r := func():
		s = (s * 1664525 + 1013904223) & 0xFFFFFFFF
		return float(s & 0xFFFFFFFF) / 4294967295.0
	for c in candidates:
		var k := "%d,%d" % [c.x, c.y]
		if path_set.has(k) or decoys.has(k):
			continue
		if r.call() < tier.tnt:
			placed.append(c)
			decoys[k] = {"pos": c, "active": false, "fuse": 0.0}
	# guarantee at least one decoy for level > 20 if none placed
	var any_decoy := not decoys.is_empty()
	if not any_decoy and tier.tnt > 0.0 and not candidates.is_empty():
		var c: Vector2i = candidates[0]
		var k := "%d,%d" % [c.x, c.y]
		if not path_set.has(k):
			decoys[k] = {"pos": c, "active": false, "fuse": 0.0}
			placed.append(c)
	return placed
