extends Node
class_name GameManager

const TOTAL_LEVELS := 200
const GRID_SIZE := 15

var camera: Camera3D
var world_root: Node3D
var ui = null
var world_env: WorldEnv
var cube_factory: CubeFactory
var player: Player
var island_builder: IslandBuilder
var camera_rig: CameraRig

var path_gen := PathGenerator.new()
var blocks := BlockManager.new()

var state := "menu"
var paused := false
var mode := "campaign"
var current_level := 1
var path: Array = []
var current_path_index := 0
var health := 3
var midpoint_rewarded := false
var sequence_id := 0
var tnt_back_direction = null
var active_tnt = null
var slide_falling := false
var stuck_timer = null
var run_streak := 0
var run_seed := 1
var segment_start_index := 0
var show_start_index := 0
var is_tutorial := false
var menu_angle := 0.0
var _ambience_started := false

# ---- lifecycle ----
func _ready():
	camera = get_parent().get_node("Camera")
	world_root = get_parent().get_node("World")
	ui = get_parent().get_node("UI")
	ui.init(self)

	world_env = WorldEnv.new()
	world_root.add_child(world_env)
	cube_factory = CubeFactory.new()
	cube_factory.gm = self
	world_root.add_child(cube_factory)
	player = Player.new()
	world_root.add_child(player)
	island_builder = IslandBuilder.new()
	world_root.add_child(island_builder)
	camera_rig = CameraRig.new()
	world_root.add_child(camera_rig)
	camera_rig.setup(camera, self)

	mode = SaveData.get_mode()
	current_level = SaveData.get_current_level()
	set_input_mode(SaveData.get_input_mode())
	if not SaveData.get_tutorial_done():
		start_tutorial()
	else:
		enter_menu()
	ui.set_indicator(indicator_text())

func _process(dt: float):
	if world_env != null:
		world_env.update(dt)
	if island_builder != null:
		island_builder.update(dt)
	if state == "menu" and camera != null:
		menu_angle += 0.003
		camera.position = Vector3(sin(menu_angle) * 8, 6.2, cos(menu_angle) * 8)
		camera.look_at(Vector3.ZERO)
		if player != null and player.visible:
			player.rotation.y = atan2(camera.position.x - player.position.x, camera.position.z - player.position.z)
	if paused:
		return
	if state != "playing":
		return
	blocks.update(dt, self)
	if blocks.slide_expired:
		blocks.slide_expired = false
		slide_falling = true
	if blocks.is_slide_active() and player != null:
		var p = path[current_path_index]
		var v = Constants.DIR_VECTORS[blocks.slide_dir]
		var prog = blocks.slide_progress()
		player.position = Vector3(p.x + v.x * 0.45 * prog, 1.2, p.y + v.z * 0.45 * prog)
	ui.set_fire_overlay(blocks.fire_active())

# ---- helpers ----
func indicator_text() -> String:
	if mode == "endless":
		return "Island " + str(run_streak + 1)
	if mode == "daily":
		return "Daily " + daily_label()
	return "Level " + str(current_level)

func daily_label() -> String:
	var d = Time.get_date_dict_from_system()
	return str(d.day) + " " + ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][d.month - 1]

func play_sfx(id: String, vol: float = 1.0):
	AudioManager.play(id, "sfx", vol)

func toggle_mute() -> bool:
	return AudioManager.toggle_mute()

func opposite(direction: String) -> String:
	match direction:
		"up": return "down"
		"down": return "up"
		"left": return "right"
		"right": return "left"
	return ""

func get_path_length(level: int) -> int:
	var ranges = [
		{"min": 1, "max": 20, "lenMin": 5, "lenMax": 8},
		{"min": 21, "max": 50, "lenMin": 8, "lenMax": 13},
		{"min": 51, "max": 100, "lenMin": 9, "lenMax": 18},
		{"min": 101, "max": 150, "lenMin": 15, "lenMax": 22},
		{"min": 151, "max": 200, "lenMin": 19, "lenMax": 25},
	]
	var r = ranges[0]
	for rr in ranges:
		if level <= rr["max"]:
			r = rr
			break
	var t = clamp(float(level - r["min"]) / float(r["max"] - r["min"]), 0.0, 1.0)
	return int(round(r["lenMin"] + (r["lenMax"] - r["lenMin"]) * t))

func get_turn_bias(level: int) -> float:
	return 0.4 + min(float(level - 1) / 199.0, 1.0) * 0.4

func offset_path_to_center():
	var min_x = INF; var min_z = INF; var max_x = -INF; var max_z = -INF
	for p in path:
		min_x = min(min_x, p.x); max_x = max(max_x, p.x)
		min_z = min(min_z, p.y); max_z = max(max_z, p.y)
	var cx = (min_x + max_x) / 2.0
	var cz = (min_z + max_z) / 2.0
	for i in range(path.size()):
		path[i] = Vector2i(path[i].x - int(cx), path[i].y - int(cz))

# ---- menu / screens ----
func enter_menu():
	state = "menu"
	paused = false
	cleanup()
	mode = SaveData.get_mode()
	current_level = SaveData.get_current_level()
	var dummy = path_gen.generate(7, 12345, 0.5, 3)
	offset_path_to_center()
	blocks.assign(dummy, 12345, 1, 0, {})
	island_builder.build(dummy, cube_factory)
	cube_factory.build_from_path(dummy, blocks)
	camera_rig.adjust_camera_to_path(0, -1)
	player.create(dummy[0], 3.0)
	player.position.y = 3.1
	ui.hide_screens()
	ui.show_screen("menu")
	ui.show_game_ui(false)
	ui.set_indicator(indicator_text())
	update_phase_text("")

func show_level_select():
	play_sfx("ui-click")
	state = "menu"
	paused = false
	ui.hide_screens()
	var items = []
	var completed = SaveData.get_completed("campaign")
	var skipped = SaveData.get_skipped("campaign")
	var cur = SaveData.get_current_level()
	for i in range(1, TOTAL_LEVELS + 1):
		var status = "locked"
		if completed.has(i):
			status = "complete"
		elif skipped.has(i):
			status = "skipped"
		elif i == cur:
			status = "current"
		elif i < cur:
			status = "available"
		items.append({"level": i, "status": status})
	ui.build_level_grid(items)
	ui.show_screen("level_select")
	ui.show_game_ui(false)

func show_settings():
	play_sfx("ui-click")
	ui.hide_screens()
	ui.show_screen("settings")
	ui.show_game_ui(false)

func hide_settings():
	play_sfx("ui-back")
	ui.hide_screens()
	ui.show_screen("menu")

func reset_progress():
	play_sfx("ui-back")
	SaveData.reset_progress()
	current_level = 1
	ui.hide_screens()
	ui.show_screen("menu")

func start_game():
	play_sfx("ui-click")
	mode = "campaign"
	current_level = SaveData.get_current_level()
	show_level_select()

# ---- level setup ----
func start_level(level: int):
	play_sfx("ui-click")
	mode = "campaign"
	cleanup()
	sequence_id += 1
	current_level = level
	SaveData.set_mode("campaign")
	setup_level({"level": level})

func start_endless():
	play_sfx("ui-click")
	mode = "endless"
	cleanup()
	run_streak = 0
	run_seed = (Time.get_unix_time_from_system() as int) & 0x7fffffff
	if run_seed == 0:
		run_seed = 1
	start_endless_segment()

func start_daily():
	play_sfx("ui-click")
	mode = "daily"
	cleanup()
	if SaveData.is_daily_done():
		show_daily_done()
		return
	start_daily_level()

func start_tutorial():
	play_sfx("ui-click")
	mode = "tutorial"
	cleanup()
	setup_level({"tutorial": true, "level": 0, "seed": 1, "noHearts": true, "canSkip": false, "phaseText": "Tutorial"})

func show_daily_done():
	state = "menu"
	ui.set_gameover("DAILY COMPLETE!", "Come back tomorrow for a new challenge!", "Streak: " + str(SaveData.get_daily_streak()) + " days", "MENU")
	ui.show_screen("gameover")

func start_daily_level():
	var path_length = 25
	var seed = SaveData.today_key() * 7919 + 7
	var min_turns = max(1, int(path_length / 3))
	setup_level({"level": 200, "seed": seed, "pathLength": path_length, "turnBias": 0.8, "minTurns": min_turns, "noHearts": true, "canSkip": false, "phaseText": "Daily Challenge!"})

func setup_level(opts: Dictionary):
	cleanup()
	sequence_id += 1
	is_tutorial = opts.get("tutorial", false)
	var path_length = opts.get("pathLength", get_path_length(opts.get("level", 1)))
	var seed = opts.get("seed", opts.get("level", 1) * 9973 + 42)
	var turn_bias = opts.get("turnBias", get_turn_bias(opts.get("level", 1)))
	var min_turns = opts.get("minTurns", max(1, int(path_length / 3)))
	if is_tutorial:
		path = tutorial_path()
	else:
		path = path_gen.generate(path_length, seed, turn_bias, min_turns)
	offset_path_to_center()
	blocks.assign(path, seed, opts.get("level", 1), 0, {})
	island_builder.build(path, cube_factory)
	cube_factory.build_from_path(path, blocks)
	camera_rig.adjust_camera_to_path(0, -1)
	segment_start_index = 0
	show_start_index = 0
	player.create(path[0])
	player.is_moving = false
	current_path_index = 0

	health = 3
	midpoint_rewarded = false
	if opts.get("hideHearts", false):
		ui.hide_hearts()
	else:
		ui.set_hearts(health, 3)
		ui.show_hearts()

	state = "showing"
	update_phase_text(opts.get("phaseText", "Watch!"))
	if opts.get("canSkip", true) == false:
		ui.set_skip_visible(false)
	else:
		ui.set_skip_visible(true)
	ui.show_game_ui(true)
	ui.set_hint_visible(false)
	ui.set_rotate_visible(false)
	ui.hide_screens()
	ui.set_indicator(indicator_text())
	start_show_sequence()

func start_show_sequence():
	var seq = sequence_id
	await cube_factory.show_path_wave(show_start_index)
	if sequence_id != seq or state != "showing":
		return
	cube_factory.draw_path_line(path, segment_start_index)
	ui.show_tap_start(true)

func tap_to_start():
	if state != "showing":
		return
	play_sfx("ui-click")
	if not _ambience_started:
		_ambience_started = true
		AudioManager.start_ambience()
	var seq = sequence_id
	ui.show_tap_start(false)
	cube_factory.remove_path_line()
	await cube_factory.hide_path_wave(show_start_index)
	if sequence_id != seq or state != "showing" or paused:
		return
	cube_factory.start_idle_animations()
	begin_playing()

func begin_playing():
	state = "playing"
	world_env.set_fog_lite(true)
	update_phase_text("Go!")
	ui.set_skip_visible(false)
	ui.set_hint_visible(true)
	ui.set_rotate_visible(true)
	ui.show_game_ui(true)
	start_stuck_timer()

func start_stuck_timer():
	clear_stuck_timer()
	stuck_timer = get_tree().create_timer(3.0)
	stuck_timer.timeout.connect(activate_hint_glow)

func activate_hint_glow():
	ui.glow_hint(true)

func clear_stuck_timer():
	if stuck_timer != null:
		stuck_timer.timeout.disconnect(activate_hint_glow)
		stuck_timer = null
	ui.glow_hint(false)

func hint_move():
	if state != "playing" or paused or player.is_moving:
		return
	if blocks.fuse_active() or blocks.is_slide_active():
		return
	var next_index = current_path_index + 1
	if next_index >= path.size():
		return
	play_sfx("hint")
	clear_stuck_timer()
	current_path_index = next_index
	player.current_index = next_index
	var next_pos = path[next_index]
	player.position = Vector3(next_pos.x, 1.2, next_pos.y)
	var prev = path[next_index - 1]
	player.set_face_direction(next_pos.x - prev.x, next_pos.y - prev.y)
	cube_factory.hint_rise_at(next_index)
	if next_index == path.size() - 1:
		win_level()
		return
	start_stuck_timer()

func skip_show():
	if mode != "campaign" or state == "menu" or state == "gameover" or state == "won" or player.is_moving:
		return
	play_sfx("ui-click")
	sequence_id += 1
	SaveData.mark_level_skipped("campaign", current_level)
	current_level += 1
	SaveData.save_current_level(current_level)
	cleanup()
	load_level()
	ui.set_indicator(indicator_text())

func load_level():
	setup_level({"level": current_level})

func toggle_pause():
	if state != "showing" and state != "playing":
		return
	paused = !paused
	if paused:
		play_sfx("ui-pause")
		AudioManager.pause_all()
		ui.show_screen("pause")
		ui.show_tap_start(false)
	else:
		play_sfx("ui-click")
		AudioManager.resume_all()
		ui.hide_screens()
		if state == "showing":
			ui.show_tap_start(true)

func resume_from_pause():
	paused = false
	AudioManager.resume_all()
	play_sfx("ui-click")
	ui.hide_screens()
	if state == "showing":
		ui.show_tap_start(true)

func go_home_from_pause():
	paused = false
	AudioManager.resume_all()
	back_to_menu()

# ---- movement ----
func rotate_view():
	if paused or (state != "playing" and state != "showing"):
		return
	camera_rig.rotate_view(90.0)

func handle_move(direction: String):
	if state != "playing" or paused or player.is_moving:
		return
	direction = camera_rig.screen_to_world(direction)
	if blocks.fuse_active():
		if direction == tnt_back_direction:
			back_to_previous()
		return
	var next_index = current_path_index + 1
	if next_index >= path.size():
		return
	var current_pos = path[current_path_index]
	var next_pos = path[next_index]
	var dir = path_gen.get_direction(current_pos, next_pos)
	if dir == direction:
		blocks.cancel_slide()
		clear_stuck_timer()
		current_path_index = next_index
		player.move_to(next_pos, next_index, _on_step.bind(next_index, current_pos))
	else:
		var v = Constants.DIR_VECTORS[direction]
		var nx = current_pos.x + int(v.x)
		var nz = current_pos.y + int(v.z)
		if blocks.is_decoy(nx, nz):
			clear_stuck_timer()
			tnt_back_direction = opposite(path_gen.get_direction(current_pos, Vector2i(nx, nz)))
			active_tnt = Vector2i(nx, nz)
			player.move_to(Vector2i(nx, nz), -1, func():
				cube_factory.rise_decoy_at(nx, nz)
				blocks.activate_tnt(self))
		else:
			game_over()

func _on_step(next_index: int, current_pos: Vector2i):
	cube_factory.rise_cube_at(next_index)
	if next_index == path.size() - 1:
		win_level()
		return
	blocks.on_entered(next_index, self, current_pos)
	if not midpoint_rewarded and next_index >= int(floor(path.size() / 2)):
		midpoint_rewarded = true
		add_health(1)
		update_phase_text("Midway! +1 Heart")
	start_stuck_timer()

func back_to_previous():
	if state != "playing" or paused or player.is_moving or not blocks.fuse_active():
		return
	var target = current_path_index - 1
	if target < 0:
		return
	blocks.defuse_tnt(self)
	current_path_index = target
	player.move_to(path[target], target, func():
		cube_factory.rise_cube_at(target)
		blocks.on_entered(target, self, path[target - 1] if target > 0 else path[0])
		start_stuck_timer())

func on_tnt_activated():
	play_sfx("tnt-fuse")
	update_phase_text("TNT! Go back!")
	ui.set_tnt_back(tnt_back_direction)

func on_tnt_defused():
	update_phase_text("Go!")
	ui.clear_tnt_back()

func on_tnt_exploded():
	update_phase_text("BOOM!")
	ui.clear_tnt_back()
	var pos = active_tnt
	active_tnt = null
	tnt_back_direction = null
	if pos != null:
		await cube_factory.blast_at(pos.x, pos.y, game_over)
	else:
		play_sfx("tnt-boom")
		game_over()

func add_health(amount: int):
	play_sfx("heart-pickup")
	health = min(health + amount, 3)
	ui.set_hearts(health, 3)

func on_fire_burned():
	play_sfx("fire-warn")
	health -= 1
	ui.set_hearts(health, 3)
	update_phase_text("Burned! -1 Heart")
	if health <= 0:
		game_over()

func win_level():
	play_sfx("win")
	if mode == "endless":
		endless_complete()
		return
	state = "won"
	update_phase_text("Level Complete!")
	ui.set_hint_visible(false)
	ui.set_rotate_visible(false)
	ui.set_skip_visible(false)
	if is_tutorial:
		SaveData.set_tutorial_done()
		ui.set_win("TUTORIAL COMPLETE!", "", "MENU")
	elif mode == "daily":
		SaveData.mark_daily_complete()
		ui.set_win("DAILY COMPLETE!", "Streak: " + str(SaveData.get_daily_streak()) + " days", "MENU")
	else:
		SaveData.mark_level_complete("campaign", current_level)
		SaveData.save_current_level(current_level + 1)
		ui.set_win("LEVEL COMPLETE!", "", "NEXT LEVEL")
	ui.show_screen("win")

func endless_complete():
	state = "won"
	run_streak += 1
	update_phase_text("Island " + str(run_streak) + " Complete!")
	ui.set_hint_visible(false)
	ui.set_rotate_visible(false)
	var best = SaveData.get_best_endless()
	if run_streak > best:
		SaveData.set_best_endless(run_streak)
	ui.set_indicator(indicator_text())
	await cube_factory.sink_old_cubes(path.size() - 1)
	if state != "won":
		return
	start_endless_segment()

func start_endless_segment():
	sequence_id += 1
	var len = int(round(clamp(8 + run_streak * 0.75, 8, 25)))
	var pseudo_level = min(run_streak * 5 + 1, 200)
	var turn_bias = min(0.4 + run_streak * 0.05, 0.8)
	var min_turns = max(1, int(len / 3))
	var seg_seed = (run_seed + run_streak * 7919) & 0xffffffff
	if run_streak == 0:
		var attempt = 0
		while true:
			path = path_gen.generate(len, (seg_seed + attempt * 1013) & 0xffffffff, turn_bias, min_turns)
			offset_path_to_center()
			island_builder.build(path, cube_factory)
			var on_island = false
			for p in path.slice(1, path.size() - 1):
				if island_builder.is_on_island(p.x, p.y):
					on_island = true
					break
			attempt += 1
			if not on_island or attempt > 40:
				break
		segment_start_index = 0
	else:
		var old_len = path.size()
		var last = path[old_len - 1]
		var blocked = {}
		for p in path:
			blocked[str(p.x) + "," + str(p.y)] = true
		for c in island_builder.islands:
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					blocked[str(c.x + dx) + "," + str(c.y + dz)] = true
		for d in blocks.decoys:
			blocked[str(d.x) + "," + str(d.y)] = true
		var seg = null
		for attempt in range(40):
			var cand = path_gen.generate(len, (seg_seed + attempt * 1013) & 0xffffffff, turn_bias, min_turns, blocked.keys(), last)
			if cand == null:
				continue
			seg = cand
			break
		if seg == null:
			seg = path_gen.generate(len, seg_seed, turn_bias, min_turns)
		path = path + seg.slice(1)
		segment_start_index = old_len - 1
	blocks.assign(path, seg_seed, pseudo_level, segment_start_index, {"noHearts": true})
	blocks.types[segment_start_index] = Constants.GRASS
	if run_streak == 0:
		show_start_index = 0
	else:
		cube_factory.retype_cube(segment_start_index, Constants.GRASS)
		island_builder.build_end_only(path)
		show_start_index = segment_start_index + 1
	cube_factory.build_from_path(path, blocks, show_start_index)
	camera_rig.adjust_camera_to_path(segment_start_index, path.size() - 1)
	if run_streak == 0:
		player.create(path[0])
		current_path_index = 0
	else:
		current_path_index = segment_start_index
	player.is_moving = false
	health = 1
	midpoint_rewarded = true
	ui.hide_hearts()
	state = "showing"
	update_phase_text("Island " + str(run_streak + 1) + "! Watch!")
	ui.set_skip_visible(false)
	ui.set_hint_visible(false)
	ui.set_rotate_visible(false)
	ui.show_game_ui(true)
	ui.hide_screens()
	ui.set_indicator(indicator_text())
	start_show_sequence()

func next_level():
	if is_tutorial:
		back_to_menu()
		return
	play_sfx("ui-click")
	current_level += 1
	SaveData.save_current_level(current_level)
	ui.hide_screens()
	cleanup()
	sequence_id += 1
	load_level()
	ui.set_indicator(indicator_text())

func game_over():
	play_sfx("gameover")
	state = "gameover"
	update_phase_text("Game Over")
	ui.set_hint_visible(false)
	ui.set_rotate_visible(false)
	ui.set_skip_visible(false)
	ui.set_fire_overlay(false)
	if mode == "endless":
		var best = SaveData.get_best_endless()
		ui.set_gameover("GAME OVER", "Wrong direction!", "Islands: " + str(run_streak) + " (Best: " + str(best) + ")", "TRY AGAIN")
	elif mode == "daily":
		ui.set_gameover("GAME OVER", "Wrong direction!", "Daily " + daily_label() + " — Streak: " + str(SaveData.get_daily_streak()) + " days", "TRY AGAIN")
	else:
		ui.set_gameover("GAME OVER", "Wrong direction!", "Level " + str(current_level), "TRY AGAIN")
	ui.show_screen("gameover")

func restart():
	play_sfx("ui-click")
	ui.hide_screens()
	if mode == "endless":
		cleanup()
		run_streak = 0
		run_seed = (Time.get_unix_time_from_system() as int) & 0x7fffffff
		if run_seed == 0:
			run_seed = 1
		start_endless_segment()
	elif mode == "daily":
		cleanup()
		if SaveData.is_daily_done():
			back_to_menu()
			return
		start_daily_level()
	elif is_tutorial:
		setup_level({"tutorial": true, "level": 0, "seed": 1, "noHearts": true, "canSkip": false, "phaseText": "Tutorial"})
	else:
		cleanup()
		sequence_id += 1
		load_level()

func back_to_menu():
	play_sfx("ui-back")
	cleanup()
	sequence_id += 1
	paused = false
	state = "menu"
	is_tutorial = false
	enter_menu()
	ui.set_indicator(indicator_text())

func set_input_mode(m: String):
	play_sfx("ui-toggle")
	SaveData.set_input_mode(m)
	ui.set_input_mode(m)

# ---- UI bridge ----
func update_phase_text(text: String):
	if ui != null:
		ui.set_phase(text)

func cleanup():
	ui.show_tap_start(false)
	ui.set_fire_overlay(false)
	clear_stuck_timer()
	tnt_back_direction = null
	slide_falling = false
	ui.clear_tnt_back()
	blocks.reset()
	cube_factory.clear()
	player.destroy()

func tutorial_path() -> Array:
	return [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
		Vector2i(3, 1), Vector2i(3, 2), Vector2i(2, 2), Vector2i(1, 2)
	]

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_UP, KEY_W: handle_move("up")
			KEY_DOWN, KEY_S: handle_move("down")
			KEY_LEFT, KEY_A: handle_move("left")
			KEY_RIGHT, KEY_D: handle_move("right")
			KEY_SPACE, KEY_ENTER:
				if state == "showing":
					tap_to_start()
			KEY_H: hint_move()
			KEY_R: rotate_view()
			KEY_ESCAPE: toggle_pause()
