extends Control
## Главное меню: вечерняя вода у стен Кур-де-Фонтейна и название.

const Decor := preload("res://ui/ambient_canvas.gd")
var _artwork: Texture2D
var _atmosphere: Control
var _box: VBoxContainer
var _foot: Label
var _title: Label
var _sub: Label
var _gap: Control
var _first_item: Button


func _ready() -> void:
	Sound.environment("backgrounds", "menu", "evening")
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/backdrop.gdshader")
	m.set_shader_parameter("c_top", Color("0b1424"))
	m.set_shader_parameter("c_mid", Color("1b3d55"))
	m.set_shader_parameter("c_bot", Color("0d2534"))
	m.set_shader_parameter("water", 1.0)
	m.set_shader_parameter("shafts", 0.5)
	bg.material = m
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_artwork = Art.background("city")
	if _artwork:
		var painting := TextureRect.new()
		painting.texture = _artwork
		painting.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		painting.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		painting.set_anchors_preset(Control.PRESET_FULL_RECT)
		painting.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(painting)
	_atmosphere = Control.new()
	_atmosphere.set_anchors_preset(Control.PRESET_FULL_RECT)
	_atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_atmosphere.draw.connect(_draw_atmosphere)
	add_child(_atmosphere)
	add_child(Decor.new(17))

	var box := VBoxContainer.new()
	_box = box
	box.custom_minimum_size.x = 405
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 13)
	box.add_child(heading)
	var crest := Control.new()
	crest.custom_minimum_size = Vector2(159, 38)
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crest.draw.connect(Decor.crest.bind(crest))
	heading.add_child(crest)
	var kicker := Label.new()
	kicker.text = "КУР-ДЕ-ФОНТЕЙН   /   I"
	kicker.add_theme_color_override("font_color", Color("b4c9c7"))
	kicker.add_theme_font_override("font", Look.font("sans"))
	kicker.add_theme_font_size_override("font_size", 13)
	heading.add_child(kicker)
	var title := Label.new()
	_title = title
	title.text = "Послевкусие"
	title.add_theme_font_override("font", Look.font("display"))
	title.add_theme_font_size_override("font_size", 68)
	title.add_theme_color_override("font_color", Color("f4e8ca"))
	title.add_theme_constant_override("line_spacing", -6)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("shadow_offset_y", 3)
	box.add_child(title)
	var sub := Label.new()
	_sub = sub
	sub.text = "коллекционер прекрасных мгновений"
	sub.add_theme_font_override("font", Look.font("display_italic"))
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color("c3b8a5"))
	box.add_child(sub)
	var gap := Control.new()
	_gap = gap
	gap.custom_minimum_size = Vector2(0, 28)
	box.add_child(gap)

	var latest := Game.latest_slot()
	if latest != "":
		_item(box, "Продолжить", func():
			Game.load_slot(latest))
	_item(box, "Новая партия", func():
		if latest != "":
			Dialogs.confirm("Начать новую партию? Записи останутся, автосохранение будет перезаписано.", Game.new_game)
		else:
			Game.new_game())
	_item(box, "Загрузить", func():
		Dialogs.saves("load"))
	_item(box, "Настройки", Dialogs.settings)
	_item(box, "Выйти", Game.main.quit_game)

	var foot := Label.new()
	_foot = foot
	foot.text = "Фанатский проект по миру Genshin Impact   ·   Музыка HOYO-MiX"
	foot.add_theme_font_size_override("font_size", 14)
	foot.add_theme_font_override("font", Look.font("sans"))
	foot.add_theme_color_override("font_color", Color(0.77, 0.75, 0.67, 0.85))
	foot.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	foot.position = Vector2(140, -50)
	add_child(foot)
	resized.connect(_layout)
	_layout()
	box.modulate.a = 0.0
	create_tween().tween_property(box, "modulate:a", 1.0, 1.2)


func on_shown() -> void:
	if _first_item and not get_viewport().gui_get_focus_owner():
		_first_item.grab_focus()


func _layout() -> void:
	var compact := size.y < 710.0
	_title.add_theme_font_size_override("font_size", 52 if compact else 68)
	_sub.add_theme_font_size_override("font_size", 18 if compact else 20)
	_gap.custom_minimum_size.y = 12 if compact else 27
	_box.position = Vector2(maxf(55.0, size.x * 0.076), maxf(50.0, size.y * (0.088 if compact else 0.115)))
	_foot.position = Vector2(_box.position.x, size.y - 48)
	_atmosphere.queue_redraw()


func _item(box: VBoxContainer, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = "MenuItem"
	b.add_theme_font_size_override("font_size", 23)
	b.custom_minimum_size = Vector2(326, 43)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.035, 0.095, 0.115, 0.64)
	normal.border_color = Color(0.76, 0.65, 0.43, 0.40)
	normal.border_width_bottom = 1
	normal.content_margin_left = 33
	normal.content_margin_right = 47
	normal.content_margin_top = 5
	normal.content_margin_bottom = 5
	var highlighted := normal.duplicate() as StyleBoxFlat
	highlighted.bg_color = Color("23464bef")
	highlighted.border_color = Color("d8bb82")
	highlighted.border_width_left = 2
	var focus := highlighted.duplicate() as StyleBoxFlat
	focus.bg_color = Color.TRANSPARENT
	focus.set_border_width_all(1)
	for state in ["hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, highlighted)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("focus", focus)
	b.add_theme_color_override("font_color", Color("ecdfbf"))
	b.add_theme_color_override("font_focus_color", Color("fff0c8"))
	b.draw.connect(Decor.menu_mark.bind(b))
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(cb)
	box.add_child(b)
	if not _first_item:
		_first_item = b


func on_escape() -> void:
	pass


func _draw_atmosphere() -> void:
	var c := _atmosphere
	var s := c.size
	if s.x < 60 or s.y < 60:
		return
	if not _artwork:
		_draw_city(c)
	# Плотная тень под названием растворяется в панораме города.
	var points := PackedVector2Array([Vector2.ZERO, Vector2(s.x * 0.72, 0), Vector2(s.x * 0.72, s.y), Vector2(0, s.y)])
	c.draw_polygon(points, PackedColorArray([Color(0.02, 0.05, 0.08, 0.95), Color(0.02, 0.05, 0.08, 0), Color(0.02, 0.05, 0.08, 0), Color(0.02, 0.05, 0.08, 0.95)]))
	Look.fill_v(c, Look.rrect(Rect2(0, s.y * 0.72, s.x, s.y * 0.28), 0), Color(0.02, 0.04, 0.06, 0), Color(0.02, 0.04, 0.06, 0.88))
	c.draw_rect(Rect2(25, 25, s.x - 50, s.y - 50), Color(0.85, 0.72, 0.46, 0.22), false, 1.0)
	Decor.corners(c, Rect2(25, 25, s.x - 50, s.y - 50), 46)


func _draw_city(c: Control) -> void:
	var s := c.size
	var base := s.y * 0.68
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var x := s.x * 0.48
	var col := Color(0.03, 0.06, 0.1, 0.9)
	# стена
	c.draw_rect(Rect2(x, base - 40, s.x - x, 60), col)
	while x < s.x:
		var w := rng.randf_range(30, 70)
		var h := rng.randf_range(40, 170)
		c.draw_rect(Rect2(x, base - 40 - h, w, h), col)
		if rng.randf() < 0.35:
			c.draw_colored_polygon(Look.ellipse(Vector2(x + w / 2, base - 40 - h), Vector2(w / 2, 18), 20), Color(0.05, 0.16, 0.18, 0.95))
		for k in rng.randi_range(0, 4):
			c.draw_rect(Rect2(x + rng.randf_range(4, w - 8), base - 40 - rng.randf_range(10, h - 10), 3, 5), Color(1.0, 0.8, 0.45, 0.6))
		x += w + rng.randf_range(0, 8)
	for i in 6:
		var cx := s.x * (0.52 + i * 0.09)
		c.draw_circle(Vector2(cx, base - 220 + i * 7), 3, Color(0.45, 0.8, 1.0, 0.8))
	# отражение
	c.draw_rect(Rect2(s.x * 0.48, base + 20, s.x * 0.52, s.y - base), Color(0.02, 0.05, 0.08, 0.35))
