extends Node
# AudioManager - procedural SFX via generated waveforms.
# Keep it self-contained (no binary assets) so the project is text-only
# and portable. Each SFX is a distinct pitched blip/whoosh created at runtime.

const SAMPLE_RATE := 22050

# sfx definitions: [freq_start, freq_end, duration, volume]
const SFX := {
	"ui_click": [880, 880, 0.06, 0.5],
	"ui_back": [660, 440, 0.10, 0.5],
	"ui_pause": [523, 392, 0.12, 0.5],
	"ui_toggle": [700, 900, 0.08, 0.4],
	"cube_rise": [300, 600, 0.10, 0.35],
	"heart_pickup": [660, 1320, 0.15, 0.6],
	"hint": [440, 880, 0.12, 0.5],
	"win": [523, 784, 0.35, 0.6],
	"gameover": [392, 196, 0.6, 0.6],
	"camera_rotate": [500, 300, 0.10, 0.4],
	"ice_slide": [880, 440, 0.2, 0.4],
	"fire_warn": [880, 880, 0.07, 0.4],
	"tnt_fuse": [200, 400, 0.15, 0.4],
	"tnt_boom": [120, 60, 0.5, 0.7],
	"hop": [440, 660, 0.06, 0.3],
}

var muted := false
var sfx_volume := 0.8

func _ready() -> void:
	AudioServer.set_bus_mute(0, false)
	AudioServer.set_bus_volume_db(0, linear_to_db(0.8))
	muted = SaveData.get_key("muted", "0") == "1"
	sfx_volume = SaveData.get_float("vol_sfx", 0.8)

func set_muted(m: bool) -> void:
	muted = m
	AudioServer.set_bus_mute(0, muted)
	SaveData.set_key("muted", "1" if m else "0")

func set_sfx_volume(v: float) -> void:
	sfx_volume = clamp(v, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(sfx_volume) if not muted else -80)
	SaveData.set_key("vol_sfx", str(sfx_volume))
func play(sfx: String) -> void:
	if muted or not SFX.has(sfx):
		return
	var p := _build_stream(SFX[sfx])
	if p == null:
		return
	add_child(p)
	p.finished.connect(p.queue_free)


func _build_stream(def: Array) -> AudioStreamPlayer:
	var freq0: float = def[0]
	var freq1: float = def[1]
	var dur: float = def[2]
	var vol: float = def[3]

	var gen := AudioStreamGenerator.new()
	gen.mix_rate = SAMPLE_RATE
	gen.buffer_length = dur + 0.1
	var player := AudioStreamPlayer.new()
	player.stream = gen
	player.volume_db = linear_to_db(sfx_volume * vol)
	player.bus = "Master"
	if not is_inside_tree():
		return null
	player.play()
	var pb := player.get_stream_playback()
	if pb == null:
		return null
	_fill_buffer(pb, freq0, freq1, dur, sfx_volume * vol)
	return player

func _fill_buffer(pb: AudioStreamGeneratorPlayback, freq0: float, freq1: float, dur: float, vol: float) -> void:
	var frames := int(SAMPLE_RATE * dur)
	var samples := PackedVector2Array()
	samples.resize(frames)
	for i in frames:
		var t: float = float(i) / SAMPLE_RATE
		var k: float = float(i) / maxf(frames, 1.0)
		var f: float = lerpf(freq0, freq1, k)
		var phase: float = fmod(float(i) * f / SAMPLE_RATE, 1.0)
		var env: float = 1.0 - k
		# simple square-ish tone
		var v: float = (1.0 if phase < 0.5 else -1.0) * env * vol * 0.5
		var sample := Vector2(v, v)
		samples[i] = sample
	pb.push_buffer(samples)
