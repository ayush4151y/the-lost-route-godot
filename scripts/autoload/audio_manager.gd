extends Node

var streams := {}
var sfx_players := []
var music_vol := 1.0
var sfx_vol := 1.0
var muted := false

var ambience_players := {}

const MAP := {
	"step": "res://assets/audio/sfx/step-hop.mp3",
	"hint": "res://assets/audio/sfx/hint.mp3",
	"win": "res://assets/audio/sfx/win.mp3",
	"gameover": "res://assets/audio/sfx/gameover.mp3",
	"tnt-fuse": "res://assets/audio/sfx/tnt-fuse.mp3",
	"tnt-boom": "res://assets/audio/sfx/tnt-boom.mp3",
	"fire-warn": "res://assets/audio/sfx/fire-warn.mp3",
	"ice-slide": "res://assets/audio/sfx/ice-slide.mp3",
	"heart-pickup": "res://assets/audio/sfx/heart-pickup.mp3",
	"camera-rotate": "res://assets/audio/sfx/camera-rotate.mp3",
	"cube-rise": "res://assets/audio/sfx/cube-rise.mp3",
	"ui-click": "res://assets/audio/ui/ui-click.mp3",
	"ui-back": "res://assets/audio/ui/ui-back.mp3",
	"ui-pause": "res://assets/audio/ui/ui-pause.mp3",
	"ui-toggle": "res://assets/audio/ui/ui-toggle.mp3",
}
const AMBIENCE := {
	"ambience": "res://assets/audio/ambience/ambience-melody-loop.mp3",
	"ambience-island": "res://assets/audio/ambience/ambience-island-loop.mp3",
}

func _ready():
	music_vol = float(SaveData.get_value("audio_music", "1.0"))
	sfx_vol = float(SaveData.get_value("audio_sfx", "1.0"))
	muted = SaveData.get_value("audio_muted", "0") == "1"
	for key in AMBIENCE:
		ambience_players[key] = _make_loop(AMBIENCE[key])

func _load(path: String) -> AudioStream:
	if streams.has(path):
		return streams[path]
	var s = load(path)
	if s == null:
		return null
	streams[path] = s
	return s

func _make_loop(path: String) -> AudioStreamPlayer:
	var p = AudioStreamPlayer.new()
	var s = _load(path)
	if s != null and s is AudioStream:
		s.loop = true
		p.stream = s
	p.volume_db = _db(music_vol)
	p.bus = "Master"
	add_child(p)
	return p

func _db(v: float) -> float:
	return 20.0 * log(max(0.0001, v)) / log(10.0)

func play(id: String, group: String = "sfx", volume: float = 1.0):
	if muted:
		return
	var path = MAP.get(id, "")
	if path == "":
		return
	var s = _load(path)
	if s == null:
		return
	var p = AudioStreamPlayer.new()
	p.stream = s
	p.bus = "Master"
	var gv = sfx_vol if group != "music" else music_vol
	p.volume_db = _db(clamp(volume * gv, 0.0, 1.0)) if not muted else -80.0
	add_child(p)
	p.play()
	p.connect("finished", func(): p.queue_free())

func start_ambience():
	for key in ambience_players:
		var p = ambience_players[key]
		if p != null and p.stream != null and not p.playing:
			p.volume_db = _db(music_vol)
			p.play()

func stop_ambience():
	for key in ambience_players:
		var p = ambience_players[key]
		if p != null and p.playing:
			p.stop()

func pause_all():
	for key in ambience_players:
		var p = ambience_players[key]
		if p != null and p.playing:
			p.stream_paused = true

func resume_all():
	for key in ambience_players:
		var p = ambience_players[key]
		if p != null and p.stream != null:
			p.stream_paused = false

func set_muted(m: bool):
	muted = m
	SaveData.set_value("audio_muted", "1" if m else "0")
	if muted:
		stop_ambience()
	else:
		start_ambience()

func toggle_mute() -> bool:
	set_muted(not muted)
	return muted

func is_muted() -> bool:
	return muted

func set_music_volume(v: float):
	music_vol = clamp(v, 0.0, 1.0)
	SaveData.set_value("audio_music", str(music_vol))
	for key in ambience_players:
		var p = ambience_players[key]
		if p != null:
			p.volume_db = _db(music_vol)

func set_sfx_volume(v: float):
	sfx_vol = clamp(v, 0.0, 1.0)
	SaveData.set_value("audio_sfx", str(sfx_vol))
