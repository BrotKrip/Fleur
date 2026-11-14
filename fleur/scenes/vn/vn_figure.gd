class_name VNFigure
extends Control
## Спрайт персонажа с мягкой анимацией дыхания и акцентом говорящего.
## Процедурный бюст остаётся резервом для ещё не нарисованных персонажей.

const STYLES := {
	"char_charlotte": {"hair": "e7a2b6", "coat": "b3262c", "trim": "d4b25a", "hat": "kepi", "hat_color": "b3262c", "eyes": "3fb6c4", "monocle": true, "bob": true},
	"char_josie": {"hair": "d9dde6", "coat": "7d90a8", "trim": "1a1a1a", "hat": "", "eyes": "8ec8ee", "ponytail": true},
	"char_tiori": {"hair": "6a3a22", "coat": "e0b030", "trim": "1a1a1a", "hat": "bun", "eyes": "c0392b"},
	"char_adrian": {"hair": "9a9894", "coat": "2e2a3a", "trim": "c9a94a", "hat": "", "eyes": "5a6a7a", "glasses_up": true, "short": true},
	"char_louis": {"hair": "cfccc2", "coat": "28374a", "trim": "8a8a8a", "hat": "", "eyes": "7a8a9a", "short": true},
	"char_marcel": {"hair": "ddd6c2", "coat": "5f6236", "trim": "1a1a1a", "hat": "", "eyes": "6a7a6a", "glasses": true, "short": true},
	"eloise": {"hair": "cbbfae", "coat": "5a2a46", "trim": "d4b25a", "hat": "bun", "eyes": "7a9ab0"},
	"char_clorinde": {"hair": "2a2f5a", "coat": "1d2340", "trim": "d4b25a", "hat": "tricorn", "hat_color": "1d2340", "eyes": "8a6ad0"},
}

var pid := ""
var speaking := false
var dim := false
var _t := 0.0
var _talk := 0.0
var base_scale := 1.0
var portrait: Texture2D
var mood := ""
var _prev_portrait: Texture2D
var _blend := 1.0


func setup(id: String, start_mood := "") -> void:
	pid = id
	mood = start_mood
	portrait = Art.portrait(id, mood)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	size = Vector2(420, 640)
	pivot_offset = Vector2(210, 640)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Сменить эмоцию. Если спрайт тот же (нет отдельного файла) — ничего не мигает.
func set_mood(m: String) -> void:
	mood = m
	var tex := Art.portrait(pid, m)
	if tex == portrait:
		return
	_prev_portrait = portrait
	portrait = tex
	_blend = 0.0


func _process(delta: float) -> void:
	_t += delta
	_blend = minf(1.0, _blend + delta / 0.18)
	_talk = lerpf(_talk, 1.0 if speaking else 0.0, 1.0 - exp(-8.0 * delta))
	var shade := 1.0 - (0.28 if dim else 0.0) * (1.0 - _talk)
	modulate = Color(shade, shade, shade, modulate.a)
	scale = Vector2.ONE * base_scale * (1.0 + 0.012 * _talk)
	queue_redraw()


func _draw() -> void:
	if portrait:
		var source := portrait.get_size()
		var fit := minf(size.x / source.x, size.y / source.y)
		var fitted := source * fit
		var breath_offset := sin(_t * 1.4) * 1.3
		var target := Rect2(Vector2((size.x - fitted.x) * 0.5, size.y - fitted.y + breath_offset), fitted)
		if _prev_portrait and _blend < 1.0:
			var ps := _prev_portrait.get_size() * minf(size.x / _prev_portrait.get_size().x, size.y / _prev_portrait.get_size().y)
			draw_texture_rect(_prev_portrait, Rect2(Vector2((size.x - ps.x) * 0.5, size.y - ps.y + breath_offset), ps), false, Color(1, 1, 1, 1.0 - _blend))
		draw_texture_rect(portrait, target, false, Color(1, 1, 1, _blend if _prev_portrait else 1.0))
		return
	# Внешность для резервного рисунка: поле "placeholder" в данных персонажа, иначе встроенная таблица.
	var st: Dictionary = Content.def(pid).get("placeholder", STYLES.get(pid, {}))
	var spk: Dictionary = Content.world.get("speakers", {}).get(pid, {})
	var base := Color(str(Content.def(pid).get("color", spk.get("color", "#888888"))))
	var coat := Color(str(st.get("coat", base.to_html())))
	var hair := Color(str(st.get("hair", base.darkened(0.3).to_html())))
	var trim := Color(str(st.get("trim", "d4b25a")))
	var skin := Color("f3dccd")
	var breath := sin(_t * 1.6) * 2.0
	var hc := Vector2(210, 262 + breath * 0.5)

	# тень за фигурой
	draw_colored_polygon(Look.ellipse(Vector2(210, 630), Vector2(190, 26), 32), Color(0, 0, 0, 0.3))
	if st.get("ponytail", false):
		draw_colored_polygon(PackedVector2Array([hc + Vector2(30, -70), hc + Vector2(90, -40), hc + Vector2(110, 280), hc + Vector2(60, 300), hc + Vector2(40, -20)]), hair.darkened(0.15))
	if st.get("long", false):
		draw_colored_polygon(PackedVector2Array([hc + Vector2(-70, -20), hc + Vector2(70, -20), hc + Vector2(96, 330), hc + Vector2(-96, 330)]), hair.darkened(0.18))
	# волосы сзади
	if st.get("bob", false):
		draw_colored_polygon(Look.ellipse(hc + Vector2(0, 10), Vector2(86, 92), 40), hair.darkened(0.12))
	elif st.get("short", false):
		draw_colored_polygon(Look.ellipse(hc + Vector2(0, -14), Vector2(66, 74), 40), hair.darkened(0.12))
	else:
		draw_colored_polygon(Look.ellipse(hc + Vector2(0, -4), Vector2(78, 90), 40), hair.darkened(0.12))
	# торс
	var torso := PackedVector2Array([
		Vector2(20, 640), Vector2(36, 470 + breath), Vector2(80, 405 + breath), Vector2(160, 378 + breath),
		Vector2(260, 378 + breath), Vector2(340, 405 + breath), Vector2(384, 470 + breath), Vector2(400, 640)])
	Look.fill_v(self, torso, coat.lightened(0.12), coat.darkened(0.45))
	# блуза и вырез
	draw_colored_polygon(PackedVector2Array([Vector2(170, 378 + breath), Vector2(250, 378 + breath), Vector2(232, 470), Vector2(210, 500), Vector2(188, 470)]), Color("f4efe6"))
	draw_polyline(PackedVector2Array([Vector2(80, 405 + breath), Vector2(160, 378 + breath), Vector2(190, 470), Vector2(210, 640)]), trim, 3.0, true)
	draw_polyline(PackedVector2Array([Vector2(340, 405 + breath), Vector2(260, 378 + breath), Vector2(230, 470), Vector2(210, 640)]), trim, 3.0, true)
	# шея и голова
	draw_rect(Rect2(184, 318, 52, 66 + breath), skin.darkened(0.08))
	draw_colored_polygon(Look.ellipse(hc, Vector2(60, 76), 40), skin)
	# глаза
	var eyes := Color(str(st.get("eyes", "445566")))
	for sx in [-24.0, 24.0]:
		var e := hc + Vector2(sx, 6)
		draw_colored_polygon(Look.ellipse(e, Vector2(9, 6), 16), Color("fdfaf6"))
		draw_circle(e + Vector2(0, 0.5), 4.6, eyes)
		draw_circle(e + Vector2(-1.5, -1.5), 1.4, Color(1, 1, 1, 0.9))
		draw_line(e + Vector2(-11, -8), e + Vector2(10, -9), hair.darkened(0.3), 2.0, true)
	draw_arc(hc + Vector2(0, 44), 9, 0.3, PI - 0.3, 10, Color("b06a68"), 2.0, true)
	draw_colored_polygon(Look.ellipse(hc + Vector2(-34, 30), Vector2(10, 5), 12), Color(1, 0.6, 0.6, 0.18))
	draw_colored_polygon(Look.ellipse(hc + Vector2(34, 30), Vector2(10, 5), 12), Color(1, 0.6, 0.6, 0.18))
	# чёлка
	var bangs := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		var r := Vector2(66, 66)
		bangs.append(hc + Vector2(cos(a) * r.x, sin(a) * r.y - 12))
	bangs.append(hc + Vector2(58, -10))
	bangs.append(hc + Vector2(30, -26))
	bangs.append(hc + Vector2(6, -14))
	bangs.append(hc + Vector2(-20, -28))
	bangs.append(hc + Vector2(-58, -6))
	draw_colored_polygon(bangs, hair)
	if st.get("bob", false):
		for sx in [-1.0, 1.0]:
			draw_colored_polygon(PackedVector2Array([hc + Vector2(sx * 58, -20), hc + Vector2(sx * 74, 40), hc + Vector2(sx * 60, 74), hc + Vector2(sx * 48, 30)]), hair)
	if st.get("glasses", false):
		for sx in [-24.0, 24.0]:
			draw_arc(hc + Vector2(sx, 6), 14, 0, TAU, 28, Color("8a8a8a"), 2.0, true)
		draw_line(hc + Vector2(-10, 4), hc + Vector2(10, 4), Color("8a8a8a"), 2.0, true)
	if st.get("glasses_up", false):
		for sx in [-20.0, 20.0]:
			draw_arc(hc + Vector2(sx, -46), 11, 0, TAU, 24, Color("b8b8b8"), 2.0, true)
	if st.get("eyepatch", false):
		draw_colored_polygon(Look.ellipse(hc + Vector2(24, 6), Vector2(14, 11), 20), Color("141414"))
		draw_line(hc + Vector2(-58, -18), hc + Vector2(62, -8), Color("141414"), 2.0, true)
		draw_circle(hc + Vector2(24, 6), 3, Look.GOLD)
	if st.get("horns", false):
		for sx in [-1.0, 1.0]:
			draw_colored_polygon(PackedVector2Array([hc + Vector2(sx * 30, -66), hc + Vector2(sx * 44, -104), hc + Vector2(sx * 50, -64)]), Color("8ac8f0"))
	if st.get("monocle", false):
		var m := hc + Vector2(24, 6)
		draw_arc(m, 13, 0, TAU, 28, Look.GOLD, 2.0, true)
		draw_polyline(PackedVector2Array([m + Vector2(12, 6), m + Vector2(30, 40), m + Vector2(26, 90)]), Color(Look.GOLD, 0.8), 1.2, true)
	# головные уборы
	match str(st.get("hat", "")):
		"kepi":
			var hcol := Color(str(st.get("hat_color", "b3262c")))
			var top := hc + Vector2(-4, -86)
			var kepi := PackedVector2Array([top + Vector2(-66, 34), top + Vector2(-54, -26), top + Vector2(50, -34), top + Vector2(68, 26)])
			Look.fill_v(self, kepi, hcol.lightened(0.1), hcol.darkened(0.3))
			draw_line(top + Vector2(-64, 22), top + Vector2(66, 14), Color("1a1414"), 8.0, true)
			for i in 4:
				draw_circle(top + Vector2(-40 + i * 26, 18 - i * 2), 2.5, Look.GOLD)
			draw_colored_polygon(PackedVector2Array([top + Vector2(-46, 26), top + Vector2(34, 22), top + Vector2(44, 36), top + Vector2(-40, 40)]), Color("141010"))
			var fp := PackedVector2Array()
			for i in 12:
				var tt := i / 11.0
				fp.append(top + Vector2(40 + tt * 70, -20 - sin(tt * PI) * 50 + tt * 30))
			draw_polyline(fp, Color("f6f2ea"), 9.0, true)
		"tricorn":
			var hcol2 := Color(str(st.get("hat_color", "1d2340")))
			var t2 := hc + Vector2(0, -74)
			draw_colored_polygon(PackedVector2Array([t2 + Vector2(-96, 20), t2 + Vector2(0, -40), t2 + Vector2(96, 20), t2 + Vector2(0, 6)]), hcol2)
			draw_polyline(PackedVector2Array([t2 + Vector2(-96, 20), t2 + Vector2(0, 6), t2 + Vector2(96, 20)]), Look.GOLD, 2.5, true)
		"tophat":
			var hc3 := Color(str(st.get("hat_color", "1a1a1a")))
			var tb := hc + Vector2(6, -70)
			draw_colored_polygon(Look.ellipse(tb + Vector2(0, 10), Vector2(74, 14), 28), hc3.darkened(0.2))
			draw_colored_polygon(PackedVector2Array([tb + Vector2(-44, 8), tb + Vector2(-38, -86), tb + Vector2(40, -86), tb + Vector2(46, 8)]), hc3)
			draw_line(tb + Vector2(-44, -6), tb + Vector2(46, -6), Look.GOLD if st.get("crown", false) else Color("6a2a8a"), 6.0, true)
			if st.get("crown", false):
				draw_colored_polygon(PackedVector2Array([tb + Vector2(-20, -86), tb + Vector2(-12, -108), tb + Vector2(0, -92), tb + Vector2(12, -108), tb + Vector2(20, -86)]), Look.GOLD)
		"beret":
			var hc4 := Color(str(st.get("hat_color", "1a1a1a")))
			draw_colored_polygon(Look.ellipse(hc + Vector2(8, -66), Vector2(66, 24), 28), hc4)
			draw_circle(hc + Vector2(8, -88), 5, Look.GOLD)
		"catears", "longears":
			var hc5 := Color(str(st.get("hat_color", "c8ccd4")))
			var tall: float = 150.0 if str(st.get("hat", "")) == "longears" else 70.0
			for sx in [-1.0, 1.0]:
				draw_colored_polygon(PackedVector2Array([hc + Vector2(sx * 22, -60), hc + Vector2(sx * 40, -60 - tall), hc + Vector2(sx * 58, -54)]), hc5)
				draw_colored_polygon(PackedVector2Array([hc + Vector2(sx * 30, -62), hc + Vector2(sx * 40, -48 - tall), hc + Vector2(sx * 50, -58)]), hc5.lightened(0.35))
		"shako":
			var hc6 := Color(str(st.get("hat_color", "141414")))
			draw_colored_polygon(PackedVector2Array([hc + Vector2(-52, -54), hc + Vector2(-44, -140), hc + Vector2(44, -140), hc + Vector2(52, -54)]), hc6)
			draw_line(hc + Vector2(-48, -70), hc + Vector2(48, -70), Color("a01e2a"), 6.0, true)
			draw_line(hc + Vector2(0, -132), hc + Vector2(0, -96), Look.GOLD, 4.0, true)
			draw_line(hc + Vector2(-16, -114), hc + Vector2(16, -114), Look.GOLD, 4.0, true)
		"chefhat":
			draw_colored_polygon(PackedVector2Array([hc + Vector2(-50, -60), hc + Vector2(-46, -110), hc + Vector2(46, -110), hc + Vector2(50, -60)]), Color("ffffff"))
			for k in 3:
				draw_circle(hc + Vector2(-34 + k * 34, -120), 30, Color("ffffff"))
			draw_line(hc + Vector2(-50, -66), hc + Vector2(50, -66), Color("6ab0e0"), 5.0, true)
		"nursecap":
			draw_colored_polygon(Look.rrect(Rect2(hc + Vector2(-26, -96), Vector2(52, 26)), 4), Color("ffffff"))
			draw_line(hc + Vector2(-26, -76), hc + Vector2(26, -76), Color("d02040"), 3.0, true)
		"flowers":
			for sx in [-1.0, 1.0]:
				var fc := hc + Vector2(sx * 60, -40)
				for k in 5:
					draw_circle(fc + Vector2.from_angle(TAU * k / 5.0) * 10, 8, Color(str(st.get("hat_color", "f0f0ff"))))
				draw_circle(fc, 6, Look.GOLD)
		"halo":
			draw_arc(hc + Vector2(0, -100), 46, PI * 1.1, PI * 1.9, 24, Color(str(st.get("hat_color", "f0c080"))), 6.0, true)
		"bun":
			draw_circle(hc + Vector2(0, -78), 34, hair)
			draw_line(hc + Vector2(-40, -90), hc + Vector2(44, -70), Color("c0392b"), 3.0, true)
			draw_circle(hc + Vector2(30, -96), 12, Color("f08a24"))
