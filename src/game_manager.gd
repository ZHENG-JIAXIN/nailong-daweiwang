extends Node
# GameManager —— 多用户：奶龙币经济 / 每日签到 / 本地存档 / 题库 / 最高分（autoload 单例）
# 每个用户独立存档，资产相互隔离。路径 res://game_manager.gd

const USERS_DIR := "user://users"
const INDEX_FILE := "user://users/index.json"
const ENTRY_FEE := 20
const DAILY_REWARD := 100
const QUIZ_REWARD := 20
const QUIZ_DAILY_CAP := 8

# 热门梗题库（20 题；选项顺序即索引 0-3）
const QUESTION_BANK := [
	{"q":"“尊嘟假嘟”是哪种网络表达的谐音？", "options":["真的假的", "都是真的", "假装不懂", "都不是"], "correct":0},
	{"q":"“显眼包”通常形容？", "options":["爱出风头惹眼的人/物", "一种眼影", "一种包子", "快递包裹"], "correct":0},
	{"q":"“遥遥领先”常被用来调侃？", "options":["夸张的领先宣传", "跑步比赛", "航天发射", "音乐节拍"], "correct":0},
	{"q":"“City不City”源自什么网络现象？", "options":["中外网友玩梗打卡", "城市名字", "英文考试", "快递公司"], "correct":0},
	{"q":"“听劝”的意思是？", "options":["愿意接受别人建议", "听歌放松", "劝人放弃", "听话照做"], "correct":0},
	{"q":"“绝绝子”一般形容？", "options":["极好或极差的夸张表达", "绝对正确", "子嗣后代", "拒绝邀请"], "correct":0},
	{"q":"“栓Q”是“thank you”的？", "options":["谐音梗", "反义词", "直译", "缩写"], "correct":0},
	{"q":"网上说“我emo了”通常指？", "options":["情绪低落丧", "收到邮件", "发个表情", "在听音乐"], "correct":0},
	{"q":"“硬控我X秒”意思是？", "options":["被某事物牢牢吸引住", "系统卡死", "控制游戏角色", "硬件故障"], "correct":0},
	{"q":"“班味”指的是？", "options":["上班带来的疲惫气质", "班级编号", "一种味道", "班长称呼"], "correct":0},
	{"q":"“芭比Q了”常用来表示？", "options":["完蛋了/糟了", "一种烧烤", "动画片名", "表示感谢"], "correct":0},
	{"q":"“社死”指的是？", "options":["社会性死亡/极度尴尬", "社交账号注销", "社团解散", "去世"], "correct":0},
	{"q":"“YYDS”是什么意思？", "options":["永远的神", "语音大师", "游戏代练", "影院点播"], "correct":0},
	{"q":"“破防了”通常指？", "options":["心理防线被击溃", "防御塔被破", "破解密码", "防水层坏了"], "correct":0},
	{"q":"“躺平”指？", "options":["不再内卷、低欲望生活", "躺在床上", "直接投降", "睡觉"], "correct":0},
	{"q":"“内卷”指？", "options":["过度无效的竞争", "卷被子", "卷入漩涡", "烫发造型"], "correct":0},
	{"q":"“元宇宙”一般指？", "options":["沉浸式虚拟世界", "宇宙的总称", "一种元素", "银河系"], "correct":0},
	{"q":"“哈基米”常指？", "options":["可爱小动物的萌称", "一种米", "哈哈大笑", "哈密瓜"], "correct":0},
	{"q":"“多巴胺穿搭”强调？", "options":["鲜明色彩带来快乐", "穿多巴胺材质的衣服", "一种中药", "运动专用穿搭"], "correct":0},
	{"q":"“搭子”指？", "options":["某方面的固定伙伴(饭搭子/旅游搭子)", "搭建工具", "搭档演员", "一种塔"], "correct":0},
]

var current_user := ""
var coins := 0
var last_signin := ""
var total_plays := 0
var signed_in_today := false
var quiz_date := ""
var quiz_count := 0
var last_q := -1
var best_score := 0
var selected_char := 0
var users: Array[String] = []

# 运行时标志：当前关卡背景是浅色还是深色，供 bullet.gd 选对比配色。
# 不写入存档（每次开局由 main.gd 按背景色重算）。
var bg_is_light := true

func _ready():
	ensure_dirs()
	load_index()

func ensure_dirs():
	var d := DirAccess.open("user://")
	if d != null and not d.dir_exists("users"):
		d.make_dir("users")

func load_index():
	users = []
	if FileAccess.file_exists(INDEX_FILE):
		var f := FileAccess.open(INDEX_FILE, FileAccess.READ)
		var txt := f.get_as_text()
		f.close()
		var data = JSON.parse_string(txt)
		if data is Dictionary and data.has("users"):
			var arr = data["users"]
			if arr is Array:
				for u in arr:
					users.append(str(u))

func save_index():
	var data := {"users": users}
	var f := FileAccess.open(INDEX_FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()

func user_exists(u: String) -> bool:
	return users.has(u)

func user_path(u: String) -> String:
	return USERS_DIR + "/" + u + "/save.json"

func register_user(u: String) -> bool:
	u = u.strip_edges()
	if u == "" or user_exists(u):
		return false
	users.append(u)
	save_index()
	current_user = u
	coins = 0
	last_signin = ""
	total_plays = 0
	signed_in_today = false
	quiz_date = ""
	quiz_count = 0
	last_q = -1
	best_score = 0
	selected_char = 0
	save_data()
	check_daily_signin()
	return true

func login(u: String) -> bool:
	u = u.strip_edges()
	if not user_exists(u):
		return false
	current_user = u
	load_user_data()
	check_daily_signin()
	return true

func logout():
	current_user = ""

func load_user_data():
	if current_user == "":
		return
	var p := user_path(current_user)
	if FileAccess.file_exists(p):
		var f := FileAccess.open(p, FileAccess.READ)
		var txt := f.get_as_text()
		f.close()
		var data = JSON.parse_string(txt)
		if data is Dictionary:
			coins = int(data.get("coins", 0))
			last_signin = str(data.get("last_signin", ""))
			total_plays = int(data.get("total_plays", 0))
			quiz_date = str(data.get("quiz_date", ""))
			quiz_count = int(data.get("quiz_count", 0))
			best_score = int(data.get("best_score", 0))
			selected_char = int(data.get("selected_char", 0))

func save_data():
	if current_user == "":
		return
	var d := DirAccess.open(USERS_DIR)
	if d != null and not d.dir_exists(current_user):
		d.make_dir(current_user)
	var data := {
		"coins": coins,
		"last_signin": last_signin,
		"total_plays": total_plays,
		"quiz_date": quiz_date,
		"quiz_count": quiz_count,
		"best_score": best_score,
		"selected_char": selected_char
	}
	var f := FileAccess.open(user_path(current_user), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()

func today() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d["year"], d["month"], d["day"]]

func check_daily_signin() -> bool:
	if current_user == "":
		return false
	var t := today()
	if last_signin != t:
		coins += DAILY_REWARD
		last_signin = t
		signed_in_today = true
		save_data()
		return true
	signed_in_today = false
	return false

func can_afford(cost: int = ENTRY_FEE) -> bool:
	return coins >= cost

func pay_entry(cost: int = ENTRY_FEE) -> bool:
	if not can_afford(cost):
		return false
	coins -= cost
	total_plays += 1
	save_data()
	return true

func add_coins(amount: int):
	coins += amount
	save_data()

func can_quiz() -> bool:
	var t := today()
	if quiz_date != t:
		quiz_date = t
		quiz_count = 0
		save_data()
	return quiz_count < QUIZ_DAILY_CAP

func answer_quiz(correct: bool) -> int:
	if not correct or not can_quiz():
		return 0
	quiz_count += 1
	coins += QUIZ_REWARD
	save_data()
	return QUIZ_REWARD

func get_question() -> Dictionary:
	var n := QUESTION_BANK.size()
	var i := randi() % n
	if n > 1 and i == last_q:
		i = (i + 1) % n
	last_q = i
	return QUESTION_BANK[i]

func reset_daily():
	if current_user == "":
		return
	quiz_count = 0
	quiz_date = today()
	signed_in_today = false
	last_signin = ""
	save_data()

func record_score(s: int) -> bool:
	if s > best_score:
		best_score = s
		save_data()
		return true
	return false

func set_char(id: int):
	selected_char = id
	save_data()

func is_logged_in() -> bool:
	return current_user != ""
