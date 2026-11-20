class_name TimeDial
extends Control
## Латунные настольные часы с четырьмя частями дня и отрывной календарь.
## Щелчок по часам — переждать часть дня.

signal wait_requested

const PHASE_ANGLES := [-PI * 0.75, -PI * 0.25, PI * 0.25, PI * 0.75]
const CLOCK_CENTER := Vector2(100, 105)
const CALENDAR := Rect2(218, 38, 94, 121)
const WEEKDAYS := ["Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота", "Воскресенье"]

var hand_angle := 0.0
var hovered := false
var _t := 0.0
var _clock: Texture2D
var _calendar: Texture2D


func _ready() -> void:
	_clock = Art.prop("desk_chronometer")
	_calendar = Art.prop("desk_calendar")
	size = Vector2(316, 210)
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
		if CLOCK_CENTER.distance_to(e.position) < 92:
			wait_requested.emit()
		accept_event()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var phase := int(Game.state["phase"])
	_draw_calendar(int(Game.state["day"]), phase)
	_draw_clock(phase)


func _draw_calendar(day: int, phase: int) -> void:
	var center_x := CALENDAR.get_center().x
	Look.soft_shadow(self, Look.rrect(CALENDAR.grow(-1), 3), Vector2(3, 5), 4, 0.45)
	if _calendar:
		draw_texture_rect(_calendar, CALENDAR, false)
	else:
		draw_rect(CALENDAR, Color("f3e6c8"))
		draw_rect(Rect2(CALENDAR.position, Vector2(CALENDAR.size.x, 16)), Color("78362b"))
	var weekday: String = WEEKDAYS[posmod(day - 1, WEEKDAYS.size())]
	Look.text_c(self, Look.font("sans"), center_x, CALENDAR.position.y + 39, weekday, 13, Color("673a30"), CALENDAR.size.x - 10)
	Look.text_c(self, Look.font("serif"), center_x, CALENDAR.position.y + 90, str(day), 51, Color("34271e"), CALENDAR.size.x - 12)
	Look.text_c(self, Look.font("serif_italic"), center_x, CALENDAR.end.y - 9, Rules.PHASES[phase].to_lower(), 14, Color("544032"), CALENDAR.size.x - 20)


func _draw_clock(phase: int) -> void:
	var c := CLOCK_CENTER
	Look.soft_shadow(self, Look.ellipse(c, Vector2(90, 90), 72), Vector2(3, 5), 6, 0.47)
	if _clock:
		draw_texture_rect(_clock, Rect2(c - Vector2(92, 92), Vector2(184, 184)), false)
	else:
		draw_circle(c, 92, Color("9e7950"), true, -1, true)
		draw_circle(c, 78, Color("eadcc0"), true, -1, true)
	# Отдельное поле для каждой части дня; стрелка движется внутри свободного центра.
	for i in 4:
		var dir := Vector2.from_angle(PHASE_ANGLES[i])
		var mark := c + Vector2(signf(dir.x) * 35, signf(dir.y) * 34)
		var ink := Color("715239") if i == phase else Color("525051")
		_draw_phase_mark(mark - Vector2(0, 7), i, ink)
		Look.text_c(self, Look.font("serif_bold" if i == phase else "serif"), mark.x, mark.y + 13, Rules.PHASES[i], 16, Color("302b2a"), 53)
	var direction := Vector2.from_angle(hand_angle)
	draw_arc(c, 69, hand_angle - 0.10, hand_angle + 0.10, 12, Color("87643d"), 1.4, true)
	var side := direction.orthogonal()
	var hand := PackedVector2Array([c - direction * 11, c + direction * 8 + side * 3.3, c + direction * 25, c + direction * 8 - side * 3.3])
	draw_colored_polygon(hand, Color("233f4a"))
	draw_line(c, c + direction * 21, Color("c3a46a"), 1.15, true)
	draw_circle(c, 4.8, Color("66482e"), true, -1, true)
	draw_circle(c, 3.5, Color("cbaa67"), true, -1, true)
	draw_circle(c - Vector2(0.8, 0.8), 1.4, Color("eedd98"), true, -1, true)
	if hovered:
		draw_arc(c, 92, 0, TAU, 96, Color(1, 0.88, 0.63, 0.54 + sin(_t * 3.0) * 0.08), 1.8, true)


func _draw_phase_mark(p: Vector2, phase: int, ink: Color) -> void:
	# Эмблемы выгравированы на эмали: восход, полуденное солнце, закат и серп луны.
	if phase == 3:
		draw_arc(p, 7, deg_to_rad(69), deg_to_rad(291), 24, ink, 1.3, true)
		draw_arc(p + Vector2(5, 0), 7, deg_to_rad(111), deg_to_rad(249), 16, ink, 1.3, true)
		return
	if phase == 1:
		draw_arc(p, 4, 0, TAU, 18, ink, 1.2, true)
		for k in 8:
			var ray := Vector2.from_angle(k * TAU / 8)
			draw_line(p + ray * 6, p + ray * 8, ink, 1.2, true)
		return
	var horizon := p + Vector2(0, 2)
	draw_arc(horizon, 4.5, PI, TAU, 16, ink, 1.25, true)
	draw_line(horizon - Vector2(9, 0), horizon + Vector2(9, 0), ink, 1.2, true)
	if phase == 0:
		for k in 3:
			var ray := Vector2.from_angle(-PI * 0.75 + k * PI * 0.25)
			draw_line(horizon + ray * 6, horizon + ray * 8.3, ink, 1.1, true)
	else:
		draw_line(horizon + Vector2(-5, 3), horizon + Vector2(5, 3), ink, 1.1, true)
