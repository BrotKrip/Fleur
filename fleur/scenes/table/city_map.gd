class_name CityMap
extends Control
## Лист с картой Кур-де-Фонтейна: город на воде, кольца каналов и крест гидромагистралей.
## Места — латунные булавки. Шляпа Флёра показывает, где он сейчас.

signal pin_clicked(loc: String)

var hover_loc := ""
var hat_pos := Vector2.ZERO
var _hat_target := Vector2.ZERO
var _t := 0.0
var _chart: Texture2D

const CHART_PATH := "res://assets/art/maps/fontaine_chart.png"


func _ready() -> void:
	size = Vector2(440, 420)
	pivot_offset = size / 2
	rotation = -0.018
	mouse_filter = Control.MOUSE_FILTER_STOP
	hat_pos = pin_local(str(Game.state.get("here", "loc_apartment")))
	_hat_target = hat_pos
	tooltip_text = ""
	if ResourceLoader.exists(CHART_PATH):
		_chart = load(CHART_PATH) as Texture2D


func pin_local(loc: String) -> Vector2:
	var p = Content.def(loc).get("pin", [0.5, 0.5])
	return Vector2(float(p[0]) * size.x, float(p[1]) * size.y)


func locations() -> Array:
	var out := []
	for id in Game.state["cards"]:
		if Rules.is_location(id):
			out.append(id)
	return out


func pin_at_local(p: Vector2) -> String:
	for loc in locations():
		if pin_local(loc).distance_to(p) < 22:
			return loc
	return ""


## Булавка под точкой экрана (для бросания карт на карту).
func pin_at_global(gp: Vector2) -> String:
	return pin_at_local(get_global_transform().affine_inverse() * gp)


func move_hat(loc: String) -> void:
	_hat_target = pin_local(loc)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		var h := pin_at_local(e.position)
		if h != hover_loc:
			hover_loc = h
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if h != "" else Control.CURSOR_ARROW
			queue_redraw()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var loc := pin_at_local(e.position)
		if loc != "":
			pin_clicked.emit(loc)
		accept_event()


func _process(delta: float) -> void:
	_t += delta
	if hat_pos.distance_to(_hat_target) > 0.5:
		hat_pos = hat_pos.lerp(_hat_target, 1.0 - exp(-6.0 * delta))
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var sheet := Look.torn_rect(r, 77, true, true, 2.5)
	Look.soft_shadow(self, sheet, Vector2(6, 9), 10, 0.55)
	Look.fill_v(self, sheet, Color("efe3c4"), Color("dccaa0"))
	if _chart:
		# Пропорции исходного плана важны для дворца, аквабусных линий и порта.
		var area := Rect2(Vector2(4, 42), size - Vector2(8, 48))
		var chart_size := _chart.get_size()
		var scale_factor := minf(area.size.x / chart_size.x, area.size.y / chart_size.y)
		chart_size *= scale_factor
		draw_texture_rect(_chart, Rect2(area.get_center() - chart_size / 2.0, chart_size), false)
	else:
		_draw_procedural_chart()
	_draw_cartouche()
	_draw_pins()
	_draw_hat()


func _draw_procedural_chart() -> void:
	# Запасная подложка для проекта без импортированного арта.
	# пятна и потёртости
	draw_circle(Vector2(360, 70), 40, Color(0.6, 0.45, 0.2, 0.06))
	draw_circle(Vector2(80, 340), 55, Color(0.6, 0.45, 0.2, 0.05))

	var c := Vector2(size.x / 2, size.y / 2 + 6)
	var water := Color("8fb8c0")
	var water_dark := Color("6d9aa6")
	# озеро
	draw_colored_polygon(Look.ellipse(c, Vector2(205, 185), 64), Color(water, 0.55))
	for i in 4:
		draw_arc(c, 175 + i * 7, 0, TAU, 64, Color(water_dark, 0.25), 1.0, true)
	# город
	var stone := Color("d8ccb0")
	draw_circle(c, 150, Color("8a7a5a"))
	draw_circle(c, 146, stone)
	# кварталы (штриховка)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 160:
		var a := rng.randf() * TAU
		var rad := rng.randf_range(30, 140)
		var p := c + Vector2(cos(a), sin(a)) * rad
		draw_rect(Rect2(p, Vector2(rng.randf_range(5, 11), rng.randf_range(4, 8))), Color(0.55, 0.45, 0.32, 0.35))
	# кольца каналов и крест магистралей
	draw_arc(c, 104, 0, TAU, 80, water_dark, 7.0, true)
	draw_arc(c, 58, 0, TAU, 64, water_dark, 6.0, true)
	for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(c + dir * 22, c + dir * 200, water_dark, 9.0, true)
	draw_circle(c, 22, stone)
	draw_circle(c, 7, Color("7a6a4a"))
	# стены и башни
	draw_arc(c, 148, 0, TAU, 96, Color("6e6250"), 3.0, true)
	for i in 12:
		var a := TAU * i / 12.0
		var tp := c + Vector2(cos(a), sin(a)) * 148
		draw_circle(tp, 5, Color("4f8c84"))



func _draw_cartouche() -> void:
	# Надписи не запечены в картинку и остаются резкими при масштабировании.
	var title_rect := Rect2(80, 9, size.x - 160, 31)
	draw_colored_polygon(Look.rrect(title_rect, 4), Color(0.96, 0.91, 0.79, 0.78))
	Look.text_c(self, Look.font("serif_italic"), size.x / 2, 32, "Кур-де-Фонтейн", 22, Color("493b2c"))
	draw_line(Vector2(112, 39), Vector2(size.x - 112, 39), Color(0.54, 0.42, 0.25, 0.38), 0.8, true)
	Look.text_c(self, Look.font("hand"), 70, size.y - 22, "Море", 13, Color(0.22, 0.31, 0.33, 0.9))
	# Маленькая латунная роза ветров на чистом поле листа.
	var rc := Vector2(size.x - 44, size.y - 46)
	draw_circle(rc, 24, Color(0.96, 0.92, 0.81, 0.86))
	draw_arc(rc, 19, 0, TAU, 48, Color(0.45, 0.36, 0.23, 0.45), 0.8, true)
	draw_colored_polygon(PackedVector2Array([rc + Vector2(0, -22), rc + Vector2(5, 0), rc, rc + Vector2(-5, 0)]), Color("665337"))
	draw_colored_polygon(PackedVector2Array([rc, rc + Vector2(5, 0), rc + Vector2(0, 22), rc + Vector2(-5, 0)]), Color("b8a47b"))
	draw_colored_polygon(PackedVector2Array([rc + Vector2(-22, 0), rc + Vector2(0, -5), rc + Vector2(22, 0), rc + Vector2(0, 5)]), Color(0.42, 0.34, 0.23, 0.65))
	draw_circle(rc, 2.2, Color("59492f"))
	Look.text_c(self, Look.font("serif"), rc.x, rc.y - 26, "С", 12, Color("6a5030"))


func _draw_pins() -> void:
	var here := str(Game.state.get("here", ""))
	for loc in locations():
		var p := pin_local(loc)
		var hov: bool = loc == hover_loc
		var title := Rules.title_of(loc, Game.state)
		var people: Array = Rules.people_at(Game.state, loc)
		var fresh: bool = Game.state["cards"][loc].get("fresh", false)
		# подпись на бумажке
		var f := Look.font("serif")
		var fs := 15 if hov else 13
		var tw := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 14
		var label_x := clampf(p.x - tw / 2, 8.0, size.x - tw - 8.0)
		var lr := Rect2(Vector2(label_x, p.y + 12), Vector2(tw, 21))
		draw_colored_polygon(Look.rrect(Rect2(lr.position + Vector2(1, 2), lr.size), 2), Color(0.18, 0.14, 0.08, 0.18))
		draw_colored_polygon(Look.rrect(lr, 2), Color(0.98, 0.95, 0.87, 0.98 if hov else 0.94))
		draw_rect(lr.grow(-0.5), Color(0.56, 0.43, 0.23, 0.75 if loc == here else 0.3), false, 0.8)
		draw_string(f, lr.position + Vector2(0, 15), title, HORIZONTAL_ALIGNMENT_CENTER, tw, fs, Look.INK)
		if hov and people.size() > 0:
			var names := []
			for pid in people:
				names.append(Rules.title_of(pid, Game.state))
			Look.text_c(self, Look.font("hand"), p.x, lr.end.y + 15, "здесь: " + ", ".join(PackedStringArray(names)), 12, Color("2d3a5a"), 260)
		# булавка
		var rad := 9.0 if hov else 7.5
		draw_circle(p + Vector2(2, 3), rad, Color(0, 0, 0, 0.35))
		Look.brass_circle(self, p, rad)
		draw_circle(p + Vector2(-1, -1), 1.6, Color(1.0, 0.95, 0.72, 0.85))
		if loc == here:
			draw_arc(p, rad + 5, 0, TAU, 32, Look.WAX, 2.5, true)
		if fresh:
			draw_arc(p, rad + 9 + sin(_t * 4) * 2, 0, TAU, 32, Color(1, 0.8, 0.3, 0.7), 2.0, true)
		if people.size() > 0 and not hov:
			draw_circle(p + Vector2(10, -9), 6, Color("2d3a5a"))
			Look.text_c(self, Look.font("sans"), p.x + 10, p.y - 5, str(people.size()), 10, Color.WHITE, 20)


func _draw_hat() -> void:
	var p := hat_pos + Vector2(0, -24 + sin(_t * 2.2) * 2)
	draw_colored_polygon(Look.ellipse(p + Vector2(2, 20), Vector2(14, 4), 20), Color(0, 0, 0, 0.25))
	draw_colored_polygon(Look.ellipse(p + Vector2(0, 6), Vector2(18, 5), 24), Color("1e2c4f"))
	draw_colored_polygon(Look.rrect(Rect2(p + Vector2(-9, -8), Vector2(18, 14)), 5), Color("24365e"))
	draw_line(p + Vector2(-9, 3), p + Vector2(9, 3), Look.GOLD, 2.0)
	draw_polyline(PackedVector2Array([p + Vector2(6, -2), p + Vector2(14, -14), p + Vector2(22, -18)]), Color("f4f0e8"), 3.0, true)
