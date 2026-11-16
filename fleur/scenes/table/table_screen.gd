extends Control
## Основной режим — письменный стол Флёра.
## Вещи лежат там, куда их положил игрок. Место выбирается на карте города, время — на часах.
## Дела выбираются на открытке места или на самой карте; нужные карты кладутся в ячейки листа.

const PHASE_TINT := [Color(1.0, 0.94, 0.86), Color(1.0, 1.0, 0.98), Color(0.96, 0.8, 0.64), Color(0.58, 0.62, 0.8)]
const PHASE_LAMP := [0.0, 0.0, 0.55, 1.0]

var bg: ColorRect
var wood: ShaderMaterial
var lamp_rect: ColorRect
var lamp_mat: ShaderMaterial
var modulate_node: CanvasModulate
var map: CityMap
var dial: TimeDial
var spread: PlaceSpread
var cards_layer: Control
var sheet_layer: Control
var note_layer: Control
var hint_label: Label
var notebook: DeskProp
var plaque: Button
var inkwell: DeskProp
var trinkets: Array[DeskTrinket] = []
var quip_layer: Control
var blotter: Control

## Большой стол: всё физическое (карта города, открытка места, вещи) лежит в world,
## которое двигает камера. Часы, записная книжка, меню и листы остаются на экране.
const WORLD := Vector2(2400, 1400)
const ZOOM_MIN := 0.55
const ZOOM_MAX := 1.35
## Зоны стола: куда ложатся новые вещи и как раскладывает «Прибрать».
const ZONES := {
	"person": Rect2(40, 560, 1240, 600),
	"approach": Rect2(40, 1190, 860, 190),
	"rumor": Rect2(1330, 560, 1030, 520), "info": Rect2(1330, 560, 1030, 520), "clue": Rect2(1330, 560, 1030, 520),
	"item": Rect2(930, 1190, 980, 190),
	"invitation": Rect2(1940, 1100, 420, 280), "event": Rect2(1940, 1100, 420, 280),
	"affair": Rect2(1400, 40, 600, 330), "storyline": Rect2(1400, 40, 600, 330),
	"deadline": Rect2(1720, 400, 300, 160),
	"state": Rect2(2050, 420, 300, 140),
	"world": Rect2(1330, 400, 380, 160),
}
## Безделушки на деревянных краях стола, вне зон для карт (координаты стола).
const TRINKETS := {
	"mirror": Vector2(494, 312),
	"bell": Vector2(642, 312),
	"letters": Vector2(762, 310),
	"swan": Vector2(1168, 264),
	"hat": Vector2(2040, 196),
	"glass": Vector2(2220, 272),
}
const ZONE_ORDER := ["affair", "storyline", "deadline", "state", "world", "person", "rumor", "info", "clue", "invitation", "event", "item", "approach"]

var world: Control
var backdrop: ColorRect
## Наклон стола: плоский стол рисуется в plane и кладётся на экран в перспективе.
## Вид сверху под углом около 22° к вертикали. Сжатие бумаги по глубине
## не зависит от того, насколько увеличиваются предметы у ближнего края.
const DEPTH_RATIO := 0.93
const FAR_SCALE := 0.975
const NEAR_SCALE := 1.025
var plane: SubViewport
var plane_view: ColorRect
var plane_mat: ShaderMaterial
var desk_input: Control              # пустое место стола внутри plane: тянет вид
var plane_size := Vector2(1600, 900)
var _h := PackedFloat32Array()       # экран → плоский стол
var _hi := PackedFloat32Array()      # плоский стол → экран
var _plane_hover := false
var tidy_btn: Button
var cam_pos := Vector2(720, 405)     # точка стола в центре экрана
var cam_zoom := 1.0
var cam_target := Vector2(720, 405)
var zoom_target := 1.0
var _shake := 0.0
var _panning := false
var _pan_moved := false
var _pan_from := Vector2.ZERO
var _user_cam_time := -10.0          # когда игрок сам двигал камеру (режиссура ему не мешает)
var _clock := 0.0
var _cam_vel := Vector2.ZERO        # скорость камеры (плавное затухание, без рывков)
var _zoom_vel := 0.0
var _smooth := 0.2                  # время сглаживания: короткое для игрока, длинное для режиссуры
var _anchor_screen := Vector2.ZERO  # масштаб «к курсору»: эта точка стола держится под курсором
var _anchor_world := Vector2.ZERO
var _anchored := false
var _drag_vel := Vector2.ZERO       # для инерции после перетаскивания
var _arrived: Array = []             # карты, прилетевшие за последнюю синхронизацию

var card_index: CardIndex
const INDEX_POS := Vector2(1182, 44)
## Что нельзя убрать в картотеку: дела, сроки и печати подходов всегда на виду.
const KEEP_ON_DESK := ["affair", "deadline", "approach"]


## Картотека: деревянный ящик на краю стола. Карту можно бросить в него, чтобы она не мешала;
## щелчок по ящику — список убранного. Нужная для дела карта возвращается сама.
class CardIndex extends Control:
	signal opened
	var count := 0

	func _init() -> void:
		size = Vector2(196, 150)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tooltip_text = "Картотека. Бросьте сюда карту, которая сейчас не нужна; щелчок — что уже убрано."

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			opened.emit()
			accept_event()

	func _draw() -> void:
		var body := Rect2(8, 34, size.x - 16, size.y - 44)
		var pts := Look.rrect(body, 6)
		Look.soft_shadow(self, pts, Vector2(3, 7), 8, 0.6)
		Look.thickness(self, pts, 5.0, Color("5a3a20"), Color("2a180c"))
		Look.fill_v(self, pts, Color("7a5232"), Color("4a2e18"))
		Look.outline(self, pts, Color("2a180c"), 2.0)
		# карточки торчат из ящика: чем больше убрано, тем выше стопка
		var shown := mini(count, 7)
		for i in shown:
			var r := Rect2(22 + i * 3, 30 - i * 2.6, size.x - 44 - i * 6, 26)
			draw_rect(r, Color("efe5cf").darkened(0.04 * (shown - i)))
			draw_rect(r, Color("8a7a5a"), false, 1.0)
		var front := Rect2(8, 58, size.x - 16, size.y - 68)
		Look.fill_v(self, Look.rrect(front, 5), Color("6a4428"), Color("3e2614"))
		Look.outline(self, Look.rrect(front, 5), Color("2a180c"), 1.5)
		var plate := Rect2(size.x / 2 - 62, 74, 124, 30)
		Look.fill_v(self, Look.rrect(plate, 4), Color("d8b866"), Color("8e6a2a"))
		Look.outline(self, Look.rrect(plate, 4), Color("4a3410"), 1.0)
		Look.text_c(self, Look.font("serif_bold"), size.x / 2, 95, "Картотека", 15, Color("2a1c0a"))
		Look.text_c(self, Look.font("hand"), size.x / 2, 128, ("убрано: %d" % count) if count > 0 else "пусто", 15, Color(0.95, 0.88, 0.7, 0.85))


var nodes: Dictionary = {}      # id -> TableCard
var sheet: ActionSheet = null
var note: Control = null
var note_card := ""
var _hidden_until_shown: Array = []
var _reading := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	modulate_node = CanvasModulate.new()
	add_child(modulate_node)

	plane = SubViewport.new()
	plane.disable_3d = true
	plane.gui_embed_subwindows = true
	plane.size_2d_override_stretch = true
	plane.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	plane.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(plane)
	desk_input = Control.new()
	desk_input.mouse_filter = Control.MOUSE_FILTER_STOP
	desk_input.theme = Look.theme()      # тема окна сквозь SubViewport не наследуется
	desk_input.gui_input.connect(_desk_gui_input)
	plane.add_child(desk_input)
	plane_view = ColorRect.new()
	plane_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	plane_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plane_mat = ShaderMaterial.new()
	plane_mat.shader = load("res://shaders/desk_tilt.gdshader")
	plane_mat.set_shader_parameter("plane_tex", plane.get_texture())
	plane_view.material = plane_mat
	add_child(plane_view)

	backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.color = Color("1c120b")
	desk_input.add_child(backdrop)
	world = Control.new()
	world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.size = WORLD
	desk_input.add_child(world)

	bg = ColorRect.new()
	bg.position = Vector2(-700, -500)
	bg.size = WORLD + Vector2(1400, 1000)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wood = ShaderMaterial.new()
	wood.shader = load("res://shaders/wood.gdshader")
	var walnut := Art.surface("walnut")
	if walnut:
		wood.set_shader_parameter("walnut", walnut)
		wood.set_shader_parameter("has_material", true)
	bg.material = wood
	world.add_child(bg)
	blotter = Control.new()
	blotter.size = WORLD
	blotter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blotter.draw.connect(_draw_blotter)
	world.add_child(blotter)

	inkwell = DeskProp.new("inkwell")
	world.add_child(inkwell)
	# безделушки лежат под слоем карт: карта сверху всегда главнее
	for k in TRINKETS:
		var trinket := DeskTrinket.new(k)
		world.add_child(trinket)
		trinkets.append(trinket)

	hint_label = Label.new()
	hint_label.add_theme_font_override("font", Look.font("hand"))
	hint_label.add_theme_font_size_override("font_size", 15)
	hint_label.add_theme_color_override("font_color", Color(0.93, 0.85, 0.7, 0.55))
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.clip_text = true
	hint_label.text = "Колесо — ближе и дальше, пустое место стола — сдвинуть вид, Home — вернуть. Булавка — отправиться туда; золотая точка — сюжетное намерение. Карту можно бросить на булавку, портрет, папку дела или в картотеку."

	map = CityMap.new()
	map.pin_clicked.connect(_travel)
	world.add_child(map)

	spread = PlaceSpread.new()
	spread.action_chosen.connect(func(a):
		_choose_action(a, str(Game.state["here"])))
	spread.person_clicked.connect(func(pid):
		if not nodes.has(pid) and Game.state.get("archived", {}).has(pid):
			_unarchive([pid])
		if nodes.has(pid):
			_toggle_note(nodes[pid]))
	world.add_child(spread)

	dial = TimeDial.new()
	dial.wait_requested.connect(_on_wait)
	add_child(dial)

	notebook = DeskProp.new("notebook")
	notebook.activated.connect(Dialogs.journal)
	add_child(notebook)
	plaque = _brass_button("Меню", Vector2(120, 44))
	plaque.tooltip_text = "Меню, сохранение, настройки (Esc)"
	plaque.pressed.connect(Dialogs.pause)
	add_child(plaque)

	card_index = CardIndex.new()
	card_index.opened.connect(_open_card_index)
	world.add_child(card_index)

	cards_layer = Control.new()
	cards_layer.size = WORLD
	cards_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.add_child(cards_layer)
	quip_layer = Control.new()
	quip_layer.size = WORLD
	quip_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.add_child(quip_layer)
	for trinket in trinkets:
		trinket.quip_layer = quip_layer
	add_child(hint_label)

	tidy_btn = _brass_button("Прибрать стол", Vector2(164, 44))
	tidy_btn.tooltip_text = "Разложить вещи по местам: люди к людям, слухи и улики к уликам."
	tidy_btn.pressed.connect(_tidy)
	add_child(tidy_btn)

	lamp_rect = ColorRect.new()
	lamp_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	lamp_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lamp_mat = ShaderMaterial.new()
	lamp_mat.shader = load("res://shaders/lamp.gdshader")
	lamp_rect.material = lamp_mat
	add_child(lamp_rect)

	sheet_layer = Control.new()
	sheet_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	sheet_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sheet_layer)
	note_layer = Control.new()
	note_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	note_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(note_layer)

	resized.connect(_layout_fixed)
	get_viewport().size_changed.connect(_layout_fixed)
	_layout_fixed()
	_home_camera(true)
	if Game.pending_return.size() > 0:
		# возвращение из сцены: общий план, потом камера подъезжает к столу
		cam_zoom = zoom_target * 0.82
		_smooth = 0.7
		_apply_camera()

	# Карты, пришедшие из сцены/активности, появятся с анимацией после затемнения
	for c in Game.pending_return.get("changes", []):
		if c["kind"] == "gain":
			_hidden_until_shown.append(c["id"])
	sync_cards(false)
	_apply_light(true)


func _brass_button(caption: String, footprint: Vector2) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = footprint
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", Look.font("serif_bold"))
	button.add_theme_font_size_override("font_size", 16)
	var plate := Art.prop("desk_plaque")
	if plate:
		var brass := StyleBoxTexture.new()
		brass.texture = plate
		brass.texture_margin_left = 23
		brass.texture_margin_right = 23
		brass.texture_margin_top = 9
		brass.texture_margin_bottom = 9
		var hover := brass.duplicate() as StyleBoxTexture
		hover.modulate_color = Color(1.12, 1.10, 1.04)
		var pressed := brass.duplicate() as StyleBoxTexture
		pressed.modulate_color = Color(0.86, 0.85, 0.80)
		button.add_theme_stylebox_override("normal", brass)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", pressed)
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(key, Color("302110"))
	return button


func on_shown() -> void:
	sync_cards(true)
	if not Game.state["flags"].get("_desk_intro", false):
		# Первый взгляд на стол: карта города, открытка места, люди и письмо — всё в кадре.
		Game.state["flags"]["_desk_intro"] = true
		focus_rect(Rect2(0, 0, WORLD.x, 1250), 1.0, true)
		_user_cam_time = _clock
	if not Game.pending_return.is_empty():
		var pr := Game.pending_return
		Game.pending_return = {}
		_read(pr.get("title", ""), pr.get("text", ""), pr.get("changes", []), "result", flow)
	else:
		flow()


func on_escape() -> void:
	if note:
		_close_note()
	elif sheet:
		_close_sheet()
	else:
		Dialogs.pause()


# ---------------------------------------------------------------- раскладка

func table_size() -> Vector2:
	return size if size.x > 10 and size.y > 10 else get_viewport_rect().size


func world_size() -> Vector2:
	return WORLD


func _layout_fixed() -> void:
	var ts := table_size()
	_update_plane()
	wood.set_shader_parameter("size", bg.size)
	lamp_mat.set_shader_parameter("size", ts)
	# на столе (в мире)
	map.position = Vector2(30, 30)
	spread.position = Vector2(500, 34)
	inkwell.position = Vector2(973, 308)
	for trinket in trinkets:
		trinket.position = TRINKETS[trinket.kind]
	# на экране
	dial.position = Vector2(ts.x - 310, 28)
	notebook.position = Vector2(ts.x - 170, ts.y - 180)
	plaque.position = Vector2(34, ts.y - 72)
	tidy_btn.position = Vector2(166, ts.y - 72)
	card_index.position = INDEX_POS
	# подсказка живёт между латунными табличками и записной книжкой и не уходит за край
	hint_label.position = Vector2(440, ts.y - 66)
	hint_label.size = Vector2(maxf(200.0, ts.x - 440 - 200), 56)
	_update_hint()
	blotter.queue_redraw()
	_clamp_camera()
	_apply_camera()


## Подсказка нужна в первые дни; потом и когда открыт лист она только мешает.
func _update_hint() -> void:
	if hint_label == null:
		return
	hint_label.visible = bool(Game.settings["hints"]) and int(Game.state.get("day", 1)) <= 3 and sheet == null


func _draw_blotter() -> void:
	var r := Rect2(20, 400, WORLD.x - 40, WORLD.y - 420)
	var edge := Look.rrect(r, 17)
	Look.soft_shadow(blotter, edge, Vector2(3, 8), 10, 0.7)
	# кожаная подложка лежит на столе толстым листом
	Look.thickness(blotter, edge, 6.0, Color("1d3533"), Color("0a1414"))
	Look.fill_v(blotter, edge, Color("273d3b"), Color("182928"))
	Look.texture_polygon(blotter, edge, Art.surface("blotter_leather"), 1.0, Color(0.84, 0.89, 0.90, 0.56))
	Look.fill_v(blotter, edge, Color(0.03, 0.10, 0.09, 0.02), Color(0.01, 0.04, 0.04, 0.24))
	Look.outline(blotter, edge, Color("0c1b1c"), 3.0)
	Look.outline(blotter, Look.rrect(r.grow(-9), 11), Color(0.67, 0.55, 0.32, 0.45), 1.0)
	Look.outline(blotter, Look.rrect(r.grow(-13), 9), Color(0.67, 0.55, 0.32, 0.18), 1.0)
	# Шов проходит внутри края, без крупного контраста под карточками.
	var seam := r.grow(-17)
	var thread := Color(0.61, 0.58, 0.39, 0.28)
	for x in range(int(seam.position.x + 14), int(seam.end.x - 14), 7):
		for y in [seam.position.y, seam.end.y]:
			blotter.draw_line(Vector2(x, y), Vector2(x + 3, y), thread, 1.0)
	for y in range(int(seam.position.y + 14), int(seam.end.y - 14), 7):
		for x in [seam.position.x, seam.end.x]:
			blotter.draw_line(Vector2(x, y), Vector2(x, y + 3), thread, 1.0)
	# Тиснение по углам подложки.
	for p in [r.position + Vector2(24, 24), Vector2(r.end.x - 24, r.position.y + 24), r.end - Vector2(24, 24), Vector2(r.position.x + 24, r.end.y - 24)]:
		var mark := PackedVector2Array([p + Vector2(0, -6), p + Vector2(4, 0), p + Vector2(0, 6), p + Vector2(-4, 0)])
		Look.outline(blotter, mark, Color(0.75, 0.61, 0.34, 0.35), 1.0)


func _reserved() -> Array:
	return [
		Rect2(map.position, map.size).grow(6),
		Rect2(spread.position, spread.size).grow(8),
		Rect2(inkwell.position, inkwell.size),
		Rect2(INDEX_POS, card_index.size).grow(6),
	] + trinkets.map(func(tr): return Rect2(tr.position, tr.size * tr.scale))


func _zone_for(d: Dictionary) -> Rect2:
	return ZONES.get(str(d.get("type", "")), Rect2(900, 600, 600, 500))


func _occupied(ignore_id := "") -> Array:
	var out := []
	for id in nodes:
		if id == ignore_id:
			continue
		var n: TableCard = nodes[id]
		var lay = Game.state["layout"].get(id)
		var p0 := n.position if lay == null else Vector2(float(lay[0]), float(lay[1]))
		out.append(Rect2(p0, n.size).grow(-6))
	return out


## Первое свободное место в зоне, рядами слева направо; если зона заполнена — поблизости.
func _grid_spot(card_size: Vector2, zone: Rect2, occupied: Array) -> Vector2:
	var reserved := _reserved()
	var step := card_size + Vector2(12, 14)
	var bounds := Rect2(Vector2(16, 16), WORLD - Vector2(32, 32) - card_size)
	var cols := maxi(1, int((zone.size.x - card_size.x) / step.x) + 1)
	var rows := maxi(1, int((zone.size.y - card_size.y) / step.y) + 1)
	var tries := []
	for r in rows + 6:
		for c in cols:
			tries.append(zone.position + Vector2(c * step.x, r * step.y))
	for k in range(1, 6):
		for r in rows:
			tries.append(zone.position + Vector2(cols * step.x + (k - 1) * step.x, r * step.y))
	for p in tries:
		p = p.clamp(bounds.position, bounds.end)
		var rect := Rect2(p, card_size)
		var ok := true
		for rr in reserved:
			if rr.intersects(rect):
				ok = false
				break
		if ok:
			for oc in occupied:
				if oc.intersects(rect):
					ok = false
					break
		if ok:
			return p
	# Зона переполнена: ищем любое свободное место на подложке, начиная с ближайших к зоне.
	var leather := Rect2(40, 420, WORLD.x - 80, WORLD.y - 440)
	var spots := []
	var y := leather.position.y
	while y + card_size.y <= leather.end.y:
		var x := leather.position.x
		while x + card_size.x <= leather.end.x:
			spots.append(Vector2(x, y))
			x += step.x
		y += step.y
	var zc := zone.get_center()
	spots.sort_custom(func(a, b): return a.distance_squared_to(zc) < b.distance_squared_to(zc))
	for p in spots:
		var rect := Rect2(p, card_size)
		var ok := true
		for rr in reserved:
			if rr.intersects(rect):
				ok = false
				break
		if ok:
			for oc in occupied:
				if oc.intersects(rect):
					ok = false
					break
		if ok:
			return p
	# Стол заставлен целиком.
	return NO_ROOM


const NO_ROOM := Vector2(-99999, -99999)


## Стол заставлен: самая старая карта, без которой можно обойтись, уходит в картотеку.
## Сначала уже подшитые улики и прочитанные слухи, потом сведения и предметы, потом люди, которых нет рядом.
func _auto_archive(keep_id: String) -> String:
	var s := Game.state
	var order := ["rumor", "world", "info", "clue", "item", "invitation", "person"]
	for kind in order:
		for id in s["cards"]:
			if id == keep_id or not nodes.has(id) or s.get("archived", {}).has(id):
				continue
			var d := Content.def(id)
			if str(d.get("type", "")) != kind or s["cards"][id].get("fresh", false):
				continue
			if kind == "person" and Rules.where_is(s, id) == s["here"]:
				continue
			if sheet and Rules.slot_candidates({"types": [kind]}, s, sheet.ctx()).has(id):
				continue
			_archive(id)
			return id
	return ""


## Свободное место для новой карты; если стола не хватает — освободить, убрав старое в картотеку.
func _place_new(card_size: Vector2, zone: Rect2, id: String) -> Vector2:
	var p := _free_spot(card_size, zone, id)
	var moved := []
	while p == NO_ROOM and moved.size() < 4:
		var gone := _auto_archive(id)
		if gone == "":
			break
		moved.append(Rules.title_of(gone, Game.state))
		p = _free_spot(card_size, zone, id)
	if moved.size() > 0:
		_toast("Стол заставлен. В картотеку: " + ", ".join(PackedStringArray(moved)))
	if p == NO_ROOM:
		var k := nodes.size() % 12
		p = zone.position + Vector2(k * 34, k * 26)
	return p


func _free_spot(card_size: Vector2, zone: Rect2, ignore_id := "") -> Vector2:
	return _grid_spot(card_size, zone, _occupied(ignore_id))


## «Прибрать стол»: всё по своим зонам, ровными рядами.
func _tidy() -> void:
	if _reading:
		return
	_close_note()
	_close_sheet()
	var ids := []
	for id in nodes:
		if nodes[id].get_parent() == cards_layer:
			ids.append(id)
	ids.sort_custom(func(a, b):
		var ta := ZONE_ORDER.find(str(nodes[a].d.get("type", "")))
		var tb := ZONE_ORDER.find(str(nodes[b].d.get("type", "")))
		if ta != tb:
			return ta < tb
		return Rules.title_of(a, Game.state) < Rules.title_of(b, Game.state))
	var occupied := []
	var tw := create_tween().set_parallel()
	var i := 0
	for id in ids:
		var card: TableCard = nodes[id]
		var target := _grid_spot(card.size, _zone_for(card.d), occupied)
		if target == NO_ROOM:
			target = _zone_for(card.d).position + Vector2((i % 12) * 34, (i % 12) * 26)
		occupied.append(Rect2(target, card.size).grow(-6))
		card.rest_rot = randf_range(-0.02, 0.02)
		_save_layout_at(card, target)
		tw.tween_property(card, "position", target, 0.55).set_delay(i * 0.012).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		i += 1
	focus_rect(Rect2(Vector2.ZERO, WORLD), 0.9)


## Убрать карту в картотеку.
func _archive(id: String) -> void:
	var s := Game.state
	if not s["cards"].has(id):
		return
	s["cards"][id]["fresh"] = false
	s["archived"][id] = true
	Sound.play("ui_paper", -2.0)
	if note_card == id:
		_close_note()
	if nodes.has(id):
		var card: TableCard = nodes[id]
		nodes.erase(id)
		s["layout"].erase(id)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tw := create_tween().set_parallel()
		tw.tween_property(card, "position", INDEX_POS + Vector2(40, 10), 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(card, "base_scale", 0.3, 0.35)
		tw.tween_property(card, "modulate:a", 0.0, 0.35)
		tw.chain().tween_callback(card.queue_free)
	card_index.count = s["archived"].size()
	card_index.queue_redraw()


## Вернуть карты из картотеки на стол.
func _unarchive(ids: Array) -> void:
	var s := Game.state
	var any := false
	for id in ids:
		if s["archived"].has(id):
			s["archived"].erase(id)
			s["layout"].erase(id)
			any = true
	if any:
		sync_cards(true)


func _open_card_index() -> void:
	if _reading:
		return
	_close_note()
	var s := Game.state
	var sh := Sheet.new(560)
	sh.add_kicker("Стол Флёра")
	sh.add_title("Картотека")
	var ids: Array = s["archived"].keys().filter(func(id): return s["cards"].has(id))
	if ids.is_empty():
		sh.add_text("Пусто. Сюда можно бросить карту, которая сейчас не нужна: человека, с которым давно не виделись, или прочитанный слух. Если карта понадобится для дела, она вернётся на стол сама.")
	else:
		ids.sort_custom(func(a, b): return Rules.title_of(a, s) < Rules.title_of(b, s))
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(0, mini(420, 44 * ids.size()))
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(col)
		for id in ids:
			var b := Button.new()
			b.theme_type_variation = "InkButton"
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.text = "→ " + Rules.title_of(id, s) + "  — вернуть на стол"
			var cid: String = id
			b.pressed.connect(func():
				sh.close()
				_unarchive([cid]))
			col.add_child(b)
		sh.body.add_child(scroll)
		sh.add_row([Sheet.make_button("Вернуть всё", func():
			sh.close()
			_unarchive(ids))])
	sh.add_row([Sheet.make_button("Закрыть", sh.close)])
	Sound.play("ui_folder")
	Game.main.open_overlay(sh)


func _save_layout(card: TableCard) -> void:
	Game.state["layout"][card.id] = [card.position.x, card.position.y, card.rest_rot]


# ---------------------------------------------------------------- синхронизация со состоянием

func sync_cards(animate: bool) -> void:
	var s := Game.state
	if not s.has("archived"):
		s["archived"] = {}
	var archived: Dictionary = s["archived"]
	var want := {}
	for id in s["cards"]:
		if Rules.is_location(id):
			continue
		if archived.has(id):
			# в картотеке: на столе её нет, пока не понадобится
			if s["cards"][id].get("fresh", false):
				archived.erase(id)
			else:
				continue
		if not animate and _hidden_until_shown.has(id):
			continue
		want[id] = true
	for id in nodes.keys():
		if not s["cards"].has(id) or archived.has(id):
			_remove_node(id, animate)
	card_index.count = archived.size()
	card_index.queue_redraw()
	_arrived.clear()
	for id in want:
		if archived.has(id):
			continue  # могла уйти в картотеку, пока раскладывали соседей
		if not nodes.has(id):
			_add_node(id, animate)
			if animate:
				_arrived.append(id)
		else:
			nodes[id].queue_redraw()
	if animate:
		_hidden_until_shown.clear()
		_show_arrivals()
	map.queue_redraw()
	spread.refresh()
	if sheet:
		sheet.refresh()


func _add_node(id: String, animate: bool) -> void:
	var card := TableCard.new()
	card.setup(id)
	card.picked.connect(_on_picked)
	card.dropped.connect(_on_dropped)
	card.clicked.connect(_on_clicked)
	cards_layer.add_child(card)
	nodes[id] = card
	var lay = Game.state["layout"].get(id)
	var target: Vector2
	if lay != null:
		target = Vector2(float(lay[0]), float(lay[1]))
		card.rest_rot = float(lay[2])
	else:
		target = _place_new(card.size, _zone_for(card.d), id)
		card.rest_rot = randf_range(-0.07, 0.07)
		_save_layout_at(card, target)
	card.rotation = card.rest_rot
	if animate:
		# прилетает из-за нижнего края экрана, где бы ни стояла камера
		card.position = Vector2(target.x, screen_to_world(Vector2(0, table_size().y + 80)).y)
		card.rotation = card.rest_rot + randf_range(-0.5, 0.5)
		card.lift = 1.0
		var tw := create_tween()
		tw.tween_interval(randf_range(0.0, 0.25))
		tw.tween_property(card, "position", target, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		card.position = target


## Режиссура: если новые вещи легли за краем кадра, камера едет к ним.
func _show_arrivals() -> void:
	if _arrived.is_empty():
		return
	var r := Rect2()
	var first := true
	for id in _arrived:
		var lay = Game.state["layout"].get(id)
		if lay == null or not nodes.has(id):
			continue
		var cr := Rect2(Vector2(float(lay[0]), float(lay[1])), nodes[id].size)
		r = cr if first else r.merge(cr)
		first = false
	if first:
		return
	if not _visible_rect().grow(-30).encloses(r):
		focus_rect(r.merge(Rect2(r.get_center() - Vector2(500, 300), Vector2(1000, 600))))


func _save_layout_at(card: TableCard, p: Vector2) -> void:
	Game.state["layout"][card.id] = [p.x, p.y, card.rest_rot]


func _remove_node(id: String, animate: bool) -> void:
	var card: TableCard = nodes[id]
	nodes.erase(id)
	Game.state["layout"].erase(id)
	if note_card == id:
		_close_note()
	if sheet:
		var sb = sheet.slot_of(card)
		if sb:
			sb.card = null
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if animate:
		var tw := create_tween().set_parallel()
		tw.tween_property(card, "modulate:a", 0.0, 0.6)
		tw.tween_property(card, "position:y", card.position.y - 30, 0.6)
		tw.chain().tween_callback(card.queue_free)
	else:
		card.queue_free()


# ---------------------------------------------------------------- свет и время

func _apply_light(instant := false) -> void:
	var ph := int(Game.state["phase"])
	Sound.environment("locations", Game.state["here"], Rules.PHASE_KEYS[ph])
	if instant:
		modulate_node.color = PHASE_TINT[ph]
		lamp_mat.set_shader_parameter("lamp", PHASE_LAMP[ph])
		return
	var tw := create_tween().set_parallel()
	tw.tween_property(modulate_node, "color", PHASE_TINT[ph], 1.2)
	tw.tween_method(func(v): lamp_mat.set_shader_parameter("lamp", v), float(lamp_mat.get_shader_parameter("lamp")), PHASE_LAMP[ph], 1.2)


func _on_wait() -> void:
	if _reading:
		return
	Sound.play("ui_dial")
	_close_note()
	_close_sheet()
	var res := Game.wait_phase()
	_after(res)


# ---------------------------------------------------------------- ввод с карт

func _gui_input(e: InputEvent) -> void:
	# стол виден в перспективе: событие пересчитывается в точку плоского стола
	if e is InputEventMouse:
		var ev := e.duplicate() as InputEventMouse
		var pp := screen_to_plane(e.position)
		ev.position = pp
		ev.global_position = pp
		if ev is InputEventMouseMotion:
			ev.relative = _plane_delta(e.position, e.relative)
			_plane_hover = true
		plane.push_input(ev, true)
		var hc := plane.gui_get_hovered_control()
		mouse_default_cursor_shape = hc.mouse_default_cursor_shape if hc and hc != desk_input else Control.CURSOR_ARROW


## Нажатие на пустое место стола (или безделушку) внутри plane: сдвинуть вид.
func _desk_gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_panning = true
			_pan_moved = false
			_pan_from = e.position
		else:
			if _panning and not _pan_moved:
				_close_note()
			if _panning:
				_end_pan()
			_panning = false
	elif e is InputEventMouseMotion and _panning and (e.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_pan_by(e.relative)


func _on_picked(card: TableCard) -> void:
	Sound.play("ui_drag")
	_close_note()
	if card.get_parent() == cards_layer:
		cards_layer.move_child(card, -1)


func _on_dropped(card: TableCard) -> void:
	Sound.play("ui_card", -3.0)
	var gp := get_global_mouse_position()
	if card.get_viewport() == plane:
		# карта ехала за мышью по плоскому столу: точка броска — оттуда же
		gp = plane_to_screen(card.get_global_mouse_position())
	# в ячейку открытого дела
	if sheet:
		var sb := sheet.slot_under(gp, card.id)
		if sb:
			_put_in_slot(card, sb)
			return
		var old = sheet.slot_of(card)
		if old:
			old.card = null
			_card_to_desk(card)
			card.base_scale = 1.0
			sheet.refresh()
	gp = screen_to_plane(gp)
	# в картотеку — убрать со стола
	if card_index.get_global_rect().grow(10).has_point(gp):
		if KEEP_ON_DESK.has(str(card.d.get("type", ""))):
			_return_card(card)
			_toast("Это лучше держать на виду.")
		else:
			_archive(card.id)
		return
	# на папку дела — подшить улику
	var case_id := _case_under(gp, card)
	if case_id != "":
		_return_card(card)
		_file_into(case_id, card.id)
		return
	# на портрет человека — разговор на эту тему
	var person := _person_under(gp, card)
	if person != "":
		_return_card(card)
		_talk_with(person, card.id)
		return
	# на булавку карты города
	var loc := map.pin_at_global(gp)
	if loc != "":
		_return_card(card)
		_travel(loc, card.id)
		return
	card.position = card.position.clamp(Vector2(-card.size.x * 0.4, -card.size.y * 0.4), WORLD - card.size * 0.6)
	card.rest_rot += randf_range(-0.03, 0.03)
	_save_layout(card)


func _on_clicked(card: TableCard) -> void:
	if sheet:
		var sb = sheet.slot_of(card)
		if sb:
			sb.card = null
			_return_card(card)
			sheet.refresh()
			_highlight_candidates()
			return
		var free := sheet.first_free_for(card.id)
		if free:
			_put_in_slot(card, free)
			return
	_toggle_note(card)


func _return_card(card: TableCard) -> void:
	if card.get_parent() != cards_layer:
		_card_to_desk(card)
	var lay = Game.state["layout"].get(card.id)
	var target := card.position
	if lay != null:
		target = Vector2(float(lay[0]), float(lay[1]))
		card.rest_rot = float(lay[2])
	var tw := create_tween().set_parallel()
	tw.tween_property(card, "position", target, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "base_scale", 1.0, 0.35)


func _put_in_slot(card: TableCard, sb) -> void:
	Sound.play("ui_card", -3.0)
	if sb.card and sb.card != card:
		var prev: TableCard = sb.card
		sb.card = null
		_return_card(prev)
	var old = sheet.slot_of(card)
	if old and old != sb:
		old.card = null
	sb.card = card
	if card.get_parent() == cards_layer:
		var center := world_to_screen(card.position + card.size / 2.0)
		card.reparent(sb, false)
		card.global_position = center - card.size / 2.0 * card.scale
	else:
		card.reparent(sb, true)
	var fit := minf(1.0, minf(150.0 / card.size.x, 116.0 / card.size.y))
	var target := Vector2(sb.size.x / 2, (sb.size.y - 22) / 2) - card.size / 2
	card.rest_rot = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(card, "position", target, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "base_scale", fit, 0.25)
	sheet.refresh()
	_highlight_candidates()


# ---------------------------------------------------------------- места

func _travel(loc: String, with_card := "") -> void:
	if _reading:
		return
	var s := Game.state
	if s["here"] != loc:
		s["here"] = loc
		Sound.play("ui_map")
		Sound.environment("locations", loc, Rules.phase_key(s))
		s["cards"][loc]["fresh"] = false
		map.move_hat(loc)
		_close_sheet()
		spread.refresh()
		var place := Rect2(map.position, map.size).merge(Rect2(spread.position, spread.size))
		if not _visible_rect().encloses(place):
			focus_rect(place.grow(40))
		for id in nodes:
			nodes[id].queue_redraw()
	if with_card != "":
		# Карта брошена на место: ищем дело здесь, где она пригодится
		for a in Rules.actions_for(s, loc):
			if a.get("uses", []).has(with_card):
				_choose_action(a, loc)
				return
			for sl in a.get("slots", []):
				if Rules.slot_accepts(sl, with_card, s, Rules.action_ctx(a, loc, {})):
					_choose_action(a, loc, {sl["id"]: with_card})
					return


# ---------------------------------------------------------------- дела

func _choose_action(a: Dictionary, where: String, preset := {}) -> void:
	if _reading:
		return
	_close_note()
	var s := Game.state
	var ctx := Rules.action_ctx(a, where, {})
	var check := Rules.can_do(a, s, ctx)
	if not check["ok"] and not check.get("needs_slot", false):
		_toast(check["reason"])
		return
	if not a.has("slots"):
		_close_sheet()
		_after(Game.do_action(a, where, {}))
		return
	_close_sheet()
	sheet = ActionSheet.new()
	Sound.play("ui_folder" if a["id"] == "file_case" else "ui_paper")
	sheet.setup(a, where)
	sheet.confirmed.connect(func(slots):
		var act: Dictionary = sheet.action
		var w: String = sheet.where
		_close_sheet()
		_after(Game.do_action(act, w, slots)))
	sheet.cancelled.connect(_close_sheet)
	sheet_layer.add_child(sheet)
	_update_hint()
	# нужные для дела карты сами выходят из картотеки
	var back := []
	for sb in sheet.slot_boxes:
		for id in Rules.slot_candidates(sb.slot, s, sheet.ctx()):
			if s.get("archived", {}).has(id) and not back.has(id):
				back.append(id)
	for id in preset.values():
		if s.get("archived", {}).has(id) and not back.has(id):
			back.append(id)
	if back.size() > 0:
		_unarchive(back)
	# Размер листа становится известен не сразу (контейнеры раскладываются на следующих кадрах),
	# поэтому место считается по минимальному размеру и пересчитывается при каждом изменении.
	var placed := sheet
	sheet.resized.connect(func(): _place_sheet(placed))
	_place_sheet(sheet)
	await get_tree().process_frame
	if sheet == null:
		return
	_place_sheet(sheet)
	_frame_candidates()
	sheet.modulate.a = 0
	create_tween().tween_property(sheet, "modulate:a", 1.0, 0.2)
	for slot_id in preset:
		var cid: String = preset[slot_id]
		if nodes.has(cid):
			for sb in sheet.slot_boxes:
				if sb.slot["id"] == slot_id:
					_put_in_slot(nodes[cid], sb)
	_highlight_candidates()


func _frame_candidates() -> void:
	if sheet == null:
		return
	var r := Rect2()
	var first := true
	for sb in sheet.slot_boxes:
		for id in Rules.slot_candidates(sb.slot, Game.state, sheet.ctx()):
			if nodes.has(id) and nodes[id].get_parent() == cards_layer:
				var cr := Rect2(nodes[id].position, nodes[id].size)
				r = cr if first else r.merge(cr)
				first = false
	if first or _visible_rect().grow(-20).encloses(r):
		return
	# лист закрывает низ экрана: подходящие карты показываем в верхней части кадра
	var ts := table_size()
	var fit := r.grow(80)
	fit.size.y += (sheet.size.y + 60) / maxf(cam_zoom, 0.1)
	focus_rect(fit, 1.0, true)


func _highlight_candidates() -> void:
	var cands := {}
	if sheet:
		for sb in sheet.slot_boxes:
			sb.hot = false
			if sb.card == null:
				for id in Rules.slot_candidates(sb.slot, Game.state, sheet.ctx()):
					cands[id] = true
					sb.hot = true
	for id in nodes:
		nodes[id].highlight = cands.has(id) and nodes[id].get_parent() == cards_layer
		nodes[id].queue_redraw()


func _close_sheet() -> void:
	if sheet == null:
		return
	for sb in sheet.slot_boxes:
		if sb.card:
			var c: TableCard = sb.card
			sb.card = null
			_return_card(c)
	sheet.queue_free()
	sheet = null
	_highlight_candidates()
	_update_hint()


func _after(res: Dictionary) -> void:
	if res.has("error"):
		_toast(res["error"])
		return
	sync_cards(true)
	_apply_light()
	dial.refresh()
	if res.get("silent", false):
		flow()
		return
	var portrait: Texture2D
	if res.has("speaker"):
		portrait = Art.portrait(res["speaker"], res.get("mood", ""))
	_read(res.get("title", ""), res.get("text", ""), res.get("changes", []), "result", flow, portrait)


## После письма Люмин город и личные встречи остаются доступны.
func _show_build_end() -> void:
	var sh := Sheet.new(600, 0.7)
	sh.add_kicker("Послевкусие")
	sh.add_title("Продолжение следует")
	sh.add_text("Письмо Люмин отправлено в Меропид. Пока она в крепости, Шевалье может вернуться к знакомым и провести в городе свободный вечер.")
	sh.add_row([
		Sheet.make_button("Остаться за столом", sh.close),
		Sheet.make_button("В главное меню", func():
			sh.close()
			Game.show_menu()),
	])
	Game.main.open_overlay(sh)


## Разбор последствий: уведомления о событиях, затем сцены/активности.
func flow() -> void:
	var item := Game.next_flow_item()
	if item.is_empty():
		_highlight_candidates()
		_update_hint()
		if Game.build_ended() and not Game.state["flags"].get("meropide_page_seen", false):
			Game.state["flags"]["meropide_page_seen"] = true
			_show_build_end()
		Game.autosave()
		return
	if item["type"] == "notice":
		sync_cards(true)
		var n: Dictionary = item["data"]
		_read(n.get("title", ""), n.get("text", ""), [], n.get("kind", "event"), flow)
	else:
		Game.start_queue_item(item)


# ---------------------------------------------------------------- чтение (события, итоги)

func _read(title: String, text: String, changes: Array, kind: String, then: Callable, portrait: Texture2D = null) -> void:
	if text == "" and _changes_lines(changes).is_empty():
		then.call()
		return
	if changes.any(func(change): return change.get("kind") == "stage"):
		Sound.play("clue")
	else:
		Sound.play("ui_paper")
	_reading = true
	var sh := Sheet.new(600 if kind != "result" else 560, 0.28)
	if kind == "intro":
		sh.add_kicker("Кур-де-Фонтейн")
	sh.add_title(title, portrait)
	if text != "":
		var l := sh.add_text(text)
		l.add_theme_font_size_override("font_size", 19)
	for c in changes:
		if c.get("kind") in ["stage", "expire"]:
			shake(5.0)
	var lines := _changes_lines(changes)
	if lines.size() > 0:
		sh.add_rule()
		for ln in lines:
			var cl := Label.new()
			cl.theme_type_variation = "Hand"
			cl.text = ln[0]
			cl.add_theme_color_override("font_color", ln[1])
			cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			cl.custom_minimum_size.x = 480
			sh.body.add_child(cl)
	sh.add_row([Sheet.make_button("Отложить", sh.close)])
	sh.closed.connect(func():
		_reading = false
		then.call())
	Game.main.open_overlay(sh)


func _changes_lines(changes: Array) -> Array:
	var out := []
	var seen := {}
	var s := Game.state
	for c in changes:
		var key := str(c)
		if seen.has(key):
			continue
		seen[key] = true
		match c["kind"]:
			"gain":
				if Rules.is_location(c["id"]):
					out.append(["На карте появилось: " + Rules.title_of(c["id"], s), Color("2f4f2a")])
				else:
					out.append(["+ " + Rules.title_of(c["id"], s), Color("2f4f2a")])
			"lose":
				out.append(["− " + Rules.title_of(c["id"], s), Color("6a2a20")])
			"expire":
				out.append([Rules.title_of(c["id"], s) + " — больше не здесь", Color("5a5048")])
			"rel":
				out.append([Rules.title_of(c["who"], s) + (": теперь " if c["add"] else ": уже не ") + str(c["tag"]).to_lower(), Color("2d3a5a")])
			"spent":
				out.append([Rules.title_of(c["id"], s) + " — понадобится время, чтобы снова на это рассчитывать", Color("6a5a40")])
			"filed":
				out.append(["Подшито в дело: " + Rules.title_of(c["id"], s), Color("5a3c14")])
			"stage":
				out.append(["Дело выросло: «" + Rules.title_of(c["id"], s) + "»", Color("8a2020")])
	return out


# ---------------------------------------------------------------- записка о карте

func _toggle_note(card: TableCard) -> void:
	if note_card == card.id:
		_close_note()
		return
	_close_note()
	note_card = card.id
	card.focused = true
	var s := Game.state
	var fresh: bool = s["cards"].get(card.id, {}).get("fresh", false)
	if fresh:
		s["cards"][card.id]["fresh"] = false
		card.queue_redraw()
	match card.look:
		"folder": Sound.play("ui_folder")
		"book": Sound.play("ui_page")
		"envelope": Sound.play("ui_seal" if fresh else "ui_paper")
		"note", "clipping", "telegram": Sound.play("ui_paper", -2.0)
		_: Sound.play("ui_card")
	var d := card.d
	var p := PanelContainer.new()
	p.theme_type_variation = "Paper"
	p.custom_minimum_size = Vector2(360, 0)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	if d.has("subtitle") and d.get("type") in ["person"]:
		var k := Label.new()
		k.theme_type_variation = "Kicker"
		k.text = str(d["subtitle"]).to_upper()
		v.add_child(k)
	var t := Label.new()
	t.theme_type_variation = "InkTitle"
	t.add_theme_font_size_override("font_size", 22)
	t.text = card.title()
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size.x = 320
	v.add_child(t)
	var body := Label.new()
	body.theme_type_variation = "Ink"
	body.add_theme_font_size_override("font_size", 16)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = 320
	body.text = Rules.txt(d.get("text"), s)
	v.add_child(body)
	if d.get("type") == "person":
		var where = Rules.where_is(s, card.id)
		var extra := Label.new()
		extra.theme_type_variation = "Hand"
		extra.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		extra.custom_minimum_size.x = 320
		var rels: Array = s["rel"].get(card.id, [])
		var lines := []
		lines.append(("Сейчас: " + Rules.title_of(where, s)) if where != null else "Где сейчас — неизвестно.")
		if d.has("vision"):
			lines.append("Глаз Бога: " + str(d["vision"]))
		if rels.size() > 0:
			lines.append("Между ними: " + ", ".join(PackedStringArray(rels)).to_lower())
		extra.text = "\n".join(PackedStringArray(lines))
		v.add_child(extra)
	if d.has("stages"):
		var filed := Rules.case_filed(s, card.id)
		var cl := Label.new()
		cl.theme_type_variation = "Hand"
		cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cl.custom_minimum_size.x = 320
		var st := Rules.case_stage(s, card.id)
		var names := PackedStringArray()
		for e in filed:
			names.append(Rules.title_of(e, s))
		cl.text = "Стадия %d из %d — %s." % [st + 1, d["stages"].size(), str(d["stages"][st].get("mark", "")).to_lower()]
		cl.text += ("
Подшито: " + ", ".join(names) + ".") if names.size() > 0 else "
Пока ничего не подшито. Улику можно бросить прямо на папку."
		v.add_child(cl)
	if card.lifetime_phrase() != "":
		var lt := Label.new()
		lt.theme_type_variation = "Hand"
		lt.add_theme_color_override("font_color", Look.BAD if card.urgent() else Color("2d3a5a"))
		lt.text = "Это ненадолго: " + card.lifetime_phrase() + "."
		v.add_child(lt)
	if d.get("type") == "person" and Rules.where_is(s, card.id) == s["here"] and Content.actions.has("talk"):
		var tb := Button.new()
		tb.theme_type_variation = "InkButton"
		tb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tb.text = "→ Поговорить. Тему — любую карту со стола"
		var pid := card.id
		tb.pressed.connect(func():
			_talk_with(pid, ""))
		v.add_child(tb)
	var acts := Rules.actions_for(s, card.id)
	if acts.size() > 0:
		var r := ColorRect.new()
		r.color = Color(0.35, 0.27, 0.18, 0.3)
		r.custom_minimum_size = Vector2(0, 1)
		v.add_child(r)
		for a in acts:
			var ctx := Rules.action_ctx(a, card.id, {})
			var check := Rules.can_do(a, s, ctx)
			var b := Button.new()
			b.theme_type_variation = "InkButton"
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var cost := Rules.cost_of(a, s)
			b.text = "→ " + str(a["title"]) + ("  " + "◷".repeat(cost) if cost > 0 else "")
			if not check["ok"] and not check.get("needs_slot", false):
				b.disabled = true
				b.tooltip_text = check["reason"]
				b.text += "\n    " + str(check["reason"])
			var act: Dictionary = a
			var cid := card.id
			b.pressed.connect(func():
				_choose_action(act, cid))
			v.add_child(b)
	note = p
	note_layer.add_child(p)
	await get_tree().process_frame
	if note != p:
		return
	var ts := table_size()
	var cr := plane_rect_to_screen(card.get_global_rect())
	var pos := Vector2(cr.end.x + 14, cr.position.y)
	if pos.x + p.size.x > ts.x - 10:
		pos.x = cr.position.x - p.size.x - 14
	pos.y = clampf(pos.y, 10, ts.y - p.size.y - 10)
	pos.x = clampf(pos.x, 10, ts.x - p.size.x - 10)
	p.position = pos
	p.modulate.a = 0
	create_tween().tween_property(p, "modulate:a", 1.0, 0.15)


func _close_note() -> void:
	if note_card != "" and nodes.has(note_card):
		nodes[note_card].focused = false
	note_card = ""
	if note:
		note.queue_free()
		note = null


# ---------------------------------------------------------------- подсказки

func _toast(text: String) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Look.paper_box(Color("f4ecd9"), 8, 10))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.theme_type_variation = "Hand"
	l.text = text
	p.add_child(l)
	note_layer.add_child(p)
	await get_tree().process_frame
	var ts := table_size()
	p.position = Vector2((ts.x - p.size.x) / 2, ts.y - 120)
	var tw := create_tween()
	tw.tween_interval(1.8)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)



# ---------------------------------------------------------------- разговоры

## Портрет человека под точкой (кроме перетаскиваемой карты).
func _person_under(gp: Vector2, dragged: TableCard) -> String:
	var best := ""
	var best_idx := -1
	for id in nodes:
		var n: TableCard = nodes[id]
		if n == dragged or n.get_parent() != cards_layer or str(n.d.get("type")) != "person":
			continue
		if n.get_global_rect().has_point(gp) and n.get_index() > best_idx:
			best = id
			best_idx = n.get_index()
	return best


## Открыть лист разговора: собеседник и (если есть) тема или подход уже лежат в ячейках.
func _talk_with(pid: String, card_id: String) -> void:
	var s := Game.state
	if not Content.actions.has("talk"):
		return
	if Rules.where_is(s, pid) != s["here"]:
		var where = Rules.where_is(s, pid)
		_toast("%s сейчас не здесь%s." % [Rules.title_of(pid, s), (" — " + Rules.title_of(where, s)) if where != null else ""])
		return
	var preset := {"who": pid}
	if card_id != "" and card_id != pid:
		if str(Content.def(card_id).get("type")) == "approach":
			if Rules.is_resting(s, card_id):
				_toast(Rules.title_of(card_id, s) + " ещё не восстановилось.")
			else:
				preset["approach"] = card_id
		else:
			preset["topic"] = card_id
	_choose_action(Content.actions["talk"], s["here"], preset)


func _place_sheet(sh) -> void:
	if sh == null or not is_instance_valid(sh) or sh != sheet:
		return
	var ts := table_size()
	var sz: Vector2 = sh.get_combined_minimum_size().max(sh.size)
	var y := clampf(ts.y - sz.y - 40, 90, maxf(90, ts.y - sz.y - 10))
	sh.position = Vector2(roundf((ts.x - sz.x) / 2), roundf(y))


func _case_under(gp: Vector2, dragged: TableCard) -> String:
	if dragged.d.has("stages"):
		return ""
	for id in nodes:
		var n: TableCard = nodes[id]
		if n != dragged and n.get_parent() == cards_layer and n.d.has("stages") and n.get_global_rect().has_point(gp):
			return id
	return ""


func _case_action(case_id: String) -> Dictionary:
	for aid in Content.actions:
		var a: Dictionary = Content.actions[aid]
		if a.get("case", false) and a.get("on") == case_id:
			return a
	return {}


## Открыть лист «Подшить в дело» с папкой и уликой в ячейках.
func _file_into(case_id: String, card_id: String) -> void:
	var a := _case_action(case_id)
	if a.is_empty() or not Rules.test(a.get("visible"), Game.state, Rules.action_ctx(a, case_id, {})):
		_toast("Это дело уже закрыто.")
		return
	if Game.state["flags"].get("filed:" + card_id, false):
		_toast(Rules.title_of(card_id, Game.state) + " уже в деле.")
		return
	_choose_action(a, case_id, {"case": case_id, "evidence": card_id})


# ---------------------------------------------------------------- камера и режиссура

func screen_to_world(sp: Vector2) -> Vector2:
	return (screen_to_plane(sp) - world.position) / cam_zoom


func world_to_screen(wp: Vector2) -> Vector2:
	return plane_to_screen(wp * cam_zoom + world.position)


func screen_to_plane(sp: Vector2) -> Vector2:
	return _apply_h(_h, sp)


func plane_to_screen(pp: Vector2) -> Vector2:
	return _apply_h(_hi, pp)


func plane_rect_to_screen(r: Rect2) -> Rect2:
	var out := Rect2(plane_to_screen(r.position), Vector2.ZERO)
	for c in [Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		out = out.expand(plane_to_screen(c))
	return out


static func _apply_h(h: PackedFloat32Array, p: Vector2) -> Vector2:
	if h.size() < 9:
		return p
	var w := h[6] * p.x + h[7] * p.y + h[8]
	return Vector2(h[0] * p.x + h[1] * p.y + h[2], h[3] * p.x + h[4] * p.y + h[5]) / w


## Гомография по четырём парам точек (from[i] → to[i]), 3×3 построчно.
static func _homography(from: Array, to: Array) -> PackedFloat32Array:
	var m := []
	for i in 4:
		var x: float = from[i].x
		var y: float = from[i].y
		var u: float = to[i].x
		var v: float = to[i].y
		m.append([x, y, 1.0, 0.0, 0.0, 0.0, -u * x, -u * y, u])
		m.append([0.0, 0.0, 0.0, x, y, 1.0, -v * x, -v * y, v])
	for col in 8:
		var piv := col
		for r in range(col + 1, 8):
			if absf(m[r][col]) > absf(m[piv][col]):
				piv = r
		var tmp = m[col]
		m[col] = m[piv]
		m[piv] = tmp
		for r in 8:
			if r != col:
				var f: float = m[r][col] / m[col][col]
				for c in range(col, 9):
					m[r][c] -= f * m[col][c]
	var h := PackedFloat32Array()
	for r in 8:
		h.append(m[r][8] / m[r][r])
	h.append(1.0)
	return h


## Обе стороны трапеции центрируем относительно оптической оси.
func _update_plane() -> void:
	if plane == null:
		return
	var ts := table_size()
	if ts.x < 10.0 or ts.y < 10.0:
		return
	var near := ts.x / NEAR_SCALE
	plane_size = Vector2(ts.x / FAR_SCALE, ts.y / DEPTH_RATIO).round()
	var cx := plane_size.x / 2.0
	var screen := [Vector2.ZERO, Vector2(ts.x, 0), ts, Vector2(0, ts.y)]
	var flat := [Vector2.ZERO, Vector2(plane_size.x, 0), Vector2(cx + near / 2.0, plane_size.y), Vector2(cx - near / 2.0, plane_size.y)]
	_h = _homography(screen, flat)
	_hi = _homography(flat, screen)
	desk_input.size = plane_size
	# запас по разрешению, чтобы ближний край и мелкий текст не мылились
	var px := get_viewport().get_final_transform().get_scale()
	var ss := clampf(maxf(px.x, px.y), 1.0, 2.5) * 1.15
	plane.size_2d_override = Vector2i(plane_size)
	plane.size = Vector2i((plane_size * ss).round())
	plane_mat.set_shader_parameter("h0", Vector3(_h[0], _h[1], _h[2]))
	plane_mat.set_shader_parameter("h1", Vector3(_h[3], _h[4], _h[5]))
	plane_mat.set_shader_parameter("h2", Vector3(_h[6], _h[7], _h[8]))
	plane_mat.set_shader_parameter("screen_size", ts)
	plane_mat.set_shader_parameter("plane_size", plane_size)


## Точка плоского стола, которая видна в центре экрана: камера держит над ней cam_pos.
func _plane_anchor() -> Vector2:
	return screen_to_plane(table_size() / 2.0)


## Сдвиг мыши на экране → сдвиг по плоскому столу в этом месте.
func _plane_delta(sp: Vector2, rel: Vector2) -> Vector2:
	return screen_to_plane(sp) - screen_to_plane(sp - rel)


## Карта возвращается из ячейки листа (он плоский, поверх стола) на стол — туда, где она видна.
func _card_to_desk(card: TableCard) -> void:
	var center := card.get_global_transform_with_canvas() * (card.size / 2.0)
	card.reparent(cards_layer, false)
	card.position = screen_to_world(center) - card.size / 2.0


func _home_rect() -> Rect2:
	return Rect2(0, 0, 1440, 900)


func _fit_zoom(r: Rect2) -> float:
	# по ближнему, самому узкому краю
	var ts := Vector2(table_size().x / NEAR_SCALE, plane_size.y)
	return clampf(minf(ts.x / r.size.x, ts.y / r.size.y), ZOOM_MIN, ZOOM_MAX)


func _home_camera(instant := false) -> void:
	var r := _home_rect()
	zoom_target = _fit_zoom(r)
	cam_target = r.get_center()
	if instant:
		cam_zoom = zoom_target
		cam_pos = cam_target
	_clamp_camera()
	_apply_camera()


## Показать область стола. Если игрок только что сам двигал камеру, не перехватываем её.
func focus_rect(r: Rect2, zoom_mul := 1.0, force := false) -> void:
	if not force and _clock - _user_cam_time < 2.5:
		return
	if not Game.settings.get("camera_direction", true) and not force:
		return
	zoom_target = clampf(_fit_zoom(r.grow(60)) * zoom_mul, ZOOM_MIN, ZOOM_MAX)
	zoom_target = minf(zoom_target, maxf(cam_zoom, 1.0))
	cam_target = r.get_center()
	_anchored = false
	_smooth = 0.55
	_clamp_camera()


## Видна ли область целиком при нынешней камере.
func _visible_rect() -> Rect2:
	# прямоугольник, целиком помещающийся в видимую трапецию
	var ts := table_size()
	var top := screen_to_world(Vector2(ts.x / 2.0, 0)).y
	var bl := screen_to_world(Vector2(0, ts.y))
	var br := screen_to_world(ts)
	return Rect2(bl.x, top, br.x - bl.x, bl.y - top)


func shake(amount := 6.0) -> void:
	if Game.settings.get("camera_direction", true):
		_shake = maxf(_shake, amount)


func _pan_by(screen_delta: Vector2) -> void:
	if screen_delta.length() > 0.5:
		_pan_moved = true
	# перетаскивание — один к одному, без запаздывания; скорость запоминаем для инерции
	_anchored = false
	var d := screen_delta / cam_zoom
	cam_pos -= d
	cam_target = cam_pos
	_cam_vel = Vector2.ZERO
	_drag_vel = _drag_vel.lerp(-d / maxf(get_process_delta_time(), 0.001), 0.35)
	_user_cam_time = _clock
	_clamp_camera()
	cam_pos = cam_target
	_apply_camera()


## Отпустили стол после перетаскивания: вид немного доезжает по инерции и мягко останавливается.
func _end_pan() -> void:
	if _pan_moved and _drag_vel.length() > 60.0:
		_smooth = 0.32
		cam_target = cam_pos + _drag_vel.limit_length(2600.0) * 0.12
		_clamp_camera()
	_drag_vel = Vector2.ZERO


func _zoom_at(screen_point: Vector2, factor: float) -> void:
	# точка стола под курсором держится под курсором на всём пути масштабирования
	if not _anchored or _anchor_screen.distance_to(screen_point) > 2.0:
		_anchor_world = (screen_to_plane(screen_point) - (_plane_anchor() - cam_pos * cam_zoom)) / cam_zoom
		_anchor_screen = screen_point
	_anchored = true
	zoom_target = clampf(zoom_target * factor, ZOOM_MIN, ZOOM_MAX)
	_smooth = 0.16
	_user_cam_time = _clock


func _clamp_camera() -> void:
	# по ближнему краю: дальний шире, но за краем мира там тоже дерево стола
	var half := Vector2(table_size().x / NEAR_SCALE, plane_size.y) / 2.0 / zoom_target
	var margin := Vector2(160, 120)
	var lo := half - margin
	var hi := WORLD - half + margin
	for k in 2:
		if lo[k] > hi[k]:
			cam_target[k] = WORLD[k] / 2.0
		else:
			cam_target[k] = clampf(cam_target[k], lo[k], hi[k])


func _apply_camera() -> void:
	if world == null:
		return
	var off := Vector2.ZERO
	if _shake > 0.05:
		off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	world.scale = Vector2.ONE * cam_zoom
	# без округления до пикселя: при плавном движении и масштабе оно давало дрожь
	world.position = _plane_anchor() - cam_pos * cam_zoom + off


## Плавное приближение к цели с затуханием скорости (без рывка в начале и в конце).
static func _damp(cur: float, target: float, vel: float, smooth: float, dt: float) -> Vector2:
	var omega := 2.0 / maxf(0.0001, smooth)
	var x := omega * dt
	var e := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change := cur - target
	var temp := (vel + omega * change) * dt
	return Vector2(target + (change + temp) * e, (vel - omega * temp) * e)


func _process(delta: float) -> void:
	_clock += delta
	if _plane_hover and get_viewport().gui_get_hovered_control() != self and Input.get_mouse_button_mask() == 0:
		_plane_hover = false
		plane.notification(Node.NOTIFICATION_VP_MOUSE_EXIT)
	var moved := cam_pos.distance_to(cam_target) > 0.05 or absf(cam_zoom - zoom_target) > 0.0002 \
		or _shake > 0.05 or _cam_vel.length() > 0.5 or absf(_zoom_vel) > 0.0005
	if not moved or _panning:
		if _panning:
			_drag_vel = _drag_vel.lerp(Vector2.ZERO, 1.0 - exp(-6.0 * delta))
		return
	var z := _damp(cam_zoom, zoom_target, _zoom_vel, _smooth, delta)
	cam_zoom = z.x
	_zoom_vel = z.y
	if _anchored:
		# пока идёт масштаб к курсору, центр вычисляется так, чтобы точка под курсором не уплывала
		cam_pos = _anchor_world - (screen_to_plane(_anchor_screen) - _plane_anchor()) / cam_zoom
		var keep := cam_pos
		cam_target = cam_pos
		_clamp_camera()
		cam_pos = cam_target
		if keep.distance_to(cam_pos) > 0.5 or absf(cam_zoom - zoom_target) < 0.0005:
			_anchored = false
		_cam_vel = Vector2.ZERO
	else:
		var px := _damp(cam_pos.x, cam_target.x, _cam_vel.x, _smooth, delta)
		var py := _damp(cam_pos.y, cam_target.y, _cam_vel.y, _smooth, delta)
		cam_pos = Vector2(px.x, py.x)
		_cam_vel = Vector2(px.y, py.y)
	_shake = lerpf(_shake, 0.0, 1.0 - exp(-9.0 * delta))
	_apply_camera()


func _over_hud(sp: Vector2) -> bool:
	if Game.main.has_overlay():
		return true
	for layer in [sheet_layer, note_layer]:
		for c in layer.get_children():
			if c is Control and c.visible and c.get_global_rect().has_point(sp):
				return true
	for c in [dial, notebook, plaque, tidy_btn]:
		if c.get_global_rect().has_point(sp):
			return true
	return false


func _input(e: InputEvent) -> void:
	if not is_visible_in_tree() or Game.mode != "table":
		return
	var wheel: bool = e is InputEventMouseButton and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]
	if wheel and _over_scrollable():
		return
	if e is InputEventMouseButton and e.pressed and not _over_hud(e.position):
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(e.position, 1.1)
			get_viewport().set_input_as_handled()
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(e.position, 1.0 / 1.1)
			get_viewport().set_input_as_handled()
		elif e.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_panning = true
			_pan_moved = false
	elif e is InputEventMouseButton and not e.pressed and e.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		if _panning:
			_end_pan()
		_panning = false
	elif e is InputEventMouseMotion and _panning and (e.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE)):
		_pan_by(_plane_delta(e.position, e.relative))
	elif e is InputEventKey and e.pressed and not e.echo:
		var step := 160.0 / cam_zoom
		match e.keycode:
			KEY_HOME:
				_user_cam_time = -10.0
				_anchored = false
				_smooth = 0.45
				_home_camera()
			KEY_A, KEY_LEFT:
				cam_target.x -= step
			KEY_D, KEY_RIGHT:
				cam_target.x += step
			KEY_W, KEY_UP:
				cam_target.y -= step
			KEY_S, KEY_DOWN:
				cam_target.y += step
			KEY_EQUAL, KEY_KP_ADD:
				zoom_target = clampf(zoom_target * 1.12, ZOOM_MIN, ZOOM_MAX)
			KEY_MINUS, KEY_KP_SUBTRACT:
				zoom_target = clampf(zoom_target / 1.12, ZOOM_MIN, ZOOM_MAX)
			_:
				return
		_anchored = false
		_smooth = 0.22
		_user_cam_time = _clock
		_clamp_camera()


## Курсор над списком, который есть куда прокручивать (дела на открытке, длинная записка).
func _over_scrollable() -> bool:
	var c := get_viewport().gui_get_hovered_control()
	if c == self:
		c = plane.gui_get_hovered_control()
	while c != null and c != self:
		if c is ScrollContainer:
			var sc := c as ScrollContainer
			var bar := sc.get_v_scroll_bar()
			if bar and bar.max_value - bar.page > 1.0:
				return true
		c = c.get_parent_control()
	return false
