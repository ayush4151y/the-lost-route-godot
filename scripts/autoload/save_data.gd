extends Node
# SaveData - localStorage equivalent using user:// config file.
# Handles all persistence: modes, completed/skipped/current levels,
# daily streak, endless best, input mode, audio volumes, tutorial flag.

const FILE := "user://rak_save.cfg"

const MODE_CAMPAIGN := "campaign"
const MODE_ENDLESS := "endless"
const MODE_DAILY := "daily"

var data := {}

func _ready() -> void:
	load_save()

func load_save() -> void:
	data = {}
	var cfg := ConfigFile.new()
	if cfg.load(FILE) == OK:
		for key in cfg.get_section_keys("rak"):
			data[key] = cfg.get_value("rak", key)
	# defaults
	if not data.has("mode"):
		data["mode"] = MODE_CAMPAIGN
	if not data.has("input"):
		data["input"] = "dpad"
	if not data.has("muted"):
		data["muted"] = "0"
	if not data.has("vol_music"):
		data["vol_music"] = "0.8"
	if not data.has("vol_sfx"):
		data["vol_sfx"] = "0.8"

func _save() -> void:
	var cfg := ConfigFile.new()
	for key in data:
		cfg.set_value("rak", key, data[key])
	cfg.save(FILE)

func get_key(key: String, def := "") -> String:
	if data.has(key):
		return str(data[key])
	return def

func set_key(key: String, val) -> void:
	data[key] = val
	_save()

# ---- arrays (completed / skipped levels) ----
func get_levels(key: String) -> Array:
	var raw := get_key(key, "[]")
	var parsed = JSON.parse_string(raw)
	if parsed is Array:
		return parsed
	return []

func add_level(key: String, level: int) -> void:
	var arr := get_levels(key)
	if not arr.has(level):
		arr.append(level)
	set_key(key, JSON.stringify(arr))

func has_level(key: String, level: int) -> bool:
	return get_levels(key).has(level)

# ---- daily helpers ----
func today_key() -> int:
	var d := Time.get_date_dict_from_system()
	return d.year * 10000 + d.month * 100 + d.day

func get_daily_streak() -> int:
	return int(get_key("daily_streak", "0"))

func set_daily_streak(v: int) -> void:
	set_key("daily_streak", str(v))

func get_int(key: String, def := 0) -> int:
	return int(get_key(key, str(def)))

func get_float(key: String, def := 0.0) -> float:
	return float(get_key(key, str(def)))

func reset_progress() -> void:
	data = {}
	var f := FileAccess.open(FILE, FileAccess.WRITE)
	f.store_string("")
	load_save()
