class_name TableCard
extends Control
## Физический объект на столе: карта, письмо, вырезка, фото, предмет...
## Перетаскивается, приподнимается при наведении, наклоняется в движении, отбрасывает тень.
## Внешний вид задаётся полем "look" в данных (а у предметов — "shape").

signal picked(card: TableCard)
signal dropped(card: TableCard)
signal clicked(card: TableCard)

const SIZES := {
	"portrait": Vector2(140, 212), "envelope": Vector2(190, 128), "calendar": Vector2(124, 150),
	"clipping": Vector2(168, 124), "note": Vector2(156, 176), "photo": Vector2(144, 172),
	"label": Vector2(156, 118), "folder": Vector2(214, 156), "book": Vector2(154, 204),
	"token": Vector2(100, 122), "trait": Vector2(108, 132), "telegram": Vector2(236, 86), "card": Vector2(170, 100),
}
const OBJECT_SIZES := {
	"rapier": Vector2(310, 74), "hairpin": Vector2(110, 52), "bottle": Vector2(226, 84),
	"newspaper": Vector2(196, 134), "parcel": Vector2(124, 94), "fin": Vector2(124, 104),
	"plate": Vector2(114, 104), "spine": Vector2(210, 54), "pearl": Vector2(78, 78),
	"crate": Vector2(200, 140), "coat": Vector2(160, 150),
}
const BOOK_COLORS := {"sl_eye": Color("26385a"), "sl_family": Color("5a2224")}
const PHASE_UNTIL := ["до утра", "до полудня", "до вечера", "до ночи"]
const OBJECT_ART := {"bottle": "nectar_bottle", "crate": "nectar_crate", "hairpin": "pearl_pin", "coat": "tailored_coat"}

var id := ""
var d: Dictionary = {}
var look := "note"
var item_art: Texture2D
var token_art: Texture2D
var book_cover: Texture2D
var lift := 0.0
var hovered := false
var dragging := false
var pressing := false
var press_pos := Vector2.ZERO
var grab := Vector2.ZERO
var rest_rot := 0.0
var vel := Vector2.ZERO
var highlight := false
var base_scale := 1.0
var focused := false
var seed_v := 1
var _t := 0.0


func setup(card_id: String) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	id = card_id
	d = Content.def(id)
	look = str(d.get("look", "note"))
	if look == "token" or look == "trait":
		token_art = Art.prop(id)
	if look == "book":
		book_cover = Art.prop(id)
	if d.get("type") == "item":
		item_art = Art.prop(id)
	seed_v = Look.hash_seed(id)
	size = size_for(d)
	pivot_offset = size / 2.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func():
		hovered = true)
	mouse_exited.connect(func():
		hovered = false)


static func size_for(def: Dictionary) -> Vector2:
	var lk := str(def.get("look", "note"))
	if lk == "object":
		return OBJECT_SIZES.get(str(def.get("shape", "parcel")), Vector2(120, 90))
	return SIZES.get(lk, Vector2(150, 150))


func state() -> Dictionary:
	return Game.state


func inst() -> Dictionary:
	return state()["cards"].get(id, {})


func title() -> String:
	if d.has("stages"):
		return Rules.title_of(id, state())
	return Rules.txt(d.get("title"), state())


func lifetime_phrase() -> String:
	var lt = inst().get("lifetime")
	if lt == null:
		return ""
	var n := int(lt)
	if n > 4:
		return "ещё %d дн." % int(ceil(n / 4.0))
	return PHASE_UNTIL[(int(state()["phase"]) + n) % 4]


func urgent() -> bool:
	var lt = inst().get("lifetime")
	return lt != null and int(lt) <= 1


# ---------------------------------------------------------------- ввод

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			pressing = true
			press_pos = e.global_position
			grab = get_parent().get_local_mouse_position() - position
			accept_event()
		elif pressing:
			pressing = false
			if dragging:
				dragging = false
				dropped.emit(self)
			else:
				clicked.emit(self)
			accept_event()
	elif e is InputEventMouseMotion and pressing:
		if not dragging and e.global_position.distance_to(press_pos) > 6.0:
			dragging = true
			picked.emit(self)
		if dragging:
			var np: Vector2 = get_parent().get_local_mouse_position() - grab
			vel = vel.lerp(np - position, 0.5)
			position = np
		accept_event()


func _process(delta: float) -> void:
	_t += delta
	var target := 1.0 if dragging else (0.4 if (hovered or focused) else 0.0)
	var prev := lift
	lift = lerpf(lift, target, 1.0 - exp(-14.0 * delta))
	var pulse := 0.0
	if urgent() and not dragging:
		pulse = sin(_t * 4.0) * 0.012
	scale = Vector2.ONE * base_scale * (1.0 + lift * 0.06 + pulse)
	var tilt := clampf(vel.x * 0.006, -0.18, 0.18) if dragging else 0.0
	rotation = lerp_angle(rotation, rest_rot + tilt, 1.0 - exp(-10.0 * delta))
	vel = vel.lerp(Vector2.ZERO, 1.0 - exp(-8.0 * delta))
	if absf(lift - prev) > 0.001 or highlight or pulse != 0.0 or dragging:
		queue_redraw()


# ---------------------------------------------------------------- рисование

func silhouette() -> PackedVector2Array:
	var r := Rect2(Vector2.ZERO, size)
	match look:
		"clipping":
			return Look.torn_rect(r, seed_v, true, true, 3.5)
		"note":
			return Look.torn_rect(r, seed_v, true, false, 4.0)
		"token":
			if token_art:
				var octagon := PackedVector2Array()
				for i in 8:
					var ray := Vector2.from_angle(PI / 8.0 + i * TAU / 8.0)
					octagon.append(Vector2(size.x / 2, 47) + ray * 42 / cos(PI / 8.0))
				return octagon
			return Look.ellipse(Vector2(size.x / 2, 48), Vector2(42, 42), 36)
		"trait":
			return Look.ellipse(Vector2(size.x / 2, 50), Vector2(46, 46), 40)
		"portrait", "book":
			return Look.rrect(r, 7)
		"label":
			return Look.rrect(r, 26)
		"object":
			return PackedVector2Array()
		_:
			return Look.rrect(r, 3)


func _draw() -> void:
	var sh_off := Vector2(4, 6) + Vector2(10, 16) * lift
	var sh_spread := 5.0 + 14.0 * lift
	var sh_alpha := 0.6 - 0.2 * lift
	var sil := silhouette()
	if highlight:
		var glow := 0.55 + 0.35 * sin(_t * 5.0)
		var gp := Geometry2D.offset_polygon(sil if sil.size() > 0 else Look.rrect(Rect2(Vector2.ZERO, size), 10), 7.0)
		for p in gp:
			draw_colored_polygon(p, Color(1.0, 0.82, 0.35, 0.25 * glow))
			Look.outline(self, p, Color(1.0, 0.85, 0.4, glow), 2.0)
	if item_art:
		_draw_object_art(item_art, "", sh_off, Color(0.02, 0.01, 0.0, sh_alpha * 0.6))
		_draw_object_art(item_art, "", Vector2.ZERO, Color.TRANSPARENT)
	elif look == "object":
		_draw_object(sh_off, Color(0.02, 0.01, 0.0, sh_alpha * 0.6))
		_draw_object(Vector2.ZERO, Color(0, 0, 0, 0))
	else:
		Look.soft_shadow(self, sil, sh_off, sh_spread, sh_alpha)
		call("_draw_" + look)
	if hovered and not dragging and (item_art or look in ["object", "label", "photo", "token", "trait"]):
		_draw_name_tag()


func _f(kind: String) -> Font:
	return Look.font(kind)


func _paper_grain(outline: PackedVector2Array, strength := 0.2) -> void:
	Look.texture_polygon(self, outline, Art.surface("paper"), 2.0, Color(1.0, 0.96, 0.88, strength))


func _lifetime_note(pos: Vector2, col := Color("3b3a5a")) -> void:
	var p := lifetime_phrase()
	if p == "":
		return
	var c := Look.BAD if urgent() else col
	draw_string(_f("hand"), pos, "⧗ " + p, HORIZONTAL_ALIGNMENT_RIGHT, -1, 13, c)


func _draw_name_tag() -> void:
	var t := title()
	var f := _f("serif")
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 18
	var r := Rect2(Vector2(size.x / 2 - w / 2, -32), Vector2(w, 24))
	Look.soft_shadow(self, Look.rrect(r, 2), Vector2(2, 3), 3, 0.4)
	draw_colored_polygon(Look.rrect(r, 2), Color("f4ecd9"))
	draw_string(f, Vector2(r.position.x, r.position.y + 17), t, HORIZONTAL_ALIGNMENT_CENTER, w, 15, Look.INK)


# ---- портрет (люди)
func _draw_portrait() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var card := Look.rrect(r, 7)
	Look.fill_v(self, card, Color("f4ecd9"), Color("ddcdab"))
	_paper_grain(card, 0.15)
	Look.outline(self, card, Color(0.35, 0.26, 0.16, 0.7), 1.0)
	Look.outline(self, Look.rrect(r.grow(-7), 4), Color(Look.GOLD, 0.8), 1.5)
	var accent := Color(str(d.get("color", "#8899aa")))
	var c := Vector2(size.x / 2, 80)
	var oval := Look.ellipse(c, Vector2(50, 60), 48)
	Look.fill_v(self, oval, accent.lightened(0.45), accent.darkened(0.35))
	var dark := accent.darkened(0.7)
	dark.a = 0.85
	var portrait := Art.portrait(id)
	if portrait:
		Look.draw_portrait(self, portrait, c, Vector2(50, 60))
	else:
		# Резервный силуэт для ещё не нарисованных персонажей.
		var sh := Look.ellipse(c + Vector2(0, 52), Vector2(40, 26), 32)
		var clipped := Geometry2D.intersect_polygons(sh, oval)
		for p in clipped:
			draw_colored_polygon(p, dark)
		draw_circle(c + Vector2(0, 2), 19, dark)
	Look.outline(self, oval, Look.GOLD, 2.0)
	Look.outline(self, Look.ellipse(c, Vector2(54, 64), 48), Color(Look.BRASS_DARK, 0.6), 1.0)
	Look.text_c(self, _f("serif_bold"), size.x / 2, 167, title(), 17, Look.INK, size.x - 12)
	Look.text_c(self, _f("serif_italic"), size.x / 2, 184, str(d.get("subtitle", "")), 11, Look.INK_SOFT, size.x - 14)
	var rels: Array = state()["rel"].get(id, [])
	if rels.size() > 0:
		var shown := rels.slice(maxi(0, rels.size() - 2))
		var line := " · ".join(PackedStringArray(shown))
		# две длинные пометки не влезают в одну строку внизу карточки — тогда только последняя
		if shown.size() > 1 and _f("hand").get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x > size.x - 10:
			shown = shown.slice(shown.size() - 1)
			line = str(shown[0])
		Look.text_c(self, _f("hand"), size.x / 2, 203, line, 12, _rel_color(shown[shown.size() - 1]), size.x - 10)
	if Rules.where_is(state(), id) == state().get("here"):
		draw_circle(Vector2(size.x - 18, 18), 8, Look.WAX)
		draw_circle(Vector2(size.x - 18, 18), 5, Look.WAX.lightened(0.15))


static func _rel_color(tag: String) -> Color:
	if tag in ["Доверие", "Близость", "Уважение", "Расположение"]:
		return Color("2f5a33")
	if tag in ["Раздражение", "Подозрение", "Разочарование", "Обида"]:
		return Color("8a2a20")
	if tag == "Долг":
		return Color("4a2f6a")
	return Color("3b3a5a")


# ---- конверт (приглашения, письма)
func _draw_envelope() -> void:
	var w := size.x
	var h := size.y
	var body := Look.rrect(Rect2(Vector2.ZERO, size), 3)
	Look.fill_v(self, body, Color("f3e9d1"), Color("e1d0ad"))
	_paper_grain(body)
	draw_colored_polygon(PackedVector2Array([Vector2(0, h), Vector2(w * 0.5, h * 0.48), Vector2(w, h)]), Color(0.8, 0.7, 0.52, 0.35))
	var flap := PackedVector2Array([Vector2(1, 1), Vector2(w * 0.5, h * 0.56), Vector2(w - 1, 1)])
	Look.fill_v(self, flap, Color("eadbbb"), Color("dac7a0"))
	_paper_grain(flap, 0.16)
	draw_polyline(PackedVector2Array([Vector2(1, 1), Vector2(w * 0.5, h * 0.56), Vector2(w - 1, 1)]), Color(0.45, 0.35, 0.22, 0.6), 1.2, true)
	Look.outline(self, body, Color(0.45, 0.35, 0.22, 0.6))
	var sc := Vector2(w * 0.5, h * 0.56)
	draw_circle(sc + Vector2(1, 2), 18, Color(0, 0, 0, 0.25))
	draw_circle(sc, 18, Look.WAX)
	draw_circle(sc, 13, Look.WAX.darkened(0.25))
	draw_arc(sc, 15.5, 0, TAU, 32, Look.WAX.lightened(0.2), 1.5, true)
	Look.text_c(self, _f("serif_bold"), sc.x, sc.y + 6, str(d.get("seal", "")), 16, Color("f0c9b0"))
	Look.text_c(self, _f("hand"), w / 2, h - 12, title(), 13, Color("2d3a5a"), w - 16)
	_lifetime_note(Vector2(w - 8 - 120, 16))


# ---- календарный листок (сроки)
func _draw_calendar() -> void:
	var w := size.x
	var body := Look.rrect(Rect2(Vector2(0, 6), size - Vector2(0, 6)), 3)
	Look.fill_v(self, body, Color("f6efdf"), Color("e6dbc4"))
	_paper_grain(body, 0.16)
	var band := Look.rrect(Rect2(Vector2(0, 6), Vector2(w, 30)), 3)
	draw_colored_polygon(band, Color("8c2a22"))
	for x in [w * 0.3, w * 0.7]:
		draw_circle(Vector2(x, 8), 6, Look.BRASS_DARK)
		draw_circle(Vector2(x, 8), 4, Look.BRASS)
	var lt = inst().get("lifetime")
	var days := int(ceil(int(lt) / 4.0)) if lt != null else 0
	Look.text_c(self, _f("serif"), w / 2, 28, "СРОК", 13, Color("f3d9c0"))
	Look.text_c(self, _f("serif_bold"), w / 2, 90, str(days), 50, Color("3a1a14"))
	Look.text_c(self, _f("serif_italic"), w / 2, 108, "дн." if days != 1 else "день", 13, Look.INK_SOFT)
	draw_multiline_string(_f("hand"), Vector2(8, 126), title(), HORIZONTAL_ALIGNMENT_CENTER, w - 16, 12, 2, Color("2d3a5a"))
	Look.outline(self, body, Color(0.4, 0.3, 0.2, 0.5))


# ---- газетная вырезка (слухи)
func _draw_clipping() -> void:
	var sil := silhouette()
	var age := 0.0
	var lt = inst().get("lifetime")
	if lt != null:
		age = clampf(1.0 - int(lt) / 16.0, 0.0, 0.6)
	Look.fill_v(self, sil, Look.NEWSPRINT.lerp(Color("d8c79a"), age), Color("d0c5ad").lerp(Color("c7b27c"), age))
	_paper_grain(sil, 0.23)
	var f := _f("serif_bold")
	draw_multiline_string(f, Vector2(10, 26), title(), HORIZONTAL_ALIGNMENT_LEFT, size.x - 20, 16, 2, Color("1e1a16"))
	draw_line(Vector2(10, 58), Vector2(size.x - 10, 58), Color(0.2, 0.18, 0.15, 0.6), 1.0)
	var col_w := (size.x - 26) / 2.0
	Look.fake_lines(self, Rect2(10, 66, col_w, 44), Color(0.25, 0.22, 0.2, 0.35), 6.0, seed_v)
	Look.fake_lines(self, Rect2(16 + col_w, 66, col_w, 44), Color(0.25, 0.22, 0.2, 0.35), 6.0, seed_v + 7)
	_lifetime_note(Vector2(size.x - 128, size.y - 4), Color("4a4038"))


# ---- страница записной книжки (сведения)
func _draw_note() -> void:
	var sil := silhouette()
	Look.fill_v(self, sil, Color("fbf6ea"), Color("ece3cf"))
	_paper_grain(sil, 0.16)
	var y := 40.0
	while y < size.y - 6:
		draw_line(Vector2(4, y), Vector2(size.x - 4, y), Color(0.45, 0.6, 0.8, 0.35), 1.0)
		y += 17.0
	draw_line(Vector2(24, 8), Vector2(24, size.y), Color(0.8, 0.35, 0.35, 0.45), 1.0)
	draw_multiline_string(_f("hand"), Vector2(30, 30), title(), HORIZONTAL_ALIGNMENT_LEFT, size.x - 36, 15, 2, Color("1f2c4f"))
	var body := Rules.txt(d.get("text"), state())
	draw_multiline_string(_f("hand"), Vector2(30, 70), body.left(110) + "…", HORIZONTAL_ALIGNMENT_LEFT, size.x - 36, 11, 6, Color(0.15, 0.22, 0.4, 0.75))
	_lifetime_note(Vector2(size.x - 128, size.y - 6))


# ---- фотография (улики)
func _draw_photo() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var card := Look.rrect(r, 2)
	Look.fill_v(self, card, Color("f7f3e8"), Color("e6dfcc"))
	_paper_grain(card, 0.14)
	var img := Rect2(10, 10, size.x - 20, 116)
	var ip := Look.rrect(img, 1)
	Look.fill_v(self, ip, Color("7a6650"), Color("2b2119"))
	var c := img.get_center()
	var lightc := Color(0.86, 0.76, 0.6, 0.85)
	match str(d.get("motif", "")):
		"bottle":
			var b := Look.rrect(Rect2(c.x - 17, c.y - 18, 34, 58), 9)
			draw_colored_polygon(b, lightc.darkened(0.35))
			draw_rect(Rect2(c.x - 6, c.y - 46, 12, 30), lightc.darkened(0.35))
			draw_rect(Rect2(c.x - 15, c.y + 22, 30, 16), Color(0.7, 0.78, 0.85, 0.55))
			draw_line(Vector2(c.x - 12, c.y + 22), Vector2(c.x + 12, c.y + 22), Color(0.9, 0.95, 1.0, 0.8), 1.5)
		_:
			draw_circle(c, 26, lightc.darkened(0.4))
	# лёгкая засветка
	draw_colored_polygon(PackedVector2Array([img.position, img.position + Vector2(50, 0), img.position + Vector2(0, 60)]), Color(1, 0.95, 0.85, 0.12))
	draw_multiline_string(_f("hand"), Vector2(10, 146), title(), HORIZONTAL_ALIGNMENT_CENTER, size.x - 20, 13, 2, Color("2d3a5a"))
	Look.outline(self, card, Color(0.4, 0.33, 0.25, 0.5))


# ---- отклеенная винная этикетка (особая улика)
func _draw_label() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var sil := Look.rrect(r, 26)
	Look.fill_v(self, sil, Color("f3e7c6"), Color("e2cf9f"))
	_paper_grain(sil, 0.22)
	Look.outline(self, Look.rrect(r.grow(-5), 22), Look.GOLD, 1.5)
	Look.outline(self, Look.rrect(r.grow(-9), 19), Color(Look.GOLD, 0.6), 1.0)
	# лоза
	var pts := PackedVector2Array()
	for i in 21:
		var x := 24.0 + (size.x - 48) * i / 20.0
		pts.append(Vector2(x, 36 + sin(i * 0.9) * 5))
	draw_polyline(pts, Color("7d6420"), 1.5, true)
	for i in range(2, 20, 4):
		draw_circle(pts[i] + Vector2(0, -5), 3.2, Color("6a7a2a"))
	Look.text_c(self, _f("serif_bold"), size.x / 2, 66, "FLEUR", 18, Color("5a3a12"))
	# пустое место для номера партии, обведённое красным карандашом
	var box := Rect2(size.x / 2 - 32, 78, 64, 16)
	draw_rect(box, Color(0.35, 0.25, 0.12, 0.6), false, 1.0)
	draw_arc(box.get_center(), 40, 0, TAU, 40, Color(0.75, 0.15, 0.12, 0.7), 2.0, true)
	Look.outline(self, sil, Color(0.4, 0.3, 0.15, 0.6))


# ---- папка дела
func _draw_folder() -> void:
	var w := size.x
	var h := size.y
	var tab := Look.rrect(Rect2(14, 0, 78, 22), 4)
	draw_colored_polygon(tab, Color("c79e5c"))
	var body := Look.rrect(Rect2(0, 14, w, h - 14), 3)
	# листы, торчащие из папки: у дела по стадиям их столько, сколько стадий пройдено
	var stage := Rules.case_stage(state(), id) if d.has("stages") else 0
	for k in range(stage, -1, -1):
		draw_colored_polygon(Look.rrect(Rect2(w - 96 - k * 14, 6 - k * 1.5, 82, 30), 1), Color("f4eee0").darkened(0.04 * k))
		draw_rect(Rect2(w - 96 - k * 14, 6 - k * 1.5, 82, 30), Color(0.4, 0.3, 0.2, 0.25), false, 1.0)
	Look.fill_v(self, body, Color("d8b679"), Color("bf9455"))
	_paper_grain(body, 0.16)
	Look.outline(self, body, Color(0.4, 0.28, 0.12, 0.7))
	draw_line(Vector2(4, 40), Vector2(w - 4, 40), Color(0.45, 0.3, 0.12, 0.35), 1.0)
	var lab := Rect2(20, 54, w - 40, 46)
	draw_rect(lab, Color("f6f0e2"))
	draw_rect(lab, Color(0.4, 0.3, 0.2, 0.5), false, 1.0)
	draw_multiline_string(_f("type"), Vector2(lab.position.x + 6, lab.position.y + 19), title(), HORIZONTAL_ALIGNMENT_CENTER, lab.size.x - 12, 14, 2, Look.INK)
	# штамп
	draw_set_transform(Vector2(w - 62, h - 24), -0.2, Vector2.ONE)
	var mark := "ДЕЛО"
	if d.has("stages"):
		mark = str(d["stages"][clampi(stage, 0, d["stages"].size() - 1)].get("mark", "ДЕЛО"))
	var mw := maxf(60.0, _f("serif_bold").get_string_size(mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 14)
	draw_rect(Rect2(-mw + 30, -14, mw, 24), Color(0.6, 0.12, 0.1, 0.55), false, 2.0)
	draw_string(_f("serif_bold"), Vector2(-mw + 30, 3), mark, HORIZONTAL_ALIGNMENT_CENTER, mw, 12, Color(0.6, 0.12, 0.1, 0.65))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# завязки
	var b1 := Vector2(30, h - 22)
	Look.brass_circle(self, b1, 6)
	draw_polyline(PackedVector2Array([b1, b1 + Vector2(18, -8), b1 + Vector2(36, 4), b1 + Vector2(52, -4)]), Color("8a2020"), 1.6, true)


# ---- переплёт (сюжетные линии)
func _draw_book() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if book_cover:
		draw_texture_rect(book_cover, r, false)
		# Центр наборной полосы смещён вправо на половину ширины корешка.
		var font := _f("serif_bold")
		var heading := title()
		var font_size := 18
		var width := size.x - 37.0
		var text_height := font.get_multiline_string_size(heading, HORIZONTAL_ALIGNMENT_CENTER, width, font_size).y
		var baseline := Vector2(22, size.y * 0.60 - text_height / 2.0 + font.get_ascent(font_size))
		draw_multiline_string(font, baseline + Vector2(0, 1), heading, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, -1, Color("211a13"))
		draw_multiline_string(font, baseline, heading, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, -1, Color("f7e3b2"))
		return
	var base: Color = BOOK_COLORS.get(id, Color("3e2a1c"))
	var cover := Look.rrect(r, 7)
	Look.fill_v(self, cover, base.lightened(0.12), base.darkened(0.35))
	Look.texture_polygon(self, cover, Art.surface("leather"), 2.8, Color(base.lightened(0.65), 0.28))
	draw_colored_polygon(Look.rrect(Rect2(0, 0, 18, size.y), 6), base.darkened(0.5))
	draw_line(Vector2(18, 4), Vector2(18, size.y - 4), Color(0, 0, 0, 0.4), 2.0)
	Look.outline(self, Look.rrect(Rect2(28, 12, size.x - 40, size.y - 24), 2), Color(Look.GOLD, 0.7), 1.2)
	for corner in [Vector2(size.x, 0), Vector2(size.x, size.y)]:
		var sx := -1.0
		var sy := 1.0 if corner.y == 0 else -1.0
		draw_colored_polygon(PackedVector2Array([corner, corner + Vector2(sx * 22, 0), corner + Vector2(0, sy * 22)]), Look.BRASS)
	draw_multiline_string(_f("serif_bold"), Vector2(30, size.y / 2 - 6), title(), HORIZONTAL_ALIGNMENT_CENTER, size.x - 44, 17, 3, Color("e9cf86"))
	Look.text_c(self, _f("serif"), 22 + (size.x - 22) / 2, size.y / 2 + 32, "❦", 18, Color(Look.GOLD, 0.8))
	draw_colored_polygon(PackedVector2Array([Vector2(size.x - 40, size.y - 2), Vector2(size.x - 30, size.y - 2), Vector2(size.x - 30, size.y + 20), Vector2(size.x - 35, size.y + 14), Vector2(size.x - 40, size.y + 20)]), Color("8e1f22"))


# ---- эмалевые жетоны подходов и состояний
func _draw_token() -> void:
	var c := Vector2(size.x / 2, 47)
	var enamel := Color("6e3a33") if d.get("mood") == "bad" else Color("3f6a5a")
	_draw_enamel(c, 42.0, enamel, Color.WHITE)
	_draw_token_caption(title(), 104, 15, _f("serif_bold"), Color("fff0ce"))
	var duration := lifetime_phrase()
	if duration != "":
		_draw_token_caption(duration, 121, 14, _f("sans"), Color("ffd3a4") if urgent() else Color("f0dfbd"))


func _draw_trait() -> void:
	var c := Vector2(size.x / 2, 50)
	var rest := int(inst().get("rest", 0))
	var enamel := Color(str(d.get("color", "#2a3f6a")))
	var tint := Color("87817b") if rest > 0 else Color.WHITE
	_draw_enamel(c, 46.0, enamel, tint)
	_draw_token_caption(title(), 114, 15, _f("serif_bold"), Color("fff0ce"))
	if rest > 0:
		var ready := clampf(1.0 - float(rest) / maxf(1.0, float(d.get("recharge", 3))), 0, 1)
		draw_arc(c, 47, 0, TAU, 64, Color("46392e"), 3.0, true)
		if ready > 0:
			draw_arc(c, 47, -PI / 2, -PI / 2 + TAU * ready, 64, Color("f5d58e"), 3.0, true)
		_draw_token_caption(PHASE_UNTIL[(int(state()["phase"]) + rest) % 4], 130, 14, _f("sans"), Color("f0dfbd"))


func _draw_enamel(c: Vector2, radius: float, enamel: Color, tint: Color) -> void:
	if token_art:
		var half := Vector2.ONE * (radius + 1.0)
		draw_texture_rect(token_art, Rect2(c - half, half * 2.0), false, tint)
		return
	# Для добавленных автором жетонов без индивидуального рисунка.
	draw_circle(c, radius, Look.BRASS_DARK * tint)
	draw_circle(c, radius - 2, Look.BRASS * tint)
	draw_circle(c, radius - 5, enamel * tint)
	_draw_glyph(str(d.get("glyph", "")), c, Color("f1e3c0") * tint)


func _draw_token_caption(caption: String, baseline: int, font_size: int, font: Font, color: Color) -> void:
	var width := size.x + 6.0
	while font_size > 11 and font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
		font_size -= 1
	var origin := Vector2((size.x - width) * 0.5, baseline)
	draw_string_outline(font, origin, caption, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, 3, Color("1d241fed"))
	draw_string(font, origin, caption, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color)


func _draw_glyph(g: String, c: Vector2, col: Color) -> void:
	match g:
		"heart":
			draw_circle(c + Vector2(-6, -4), 7, col)
			draw_circle(c + Vector2(6, -4), 7, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-12.5, -1), c + Vector2(12.5, -1), c + Vector2(0, 14)]), col)
		"crest":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-12, -13), c + Vector2(12, -13), c + Vector2(12, 2), c + Vector2(0, 15), c + Vector2(-12, 2)]), col)
			draw_line(c + Vector2(0, -9), c + Vector2(0, 9), col.darkened(0.6), 2.0, true)
			draw_line(c + Vector2(-7, -3), c + Vector2(7, -3), col.darkened(0.6), 2.0, true)
		"coin":
			draw_circle(c + Vector2(4, 4), 11, col.darkened(0.25))
			draw_circle(c + Vector2(-3, -3), 11, col)
			draw_arc(c + Vector2(-3, -3), 7, 0, TAU, 20, col.darkened(0.45), 1.5, true)
		"eye":
			draw_arc(c + Vector2(0, 8), 16, PI * 1.18, PI * 1.82, 18, col, 2.5, true)
			draw_arc(c + Vector2(0, -8), 16, PI * 0.18, PI * 0.82, 18, col, 2.5, true)
			draw_circle(c, 5, col)
		"glass":
			draw_arc(c + Vector2(0, -8), 11, 0, PI, 16, col, 2.5, true)
			draw_line(c + Vector2(-11, -8), c + Vector2(11, -8), col, 2.0)
			draw_line(c + Vector2(0, 3), c + Vector2(0, 14), col, 2.0)
			draw_line(c + Vector2(-8, 15), c + Vector2(8, 15), col, 2.5)
		"blade":
			draw_line(c + Vector2(-14, 14), c + Vector2(15, -15), col, 2.5, true)
			draw_line(c + Vector2(-14, 4), c + Vector2(-4, 14), col, 3.0, true)
		"quill":
			var pts := PackedVector2Array([c + Vector2(-12, 16), c + Vector2(-2, 0), c + Vector2(12, -16), c + Vector2(4, 2)])
			draw_colored_polygon(pts, col)
			draw_line(c + Vector2(-14, 18), c + Vector2(10, -12), inner_dark(col), 1.0)
		"moon":
			draw_circle(c, 15, col)
			draw_circle(c + Vector2(7, -5), 13, Color("6e3a33"))
		"drop":
			var pts2 := PackedVector2Array()
			for i in 17:
				var a := PI * i / 16.0
				pts2.append(c + Vector2(cos(a), sin(a)) * 11 + Vector2(0, 2))
			pts2.append(c + Vector2(-6, -8))
			pts2.append(c + Vector2(0, -17))
			pts2.append(c + Vector2(6, -8))
			draw_colored_polygon(pts2, col)
		_:
			draw_circle(c, 8, col)


func inner_dark(c: Color) -> Color:
	return c.darkened(0.6)


# ---- лента (состояния мира)
func _draw_telegram() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var sil := Look.rrect(r, 1)
	Look.fill_v(self, sil, Color("efe2ac"), Color("e0cf8c"))
	_paper_grain(sil, 0.2)
	draw_rect(Rect2(8, 30, size.x - 16, 20), Color(1, 1, 1, 0.35))
	draw_string(_f("type"), Vector2(10, 22), title().to_upper(), HORIZONTAL_ALIGNMENT_LEFT, size.x - 20, 14, Color("2a2418"))
	var body := Rules.txt(d.get("text"), state())
	draw_multiline_string(_f("type"), Vector2(12, 45), body, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, 10, 3, Color(0.2, 0.17, 0.1, 0.8))
	Look.outline(self, sil, Color(0.45, 0.38, 0.2, 0.6))


# ---- визитная карточка
func _draw_card() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var c := Look.rrect(r, 2)
	Look.fill_v(self, c, Color("fbf8f0"), Color("ece6d8"))
	_paper_grain(c, 0.16)
	Look.outline(self, c, Color(0.4, 0.35, 0.3, 0.5))
	Look.text_c(self, _f("serif_bold"), size.x / 2, 38, str(d.get("card_name", title())), 17, Look.INK, size.x - 16)
	Look.text_c(self, _f("serif_italic"), size.x / 2, 56, str(d.get("card_sub", "")), 11, Look.INK_SOFT, size.x - 16)
	draw_polyline(PackedVector2Array([Vector2(size.x - 34, size.y - 12), Vector2(size.x - 20, size.y - 30), Vector2(size.x - 10, size.y - 44)]), Color("b3262c"), 2.0, true)
	draw_string(_f("hand"), Vector2(12, size.y - 12), str(d.get("card_note", "")), HORIZONTAL_ALIGNMENT_LEFT, size.x - 50, 12, Color("2d3a5a"))


# ---- предметы: рисуются как вещи, без рамки карты
func _draw_object(off: Vector2, shadow: Color) -> void:
	var sh := shadow.a > 0.0
	var shape := str(d.get("shape", ""))
	var artwork := Art.prop(str(OBJECT_ART.get(shape, ""))) if OBJECT_ART.has(shape) else null
	if artwork:
		_draw_object_art(artwork, shape, off, shadow)
		return
	var C := func(c: Color) -> Color:
		return shadow if sh else c
	var w := size.x
	var h := size.y
	if sh:
		draw_set_transform(off, 0, Vector2.ONE)
	match str(d.get("shape", "")):
		"rapier":
			var blade := PackedVector2Array([Vector2(74, h / 2 - 3.5), Vector2(w - 6, h / 2), Vector2(74, h / 2 + 3.5)])
			draw_colored_polygon(blade, C.call(Color("c9cfd6")))
			if not sh:
				draw_line(Vector2(76, h / 2 - 1), Vector2(w - 20, h / 2), Color(1, 1, 1, 0.7), 1.0)
				draw_line(Vector2(76, h / 2 + 2), Vector2(w - 16, h / 2), Color("66828c"), 1.0, true)
			draw_colored_polygon(Look.ellipse(Vector2(66, h / 2), Vector2(10, 24), 24), C.call(Color("b8913f")))
			if not sh:
				draw_arc(Vector2(66, h / 2), 18, -1.2, 1.2, 16, Color("e6c77a"), 2.0, true)
				draw_arc(Vector2(48, h / 2), 20, -2.2, -0.6, 16, Color("b8913f"), 2.5, true)
			draw_rect(Rect2(24, h / 2 - 5, 34, 10), C.call(Color("3a2416")))
			if not sh:
				for i in 7:
					var hx := 26.0 + i * 4.0
					draw_line(Vector2(hx, h / 2 - 4), Vector2(hx + 3, h / 2 + 4), Color("a98342"), 1.0, true)
				draw_line(Vector2(24, h / 2 - 5), Vector2(56, h / 2 - 5), Color("d3b370"), 1.5, true)
			draw_circle(Vector2(20, h / 2), 7, C.call(Color("b8913f")))
			if not sh:
				draw_circle(Vector2(18, h / 2 - 2), 2.5, Color("f4df9b"))
		"hairpin":
			draw_line(Vector2(10, 34), Vector2(84, 22), C.call(Color("c9a94a")), 2.0, true)
			draw_circle(Vector2(88, 21), 9, C.call(Color("efeae4")))
			if not sh:
				draw_circle(Vector2(85, 18), 3, Color(1, 1, 1, 0.9))
				draw_arc(Vector2(88, 21), 9, 0, TAU, 24, Color("c9b8a8"), 1.0, true)
		"bottle":
			var bd := Look.rrect(Rect2(36, 16, 150, 52), 22)
			if sh:
				draw_colored_polygon(bd, shadow)
			else:
				Look.fill_v(self, bd, Color("2f5a38"), Color("12261a"))
			draw_rect(Rect2(180, 32, 38, 20), C.call(Color("1d3a24")))
			draw_rect(Rect2(190, 30, 30, 24), C.call(Color("c9a94a")))
			if not sh:
				draw_rect(Rect2(84, 22, 58, 40), Color("efe2c0"))
				draw_rect(Rect2(84, 22, 58, 40), Color("b8913f"), false, 1.0)
				Look.text_c(self, _f("serif_bold"), 113, 47, "F", 16, Color("5a3a12"))
				draw_line(Vector2(50, 22), Vector2(170, 22), Color(1, 1, 1, 0.25), 2.0)
		"newspaper":
			var np := Look.rrect(Rect2(0, 0, w, h), 1)
			draw_colored_polygon(np, C.call(Look.NEWSPRINT))
			if not sh:
				draw_colored_polygon(Look.rrect(Rect2(w / 2, 0, w / 2, h), 1), Color(0, 0, 0, 0.05))
				Look.text_c(self, _f("serif_bold"), w / 2, 22, "ПАРОВАЯ ПТИЦА", 15, Color("1e1a16"), w)
				draw_line(Vector2(8, 30), Vector2(w - 8, 30), Color(0.2, 0.18, 0.15, 0.7), 1.5)
				for i in 3:
					Look.fake_lines(self, Rect2(10 + i * (w - 20) / 3.0, 40, (w - 20) / 3.0 - 8, h - 50), Color(0.25, 0.22, 0.2, 0.3), 6.0, seed_v + i)
				draw_line(Vector2(w / 2, 4), Vector2(w / 2, h - 4), Color(0, 0, 0, 0.15), 1.0)
		"crate":
			var cr := Rect2(10, 14, w - 20, h - 28)
			if sh:
				draw_colored_polygon(Look.rrect(cr, 3), shadow)
			else:
				Look.fill_v(self, Look.rrect(cr, 3), Color("b8925e"), Color("8e6a3c"))
				for i in 4:
					draw_line(Vector2(cr.position.x, cr.position.y + i * cr.size.y / 4.0), Vector2(cr.end.x, cr.position.y + i * cr.size.y / 4.0), Color(0.35, 0.22, 0.1, 0.5), 1.5)
				draw_rect(Rect2(cr.position.x + 30, cr.position.y + 34, cr.size.x - 60, 36), Color(0.95, 0.88, 0.7, 0.25))
				Look.text_c(self, _f("serif_bold"), w / 2, cr.position.y + 50, "НЕКТАР ФЛЁР", 15, Color(0.25, 0.14, 0.05, 0.85), w)
				Look.text_c(self, _f("serif_italic"), w / 2, cr.position.y + 66, "для семьи", 12, Color(0.25, 0.14, 0.05, 0.7), w)
				for x in [cr.position.x + 18, cr.end.x - 18]:
					for y in [cr.position.y + 8, cr.end.y - 8]:
						draw_circle(Vector2(x, y), 3, Color("4a3018"))
		"coat":
			var body := PackedVector2Array([Vector2(w * 0.3, 18), Vector2(w * 0.7, 18), Vector2(w - 14, 46), Vector2(w - 24, h - 10), Vector2(24, h - 10), Vector2(14, 46)])
			draw_colored_polygon(body, C.call(Color("25386a")))
			if not sh:
				draw_colored_polygon(PackedVector2Array([Vector2(w * 0.4, 18), Vector2(w * 0.6, 18), Vector2(w * 0.5, 64)]), Color("f2eee6"))
				for i in 4:
					draw_circle(Vector2(w * 0.5 + 10, 74 + i * 16), 3.5, Color("d4b25a"))
				draw_line(Vector2(w * 0.5, 64), Vector2(w * 0.5, h - 10), Color(0.1, 0.15, 0.3), 1.5)
				draw_rect(Rect2(w * 0.5 - 30, 4, 60, 16), Color("f4ecd9"))
				Look.text_c(self, _f("hand"), w / 2, 17, "Тиори", 11, Look.INK, 60)
		"parcel":
			var pp := Look.rrect(Rect2(6, 10, w - 12, h - 20), 8)
			draw_colored_polygon(pp, C.call(Color("b99c6c")))
			if not sh:
				draw_line(Vector2(w / 2, 10), Vector2(w / 2, h - 10), Color("6a4a2a"), 2.0)
				draw_line(Vector2(6, h / 2), Vector2(w - 6, h / 2), Color("6a4a2a"), 2.0)
				draw_circle(Vector2(w / 2, h / 2), 5, Color("6a4a2a"))
		"fin":
			draw_colored_polygon(PackedVector2Array([Vector2(10, h - 10), Vector2(w * 0.55, 8), Vector2(w - 8, h - 14)]), C.call(Color("3e5a6a")))
			if not sh:
				for i in 5:
					draw_line(Vector2(20 + i * 20, h - 12), Vector2(w * 0.55, 12), Color(0.7, 0.8, 0.85, 0.3), 1.0)
		"plate":
			draw_colored_polygon(Look.ellipse(Vector2(w / 2, h / 2), Vector2(w / 2 - 6, h / 2 - 8), 32), C.call(Color("8fb3a6")))
			if not sh:
				draw_arc(Vector2(w / 2, h / 2), 26, -1.4, 1.4, 20, Color("d6ebe0"), 2.0, true)
				draw_arc(Vector2(w / 2, h / 2), 38, -1.2, 1.2, 20, Color("d6ebe0"), 1.0, true)
		"spine":
			var pts := PackedVector2Array([Vector2(6, h / 2 - 6), Vector2(w - 4, h / 2), Vector2(6, h / 2 + 6)])
			draw_colored_polygon(pts, C.call(Color("ddd2b0")))
			if not sh:
				for i in 7:
					var x := 30.0 + i * 24
					draw_line(Vector2(x, h / 2 - 5), Vector2(x + 6, h / 2 - 11), Color("ddd2b0"), 2.0)
		"pearl":
			draw_colored_polygon(Look.rrect(Rect2(4, 4, w - 8, h - 8), 6), C.call(Color("23234a")))
			if not sh:
				draw_circle(Vector2(w / 2, h / 2), 15, Color("dfe8f2"))
				draw_circle(Vector2(w / 2 - 5, h / 2 - 5), 5, Color(1, 1, 1, 0.9))
				draw_arc(Vector2(w / 2, h / 2), 15, 0, TAU, 32, Color("7a8ab8"), 1.0, true)
		_:
			draw_colored_polygon(Look.rrect(Rect2(8, 8, w - 16, h - 16), 8), C.call(Color("8a7a5a")))
	if sh:
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	elif int(inst().get("count", 1)) > 1:
		draw_string(_f("hand"), Vector2(w - 34, h - 2), "×" + str(int(inst()["count"])), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f0e2c0"))


func _draw_object_art(texture: Texture2D, shape: String, off: Vector2, shadow: Color) -> void:
	var area := Rect2(Vector2(3, 3), size - Vector2(6, 6))
	if shadow.a > 0.0:
		# Несколько слабых копий сглаживают край тени при подъёме предмета.
		for drift in [Vector2(-1.2, 0), Vector2(1.2, 0), Vector2(0, 1.2)]:
			DeskProp.draw_sprite(self, texture, Rect2(area.position + off + drift * (1.0 + lift), area.size), Color(shadow, shadow.a * 0.35))
		return
	var r := DeskProp.draw_sprite(self, texture, area)
	match shape:
		"bottle":
			var cx := r.position.x + r.size.x * 0.36
			Look.text_c(self, _f("serif_bold"), cx, r.position.y + r.size.y * 0.47, "НЕКТАР", 9, Color("65421d"), r.size.x * 0.28)
			Look.text_c(self, _f("serif_bold"), cx, r.position.y + r.size.y * 0.65, "ФЛЁР", 11, Color("65421d"), r.size.x * 0.28)
		"crate":
			var cx := r.get_center().x
			Look.text_c(self, _f("serif_bold"), cx, r.position.y + r.size.y * 0.43, "НЕКТАР ФЛЁР", 12, Color("5a3215"), r.size.x * 0.57)
			Look.text_c(self, _f("serif_italic"), cx, r.position.y + r.size.y * 0.58, "для семьи", 10, Color("6f461f"), r.size.x * 0.56)
		"coat":
			# Бирка имеет собственный наклон; надпись остаётся кодовой.
			var tag := r.position + Vector2(r.size.x * 0.75, r.size.y * 0.32)
			draw_set_transform(tag, -0.43, Vector2.ONE)
			Look.text_c(self, _f("hand"), 0, 3, "Тиори", 7, Look.INK, 24)
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if int(inst().get("count", 1)) > 1:
		draw_string(_f("hand"), Vector2(size.x - 34, size.y - 2), "×" + str(int(inst()["count"])), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f0e2c0"))
