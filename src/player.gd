extends Area2D
class_name Player
# Player —— 拖拽/鼠标跟随移动、吞噬成长；贴图渲染（带描边轮廓）+ 无贴图时代码绘制占位
# 起草：engineering-lead 方法论（主理人代笔）。路径 res://player.gd

var radius: float = 20.0
var speed: float = 260.0
var target: Vector2 = Vector2.ZERO
var dead: bool = false
var body_color: Color = Color(1.0, 0.85, 0.4)
var horn_color: Color = Color(1.0, 0.72, 0.32)
var char_id: int = 0
var char_tex: Texture2D = null
var sprite: Sprite2D = null

# 预加载三个角色贴图（固定资源用 preload，确保导出/运行时均正确加载且随包分发）
const CHARACTER_TEXTURES: Array[Texture2D] = [
	preload("res://assets/characters/0.png"),
	preload("res://assets/characters/1.png"),
	preload("res://assets/characters/2.png"),
]

# 描边轮廓 Shader：依据贴图 alpha 在外缘生成统一描边（非方形框），让角色像游戏精灵
const OUTLINE_SHADER := "
shader_type canvas_item;
uniform vec4 outline_color = vec4(0.12, 0.10, 0.18, 1.0);
uniform float outline_width = 60.0;
void fragment() {
	vec2 px = outline_width / vec2(textureSize(TEXTURE, 0));
	vec4 t = texture(TEXTURE, UV);
	float a = t.a;
	float n = 0.0;
	n = max(n, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
	n = max(n, texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
	n = max(n, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
	n = max(n, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
	n = max(n, texture(TEXTURE, UV + px).a);
	n = max(n, texture(TEXTURE, UV - px).a);
	n = max(n, texture(TEXTURE, UV + vec2(px.x, -px.y)).a);
	n = max(n, texture(TEXTURE, UV + vec2(-px.x, px.y)).a);
	if (a > 0.4) {
		COLOR = t;
	} else if (n > 0.4) {
		COLOR = outline_color;
	} else {
		COLOR = vec4(0.0);
	}
}
"

func _make_outline_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = OUTLINE_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	return mat

func apply_character(id: int):
	char_id = id
	match id:
		0:
			body_color = Color(1.0, 0.85, 0.4)
			horn_color = Color(1.0, 0.72, 0.32)
		1:
			body_color = Color(0.6, 0.9, 0.7)
			horn_color = Color(0.4, 0.7, 0.5)
		2:
			body_color = Color(1.0, 0.75, 0.85)
			horn_color = Color(1.0, 0.6, 0.75)
	if id >= 0 and id < CHARACTER_TEXTURES.size():
		char_tex = CHARACTER_TEXTURES[id]
	else:
		char_tex = null
	if sprite != null:
		sprite.texture = char_tex
		sprite.visible = (char_tex != null)
		if char_tex != null:
			var tw := float(char_tex.get_width())
			# 描边宽度按贴图分辨率设定，缩放到屏幕后约为角色半径的 6%
			sprite.material.set_shader_parameter("outline_width", 0.06 * tw)
			_update_sprite_scale()
	queue_redraw()

func _update_sprite_scale():
	if sprite == null or sprite.texture == null:
		return
	var tex_w: float = float(sprite.texture.get_width())
	var tex_h: float = float(sprite.texture.get_height())
	var target: float = radius * 2.0
	var max_dim: float = tex_w if tex_w >= tex_h else tex_h
	var sc: float = target / max_dim
	sprite.scale = Vector2(sc, sc)

func _ready():
	sprite = Sprite2D.new()
	sprite.centered = true
	sprite.material = _make_outline_material()
	add_child(sprite)
	# apply_character 可能在入树前已设置贴图，这里补挂到 sprite
	if char_tex != null:
		sprite.texture = char_tex
		sprite.visible = true
		var tw := float(char_tex.get_width())
		sprite.material.set_shader_parameter("outline_width", 0.06 * tw)
		_update_sprite_scale()
	add_to_group("player")
	var shape := CircleShape2D.new()
	shape.radius = radius
	var cs := CollisionShape2D.new()
	cs.name = "Col"
	cs.shape = shape
	add_child(cs)
	target = global_position
	queue_redraw()

func set_radius(r: float):
	radius = r
	var cs = get_node_or_null("Col")
	if cs:
		cs.shape.radius = r
	_update_sprite_scale()
	queue_redraw()

func grow(amount: float):
	set_radius(radius + amount)

func _process(delta: float):
	if dead:
		return
	var to_t := target - global_position
	var step := speed * delta
	if to_t.length() <= step:
		global_position = target
	else:
		global_position += to_t.normalized() * step
	var v := get_viewport_rect().size
	global_position.x = clamp(global_position.x, radius, v.x - radius)
	global_position.y = clamp(global_position.y, radius, v.y - radius)

func _draw():
	if char_tex != null:
		return
	# 无贴图占位：带描边的圆身 + 肚皮 + 角 + 眼睛
	var outline := horn_color.darkened(0.35)
	var ow: float = radius * 0.14
	if ow < 2.0:
		ow = 2.0
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, outline, ow)
	draw_circle(Vector2.ZERO, radius - ow * 0.5, body_color)
	var belly: Color = body_color.lightened(0.18)
	draw_circle(Vector2(-radius * 0.18, -radius * 0.15), radius * 0.62, belly)
	draw_circle(Vector2(0.0, -radius), radius * 0.14, horn_color)
	var er: float = max(2.0, radius * 0.13)
	for ex in [-0.32, 0.32]:
		draw_circle(Vector2(radius * ex, -radius * 0.22), er, Color.WHITE)
		draw_circle(Vector2(radius * ex, -radius * 0.22), er * 0.5, Color.BLACK)
