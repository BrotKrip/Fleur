class_name DeskProp
extends Control
## Мелкие вещи на столе, через которые доступны служебные функции:
## записная книжка (журнал), латунная табличка (меню), чернильница (украшение).

signal activated

var kind := "notebook"
var hovered := false
static var _sprite_regions: Dictionary = {}


func _init(k: String) -> void:
	kind = k


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	match kind:
		"notebook":
			size = Vector2(130, 150)
			tooltip_text = "Записная книжка: что было"
			rotation = 0.12
		"plaque":
			size = Vector2(120, 44)
			tooltip_text = "Меню, сохранение, настройки (Esc)"
		"inkwell":
			size = Vector2(110, 90)
	pivot_offset = size / 2
	mouse_filter = Control.MOUSE_FILTER_STOP if kind != "inkwell" else Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func():
		hovered = true
		queue_redraw())
	mouse_exited.connect(func():
		hovered = false
		queue_redraw())


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		activated.emit()
		accept_event()


func _draw() -> void:
	var lift := Vector2(0, -3) if hovered else Vector2.ZERO
	var artwork := Art.prop(kind)
	if artwork and kind in ["notebook", "inkwell"]:
		var area := Rect2(Vector2(6, 2) + lift, size - Vector2(12, 6))
		if kind == "inkwell":
			area = Rect2(0, -26, 110, 116)
		# Тень повторяет альфу самого предмета, а не прямоугольник картинки.
		draw_sprite(self, artwork, Rect2(area.position + Vector2(5, 7), area.size), Color(0.01, 0.015, 0.02, 0.42))
		var drawn := draw_sprite(self, artwork, area, Color(1.08, 1.04, 0.97) if hovered else Color.WHITE)
		if kind == "notebook":
			var cx := drawn.position.x + drawn.size.x * 0.46
			Look.text_c(self, Look.font("serif_italic"), cx, drawn.position.y + drawn.size.y * 0.48, "Записи", 15, Color("e2c98e"), drawn.size.x * 0.72)
		return
	match kind:
		"notebook":
			var r := Rect2(Vector2(10, 6) + lift, Vector2(104, 136))
			var p := Look.rrect(r, 5)
			Look.soft_shadow(self, p, Vector2(5, 8) - lift, 8, 0.55)
			Look.fill_v(self, p, Color("4a3a2a"), Color("2c2117"))
			draw_rect(Rect2(r.end.x - 4, r.position.y + 4, 4, r.size.y - 8), Color("efe6d0"))
			draw_line(Vector2(r.position.x + 70, r.position.y), Vector2(r.position.x + 70, r.end.y), Color(0.1, 0.07, 0.04, 0.8), 6.0)
			Look.text_c(self, Look.font("serif_italic"), r.get_center().x - 10, r.get_center().y + 6, "Записи", 15, Color("d9c08a"))
			# карандаш
			draw_line(Vector2(0, 130) + lift, Vector2(118, 112) + lift, Color("c9a23a"), 6.0, true)
			draw_line(Vector2(118, 112) + lift, Vector2(128, 110) + lift, Color("2a2018"), 3.0, true)
		"plaque":
			var r2 := Rect2(Vector2(2, 2) + lift, size - Vector2(4, 4))
			var p2 := Look.rrect(r2, 4)
			Look.soft_shadow(self, p2, Vector2(3, 5), 5, 0.5)
			Look.fill_v(self, p2, Look.BRASS.lightened(0.15 if hovered else 0.0), Look.BRASS_DARK)
			Look.outline(self, Look.rrect(r2.grow(-4), 3), Color(1, 0.9, 0.6, 0.5))
			for sx in [10.0, size.x - 10.0]:
				draw_circle(Vector2(sx, size.y / 2) + lift, 3, Look.BRASS_DARK)
			Look.text_c(self, Look.font("serif_bold"), size.x / 2, size.y / 2 + 6 + lift.y, "Меню", 16, Color("2a1d0c"))
		"inkwell":
			var c := Vector2(55, 52)
			draw_circle(c + Vector2(6, 9), 32, Color(0, 0, 0, 0.35))
			draw_circle(c, 32, Color("1a2230"))
			draw_circle(c, 25, Color("0b0f18"))
			draw_circle(c + Vector2(-10, -10), 8, Color(1, 1, 1, 0.12))
			Look.brass_circle(self, c, 12)
			draw_polyline(PackedVector2Array([c + Vector2(4, -4), c + Vector2(30, -40), c + Vector2(48, -66)]), Color("e8e2d6"), 4.0, true)
			draw_polyline(PackedVector2Array([c + Vector2(26, -34), c + Vector2(44, -50), c + Vector2(52, -70), c + Vector2(36, -58)]), Color("f2eee6"), 6.0, true)


## Область видимого предмета: прозрачные поля PNG не влияют на размер на столе.
## Редкие почти прозрачные пиксели вне силуэта игнорируются; расчёт кэшируется.
static func sprite_region(texture: Texture2D) -> Rect2:
	var key := texture.get_instance_id()
	if _sprite_regions.has(key):
		return _sprite_regions[key]
	var img := texture.get_image()
	var full := Rect2(Vector2.ZERO, texture.get_size())
	if not img:
		return full
	if img.is_compressed():
		img.decompress()
	var stride := maxi(1, int(maxi(img.get_width(), img.get_height()) / 512.0))
	var lo := img.get_size()
	var hi := Vector2i(-1, -1)
	for y in range(0, img.get_height(), stride):
		for x in range(0, img.get_width(), stride):
			if img.get_pixel(x, y).a > 0.06:
				lo = lo.min(Vector2i(x, y))
				hi = hi.max(Vector2i(x, y))
	var region := full
	if hi.x >= 0:
		region = Rect2(Vector2(lo), Vector2(hi - lo + Vector2i(stride, stride))).grow(float(stride + 2)).intersection(full)
	_sprite_regions[key] = region
	return region


## Вписывает PNG в область без растяжения и возвращает его экранный прямоугольник.
static func draw_sprite(ci: CanvasItem, texture: Texture2D, area: Rect2, tint := Color.WHITE) -> Rect2:
	var source := sprite_region(texture)
	var factor := minf(area.size.x / source.size.x, area.size.y / source.size.y)
	var drawn_size := source.size * factor
	var dest := Rect2(area.get_center() - drawn_size * 0.5, drawn_size)
	ci.draw_texture_rect_region(texture, dest, source, tint)
	return dest
