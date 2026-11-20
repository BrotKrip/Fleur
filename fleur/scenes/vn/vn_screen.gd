extends Control
## Режим визуальной новеллы. Проигрывает сцену из res://data/scenes, применяет её эффекты
## к состоянию игры и по завершении возвращает список изменений на стол.
##
## Узлы сцены: { bg }, { show, at }, { hide }, { n } — повествование, { s, t } — реплика,
## { choice: [{ t, when, effects, goto }] }, { label }, { goto }, { if, goto }, { do }, { end }.

const Decor := preload("res://ui/ambient_canvas.gd")
const FIGURE_LIGHT := preload("res://shaders/figure_lighting.gdshader")
const BACKGROUND_FADE := 0.65
static var _backdrop_colors: Dictionary[String, PackedColorArray] = {}
var scene: Dictionary
var ctx: Dictionary
var api: Dictionary
var nodes: Array
var labels := {}
var hub_at := -1        # индекс последнего хаба тем, куда ведёт @back
var hub_taken := {}     # "индекс:метка" уже выбранных тем
var i := 0
var history: Array = []

var backdrop: ColorRect
var bg_mat: ShaderMaterial
var background_art: TextureRect
var previous_art: TextureRect
var background_tween: Tween
var figure_material := ShaderMaterial.new()
var lighting_tween: Tween
var current_bg := ""
var score_override := ""
var shot_lighting := ""
var lighting_phase := -1
var place_label: Label
var scene_label: Label
var location_plaque: Control
var input_hint: Label
var dialog_scroll: ScrollContainer
var figures_layer: Control
var figures := {}
var box: PanelContainer
var name_plate: PanelContainer
var name_label: Label
var text_label: Label
var cont_mark: Label
var choices: VBoxContainer
var choice_scroll: ScrollContainer

var waiting := ""     # "click" | "choice"
var tool_bar: HBoxContainer
var skip_button: Button
var skip_on := false      # кнопка «Пропуск»; Ctrl держит пропуск, пока зажат
var _skip_t := 0.0
var ui_hidden := false    # «Скрыть»: остаются фон и фигуры
var typing := false
var _shown_chars := 0.0
var _finished := false
var _t := 0.0


func setup(sc: Dictionary, c: Dictionary) -> void:
	scene = sc
	score_override = str(sc.get("music", ""))
	ctx = c.duplicate()
	api = Rules.new_api()
	nodes = sc.get("nodes", [])
	for k in nodes.size():
		if nodes[k].has("label"):
			labels[nodes[k]["label"]] = k


func get_title() -> String:
	return str(scene.get("title", ""))


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_mat = ShaderMaterial.new()
	bg_mat.shader = load("res://shaders/backdrop.gdshader")
	backdrop.material = bg_mat
	add_child(backdrop)
	for layer in 2:
		var art := TextureRect.new()
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(art)
		if layer == 0:
			background_art = art
		else:
			previous_art = art
			previous_art.visible = false

	# Затемнение краёв помогает отделить фигуры и подписи от подробного фона.
	var atmosphere := ColorRect.new()
	atmosphere.set_anchors_preset(Control.PRESET_FULL_RECT)
	atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var atmosphere_material := ShaderMaterial.new()
	var atmosphere_shader := Shader.new()
	atmosphere_shader.code = "shader_type canvas_item; render_mode unshaded; void fragment() { vec2 p = UV - vec2(0.5); float edge = smoothstep(0.24, 0.71, length(p)); float top = 0.30 * (1.0 - smoothstep(0.0, 0.23, UV.y)); float bottom = 0.35 * smoothstep(0.55, 1.0, UV.y); COLOR = vec4(0.025, 0.040, 0.055, clamp(edge * 0.36 + top + bottom, 0.0, 0.65)); }"
	atmosphere_material.shader = atmosphere_shader
	atmosphere.material = atmosphere_material
	add_child(atmosphere)
	add_child(Decor.new(11))

	figures_layer = Control.new()
	figure_material.shader = FIGURE_LIGHT
	figure_material.set_shader_parameter("figure_width", VNFigure.FRAME_SIZE.x)
	figures_layer.material = figure_material
	figures_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	figures_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(figures_layer)

	location_plaque = Control.new()
	location_plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	location_plaque.position = Vector2(32, 20)
	location_plaque.draw.connect(Decor.location.bind(location_plaque))
	add_child(location_plaque)
	place_label = Label.new()
	place_label.position = Vector2(56, 26)
	place_label.add_theme_font_override("font", Look.font("display"))
	place_label.add_theme_font_size_override("font_size", 19)
	place_label.add_theme_color_override("font_color", Color("f0e4c7"))
	place_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	place_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(place_label)
	scene_label = Label.new()
	scene_label.position = Vector2(56, 52)
	scene_label.text = ""
	scene_label.visible = false
	scene_label.add_theme_font_override("font", Look.font("display_italic"))
	scene_label.add_theme_font_size_override("font_size", 14)
	scene_label.add_theme_color_override("font_color", Color("d6c7a8"))
	scene_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	add_child(scene_label)

	# Диалоговая рамка
	box = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.075, 0.085, 0.95)
	sb.border_color = Color(0.72, 0.60, 0.37, 0.8)
	sb.set_border_width_all(1)
	sb.border_width_top = 2
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 32
	sb.content_margin_bottom = 26
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 24
	box.add_theme_stylebox_override("panel", sb)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.draw.connect(Decor.dialogue.bind(box, Art.surface("leather")))
	add_child(box)
	dialog_scroll = ScrollContainer.new()
	dialog_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# полосы прокрутки нет: шрифт реплики подбирается так, чтобы она помещалась целиком
	dialog_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	dialog_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(dialog_scroll)
	text_label = Label.new()
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_font_size_override("font_size", 23)
	text_label.add_theme_color_override("font_color", Color("f1e8d6"))
	text_label.add_theme_constant_override("line_spacing", 6)
	text_label.custom_minimum_size = Vector2(0, 110)
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	# Курсив выступает за левый край строки («Д», «У»): без поля прокрутка срезает его.
	var text_margin := MarginContainer.new()
	text_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_margin.add_theme_constant_override("margin_left", TEXT_INSET)
	text_margin.add_theme_constant_override("margin_right", TEXT_INSET)
	text_margin.add_child(text_label)
	dialog_scroll.add_child(text_margin)

	name_plate = PanelContainer.new()
	var np := StyleBoxFlat.new()
	np.bg_color = Color("1c393d")
	np.border_color = Color("b59b68")
	np.set_border_width_all(1)
	np.set_corner_radius_all(2)
	np.content_margin_left = 29
	np.content_margin_right = 29
	np.content_margin_top = 8
	np.content_margin_bottom = 8
	name_plate.add_theme_stylebox_override("panel", np)
	name_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_plate.draw.connect(Decor.nameplate.bind(name_plate))
	name_label = Label.new()
	name_label.add_theme_font_override("font", Look.font("display_bold"))
	name_label.add_theme_font_size_override("font_size", 22)
	name_plate.add_child(name_label)
	add_child(name_plate)

	cont_mark = Label.new()
	cont_mark.text = "❧"
	cont_mark.add_theme_color_override("font_color", Look.GOLD)
	cont_mark.add_theme_font_size_override("font_size", 24)
	add_child(cont_mark)
	input_hint = Label.new()
	input_hint.text = ""
	input_hint.add_theme_font_override("font", Look.font("sans"))
	input_hint.add_theme_font_size_override("font_size", 14)
	input_hint.add_theme_color_override("font_color", Color("d4d9cd"))
	input_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	input_hint.add_theme_constant_override("shadow_offset_y", 1)
	input_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(input_hint)

	choice_scroll = ScrollContainer.new()
	choice_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	choice_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	choice_scroll.follow_focus = true
	choice_scroll.visible = false
	var choice_bar := choice_scroll.get_v_scroll_bar()
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.03, 0.06, 0.07, 0.75)
	track.content_margin_left = 7
	track.content_margin_right = 7
	track.set_corner_radius_all(5)
	choice_bar.add_theme_stylebox_override("scroll", track)
	var thumb := StyleBoxFlat.new()
	thumb.bg_color = Color("c5a66d")
	thumb.content_margin_top = 10
	thumb.content_margin_bottom = 10
	thumb.set_corner_radius_all(5)
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		choice_bar.add_theme_stylebox_override(state, thumb)
	add_child(choice_scroll)
	var choice_margin := MarginContainer.new()
	choice_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for edge in ["left", "right", "top", "bottom"]:
		choice_margin.add_theme_constant_override("margin_" + edge, 14)
	choice_scroll.add_child(choice_margin)
	choices = VBoxContainer.new()
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.add_theme_constant_override("separation", 12)
	choice_margin.add_child(choices)

	var tools := HBoxContainer.new()
	tool_bar = tools
	tools.add_theme_constant_override("separation", 4)
	tools.draw.connect(func(): tools.draw_texture_rect(Decor.haze(), Rect2(-60, -26, tools.size.x + 120, tools.size.y + 52), false))
	for pair in [["Пропуск", _toggle_skip], ["Скрыть", _toggle_ui], ["История", _show_history], ["Настройки", Dialogs.settings]]:
		var b := Button.new()
		b.text = pair[0]
		b.add_theme_font_size_override("font_size", 15)
		# Лёгкие надписи вместо четырёх плашек: сцена не закрыта рамками, латунь — только под курсором.
		var tool_style := StyleBoxFlat.new()
		tool_style.bg_color = Color(0, 0, 0, 0)
		tool_style.border_color = Color(Decor.BRASS, 0.0)
		tool_style.border_width_bottom = 1
		tool_style.content_margin_left = 11
		tool_style.content_margin_right = 11
		tool_style.content_margin_top = 6
		tool_style.content_margin_bottom = 6
		var tool_hover := tool_style.duplicate() as StyleBoxFlat
		tool_hover.border_color = Color(Decor.PALE_BRASS, 0.9)
		var tool_active := tool_style.duplicate() as StyleBoxFlat
		tool_active.bg_color = Color(0.09, 0.22, 0.24, 0.75)
		tool_active.border_color = Decor.PALE_BRASS
		tool_active.set_corner_radius_all(2)
		b.add_theme_stylebox_override("normal", tool_style)
		b.add_theme_stylebox_override("hover", tool_hover)
		b.add_theme_stylebox_override("pressed", tool_active)
		b.add_theme_color_override("font_color", Color(0.95, 0.88, 0.74, 0.86))
		b.add_theme_color_override("font_hover_color", Color("fff3d6"))
		b.add_theme_color_override("font_pressed_color", Color("fff3d6"))
		b.add_theme_color_override("font_hover_pressed_color", Color("fff3d6"))
		b.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.06, 0.8))
		b.add_theme_constant_override("outline_size", 4)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.pressed.connect(pair[1])
		b.focus_mode = Control.FOCUS_NONE
		match pair[0]:
			"Пропуск":
				skip_button = b
				b.toggle_mode = true
				b.add_theme_stylebox_override("hover_pressed", tool_active)
				b.tooltip_text = "Пропускать реплики до следующего выбора. Зажатый Ctrl делает то же самое, пока держишь."
			"Скрыть":
				b.tooltip_text = "Спрятать рамку и кнопки, чтобы рассмотреть сцену (V или правая кнопка мыши). Любой щелчок вернёт их."
			"История":
				b.tooltip_text = "Что было сказано (H, L или колесо вверх)."
		tools.add_child(b)
	add_child(tools)

	resized.connect(_layout)
	_layout()
	_run.call_deferred()


func on_escape() -> void:
	Dialogs.pause()


func _layout() -> void:
	var s := size if size.x > 10 else get_viewport_rect().size
	var w := minf(1180.0, s.x - 80)
	box.position = Vector2((s.x - w) / 2, s.y - 244)
	box.size = Vector2(w, 200)
	name_plate.position = box.position + Vector2(30, -22)
	cont_mark.position = box.position + Vector2(w - 50, 160)
	input_hint.position = Vector2(box.position.x + 4, s.y - 32)
	tool_bar.reset_size()
	tool_bar.position = Vector2(s.x - tool_bar.size.x - 24, 28)
	_fit_location()
	# Ответы занимают отдельную половину сцены; размер задаётся экраном, а не
	# ещё не рассчитанной высотой VBox. Длинный список прокручивается внутри неё.
	choice_scroll.visible = waiting == "choice" and not ui_hidden
	var choice_width := minf(700.0, s.x * 0.48)
	var choice_top := maxf(112.0, s.y * 0.21)
	choice_scroll.position = Vector2(s.x - choice_width - 30.0 if _choices_on_right() else 30.0, choice_top)
	choice_scroll.size = Vector2(choice_width, maxf(120.0, box.position.y - choice_top - 28.0))
	for id in figures:
		_place_figure(figures[id])
	_fit_text()


const TEXT_FS_MAX := 23
const TEXT_INSET := 8
const TEXT_FS_MIN := 14


## Подбирает размер шрифта реплики: самый крупный (до 23), при котором текст целиком
## помещается в окно диалога. Прокрутка остаётся только запасным вариантом для очень
## длинных реплик и делается щелчком, без видимой полосы.
func _fit_text() -> void:
	if text_label == null or box == null or text_label.text == "":
		return
	var sb := box.get_theme_stylebox("panel")
	var avail := box.size - Vector2(sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT), sb.get_margin(SIDE_TOP) + sb.get_margin(SIDE_BOTTOM))
	if avail.x < 50 or avail.y < 20:
		return
	var font := text_label.get_theme_font("font")
	var spacing := text_label.get_theme_constant("line_spacing")
	var flags := TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	var fs := TEXT_FS_MAX
	while fs > TEXT_FS_MIN:
		var lines := _wrapped_lines(font, text_label.text, avail.x - 4 - TEXT_INSET * 2, fs, flags)
		var h := lines * font.get_height(fs) + maxi(0, lines - 1) * spacing
		if h <= avail.y:
			break
		fs -= 1
	text_label.add_theme_font_size_override("font_size", fs)
	text_label.custom_minimum_size = Vector2(0, minf(110.0, avail.y))


func _wrapped_lines(font: Font, text: String, width: float, fs: int, flags: int) -> int:
	var n := 0
	for para in text.split("
"):
		var ts := TextServerManager.get_primary_interface()
		var rid := ts.create_shaped_text()
		ts.shaped_text_add_string(rid, para if para != "" else " ", font.get_rids(), fs)
		var breaks := ts.shaped_text_get_line_breaks(rid, width, 0, flags)
		n += maxi(1, breaks.size() / 2)
		ts.free_rid(rid)
	return n


func _fit_location() -> void:
	var s := size if size.x > 10 else get_viewport_rect().size
	var width := 0.0
	for title: Label in [place_label, scene_label]:
		var font := title.get_theme_font("font")
		width = maxf(width, font.get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, title.get_theme_font_size("font_size")).x)
	width = clampf(ceilf(width), 130.0, maxf(130, s.x - 370.0))
	for title: Label in [place_label, scene_label]:
		title.clip_text = true
		title.size.x = width + 3
	# Линейка ложится сразу под последней строкой, без пустого поля под названием.
	location_plaque.size = Vector2(width + 53, 58 if scene_label.visible and scene_label.text != "" else 40)
	location_plaque.queue_redraw()


func _place_figure(f: VNFigure) -> void:
	var s := size if size.x > 10 else get_viewport_rect().size
	var at := str(f.get_meta("at", "center"))
	var x: float = s.x * {"left": 0.24, "center": 0.5, "right": 0.72}.get(at, 0.5)
	var normal_scale := clampf(s.y / 900.0 * 1.3, 0.8, 1.6)
	f.base_scale = normal_scale
	var lift := 0.0
	if waiting == "choice":
		if figures.size() <= 1:
			x = s.x * (0.26 if _choices_on_right() else 0.75)
		else:
			var ids := figures.keys()
			var index := ids.find(f.pid)
			var stage_width := s.x * 0.41
			x = s.x * 0.56 + stage_width * (float(index) + 0.5) / float(ids.size())
			# Места достаточно, когда соседние лица читаются отдельно. Плечи могут перекрываться.
			f.base_scale = minf(normal_scale, maxf(0.55, stage_width / (float(ids.size()) * 180.0)))
	var character := Content.def(f.pid)
	var portrait_scale := float(character.get("vn_scale", 1.0))
	if character.get("vn_float", false):
		# Парящая фигура держится у плеча собеседника, ступни видны над репликой.
		lift = maxf(f.base_scale * f.size.y * 0.32, s.y - box.position.y + 12.0)
	# Один нижний край для всех стоящих фигур, в том числе при выборе ответа.
	f.base_scale *= portrait_scale
	f.position = Vector2(x - f.size.x / 2, s.y - f.size.y - lift)


func _choices_on_right() -> bool:
	if figures.size() != 1:
		return false
	var f: VNFigure = figures.values()[0]
	return str(f.get_meta("at", "center")) == "left"


# ---------------------------------------------------------------- проигрывание

func _run() -> void:
	var s := Game.state
	var guard := 0
	while i < nodes.size():
		guard += 1
		if guard > 2000:
			push_error("VN: зацикливание")
			break
		var n: Dictionary = nodes[i]
		if n.has("label"):
			i += 1
		elif n.has("bg"):
			_set_bg(str(n["bg"]), str(n.get("lighting", "")))
			i += 1
		elif n.has("show"):
			_show(str(n["show"]), str(n.get("at", "center")), str(n.get("mood", "")))
			i += 1
		elif n.has("mood"):
			_set_mood(str(n["mood"]), str(n.get("as", "")))
			i += 1
		elif n.has("look"):
			var pid := str(n["look"])
			looks[pid] = str(n.get("as", ""))
			if figures.has(pid):
				figures[pid].set_look(looks[pid])
			i += 1
		elif n.has("hide"):
			_hide(str(n["hide"]))
			i += 1
		elif n.has("do"):
			Rules.apply(n["do"], s, ctx, api)
			i += 1
		elif n.has("sfx"):
			Sound.play(n["sfx"])
			i += 1
		elif n.has("score"):
			score_override = "" if n["score"] == "auto" else str(n["score"])
			Sound.set_background_music(current_bg, score_override)
			i += 1
		elif n.has("if"):
			i = labels[n["goto"]] if Rules.test(n["if"], s, ctx) else i + 1
		elif n.has("goto"):
			i = labels[n["goto"]]
		elif n.has("end"):
			_finish()
			return
		elif n.has("n"):
			_say("", Rules.txt(n["n"], s, ctx))
			return
		elif n.has("s"):
			if n.has("as"):
				_set_mood(str(n["s"]), str(n["as"]))
			_say(str(n["s"]), Rules.txt(n.get("t"), s, ctx))
			return
		elif n.has("back"):
			if hub_at < 0:
				push_error("VN: @back без @hub")
				i += 1
			else:
				i = hub_at
		elif n.has("choice"):
			if n.get("hub", false):
				hub_at = i
				if not _has_options(n["choice"], true):
					i += 1
					continue
			_show_choice(n["choice"])
			return
		else:
			i += 1
	_finish()


func _set_bg(id: String, light_profile := "") -> void:
	var had_bg := not current_bg.is_empty()
	current_bg = id
	shot_lighting = light_profile
	if background_tween:
		background_tween.kill()
	previous_art.texture = background_art.texture
	previous_art.modulate = background_art.modulate
	previous_art.visible = previous_art.texture != null
	background_art.texture = Art.background(id)
	_apply_environment(had_bg, false)
	if previous_art.visible:
		background_tween = create_tween()
		background_tween.tween_property(previous_art, "modulate:a", 0.0, BACKGROUND_FADE)
		background_tween.tween_callback(func(): previous_art.visible = false)
	var b := Content.background(id)
	var cols: Array = b.get("colors", ["#223344", "#334455", "#112233"])
	var c0 := Color(str(cols[0]))
	var c1 := Color(str(cols[1])) if cols.size() > 1 else c0
	var c2 := Color(str(cols[2])) if cols.size() > 2 else c1
	bg_mat.set_shader_parameter("c_top", c0)
	bg_mat.set_shader_parameter("c_mid", c1)
	bg_mat.set_shader_parameter("c_bot", c2)
	bg_mat.set_shader_parameter("water", 1.0 if id in ["vasari", "docks"] else 0.0)
	bg_mat.set_shader_parameter("shafts", 0.2 if id.contains("night") else 0.7)
	place_label.text = str(b.get("label", ""))
	_fit_location()


## Усредняем на уровне лиц и плеч. В кэше остаются только два цвета без текстуры.
func _reflected_light(texture: Texture2D) -> PackedColorArray:
	if texture == null:
		var colors: Array = Content.background(current_bg).get("colors", [])
		var middle := Color(str(colors[1])) if colors.size() > 1 else Color(0.45, 0.45, 0.45)
		return PackedColorArray([middle, middle])
	var path := texture.resource_path
	if _backdrop_colors.has(path):
		return _backdrop_colors[path]
	var image := texture.get_image()
	if image == null or image.is_empty() or (image.is_compressed() and image.decompress() != OK):
		return PackedColorArray([Color(0.45, 0.45, 0.45), Color(0.45, 0.45, 0.45)])
	var sides := PackedColorArray()
	for half in 2:
		var sum := Color(0, 0, 0, 0)
		for row in 6:
			for col in 8:
				var u := 0.5 * half + (col + 0.5) / 16.0
				var v := 0.14 + (row + 0.5) * 0.09
				sum += image.get_pixel(int(u * image.get_width()), int(v * image.get_height()))
		sides.append(sum / 48.0)
	_backdrop_colors[path] = sides
	return sides


## Одна палитра на весь кадр, включая уходящие фигуры и обе позы во время смены эмоции.
func _apply_environment(animate: bool, fade_same_backdrop: bool) -> void:
	lighting_phase = int(Game.state.get("phase", 1))
	Sound.environment("backgrounds", current_bg, Rules.PHASE_KEYS[lighting_phase], shot_lighting, score_override)
	var profile := Content.figure_lighting(current_bg, Rules.PHASE_KEYS[lighting_phase], shot_lighting)
	var backdrop_tint := Art.background_tint(current_bg) * Color.from_string(profile.get("backdrop_tint", ""), Color.WHITE)
	var reflected := _reflected_light(background_art.texture)
	var reflected_tint := backdrop_tint if background_art.texture else Color.WHITE
	var uniforms := {
		"backdrop_left": reflected[0] * reflected_tint,
		"backdrop_right": reflected[1] * reflected_tint,
		"ambient_color": Color.from_string(profile.get("ambient_color", ""), Color.WHITE),
		"ambient_strength": float(profile.get("ambient_strength", 0.0)),
		"brightness": float(profile.get("brightness", 1.0)),
		"light_color": Color.from_string(profile.get("light_color", ""), Color.WHITE),
		"light_strength": float(profile.get("light_strength", 0.0)),
		"light_side": float(profile.get("light_side", 1.0)),
	}
	if lighting_tween:
		lighting_tween.kill()
	if animate:
		lighting_tween = create_tween().set_parallel()
	for key in uniforms:
		if animate:
			lighting_tween.tween_property(figure_material, "shader_parameter/" + key, uniforms[key], BACKGROUND_FADE)
		else:
			figure_material.set_shader_parameter(key, uniforms[key])
	if fade_same_backdrop and animate:
		lighting_tween.tween_property(background_art, "modulate", backdrop_tint, BACKGROUND_FADE)
	else:
		background_art.modulate = backdrop_tint


## Эмоции персонажей в этой сцене. Сохраняются, пока сцена не сменит их,
## и применяются, даже если персонаж ещё не вышел на экран.
var moods := {}
var looks := {}


func _set_mood(pid: String, m: String) -> void:
	moods[pid] = m
	if figures.has(pid):
		figures[pid].set_mood(m)


func _show(pid: String, at: String, m := "") -> void:
	if m != "":
		moods[pid] = m
	if figures.has(pid):
		figures[pid].set_meta("at", at)
		if m != "":
			figures[pid].set_mood(m)
		_place_figure(figures[pid])
		return
	var f := VNFigure.new()
	f.setup(pid, str(moods.get(pid, "")), str(looks.get(pid, "")))
	f.use_parent_material = true
	f.set_meta("at", at)
	figures_layer.add_child(f)
	figures[pid] = f
	_place_figure(f)
	f.modulate.a = 0.0
	var y := f.position.y
	f.position.y += 30
	var tw := create_tween().set_parallel()
	tw.tween_property(f, "modulate:a", 1.0, 0.45)
	tw.tween_property(f, "position:y", y, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _hide(pid: String) -> void:
	if not figures.has(pid):
		return
	var f: VNFigure = figures[pid]
	figures.erase(pid)
	var tw := create_tween()
	tw.tween_property(f, "modulate:a", 0.0, 0.4)
	tw.tween_callback(f.queue_free)


func _speaker_name(id: String) -> String:
	if id == "":
		return ""
	var d := Content.def(id)
	if not d.is_empty():
		return Rules.txt(d.get("title"), Game.state)
	return str(Content.world.get("speakers", {}).get(id, {}).get("title", id))


func _speaker_color(id: String) -> Color:
	var d := Content.def(id)
	if d.has("color"):
		return Color(str(d["color"])).lightened(0.25)
	return Color(str(Content.world.get("speakers", {}).get(id, {}).get("color", "#e6d6a8")))


func _say(who: String, text: String) -> void:
	for id in figures:
		figures[id].speaking = id == who
		figures[id].dim = who != "" and id != who
	name_plate.visible = who != ""
	name_label.text = _speaker_name(who)
	# Метка сохраняет оттенок персонажа, включая глубокие фиолетовые и синие,
	# но светлее тёмной эмали и читается при любой реплике.
	name_label.add_theme_color_override("font_color", _speaker_color(who).lerp(Color("fff0cd"), 0.38))
	name_plate.reset_size()
	if who == "":
		# Повествование прямым шрифтом: кириллический курсив («т» как «m») тяжело читать
		# абзацами. От реплик его отличают тёплый приглушённый тон и отсутствие имени.
		text_label.add_theme_font_override("font", Look.font("serif"))
		text_label.add_theme_color_override("font_color", Color("ddd0b4"))
	else:
		text_label.add_theme_font_override("font", Look.font("serif"))
		text_label.add_theme_color_override("font_color", Color("f6eedc"))
	history.append([_speaker_name(who), text])
	text_label.text = text
	dialog_scroll.scroll_vertical = 0
	waiting = "click"
	_layout()
	_fit_text()
	var speed := float(Game.settings["text_speed"])
	if speed <= 0:
		text_label.visible_characters = -1
		typing = false
	else:
		text_label.visible_characters = 0
		_shown_chars = 0.0
		typing = true


func _process(delta: float) -> void:
	_t += delta
	if not current_bg.is_empty() and int(Game.state.get("phase", 1)) != lighting_phase:
		_apply_environment(true, true)
	if typing:
		_shown_chars += delta * float(Game.settings["text_speed"])
		text_label.visible_characters = int(_shown_chars)
		if _shown_chars >= text_label.text.length():
			typing = false
			text_label.visible_characters = -1
	cont_mark.visible = waiting == "click" and not typing and not ui_hidden
	cont_mark.modulate.a = 0.5 + 0.5 * sin(_t * 4.0)
	# Подсказка только там, где без неё легко потеряться: длинный список ответов.
	input_hint.text = ""
	if waiting == "choice":
		var scroll_bar := choice_scroll.get_v_scroll_bar()
		if scroll_bar.max_value > scroll_bar.page:
			input_hint.text = "КОЛЕСО — ОСТАЛЬНЫЕ ВАРИАНТЫ"
	elif _skipping():
		input_hint.text = "ПРОПУСК ▸▸"
	input_hint.visible = not ui_hidden
	# Пропуск: реплика дописывается сразу, следующая — через короткую паузу. Выбор его останавливает.
	if _skipping() and waiting == "click":
		_skip_t += delta
		if _skip_t >= 0.07:
			_skip_t = 0.0
			typing = false
			text_label.visible_characters = -1
			waiting = ""
			i += 1
			_run()
	else:
		_skip_t = 0.0


func _skipping() -> bool:
	if ui_hidden or (Game.main and Game.main.has_overlay()):
		return false
	return skip_on or Input.is_key_pressed(KEY_CTRL)


func _toggle_skip() -> void:
	skip_on = skip_button.button_pressed
	if skip_on and ui_hidden:
		_toggle_ui()


func _toggle_ui() -> void:
	ui_hidden = not ui_hidden
	for c in [box, name_plate, cont_mark, input_hint, tool_bar, location_plaque, place_label]:
		c.visible = not ui_hidden
	name_plate.visible = not ui_hidden and name_label.text != ""
	choice_scroll.visible = not ui_hidden and waiting == "choice"
	scene_label.visible = false
	if ui_hidden:
		skip_on = false
		skip_button.button_pressed = false


func _more_text_below() -> bool:
	var bar := dialog_scroll.get_v_scroll_bar()
	return bar.value < floorf(bar.max_value - bar.page)


func _advance() -> void:
	if waiting != "click":
		return
	if typing:
		typing = false
		text_label.visible_characters = -1
		return
	if _more_text_below():
		var page := dialog_scroll.get_v_scroll_bar().page
		dialog_scroll.scroll_vertical += maxi(1, floori(page) - text_label.get_line_height())
		return
	waiting = ""
	i += 1
	_run()


func _gui_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed):
		return
	if ui_hidden:
		# пока рамка спрятана, щелчок только возвращает её
		_toggle_ui()
		accept_event()
		return
	match e.button_index:
		MOUSE_BUTTON_LEFT:
			if skip_on:
				skip_on = false
				skip_button.button_pressed = false
			_advance()
			accept_event()
		MOUSE_BUTTON_RIGHT:
			_toggle_ui()
			accept_event()
		MOUSE_BUTTON_WHEEL_UP:
			if dialog_scroll.scroll_vertical == 0:
				_show_history()
				accept_event()


func _unhandled_input(e: InputEvent) -> void:
	if Game.main.has_overlay():
		return
	if e is InputEventKey and e.pressed and not e.echo:
		# Горячие клавиши по физическому положению: работают и в русской раскладке.
		var key: Key = e.physical_keycode
		if ui_hidden:
			_toggle_ui()
			get_viewport().set_input_as_handled()
			return
		if key in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			_advance()
			get_viewport().set_input_as_handled()
		elif key in [KEY_H, KEY_L]:
			_show_history()
			get_viewport().set_input_as_handled()
		elif key == KEY_V:
			_toggle_ui()
			get_viewport().set_input_as_handled()
		elif waiting == "choice" and key >= KEY_1 and key <= KEY_9:
			var idx: int = key - KEY_1
			if idx < choices.get_child_count():
				(choices.get_child(idx) as Button).emit_signal("pressed")


func _show_choice(opts: Array) -> void:
	var s := Game.state
	waiting = "choice"
	if skip_on:
		# пропуск всегда останавливается на выборе
		skip_on = false
		skip_button.button_pressed = false
	choice_scroll.scroll_vertical = 0
	for c in choices.get_children():
		c.queue_free()
	var paper := Look.paper_box(Color("ede1c4"), 9, 12)
	paper.content_margin_left = 63
	paper.content_margin_right = 22
	paper.border_color = Color("aa956d")
	paper.border_width_left = 3
	var paper_h := paper.duplicate() as StyleBoxFlat
	paper_h.bg_color = Color("fff3d3")
	paper_h.border_color = Color("8c754a")
	var paper_focus := paper_h.duplicate() as StyleBoxFlat
	paper_focus.draw_center = false
	paper_focus.shadow_size = 0
	paper_focus.border_color = Color("1e5052")
	paper_focus.set_border_width_all(2)
	var grain := Art.surface("paper")
	var n := 0
	var hub: bool = nodes[i].get("hub", false)
	var hub_i := i
	for o in opts:
		if hub and hub_taken.has("%d:%s" % [hub_i, o.get("goto", "")]):
			continue
		if not Rules.test(o.get("when"), s, ctx):
			continue
		# Вариант с подходом Флёра: виден, только если карта подхода есть; пока она отдыхает — недоступен.
		var ap := str(o.get("ap", ""))
		if ap != "" and not s["cards"].has(ap):
			continue
		n += 1
		var b := Button.new()
		b.text = Rules.txt(o.get("t"), s, ctx)
		var rel_marks := _rel_marks(o.get("when"))
		if rel_marks.size() > 0:
			# вариант открыт благодаря отношениям: игрок видит, что прошлое сработало
			b.text = "◆ %s  %s" % [", ".join(rel_marks), b.text]
			b.tooltip_text = "Этот вариант есть, потому что между ними уже сложилось: " + ", ".join(rel_marks).to_lower() + "."
		if ap != "":
			b.text = "[%s]  %s" % [Rules.title_of(ap, s), b.text]
			if Rules.is_resting(s, ap):
				b.disabled = true
				b.text += "   — сейчас не получится"
				b.tooltip_text = "%s ещё не восстановилось. Карта снова будет готова через некоторое время." % Rules.title_of(ap, s)
		b.accessibility_name = "%d. %s" % [n, b.text]
		b.draw.connect(Decor.choice_badge.bind(b, n, grain))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_stylebox_override("normal", paper)
		b.add_theme_stylebox_override("hover", paper_h)
		b.add_theme_stylebox_override("pressed", paper_h)
		b.add_theme_stylebox_override("focus", paper_focus)
		b.add_theme_color_override("font_color", Look.INK)
		b.add_theme_color_override("font_hover_color", Color("6a2416"))
		b.add_theme_color_override("font_pressed_color", Color("6a2416"))
		b.add_theme_color_override("font_focus_color", Look.INK)
		b.add_theme_font_size_override("font_size", 20)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var opt: Dictionary = o
		var label_text := Rules.txt(o.get("t"), s, ctx)
		var btn := b
		b.pressed.connect(func():
			if btn.disabled:
				return
			for c in choices.get_children():
				c.queue_free()
			waiting = ""
			_layout()
			history.append(["→", label_text])
			if hub:
				hub_taken["%d:%s" % [hub_i, opt.get("goto", "")]] = true
			if str(opt.get("ap", "")) != "":
				Rules.spend_approach(Game.state, str(opt["ap"]), api)
			Rules.apply(opt.get("effects"), Game.state, ctx, api)
			i = labels[opt["goto"]] if opt.has("goto") else i + 1
			_run())
		choices.add_child(b)
		b.modulate.a = 0
		create_tween().tween_property(b, "modulate:a", 1.0, 0.25).set_delay(0.08 * n)
	_layout.call_deferred()


func _show_history() -> void:
	Sound.play("ui_page")
	var sh := Sheet.new(720)
	sh.add_kicker("Сцена")
	sh.add_title("Что было сказано")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 480)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	scroll.add_child(col)
	for e in history:
		var l := Label.new()
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 640
		l.theme_type_variation = "Ink" if e[0] != "" else "InkSoft"
		l.add_theme_font_size_override("font_size", 17)
		l.text = (str(e[0]) + ": " if e[0] != "" else "") + str(e[1])
		col.add_child(l)
	sh.body.add_child(scroll)
	sh.add_row([Sheet.make_button("Закрыть", sh.close)])
	Game.main.open_overlay(sh)


func _finish() -> void:
	if _finished:
		return
	_finished = true
	Game.finish_scene(api["changes"], str(scene.get("after", "")), history)


## Отношения, от которых зависит вариант: «Шарлотта: доверие». Ищутся rel и relAny на любой глубине условия.
func _rel_marks(cond) -> PackedStringArray:
	var out := PackedStringArray()
	if cond is Array:
		for c in cond:
			out.append_array(_rel_marks(c))
	elif cond is Dictionary:
		for k in cond:
			var v = cond[k]
			if k == "rel" and v is Array and v.size() > 1:
				out.append("%s: %s" % [Rules.title_of(str(v[0]), Game.state), str(v[1]).to_lower()])
			elif k == "relAny" and v is Array and v.size() > 1:
				var have: Array = Game.state["rel"].get(str(v[0]), [])
				for tag in (v[1] if v[1] is Array else [v[1]]):
					if have.has(tag):
						out.append("%s: %s" % [Rules.title_of(str(v[0]), Game.state), str(tag).to_lower()])
						break
			elif k == "all":
				out.append_array(_rel_marks(v))
			elif k == "any":
				for sub in v:
					if Rules.test(sub, Game.state, ctx):
						out.append_array(_rel_marks(sub))
						break
	return out


## Есть ли в выборе хотя бы один видимый вариант (для хаба — ещё не выбранный).
func _has_options(opts: Array, hub: bool) -> bool:
	var s := Game.state
	for o in opts:
		if hub and hub_taken.has("%d:%s" % [i, o.get("goto", "")]):
			continue
		if not Rules.test(o.get("when"), s, ctx):
			continue
		var ap := str(o.get("ap", ""))
		if ap != "" and not s["cards"].has(ap):
			continue
		return true
	return false
