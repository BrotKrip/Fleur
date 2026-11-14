class_name Look
extends RefCounted
## Визуальный язык игры: палитра, шрифты, тема и процедурное рисование (бумага, тени, латунь).
## Бумага, металл и рамки дополняют заменяемые иллюстрации из assets/art.

const INK := Color("2a1f17")
const INK_SOFT := Color("5b4a3a")
const PENCIL := Color("6b6258")
const PAPER := Color("efe5cf")
const PAPER_DARK := Color("d9cbae")
const NEWSPRINT := Color("e2dac8")
const GOLD := Color("c9a94a")
const BRASS := Color("b48a3a")
const BRASS_DARK := Color("6e5220")
const WAX := Color("8c1d22")
const LIGHT_TEXT := Color("efe6d2")
const MUTED := Color("a99c86")
const GOOD := Color("4f7a4a")
const BAD := Color("8e3a2e")

static var _fonts := {}
static var _theme: Theme


static func font(kind: String) -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var f := SystemFont.new()
	match kind:
		"serif":
			f.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Book Antiqua", "Times New Roman"])
		"serif_bold":
			f.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Times New Roman"])
			f.font_weight = 700
		"serif_italic":
			f.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Times New Roman"])
			f.font_italic = true
		"hand":
			f.font_names = PackedStringArray(["Segoe Script", "Segoe Print", "Gabriola", "Georgia"])
		"type":
			f.font_names = PackedStringArray(["Courier New", "Consolas", "Lucida Console"])
		_:
			f.font_names = PackedStringArray(["Segoe UI", "Arial"])
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	_fonts[kind] = f
	return f


# ---------------------------------------------------------------- тема

static func paper_box(color := PAPER, shadow := 18, margin := 22) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = color.darkened(0.18)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = shadow
	sb.shadow_offset = Vector2(6, 10)
	sb.set_content_margin_all(margin)
	return sb


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font("serif")
	t.default_font_size = 19
	t.set_color("font_color", "Label", LIGHT_TEXT)

	# Надписи на бумаге
	t.set_type_variation("Ink", "Label")
	t.set_color("font_color", "Ink", INK)
	t.set_type_variation("InkSoft", "Label")
	t.set_color("font_color", "InkSoft", INK_SOFT)
	t.set_font_size("font_size", "InkSoft", 16)
	t.set_type_variation("Hand", "Label")
	t.set_color("font_color", "Hand", Color("2d3a5a"))
	t.set_font("font", "Hand", font("hand"))
	t.set_font_size("font_size", "Hand", 17)
	t.set_type_variation("InkTitle", "Label")
	t.set_color("font_color", "InkTitle", INK)
	t.set_font("font", "InkTitle", font("serif_bold"))
	t.set_font_size("font_size", "InkTitle", 26)
	t.set_type_variation("Kicker", "Label")
	t.set_color("font_color", "Kicker", Color(0.45, 0.36, 0.27))
	t.set_font_size("font_size", "Kicker", 14)

	# Кнопки по умолчанию — «латунные» таблички
	var bn := StyleBoxFlat.new()
	bn.bg_color = Color("3b2f1e")
	bn.border_color = BRASS
	bn.set_border_width_all(1)
	bn.set_corner_radius_all(3)
	bn.shadow_color = Color(0, 0, 0, 0.18)
	bn.shadow_size = 3
	bn.shadow_offset = Vector2(0, 2)
	bn.set_content_margin_all(10)
	bn.content_margin_left = 18
	bn.content_margin_right = 18
	var bh := bn.duplicate()
	bh.bg_color = Color("54422a")
	bh.border_color = GOLD
	bh.border_width_top = 2
	var bp := bn.duplicate()
	bp.bg_color = Color("2a2115")
	bp.shadow_size = 0
	bp.border_width_bottom = 2
	var bd := bn.duplicate()
	bd.bg_color = Color("2f2a24")
	bd.border_color = Color("5a4c35")
	t.set_stylebox("normal", "Button", bn)
	t.set_stylebox("hover", "Button", bh)
	t.set_stylebox("pressed", "Button", bp)
	t.set_stylebox("disabled", "Button", bd)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Color("f0dfae"))
	t.set_color("font_hover_color", "Button", Color("fff2c8"))
	t.set_color("font_pressed_color", "Button", Color("e0c98a"))
	t.set_color("font_disabled_color", "Button", Color("8a7c62"))

	# Строки на бумаге: «чернильные» кнопки без рамки
	t.set_type_variation("InkButton", "Button")
	var e := StyleBoxEmpty.new()
	e.set_content_margin_all(4)
	var eh := StyleBoxFlat.new()
	eh.bg_color = Color(0.55, 0.42, 0.2, 0.14)
	eh.set_corner_radius_all(2)
	eh.set_content_margin_all(4)
	for st in ["normal", "pressed", "disabled", "focus"]:
		t.set_stylebox(st, "InkButton", e)
	t.set_stylebox("hover", "InkButton", eh)
	var ink_focus := StyleBoxFlat.new()
	ink_focus.bg_color = Color(0.43, 0.33, 0.16, 0.06)
	ink_focus.border_color = Color(0.50, 0.36, 0.16, 0.65)
	ink_focus.set_border_width_all(1)
	ink_focus.set_corner_radius_all(2)
	t.set_stylebox("focus", "InkButton", ink_focus)
	t.set_color("font_color", "InkButton", INK)
	t.set_color("font_hover_color", "InkButton", Color("6a2416"))
	t.set_color("font_pressed_color", "InkButton", Color("6a2416"))
	t.set_color("font_disabled_color", "InkButton", Color(0.35, 0.3, 0.25, 0.55))

	# Пункты главного меню — крупный текст без подложки
	t.set_type_variation("MenuItem", "Button")
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var m := StyleBoxEmpty.new()
		m.set_content_margin_all(6)
		t.set_stylebox(st, "MenuItem", m)
	t.set_font_size("font_size", "MenuItem", 30)
	t.set_color("font_color", "MenuItem", Color("d8ccb4"))
	t.set_color("font_hover_color", "MenuItem", Color("f3d98c"))
	t.set_color("font_pressed_color", "MenuItem", GOLD)
	t.set_color("font_disabled_color", "MenuItem", Color(0.6, 0.55, 0.5, 0.35))
	var menu_hover := StyleBoxFlat.new()
	menu_hover.bg_color = Color(0.83, 0.7, 0.43, 0.1)
	menu_hover.border_color = Color("d5b776")
	menu_hover.border_width_left = 2
	menu_hover.content_margin_left = 16
	menu_hover.content_margin_right = 16
	menu_hover.content_margin_top = 6
	menu_hover.content_margin_bottom = 6
	t.set_stylebox("hover", "MenuItem", menu_hover)
	t.set_stylebox("focus", "MenuItem", menu_hover)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("e5c98c")
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(3)
	t.set_stylebox("focus", "Button", focus)

	t.set_stylebox("panel", "PanelContainer", paper_box())
	t.set_type_variation("Paper", "PanelContainer")
	t.set_stylebox("panel", "Paper", paper_box())

	# Подсказки — маленькая бумажка
	var tip := paper_box(Color("f4ecd9"), 8, 8)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", INK)
	t.set_font_size("font_size", "TooltipLabel", 16)

	# Ползунки и флажки на бумаге
	t.set_color("font_color", "CheckBox", INK)
	t.set_color("font_hover_color", "CheckBox", Color("6a2416"))
	t.set_color("font_pressed_color", "CheckBox", INK)
	t.set_color("font_focus_color", "CheckBox", INK)
	t.set_color("font_hover_pressed_color", "CheckBox", Color("6a2416"))
	for st in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		t.set_stylebox(st, "CheckBox", StyleBoxEmpty.new())
	var check_focus := ink_focus.duplicate() as StyleBoxFlat
	check_focus.expand_margin_left = 3
	check_focus.expand_margin_right = 3
	t.set_stylebox("focus", "CheckBox", check_focus)
	t.set_constant("h_separation", "CheckBox", 9)
	for icon_name in {"checked": "check_on", "unchecked": "check_off"}:
		var icon_file: String = {"checked": "check_on", "unchecked": "check_off"}[icon_name]
		var icon_path := "res://ui/icons/" + icon_file + ".svg"
		if ResourceLoader.exists(icon_path):
			t.set_icon(icon_name, "CheckBox", load(icon_path))
	var slider_track := StyleBoxFlat.new()
	slider_track.bg_color = Color("c8b995")
	slider_track.border_color = Color("ac966e")
	slider_track.set_border_width_all(1)
	slider_track.set_corner_radius_all(3)
	slider_track.content_margin_top = 3
	slider_track.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", slider_track)
	var slider_fill := slider_track.duplicate() as StyleBoxFlat
	slider_fill.bg_color = Color("456866")
	slider_fill.border_color = Color("345250")
	t.set_stylebox("grabber_area", "HSlider", slider_fill)
	var slider_hot := slider_fill.duplicate() as StyleBoxFlat
	slider_hot.bg_color = Color("59807b")
	t.set_stylebox("grabber_area_highlight", "HSlider", slider_hot)
	if ResourceLoader.exists("res://ui/icons/slider_knob.svg"):
		for state_name in ["grabber", "grabber_highlight", "grabber_disabled"]:
			t.set_icon(state_name, "HSlider", load("res://ui/icons/slider_knob.svg"))
	_theme = t
	return t


# ---------------------------------------------------------------- геометрия

## Заполнение прямоугольника без искажения пропорций изображения.
static func draw_cover(ci: CanvasItem, texture: Texture2D, rect: Rect2, tint := Color.WHITE) -> void:
	if not texture or rect.size.x <= 0 or rect.size.y <= 0:
		return
	var ts := texture.get_size()
	var factor := maxf(rect.size.x / ts.x, rect.size.y / ts.y)
	var source_size := rect.size / factor
	ci.draw_texture_rect_region(texture, rect, Rect2((ts - source_size) * 0.5, source_size), tint)


## Материал внутри произвольного контура, без выхода за рваные/скруглённые края.
## scale > 1 приближает текстуру; исходные пропорции сохраняются.
static func texture_polygon(ci: CanvasItem, pts: PackedVector2Array, texture: Texture2D, scale := 1.0, tint := Color.WHITE) -> void:
	if not texture or pts.size() < 3:
		return
	var bounds := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		bounds = bounds.expand(p)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	var source := Art.cover_region(texture, bounds.size)
	var crop_size := source.size / maxf(1.0, scale)
	source = Rect2(source.get_center() - crop_size * 0.5, crop_size)
	var uv := PackedVector2Array()
	for p in pts:
		uv.append((source.position + (p - bounds.position) / bounds.size * source.size) / texture.get_size())
	ci.draw_polygon(pts, PackedColorArray([tint]), uv, texture)


## Плавное золотое тиснение: компактный орнамент в четырёх углах рамки.
static func engraved_corners(ci: CanvasItem, rect: Rect2, color := GOLD, length := 22.0) -> void:
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
		var p: Vector2 = rect.position + rect.size * corner
		var dir: Vector2 = Vector2.ONE - corner * 2.0
		ci.draw_polyline(PackedVector2Array([p + Vector2(0, dir.y * length), p, p + Vector2(dir.x * length, 0)]), color, 1.0, true)
		var mid := p + dir * 5.0
		ci.draw_colored_polygon(PackedVector2Array([mid + Vector2(-2, 0), mid + Vector2(0, -3), mid + Vector2(2, 0), mid + Vector2(0, 3)]), color)


## Верх спрайта в овальной фотографической рамке; UV обрезаются самой рамкой.
static func draw_portrait(ci: CanvasItem, texture: Texture2D, center: Vector2, radii: Vector2) -> void:
	var pts := ellipse(center, radii, 64)
	var uv := PackedVector2Array()
	var ts := texture.get_size()
	var source_w := ts.x * 0.86
	var source_h := minf(ts.y * 0.72, source_w * radii.y / radii.x)
	var source := Rect2((ts.x - source_w) * 0.5, ts.y * 0.015, source_w, source_h)
	for point in pts:
		var normalized := (point - center + radii) / (radii * 2.0)
		uv.append((source.position + normalized * source.size) / ts)
	ci.draw_polygon(pts, PackedColorArray([Color.WHITE]), uv, texture)

static func rrect(r: Rect2, rad: float, seg := 5) -> PackedVector2Array:
	var pts := PackedVector2Array()
	rad = minf(rad, minf(r.size.x, r.size.y) * 0.5)
	if rad <= 0.5:
		return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var corners := [
		[Vector2(r.end.x - rad, r.position.y + rad), -PI / 2],
		[Vector2(r.end.x - rad, r.end.y - rad), 0.0],
		[Vector2(r.position.x + rad, r.end.y - rad), PI / 2],
		[Vector2(r.position.x + rad, r.position.y + rad), PI],
	]
	for c in corners:
		for i in seg + 1:
			var a: float = c[1] + (PI / 2) * float(i) / seg
			pts.append(c[0] + Vector2(cos(a), sin(a)) * rad)
	return pts


static func ellipse(center: Vector2, radii: Vector2, seg := 40) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in seg:
		var a := TAU * i / seg
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return pts


static func offset(pts: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + by)
	return out


## Мягкая тень многоугольника: несколько расширяющихся слоёв.
static func soft_shadow(ci: CanvasItem, pts: PackedVector2Array, off: Vector2, spread: float, alpha: float) -> void:
	var layers := 6
	for i in layers:
		var grow := spread * (1.0 - float(i) / layers)
		var poly := Geometry2D.offset_polygon(offset(pts, off), grow)
		var a := alpha / layers * 1.4
		for p in poly:
			if p.size() >= 3:
				ci.draw_colored_polygon(p, Color(0.02, 0.01, 0.0, a))


## Заливка с вертикальным градиентом.
static func fill_v(ci: CanvasItem, pts: PackedVector2Array, top: Color, bottom: Color) -> void:
	if pts.size() < 3:
		return
	var miny := INF
	var maxy := -INF
	for p in pts:
		miny = minf(miny, p.y)
		maxy = maxf(maxy, p.y)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(bottom, (p.y - miny) / maxf(1.0, maxy - miny)))
	ci.draw_polygon(pts, cols)


static func outline(ci: CanvasItem, pts: PackedVector2Array, col: Color, w := 1.0) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, col, w, true)


## Рваный/зубчатый край: прямоугольник, у которого верх и/или низ неровные.
static func torn_rect(r: Rect2, seed_val: int, top := true, bottom := true, amp := 3.0) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var pts := PackedVector2Array()
	var steps := int(r.size.x / 7.0)
	for i in steps + 1:
		var x := r.position.x + r.size.x * float(i) / steps
		pts.append(Vector2(x, r.position.y + (rng.randf_range(0, amp) if top else 0.0)))
	for i in steps + 1:
		var x := r.end.x - r.size.x * float(i) / steps
		pts.append(Vector2(x, r.end.y - (rng.randf_range(0, amp) if bottom else 0.0)))
	return pts


## Строки «текста» серыми полосками (газета, документ).
static func fake_lines(ci: CanvasItem, r: Rect2, col: Color, step := 7.0, seed_val := 1) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var y := r.position.y
	while y < r.end.y:
		var w := r.size.x * rng.randf_range(0.6, 1.0)
		ci.draw_line(Vector2(r.position.x, y), Vector2(r.position.x + w, y), col, 2.0)
		y += step


static func brass_circle(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_circle(c, r, BRASS_DARK)
	ci.draw_circle(c, r * 0.9, BRASS)
	ci.draw_circle(c + Vector2(-r * 0.25, -r * 0.3), r * 0.45, Color(1, 0.92, 0.6, 0.35))


static func text_c(ci: CanvasItem, f: Font, center_x: float, y: float, s: String, size: int, col: Color, width := -1.0) -> void:
	var w := width if width > 0 else 2000.0
	ci.draw_string(f, Vector2(center_x - w / 2.0, y), s, HORIZONTAL_ALIGNMENT_CENTER, w, size, col)


static func hash_seed(s: String) -> int:
	return abs(s.hash()) % 100000 + 1
