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
var _bgm_kicked: bool = false     # 是否已在用户手势后强制重启过 BGM（防重复重启）

const SR: int = 44100
const MAX_BGM_FILL: int = 4096  # 单次补填上限，避免单帧 CPU 尖峰（约 93ms @44.1k）
# BGM 音源：用 preload 在导出时解析路径——Web 包里运行时 load() 常取不到资源，会静默回退到合成音；preload 最可靠。
# 注意用 var 而非 const：GDScript 不允许修改常量资源的属性（如 loop_mode），var 可正常设置循环。
var bgm_stream: AudioStream = preload("res://assets/audio/bgm.wav")

func _ready():
	# SFX：程序化（吃鱼/死亡短音，开销极低，保留原逻辑）
	gen_sfx = AudioStreamGenerator.new()
	gen_sfx.mix_rate = float(SR)
	gen_sfx.buffer_length = 0.15
	sfx_player = AudioStreamPlayer.new()
	sfx_player.stream = gen_sfx
	add_child(sfx_player)
	sfx_player.play()

	# BGM：播放导入的音频文件（preload 已在导出时解析，Web 下可靠）；若资源缺失则回退程序化合成
	bgm_player = AudioStreamPlayer.new()
	add_child(bgm_player)
	if bgm_stream != null:
		bgm_file_mode = true
		bgm_player.stream = bgm_stream
		var wav := bgm_stream as AudioStreamWAV
		if wav != null:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	else:
		# 兜底：实时合成（缓冲加长，单线程下留足余量）
		gen_bgm = AudioStreamGenerator.new()
		gen_bgm.mix_rate = float(SR)
		gen_bgm.buffer_length = 1.0
		bgm_player.stream = gen_bgm

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
	# 强制从头重启：确保在 AudioContext 已恢复（有用户手势）后真正出声。
	# 浏览器策略下，早先在挂起上下文里的 play() 会静音但把 playing 置真，必须 stop 后重放才能出声。
	bgm_player.stop()
	bgm_player.play()

func stop_bgm():
	bgm_on = false
	bgm_player.stop()

# 浏览器自动播放策略兜底：首个「真实手势」（鼠标按下/按键/触摸）后，再强制重启一次 BGM。
# 只在第一次触发，避免每个输入都重头播放。对文件模式与合成兜底模式都生效。
func _input(event: InputEvent):
	if not bgm_on or _bgm_kicked:
		return
	var gesture := false
	if event is InputEventMouseButton:
		gesture = (event as InputEventMouseButton).pressed
	elif event is InputEventKey:
		gesture = (event as InputEventKey).pressed
	elif event is InputEventScreenTouch:
		gesture = (event as InputEventScreenTouch).pressed
	if gesture:
		_bgm_kicked = true
		bgm_player.stop()
		bgm_player.play()
