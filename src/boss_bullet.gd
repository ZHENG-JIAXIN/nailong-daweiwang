extends Area2D
class_name BossBullet
# BOSS 弹幕子弹：环形 / 扇形 / 慢速追踪；命中 player 扣血后销毁。
# 视觉与玩家子弹（橙黄）明显区分：红紫芯 + 按背景亮度自适应的描边。
# 路径 res://boss_bullet.gd

var speed: float = 180.0
var damage: float = 10.0
var velocity: Vector2 = Vector2.ZERO
var life: float = 5.0
var homing: bool = false
var turn_rate: float = 1.4
var target: Node2D = null
var _age: float = 0.0
var _hit: bool = false

func setup(p_pos: Vector2, p_dir: Vector2, p_spd: float, p_dmg: float, p_life: float, p_homing: bool, p_target: Node2D):
	global_position = p_pos
	damage = p_dmg
	speed = p_spd
	life = p_life
	homing = p_homing
	target = p_target
	if p_dir.length() > 0.0:
		velocity = p_dir.normalized() * speed
	else:
		velocity = Vector2(speed, 0.0)
	rotation = velocity.angle()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 9.0
	var cs: CollisionShape2D = CollisionShape2D.new()
	cs.name = "Col"
	cs.shape = shape
	add_child(cs)
	add_to_group("boss_bullet")
	queue_redraw()

func _ready():
	area_entered.connect(_on_hit)

func _on_hit(area):
	if _hit:
		return
	if area.is_in_group("player"):
		var p: Player = area as Player
		if p != null and is_instance_valid(p):
			_hit = true
			p.take_damage(damage)
			queue_free()

func _process(delta: float):
	if homing and target != null and is_instance_valid(target):
		var want: Vector2 = (target.global_position - global_position).normalized() * speed
		velocity = velocity.lerp(want, clampf(turn_rate * delta, 0.0, 1.0))
		rotation = velocity.angle()
	global_position += velocity * delta
	_age += delta
	var v: Vector2 = get_viewport_rect().size
	var m: float = 80.0
	if _age > life or global_position.x < -m or global_position.x > v.x + m or global_position.y < -m or global_position.y > v.y + m:
		queue_free()

# 只在 setup() 后绘制一次：移动靠 global_position、追踪靠 rotation（节点变换，不重绘）
func _draw():
	var outline: Color = Color(0.12, 0.02, 0.12)
	var core: Color = Color(0.95, 0.20, 0.55)
	if not GameManager.bg_is_light:
		outline = Color(1.0, 0.85, 0.95, 0.95)
		core = Color(1.0, 0.35, 0.65)
	draw_circle(Vector2.ZERO, 9.0, outline)
	draw_circle(Vector2.ZERO, 6.5, core)
	draw_circle(Vector2.ZERO, 2.5, Color.WHITE)
