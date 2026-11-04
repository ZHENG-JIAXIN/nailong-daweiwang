extends Area2D
class_name Bullet
# Bullet —— 玩家远程武器发射的子弹；代码绘制发光弹体；命中 damageable(鱼/BOSS) 造成伤害后销毁
# 路径 res://bullet.gd

var speed: float = 700.0
var damage: float = 10.0
var velocity: Vector2 = Vector2.ZERO
var life: float = 1.4
var _age: float = 0.0
var _hit: bool = false

func setup(p_pos: Vector2, p_dir: Vector2, p_dmg: float, p_speed: float, p_life: float):
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
	shape.radius = 5.0
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
			queue_free()

func _process(delta: float):
	global_position += velocity * delta
	_age += delta
	var v: Vector2 = get_viewport_rect().size
	var m: float = 80.0
	if _age > life or global_position.x < -m or global_position.x > v.x + m or global_position.y < -m or global_position.y > v.y + m:
		queue_free()

func _draw():
	var tail: Vector2 = -velocity.normalized() * 12.0
	draw_line(Vector2.ZERO, tail, Color(1.0, 0.95, 0.45, 0.5), 3.0)
	draw_circle(Vector2.ZERO, 4.5, Color(1.0, 0.9, 0.3))
	draw_circle(Vector2.ZERO, 2.2, Color.WHITE)
