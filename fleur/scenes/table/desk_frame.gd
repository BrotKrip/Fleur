class_name DeskFrame
extends Control
## Экранная рамка стола, как у игрового поля: тонкий золочёный кант по краям экрана
## и угловые постаменты. Справа сверху на кронштейне стоят часы с календарём,
## слева снизу на консоли лежат таблички «Меню» и «Прибрать стол», справа снизу
## в зеркальной консоли записная книжка. Слева сверху только завиток с ракушкой:
## там на столе карта города, и крупный угол закрыл бы её.
## Рамка не ловит мышь: всё кликабельное лежит поверх неё.

## Ширина угловых постаментов на экране (высота — по пропорции картинки).
const TR_W := 500.0
const BOTTOM_W := 420.0
const BR_W := 300.0
const TL_W := 190.0
## Опорные точки в долях картинок (замерены по альфе): низ полки и правая стойка
## кронштейна, верх полки консоли и где у неё кончается чаша фонтанчика.
const TR_SHELF_BOTTOM := 0.345
const TR_ARM_X := 0.898
const LEDGE_TOP := 0.778
const LEDGE_FROM := 0.20
## Кант по краю экрана.
const RAIL := 7.0

var _tr: Texture2D
var _bottom: Texture2D
var _tl: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_tr = Art.prop("desk_frame_tr")
	_bottom = Art.prop("desk_frame_bottom")
	_tl = Art.prop("desk_frame_tl")
	resized.connect(queue_redraw)


## Прямоугольник постамента на экране: чтобы разложить по нему часы, кнопки и книжку.
func corner_rect(which: String) -> Rect2:
	var s := size
	match which:
		"tr":
			var h := _height(_tr, TR_W)
			return Rect2(s.x - TR_W, 0, TR_W, h)
		"bl":
			var h := _height(_bottom, BOTTOM_W)
			return Rect2(0, s.y - h, BOTTOM_W, h)
		"br":
			var h := _height(_bottom, BR_W)
			return Rect2(s.x - BR_W, s.y - h, BR_W, h)
		"tl":
			return Rect2(0, 0, TL_W, _height(_tl, TL_W))
	return Rect2()


func _height(tex: Texture2D, w: float) -> float:
	if tex == null:
		return 0.0
	var region := DeskProp.sprite_region(tex)
	return w * region.size.y / region.size.x


func _draw() -> void:
	_draw_rail()
	_corner(_tl, corner_rect("tl"), false)
	_corner(_tr, corner_rect("tr"), false)
	_corner(_bottom, corner_rect("bl"), false)
	_corner(_bottom, corner_rect("br"), true)


func _corner(tex: Texture2D, r: Rect2, mirror: bool) -> void:
	if tex == null:
		return
	var region := DeskProp.sprite_region(tex)
	# тень постамента на стол
	var shadow := Rect2(r.position + Vector2(3, 6), r.size)
	if mirror:
		# x → (r.position.x + r.end.x) − x: картинка отражается внутри того же прямоугольника
		draw_set_transform(Vector2(r.position.x + r.end.x, 0), 0.0, Vector2(-1, 1))
		draw_texture_rect_region(tex, Rect2(r.position + Vector2(-3, 6), r.size), region, Color(0, 0, 0, 0.45))
		draw_texture_rect_region(tex, r, region)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	draw_texture_rect_region(tex, shadow, region, Color(0, 0, 0, 0.45))
	draw_texture_rect_region(tex, r, region)


## Тонкий кант по краю экрана: тёмная бронза, золотая нить, бирюзовая эмаль,
## и мягкая тень внутрь, будто стол утоплен в раму.
func _draw_rail() -> void:
	var r := Rect2(Vector2.ZERO, size)
	for i in 10:
		var a := 0.20 * (1.0 - i / 10.0)
		draw_rect(r.grow(-RAIL - i * 2.0), Color(0.02, 0.01, 0.0, a), false, 2.0)
	draw_rect(r.grow(-RAIL * 0.5), Color("2a1a0c"), false, RAIL)
	draw_rect(r.grow(-1.5), Color(0.1, 0.06, 0.02), false, 3.0)
	draw_rect(r.grow(-RAIL + 1.0), Color("c9a55a"), false, 1.6)
	draw_rect(r.grow(-RAIL - 1.5), Color(0.18, 0.45, 0.42, 0.8), false, 1.2)
