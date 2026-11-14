class_name TimeDial
extends Control
## Латунные настольные часы с четырьмя частями дня и отрывной календарь.
## Щелчок по часам — переждать часть дня.

signal wait_requested

const PHASE_ANGLES := [-PI * 0.75, -PI * 0.25, PI * 0.25, PI * 0.75]

var hand_angle := 0.0
var hovered := false
var _t := 0.0


func _ready() -> void:
	size = Vector2(290, 210)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "Переждать: пусть пройдёт часть дня"
	hand_angle = PHASE_ANGLES[int(Game.state["phase"])]
	mouse_entered.connect(func():
		hovered = true)
	mouse_exited.connect(func():
		hovered = false)


func refresh() -> void:
	var target: float = PHASE_ANGLES[int(Game.state["phase"])]
	while target < hand_angle - 0.01:
		target += TAU
	var tw := create_tween()
	tw.tween_property(self, "hand_angle", target, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if Vector2(100, 105).distance_to(e.position) < 92:
			wait_requested.emit()
		accept_event()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var c := Vector2(100, 105)
	var phase := int(Game.state["phase"])
	# календарь
	var cal := Rect2(196, 30, 84, 104)
	var calp := Look.rrect(cal, 3)
	Look.soft_shadow(self, calp, Vector2(4, 6), 6, 0.5)
	Look.fill_v(self, calp, Color("f7f1e2"), Color("e7dcc5"))
	Look.texture_polygon(self, calp, Art.surface("paper"), 1.0, Color(1, 1, 1, 0.72))
	for y in [cal.end.y + 2, cal.end.y + 4]:
		draw_line(Vector2(cal.position.x + 3, y), Vector2(cal.end.x - 3, y), Color(0.64, 0.55, 0.40, 0.8), 1.0, true)
	draw_colored_polygon(Look.rrect(Rect2(cal.position, Vector2(cal.size.x, 24)), 3), Color("8c2a22"))
	for x in [cal.position.x + 13, cal.end.x - 13]:
		draw_circle(Vector2(x, cal.position.y + 4), 2.6, Color("4d2219"))
		draw_line(Vector2(x, cal.position.y - 4), Vector2(x, cal.position.y + 4), Color("bda67b"), 2.0, true)
	var wd: String = ["ПОНЕДЕЛЬНИК", "ВТОРНИК", "СРЕДА", "ЧЕТВЕРГ", "ПЯТНИЦА", "СУББОТА", "ВОСКРЕСЕНЬЕ"][(int(Game.state["day"]) - 1) % 7]
	Look.text_c(self, Look.font("serif"), cal.get_center().x, cal.position.y + 17, wd, 10, Color("f3d9c0"))
	Look.text_c(self, Look.font("serif_bold"), cal.get_center().x, cal.position.y + 78, str(int(Game.state["day"])), 46, Color("3a1a14"))
	Look.text_c(self, Look.font("serif_italic"), cal.get_center().x, cal.position.y + 98, Rules.PHASES[phase].to_lower(), 13, Look.INK_SOFT)

	# корпус часов
	var lift := 3.0 if hovered else 0.0
	Look.soft_shadow(self, Look.ellipse(c, Vector2(92, 92), 80), Vector2(4, 7 + lift), 8, 0.6)
	Look.fill_v(self, Look.ellipse(c, Vector2(92, 92), 96), Color("d3b36d"), Color("5c401d"))
	draw_arc(c, 91, -2.8, -0.2, 64, Color("e6ce91"), 1.2, true)
	draw_circle(c, 86, Color("594021"))
	Look.fill_v(self, Look.ellipse(c, Vector2(84, 84), 96), Color("e8d29a"), Color("92703a"))
	draw_circle(c, 79, Color("5c442b"))
	draw_circle(c, 77, Color("f2e8d0"))
	Look.texture_polygon(self, Look.ellipse(c, Vector2(77, 77), 80), Art.surface("paper"), 1.0, Color(1, 1, 1, 0.72))
	# Насечка металлического обода и тонкая минутная шкала под стеклом.
	for i in 60:
		var a := TAU * i / 60.0
		var dir := Vector2(sin(a), -cos(a))
		draw_line(c + dir * 87, c + dir * 90, Color(0.27, 0.19, 0.08, 0.32), 1.0, true)
	# сектора частей дня
	var cols := [Color("f2d9a0"), Color("f7f0c8"), Color("e8a76a"), Color("4a5578")]
	for i in 4:
		var a0: float = PHASE_ANGLES[i] - PI / 4
		var pts := PackedVector2Array([c])
		for k in 17:
			var a := a0 + (PI / 2) * k / 16.0
			pts.append(c + Vector2(cos(a), sin(a)) * 74)
		var col: Color = cols[i]
		col.a = 0.95 if i == phase else 0.35
		draw_colored_polygon(pts, col)
		draw_line(c, c + Vector2(cos(a0), sin(a0)) * 76, Color(0.4, 0.3, 0.15, 0.5), 1.0)
		var lp := c + Vector2(cos(PHASE_ANGLES[i]), sin(PHASE_ANGLES[i])) * 50
		var tc := Look.INK if i != 3 or i != phase else Color("e8e0f0")
		if i == 3 and i == phase:
			tc = Color("eef0ff")
		Look.text_c(self, Look.font("serif_bold" if i == phase else "serif"), lp.x, lp.y + 6, Rules.PHASES[i], 15 if i == phase else 13, tc)
	for i in 60:
		var a := TAU * i / 60.0
		var dir := Vector2(sin(a), -cos(a))
		draw_line(c + dir * (67 if i % 5 == 0 else 71), c + dir * 74, Color(0.27, 0.23, 0.17, 0.60), 1.4 if i % 5 == 0 else 0.75, true)
	draw_arc(c, 64, 0, TAU, 96, Color(0.47, 0.37, 0.23, 0.2), 1.0, true)
	# символы солнца и луны
	var sun := c + Vector2(cos(PHASE_ANGLES[1]), sin(PHASE_ANGLES[1])) * 28
	draw_circle(sun, 6, Color(0.85, 0.6, 0.15, 0.8))
	var moon := c + Vector2(cos(PHASE_ANGLES[3]), sin(PHASE_ANGLES[3])) * 28
	draw_circle(moon, 6, Color(0.9, 0.9, 1.0, 0.85))
	draw_circle(moon + Vector2(3, -2), 5, cols[3] if phase != 3 else Color("4a5578"))
	# стрелка
	var tip := c + Vector2(cos(hand_angle), sin(hand_angle)) * 66
	var tail := c - Vector2(cos(hand_angle), sin(hand_angle)) * 15
	draw_line(tail + Vector2(1.5, 2), tip + Vector2(1.5, 2), Color(0.1, 0.07, 0.03, 0.23), 5.0, true)
	draw_line(tail, tip, Color("2a1f17"), 4.0, true)
	draw_line(c, tip - Vector2(cos(hand_angle), sin(hand_angle)) * 8, Color("9b8152"), 1.0, true)
	draw_colored_polygon(PackedVector2Array([tip + Vector2(cos(hand_angle + 2.6), sin(hand_angle + 2.6)) * 10, tip + Vector2(cos(hand_angle), sin(hand_angle)) * 6, tip + Vector2(cos(hand_angle - 2.6), sin(hand_angle - 2.6)) * 10]), Color("2a1f17"))
	Look.brass_circle(self, c, 8)
	# блик стекла
	draw_arc(c, 70, -2.6, -1.6, 20, Color(1, 1, 1, 0.35), 4.0, true)
	if hovered:
		draw_arc(c, 95 + sin(_t * 4.0) * 1.5, 0, TAU, 64, Color(1, 0.85, 0.45, 0.6), 2.0, true)
