extends Node
class_name AudioPlayer
# AudioPlayer —— 零素材程序化音频：吃鱼/死亡音效 + 循环 BGM（AudioStreamGenerator）
# 起草：engineering-lead 方法论（主理人代笔）。路径 res://audio_player.gd

var sfx_player: AudioStreamPlayer
var bgm_player: AudioStreamPlayer
var gen_sfx: AudioStreamGenerator
var gen_bgm: AudioStreamGenerator
var bgm_phase: int = 0
var bgm_on: bool = false

const SR: int = 44100

func _ready():
	gen_sfx = AudioStreamGenerator.new()
	gen_sfx.mix_rate = float(SR)
	gen_sfx.buffer_length = 0.15
	sfx_player = AudioStreamPlayer.new()
	sfx_player.stream = gen_sfx
	add_child(sfx_player)
	sfx_player.play()

	gen_bgm = AudioStreamGenerator.new()
	gen_bgm.mix_rate = float(SR)
	gen_bgm.buffer_length = 0.25
	bgm_player = AudioStreamPlayer.new()
	bgm_player.stream = gen_bgm
	add_child(bgm_player)
	bgm_player.play()

func _process(_delta: float):
	if bgm_on:
		var pb := bgm_player.get_stream_playback() as AudioStreamGeneratorPlayback
		if pb != null:
			var avail: int = pb.get_frames_available()
			if avail > 2048:
				var buf := PackedVector2Array()
				buf.resize(avail)
				for i in avail:
					var t: float = float(bgm_phase) / float(SR)
					var note: float = bgm_note(t)
					var s: float = sin(t * note * TAU) * 0.16
					s += sin(t * (note * 0.5) * TAU) * 0.07
					buf[i] = Vector2(s, s)
					bgm_phase += 1
				pb.push_buffer(buf)

# 8 秒循环的五声音阶分解和弦（舒缓）
func bgm_note(t: float) -> float:
	var scale := [261.63, 293.66, 329.63, 392.0, 440.0]  # C D E G A
	var beat: float = 0.5
	var idx: int = int(floor(t / beat)) % scale.size()
	return scale[idx]

func play_eat():
	var pb := sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb == null:
		return
	var dur: float = 0.12
	var frames: int = int(dur * float(SR))
	var buf := PackedVector2Array()
	buf.resize(frames)
	for i in frames:
		var t: float = float(i) / float(SR)
		var env: float = clamp(1.0 - (t / dur), 0.0, 1.0)
		var f: float = 440.0 + 600.0 * (t / dur)
		var s: float = sin(t * f * TAU) * env * 0.25
		buf[i] = Vector2(s, s)
	pb.push_buffer(buf)

func play_death():
	var pb := sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb == null:
		return
	var dur: float = 0.5
	var frames: int = int(dur * float(SR))
	var buf := PackedVector2Array()
	buf.resize(frames)
	for i in frames:
		var t: float = float(i) / float(SR)
		var env: float = clamp(1.0 - (t / dur), 0.0, 1.0)
		var f: float = 320.0 - 240.0 * (t / dur)
		var s: float = sin(t * f * TAU) * env * 0.3
		buf[i] = Vector2(s, s)
	pb.push_buffer(buf)

func start_bgm():
	bgm_on = true

func stop_bgm():
	bgm_on = false
