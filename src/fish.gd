extends Area2D
class_name Fish
# Fish —— 食物(小)/捕食者(大)/BOSS 通用；漂移移动；出界回收；代码绘制「鱼形」+ 描边
# 战斗扩展：HP / 受伤 / 死亡信号 / 接触伤害 / BOSS 形态
# 起草：engineering-lead 方法论（主理人代笔，实际由主理人执行）。路径 res://fish.gd

const CJK_FONT := preload("res://assets/fonts/simhei.ttf")
const BossBulletScript := preload("res://boss_bullet.gd")

# BOSS 类型表（外观 / 数值明显区别于普通鱼）
const BOSS_TYPES: Array[Dictionary] = [
	{"name":"深海巨鲨","color":Color(0.15,0.25,0.55),"hp":900.0,"radius":110.0,"dmg":45.0,"speed":70.0},
	{"name":"熔岩章鱼","color":Color(0.95,0.35,0.20),"hp":700.0,"radius":95.0,"dmg":40.0,"speed":85.0},
	{"name":"幽灵鲸王","color":Color(0.50,0.30,0.70),"hp":1200.0,"radius":130.0,"dmg":55.0,"speed":60.0},
]

signal died(f: Fish)

var radius: float = 12.0
var velocity: Vector2 = Vector2.ZERO
var color: Color = Color(0.55, 0.85, 1.0)
var is_predator: bool = false
var player_ref: Node2D = null
var chase_speed_mult: float = 1.0
var base_speed: float = 60.0
var last_draw_angle: float = 1000.0  # 哨兵值，确保首帧绘制；之后仅在转向时重绘
var chase_range: float = 320.0       # 追猎触发范围（BOSS 会拉大）

# 战斗属性
var hp: float = 10.0
var max_hp: float = 10.0
var contact_damage: float = 10.0   # 接触玩家时对玩家造成的伤害
var is_boss: bool = false
var boss_name: String = ""

# BOSS 技能状态
var boss_type: int = -1
var skill_timer: float = 2.0
var charge_timer: float = 0.0
var charging: bool = false

func _ready():
	add_to_group("fish")
	add_to_group("damageable")
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = radius
	var cs: CollisionShape2D = CollisionShape2D.new()
	cs.name = "Col"
	cs.shape = shape
	add_child(cs)
	queue_redraw()

func setup(r: float, vel: Vector2, col: Color):
	radius = r
	var cs = get_node_or_null("Col")
	if cs:
		cs.shape.radius = r
	velocity = vel
	base_speed = vel.length()
	color = col
	contact_damage = max(5.0, r * 0.45)
	max_hp = 6.0 + r * 0.8
	hp = max_hp
	queue_redraw()

func _process(delta: float):
	if is_boss and hp > 0.0:
		_update_boss_skill(delta)
	if is_predator and player_ref != null and is_instance_valid(player_ref):
		var d: Vector2 = player_ref.global_position - global_position
		if d.length() < chase_range:
			velocity = d.normalized() * (base_speed * chase_speed_mult)
	global_position += velocity * delta
	var v: Vector2 = get_viewport_rect().size
	var m: float = 120.0
	if global_position.x < -m or global_position.x > v.x + m or global_position.y < -m or global_position.y > v.y + m:
		queue_free()
		return
	# 仅在游动方向（角度）发生明显变化时重绘，避免每帧重画多边形+描边（单线程 Web 主线程过载主因）
	var a: float = velocity.angle()
	if absf(a - last_draw_angle) > 0.02:
		last_draw_angle = a
		queue_redraw()

func _fill(c: Color, n: int) -> PackedColorArray:
	var arr: PackedColorArray = PackedColorArray()
	for i in range(n):
		arr.append(c)
	return arr

func _draw():
	# 以游动方向为基准，绘制鱼形（椭圆身 + 三角尾 + 眼睛），并描边
	var a: float = velocity.angle()
	var col: Color = color
	var outline: Color = col.darkened(0.5)
	var fwd: Vector2 = Vector2(cos(a), sin(a))
	var side: Vector2 = Vector2(-sin(a), cos(a))
	var bw: float = radius * 1.2
	var bh: float = radius * 0.72
	var body: PackedVector2Array = PackedVector2Array()
	for i in range(28):
		var t: float = float(i) / 28.0 * TAU
		body.append(fwd * (cos(t) * bw) + side * (sin(t) * bh))
	var tail: PackedVector2Array = PackedVector2Array([
		fwd * (-bw * 0.9),
		fwd * (-bw * 1.75) + side * (-bh * 0.95),
		fwd * (-bw * 1.75) + side * (bh * 0.95),
	])
	draw_polygon(tail, _fill(outline, 3))
	draw_polyline(tail + PackedVector2Array([tail[0]]), outline, max(2.0, radius * 0.14))
	draw_polygon(body, _fill(col, body.size()))
	draw_polyline(body + PackedVector2Array([body[0]]), outline, max(2.0, radius * 0.14))
	var eye: Vector2 = fwd * (bw * 0.45) + side * (-bh * 0.34)
	draw_circle(eye, max(2.0, radius * 0.2), Color.WHITE)
	draw_circle(eye, max(1.0, radius * 0.1), Color.BLACK)

	if is_boss:
		if charging:
			draw_arc(Vector2.ZERO, radius * 1.3, 0.0, TAU, 48, Color(1.0, 0.25, 0.25, 0.9), 5.0)
		var bar_w: float = radius * 2.2
		var bar_h: float = 12.0
		var bx: float = -bar_w * 0.5
		var by: float = -radius - 52.0
		draw_rect(Rect2(bx, by, bar_w, bar_h), Color(0.0, 0.0, 0.0, 0.55))
		var ratio: float = clampf(hp / max_hp, 0.0, 1.0)
		draw_rect(Rect2(bx, by, bar_w * ratio, bar_h), Color(1.0, 0.25, 0.25))
		var name_pos: Vector2 = Vector2(-bar_w * 0.5, by - 26.0)
		draw_string(CJK_FONT, name_pos, boss_name, HORIZONTAL_ALIGNMENT_CENTER, int(bar_w), 22, Color(1.0, 0.95, 0.6))

func take_damage(dmg: float) -> bool:
	hp -= dmg
	if hp <= 0.0:
		hp = 0.0
		died.emit(self)
		queue_free()
		return true
	queue_redraw()
	return false

func make_boss(type_index: int):
	boss_type = type_index % BOSS_TYPES.size()
	var t: Dictionary = BOSS_TYPES[boss_type]
	is_boss = true
	skill_timer = 2.0
	charge_timer = 0.0
	charging = false
	boss_name = t["name"]
	color = t["color"]
	max_hp = float(t["hp"])
	hp = max_hp
	radius = float(t["radius"])
	contact_damage = float(t["dmg"])
	base_speed = float(t["speed"])
	is_predator = true
	chase_speed_mult = 1.0
	chase_range = 2000.0
	velocity = Vector2(base_speed, 0.0).rotated(randf() * TAU)
	var cs = get_node_or_null("Col")
	if cs != null:
		cs.shape.radius = radius
	queue_redraw()

# ---------------- BOSS 技能（见 design/gdd/boss-skills-spec.md） ----------------

func _skill_phase() -> int:
	var ratio: float = hp / max_hp
	if ratio > 0.7:
		return 1
	if ratio > 0.3:
		return 2
	return 3

func _skill_interval() -> float:
	match _skill_phase():
		1: return 2.4
		2: return 1.8
		_: return 1.3
	return 2.0

func _bullet_count() -> int:
	var base: int = 8
	match boss_type:
		0: base = 8
		1: base = 5
		2: base = 3
	return base + 2 * (_skill_phase() - 1)

func _update_boss_skill(delta: float):
	if charging:
		charge_timer -= delta
		# 蓄力闪烁只改 modulate，不触发重绘（单线程 Web 性能）
		var pulse: float = absf(sin(charge_timer * 12.0))
		modulate = Color(1.0, 1.0 - 0.35 * pulse, 1.0 - 0.35 * pulse)
		if charge_timer <= 0.0:
			charging = false
			modulate = Color.WHITE
			_fire_boss_skill()
			queue_redraw()
		return
	skill_timer -= delta
	if skill_timer <= 0.0:
		charging = true
		charge_timer = 0.6
		skill_timer = _skill_interval()
		queue_redraw()

func _fire_boss_skill():
	if player_ref == null or not is_instance_valid(player_ref):
		return
	# 单屏敌方子弹硬上限，避免弹幕拖垮单线程 Web
	if get_tree().get_nodes_in_group("boss_bullet").size() >= 40:
		return
	match boss_type:
		0: _fire_ring()
		1: _fire_fan()
		2: _fire_homing()

func _spawn_boss_bullet(pos: Vector2, dir: Vector2, spd: float, dmg: float, p_life: float, p_homing: bool):
	var b: BossBullet = BossBulletScript.new()
	b.setup(pos, dir, spd, dmg, p_life, p_homing, player_ref)
	var parent: Node = get_parent()
	if parent != null:
		parent.add_child(b)

func _fire_ring():
	var n: int = _bullet_count()
	var spd: float = 170.0 + 20.0 * float(_skill_phase() - 1)
	for i in range(n):
		var ang: float = TAU * float(i) / float(n) + randf() * 0.12
		var dir: Vector2 = Vector2(cos(ang), sin(ang))
		_spawn_boss_bullet(global_position + dir * radius, dir, spd, 10.0, 5.0, false)

func _fire_fan():
	var n: int = _bullet_count()
	var to_p: Vector2 = player_ref.global_position - global_position
	var aim: float = to_p.angle()
	var spd: float = 210.0 + 20.0 * float(_skill_phase() - 1)
	for i in range(n):
		var t: float = 0.0
		if n > 1:
			t = float(i) / float(n - 1) - 0.5
		var ang: float = aim + t * 0.85
		var dir: Vector2 = Vector2(cos(ang), sin(ang))
		_spawn_boss_bullet(global_position + dir * radius, dir, spd, 10.0, 5.0, false)

func _fire_homing():
	var n: int = mini(_bullet_count(), 5)
	var to_p: Vector2 = player_ref.global_position - global_position
	var aim: float = to_p.angle()
	for i in range(n):
		var ang: float = aim + (float(i) - float(n - 1) * 0.5) * 0.35
		var dir: Vector2 = Vector2(cos(ang), sin(ang))
		_spawn_boss_bullet(global_position + dir * radius, dir, 140.0, 10.0, 6.0, true)
