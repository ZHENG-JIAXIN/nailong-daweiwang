extends Node
class_name AudioPlayer
# AudioPlayer —— 音频系统：
#   · BGM 优先播放音频文件（res://assets/audio/bgm.{ogg,mp3,wav}），由音频后端解码，不占游戏主线程 → 根除单线程 Web 卡顿；
#     找不到文件时自动回退到程序化合成（AudioStreamGenerator），保证游戏永不因缺文件而崩。
#   · SFX（吃鱼/死亡）保持轻量程序化合成，开销极低。
# 起草：engineering-lead 方法论（主理人代笔）。路径 res://audio_player.gd

var sfx_player: AudioStreamPlayer
var bgm_player: AudioStreamPlayer
var gen_sfx: AudioStreamGenerator
var gen_bgm: AudioStreamGenerator
var bgm_phase: int = 0
var bgm_on: bool = false
var bgm_file_mode: bool = false  # true=BGM 走文件播放；false=回退程序化合成

const SR: int = 44100
const MAX_BGM_FILL: int = 4096  # 单次补填上限，避免单帧 CPU 尖峰（约 93ms @44.1k）

func _ready():
	# SFX：程序化（吃鱼/死亡短音，开销极低，保留原逻辑）
	gen_sfx = AudioStreamGenerator.new()
	gen_sfx.mix_rate = float(SR)
	gen_sfx.buffer_length = 0.15
	sfx_player = AudioStreamPlayer.new()
	sfx_player.stream = gen_sfx
	add_child(sfx_player)
	sfx_player.play()

	# BGM：先尝试加载音频文件；失败则回退程序化合成
	bgm_player = AudioStreamPlayer.new()
	add_child(bgm_player)
	var bgm_stream: AudioStream = _load_bgm_file()
	if bgm_stream != null:
		bgm_file_mode = true
		bgm_player.stream = bgm_stream
		# 循环播放：不同格式循环属性不同，分别处理
		if bgm_stream is AudioStreamOggVorbis or bgm_stream is AudioStreamMP3:
			bgm_stream.loop = true
		elif bgm_stream is AudioStreamWAV:
			bgm_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	else:
		# 回退：实时合成（缓冲加长，单线程下留足余量）
		gen_bgm = AudioStreamGenerator.new()
		gen_bgm.mix_rate = float(SR)
		gen_bgm.buffer_length = 1.0
		bgm_player.stream = gen_bgm

# 依次尝试常见格式；把音轨丢进 res://assets/audio/bgm.{ogg,mp3,wav} 即生效
func _load_bgm_file() -> AudioStream:
	for ext: String in ["ogg", "mp3", "wav"]:
		var path := "res://assets/audio/bgm." + ext
		if ResourceLoader.exists(path):
			var res := load(path)
			if res is AudioStream:
				return res
	return null

func _process(_delta: float):
	# 仅回退合成模式需主线程补填；文件模式完全由音频后端解码，此处空转
	if bgm_on and not bgm_file_mode:
		var pb := bgm_player.get_stream_playback() as AudioStreamGeneratorPlayback
		if pb != null:
			var avail: int = pb.get_frames_available()
			if avail > 0:
				var n: int = mini(avail, MAX_BGM_FILL)
				var buf := PackedVector2Array()
				buf.resize(n)
				for i in n:
					var t: float = float(bgm_phase) / float(SR)
					var note: float = bgm_note(t)
					var s: float = sin(t * note * TAU) * 0.16
					s += sin(t * (note * 0.5) * TAU) * 0.07
					buf[i] = Vector2(s, s)
					bgm_phase += 1
				pb.push_buffer(buf)

# 8 秒循环的五声音阶分解和弦（舒缓，仅回退合成模式使用）
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
	# 文件模式：若尚未播放则开始（循环已在加载时设置）；合成模式：开启主线程补填
	if not bgm_player.playing:
		bgm_player.play()

func stop_bgm():
	bgm_on = false
	bgm_player.stop()
