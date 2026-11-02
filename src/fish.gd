extends Area2D
class_name Fish
# Fish —— 食物(小)/捕食者(大) 通用；漂移移动；出界回收；代码绘制「鱼形」+ 描边
# 起草：engineering-lead 方法论（主理人代笔）。路径 res://fish.gd

var radius: float = 12.0
var velocity: Vector2 = Vector2.ZERO
var color: Color = Color(0.55, 0.85, 1.0)
var is_predator: bool = false
var player_ref: Node2D = null
var chase_speed_mult: float = 1.0
var base_speed: float = 60.0

func _ready():
	add_to_group("fish")
	var shape := CircleShape2D.new()
	shape.radius = radius
	var cs := CollisionShape2D.new()
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
	queue_redraw()

func _process(delta: float):
	if is_predator and player_ref != null and is_instance_valid(player_ref):
		var d: Vector2 = player_ref.global_position - global_position
		if d.length() < 320.0:
			velocity = d.normalized() * (base_speed * chase_speed_mult)
	global_position += velocity * delta
	var v := get_viewport_rect().size
	var m := 120.0
	if global_position.x < -m or global_position.x > v.x + m or global_position.y < -m or global_position.y > v.y + m:
		queue_free()
	# 鱼形随游动方向转向，每帧重绘
	queue_redraw()

func _fill(c: Color, n: int) -> PackedColorArray:
	var arr := PackedColorArray()
	for i in range(n):
		arr.append(c)
	return arr

func _draw():
	# 以游动方向为基准，绘制鱼形（椭圆身 + 三角尾 + 眼睛），并描边
	var a := velocity.angle()
	var col := color
	var outline := col.darkened(0.5)
	var fwd := Vector2(cos(a), sin(a))
	var side := Vector2(-sin(a), cos(a))
	var bw := radius * 1.2
	var bh := radius * 0.72
	var body := PackedVector2Array()
	for i in range(28):
		var t := float(i) / 28.0 * TAU
		body.append(fwd * (cos(t) * bw) + side * (sin(t) * bh))
	var tail := PackedVector2Array([
		fwd * (-bw * 0.9),
		fwd * (-bw * 1.75) + side * (-bh * 0.95),
		fwd * (-bw * 1.75) + side * (bh * 0.95),
	])
	draw_polygon(tail, _fill(outline, 3))
	draw_polyline(tail + PackedVector2Array([tail[0]]), outline, max(2.0, radius * 0.14))
	draw_polygon(body, _fill(col, body.size()))
	draw_polyline(body + PackedVector2Array([body[0]]), outline, max(2.0, radius * 0.14))
	var eye := fwd * (bw * 0.45) + side * (-bh * 0.34)
	draw_circle(eye, max(2.0, radius * 0.2), Color.WHITE)
	draw_circle(eye, max(1.0, radius * 0.1), Color.BLACK)
