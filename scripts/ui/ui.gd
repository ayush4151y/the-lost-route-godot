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
var dpad: Control
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
var settings_dpad_btn: Button
var settings_swipe_btn: Button
var settings_sound_btn: Button

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

func _img_btn(path: String, cb: Callable, w: int) -> Button:
	var b = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, 82)
	var tex = load(path)
	if tex != null:
		b.icon = tex
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_stylebox_override("normal", _transparent_style())
	b.add_theme_stylebox_override("hover", _transparent_style())
	b.add_theme_stylebox_override("pressed", _transparent_style())
	b.add_theme_stylebox_override("focus", _transparent_style())
	b.pressed.connect(cb)
	return b

func _transparent_style() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(1, 1, 1, 0.0)
	return s

func _slider(label_text: String, value: float, cb: Callable) -> VBoxContainer:
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var lab = Label.new()
	lab.text = label_text
	lab.add_theme_font_size_override("font_size", 16)
	lab.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	v.add_child(lab)
	var sl = HSlider.new()
	sl.min_value = 0.0; sl.max_value = 1.0; sl.step = 0.01
	sl.value = value
	sl.custom_minimum_size = Vector2(300, 28)
	sl.focus_mode = Control.FOCUS_NONE
	sl.value_changed.connect(func(val): cb.call(val))
	v.add_child(sl)
	return v

func _toggle_sound_label(btn: Button):
	var muted = gm.toggle_mute()
	btn.text = "SOUND: " + ("OFF" if muted else "ON")

func _highlight_input():
	if settings_dpad_btn == null or settings_swipe_btn == null:
		return
	var dpad_on = (current_input_mode == "dpad")
	settings_dpad_btn.modulate = Color(1, 1, 1) if dpad_on else Color(0.55, 0.6, 0.65)
	settings_swipe_btn.modulate = Color(1, 1, 1) if not dpad_on else Color(0.55, 0.6, 0.65)

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

func _anchor(ctrl: Control, aleft: float, atop: float, aright: float, abottom: float, oleft: float, otop: float, oright: float, obottom: float):
	ctrl.anchor_left = aleft
	ctrl.anchor_top = atop
	ctrl.anchor_right = aright
	ctrl.anchor_bottom = abottom
	ctrl.offset_left = oleft
	ctrl.offset_top = otop
	ctrl.offset_right = oright
	ctrl.offset_bottom = obottom

func _mk(text: String, cb: Callable, w: int, h: int, radius: int) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, h)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 30)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.10)
	sb.border_color = Color(1, 1, 1, 0.18)
	for s in ["border_width_left", "border_width_right", "border_width_top", "border_width_bottom"]:
		sb.set(s, 1)
	for c in ["corner_radius_top_left", "corner_radius_top_right", "corner_radius_bottom_left", "corner_radius_bottom_right"]:
		sb.set(c, radius)
	b.add_theme_stylebox_override("normal", sb)
	var hsb = sb.duplicate(); hsb.bg_color = Color(0.0, 0.737, 0.831, 0.30); b.add_theme_stylebox_override("hover", hsb)
	var psb = sb.duplicate(); psb.bg_color = Color(0.0, 0.737, 0.831, 0.55); b.add_theme_stylebox_override("pressed", psb)
	b.add_theme_color_override("font_color", Color(1, 1, 1))
	b.pressed.connect(cb)
	return b

func _build_hud():
	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_STOP
	_anchor(hud, 0, 0, 1, 1, 0, 0, 0, 0)
	add_child(hud)

	# top-left: pause + hearts + level
	top_bar = HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 12)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(top_bar, 0, 0, 1, 0, 15, 15, -15, 59)
	hud.add_child(top_bar)

	pause_btn = _mk("II", gm_cb("toggle_pause"), 44, 44, 12)
	top_bar.add_child(pause_btn)

	hearts_label = Label.new()
	hearts_label.text = "♥♥♥"
	hearts_label.add_theme_font_size_override("font_size", 26)
	hearts_label.add_theme_color_override("font_color", Color(1.0, 0.32, 0.36))
	hearts_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	top_bar.add_child(hearts_label)

	indicator_label = Label.new()
	indicator_label.text = "Level 1"
	indicator_label.add_theme_font_size_override("font_size", 22)
	indicator_label.add_theme_color_override("font_color", Color(0.0, 0.737, 0.831))
	indicator_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	top_bar.add_child(indicator_label)

	# top-right: rotate + hint + skip
	var top_right = HBoxContainer.new()
	top_right.alignment = BoxContainer.ALIGNMENT_END
	top_right.add_theme_constant_override("separation", 12)
	top_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(top_right, 0, 0, 1, 0, 15, 15, -15, 59)
	hud.add_child(top_right)

	rotate_btn = _mk("↻", gm_cb("rotate_view"), 44, 44, 12)
	hint_btn = _mk("?", gm_cb("hint_move"), 44, 44, 12)
	skip_btn = _mk("⏭", gm_cb("skip_show"), 44, 44, 12)
	top_right.add_child(rotate_btn)
	top_right.add_child(hint_btn)
	top_right.add_child(skip_btn)

	phase_label = Label.new()
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.text = ""
	phase_label.add_theme_font_size_override("font_size", 30)
	phase_label.add_theme_color_override("font_color", Color(1, 0.92, 0.6))
	phase_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(phase_label, 0, 0, 1, 0, 0, 72, 0, 110)
	hud.add_child(phase_label)

	tnt_label = Label.new()
	tnt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tnt_label.text = ""
	tnt_label.add_theme_font_size_override("font_size", 26)
	tnt_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
	tnt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(tnt_label, 0, 0, 1, 0, 0, 114, 0, 148)
	hud.add_child(tnt_label)

	# dpad: bottom-left (up/down) + bottom-right (left/right)
	dpad = Control.new()
	dpad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(dpad, 0, 0, 1, 1, 0, 0, 0, 0)
	hud.add_child(dpad)

	var bl = VBoxContainer.new()
	bl.add_theme_constant_override("separation", 14)
	bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(bl, 0, 1, 0, 1, 24, -246, 100, -80)
	dpad.add_child(bl)
	bl.add_child(_mk("▲", gm_cb_str("handle_move", "up"), 76, 76, 22))
	bl.add_child(_mk("▼", gm_cb_str("handle_move", "down"), 76, 76, 22))

	var br = HBoxContainer.new()
	br.add_theme_constant_override("separation", 14)
	br.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(br, 1, 1, 1, 1, -190, -156, -24, -80)
	dpad.add_child(br)
	br.add_child(_mk("◀", gm_cb_str("handle_move", "left"), 76, 76, 22))
	br.add_child(_mk("▶", gm_cb_str("handle_move", "right"), 76, 76, 22))

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

	# MENU (matches original: sky bg, logo, island, image buttons)
	menu_panel = Control.new()
	menu_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panels.add_child(menu_panel)

	var bg = TextureRect.new()
	var btex = load("res://assets/menu/sky.png")
	if btex != null:
		bg.texture = btex
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = 1
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_panel.add_child(bg)
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.28)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_panel.add_child(dim)

	var cc = CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_panel.add_child(cc)
	var mv = VBoxContainer.new()
	mv.add_theme_constant_override("separation", 16)
	mv.alignment = BoxContainer.ALIGNMENT_CENTER
	cc.add_child(mv)

	var logo = TextureRect.new()
	var ltex = load("res://assets/menu/logo.png")
	if ltex != null:
		logo.texture = ltex
	logo.expand_mode = 1
	logo.custom_minimum_size = Vector2(440, 120)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mv.add_child(logo)

	var tag = Label.new()
	tag.text = "MEMORY   •   REACTION   •   MASTERY"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 18)
	tag.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	mv.add_child(tag)

	var isl = TextureRect.new()
	var itex = load("res://assets/menu/island.png")
	if itex != null:
		isl.texture = itex
	isl.expand_mode = 1
	isl.custom_minimum_size = Vector2(360, 200)
	isl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mv.add_child(isl)

	mv.add_child(_img_btn("res://assets/menu/btn-start.png", gm_cb("start_game"), 300))
	mv.add_child(_img_btn("res://assets/menu/btn-endless.png", gm_cb("start_endless"), 300))
	mv.add_child(_img_btn("res://assets/menu/btn-daily.png", gm_cb("start_daily"), 300))
	mv.add_child(_img_btn("res://assets/menu/btn-settings.png", gm_cb("show_settings"), 300))

	var st = Label.new()
	st.text = "AY GAME STUDIO"
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	st.add_theme_font_size_override("font_size", 13)
	st.add_theme_color_override("font_color", Color(0.7, 0.78, 0.85, 0.8))
	mv.add_child(st)

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

	# SETTINGS (matches original: input toggle, sound, volumes, tutorial, reset)
	settings_panel = _panel()
	settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	settings_panel.custom_minimum_size = Vector2(360, 540)
	var sv = VBoxContainer.new(); sv.add_theme_constant_override("separation", 14)
	sv.set_anchors_preset(Control.PRESET_CENTER)
	settings_panel.add_child(sv)
	var shead = Label.new(); shead.text = "SETTINGS"; shead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shead.add_theme_font_size_override("font_size", 28); shead.add_theme_color_override("font_color", Color(0.6, 0.9, 1))
	sv.add_child(shead)

	var il = Label.new(); il.text = "INPUT"; il.add_theme_font_size_override("font_size", 15); il.add_theme_color_override("font_color", Color(0.8,0.9,1.0))
	sv.add_child(il)
	var input_row = HBoxContainer.new(); input_row.alignment = BoxContainer.ALIGNMENT_CENTER
	input_row.add_theme_constant_override("separation", 10)
	settings_dpad_btn = _make_btn("DPad", func(): gm.set_input_mode("dpad"), 150, 48)
	settings_swipe_btn = _make_btn("Swipe", func(): gm.set_input_mode("swipe"), 150, 48)
	input_row.add_child(settings_dpad_btn); input_row.add_child(settings_swipe_btn)
	sv.add_child(input_row)

	settings_sound_btn = _make_btn("SOUND: ON", func(): _toggle_sound_label(settings_sound_btn), 320, 48)
	sv.add_child(settings_sound_btn)
	sv.add_child(_slider("MUSIC VOLUME", AudioManager.music_vol, func(v): AudioManager.set_music_volume(v)))
	sv.add_child(_slider("EFFECTS VOLUME", AudioManager.sfx_vol, func(v): AudioManager.set_sfx_volume(v)))
	sv.add_child(_make_btn("Tutorial", gm_cb("start_tutorial"), 320, 48))
	sv.add_child(_make_btn("Reset Progress", gm_cb("reset_progress"), 320, 48))
	sv.add_child(_make_btn("Back", gm_cb("hide_settings"), 320, 50))
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

func _refresh_settings():
	_highlight_input()
	if settings_sound_btn != null:
		settings_sound_btn.text = "SOUND: " + ("OFF" if AudioManager.is_muted() else "ON")

func show_screen(name: String):
	hide_screens()
	match name:
		"menu": menu_panel.show()
		"level_select": level_panel.show()
		"settings":
			_refresh_settings()
			settings_panel.show()
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
		var fg = Color(0.85, 0.9, 0.95)
		var bg = Color(0.18, 0.22, 0.32)
		match it["status"]:
			"complete": bg = Color(0.16, 0.42, 0.22); fg = Color(0.82, 1.0, 0.86)
			"skipped": bg = Color(0.45, 0.38, 0.12); fg = Color(1.0, 0.95, 0.7)
			"current": bg = Color(0.12, 0.45, 0.7); fg = Color(0.85, 0.95, 1.0)
			"available": bg = Color(0.25, 0.3, 0.4); fg = Color(0.9, 0.9, 0.95)
			"locked": bg = Color(0.15, 0.17, 0.23); fg = Color(0.5, 0.55, 0.62)
		var st = StyleBoxFlat.new()
		st.bg_color = bg
		st.set_corner_radius_all(8)
		st.border_color = bg.lightened(0.35)
		st.set_border_width_all(1)
		b.add_theme_stylebox_override("normal", st)
		var st_h = st.duplicate(); st_h.bg_color = bg.lightened(0.15)
		b.add_theme_stylebox_override("hover", st_h)
		b.add_theme_color_override("font_color", fg)
		b.add_theme_color_override("disabled_font_color", fg)
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
	_highlight_input()
