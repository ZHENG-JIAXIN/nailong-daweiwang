extends Control
class_name JoystickOverlay
# 双浮动摇杆绘制层：只负责画，不做输入判定。
# 坐标与 viewport 一致（覆盖全屏），由 main.gd 的 _sync_joysticks() 喂状态。
# 注意：BASE_R 需与 main.gd 的 JOY_BASE_R 保持一致。

const BASE_R: float = 104.0
const KNOB_R: float = 44.0

var left_active: bool = false
var left_origin: Vector2 = Vector2.ZERO
var left_knob: Vector2 = Vector2.ZERO
var right_active: bool = false
var right_origin: Vector2 = Vector2.ZERO
var right_knob: Vector2 = Vector2.ZERO

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_state(l_on: bool, l_o: Vector2, l_k: Vector2, r_on: bool, r_o: Vector2, r_k: Vector2):
	left_active = l_on
	left_origin = l_o
	left_knob = l_k
	right_active = r_on
	right_origin = r_o
	right_knob = r_k
	queue_redraw()

func _draw():
	if left_active:
		_draw_stick(left_origin, left_knob, Color(0.20, 0.70, 0.95, 0.22), Color(0.20, 0.70, 0.95, 0.72))
	if right_active:
		_draw_stick(right_origin, right_knob, Color(1.0, 0.52, 0.20, 0.22), Color(1.0, 0.52, 0.20, 0.72))

func _draw_stick(o: Vector2, k: Vector2, base_col: Color, knob_col: Color):
	draw_circle(o, BASE_R, base_col)
	draw_arc(o, BASE_R, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.40), 3.0)
	draw_circle(k, KNOB_R, knob_col)
	draw_arc(k, KNOB_R, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.55), 2.0)
