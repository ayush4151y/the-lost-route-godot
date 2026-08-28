extends Node

var player: AudioStreamPlayer
var ambient_player: AudioStreamPlayer
var muted := false
var master_volume := 1.0

func _ready():
	player = AudioStreamPlayer.new()
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = 44100
	gen.buffer_length = 0.15
	player.stream = gen
	add_child(player)
	player.play()

	ambient_player = AudioStreamPlayer.new()
	var gen2 = AudioStreamGenerator.new()
	gen2.mix_rate = 44100
	gen2.buffer_length = 0.5
	ambient_player.stream = gen2
	add_child(ambient_player)
	ambient_player.play()
	_ambient_buf = _make_pad(2.0)
	_ambient_pos = 0

var _ambient_buf: PackedVector2Array
var _ambient_pos := 0

func set_muted(m: bool):
	muted = m

func is_muted() -> bool:
	return muted

func _make_pad(dur: float) -> PackedVector2Array:
	var n = int(dur * 44100)
	var out = PackedVector2Array()
	out.resize(n)
	for i in range(n):
		var t = float(i) / 44100.0
		var s = 0.05 * sin(2.0 * PI * 110.0 * t)
		s += 0.04 * sin(2.0 * PI * 164.81 * t)
		s += 0.03 * sin(2.0 * PI * 220.0 * t)
		s *= 0.6 + 0.4 * sin(2.0 * PI * 0.1 * t)
		out[i] = Vector2(s, s)
	return out

func _process(_dt):
	if not muted and ambient_player.playing:
		var pb = ambient_player.get_stream_playback()
		var avail = pb.get_frames_available()
		var written = 0
		while written < avail and written < 2000:
			pb.push_frame(_ambient_buf[_ambient_pos])
			_ambient_pos = (_ambient_pos + 1) % _ambient_buf.size()
			written += 1

func _frames(dur: float, vol: float, fn: Callable) -> PackedVector2Array:
	var n = int(dur * 44100)
	var out = PackedVector2Array()
	out.resize(n)
	for i in range(n):
		var t = float(i) / 44100.0
		var s = fn.call(t, i) * vol
		s = clamp(s, -1.0, 1.0)
		out[i] = Vector2(s, s)
	return out

func _wave(type: String, t: float, freq: float) -> float:
	var ph = 2.0 * PI * freq * t
	match type:
		"sine": return sin(ph)
		"square": return 1.0 if sin(ph) >= 0 else -1.0
		"tri": return asin(sin(ph)) * 2.0 / PI
		"saw": return 2.0 * (freq * t - floor(0.5 + freq * t))
		_:
			return sin(ph)

func play(id: String, group: String = "sfx", volume: float = 1.0):
	if muted:
		return
	var v = volume * master_volume
	var frames: PackedVector2Array
	match id:
		"ui-click", "ui-back", "ui-toggle":
			frames = _frames(0.06, v * 0.5, func(t, i): return _wave("square", t, 440.0 + t * 200.0))
		"ui-pause":
			frames = _frames(0.12, v * 0.5, func(t, i): return _wave("sine", t, 300.0 - t * 100.0))
		"step-hop", "cube-rise":
			frames = _frames(0.08, v * 0.4, func(t, i): return _wave("sine", t, 300.0 + t * 400.0))
		"camera-rotate":
			frames = _frames(0.1, v * 0.4, func(t, i): return _wave("tri", t, 520.0))
		"hint":
			frames = _frames(0.18, v * 0.45, func(t, i): return _wave("sine", t, 600.0 + sin(t * 20.0) * 80.0))
		"ice-slide":
			frames = _frames(0.4, v * 0.4, func(t, i): return _wave("saw", t, 700.0 - t * 300.0) * (1.0 - t))
		"fire-warn":
			frames = _frames(0.15, v * 0.4, func(t, i): return _wave("square", t, 900.0) * (0.5 + 0.5 * sin(t * 40.0)))
		"heart-pickup":
			frames = _frames(0.3, v * 0.5, func(t, i): return _wave("sine", t, 500.0 + t * 500.0))
		"tnt-fuse":
			frames = _frames(0.3, v * 0.4, func(t, i): return _wave("square", t, 200.0 + t * 100.0))
		"tnt-boom":
			frames = _frames(0.5, v * 0.7, func(t, i): return (_wave("square", t * 30.0, 60.0)) * (1.0 - t))
		"win":
			frames = _frames(0.5, v * 0.5, func(t, i):
				var f = 523.25 if t < 0.16 else (659.25 if t < 0.33 else 783.99)
				return _wave("sine", t, f))
		"gameover":
			frames = _frames(0.6, v * 0.5, func(t, i): return _wave("saw", t, 400.0 - t * 250.0))
		_:
			frames = _frames(0.06, v * 0.4, func(t, i): return _wave("sine", t, 440.0))
	if frames == null or frames.is_empty():
		return
	var pb = player.get_stream_playback()
	var i = 0
	while i < frames.size():
		var avail = pb.get_frames_available()
		if avail <= 0:
			break
		var take = min(avail, frames.size() - i)
		for k in range(take):
			pb.push_frame(frames[i + k])
		i += take
		await get_tree().process_frame
