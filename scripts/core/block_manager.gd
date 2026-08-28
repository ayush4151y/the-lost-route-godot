extends RefCounted
class_name BlockManager

var types := {}        # index -> block type string
var decoys := []        # Array of Vector2i
var slide_remaining = null
var slide_dir = ""
var slide_expired := false
var fire_remaining := Constants.FIRE_BUDGET
var standing_on_fire := false
var fuse_remaining = null
var fire_warn_accum := 0.0

func assign(path: Array, seed: int, level: int, start_index: int, opts: Dictionary = {}):
	types = {}
	decoys = []
	var tier = Constants.tier_for(level)
	var ice_pct = Constants.ramp(tier["ice"], level, tier)
	var fire_pct = Constants.ramp(tier["fire"], level, tier)
	var heart_pct = 0.0 if opts.get("noHearts", false) else Constants.ramp(tier["heart"], level, tier)
	var rseed = (seed * 2654435761) & 0xffffffff
	var rng = Constants.SeededRandom.new(rseed)

	for i in range(start_index, path.size()):
		if i == 0:
			types[0] = Constants.GRASS
			continue
		var r = rng.next()
		if heart_pct > 0 and r < heart_pct:
			types[i] = Constants.HEART
		elif fire_pct > 0 and r < heart_pct + fire_pct:
			types[i] = Constants.FIRE
		elif ice_pct > 0 and r < heart_pct + fire_pct + ice_pct:
			types[i] = Constants.ICE
		else:
			types[i] = Constants.GRASS

	var first_candidate = null
	for i in range(start_index + 1, path.size() - 1):
		var d1 = direction_of(path[i-1], path[i])
		var d2 = direction_of(path[i], path[i+1])
		if d1 == d2 or d1 == "":
			continue
		var v = Constants.DIR_VECTORS[d1]
		var pos = Vector2i(path[i].x + int(v.x), path[i].y + int(v.z))
		var overlaps_path = false
		for p in path:
			if p.x == pos.x and p.y == pos.y:
				overlaps_path = true
				break
		var overlaps_decoy = false
		for d in decoys:
			if d.x == pos.x and d.y == pos.y:
				overlaps_decoy = true
				break
		var is_tnt = rng.next() < tier["tnt"]
		if not overlaps_path and not overlaps_decoy:
			if first_candidate == null:
				first_candidate = pos
			if is_tnt:
				decoys.append(pos)
	if level > 20 and decoys.is_empty() and first_candidate != null:
		decoys.append(first_candidate)

func direction_of(from: Vector2i, to: Vector2i) -> String:
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

func type_of(index: int) -> String:
	if types.has(index):
		return types[index]
	return Constants.GRASS

func is_decoy(x: int, z: int) -> bool:
	for d in decoys:
		if d.x == x and d.y == z:
			return true
	return false

func is_slide_active() -> bool:
	return slide_remaining != null

func slide_progress() -> float:
	if slide_remaining == null:
		return 0.0
	return 1.0 - max(slide_remaining / Constants.ICE_SLIDE_TIME, 0.0)

func fire_active() -> bool:
	return standing_on_fire

func fuse_active() -> bool:
	return fuse_remaining != null

func fire_percent() -> float:
	return max(fire_remaining / Constants.FIRE_BUDGET, 0.0)

func on_entered(index: int, gm, from_pos: Vector2i):
	var type = type_of(index)
	if type == Constants.ICE:
		slide_remaining = Constants.ICE_SLIDE_TIME
		slide_dir = direction_of(from_pos, gm.path[index])
		gm.update_phase_text("SLIDING! Choose direction!")
		gm.play_sfx("ice-slide", 0.8)
	elif slide_remaining != null:
		slide_remaining = null
		gm.update_phase_text("Go!")
	if type == Constants.FIRE:
		standing_on_fire = true
		fire_warn_accum = 0.0
		gm.player.set_fire(true)
	elif standing_on_fire:
		standing_on_fire = false
		gm.player.set_fire(false)
	if type == Constants.HEART:
		gm.add_health(1)
		gm.update_phase_text("Heart! +1")

func cancel_slide():
	slide_remaining = null

func activate_tnt(gm):
	fuse_remaining = Constants.TNT_FUSE_TIME
	gm.on_tnt_activated()

func defuse_tnt(gm):
	fuse_remaining = null
	gm.on_tnt_defused()

func update(dt: float, gm):
	if slide_remaining != null:
		slide_remaining -= dt
		if slide_remaining <= 0:
			slide_remaining = null
			slide_expired = true
			gm.game_over()
			return
	if standing_on_fire:
		fire_remaining -= dt
		if fire_remaining <= 0:
			fire_remaining = Constants.FIRE_BUDGET
			gm.on_fire_burned()
			return
		fire_warn_accum += dt
		if fire_warn_accum >= 0.22:
			fire_warn_accum = 0.0
			gm.play_sfx("fire-warn", 0.6)
		gm.update_phase_text("FIRE! " + str(max(fire_remaining, 0.0)).pad_decimals(1) + "s")
	if fuse_remaining != null:
		fuse_remaining -= dt
		if fuse_remaining <= 0:
			fuse_remaining = null
			gm.on_tnt_exploded()

func reset():
	types = {}
	decoys = []
	slide_remaining = null
	slide_dir = ""
	slide_expired = false
	fire_remaining = Constants.FIRE_BUDGET
	standing_on_fire = false
	fire_warn_accum = 0.0
	fuse_remaining = null
