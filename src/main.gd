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

var player: Player
var fish_layer: Node2D
var ui: Control
var bg: ColorRect
var hud: VBoxContainer
var spawn_timer: Timer

var state := "login"   # login | menu | playing | gameover
var score := 0
var selected_diff: int = 1
var current_level: int = 0
var win_mode: bool = false
var audio: AudioPlayer

# UI 引用
var lbl_size: Label
var lbl_score: Label
var lbl_coins: Label
var lbl_signin: Label
var lbl_level: Label
var lbl_best: Label
var lbl_user: Label
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

	# 游戏内提示 & 调试标签
	hint_label = mk_label("拖拽 / 移动鼠标控制奶龙，吃小的长大，躲大的！", 20, Color(0.1, 0.2, 0.35))
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

func mk_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
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
	lbl_score.text = "分数: %d / %d" % [score, int(lvl["target"])]
	lbl_coins.text = "奶龙币: %d" % GameManager.coins
	lbl_level.text = "关卡 %d/%d  %s" % [current_level + 1, LEVELS.size(), lvl["name"]]

func show_menu():
	state = "menu"
	hud.visible = false
	hint_label.visible = false
	level_banner.visible = false
	login_center.visible = false
	menu_center.visible = true
	over_center.visible = false
	refresh_menu()

func show_login():
	state = "login"
	hud.visible = false
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
	current_level = 0
	win_mode = false
	var start_bg: Color = LEVELS[0]["bg"]
	bg.color = start_bg
	player = PlayerScript.new()
	player.apply_character(GameManager.selected_char)
	player.global_position = get_viewport_rect().size * 0.5
	player.target = player.global_position
	player.area_entered.connect(_on_player_area_entered)
	add_child(player)
	score = 0
	state = "playing"
	hud.visible = true
	hint_label.visible = true
	menu_center.visible = false
	over_center.visible = false
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
	var f := FishScript.new()
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
	var lvl_scale: float = 1.0 + 0.1 * float(current_level)
	var pred_chance: float = min(0.78, float(d["pred"]) + 0.05 * float(current_level))
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
			score += 10 + int(fr)
			fish.queue_free()
			if audio != null:
				audio.play_eat()
			refresh_hud()
			check_progress()
		elif fr > player.radius * 1.15:
			game_over()

func check_progress():
	var lvl: Dictionary = LEVELS[current_level]
	if score >= int(lvl["target"]):
		if current_level < LEVELS.size() - 1:
			current_level += 1
			var nl: Dictionary = LEVELS[current_level]
			var bgc: Color = nl["bg"]
			bg.color = bgc
			show_level_banner("进入关卡 %d：%s" % [current_level + 1, nl["name"]])
			refresh_hud()
		else:
			game_win()

func show_level_banner(text: String):
	lbl_level_banner.text = text
	level_banner.visible = true
	level_banner_timer.start()

func _on_banner_hide():
	level_banner.visible = false

func game_over():
	if win_mode:
		return
	state = "gameover"
	spawn_timer.stop()
	GameManager.record_score(score)
	lbl_over.text = "游戏结束\n分数: %d\n最高分: %d" % [score, GameManager.best_score]
	over_center.visible = true
	hint_label.visible = false
	if audio != null:
		audio.play_death()
	if player and is_instance_valid(player):
		player.queue_free()
		player = null

func game_win():
	state = "gameover"
	win_mode = true
	spawn_timer.stop()
	GameManager.record_score(score)
	lbl_over.text = "通关啦！\n总分: %d\n最高分: %d" % [score, GameManager.best_score]
	over_center.visible = true
	hint_label.visible = false
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
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			player.target = event.position
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		player.target = event.position
