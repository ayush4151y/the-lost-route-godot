extends Control
class_name UI

var gm = null
var hud: Control
var top_bar: HBoxContainer
var indicator_label: Label
var hearts_label: Label
var pause_btn: Button
var phase_label: Label
var bottom: HBoxContainer
var dpad: VBoxContainer
var hint_btn: Button
var skip_btn: Button
var rotate_btn: Button
var tnt_label: Label
var fire_overlay: ColorRect
var tap_overlay: Control
var panels: Control
var menu_panel: Control
var level_panel: Control
var settings_panel: Control
var win_panel: Control
var gameover_panel: Control
var pause_panel: Control
var win_title: Label
var win_sub: Label
var win_btn: Button
var gameover_title: Label
var gameover_sub: Label
var gameover_final: Label
var gameover_btn: Button
var current_input_mode := "dpad"

func init(g):
	gm = g
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_hud()
	_build_overlays()
	_build_panels()
	hide_screens()
	show_game_ui(false)

func _make_btn(text: String, cb: Callable, minw := 120, minh := 54) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(minw, minh)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(cb)
	return b

func _panel(extra := 0) -> PanelContainer:
	var p = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.12, 0.2, 0.92)
	sb.border_color = Color(0.4, 0.8, 1.0, 0.8)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	p.add_theme_stylebox_override("panel", sb)
	return p

func _build_hud():
	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(hud)

	top_bar = HBoxContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.position = Vector2(12, 12)
	top_bar.add_theme_constant_override("separation", 12)
	hud.add_child(top_bar)

	indicator_label = Label.new()
	indicator_label.text = "Level 1"
	indicator_label.add_theme_font_size_override("font_size", 24)
	indicator_label.add_theme_color_override("font_color", Color(1, 1, 1))
	top_bar.add_child(indicator_label)

	hearts_label = Label.new()
	hearts_label.text = "♥♥♥"
	hearts_label.add_theme_font_size_override("font_size", 26)
	hearts_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.35))
	top_bar.add_child(hearts_label)

	pause_btn = _make_btn("II", gm_cb("toggle_pause"), 56, 48)
	top_bar.add_child(pause_btn)

	phase_label = Label.new()
	phase_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	phase_label.position = Vector2(0, 64)
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.text = ""
	phase_label.add_theme_font_size_override("font_size", 30)
	phase_label.add_theme_color_override("font_color", Color(1, 0.92, 0.6))
	hud.add_child(phase_label)

	tnt_label = Label.new()
	tnt_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	tnt_label.position = Vector2(0, 104)
	tnt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tnt_label.text = ""
	tnt_label.add_theme_font_size_override("font_size", 26)
	tnt_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
	hud.add_child(tnt_label)

	bottom = HBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.position = Vector2(12, -12)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	hud.add_child(bottom)

	hint_btn = _make_btn("?", gm_cb("hint_move"), 64, 64)
	bottom.add_child(hint_btn)
	skip_btn = _make_btn("SKIP", gm_cb("skip_show"), 90, 64)
	bottom.add_child(skip_btn)
	rotate_btn = _make_btn("↻", gm_cb("rotate_view"), 64, 64)
	bottom.add_child(rotate_btn)

	dpad = VBoxContainer.new()
	dpad.add_theme_constant_override("separation", 4)
	var up = _make_btn("▲", gm_cb_str("handle_move", "up"), 72, 56)
	var mid = HBoxContainer.new()
	var left = _make_btn("◀", gm_cb_str("handle_move", "left"), 72, 56)
	var right = _make_btn("▶", gm_cb_str("handle_move", "right"), 72, 56)
	mid.add_child(left); mid.add_child(right)
	var down = _make_btn("▼", gm_cb_str("handle_move", "down"), 72, 56)
	dpad.add_child(up); dpad.add_child(mid); dpad.add_child(down)
	bottom.add_child(dpad)

	hud.gui_input.connect(_on_hud_input)

func gm_cb(method: String) -> Callable:
	return Callable(gm, method)

func gm_cb_str(method: String, arg: String) -> Callable:
	return func(): gm.call(method, arg)

func _on_hud_input(event):
	if current_input_mode != "swipe":
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_swipe_start = event.position
		elif _swipe_start != null:
			var d = event.position - _swipe_start
			_swipe_start = null
			if d.length() > 30:
				if abs(d.x) > abs(d.y):
					gm.handle_move("right" if d.x > 0 else "left")
				else:
					gm.handle_move("down" if d.y > 0 else "up")
var _swipe_start = null

func _build_overlays():
	fire_overlay = ColorRect.new()
	fire_overlay.color = Color(1, 0.2, 0.1, 0.0)
	fire_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	fire_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fire_overlay)

	tap_overlay = Control.new()
	tap_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	tap_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	tap_overlay.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			gm.tap_to_start())
	add_child(tap_overlay)
	tap_overlay.hide()

func _build_panels():
	panels = Control.new()
	panels.set_anchors_preset(Control.PRESET_FULL_RECT)
	panels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panels)

	# MENU
	menu_panel = _panel()
	menu_panel.set_anchors_preset(Control.PRESET_CENTER)
	menu_panel.custom_minimum_size = Vector2(340, 420)
	var mv = VBoxContainer.new()
	mv.add_theme_constant_override("separation", 12)
	mv.set_anchors_preset(Control.PRESET_CENTER)
	menu_panel.add_child(mv)
	var title = Label.new(); title.text = "THE LOST ROUTE"; title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34); title.add_theme_color_override("font_color", Color(0.6, 0.9, 1))
	mv.add_child(title)
	mv.add_child(_make_btn("Play", gm_cb("start_game"), 240, 56))
	mv.add_child(_make_btn("Endless", gm_cb("start_endless"), 240, 56))
	mv.add_child(_make_btn("Daily", gm_cb("start_daily"), 240, 56))
	mv.add_child(_make_btn("Tutorial", gm_cb("start_tutorial"), 240, 56))
	mv.add_child(_make_btn("Settings", gm_cb("show_settings"), 240, 56))
	panels.add_child(menu_panel)

	# LEVEL SELECT
	level_panel = _panel()
	level_panel.set_anchors_preset(Control.PRESET_CENTER)
	level_panel.custom_minimum_size = Vector2(360, 520)
	var lv = VBoxContainer.new()
	lv.set_anchors_preset(Control.PRESET_FULL_RECT)
	level_panel.add_child(lv)
	var lhead = Label.new(); lhead.text = "SELECT LEVEL"; lhead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lhead.add_theme_font_size_override("font_size", 28); lhead.add_theme_color_override("font_color", Color(0.6, 0.9, 1))
	lv.add_child(lhead)
	var scroll = ScrollContainer.new(); scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	var grid = GridContainer.new(); grid.columns = 5; grid.add_theme_constant_override("h_separation", 6); grid.add_theme_constant_override("v_separation", 6)
	grid.name = "grid"
	scroll.add_child(grid)
	lv.add_child(scroll)
	lv.add_child(_make_btn("Back", gm_cb("back_to_menu"), 240, 50))
	panels.add_child(level_panel)

	# SETTINGS
	settings_panel = _panel()
	settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	settings_panel.custom_minimum_size = Vector2(340, 360)
	var sv = VBoxContainer.new(); sv.add_theme_constant_override("separation", 12)
	sv.set_anchors_preset(Control.PRESET_CENTER)
	settings_panel.add_child(sv)
	var shead = Label.new(); shead.text = "SETTINGS"; shead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shead.add_theme_font_size_override("font_size", 28); shead.add_theme_color_override("font_color", Color(0.6, 0.9, 1))
	sv.add_child(shead)
	sv.add_child(_make_btn("Input: DPad", _toggle_input, 260, 50))
	sv.add_child(_make_btn("Reset Progress", gm_cb("reset_progress"), 260, 50))
	sv.add_child(_make_btn("Back", gm_cb("hide_settings"), 260, 50))
	panels.add_child(settings_panel)

	# WIN
	win_panel = _panel()
	win_panel.set_anchors_preset(Control.PRESET_CENTER)
	win_panel.custom_minimum_size = Vector2(360, 320)
	var wv = VBoxContainer.new(); wv.add_theme_constant_override("separation", 12)
	wv.set_anchors_preset(Control.PRESET_CENTER)
	win_panel.add_child(wv)
	win_title = Label.new(); win_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_title.add_theme_font_size_override("font_size", 32); win_title.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	wv.add_child(win_title)
	win_sub = Label.new(); win_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_sub.add_theme_font_size_override("font_size", 22)
	wv.add_child(win_sub)
	win_btn = _make_btn("NEXT LEVEL", gm_cb("next_level"), 240, 56)
	wv.add_child(win_btn)
	panels.add_child(win_panel)

	# GAMEOVER
	gameover_panel = _panel()
	gameover_panel.set_anchors_preset(Control.PRESET_CENTER)
	gameover_panel.custom_minimum_size = Vector2(360, 360)
	var gv = VBoxContainer.new(); gv.add_theme_constant_override("separation", 12)
	gv.set_anchors_preset(Control.PRESET_CENTER)
	gameover_panel.add_child(gv)
	gameover_title = Label.new(); gameover_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gameover_title.add_theme_font_size_override("font_size", 32); gameover_title.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	gv.add_child(gameover_title)
	gameover_sub = Label.new(); gameover_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gameover_sub.add_theme_font_size_override("font_size", 22)
	gv.add_child(gameover_sub)
	gameover_final = Label.new(); gameover_final.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gameover_final.add_theme_font_size_override("font_size", 18); gameover_final.add_theme_color_override("font_color", Color(0.9, 0.9, 0.7))
	gv.add_child(gameover_final)
	gameover_btn = _make_btn("TRY AGAIN", gm_cb("restart"), 240, 56)
	gv.add_child(gameover_btn)
	gv.add_child(_make_btn("Menu", gm_cb("back_to_menu"), 240, 50))
	panels.add_child(gameover_panel)

	# PAUSE
	pause_panel = _panel()
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.custom_minimum_size = Vector2(320, 280)
	var pv = VBoxContainer.new(); pv.add_theme_constant_override("separation", 12)
	pv.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.add_child(pv)
	var phead = Label.new(); phead.text = "PAUSED"; phead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phead.add_theme_font_size_override("font_size", 30); phead.add_theme_color_override("font_color", Color(0.6, 0.9, 1))
	pv.add_child(phead)
	pv.add_child(_make_btn("Resume", gm_cb("resume_from_pause"), 240, 54))
	pv.add_child(_make_btn("Restart", gm_cb("restart"), 240, 54))
	pv.add_child(_make_btn("Menu", gm_cb("go_home_from_pause"), 240, 54))
	panels.add_child(pause_panel)

func _toggle_input():
	if current_input_mode == "dpad":
		set_input_mode("swipe")
	else:
		set_input_mode("dpad")

# ---- public API used by GameManager ----
func set_phase(text: String):
	phase_label.text = text

func set_indicator(text: String):
	indicator_label.text = text

func set_hearts(hp: int, max_hp: int):
	var s = ""
	for i in range(max_hp):
		s += "♥" if i < hp else "♡"
	hearts_label.text = s
	hearts_label.visible = true

func show_hearts():
	hearts_label.visible = true

func hide_hearts():
	hearts_label.visible = false

func show_game_ui(on: bool):
	hud.visible = on

func show_tap_start(on: bool):
	tap_overlay.visible = on
	if on:
		tap_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		tap_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_skip_visible(on: bool):
	skip_btn.visible = on

func set_hint_visible(on: bool):
	hint_btn.visible = on

func set_rotate_visible(on: bool):
	rotate_btn.visible = on

func glow_hint(on: bool):
	hint_btn.modulate = Color(1.0, 1.0, 0.6) if on else Color(1, 1, 1)

func set_tnt_back(dir: String):
	tnt_label.text = "Go BACK: " + dir.to_upper()

func clear_tnt_back():
	tnt_label.text = ""

func set_fire_overlay(on: bool):
	var target = 0.18 if on else 0.0
	fire_overlay.color = Color(1, 0.2, 0.1, target)

func hide_screens():
	for p in [menu_panel, level_panel, settings_panel, win_panel, gameover_panel, pause_panel]:
		p.hide()

func show_screen(name: String):
	hide_screens()
	match name:
		"menu": menu_panel.show()
		"level_select": level_panel.show()
		"settings": settings_panel.show()
		"win": win_panel.show()
		"gameover": gameover_panel.show()
		"pause": pause_panel.show()

func build_level_grid(items: Array):
	var grid = level_panel.find_child("grid", true, false)
	for c in grid.get_children():
		c.queue_free()
	for it in items:
		var b = Button.new()
		b.text = str(it["level"])
		b.custom_minimum_size = Vector2(56, 56)
		b.focus_mode = Control.FOCUS_NONE
		var col = Color(0.6, 0.7, 0.8)
		match it["status"]:
			"complete": col = Color(0.4, 0.9, 0.5)
			"skipped": col = Color(0.9, 0.8, 0.3)
			"current": col = Color(0.4, 0.8, 1.0)
			"available": col = Color(0.7, 0.7, 0.7)
			"locked": col = Color(0.4, 0.4, 0.45)
		b.add_theme_color_override("font_color", col)
		if it["status"] != "locked":
			b.pressed.connect(func(): gm.start_level(it["level"]))
		else:
			b.disabled = true
		grid.add_child(b)

func set_win(title: String, sub: String, btn: String):
	win_title.text = title
	win_sub.text = sub
	win_btn.text = btn

func set_gameover(title: String, sub: String, final_text: String, btn: String):
	gameover_title.text = title
	gameover_sub.text = sub
	gameover_final.text = final_text
	gameover_btn.text = btn

func set_input_mode(m: String):
	current_input_mode = m
	if m == "swipe":
		dpad.visible = false
	else:
		dpad.visible = true
