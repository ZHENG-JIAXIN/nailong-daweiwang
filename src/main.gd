extends Node2D
# Main —— 核心循环编排：状态机(菜单/游戏/结算)、生成鱼群、UI、经济与签到接线
# 增强：3 难度、3 关卡(主题色+通关目标)、3 皮肤、捕食者 AI、程序化音频、过关横幅
# 起草：engineering-lead 方法论（主理人代笔）。路径 res://main.gd

const PlayerScript := preload("res://player.gd")
const FishScript := preload("res://fish.gd")

# 难度：pred 捕食者概率 / psmin-psmax 捕食者基础速度 / chase 追猎倍率 /
# crange 追猎范围 / spawn 生成间隔 / fee 入场费 / fmin-fmax 食物速度
const DIFFS: Array[Dictionary] = [
	{"name":"简单","pred":0.30,"psmin":90.0,"psmax":130.0,"chase":1.0,"crange":300.0,"spawn":0.55,"fee":20,"fmin":40.0,"fmax":95.0},
	{"name":"普通","pred":0.45,"psmin":130.0,"psmax":180.0,"chase":1.12,"crange":430.0,"spawn":0.45,"fee":30,"fmin":50.0,"fmax":120.0},
	{"name":"困难","pred":0.60,"psmin":170.0,"psmax":230.0,"chase":1.30,"crange":560.0,"spawn":0.35,"fee":40,"fmin":60.0,"fmax":150.0},
]
# 关卡：主题背景色 + 通关分数目标
const LEVELS: Array[Dictionary] = [
	{"name":"浅海乐园","bg":Color(0.74,0.91,1.0),"target":300},
	{"name":"珊瑚浅滩","bg":Color(1.0,0.86,0.80),"target":800},
	{"name":"深渊秘境","bg":Color(0.12,0.22,0.42),"target":1600},
]
const CHARACTERS: Array[String] = ["奶龙","噜噜","奶娃"]
const WEAPON_SHORT: Array[String] = ["M4A1", "巴雷特", "军刀", "战斧"]

var player: Player
var fish_layer: Node2D
var ui: Control
var bg: ColorRect
var hud: VBoxContainer
var spawn_timer: Timer

var state := "login"   # login | menu | playing | levelclear | gameover
var score := 0
var selected_diff: int = 1
var level_index: int = 1        # 第几关，无上限
var current_level: int = 0      # 主题索引 = (level_index-1) % LEVELS.size()
var level_score: int = 0        # 本关得分（过关判定用）
var level_kills: int = 0        # 本关击杀
var level_target: int = 300     # 本关目标
var win_mode: bool = false
var kill_count: int = 0
var boss_threshold_score: int = 800
var boss_threshold_kills: int = 25
var current_boss: Fish = null
var audio: AudioPlayer

# UI 引用
var lbl_size: Label
var lbl_score: Label
var lbl_coins: Label
var lbl_signin: Label
var lbl_level: Label
var lbl_best: Label
var lbl_user: Label
var lbl_hp: Label
var lbl_weapon: Label
var lbl_ammo: Label
var boss_bar: Control
var boss_bar_bg: ColorRect
var boss_bar_fill: ColorRect
var boss_bar_label: Label
var login_center: CenterContainer
var username_input: LineEdit
var login_feedback: Label
var menu_center: CenterContainer
var over_center: CenterContainer
var lbl_title: Label
var btn_start: Button
var lbl_over: Label
var btn_again: Button
var btn_quiz: Button
var quiz_panel: CenterContainer
var quiz_q: Label
var quiz_feedback: Label
var quiz_opts: Array[Button] = []
var current_q: Dictionary
var hint_label: Label
var debug_label: Label
var diff_btns: Array[Button] = []
var char_btns: Array[Button] = []
var level_banner: CenterContainer
var lbl_level_banner: Label
var level_banner_timer: Timer

# 武器快捷栏与过关结算面板
var weapon_bar: HBoxContainer
var weapon_btns: Array[Button] = []
var level_clear_panel: CenterContainer
var lbl_clear_title: Label
var lbl_clear_stats: Label
var lbl_clear_grade: Label
var lbl_clear_reward: Label
var btn_next_level: Button

# 双浮动摇杆：左右半屏各按 InputEventScreenTouch.index 追踪一根手指
# BASE_R 需与 joystick_overlay.gd 的 BASE_R 保持一致
const JOY_BASE_R: float = 104.0
const JOY_DEADZONE: float = 8.0

var joy: JoystickOverlay
var touch_seen: bool = false
var left_idx: int = -1
var left_origin: Vector2 = Vector2.ZERO
var left_current: Vector2 = Vector2.ZERO
var right_idx: int = -1
var right_origin: Vector2 = Vector2.ZERO
var right_current: Vector2 = Vector2.ZERO

func _ready():
	# 强制全局字体：直接 preload 静态 TTF(simhei，已烘焙 556 中文字形)并代码建主题。
	# 同时挂到根窗口与 UI 控件，双保险确保 UI 控件继承到中文字体。
	var cjk_font: FontFile = preload("res://assets/fonts/simhei.ttf")
	var ui_theme := Theme.new()
	ui_theme.default_font = cjk_font
	get_tree().root.theme = ui_theme
	bg = ColorRect.new()
	bg.color = Color(0.74, 0.91, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.z_index = -1
	add_child(bg)
	fish_layer = Node2D.new()
	add_child(fish_layer)
	audio = AudioPlayer.new()
	add_child(audio)
	audio.start_bgm()
	build_ui()
	ui.theme = ui_theme   # 双保险：UI 控件(Control)直接挂主题，确保继承到 simhei 中文字体
	show_login()
	get_viewport().size_changed.connect(_on_size_changed)
	_resize()

func _resize():
	var sz := get_viewport_rect().size
	if bg:
		bg.position = Vector2.ZERO
		bg.size = sz
	if ui:
		ui.position = Vector2.ZERO
		ui.size = sz

func _on_size_changed():
	_resize()

func cur_fee() -> int:
	return int(DIFFS[selected_diff]["fee"])

func build_ui():
	ui = Control.new()
	ui.position = Vector2.ZERO
	ui.size = get_viewport_rect().size
	ui.set_anchors_preset(Control.PRESET_TOP_LEFT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)

	hud = VBoxContainer.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	hud.position = Vector2(14, 14)
	ui.add_child(hud)

	lbl_size = mk_label("尺寸: 20", 20, Color(0.1, 0.2, 0.35))
	lbl_score = mk_label("分数: 0", 20, Color(0.1, 0.2, 0.35))
	lbl_coins = mk_label("奶龙币: 0", 20, Color(0.1, 0.2, 0.35))
	lbl_level = mk_label("关卡 1/3 浅海乐园", 20, Color(0.1, 0.2, 0.35))
	hud.add_child(lbl_size)
	hud.add_child(lbl_score)
	hud.add_child(lbl_coins)
	hud.add_child(lbl_level)
	lbl_hp = mk_label("生命: 100/100", 20, Color(0.8, 0.12, 0.12))
	lbl_weapon = mk_label("武器: M4A1 突击步枪", 20, Color(0.1, 0.2, 0.35))
	lbl_ammo = mk_label("弹药: 25/25", 20, Color(0.1, 0.2, 0.35))
	hud.add_child(lbl_hp)
	hud.add_child(lbl_weapon)
	hud.add_child(lbl_ammo)

	# 菜单
	menu_center = CenterContainer.new()
	menu_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(menu_center)
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 18)
	menu_center.add_child(mv)
	lbl_title = mk_label("奶龙大胃王", 52, Color.WHITE)
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(lbl_title)
	btn_start = mk_button("开始游戏 (消耗 %d 奶龙币)" % cur_fee())
	mv.add_child(btn_start)
	btn_start.pressed.connect(_on_start_pressed)
	lbl_user = mk_label("", 18, Color(1.0, 1.0, 1.0, 0.85))
	lbl_user.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(lbl_user)
	lbl_signin = mk_label("", 22, Color(1.0, 0.85, 0.3))
	lbl_signin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(lbl_signin)
	btn_quiz = mk_button("答题赚奶龙币")
	btn_quiz.pressed.connect(_on_quiz_open)
	mv.add_child(btn_quiz)
	lbl_best = mk_label("", 20, Color(1.0, 0.85, 0.3))
	lbl_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(lbl_best)

	# 难度选择
	var diff_lbl := mk_label("难度（影响入场费与敌人强度）", 20, Color(1.0, 1.0, 1.0, 0.9))
	diff_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(diff_lbl)
	var dh := HBoxContainer.new()
	dh.alignment = BoxContainer.ALIGNMENT_CENTER
	mv.add_child(dh)
	for i in range(DIFFS.size()):
		var b := mk_button(str(DIFFS[i]["name"]), 180, 64)
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.pressed.connect(pick_diff.bind(i))
		dh.add_child(b)
		diff_btns.append(b)

	# 角色选择（噜噜 / 奶龙 / 奶娃）
	var char_lbl := mk_label("角色（噜噜 / 奶龙 / 奶娃）", 20, Color(1.0, 1.0, 1.0, 0.9))
	char_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(char_lbl)
	var ch := HBoxContainer.new()
	ch.alignment = BoxContainer.ALIGNMENT_CENTER
	mv.add_child(ch)
	for i in range(CHARACTERS.size()):
		var b := mk_button(CHARACTERS[i], 180, 64)
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.pressed.connect(pick_char.bind(i))
		ch.add_child(b)
		char_btns.append(b)

	# 退出登录
	var btn_logout := mk_button("退出登录", 200, 60)
	btn_logout.pressed.connect(_on_logout_pressed)
	mv.add_child(btn_logout)

	refresh_selectors()

	# 结算
	over_center = CenterContainer.new()
	over_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	over_center.visible = false
	ui.add_child(over_center)
	var ov := VBoxContainer.new()
	ov.add_theme_constant_override("separation", 24)
	over_center.add_child(ov)
	lbl_over = mk_label("", 40, Color.WHITE)
	lbl_over.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ov.add_child(lbl_over)
	btn_again = mk_button("再来一局")
	ov.add_child(btn_again)
	btn_again.pressed.connect(_on_again_pressed)

	# 答题赚币面板
	quiz_panel = CenterContainer.new()
	quiz_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	quiz_panel.visible = false
	quiz_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(quiz_panel)
	var qbg := ColorRect.new()
	qbg.color = Color(0, 0, 0, 0.72)
	qbg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	qbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quiz_panel.add_child(qbg)
	var qv := VBoxContainer.new()
	qv.add_theme_constant_override("separation", 16)
	qv.custom_minimum_size = Vector2(640, 760)
	quiz_panel.add_child(qv)
	quiz_q = mk_label("", 26, Color.WHITE)
	quiz_q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qv.add_child(quiz_q)
	for i in range(4):
		var ob := mk_button("", 560, 64)
		ob.mouse_filter = Control.MOUSE_FILTER_STOP
		ob.connect("pressed", _on_quiz_option_pressed.bind(i))
		qv.add_child(ob)
		quiz_opts.append(ob)
	quiz_feedback = mk_label("", 22, Color(1.0, 0.9, 0.3))
	quiz_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qv.add_child(quiz_feedback)
	var btn_qclose := mk_button("返回", 200, 64)
	btn_qclose.pressed.connect(_on_quiz_close)
	qv.add_child(btn_qclose)

	# 武器快捷栏（HUD 下方一行，PC 可点 / 移动端可触摸，1-4 键保留）
	weapon_bar = HBoxContainer.new()
	weapon_bar.position = Vector2(28.0, 214.0)
	weapon_bar.custom_minimum_size = Vector2(664.0, 56.0)
	weapon_bar.add_theme_constant_override("separation", 8)
	weapon_bar.visible = false
	ui.add_child(weapon_bar)
	for i in range(WEAPON_SHORT.size()):
		var wb: Button = mk_button(WEAPON_SHORT[i], 160, 56)
		wb.mouse_filter = Control.MOUSE_FILTER_STOP
		wb.pressed.connect(_on_weapon_pressed.bind(i))
		weapon_bar.add_child(wb)
		weapon_btns.append(wb)

	# 过关结算面板（无尽关卡：达标 -> 结算 -> 主动继续）
	level_clear_panel = CenterContainer.new()
	level_clear_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	level_clear_panel.visible = false
	level_clear_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(level_clear_panel)
	var cp_bg := ColorRect.new()
	cp_bg.color = Color(0, 0, 0, 0.72)
	cp_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_clear_panel.add_child(cp_bg)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 18)
	cv.custom_minimum_size = Vector2(640, 520)
	level_clear_panel.add_child(cv)
	lbl_clear_title = mk_label("", 46, Color(1.0, 0.92, 0.4))
	lbl_clear_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(lbl_clear_title)
	lbl_clear_stats = mk_label("", 26, Color.WHITE)
	lbl_clear_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(lbl_clear_stats)
	lbl_clear_grade = mk_label("", 40, Color(0.6, 0.95, 1.0))
	lbl_clear_grade.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(lbl_clear_grade)
	lbl_clear_reward = mk_label("", 26, Color(1.0, 0.85, 0.3))
	lbl_clear_reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(lbl_clear_reward)
	btn_next_level = mk_button("继续下一关 →", 420, 76)
	btn_next_level.pressed.connect(_on_next_level_pressed)
	cv.add_child(btn_next_level)

	# 过关横幅
	level_banner = CenterContainer.new()
	level_banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	level_banner.visible = false
	level_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(level_banner)
	var lb_bg := ColorRect.new()
	lb_bg.color = Color(0, 0, 0, 0.5)
	lb_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lb_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_banner.add_child(lb_bg)
	lbl_level_banner = mk_label("", 44, Color(1.0, 0.92, 0.4))
	lbl_level_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_banner.add_child(lbl_level_banner)
	level_banner_timer = Timer.new()
	level_banner_timer.wait_time = 1.6
	level_banner_timer.one_shot = true
	level_banner_timer.timeout.connect(_on_banner_hide)
	add_child(level_banner_timer)

	# BOSS 血条（顶部居中，默认隐藏）
	boss_bar = Control.new()
	boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_bar.visible = false
	ui.add_child(boss_bar)
	var bw: float = 420.0
	var bx: float = get_viewport_rect().size.x * 0.5 - bw * 0.5
	var by: float = 84.0
	boss_bar_bg = ColorRect.new()
	boss_bar_bg.color = Color(0.0, 0.0, 0.0, 0.55)
	boss_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_bar_bg.position = Vector2(bx, by)
	boss_bar_bg.size = Vector2(bw, 16.0)
	boss_bar.add_child(boss_bar_bg)
	boss_bar_fill = ColorRect.new()
	boss_bar_fill.color = Color(1.0, 0.25, 0.25)
	boss_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_bar_fill.position = Vector2(bx, by)
	boss_bar_fill.size = Vector2(bw, 16.0)
	boss_bar.add_child(boss_bar_fill)
	boss_bar_label = mk_label("", 20, Color(1.0, 0.92, 0.55))
	boss_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_bar_label.position = Vector2(bx, by - 28.0)
	boss_bar_label.size = Vector2(bw, 26.0)
	boss_bar.add_child(boss_bar_label)

	# 游戏内提示 & 调试标签
	hint_label = mk_label("WASD/方向键移动 · 鼠标瞄准 · 左键开火 · 下方按钮或 1-4 切武器 · R 换弹｜手机：左右半屏按住出摇杆，左移动 / 右瞄准开火", 18, Color(0.1, 0.2, 0.35))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint_label.offset_top = -56
	hint_label.visible = false
	ui.add_child(hint_label)
	debug_label = mk_label("", 16, Color(1.0, 1.0, 1.0, 0.7))
	debug_label.position = Vector2(10, 100)
	debug_label.visible = false
	ui.add_child(debug_label)

	# 登录界面
	login_center = CenterContainer.new()
	login_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	login_center.visible = false
	ui.add_child(login_center)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 20)
	login_center.add_child(lv)
	var ltitle := mk_label("奶龙大胃王", 52, Color.WHITE)
	ltitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv.add_child(ltitle)
	var lsub := mk_label("非商用 · 同人作品（IP 仅供学习交流）", 18, Color(1.0, 0.9, 0.6))
	lsub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv.add_child(lsub)
	# 浏览器自动播放策略：无手势时音频静音，提示用户第一次交互即可出声
	var laudio := mk_label("（点击或按键后音乐开始播放）", 16, Color(1.0, 0.9, 0.6))
	laudio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv.add_child(laudio)
	username_input = LineEdit.new()
	username_input.placeholder_text = "输入用户名"
	username_input.custom_minimum_size = Vector2(420.0, 64.0)
	lv.add_child(username_input)
	var login_row := HBoxContainer.new()
	login_row.alignment = BoxContainer.ALIGNMENT_CENTER
	lv.add_child(login_row)
	var btn_login := mk_button("登录", 200, 64)
	btn_login.pressed.connect(_on_login_pressed)
	login_row.add_child(btn_login)
	var btn_reg := mk_button("注册并进入", 200, 64)
	btn_reg.pressed.connect(_on_register_pressed)
	login_row.add_child(btn_reg)
	login_feedback = mk_label("", 18, Color(1.0, 0.5, 0.5))
	login_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv.add_child(login_feedback)
	if GameManager.users.size() > 0:
		var exist_lbl := mk_label("已有用户（点击直接登录）", 16, Color(1.0, 1.0, 1.0, 0.7))
		exist_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lv.add_child(exist_lbl)
		var ev := VBoxContainer.new()
		lv.add_child(ev)
		for u in GameManager.users:
			var ub := mk_button(u, 420, 56)
			ub.pressed.connect(_on_existing_user_pressed.bind(u))
			ev.add_child(ub)

	spawn_timer = Timer.new()
	spawn_timer.wait_time = 0.55
	spawn_timer.timeout.connect(spawn_fish)
	add_child(spawn_timer)
	build_joysticks()

# 双浮动摇杆：左右半屏各追踪一根手指，按下点即摇杆原点（跟随手指，不固定位置）。
# 方向来自「手指相对按下点的偏移向量」，与角色位置无关 → 瞄准真 360°。
func build_joysticks():
	joy = JoystickOverlay.new()
	# 显式锚点覆盖整个 ui，避免 preset 在未入树(size=0)时算出错误 offsets
	joy.anchor_left = 0.0
	joy.anchor_top = 0.0
	joy.anchor_right = 1.0
	joy.anchor_bottom = 1.0
	joy.offset_left = 0.0
	joy.offset_top = 0.0
	joy.offset_right = 0.0
	joy.offset_bottom = 0.0
	joy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joy.visible = false
	ui.add_child(joy)

func _reset_joysticks(show_overlay: bool):
	left_idx = -1
	left_origin = Vector2.ZERO
	left_current = Vector2.ZERO
	right_idx = -1
	right_origin = Vector2.ZERO
	right_current = Vector2.ZERO
	if joy != null:
		joy.visible = show_overlay
	_sync_joysticks()

func _joy_offset(origin: Vector2, current: Vector2) -> Vector2:
	var d: Vector2 = current - origin
	if d.length() > JOY_BASE_R:
		d = d.normalized() * JOY_BASE_R
	return d

func _sync_joysticks():
	var ld: Vector2 = _joy_offset(left_origin, left_current)
	var rd: Vector2 = _joy_offset(right_origin, right_current)
	if player != null and is_instance_valid(player):
		# 左摇杆：偏移比例驱动移动，轻推慢走、推到底全速（全向）
		if ld.length() < JOY_DEADZONE:
			player.pad_dir = Vector2.ZERO
		else:
			player.pad_dir = ld / JOY_BASE_R
		# 右摇杆：偏移方向即瞄准方向，与角色坐标无关 → 真 360°
		if right_idx != -1:
			player.touch_aim_active = true
			if rd.length() >= JOY_DEADZONE:
				player.touch_aim_dir = (rd / JOY_BASE_R).normalized()
		player.touch_firing = (right_idx != -1)
		# 触摸模式下由 touch_firing 独占，清掉鼠标模拟事件的残留开火
		player.firing = false
	if joy != null:
		joy.set_state(
			left_idx != -1, left_origin, left_origin + ld,
			right_idx != -1, right_origin, right_origin + rd
		)

func _handle_touch(event: InputEvent):
	touch_seen = true
	var idx: int = -1
	var p: Vector2 = Vector2.ZERO
	var pressed: bool = true
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		idx = st.index
		p = st.position
		pressed = st.pressed
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event as InputEventScreenDrag
		idx = sd.index
		p = sd.position
	else:
		return
	if not pressed:
		_release_touch(idx)
		return
	# 已归属的手指只更新位置
	if idx == left_idx:
		left_current = p
		_sync_joysticks()
		return
	if idx == right_idx:
		right_current = p
		_sync_joysticks()
		return
	# 新手指按落点分左右，每侧只认第一根；双指先后顺序任意
	# 武器快捷栏区域由按钮自身消化，不生成摇杆
	if _point_over_weapon_bar(p):
		return
	var half: float = get_viewport_rect().size.x * 0.5
	if p.x < half and left_idx == -1:
		left_idx = idx
		left_origin = p
		left_current = p
	elif p.x >= half and right_idx == -1:
		right_idx = idx
		right_origin = p
		right_current = p
	else:
		return
	_sync_joysticks()

func _release_touch(idx: int):
	if idx == left_idx:
		left_idx = -1
		left_origin = Vector2.ZERO
		left_current = Vector2.ZERO
	if idx == right_idx:
		right_idx = -1
		right_origin = Vector2.ZERO
		right_current = Vector2.ZERO
	_sync_joysticks()

func mk_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func mk_button(text: String, w: int = 420, h: int = 76) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 26)
	b.custom_minimum_size = Vector2(float(w), float(h))
	return b

func refresh_selectors():
	for i in range(DIFFS.size()):
		diff_btns[i].text = ("✔ " if i == selected_diff else "    ") + str(DIFFS[i]["name"])
	for i in range(CHARACTERS.size()):
		char_btns[i].text = ("✔ " if i == GameManager.selected_char else "    ") + CHARACTERS[i]

func pick_diff(i: int):
	selected_diff = i
	refresh_selectors()
	refresh_menu()

func pick_char(i: int):
	GameManager.set_char(i)
	refresh_selectors()

func refresh_menu():
	var fee: int = cur_fee()
	btn_start.text = "开始游戏 (消耗 %d 奶龙币)" % fee
	lbl_coins.text = "奶龙币: %d" % GameManager.coins
	lbl_best.text = "最高分: %d" % GameManager.best_score
	lbl_user.text = "用户: " + GameManager.current_user
	if GameManager.can_afford(fee):
		if GameManager.signed_in_today:
			lbl_signin.text = "每日签到 +%d 奶龙币！" % GameManager.DAILY_REWARD
		else:
			lbl_signin.text = "今日未签到"
	else:
		if GameManager.can_quiz():
			lbl_signin.text = "奶龙币不足，答题赚币或明日签到"
		else:
			lbl_signin.text = "今日签到与答题次数已用完，明天再来"
	if btn_quiz:
		btn_quiz.visible = (not GameManager.can_afford(fee)) and GameManager.can_quiz()

func refresh_hud():
	var lvl: Dictionary = LEVELS[current_level]
	lbl_size.text = "尺寸: %d" % int(player.radius)
	lbl_score.text = "本关: %d / %d   总分: %d" % [level_score, level_target, score]
	lbl_coins.text = "奶龙币: %d" % GameManager.coins
	lbl_level.text = "第 %d 关 · %s" % [level_index, str(lvl["name"])]
	lbl_hp.text = "生命: %d/%d" % [int(maxf(0.0, player.hp)), int(player.max_hp)]

func show_menu():
	state = "menu"
	hud.visible = false
	hint_label.visible = false
	_reset_joysticks(false)
	weapon_bar.visible = false
	level_clear_panel.visible = false
	level_banner.visible = false
	login_center.visible = false
	menu_center.visible = true
	over_center.visible = false
	refresh_menu()

func show_login():
	state = "login"
	hud.visible = false
	_reset_joysticks(false)
	weapon_bar.visible = false
	level_clear_panel.visible = false
	menu_center.visible = false
	over_center.visible = false
	login_center.visible = true
	login_feedback.text = ""

func _on_login_pressed():
	var u := username_input.text.strip_edges()
	if u == "":
		login_feedback.text = "请输入用户名"
		return
	if not GameManager.user_exists(u):
		login_feedback.text = "用户不存在，请先注册"
		return
	GameManager.login(u)
	show_menu()

func _on_register_pressed():
	var u := username_input.text.strip_edges()
	if u == "":
		login_feedback.text = "请输入用户名"
		return
	if GameManager.user_exists(u):
		login_feedback.text = "用户名已存在"
		return
	GameManager.register_user(u)
	show_menu()

func _on_existing_user_pressed(u: String):
	GameManager.login(u)
	show_menu()

func _on_logout_pressed():
	GameManager.logout()
	show_login()

func _on_start_pressed():
	var fee: int = cur_fee()
	if not GameManager.can_afford(fee):
		return
	GameManager.pay_entry(fee)
	start_game()

func _on_again_pressed():
	var fee: int = cur_fee()
	if not GameManager.can_afford(fee):
		show_menu()
		lbl_signin.text = "奶龙币不足，请明日签到领取"
		return
	GameManager.pay_entry(fee)
	start_game()

func start_game():
	for f in fish_layer.get_children():
		f.queue_free()
	if player and is_instance_valid(player):
		player.queue_free()
		player = null
	level_index = 1
	current_level = 0
	level_score = 0
	level_kills = 0
	level_target = 300
	win_mode = false
	var start_bg: Color = LEVELS[0]["bg"]
	_apply_bg(start_bg)
	player = PlayerScript.new()
	player.apply_character(GameManager.selected_char)
	player.global_position = get_viewport_rect().size * 0.5
	player.area_entered.connect(_on_player_area_entered)
	add_child(player)
	score = 0
	kill_count = 0
	boss_threshold_score = 800
	boss_threshold_kills = 25
	current_boss = null
	if boss_bar:
		boss_bar.visible = false
	state = "playing"
	hud.visible = true
	hint_label.visible = true
	_reset_joysticks(true)
	menu_center.visible = false
	over_center.visible = false
	level_clear_panel.visible = false
	weapon_bar.visible = true
	_refresh_weapon_bar()
	level_banner.visible = false
	refresh_hud()
	spawn_timer.wait_time = float(DIFFS[selected_diff]["spawn"])
	for i in range(16):
		spawn_fish()
	spawn_timer.start()
	if audio != null:
		audio.start_bgm()

func spawn_fish():
	if state != "playing":
		return
	var f: Fish = FishScript.new()
	fish_layer.add_child(f)
	var v := get_viewport_rect().size
	var edge: int = randi() % 4
	var pos := Vector2()
	match edge:
		0: pos = Vector2(randf() * v.x, -40.0)
		1: pos = Vector2(randf() * v.x, v.y + 40.0)
		2: pos = Vector2(-40.0, randf() * v.y)
		3: pos = Vector2(v.x + 40.0, randf() * v.y)
	f.global_position = pos
	var d: Dictionary = DIFFS[selected_diff]
	var lvl_scale: float = minf(2.8, 1.0 + 0.08 * float(level_index - 1))
	var pred_chance: float = minf(0.82, float(d["pred"]) + 0.04 * float(level_index - 1))
	var r: float
	var col: Color
	var is_pred: bool = false
	var base_spd: float = 0.0
	if randf() < pred_chance:
		is_pred = true
		r = randf_range(28.0, 70.0)
		col = Color(1.0, 0.6, 0.72)
		base_spd = randf_range(float(d["psmin"]), float(d["psmax"])) * lvl_scale
	else:
		r = randf_range(6.0, 18.0)
		col = Color(0.55, 0.85, 1.0)
		base_spd = randf_range(float(d["fmin"]), float(d["fmax"]))
	var ang: float = randf() * TAU
	var vel := Vector2(cos(ang), sin(ang)) * base_spd
	f.setup(r, vel, col)
	f.died.connect(_on_fish_died)
	if is_pred:
		f.is_predator = true
		f.player_ref = player
		f.chase_speed_mult = float(d["chase"])

func _on_player_area_entered(area):
	if state != "playing":
		return
	if area.is_in_group("fish"):
		var fish := area as Fish
		var fr: float = fish.radius
		if player.radius > fr * 1.15:
			player.grow(1.4 + fr * 0.045)
			var gained: int = 10 + int(fr)
			score += gained
			level_score += gained
			fish.queue_free()
			if audio != null:
				audio.play_eat()
			refresh_hud()
			check_progress()
		elif fr > player.radius * 1.15:
			player.take_damage(fish.contact_damage)
			refresh_hud()
			if player.hp <= 0.0:
				game_over()

func check_progress():
	if state == "playing" and level_score >= level_target:
		level_clear()

# 无尽关卡：达标进入结算，玩家点「继续」才推进；死亡才最终结算。
func level_clear():
	state = "levelclear"
	spawn_timer.stop()
	# 清场，避免结算期间继续受伤 / BOSS 血条残留
	for f in fish_layer.get_children():
		f.queue_free()
	current_boss = null
	if boss_bar:
		boss_bar.visible = false
	level_banner.visible = false
	hint_label.visible = false
	weapon_bar.visible = false
	_reset_joysticks(false)
	var hp_ratio: float = 0.0
	if player != null and is_instance_valid(player):
		hp_ratio = player.hp / player.max_hp
	var over: int = int(float(level_target) * 1.2)
	var grade: String = "B"
	if hp_ratio >= 0.8 and level_score >= over:
		grade = "S"
	elif hp_ratio >= 0.5 or level_score >= over:
		grade = "A"
	var reward: int = 10 + 5 * (level_index - 1)
	GameManager.add_coins(reward)
	lbl_clear_title.text = "第 %d 关 完成" % level_index
	lbl_clear_stats.text = "本关得分 %d / %d\n本关击杀 %d\n累计总分 %d\n剩余生命 %d%%" % [level_score, level_target, level_kills, score, int(hp_ratio * 100.0)]
	lbl_clear_grade.text = "评价  " + grade
	lbl_clear_reward.text = "奖励 +%d 奶龙币" % reward
	btn_next_level.text = "继续第 %d 关 →" % (level_index + 1)
	level_clear_panel.visible = true
	refresh_hud()

func _on_next_level_pressed():
	next_level()

func next_level():
	level_index += 1
	current_level = (level_index - 1) % LEVELS.size()
	level_score = 0
	level_kills = 0
	level_target = 300 + 200 * (level_index - 1)
	var nl: Dictionary = LEVELS[current_level]
	var nbgc: Color = nl["bg"]
	_apply_bg(nbgc)
	for f in fish_layer.get_children():
		f.queue_free()
	current_boss = null
	if boss_bar:
		boss_bar.visible = false
	boss_threshold_score = score + 600
	boss_threshold_kills = kill_count + 15
	state = "playing"
	level_clear_panel.visible = false
	hint_label.visible = true
	weapon_bar.visible = true
	_refresh_weapon_bar()
	_reset_joysticks(true)
	spawn_timer.wait_time = maxf(0.22, float(DIFFS[selected_diff]["spawn"]) - 0.01 * float(level_index - 1))
	for i in range(16):
		spawn_fish()
	spawn_timer.start()
	show_level_banner("第 %d 关 · %s" % [level_index, str(nl["name"])])
	refresh_hud()
	# 每 3 关开场强制 BOSS，形成阶段高潮
	if level_index % 3 == 0:
		spawn_boss()

# 背景切换时同步子弹对比配色标志（autoload 运行时字段，不进存档）
func _apply_bg(c: Color):
	bg.color = c
	var lum: float = c.r * 0.299 + c.g * 0.587 + c.b * 0.114
	GameManager.bg_is_light = (lum > 0.62)

func _on_weapon_pressed(i: int):
	if state != "playing" or player == null:
		return
	player.switch_weapon(i)
	_refresh_weapon_bar()

func _refresh_weapon_bar():
	for i in range(weapon_btns.size()):
		var b: Button = weapon_btns[i]
		if player != null and i == player.weapon_index:
			b.modulate = Color(1.0, 0.82, 0.35)
			b.text = "✔ " + WEAPON_SHORT[i]
		else:
			b.modulate = Color.WHITE
			b.text = WEAPON_SHORT[i]

func _point_over_weapon_bar(p: Vector2) -> bool:
	if weapon_bar == null or not weapon_bar.visible:
		return false
	return weapon_bar.get_global_rect().has_point(p)

func show_level_banner(text: String):
	lbl_level_banner.text = text
	level_banner.visible = true
	level_banner_timer.start()

func _on_banner_hide():
	level_banner.visible = false

func _on_fish_died(fish: Fish):
	if fish == null:
		return
	if fish.is_boss:
		score += 400
		level_score += 400
		GameManager.add_coins(30)
		current_boss = null
		if boss_bar:
			boss_bar.visible = false
		boss_threshold_score = score + 600
		boss_threshold_kills = kill_count + 15
	else:
		var ks: int = 5 + int(fish.radius) * 2
		score += ks
		level_score += ks
		GameManager.add_coins(1 + int(fish.radius / 10))
	kill_count += 1
	level_kills += 1
	refresh_hud()
	check_progress()
	_try_spawn_boss()

func _try_spawn_boss():
	if state != "playing":
		return
	if current_boss != null and not is_instance_valid(current_boss):
		current_boss = null
	if current_boss != null:
		return
	if score >= boss_threshold_score or kill_count >= boss_threshold_kills:
		spawn_boss()

func spawn_boss():
	if player == null or not is_instance_valid(player):
		return
	var f: Fish = FishScript.new()
	var t: int = randi() % Fish.BOSS_TYPES.size()
	f.make_boss(t)
	fish_layer.add_child(f)
	var v: Vector2 = get_viewport_rect().size
	f.global_position = Vector2(randf_range(v.x * 0.2, v.x * 0.8), -60.0)
	f.player_ref = player
	f.died.connect(_on_fish_died)
	current_boss = f
	if boss_bar:
		boss_bar.visible = true
	show_level_banner("⚠ BOSS 出现：" + f.boss_name)

func update_combat_hud():
	if player == null:
		return
	lbl_hp.text = "生命: %d/%d" % [int(maxf(0.0, player.hp)), int(player.max_hp)]
	var w: Dictionary = player.WEAPONS[player.weapon_index]
	if w["type"] == "ranged":
		var st: String = "（换弹中…）" if player.reloading else ""
		lbl_ammo.text = "弹药: %d/%d %s" % [player.ammo, int(w["mag"]), st]
	else:
		lbl_ammo.text = "弹药: 近战（无限）"
	lbl_weapon.text = "武器: " + str(w["name"]) + "  [下方按钮 / 1-4 切换 · R 换弹]"
	if current_boss != null and is_instance_valid(current_boss):
		boss_bar.visible = true
		var ratio: float = clampf(current_boss.hp / current_boss.max_hp, 0.0, 1.0)
		boss_bar_fill.size.x = 420.0 * ratio
		boss_bar_label.text = current_boss.boss_name + "  %.0f%%" % (ratio * 100.0)
	else:
		boss_bar.visible = false

func game_over():
	if win_mode:
		return
	state = "gameover"
	spawn_timer.stop()
	if boss_bar:
		boss_bar.visible = false
	current_boss = null
	GameManager.record_score(score)
	lbl_over.text = "游戏结束\n到达第 %d 关\n总分: %d\n最高分: %d" % [level_index, score, GameManager.best_score]
	over_center.visible = true
	hint_label.visible = false
	weapon_bar.visible = false
	level_clear_panel.visible = false
	_reset_joysticks(false)
	if audio != null:
		audio.play_death()
	if player and is_instance_valid(player):
		player.queue_free()
		player = null

func game_win():
	state = "gameover"
	win_mode = true
	spawn_timer.stop()
	if boss_bar:
		boss_bar.visible = false
	current_boss = null
	GameManager.record_score(score)
	lbl_over.text = "通关啦！\n总分: %d\n最高分: %d" % [score, GameManager.best_score]
	over_center.visible = true
	hint_label.visible = false
	_reset_joysticks(false)
	if player and is_instance_valid(player):
		player.queue_free()
		player = null

func _on_quiz_open():
	if not GameManager.can_quiz():
		refresh_menu()
		return
	current_q = GameManager.get_question()
	quiz_q.text = current_q.q
	for i in range(4):
		quiz_opts[i].text = current_q.options[i]
	quiz_feedback.text = ""
	quiz_panel.visible = true
	menu_center.visible = false

func _on_quiz_option_pressed(idx: int):
	if not quiz_panel.visible:
		return
	var correct := (idx == int(current_q.correct))
	var gained := GameManager.answer_quiz(correct)
	if gained > 0:
		quiz_feedback.text = "答对啦！+%d 奶龙币" % gained
	else:
		quiz_feedback.text = "答错了，正确答案：%s" % current_q.options[int(current_q.correct)]
	refresh_menu()

func _on_quiz_close():
	quiz_panel.visible = false
	show_menu()

func _process(_delta: float):
	if state == "playing" and player != null:
		update_combat_hud()
	if debug_label and state == "playing":
		var fc := fish_layer.get_child_count()
		var pr := 0
		if player != null:
			pr = int(player.radius)
		debug_label.text = "状态:%s 鱼:%d 尺寸:%d 分:%d" % [state, fc, pr, score]
		debug_label.visible = true
	elif debug_label:
		debug_label.visible = false

func _input(event):
	if state != "playing" or player == null:
		return
	if event is InputEventMouseButton:
		# 触摸设备会把触摸模拟成鼠标；一旦见过触摸就完全交给摇杆逻辑
		if touch_seen:
			return
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				# 点武器快捷栏只切枪，不误开火
				player.firing = not _point_over_weapon_bar(mb.position)
			else:
				player.firing = false
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		_handle_touch(event)
