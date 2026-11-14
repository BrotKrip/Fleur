class_name DeskProp
extends Control
## Мелкие вещи на столе, через которые доступны служебные функции:
## Записная книжка открывает журнал. Чернильница служит украшением.

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
		"inkwell":
			size = Vector2(192, 72)
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
	if artwork:
		var area := Rect2(Vector2(4, 2) + lift, size - Vector2(8, 6))
		var off := Vector2(2, 3) if kind == "inkwell" else Vector2(4, 6)
		draw_sprite(self, artwork, Rect2(area.position + off, area.size), Color(0.015, 0.012, 0.008, 0.42))
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
		"inkwell":
			var tray := Look.rrect(Rect2(4, 3, size.x - 8, size.y - 7), 8)
			Look.soft_shadow(self, tray, Vector2(2, 3), 3, 0.45)
			Look.fill_v(self, tray, Color("344253"), Color("202a38"))
			Look.outline(self, tray, Look.BRASS, 2)
			var c := Vector2(41, size.y / 2)
			draw_circle(c, 24, Color("243859"), true, -1, true)
			draw_circle(c, 16, Look.BRASS, true, -1, true)
			draw_circle(c, 12, Color("0a1120"), true, -1, true)
			draw_line(Vector2(82, 51), Vector2(158, 27), Look.BRASS, 3, true)
			draw_colored_polygon(PackedVector2Array([Vector2(106, 44), Vector2(124, 28), Vector2(169, 17), Vector2(157, 31), Vector2(130, 42)]), Color("dfcfab"))


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
