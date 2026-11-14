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
var plaque: DeskProp
var inkwell: DeskProp
var blotter: Control

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

	bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wood = ShaderMaterial.new()
	wood.shader = load("res://shaders/wood.gdshader")
	var walnut := Art.surface("walnut")
	if walnut:
		wood.set_shader_parameter("walnut", walnut)
		wood.set_shader_parameter("has_material", true)
	bg.material = wood
	add_child(bg)
	blotter = Control.new()
	blotter.set_anchors_preset(Control.PRESET_FULL_RECT)
	blotter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blotter.draw.connect(_draw_blotter)
	add_child(blotter)

	inkwell = DeskProp.new("inkwell")
	add_child(inkwell)

	hint_label = Label.new()
	hint_label.add_theme_font_override("font", Look.font("hand"))
	hint_label.add_theme_font_size_override("font_size", 15)
	hint_label.add_theme_color_override("font_color", Color(0.93, 0.85, 0.7, 0.55))
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label.text = "Вещи можно раскладывать как угодно. Булавка на карте — отправиться туда.\nЧасы — переждать. Карту можно бросить на булавку или в ячейку дела."
	add_child(hint_label)

	map = CityMap.new()
	map.pin_clicked.connect(_travel)
	add_child(map)

	spread = PlaceSpread.new()
	spread.action_chosen.connect(func(a):
		_choose_action(a, str(Game.state["here"])))
	spread.person_clicked.connect(func(pid):
		if nodes.has(pid):
			_toggle_note(nodes[pid]))
	add_child(spread)

	dial = TimeDial.new()
	dial.wait_requested.connect(_on_wait)
	add_child(dial)

	notebook = DeskProp.new("notebook")
	notebook.activated.connect(Dialogs.journal)
	add_child(notebook)
	plaque = DeskProp.new("plaque")
	plaque.activated.connect(Dialogs.pause)
	add_child(plaque)

	cards_layer = Control.new()
	cards_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	cards_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cards_layer)

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
	_layout_fixed()

	# Карты, пришедшие из сцены/активности, появятся с анимацией после затемнения
	for c in Game.pending_return.get("changes", []):
		if c["kind"] == "gain":
			_hidden_until_shown.append(c["id"])
	sync_cards(false)
	_apply_light(true)


func on_shown() -> void:
	sync_cards(true)
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
	return size if size.x > 10 else get_viewport_rect().size


func _layout_fixed() -> void:
	var ts := table_size()
	wood.set_shader_parameter("size", ts)
	lamp_mat.set_shader_parameter("size", ts)
	map.position = Vector2(30, 30)
	spread.position = Vector2(500, 34)
	dial.position = Vector2(ts.x - 310, 28)
	notebook.position = Vector2(ts.x - 170, ts.y - 180)
	plaque.position = Vector2(34, ts.y - 72)
	inkwell.position = Vector2(ts.x - 430, 40)
	hint_label.position = Vector2(ts.x * 0.5 - 300, ts.y - 64)
	hint_label.visible = bool(Game.settings["hints"])
	blotter.queue_redraw()


func _draw_blotter() -> void:
	var ts := table_size()
	var r := Rect2(26, 310, ts.x - 224, ts.y - 400)
	if r.size.x < 100 or r.size.y < 100:
		return
	var edge := Look.rrect(r, 17)
	Look.soft_shadow(blotter, edge, Vector2(3, 8), 10, 0.7)
	Look.fill_v(blotter, edge, Color("273d3b"), Color("182928"))
	Look.texture_polygon(blotter, edge, Art.surface("leather"), 1.0, Color(0.86, 0.91, 0.87, 0.56))
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
	var out := [
		Rect2(map.position, map.size).grow(6),
		Rect2(spread.position, spread.size).grow(8),
		Rect2(dial.position, dial.size),
		Rect2(notebook.position, notebook.size).grow(30),
		Rect2(plaque.position, plaque.size),
		Rect2(hint_label.position, Vector2(640, 50)),
	]
	return out


func _anchor_for(d: Dictionary) -> Vector2:
	var ts := table_size()
	match str(d.get("type", "")):
		"person":
			return Vector2(40, 470)
		"invitation", "event":
			return Vector2(ts.x * 0.42, ts.y - 260)
		"rumor", "info", "clue":
			return Vector2(ts.x * 0.36, 330)
		"item":
			return Vector2(ts.x * 0.62, ts.y - 240)
		"state":
			return Vector2(ts.x - 140, 260)
		"world":
			return Vector2(ts.x * 0.6, 330)
		"affair", "storyline":
			return Vector2(ts.x - 520, 262)
	return Vector2(ts.x * 0.5, ts.y * 0.5)


func _free_spot(card_size: Vector2, anchor: Vector2, ignore_id := "") -> Vector2:
	var ts := table_size()
	var bounds := Rect2(Vector2(20, 20), ts - Vector2(40, 40) - card_size)
	var reserved := _reserved()
	var occupied := []
	for id in nodes:
		if id == ignore_id:
			continue
		var n: TableCard = nodes[id]
		var lay = Game.state["layout"].get(id)
		var p0 := n.position if lay == null else Vector2(float(lay[0]), float(lay[1]))
		occupied.append(Rect2(p0, n.size).grow(-8))
	var step := 26.0
	for ring in range(0, 40):
		var count := maxi(1, ring * 8)
		for k in count:
			var a := TAU * k / count
			var p := anchor + Vector2(cos(a), sin(a) * 0.8) * ring * step
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
	return (anchor + Vector2(randf_range(-40, 40), randf_range(-40, 40))).clamp(bounds.position, bounds.end)


func _save_layout(card: TableCard) -> void:
	Game.state["layout"][card.id] = [card.position.x, card.position.y, card.rest_rot]


# ---------------------------------------------------------------- синхронизация со состоянием

func sync_cards(animate: bool) -> void:
	var s := Game.state
	var want := {}
	for id in s["cards"]:
		if Rules.is_location(id):
			continue
		if not animate and _hidden_until_shown.has(id):
			continue
		want[id] = true
	for id in nodes.keys():
		if not s["cards"].has(id):
			_remove_node(id, animate)
	for id in want:
		if not nodes.has(id):
			_add_node(id, animate)
		else:
			nodes[id].queue_redraw()
	if animate:
		_hidden_until_shown.clear()
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
		target = _free_spot(card.size, _anchor_for(card.d), id)
		card.rest_rot = randf_range(-0.07, 0.07)
		_save_layout_at(card, target)
	card.rotation = card.rest_rot
	if animate:
		var ts := table_size()
		card.position = Vector2(target.x, ts.y + 60)
		card.rotation = card.rest_rot + randf_range(-0.5, 0.5)
		card.lift = 1.0
		var tw := create_tween()
		tw.tween_interval(randf_range(0.0, 0.25))
		tw.tween_property(card, "position", target, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		card.position = target


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
	_close_note()
	_close_sheet()
	var res := Game.wait_phase()
	_after(res)


# ---------------------------------------------------------------- ввод с карт

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_close_note()


func _on_picked(card: TableCard) -> void:
	_close_note()
	if card.get_parent() == cards_layer:
		cards_layer.move_child(card, -1)


func _on_dropped(card: TableCard) -> void:
	var gp := get_global_mouse_position()
	# в ячейку открытого дела
	if sheet:
		var sb := sheet.slot_under(gp, card.id)
		if sb:
			_put_in_slot(card, sb)
			return
		var old = sheet.slot_of(card)
		if old:
			old.card = null
			card.reparent(cards_layer, true)
			card.base_scale = 1.0
			sheet.refresh()
	# на булавку карты города
	var loc := map.pin_at_global(gp)
	if loc != "":
		_return_card(card)
		_travel(loc, card.id)
		return
	var ts := table_size()
	card.position = card.position.clamp(Vector2(-card.size.x * 0.4, -card.size.y * 0.4), ts - card.size * 0.6)
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
		card.reparent(cards_layer, true)
	var lay = Game.state["layout"].get(card.id)
	var target := card.position
	if lay != null:
		target = Vector2(float(lay[0]), float(lay[1]))
		card.rest_rot = float(lay[2])
	var tw := create_tween().set_parallel()
	tw.tween_property(card, "position", target, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "base_scale", 1.0, 0.35)


func _put_in_slot(card: TableCard, sb) -> void:
	if sb.card and sb.card != card:
		var prev: TableCard = sb.card
		sb.card = null
		_return_card(prev)
	var old = sheet.slot_of(card)
	if old and old != sb:
		old.card = null
	sb.card = card
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
		s["cards"][loc]["fresh"] = false
		map.move_hat(loc)
		_close_sheet()
		spread.refresh()
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
	sheet.setup(a, where)
	sheet.confirmed.connect(func(slots):
		var act: Dictionary = sheet.action
		var w: String = sheet.where
		_close_sheet()
		_after(Game.do_action(act, w, slots)))
	sheet.cancelled.connect(_close_sheet)
	sheet_layer.add_child(sheet)
	await get_tree().process_frame
	if sheet == null:
		return
	var ts := table_size()
	sheet.position = Vector2((ts.x - sheet.size.x) / 2, maxf(300, ts.y - sheet.size.y - 40))
	sheet.modulate.a = 0
	create_tween().tween_property(sheet, "modulate:a", 1.0, 0.2)
	for slot_id in preset:
		var cid: String = preset[slot_id]
		if nodes.has(cid):
			for sb in sheet.slot_boxes:
				if sb.slot["id"] == slot_id:
					_put_in_slot(nodes[cid], sb)
	_highlight_candidates()


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
	_read(res.get("title", ""), res.get("text", ""), res.get("changes", []), "result", flow)


## Разбор последствий: уведомления о событиях, затем сцены/активности.
func flow() -> void:
	var item := Game.next_flow_item()
	if item.is_empty():
		_highlight_candidates()
		Game.autosave()
		return
	if item["type"] == "notice":
		sync_cards(true)
		var n: Dictionary = item["data"]
		_read(n.get("title", ""), n.get("text", ""), [], n.get("kind", "event"), flow)
	else:
		Game.start_queue_item(item)


# ---------------------------------------------------------------- чтение (события, итоги)

func _read(title: String, text: String, changes: Array, kind: String, then: Callable) -> void:
	if text == "" and _changes_lines(changes).is_empty():
		then.call()
		return
	_reading = true
	var sh := Sheet.new(600 if kind != "result" else 560, 0.28)
	if kind == "intro":
		sh.add_kicker("Кур-де-Фонтейн")
	sh.add_title(title)
	if text != "":
		var l := sh.add_text(text)
		l.add_theme_font_size_override("font_size", 19)
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
	if card.lifetime_phrase() != "":
		var lt := Label.new()
		lt.theme_type_variation = "Hand"
		lt.add_theme_color_override("font_color", Look.BAD if card.urgent() else Color("2d3a5a"))
		lt.text = "Это ненадолго: " + card.lifetime_phrase() + "."
		v.add_child(lt)
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
	var cr := card.get_global_rect()
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
