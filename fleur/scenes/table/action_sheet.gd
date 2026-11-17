class_name ActionSheet
extends PanelContainer
## Лист с задуманным делом: описание, ячейки, в которые кладутся карты со стола, и время.

signal confirmed(slots: Dictionary)
signal cancelled

var action: Dictionary
var where := ""
var slot_boxes: Array = []
var reason_l: Label
var who_l: Label
var do_btn: Button


class SlotBox:
	extends Control
	var slot: Dictionary
	var card: TableCard = null
	var hot := false
	var _t := 0.0

	func _init(sl: Dictionary) -> void:
		slot = sl
		custom_minimum_size = Vector2(172, 150)
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2(4, 4), size - Vector2(8, 26))
		var col := Color(0.42, 0.3, 0.18, 0.55)
		if hot:
			col = Color(0.75, 0.5, 0.1, 0.6 + 0.3 * sin(_t * 5.0))
		draw_rect(r, Color(0.3, 0.2, 0.1, 0.06))
		var p := r.position
		var dash := 9.0
		for edge in [[p, Vector2(r.end.x, p.y)], [Vector2(r.end.x, p.y), r.end], [r.end, Vector2(p.x, r.end.y)], [Vector2(p.x, r.end.y), p]]:
			var a: Vector2 = edge[0]
			var b: Vector2 = edge[1]
			var n := int(a.distance_to(b) / dash)
			for i in range(0, n, 2):
				draw_line(a.lerp(b, float(i) / n), a.lerp(b, float(i + 1) / n), col, 1.6)
		var label := str(slot.get("label", ""))
		if card == null:
			Look.text_c(self, Look.font("hand"), r.get_center().x, r.get_center().y + 6, "положите карту", 13, Color(0.4, 0.3, 0.2, 0.55), r.size.x)
		draw_string(Look.font("serif_italic"), Vector2(0, size.y - 6), label + ("" if slot.get("required", false) else ""), HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Look.INK_SOFT)

	func drop_rect() -> Rect2:
		return get_global_rect().grow(18)


func setup(a: Dictionary, w: String) -> void:
	action = a
	where = w


func _ready() -> void:
	theme_type_variation = "Paper"
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	draw.connect(func():
		Look.texture_polygon(self, Look.rrect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), 2), Art.surface("paper"), 1.0, Color(1, 1, 1, 0.5))
		Look.engraved_corners(self, Rect2(Vector2(10, 10), size - Vector2(20, 20)), Color(0.48, 0.35, 0.16, 0.40), 15))
	custom_minimum_size = Vector2(560, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var k := Label.new()
	k.theme_type_variation = "Kicker"
	var place := Rules.title_of(where, Game.state) if Rules.is_location(where) else Rules.title_of(where, Game.state)
	k.text = place.to_upper()
	v.add_child(k)
	var t := Label.new()
	t.theme_type_variation = "InkTitle"
	t.text = str(action["title"])
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size.x = 500
	v.add_child(t)
	if action.has("desc"):
		var dl := Label.new()
		dl.theme_type_variation = "Ink"
		dl.add_theme_font_override("font", Look.font("serif_italic"))
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.custom_minimum_size.x = 500
		dl.text = Rules.txt(action["desc"], Game.state)
		v.add_child(dl)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	for sl in action.get("slots", []):
		var sb := SlotBox.new(sl)
		slot_boxes.append(sb)
		row.add_child(sb)
	v.add_child(row)
	who_l = Label.new()
	who_l.theme_type_variation = "Hand"
	who_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	who_l.custom_minimum_size.x = 500
	who_l.add_theme_color_override("font_color", Color("2d3a5a"))
	v.add_child(who_l)
	var cost := Rules.cost_of(action, Game.state)
	var cl := Label.new()
	cl.theme_type_variation = "InkSoft"
	cl.text = "Почти не займёт времени." if cost == 0 else ("Займёт " + {1: "часть дня", 2: "полдня", 3: "почти весь день"}.get(cost, "весь день") + "  " + "◷".repeat(cost))
	v.add_child(cl)
	reason_l = Label.new()
	reason_l.theme_type_variation = "Ink"
	reason_l.add_theme_color_override("font_color", Look.BAD)
	reason_l.add_theme_font_size_override("font_size", 16)
	v.add_child(reason_l)
	var br := HBoxContainer.new()
	br.alignment = BoxContainer.ALIGNMENT_END
	br.add_theme_constant_override("separation", 12)
	var cancel := Button.new()
	cancel.theme_type_variation = "InkButton"
	cancel.text = "Отложить"
	cancel.pressed.connect(func():
		cancelled.emit())
	do_btn = Button.new()
	do_btn.text = "Сделать"
	do_btn.pressed.connect(func():
		confirmed.emit(slots()))
	br.add_child(cancel)
	br.add_child(do_btn)
	v.add_child(br)
	refresh()


func slots() -> Dictionary:
	var out := {}
	for sb in slot_boxes:
		out[sb.slot["id"]] = sb.card.id if sb.card else null
	return out


func ctx() -> Dictionary:
	return Rules.action_ctx(action, where, slots())


func accepts(sb: SlotBox, card_id: String) -> bool:
	return Rules.slot_accepts(sb.slot, card_id, Game.state, ctx())


func slot_under(gp: Vector2, card_id: String) -> SlotBox:
	for sb in slot_boxes:
		if sb.drop_rect().has_point(gp) and accepts(sb, card_id):
			return sb
	return null


func first_free_for(card_id: String) -> SlotBox:
	for sb in slot_boxes:
		if sb.card == null and accepts(sb, card_id):
			return sb
	return null


func slot_of(card: TableCard) -> SlotBox:
	for sb in slot_boxes:
		if sb.card == card:
			return sb
	return null


func refresh() -> void:
	if reason_l == null:
		return
	_refresh_who()
	var check := Rules.can_do(action, Game.state, ctx())
	do_btn.disabled = not check["ok"]
	reason_l.text = "" if check["ok"] else str(check["reason"])
	var empty_slots := false
	for sb in slot_boxes:
		if sb.card == null:
			empty_slots = true
	if empty_slots and slot_boxes.size() > 0:
		var any := false
		for sb in slot_boxes:
			if sb.card == null and Rules.slot_candidates(sb.slot, Game.state, ctx()).size() > 0:
				any = true
		if not any and not check["ok"]:
			reason_l.text = str(check["reason"]) + " Подходящих карт на столе нет."


## Для ячеек «кто рядом» подсказка: кого сюда можно положить прямо сейчас.
func _refresh_who() -> void:
	if who_l == null:
		return
	var lines := PackedStringArray()
	for sb in slot_boxes:
		if not sb.slot.get("present", false) or sb.card != null:
			continue
		var names := PackedStringArray()
		for id in Rules.slot_candidates(sb.slot, Game.state, ctx()):
			names.append(Rules.title_of(id, Game.state))
		if names.is_empty():
			lines.append("Здесь сейчас никого нет. Люди бывают в разных местах в разное время: смотрите на портреты на открытке места.")
		else:
			lines.append("%s: здесь сейчас %s. Щёлкните по портрету на столе или перетащите его сюда." % [str(sb.slot.get("label", "")), ", ".join(names)])
	who_l.text = "
".join(lines)
	who_l.visible = lines.size() > 0
