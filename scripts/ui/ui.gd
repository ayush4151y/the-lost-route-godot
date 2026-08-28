extends CanvasLayer
# UI - builds the HUD and all screens (menu, level select, settings, pause,
# win, game over) using programmatic Control nodes. Communicates via signals.

signal action(action_name: String, payload: Variant)

var _root: Control
var _hud: Control
var _level_label: Label
var _phase_label: Label
var _hearts: Array = []
var _fire_bar: ColorRect
var _fire_label: Label
var _hint_btn: Button
var _menu: Control
var _dirty := true

func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

func _make_panel(center := true) -> Control:
	var panel := ColorRect.new()
	panel.color = Color(0, 0, 0, 0.0)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel

func _btn(text: String, pos: Vector2, size := Vector2(220, 44), fg := Color.WHITE) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size
	b.add_theme_color_override("font_color", fg)
	b.add_theme_font_size_override("font_size", 18)
	return b

func _label(text: String, pos: Vector2, size: float) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	return l

# ---------------- HUD ----------------
func init_hud(on_hint: Callable, on_pause: Callable, on_skip: Callable, on_rotate: Callable) -> void:
	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hud)

	_level_label = _label("Level 1", Vector2(20, 20), 30)
	_phase_label = _label("", Vector2(20, 60), 20)
	_phase_label.modulate = Color(1, 1, 0.5)
	_hud.add_child(_level_label)
	_hud.add_child(_phase_label)

	# hearts
	for i in 3:
		var h := _label("♥", Vector2(20 + i * 30, 95), 26)
		h.modulate = Color(0.9, 0.2, 0.2)
		_hearts.append(h)
		_hud.add_child(h)

	# fire bar
	_fire_label = _label("", Vector2(20, 130), 16)
	_fire_label.visible = false
	_hud.add_child(_fire_label)
	_fire_bar = ColorRect.new()
	_fire_bar.color = Color(1, 0.4, 0.1)
	_fire_bar.position = Vector2(20, 152)
	_fire_bar.size = Vector2(120, 10)
	_fire_bar.visible = false
	_hud.add_child(_fire_bar)

	# buttons (top-right)
	_hint_btn = _btn("HINT", Vector2(1180, 20), Vector2(80, 40))
	_hint_btn.pressed.connect(on_hint)
	_hud.add_child(_hint_btn)
	var pause := _btn("II", Vector2(1090, 20), Vector2(80, 40))
	pause.pressed.connect(on_pause)
	_hud.add_child(pause)
	var rot := _btn("ROT", Vector2(1000, 20), Vector2(80, 40))
	rot.pressed.connect(on_rotate)
	_hud.add_child(rot)
	var skip := _btn("SKIP", Vector2(910, 20), Vector2(80, 40))
	skip.pressed.connect(on_skip)
	_hud.add_child(skip)

	set_level(1)

func set_level(level: int) -> void:
	if _level_label:
		_level_label.text = "Level %d" % level

func set_phase(text: String, fire: bool = false) -> void:
	if _phase_label:
		_phase_label.text = text
	_show_fire(fire)

func _show_fire(on: bool) -> void:
	if _fire_bar:
		_fire_bar.visible = on
		_fire_label.visible = on

func set_hearts(n: int) -> void:
	for i in _hearts.size():
		var empty := i >= n
		_hearts[i].modulate = Color(0.4, 0.4, 0.4) if empty else Color(0.9, 0.2, 0.2)

func set_fire(frac: float) -> void:
	if _fire_bar and _fire_label:
		_fire_bar.size.x = 120 * clampf(frac, 0, 1)
		_fire_label.text = "FIRE! %d%%" % int(frac * 100)

func set_hint_glow(glow: bool) -> void:
	if _hint_btn:
		_hint_btn.modulate = Color(1, 0.8, 0.2) if glow else Color.WHITE

func show_hud() -> void:
	if _hud:
		_hud.visible = true

func hide_hud() -> void:
	if _hud:
		_hud.visible = false

# ---------------- generic screen builder ----------------
func _overlay(title: String) -> Control:
	var panel := ColorRect.new()
	panel.color = Color(0, 0, 0, 0.82)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(panel)
	var tl := _label(title, Vector2(360, 120), 40)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.position = Vector2(300, 120)
	tl.size = Vector2(680, 60)
	panel.add_child(tl)
	return panel

# ---------------- MENU ----------------
func show_menu(on_click: Callable) -> void:
	_clear_overlays()
	_menu = _overlay("THE LOST ROUTE")
	_menu.color = Color(0.05, 0.12, 0.2, 0.9)
	var tag := _label("MEMORY • REACTION • MASTERY", Vector2(300, 190), 20)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.size = Vector2(680, 40)
	_menu.add_child(tag)
	var y := 300
	var labels := [
		["START", "start"],
		["ENDLESS", "endless"],
		["DAILY", "daily"],
		["SETTINGS", "settings"],
	]
	for item in labels:
		var b := _btn(item[0], Vector2(530, y), Vector2(220, 46))
		b.pressed.connect(func(): on_click.call(item[1]))
		_menu.add_child(b)
		y += 60
	var foot := _label("AY GAME STUDIO", Vector2(470, 620), 16)
	_menu.add_child(foot)

# ---------------- PAUSE ----------------
func show_pause(on_click: Callable) -> void:
	var panel := _overlay("GAME PAUSED")
	var home := _btn("HOME", Vector2(480, 300), Vector2(320, 46))
	home.pressed.connect(func(): on_click.call("home"))
	panel.add_child(home)
	var stay := _btn("STAY", Vector2(480, 360), Vector2(320, 46))
	stay.pressed.connect(func(): on_click.call("stay"))
	panel.add_child(stay)

# ---------------- WIN ----------------
func show_win(title: String, subtitle: String, next_label: String, on_click: Callable) -> void:
	var panel := _overlay(title)
	if subtitle != "":
		var sub := _label(subtitle, Vector2(400, 200), 22)
		sub.size = Vector2(480, 40)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(sub)
	var b := _btn(next_label, Vector2(480, 320), Vector2(320, 46))
	b.pressed.connect(func(): on_click.call("next"))
	panel.add_child(b)

# ---------------- GAME OVER ----------------
func show_game_over(line: String, on_click: Callable) -> void:
	var panel := _overlay("GAME OVER")
	var l := _label(line, Vector2(400, 200), 22)
	l.size = Vector2(480, 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(l)
	var b := _btn("TRY AGAIN", Vector2(480, 320), Vector2(320, 46))
	b.pressed.connect(func(): on_click.call("retry"))
	panel.add_child(b)

# ---------------- SETTINGS ----------------
func show_settings(on_click: Callable) -> void:
	var panel := _overlay("SETTINGS")
	var y := 240
	var items := [
		["INPUT: KEYS", "input"],
		["SOUND: " + ("OFF" if SaveData.get_key("muted", "0") == "1" else "ON"), "sound"],
		["RESET PROGRESS", "reset"],
		["BACK", "back"],
	]
	for item in items:
		var b := _btn(item[0], Vector2(480, y), Vector2(320, 44))
		b.pressed.connect(func(): on_click.call(item[1]))
		panel.add_child(b)
		y += 56

# ---------------- LEVEL SELECT ----------------
func show_level_select(current: int, completed: Array, skipped: Array, on_click: Callable) -> void:
	var panel := _overlay("SELECT LEVEL / CAMPAIGN")
	var grid := GridContainer.new()
	grid.columns = 10
	grid.position = Vector2(180, 260)
	grid.size = Vector2(920, 320)
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	panel.add_child(grid)
	var available_upto := current
	for i in range(1, 201):
		var b := _btn(str(i), Vector2.ZERO, Vector2(80, 28))
		b.add_theme_font_size_override("font_size", 12)
		if completed.has(i):
			b.add_theme_color_override("font_color", Color(0.4, 1, 0.4))
		elif skipped.has(i):
			b.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
		elif i == current:
			b.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
		if i <= available_upto:
			b.pressed.connect(func(): on_click.call(i))
		else:
			b.disabled = true
			b.text = "🔒"
		grid.add_child(b)
	var back := _btn("< BACK", Vector2(20, 20), Vector2(120, 40))
	back.pressed.connect(func(): on_click.call("back"))
	panel.add_child(back)

func _clear_overlays() -> void:
	for child in _root.get_children():
		if child != _hud:
			child.queue_free()
