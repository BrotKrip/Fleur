class_name Sheet
extends Control
## Лист бумаги поверх затемнённого экрана. Основа для паузы, настроек, сохранений, журнала.

signal closed

var panel: PanelContainer
var body: VBoxContainer
var dismissable := true


func _init(width := 560.0, dim := 0.55) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.01, 0.0, dim)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.gui_input.connect(_on_bg_input)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	panel = PanelContainer.new()
	panel.theme_type_variation = "Paper"
	panel.custom_minimum_size = Vector2(width, 0)
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	panel.draw.connect(_draw_stationery)
	panel.resized.connect(func(): panel.queue_redraw())
	center.add_child(panel)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	panel.add_child(body)
	modulate.a = 0.0


func _ready() -> void:
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)


func _draw_stationery() -> void:
	var rect := Rect2(Vector2(2, 2), panel.size - Vector2(4, 4))
	Look.texture_polygon(panel, Look.rrect(rect, 2), Art.surface("paper"), 1.0, Color(1, 1, 1, 0.58))
	Look.engraved_corners(panel, rect.grow(-8), Color(0.48, 0.35, 0.16, 0.40), 15)


func _on_bg_input(e: InputEvent) -> void:
	if dismissable and e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		close()


func close() -> void:
	if is_queued_for_deletion():
		return
	closed.emit()
	queue_free()


# ---------------------------------------------------------------- помощники

func add_kicker(t: String) -> Label:
	var l := Label.new()
	l.text = t.to_upper()
	l.theme_type_variation = "Kicker"
	body.add_child(l)
	return l


func add_title(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.theme_type_variation = "InkTitle"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(l)
	return l


func add_text(t: String, variation := "Ink") -> Label:
	var l := Label.new()
	l.text = t
	l.theme_type_variation = variation
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 200
	body.add_child(l)
	return l


func add_rule() -> void:
	var r := ColorRect.new()
	r.color = Color(0.35, 0.27, 0.18, 0.3)
	r.custom_minimum_size = Vector2(0, 1)
	body.add_child(r)


func add_button(t: String, cb: Callable, variation := "InkButton") -> Button:
	var b := Button.new()
	b.text = t
	b.theme_type_variation = variation
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(cb)
	body.add_child(b)
	return b


func add_row(buttons: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	for b in buttons:
		row.add_child(b)
	body.add_child(row)
	return row


static func make_button(t: String, cb: Callable, variation := "") -> Button:
	var b := Button.new()
	b.text = t
	if variation != "":
		b.theme_type_variation = variation
	b.pressed.connect(cb)
	return b
