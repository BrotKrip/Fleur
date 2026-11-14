class_name PlaceSpread
extends Control
## Открытка места, где сейчас Флёр: картинка, пара строк о месте, люди рядом и чем можно заняться.

signal action_chosen(action: Dictionary)
signal person_clicked(pid: String)

const IMG_W := 230.0

var loc := ""
var list: VBoxContainer
var people_row: HBoxContainer
var desc: Label
var action_scroll: ScrollContainer


func _ready() -> void:
	size = Vector2(660, 262)
	mouse_filter = Control.MOUSE_FILTER_STOP
	rotation = 0.006
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	desc = Label.new()
	desc.theme_type_variation = "InkSoft"
	desc.add_theme_font_override("font", Look.font("serif_italic"))
	desc.add_theme_font_size_override("font_size", 14)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.max_lines_visible = 3
	desc.position = Vector2(IMG_W + 22, 14)
	desc.size = Vector2(size.x - IMG_W - 38, 60)
	add_child(desc)
	action_scroll = ScrollContainer.new()
	action_scroll.position = Vector2(IMG_W + 16, 78)
	action_scroll.size = Vector2(size.x - IMG_W - 30, size.y - 94)
	action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	action_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	action_scroll.follow_focus = true
	add_child(action_scroll)
	_style_scrollbar(action_scroll.get_v_scroll_bar())
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 0)
	action_scroll.add_child(list)
	people_row = HBoxContainer.new()
	people_row.position = Vector2(12, size.y - 44)
	people_row.size = Vector2(IMG_W - 20, 34)
	people_row.add_theme_constant_override("separation", 4)
	add_child(people_row)
	refresh()


func _style_scrollbar(bar: ScrollBar) -> void:
	bar.custom_minimum_size.x = 8
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.3, 0.22, 0.12, 0.09)
	track.set_corner_radius_all(3)
	track.content_margin_left = 4
	track.content_margin_right = 4
	bar.add_theme_stylebox_override("scroll", track)
	var handle := StyleBoxFlat.new()
	handle.bg_color = Color(0.46, 0.33, 0.16, 0.48)
	handle.set_corner_radius_all(3)
	handle.content_margin_left = 4
	handle.content_margin_right = 4
	bar.add_theme_stylebox_override("grabber", handle)
	var active := handle.duplicate() as StyleBoxFlat
	active.bg_color = Color(0.43, 0.29, 0.12, 0.8)
	bar.add_theme_stylebox_override("grabber_highlight", active)
	bar.add_theme_stylebox_override("grabber_pressed", active)


func refresh() -> void:
	var s := Game.state
	var new_loc := str(s.get("here", "loc_apartment"))
	if new_loc != loc:
		action_scroll.scroll_vertical = 0
	loc = new_loc
	var d := Content.def(loc)
	desc.text = Rules.txt(d.get("text"), s)
	for c in list.get_children():
		c.queue_free()
	for c in people_row.get_children():
		c.queue_free()
	for a in Rules.actions_for(s, loc):
		var ctx := Rules.action_ctx(a, loc, {})
		var check := Rules.can_do(a, s, ctx)
		var enabled: bool = check["ok"] or check.get("needs_slot", false)
		var b := Button.new()
		b.theme_type_variation = "InkButton"
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 17)
		var cost := Rules.cost_of(a, s)
		var marks := " " + "◷".repeat(mini(cost, 4)) if cost > 0 else ""
		var lead := "◆ " if str(a.get("intent", "")) == "main" else "— "
		b.text = lead + str(a["title"]) + marks
		b.disabled = not enabled
		if not enabled:
			b.tooltip_text = check["reason"]
			var why := str(check["reason"]).trim_suffix(".").to_lower()
			if (b.text + why).length() < 62:
				b.text += "   (" + why + ")"
			b.add_theme_font_size_override("font_size", 15)
		elif a.has("slots"):
			b.tooltip_text = "Понадобится выбрать: " + ", ".join(PackedStringArray(a["slots"].map(func(sl): return str(sl["label"]).to_lower())))
		b.clip_text = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var act: Dictionary = a
		b.pressed.connect(func():
			action_chosen.emit(act))
		list.add_child(b)
	for pid in Rules.people_at(s, loc):
		var pb := Button.new()
		pb.theme_type_variation = "InkButton"
		pb.text = Rules.title_of(pid, s)
		pb.add_theme_color_override("font_color", Color("f2e6c8"))
		pb.add_theme_color_override("font_hover_color", Color("ffe9a8"))
		pb.add_theme_font_size_override("font_size", 15)
		var p: String = pid
		pb.pressed.connect(func():
			person_clicked.emit(p))
		people_row.add_child(pb)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var card := Look.rrect(r, 4)
	Look.soft_shadow(self, card, Vector2(6, 10), 10, 0.55)
	Look.fill_v(self, card, Color("f4ecda"), Color("e4d6b8"))
	Look.texture_polygon(self, card, Art.surface("paper"), 1.0, Color(1, 1, 1, 0.62))
	Look.engraved_corners(self, Rect2(IMG_W + 6, 7, size.x - IMG_W - 14, size.y - 14), Color(0.46, 0.35, 0.17, 0.25), 12)
	# картинка места
	var img := Rect2(10, 10, IMG_W - 10, size.y - 20)
	var bg_id := str(Content.def(loc).get("bg", ""))
	var phase := int(Game.state.get("phase", 0))
	if bg_id == "docks" and phase == 3:
		bg_id = "docks_night"
	elif bg_id == "apartment" and phase >= 2:
		bg_id = "apartment_evening" if phase == 2 else "apartment_night"
	var bg := Content.background(bg_id)
	var cols: Array = bg.get("colors", ["#445566", "#223344", "#112233"])
	var pts := Look.rrect(img, 3)
	var top := Color(str(cols[0]))
	var mid := Color(str(cols[1])) if cols.size() > 1 else top
	var bot := Color(str(cols[2])) if cols.size() > 2 else mid
	var vcols := PackedColorArray()
	for p in pts:
		var t := (p.y - img.position.y) / img.size.y
		vcols.append(top.lerp(mid, t * 2.0) if t < 0.5 else mid.lerp(bot, (t - 0.5) * 2.0))
	draw_polygon(pts, vcols)
	var artwork := Art.background(bg_id)
	if artwork:
		Look.draw_cover(self, artwork, img)
		Look.fill_v(self, pts, Color(0.02, 0.04, 0.06, 0.78), Color(0.02, 0.04, 0.06, 0.04))
	else:
		# Резервный рисунок для места без иллюстрации.
		var rng := RandomNumberGenerator.new()
		rng.seed = Look.hash_seed(loc)
		var base_y := img.end.y - 70
		for i in 9:
			var w := rng.randf_range(16, 34)
			var x := img.position.x + i * 26 + rng.randf_range(-4, 4)
			var h := rng.randf_range(30, 90)
			draw_rect(Rect2(x, base_y - h, w, h + 70), Color(0.05, 0.06, 0.1, 0.22))
	draw_rect(Rect2(img.position.x, img.end.y - 56, img.size.x, 56), Color(0, 0, 0, 0.35))
	var tf := Look.font("serif_bold")
	var tname := Rules.title_of(loc, Game.state)
	draw_multiline_string(tf, Vector2(img.position.x + 12, img.position.y + 34), tname, HORIZONTAL_ALIGNMENT_LEFT, img.size.x - 24, 22, 2, Color("fff6e0"))
	var th := tf.get_multiline_string_size(tname, HORIZONTAL_ALIGNMENT_LEFT, img.size.x - 24, 22, 2).y
	draw_multiline_string(Look.font("serif_italic"), Vector2(img.position.x + 12, img.position.y + 30 + th), str(Content.def(loc).get("subtitle", "")), HORIZONTAL_ALIGNMENT_LEFT, img.size.x - 24, 14, 2, Color(1, 0.96, 0.88, 0.85))
	if Rules.people_at(Game.state, loc).size() > 0:
		draw_string(Look.font("serif_italic"), Vector2(img.position.x + 12, img.end.y - 40), "Здесь сейчас:", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.95, 0.85, 0.7))
	Look.outline(self, pts, Color(0, 0, 0, 0.3))
	# Тонкая рамка старой открытки.
	draw_rect(img.grow(-4), Color(0.94, 0.83, 0.59, 0.45), false, 1.0)
	# марка в углу и штрих-разделитель
	draw_line(Vector2(IMG_W + 14, 70), Vector2(size.x - 18, 70), Color(0.4, 0.3, 0.2, 0.3), 1.0)
	Look.outline(self, card, Color(0.4, 0.3, 0.2, 0.4))
