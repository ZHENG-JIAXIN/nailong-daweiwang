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
var _bgm_kicked: bool = false     # 是否已在首个用户手势后解除静音（防重复处理）

const SR: int = 44100
const MAX_BGM_FILL: int = 4096  # 单次补填上限，避免单帧 CPU 尖峰（约 93ms @44.1k）
const BGM_VOLUME_DB: float = 0.0   # 正常音量（与原默认值一致，不改响度）
const MUTE_DB: float = -80.0       # 用户手势前的静音起步音量
# BGM 音源：用 preload 在导出时解析路径——Web 包里运行时 load() 常取不到资源，会静默回退到合成音；preload 最可靠。
# 注意用 var 而非 const：GDScript 不允许修改常量资源的属性（loop_mode / loop），var 可正常设置循环。
# 换歌时改这一行路径即可（或用 scripts/extract_bgm.py 生成同名 bgm.ogg 覆盖）。
var bgm_stream: AudioStream = preload("res://assets/audio/bgm.ogg")

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
		# 兼容两种音源：WAV 用 loop_mode，Ogg Vorbis 用 loop
		var wav := bgm_stream as AudioStreamWAV
		if wav != null:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		var ogg := bgm_stream as AudioStreamOggVorbis
		if ogg != null:
			ogg.loop = true
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
	# 已在用户手势后正常播放时不打断，避免进游戏时音乐从头重启。
	if _bgm_kicked and bgm_player.playing:
		bgm_player.volume_db = BGM_VOLUME_DB
		return
	# 浏览器在首次手势前挂起 AudioContext：先静音起播，让解码与上下文尽早就绪；
	# 首个手势只解除静音（不 stop/play），避免重启空白与从头开始。
	bgm_player.stop()
	if _bgm_kicked:
		bgm_player.volume_db = BGM_VOLUME_DB
	else:
		bgm_player.volume_db = MUTE_DB
	bgm_player.play()

func stop_bgm():
	bgm_on = false
	bgm_player.stop()

# 浏览器自动播放策略兜底：首个真实手势后立即解除静音（不重启播放，零空白）。
# 之后每次手势只检查播放器是否被挂起（切后台回来等），不重置播放位置。
# 对文件模式与合成兜底模式都生效。
func _input(event: InputEvent):
	if not bgm_on:
		return
	var gesture := false
	if event is InputEventMouseButton:
		gesture = (event as InputEventMouseButton).pressed
	elif event is InputEventKey:
		gesture = (event as InputEventKey).pressed
	elif event is InputEventScreenTouch:
		gesture = (event as InputEventScreenTouch).pressed
	elif event is InputEventScreenDrag:
		gesture = true
	if not gesture:
		return
	if not _bgm_kicked:
		_bgm_kicked = true
		bgm_player.volume_db = BGM_VOLUME_DB
	if not bgm_player.playing:
		bgm_player.play()
