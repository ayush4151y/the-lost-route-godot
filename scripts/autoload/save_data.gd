extends Node

func suffix(mode: String) -> String:
	match mode:
		"endless": return "_e"
		"daily": return "_d"
		"tutorial": return "_t"
		_: return ""

func _rd(key: String, default):
	var p = "user://" + key + ".json"
	if not FileAccess.file_exists(p):
		return default
	var f = FileAccess.open(p, FileAccess.READ)
	var txt = f.get_as_text()
	f.close()
	var v = JSON.parse_string(txt)
	return v if v != null else default

func _wr(key: String, value):
	var p = "user://" + key + ".json"
	var f = FileAccess.open(p, FileAccess.WRITE)
	f.store_string(JSON.stringify(value))
	f.close()

func get_completed(mode: String) -> Array:
	return _rd("rak_completed" + suffix(mode), [])

func save_completed(mode: String, levels: Array):
	_wr("rak_completed" + suffix(mode), levels)

func mark_level_complete(mode: String, level: int):
	var c = get_completed(mode)
	if not c.has(level):
		c.append(level)
		save_completed(mode, c)

func get_current_level() -> int:
	return int(_rd("rak_level", 1))

func save_current_level(level: int):
	_wr("rak_level", level)

func get_skipped(mode: String) -> Array:
	return _rd("rak_skipped" + suffix(mode), [])

func save_skipped(mode: String, levels: Array):
	_wr("rak_skipped" + suffix(mode), levels)

func mark_level_skipped(mode: String, level: int):
	var s = get_skipped(mode)
	if not s.has(level):
		s.append(level)
		save_skipped(mode, s)

func get_mode() -> String:
	return _rd("rak_mode", "campaign")

func set_mode(mode: String):
	_wr("rak_mode", mode)

func is_daily_done() -> bool:
	return int(_rd("rak_daily_last", 0)) == today_key()

func get_daily_streak() -> int:
	return int(_rd("rak_daily_streak", 0))

func mark_daily_complete():
	var today = today_key()
	if int(_rd("rak_daily_last", 0)) == today:
		return
	var last = int(_rd("rak_daily_last", 0))
	var streak = 1
	if last == today - 1:
		streak = get_daily_streak() + 1
	_wr("rak_daily_streak", streak)
	_wr("rak_daily_last", today)

func today_key() -> int:
	var d = Time.get_date_dict_from_system()
	return d.year * 10000 + d.month * 100 + d.day

func get_best_endless() -> int:
	return int(_rd("rak_best_endless", 0))

func set_best_endless(v: int):
	_wr("rak_best_endless", v)

func get_input_mode() -> String:
	return _rd("rak_input", "dpad")

func set_input_mode(mode: String):
	_wr("rak_input", mode)

func get_tutorial_done() -> bool:
	return bool(_rd("rak_tutorial", false))

func set_tutorial_done():
	_wr("rak_tutorial", true)

func reset_progress():
	for k in ["rak_completed", "rak_skipped", "rak_level", "rak_completed_e", "rak_skipped_e",
			"rak_level_e", "rak_completed_d", "rak_skipped_d", "rak_level_d",
			"rak_completed_t", "rak_skipped_t", "rak_level_t", "rak_mode",
			"rak_best_endless", "rak_daily_last", "rak_daily_streak", "rak_tutorial", "rak_input"]:
		var p = "user://" + k + ".json"
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
