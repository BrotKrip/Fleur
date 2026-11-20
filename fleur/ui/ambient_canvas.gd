extends Control
## Лёгкая пыль перед декорацией. Статические функции рисуют орнамент на самих
## элементах интерфейса и не создают поверх текста узлы, перехватывающие ввод.

const BRASS := Color("c6a66b")
const PALE_BRASS := Color("e7c98c")
var _count := 12
var _elapsed := 0.0
var _accumulated := 0.0


func _init(particle_count := 12) -> void:
	_count = clampi(particle_count, 0, 20)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_elapsed += delta
	_accumulated += delta
	if _accumulated >= 1.0 / 18.0:
		_accumulated = 0.0
		queue_redraw()


func _draw() -> void:
	if size.x < 1 or size.y < 1:
		return
	for i in _count:
		var x := fposmod(i * 187.7 + sin(_elapsed * 0.085 + i) * 23.0, size.x)
		var y := fposmod(i * 117.1 - _elapsed * (2.7 + i * 0.17), size.y)
		var opacity := 0.11 + 0.08 * sin(_elapsed * 0.35 + i * 1.3)
		draw_circle(Vector2(x, y), 0.9 + (i % 3) * 0.4, Color(0.99, 0.88, 0.64, opacity))


static func _diamond(c: CanvasItem, center: Vector2, radius: Vector2, tint: Color) -> void:
	c.draw_colored_polygon(PackedVector2Array([
		center - Vector2(radius.x, 0), center - Vector2(0, radius.y),
		center + Vector2(radius.x, 0), center + Vector2(0, radius.y)]), tint)


static func _accent(c: CanvasItem, p: Vector2, sx: float, sy: float, reach: float) -> void:
	var d := Vector2(sx, sy)
	var line := Color(BRASS, 0.89)
	c.draw_polyline(PackedVector2Array([p + Vector2(reach, 0) * d, p + Vector2(9, 0) * d,
			p + Vector2(0, 9) * d, p + Vector2(0, reach) * d]), line, 1.3, true)
	c.draw_polyline(PackedVector2Array([p + Vector2(reach * 0.61, 4) * d, p + Vector2(10, 4) * d,
			p + Vector2(4, 10) * d, p + Vector2(4, reach * 0.61) * d]), Color(PALE_BRASS, 0.42), 1.0, true)
	_diamond(c, p + Vector2(10, 10) * d, Vector2(2.1, 2.1), PALE_BRASS)


static func corners(c: CanvasItem, bounds: Rect2, reach: float) -> void:
	_accent(c, bounds.position, 1, 1, reach)
	_accent(c, Vector2(bounds.end.x, bounds.position.y), -1, 1, reach)
	_accent(c, bounds.end, -1, -1, reach)
	_accent(c, Vector2(bounds.position.x, bounds.end.y), 1, -1, reach)


static func crest(c: Control) -> void:
	# Лилия из трёх гравированных лепестков; служит знаком титульного листа.
	var p := Vector2(17, c.size.y * 0.5)
	var ink := Color(PALE_BRASS, 0.92)
	c.draw_polyline(PackedVector2Array([p + Vector2(0, 14), p + Vector2(-2, 2), p + Vector2(-6, -7),
			p + Vector2(0, -18), p + Vector2(6, -7), p + Vector2(2, 2), p + Vector2(0, 14)]), ink, 1.7, true)
	for sign_x in [-1.0, 1.0]:
		var d := Vector2(sign_x, 1)
		c.draw_polyline(PackedVector2Array([p + Vector2(0, 9) * d, p + Vector2(3, 0) * d,
				p + Vector2(10, -7) * d, p + Vector2(15, -5) * d, p + Vector2(14, 0) * d,
				p + Vector2(10, 2) * d]), ink, 1.6, true)
	c.draw_line(p + Vector2(-7, 6), p + Vector2(7, 6), ink, 2.4, true)
	c.draw_line(p + Vector2(28, 0), p + Vector2(133, 0), Color(BRASS, 0.64), 1.0, true)
	_diamond(c, p + Vector2(139, 0), Vector2(4, 3), BRASS)


static func dialogue(c: Control, leather: Texture2D) -> void:
	var bounds := Rect2(Vector2.ZERO, c.size)
	if c.size.x < 40 or c.size.y < 40:
		return
	# Светлая кромка лака и более холодная нижняя часть, под текстом.
	Look.fill_v(c, Look.rrect(bounds.grow(-2), 2), Color(0.15, 0.32, 0.32, 0.36), Color(0.01, 0.03, 0.04, 0))
	if leather:
		Look.texture_polygon(c, Look.rrect(bounds.grow(-3), 2), leather, 1.0, Color(0.47, 0.67, 0.64, 0.23))
	c.draw_rect(bounds.grow(-6), Color(BRASS, 0.26), false, 1.0)
	corners(c, bounds.grow(-3), 33.0)
	var p := Vector2(c.size.x * 0.5, c.size.y - 9)
	for d in [-1.0, 1.0]:
		c.draw_line(p + Vector2(d * 10, 0), p + Vector2(d * 47, 0), Color(BRASS, 0.59), 1.0, true)
	_diamond(c, p, Vector2(5, 2.8), BRASS)


static func nameplate(c: Control) -> void:
	if c.size.x < 35:
		return
	for x in [12.0, c.size.x - 12.0]:
		_diamond(c, Vector2(x, c.size.y * 0.5), Vector2(2.4, 4.0), BRASS)
	c.draw_line(Vector2(6, c.size.y - 4), Vector2(c.size.x - 6, c.size.y - 4), Color(BRASS, 0.36), 1.0)


static var _haze: GradientTexture2D


## Мягкое тёмное пятно с растушёванными краями — подложка под надписью поверх фона.
static func haze() -> GradientTexture2D:
	if _haze == null:
		var g := Gradient.new()
		g.set_color(0, Color(0.02, 0.07, 0.09, 0.78))
		g.set_color(1, Color(0.02, 0.07, 0.09, 0.0))
		g.add_point(0.55, Color(0.02, 0.07, 0.09, 0.42))
		_haze = GradientTexture2D.new()
		_haze.gradient = g
		_haze.fill = GradientTexture2D.FILL_RADIAL
		_haze.fill_from = Vector2(0.5, 0.5)
		_haze.fill_to = Vector2(1.0, 0.5)
		_haze.width = 256
		_haze.height = 64
	return _haze


## Название места: надпись на растушёванной тени и латунная линейка, гаснущая вправо.
static func location(c: Control) -> void:
	if c.size.x < 30:
		return
	var w := c.size.x
	var h := c.size.y
	c.draw_texture_rect(haze(), Rect2(-70, -24, w + 150, h + 40), false)
	var y := h - 3.0
	c.draw_polyline_colors(PackedVector2Array([Vector2(24, y), Vector2(24 + (w - 24) * 0.55, y), Vector2(w + 30, y)]),
			PackedColorArray([Color(BRASS, 0.9), Color(BRASS, 0.55), Color(BRASS, 0.0)]), 1.2, true)
	_diamond(c, Vector2(13, y), Vector2(5.5, 3.2), PALE_BRASS)
	_diamond(c, Vector2(13, y), Vector2(2.4, 1.4), Color("173238"))


static func choice_badge(c: Button, index: int, paper: Texture2D) -> void:
	var y := c.size.y * 0.5
	var is_active := c.has_focus() or c.is_hovered()
	var ink := Color("234749") if is_active else Color("305256")
	# Бумага видна на полях, печатный текст остаётся нетронутым.
	if paper:
		Look.texture_polygon(c, Look.rrect(Rect2(3, 2, 45, c.size.y - 4), 1), paper, 1.0, Color(1, 1, 1, 0.45))
	c.draw_rect(Rect2(13, y - 13, 28, 26), ink)
	c.draw_rect(Rect2(15, y - 11, 24, 22), Color(BRASS, 0.60), false, 1.0)
	c.draw_string(Look.font("serif_bold"), Vector2(13, y + 5), str(index), HORIZONTAL_ALIGNMENT_CENTER, 28, 15, Color("f4e7bf"))
	c.draw_line(Vector2(50, 10), Vector2(50, c.size.y - 10), Color(0.45, 0.36, 0.22, 0.29), 1.0)


static func menu_mark(c: Button) -> void:
	var p := Vector2(15, c.size.y * 0.5)
	var active := c.has_focus() or c.is_hovered()
	_diamond(c, p, Vector2(4.5 if active else 3.0, 3), PALE_BRASS if active else Color(BRASS, 0.68))
	if active:
		c.draw_line(Vector2(c.size.x - 42, p.y), Vector2(c.size.x - 19, p.y), Color(BRASS, 0.82), 1.2, true)
		_diamond(c, Vector2(c.size.x - 16, p.y), Vector2(4.2, 2.6), PALE_BRASS)
