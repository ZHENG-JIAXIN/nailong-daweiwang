extends Area2D
class_name Gift
# 地图限时礼包：存在 8 秒，超时自动消失；碰到玩家即被拾取（由 main.gd 处理）。
# 代码绘制礼盒；z_index 高于 HUD/横幅，避免被 UI 层压暗或遮住。
# 闪烁只用 modulate，不每帧重绘。路径 res://gift.gd

var life: float = 8.0
var _age: float = 0.0
var _pulse: float = 0.0
var opened: bool = false

func _ready():
	# fish_layer 与 ui 同层，礼包提到上层才能在任何背景与横幅下都醒目
	z_index = 2

func setup(pos: Vector2, p_life: float):
	global_position = pos
	life = p_life
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 34.0
	var cs: CollisionShape2D = CollisionShape2D.new()
	cs.name = "Col"
	cs.shape = shape
	add_child(cs)
	add_to_group("gift")
	queue_redraw()

func _process(delta: float):
	_age += delta
	_pulse += delta
	# 剩余 2 秒闪烁加快，提示即将消失；改 modulate 不触发重绘
	var rate: float = 4.0
	if _age > life - 2.0:
		rate = 14.0
	var k: float = 0.78 + 0.22 * sin(_pulse * rate)
	modulate = Color(1.0, k, k)
	if _age >= life:
		queue_free()

func _draw():
	var s: float = 26.0
	# 外圈光环：浅色/深色背景都能一眼看到
	draw_circle(Vector2.ZERO, s + 10.0, Color(1.0, 0.92, 0.45, 0.22))
	draw_arc(Vector2.ZERO, s + 10.0, 0.0, TAU, 48, Color(1.0, 0.85, 0.2, 0.95), 4.0)
	# 礼盒
	draw_rect(Rect2(-s, -s, s * 2.0, s * 2.0), Color(0.28, 0.13, 0.05))
	draw_rect(Rect2(-s + 4.0, -s + 4.0, (s - 4.0) * 2.0, (s - 4.0) * 2.0), Color(1.0, 0.78, 0.25))
	draw_rect(Rect2(-6.0, -s, 12.0, s * 2.0), Color(0.95, 0.25, 0.35))
	draw_rect(Rect2(-s, -6.0, s * 2.0, 12.0), Color(0.95, 0.25, 0.35))
	draw_circle(Vector2(-10.0, -s - 4.0), 8.0, Color(0.95, 0.25, 0.35))
	draw_circle(Vector2(10.0, -s - 4.0), 8.0, Color(0.95, 0.25, 0.35))
