extends Area2D
class_name Bullet
# Bullet —— 玩家远程武器发射的子弹；按关卡背景亮度自适应对比配色；命中 damageable 造成伤害后销毁
# 路径 res://bullet.gd

var speed: float = 700.0
var damage: float = 10.0
var velocity: Vector2 = Vector2.ZERO
var life: float = 1.4
var _age: float = 0.0
var _hit: bool = false
var size_mult: float = 1.0
var owner_player: Player = null

func setup(p_pos: Vector2, p_dir: Vector2, p_dmg: float, p_speed: float, p_life: float, p_size: float = 1.0):
	size_mult = p_size
	global_position = p_pos
	damage = p_dmg
	speed = p_speed
	life = p_life
	if p_dir.length() > 0.0:
		velocity = p_dir.normalized() * speed
	else:
		velocity = Vector2(speed, 0.0)
	rotation = velocity.angle()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 6.0 * size_mult
	var cs: CollisionShape2D = CollisionShape2D.new()
	cs.name = "Col"
	cs.shape = shape
	add_child(cs)
	add_to_group("bullet")
	queue_redraw()

func _ready():
	area_entered.connect(_on_hit)

func _on_hit(area):
	if _hit:
		return
	if area.is_in_group("damageable"):
		var fish: Fish = area as Fish
		if fish != null and is_instance_valid(fish):
			_hit = true
			fish.take_damage(damage)
			if owner_player != null and is_instance_valid(owner_player):
				owner_player.on_dealt_damage(damage)
			queue_free()

func _process(delta: float):
	global_position += velocity * delta
	_age += delta
	var v: Vector2 = get_viewport_rect().size
	var m: float = 80.0
	if _age > life or global_position.x < -m or global_position.x > v.x + m or global_position.y < -m or global_position.y > v.y + m:
		queue_free()

# 双层描边结构：浅背景靠深色轮廓、深背景靠亮色轮廓，任意背景都能看清。
# 配色规则见 design/gdd/bullet-visibility-spec.md；只在 setup() 后绘制一次。
func _draw():
	var outline: Color = Color(0.06, 0.09, 0.18)
	var core: Color = Color(1.0, 0.55, 0.10)
	var trail_col: Color = Color(0.15, 0.12, 0.30, 0.65)
	if not GameManager.bg_is_light:
		outline = Color(1.0, 1.0, 1.0, 0.95)
		core = Color(1.0, 0.85, 0.25)
		trail_col = Color(1.0, 0.90, 0.55, 0.55)
	var r1: float = 6.5 * size_mult
	var r2: float = 4.6 * size_mult
	var r3: float = 2.0 * size_mult
	var tail: Vector2 = -velocity.normalized() * 18.0
	draw_line(Vector2.ZERO, tail, trail_col, 5.0 * size_mult)
	draw_circle(Vector2.ZERO, r1, outline)
	draw_circle(Vector2.ZERO, r2, core)
	draw_circle(Vector2.ZERO, r3, Color.WHITE)
