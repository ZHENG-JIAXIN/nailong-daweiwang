extends Area2D
class_name Player
# Player —— 按键/左摇杆移动 + 鼠标或右摇杆瞄准（全向 360°）、吞噬成长、生命值、武器系统、角色增益
# 起草：engineering-lead 方法论（主理人代笔）。路径 res://player.gd

const BulletScript := preload("res://bullet.gd")

# 礼包效果参数（所有效果上限 10 秒，见 design/gdd/gift-mechanic-spec.md）
const GIFT_DURATION: float = 10.0
const GIFT_LIFESTEAL: float = 0.15
const GIFT_BULLET_SCALE: float = 1.8
const GIFT_DEBUFF_DAMAGE_MULT: float = 0.5

var radius: float = 20.0
var speed: float = 260.0
var dead: bool = false
var body_color: Color = Color(1.0, 0.85, 0.4)
var horn_color: Color = Color(1.0, 0.72, 0.32)
var char_id: int = 0
var char_tex: Texture2D = null
var sprite: Sprite2D = null

# 战斗状态
var hp: float = 100.0
var max_hp: float = 100.0
var weapon_index: int = 0
var ammo: int = 25
var reloading: bool = false
var reload_timer: float = 0.0
var rof_timer: float = 0.0
var melee_cd: float = 0.0
# 输入三路解耦：移动(键盘 + pad_dir) / 瞄准(鼠标或触摸) / 开火(PC 左键或触摸)
var pad_dir: Vector2 = Vector2.ZERO
var firing: bool = false
var touch_firing: bool = false
var touch_aim_active: bool = false
var touch_aim_dir: Vector2 = Vector2(1.0, 0.0)
var aim_dir: Vector2 = Vector2(1.0, 0.0)
var _iframes: float = 0.0
var _swing_timer: float = 0.0

# 礼包效果状态：一个 effect + 一组乘性系数，清空即恢复原状态
var gift_effect: String = ""
var gift_timer: float = 0.0
var gift_bullet_scale: float = 1.0
var gift_damage_mult: float = 1.0
var gift_dot_cap: float = 0.0
var gift_dot_total: float = 0.0

# 角色增益系数（随吞噬成长放大）
var char_reload_mult: float = 1.0
var char_ranged_dmg_mult: float = 1.0
var char_melee_dmg_mult: float = 1.0
var char_speed_mult: float = 1.0
var heal_on_kill: float = 0.0
var base_radius_for_buff: float = 20.0

# 武器库（参考《生死狙击》风格）。type: ranged | melee
const WEAPONS: Array[Dictionary] = [
	{"id":0,"name":"M4A1 突击步枪","type":"ranged","dmg":14.0,"mag":25,"reload":1.5,"rof":0.10,"spread":0.04,"speed":720.0,"range":1.4},
	{"id":1,"name":"巴雷特M95 狙击枪","type":"ranged","dmg":55.0,"mag":25,"reload":2.2,"rof":0.90,"spread":0.005,"speed":1100.0,"range":2.2},
	{"id":2,"name":"尼泊尔军刀","type":"melee","dmg":40.0,"cd":0.40,"arc":1.1,"reach":72.0},
	{"id":3,"name":"战斧","type":"melee","dmg":30.0,"cd":0.60,"arc":1.8,"reach":112.0},
]

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
	var sh: Shader = Shader.new()
	sh.code = OUTLINE_SHADER
	var mat: ShaderMaterial = ShaderMaterial.new()
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
		sprite.z_index = -1
		if char_tex != null:
			var tw: float = float(char_tex.get_width())
			# 描边宽度按贴图分辨率设定，缩放到屏幕后约为角色半径的 6%
			sprite.material.set_shader_parameter("outline_width", 0.06 * tw)
			_update_sprite_scale()
	# 武器与增益初始化（角色切换时重置）
	weapon_index = 0
	ammo = int(WEAPONS[0]["mag"])
	reloading = false
	reload_timer = 0.0
	rof_timer = 0.0
	melee_cd = 0.0
	apply_buffs()
	queue_redraw()

func apply_buffs():
	# 吞噬成长放大：每长大 40px 算 1 级成长
	var growth: float = maxf(0.0, (radius - base_radius_for_buff) / 40.0)
	match char_id:
		0: # 奶龙 · 突击手：换弹更快、移速更高
			char_reload_mult = maxf(0.4, 0.7 - 0.02 * growth)
			char_speed_mult = 1.10 + 0.02 * growth
			char_ranged_dmg_mult = 1.0
			char_melee_dmg_mult = 1.0
			heal_on_kill = 0.0
		1: # 噜噜 · 狙击手：远程伤害与射程更高
			char_ranged_dmg_mult = 1.25 + 0.05 * growth
			char_speed_mult = 1.0
			char_reload_mult = 1.0
			char_melee_dmg_mult = 1.0
			heal_on_kill = 0.0
		2: # 奶娃 · 狂战：近战伤害更高、击杀回血、移速略高
			char_melee_dmg_mult = 1.40 + 0.06 * growth
			char_speed_mult = 1.05 + 0.02 * growth
			heal_on_kill = 6.0 + growth
			char_reload_mult = 1.0
			char_ranged_dmg_mult = 1.0
		_:
			char_reload_mult = 1.0
			char_ranged_dmg_mult = 1.0
			char_melee_dmg_mult = 1.0
			char_speed_mult = 1.0
			heal_on_kill = 0.0
	speed = 260.0 * char_speed_mult

func _fill_col(c: Color, n: int) -> PackedColorArray:
	var a: PackedColorArray = PackedColorArray()
	for i in range(n):
		a.append(c)
	return a

func _update_sprite_scale():
	if sprite == null or sprite.texture == null:
		return
	var tex_w: float = float(sprite.texture.get_width())
	var tex_h: float = float(sprite.texture.get_height())
	var tgt: float = radius * 2.0
	var max_dim: float = tex_w if tex_w >= tex_h else tex_h
	var sc: float = tgt / max_dim
	sprite.scale = Vector2(sc, sc)

func _ready():
	sprite = Sprite2D.new()
	sprite.centered = true
	sprite.z_index = -1
	sprite.material = _make_outline_material()
	add_child(sprite)
	# apply_character 可能在入树前已设置贴图，这里补挂到 sprite
	if char_tex != null:
		sprite.texture = char_tex
		sprite.visible = true
		sprite.z_index = -1
		var tw: float = float(char_tex.get_width())
		sprite.material.set_shader_parameter("outline_width", 0.06 * tw)
		_update_sprite_scale()
	add_to_group("player")
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = radius
	var cs: CollisionShape2D = CollisionShape2D.new()
	cs.name = "Col"
	cs.shape = shape
	add_child(cs)
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
	apply_buffs()

func take_damage(dmg: float):
	if gift_effect == "invincible" or _iframes > 0.0 or dead:
		return
	hp -= dmg
	_iframes = 0.4
	if hp <= 0.0:
		hp = 0.0
		dead = true
	queue_redraw()

func heal(a: float):
	hp = minf(max_hp, hp + a)

# ---- 礼包效果（仅一种生效，10 秒后自动恢复）----
func apply_gift_effect(effect: String):
	clear_gift_effect()
	gift_effect = effect
	gift_timer = GIFT_DURATION
	match effect:
		"big_bullet":
			gift_bullet_scale = GIFT_BULLET_SCALE
		"dot":
			gift_dot_cap = hp * 0.5
			gift_dot_total = 0.0
		"explosion":
			hp = maxf(0.0, hp - max_hp * 0.2)
			gift_damage_mult = GIFT_DEBUFF_DAMAGE_MULT
			if hp <= 0.0:
				dead = true
	queue_redraw()

func clear_gift_effect():
	gift_effect = ""
	gift_timer = 0.0
	gift_bullet_scale = 1.0
	gift_damage_mult = 1.0
	gift_dot_cap = 0.0
	gift_dot_total = 0.0
	queue_redraw()

func on_dealt_damage(dmg: float):
	if gift_effect == "lifesteal":
		heal(dmg * GIFT_LIFESTEAL)

func _tick_gift_dot(delta: float):
	if gift_dot_cap <= 0.0:
		return
	var amount: float = minf(gift_dot_cap / GIFT_DURATION * delta, gift_dot_cap - gift_dot_total)
	if amount <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	gift_dot_total += amount

func gift_display_name() -> String:
	match gift_effect:
		"lifesteal": return "吸血 15%"
		"big_bullet": return "子弹变大"
		"invincible": return "无敌金身"
		"dot": return "持续扣血"
		"explosion": return "爆炸 · 伤害减半"
		_: return ""
	return ""

func switch_weapon(i: int):
	if i < 0 or i >= WEAPONS.size() or i == weapon_index:
		return
	weapon_index = i
	reloading = false
	reload_timer = 0.0
	rof_timer = 0.0
	melee_cd = 0.0
	var w: Dictionary = WEAPONS[weapon_index]
	if w["type"] == "ranged":
		ammo = int(w["mag"])
	queue_redraw()

func start_reload():
	var w: Dictionary = WEAPONS[weapon_index]
	if w["type"] != "ranged":
		return
	if reloading or ammo >= int(w["mag"]):
		return
	reloading = true
	reload_timer = float(w["reload"]) * char_reload_mult
	queue_redraw()

func fire_bullet():
	var w: Dictionary = WEAPONS[weapon_index]
	var b: Bullet = BulletScript.new()
	var dmg: float = float(w["dmg"])
	if char_id == 1:
		dmg *= char_ranged_dmg_mult
	dmg *= gift_damage_mult
	var spread: float = float(w["spread"])
	var dir: Vector2 = aim_dir.rotated(randf_range(-spread, spread))
	var life: float = float(w["range"])
	b.setup(global_position + dir * (radius + 8.0), dir, dmg, float(w["speed"]), life, gift_bullet_scale)
	b.owner_player = self
	var parent: Node = get_parent()
	if parent != null:
		parent.add_child(b)

func swing():
	_swing_timer = 0.18
	var w: Dictionary = WEAPONS[weapon_index]
	var dmg: float = float(w["dmg"]) * char_melee_dmg_mult * gift_damage_mult
	var center: Vector2 = global_position
	var aim: float = aim_dir.angle()
	var arc: float = float(w["arc"])
	var reach: float = float(w["reach"])
	for node in get_tree().get_nodes_in_group("damageable"):
		var fish: Fish = node as Fish
		if fish == null or not is_instance_valid(fish):
			continue
		var d: Vector2 = fish.global_position - center
		var dist: float = d.length()
		if dist > reach + fish.radius:
			continue
		var diff: float = absf(angle_difference(aim, d.angle()))
		if diff <= arc * 0.5:
			var killed: bool = fish.take_damage(dmg)
			on_dealt_damage(dmg)
			if killed and char_id == 2:
				heal(heal_on_kill)
	queue_redraw()

func _fire_loop():
	var w: Dictionary = WEAPONS[weapon_index]
	if w["type"] == "ranged":
		if reloading:
			return
		if ammo <= 0:
			start_reload()
			return
		if rof_timer <= 0.0:
			fire_bullet()
			ammo -= 1
			rof_timer = float(w["rof"])
			if ammo <= 0:
				start_reload()
	else:
		if melee_cd <= 0.0:
			swing()
			melee_cd = float(w["cd"])

func _process(delta: float):
	if dead:
		return
	# 瞄准：移动端用右摇杆的方向向量（与角色位置无关，真 360°）；PC 用鼠标
	if touch_aim_active:
		aim_dir = touch_aim_dir
	else:
		var gm: Vector2 = get_global_mouse_position()
		var to_m: Vector2 = gm - global_position
		if to_m.length() > 1.0:
			aim_dir = to_m.normalized()
	# 计时器
	if gift_timer > 0.0:
		gift_timer -= delta
		if gift_effect == "dot":
			_tick_gift_dot(delta)
		if gift_timer <= 0.0:
			clear_gift_effect()
	if _iframes > 0.0:
		_iframes -= delta
	if _swing_timer > 0.0:
		_swing_timer -= delta
		if _swing_timer <= 0.0:
			queue_redraw()
	if melee_cd > 0.0:
		melee_cd -= delta
	if rof_timer > 0.0:
		rof_timer -= delta
	if reloading:
		reload_timer -= delta
		if reload_timer <= 0.0:
			reloading = false
			ammo = int(WEAPONS[weapon_index]["mag"])
			queue_redraw()
	# 移动：键盘 WASD/方向键 + 屏幕方向键合成，斜向归一化，按住持续移动
	var kb: Vector2 = Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		kb.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		kb.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		kb.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		kb.x += 1.0
	var mv: Vector2 = kb + pad_dir
	if mv.length() > 1.0:
		mv = mv.normalized()
	global_position += mv * speed * delta
	var v: Vector2 = get_viewport_rect().size
	global_position.x = clampf(global_position.x, radius, v.x - radius)
	global_position.y = clampf(global_position.y, radius, v.y - radius)
	# 开火：PC 左键与移动端触摸互不覆盖
	if firing or touch_firing:
		_fire_loop()

func _input(event):
	if dead:
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: switch_weapon(0)
			KEY_2: switch_weapon(1)
			KEY_3: switch_weapon(2)
			KEY_4: switch_weapon(3)
			KEY_R: start_reload()
	# 鼠标/触摸开火统一交给 main.gd，避免屏幕方向键误触开火

func _draw():
	if char_tex == null:
		# 无贴图占位：带描边的圆身 + 肚皮 + 角 + 眼睛
		var outline: Color = horn_color.darkened(0.35)
		var ow: float = radius * 0.14
		if ow < 2.0:
			ow = 2.0
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, outline, ow)
		draw_circle(Vector2.ZERO, radius - ow * 0.5, body_color)
		var belly: Color = body_color.lightened(0.18)
		draw_circle(Vector2(-radius * 0.18, -radius * 0.15), radius * 0.62, belly)
		draw_circle(Vector2(0.0, -radius), radius * 0.14, horn_color)
		var er: float = maxf(2.0, radius * 0.13)
		for ex in [-0.32, 0.32]:
			draw_circle(Vector2(radius * ex, -radius * 0.22), er, Color.WHITE)
			draw_circle(Vector2(radius * ex, -radius * 0.22), er * 0.5, Color.BLACK)
	_draw_weapon()

func _draw_weapon():
	if dead:
		return
	var w: Dictionary = WEAPONS[weapon_index]
	var aim: float = aim_dir.angle()
	var fwd: Vector2 = Vector2(cos(aim), sin(aim))
	var side: Vector2 = Vector2(-sin(aim), cos(aim))
	if w["type"] == "melee":
		var reach: float = float(w["reach"])
		var arc: float = float(w["arc"])
		if _swing_timer > 0.0:
			var a0: float = aim - arc * 0.5
			var col: Color = Color(1.0, 1.0, 1.0, 0.45)
			var pts: PackedVector2Array = PackedVector2Array()
			pts.append(Vector2.ZERO)
			for i in range(9):
				var t: float = float(i) / 8.0
				var ang: float = a0 + arc * t
				pts.append(Vector2(cos(ang), sin(ang)) * reach)
			draw_polygon(pts, _fill_col(col, pts.size()))
		var tip: Vector2 = fwd * (radius + 14.0)
		if w["id"] == 2:
			draw_line(fwd * radius * 0.4, tip, Color(0.8, 0.85, 0.9), 4.0)
			draw_circle(tip, 5.0, Color(0.9, 0.95, 1.0))
		else:
			draw_line(fwd * radius * 0.4, tip, Color(0.6, 0.4, 0.2), 7.0)
			draw_rect(Rect2(tip - side * 8.0 - fwd * 6.0, Vector2(22.0, 16.0)), Color(0.5, 0.35, 0.18))
	else:
		var len: float = radius + 18.0
		var col: Color = Color(0.2, 0.2, 0.25)
		if w["id"] == 1:
			col = Color(0.1, 0.1, 0.15)
			draw_line(fwd * (radius * 0.3), fwd * len, col, 7.0)
		else:
			draw_line(fwd * (radius * 0.3), fwd * len, col, 5.0)
