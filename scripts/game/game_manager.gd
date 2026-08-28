extends Node3D
# GameManager - central orchestrator. Owns 3D world, player, blocks, camera,
# island, environment and the UI. Implements the game state machine
# (menu / playing / paused / win / game over) and mode handling
# (campaign / endless / daily).

signal state_changed(new_state: String)

const TOTAL_LEVELS := 200

const PathGenerator = preload("res://scripts/world/path_generator.gd")
const CubeFactory = preload("res://scripts/world/cube_factory.gd")
const BlockManager = preload("res://scripts/world/block_manager.gd")
const CameraRig = preload("res://scripts/world/camera_rig.gd")
const GameEnv = preload("res://scripts/world/game_env.gd")
const IslandBuilder = preload("res://scripts/world/island_builder.gd")
const Player = preload("res://scripts/entities/player.gd")
const UI = preload("res://scripts/ui/ui.gd")

enum State { MENU, PLAYING, PAUSED, WIN, GAMEOVER, LEVELSELECT, SETTINGS }

var state := State.MENU
var mode := SaveData.MODE_CAMPAIGN

# world references
var block_mgr: BlockManager
var camera: CameraRig
var player: Player
var game_env: GameEnv
var island: IslandBuilder
var ui: UI

var current_level := 1
var path: Array = []          # Array[Vector2i]
var kinds: Array = []         # parallel kinds
var path_index := 0
var cell_kind := {}           # "x,y" -> kind (including start/end/decoys)
var is_dead := false
var hint_pending := false
var idle_time := 0.0

# endless
var endless_streak := 0
var endless_best := 0
var run_seed := 0

# daily
var daily_done := false

func _ready() -> void:
	game_env = GameEnv.new()
	add_child(game_env)

	camera = CameraRig.new()
	add_child(camera)

	island = IslandBuilder.new()
	add_child(island)

	block_mgr = BlockManager.new()
	add_child(block_mgr)

	ui = UI.new()
	add_child(ui)

	_build_world_lights()
	_setup_ui_handlers()
	show_menu()

func _build_world_lights() -> void:
	var dir := DirectionalLight3D.new()
	dir.rotation_degrees = Vector3(-55, -35, 0)
	dir.light_energy = 1.0
	dir.shadow_enabled = true
	add_child(dir)
	var amb := DirectionalLight3D.new()
	amb.rotation_degrees = Vector3(-20, 160, 0)
	amb.light_energy = 0.35
	amb.light_color = Color(0.7, 0.85, 1.0)
	add_child(amb)

# ---------------- UI wiring ----------------
func _setup_ui_handlers() -> void:
	ui.init_hud(
		func(): _on_hint(),
		func(): _on_pause(),
		func(): _on_skip(),
		func(): _rotate_view(),
	)

func show_menu() -> void:
	_set_state(State.MENU)
	ui.show_menu(func(action): _on_menu_action(action))
	ui.hide_hud()

func _on_menu_action(action: String) -> void:
	AudioManager.play("ui_click")
	match action:
		"start":
			mode = SaveData.MODE_CAMPAIGN
			current_level = maxi(SaveData.get_int("rak_level", 1), 1)
			_show_level_select()
		"endless":
			mode = SaveData.MODE_ENDLESS
			start_endless()
		"daily":
			var dk := SaveData.today_key()
			var last := SaveData.get_int("rak_daily_last", 0)
			if last == dk:
				daily_done = true
				_on_win("DAILY COMPLETE!", "Come back tomorrow", "MENU", true)
			else:
				daily_done = false
				start_daily()
		"settings":
			_set_state(State.SETTINGS)
			ui.show_settings(func(a): _on_settings_action(a))

func _show_level_select() -> void:
	_set_state(State.LEVELSELECT)
	ui.show_level_select(
		current_level,
		SaveData.get_levels("completed"),
		SaveData.get_levels("skipped"),
		func(level): _on_level_selected(level),
	)

func _on_level_selected(level) -> void:
	if level is int:
		AudioManager.play("ui_click")
		current_level = level
		start_level(current_level)

func _on_settings_action(action: String) -> void:
	AudioManager.play("ui_click")
	match action:
		"sound":
			AudioManager.set_muted(not AudioManager.muted)
			show_menu()
		"reset":
			SaveData.reset_progress()
			current_level = 1
			show_menu()
		"back":
			show_menu()

func _rotate_view() -> void:
	if camera:
		camera.rotate_view(90)

# ---------------- level loading ----------------
func start_level(level: int) -> void:
	is_dead = false
	path_index = 0
	path = []
	kinds = []
	cell_kind = {}
	_clear_world_nodes()

	var len_band := _path_length(level)
	var seed := level * 9973 + 42
	var turn_bias := 0.4 + float(level - 1) / 199.0 * 0.4
	var min_turns := maxi(1, int(len_band / 3.0))
	var pg := PathGenerator.new(seed)
	path = pg.generate(len_band, seed, turn_bias, min_turns)
	if path.is_empty():
		path = _fallback_path(len_band)
	_center_path()

	kinds = block_mgr.assign_kinds(path, level, seed + 7)
	_build_world(level, seed)

	_set_state(State.PLAYING)
	ui.show_hud()
	ui.set_level(level)
	ui.set_hearts(player.health)

func _path_length(level: int) -> int:
	if level <= 20:
		return 5 + (level - 1) % 8
	elif level <= 50:
		return 8 + (level - 21) % 6
	elif level <= 100:
		return 9 + (level - 51) % 10
	elif level <= 150:
		return 15 + (level - 101) % 8
	return 19 + (level - 151) % 7

func _fallback_path(len_band: int) -> Array:
	var p := []
	for i in len_band:
		p.append(Vector2i(i, 0))
	return p

func _center_path() -> void:
	var min_x := 0
	var max_x := 0
	var min_z := 0
	var max_z := 0
	for c: Vector2i in path:
		min_x = mini(min_x, c.x); max_x = maxi(max_x, c.x)
		min_z = mini(min_z, c.y); max_z = maxi(max_z, c.y)
	var ox := -(min_x + max_x) / 2
	var oz := -(min_z + max_z) / 2
	for i in path.size():
		path[i] = path[i] + Vector2i(ox, oz)

func _build_world(level: int, seed: int) -> void:
	# spawn path cubes
	for i in path.size():
		var c: Vector2i = path[i]
		var kind: String = kinds[i] if i > 0 else CubeFactory.START
		if i == path.size() - 1:
			kind = CubeFactory.END
		_spawn_block(c, kind)
		cell_kind["%d,%d" % [c.x, c.y]] = kind
	# decoys
	var tier := block_mgr.tier_for_level(level)
	var decoys := block_mgr.place_decoys(path, tier, seed + 13)
	for d: Vector2i in decoys:
		var k := "%d,%d" % [d.x, d.y]
		_spawn_block(d, CubeFactory.DECOY, true)
		cell_kind[k] = CubeFactory.DECOY
	# island anchors
	var start_anchor: Vector2i = path[0] - _entry_dir()
	var end_anchor: Vector2i = path[path.size() - 1] + _entry_dir()
	island.build(self, start_anchor, end_anchor)
	# player
	player = Player.new()
	add_child(player)
	player.setup(self, path[0])
	# camera
	var cells := path.duplicate()
	for d: Vector2i in decoys:
		cells.append(d)
	camera.frame_path(cells)

func _entry_dir() -> Vector2i:
	if path.size() >= 2:
		return path[1] - path[0]
	return Vector2i(1, 0)

func _spawn_block(c: Vector2i, kind: String, is_decoy := false) -> void:
	var node: Node3D = CubeFactory.new().build_block(kind) if not is_decoy else CubeFactory.new().build_tnt_barrel()
	node.position = Vector3(c.x, 0, c.y)
	node.set_meta("cell", c)
	node.set_meta("kind", kind)
	add_child(node)
	_animate_rise(node, 0.25 + float(block_mgr.blocks.size()) * 0.03)

func _animate_rise(node: Node3D, delay: float) -> void:
	var start_y := -0.4
	node.position.y = start_y
	var tween := node.create_tween()
	tween.tween_interval(delay)
	tween.tween_property(node, "position:y", 0.0, 0.25)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# ---------------- input / movement ----------------
func _unhandled_input(event: InputEvent) -> void:
	if state != State.PLAYING or is_dead:
		return
	if player and player.is_moving:
		return
	var dir := Vector2i.ZERO
	if event.is_action_pressed("ui_up"):
		dir = Vector2i(0, -1)
	elif event.is_action_pressed("ui_down"):
		dir = Vector2i(0, 1)
	elif event.is_action_pressed("ui_left"):
		dir = Vector2i(-1, 0)
	elif event.is_action_pressed("ui_right"):
		dir = Vector2i(1, 0)
	elif event.is_action_pressed("ui_accept"):
		if hint_pending:
			_do_hint()
		return
	if dir != Vector2i.ZERO:
		_attempt_move(dir)
	elif event is InputEventScreenTouch and event.pressed:
		var target := _screen_dir(event.position)
		if target != Vector2i.ZERO:
			_attempt_move(target)

func _screen_dir(pos: Vector2) -> Vector2i:
	var vp := get_viewport()
	var size := vp.get_visible_rect().size
	var rel := pos - size / 2.0
	if abs(rel.x) > abs(rel.y):
		return Vector2i(sign(rel.x), 0)
	return Vector2i(0, sign(rel.y))

func _cell_key(c: Vector2i) -> String:
	return "%d,%d" % [c.x, c.y]

func _attempt_move(dir: Vector2i) -> void:
	var cur: Vector2i = player.get_holding_cell()
	var nxt := cur + dir
	var nk := _cell_key(nxt)

	# check decoy activation even when moving onto a shoulder
	if cell_kind.get(nk) == CubeFactory.DECOY:
		_enter_decoy(nxt)
		return

	# path movement
	if _is_next_path_cell(nxt):
		_hazard_cleanup()
		_do_hop_to(nxt)
	else:
		# wrong direction (off path, not a decoy we accepted) -> game over
		_on_game_over("Wrong direction!")

func _is_next_path_cell(c: Vector2i) -> bool:
	var next_idx := path_index + 1
	if next_idx < path.size() and path[next_idx] == c:
		return true
	# allow hopping backwards onto previous step
	if path_index - 1 >= 0 and path[path_index - 1] == c:
		return true
	return false

func _do_hop_to(c: Vector2i) -> void:
	path_index = _index_of(c)
	idle_time = 0.0
	ui.set_hint_glow(false)
	if player and not player.is_connected("hop_finished", _on_hop_landed):
		player.hop_to(c)
		player.hop_finished.connect(_on_hop_landed, CONNECT_ONE_SHOT)
	AudioManager.play("hop")

func _index_of(c: Vector2i) -> int:
	for i in path.size():
		if path[i] == c:
			return i
	return path_index

func _on_hop_landed() -> void:
	if is_dead:
		return
	var c: Vector2i = player.get_holding_cell()
	if c == path[path.size() - 1]:
		_on_win_level()
		return
	var kind: String = cell_kind.get(_cell_key(c), CubeFactory.GRASS)
	match kind:
		CubeFactory.ICE:
			_apply_ice(c)
		CubeFactory.FIRE:
			_apply_fire()
		CubeFactory.HEART:
			if player:
				player.gain_health()
				ui.set_hearts(player.health)
			AudioManager.play("heart_pickup")
			ui.set_phase("Heart! +1")
		CubeFactory.GRASS, CubeFactory.START:
			ui.set_phase("")
	_midpoint_bonus()

func _hazard_cleanup() -> void:
	if player:
		player.set_slide(false, Vector2i.ZERO)
		player.reset_burn_on_move()

func _apply_ice(c: Vector2i) -> void:
	if player:
		var entry: Vector2i = path[path_index] - path[path_index - 1]
		player.set_slide(true, entry)
	AudioManager.play("ice_slide")
	ui.set_phase("SLIDING! Choose direction!", true)

func _apply_fire() -> void:
	if player:
		player.set_fire(true)
	AudioManager.play("fire_warn")
	ui.set_phase("FIRE!")

func _vc(d: Vector3) -> Vector2i:
	return Vector2i(roundi(d.x), roundi(d.z))

func _midpoint_bonus() -> void:
	if mode == SaveData.MODE_ENDLESS:
		return
	var mid := int(path.size() / 2.0)
	if path_index >= mid and not _mid_bonus_given and mid > 1:
		_mid_bonus_given = true
		if player:
			player.gain_health()
			ui.set_hearts(player.health)
		ui.set_phase("Midway! +1 Heart")
		AudioManager.play("heart_pickup")

var _mid_bonus_given := false

# ---------------- decoys ----------------
func _enter_decoy(c: Vector2i) -> void:
	# land on decoy cell -> fuse timer starts, must move back
	if player:
		player.hop_to(c)
	player.set_meta("on_decoy_key", _cell_key(c))
	player.set_meta("decoy_fuse", 3.0)
	AudioManager.play("tnt_fuse")
	ui.set_phase("TNT! Go back!")

func _process(delta: float) -> void:
	if state == State.PLAYING and player and not is_dead:
		player.update_fire_slide(delta)
		ui.set_fire(clampf(player.fire_budget / player.FIRE_BUDGET, 0, 1))
		# check fire/ice death
		if player.dead:
			_on_game_over("Burned alive!")
			return
		if player.sliding and player.slide_timer <= 0.0:
			_on_game_over("Fell on the ice!")
			return
		# decoy fuse
		if player.has_meta("decoy_fuse"):
			var fuse: float = player.get_meta("decoy_fuse") - delta
			player.set_meta("decoy_fuse", fuse)
			if fuse <= 0.0:
				_boom_at(player.position)
				_on_game_over("TNT exploded!")
			return
		# idle hint glow
		idle_time += delta
		ui.set_hint_glow(idle_time > 3.0)

# ---------------- hint ----------------
func _on_hint() -> void:
	_do_hint()

func _do_hint() -> void:
	if state != State.PLAYING or is_dead or not player:
		return
	var next_idx := path_index + 1
	if next_idx >= path.size():
		return
	AudioManager.play("hint")
	is_dead = true
	ui.show_win("LEVEL COMPLETE!", "", "NEXT LEVEL", func(a): _on_win_action(a))
	_on_win_level(true)

func _on_skip() -> void:
	if mode == SaveData.MODE_CAMPAIGN:
		SaveData.add_level("skipped", current_level)
		current_level += 1
		SaveData.set_key("rak_level", current_level)
		start_level(current_level)

# ---------------- pause ----------------
func _on_pause() -> void:
	AudioManager.play("ui_pause")
	if state == State.PLAYING:
		_set_state(State.PAUSED)
		ui.show_pause(func(a): _on_pause_action(a))
	get_tree().paused = true

func _on_pause_action(action: String) -> void:
	get_tree().paused = false
	if action == "home":
		show_menu()
	else:
		_set_state(State.PLAYING)

# ---------------- win ----------------
func _on_win_level(hint_win := false) -> void:
	if is_dead and not hint_win:
		return
	AudioManager.play("win")
	match mode:
		SaveData.MODE_CAMPAIGN:
			SaveData.add_level("completed", current_level)
			SaveData.set_key("rak_level", current_level + 1)
			if hint_win:
				return
			_set_state(State.WIN)
			ui.show_win("LEVEL COMPLETE!", "", "NEXT LEVEL", func(a): _on_win_action(a))
		SaveData.MODE_ENDLESS:
			endless_streak += 1
			endless_best = maxi(endless_best, endless_streak)
			SaveData.set_key("rak_best_endless", endless_best)
			_continue_endless()
		SaveData.MODE_DAILY:
			if SaveData.get_int("rak_daily_last", 0) != SaveData.today_key():
				var last := SaveData.get_int("rak_daily_streak", 0)
				var streak := 1
				if last == 0 or SaveData.get_int("rak_daily_last", 0) == SaveData.today_key() - 1:
					streak = SaveData.get_int("rak_daily_streak", 0) + 1
				SaveData.set_key("rak_daily_streak", streak)
				SaveData.set_key("rak_daily_last", SaveData.today_key())
			ui.show_win("DAILY COMPLETE!", "Streak: %d days" % SaveData.get_daily_streak(), "MENU", func(a): show_menu())

func _on_win_action(action: String) -> void:
	if action == "next":
		current_level += 1
		SaveData.set_key("rak_level", current_level)
		start_level(current_level)

func _on_win(title: String, sub: String, btn: String, already: bool) -> void:
	_set_state(State.WIN)
	ui.show_win(title, sub, btn, func(_a): show_menu())

# ---------------- game over ----------------
func _on_game_over(line: String) -> void:
	if is_dead:
		return
	is_dead = true
	AudioManager.play("gameover")
	var final_line := line
	if mode == SaveData.MODE_CAMPAIGN:
		final_line = "Level %d — %s" % [current_level, line]
	elif mode == SaveData.MODE_ENDLESS:
		final_line = "Islands: %d (Best: %d)" % [endless_streak, endless_best]
	_set_state(State.GAMEOVER)
	ui.set_phase("")
	ui.show_game_over(final_line, func(_a): _on_retry())

func _on_retry() -> void:
	match mode:
		SaveData.MODE_CAMPAIGN:
			start_level(current_level)
		SaveData.MODE_ENDLESS:
			start_endless()
		SaveData.MODE_DAILY:
			start_daily()

# ---------------- modes ----------------
func start_endless() -> void:
	endless_streak = 0
	endless_best = SaveData.get_int("rak_best_endless", 0)
	run_seed = int(Time.get_ticks_msec()) & 0x7fffffff
	_endless_path = []
	_start_next_endless_segment()

var _endless_path: Array = []

func _start_next_endless_segment() -> void:
	var level := mini(endless_streak * 5 + 1, 200)
	var seg_len := 8 + endless_streak * 3
	seg_len = clampi(seg_len, 8, 25)
	var seed := run_seed + endless_streak * 7919
	var pg := PathGenerator.new(seed)
	var seg := pg.generate(seg_len, seed, minf(0.4 + endless_streak * 0.05, 0.8), 1, [], Vector2i.ZERO)
	if seg.is_empty():
		seg = _fallback_path(seg_len)
	# combine: if we have a previous end, chain
	if _endless_path.is_empty():
		_endless_path = seg
	else:
		var last: Vector2i = _endless_path[_endless_path.size() - 1]
		var base: Vector2i = seg[0]
		var offset := last - base
		var shifted := []
		for c: Vector2i in seg:
			shifted.append(c + offset)
		for i in range(1, shifted.size()):
			_endless_path.append(shifted[i])
	_setup_endless_play(level)

func _setup_endless_play(level: int) -> void:
	is_dead = false
	path_index = 0
	path = _endless_path.duplicate()
	kinds = []
	cell_kind = {}
	_clear_world_nodes()
	# show only the last segment's cubes (the new one)
	var show_from := maxi(_endless_path.size() - 25, 0)
	var seed := run_seed + endless_streak * 7919
	var full_kinds := block_mgr.assign_kinds(path, level, seed + 7)
	kinds = full_kinds
	mode = SaveData.MODE_ENDLESS
	_build_endless_world(level, seed)
	_set_state(State.PLAYING)
	ui.show_hud()
	ui.set_level(endless_streak + 1)
	ui.set_hearts(player.health)

func _build_endless_world(level: int, seed: int) -> void:
	for i in path.size():
		var c: Vector2i = path[i]
		var kind: String = kinds[i] if i > 0 else CubeFactory.START
		if i == path.size() - 1:
			kind = CubeFactory.END
		_spawn_block(c, kind)
		cell_kind["%d,%d" % [c.x, c.y]] = kind
	# player starts at path[0]
	player = Player.new()
	add_child(player)
	player.setup(self, path[0])
	camera.frame_path(path)

func _continue_endless() -> void:
	# sink old cubes of previous segment (simplified: just build next)
	_endless_streak_for_display = endless_streak
	_start_next_endless_segment()

var _endless_streak_for_display := 0

func start_daily() -> void:
	daily_done = false
	is_dead = false
	var dk := SaveData.today_key()
	var seed := dk * 7919 + 7
	path = PathGenerator.new(seed).generate(25, seed, 0.8, 8, [], Vector2i.ZERO)
	if path.is_empty():
		path = _fallback_path(25)
	_center_path()
	kinds = block_mgr.assign_kinds(path, 200, seed + 7)
	cell_kind = {}
	_clear_world_nodes()
	_build_world(200, seed)
	ui.set_level(0)
	ui.set_hearts(player.health)
	_set_state(State.PLAYING)
	ui.show_hud()
	ui.set_phase("Daily Challenge!")

func _clear_world_nodes() -> void:
	if player:
		player.queue_free()
		player = null
	for child in get_children():
		if child in [game_env, camera, island, block_mgr, ui]:
			continue
		child.queue_free()
	for child in island.get_children():
		child.queue_free()

# ---------------- helpers ----------------
func _boom_at(pos: Vector3) -> void:
	var boom := CubeFactory.new().build_boom()
	boom.position = pos
	add_child(boom)
	var tween := boom.create_tween()
	tween.tween_property(boom, "scale", Vector3.ONE * 4.0, 0.4)
	tween.tween_callback(boom.queue_free)
	AudioManager.play("tnt_boom")

func _set_state(s: int) -> void:
	state = s
	state_changed.emit(_state_name(s))

func _state_name(s: int) -> String:
	match s:
		State.MENU: return "menu"
		State.PLAYING: return "playing"
		State.PAUSED: return "paused"
		State.WIN: return "win"
		State.GAMEOVER: return "gameover"
		State.LEVELSELECT: return "levelselect"
		State.SETTINGS: return "settings"
	return "?"
