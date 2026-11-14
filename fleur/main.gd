extends Control
## Корень игры: держит текущий экран, слой оверлеев (пауза, настройки, сохранения)
## и затемнение для переходов между режимами.

var screen_root: Control
var overlay_layer: CanvasLayer
var overlays: Control
var fader: ColorRect
var fade_title: Label
var screen: Control = null
var _busy := false


func _ready() -> void:
	get_tree().root.theme = Look.theme()
	get_tree().root.min_size = Vector2i(1024, 600)
	Game.main = self

	screen_root = Control.new()
	screen_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen_root)

	overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 50
	add_child(overlay_layer)
	overlays = Control.new()
	overlays.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlays.theme = Look.theme()
	overlay_layer.add_child(overlays)

	var fl := CanvasLayer.new()
	fl.layer = 100
	add_child(fl)
	fader = ColorRect.new()
	fader.color = Color(0.02, 0.02, 0.03, 1)
	fader.set_anchors_preset(Control.PRESET_FULL_RECT)
	fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fl.add_child(fader)
	fade_title = Label.new()
	fade_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fade_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fade_title.add_theme_font_override("font", Look.font("serif_italic"))
	fade_title.add_theme_font_size_override("font_size", 44)
	fade_title.add_theme_color_override("font_color", Color("e6d6a8"))
	fade_title.modulate.a = 0
	fl.add_child(fade_title)

	Game.show_menu()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--smoke"):
			add_child(load("res://tools/smoke_test.gd").new())
		elif a.begins_with("--gallery"):
			overlay_layer.add_child(load("res://tools/gallery.gd").new())


## Сменить экран через затемнение. title — короткая надпись на чёрном (например, название сцены).
func swap(new_screen: Control, title := "") -> void:
	_busy = true
	close_all_overlays()
	var tw := create_tween()
	fader.mouse_filter = Control.MOUSE_FILTER_STOP
	tw.tween_property(fader, "modulate:a", 1.0, 0.35 if screen else 0.0)
	await tw.finished
	if screen:
		screen.queue_free()
	screen = new_screen
	screen_root.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if title != "":
		fade_title.text = title
		var t2 := create_tween()
		t2.tween_property(fade_title, "modulate:a", 1.0, 0.4)
		t2.tween_interval(0.9)
		t2.tween_property(fade_title, "modulate:a", 0.0, 0.4)
		await t2.finished
	var t3 := create_tween()
	t3.tween_property(fader, "modulate:a", 0.0, 0.5)
	await t3.finished
	fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
	if screen and screen.has_method("on_shown"):
		screen.on_shown()


# ---------------------------------------------------------------- оверлеи

func open_overlay(node: Control) -> void:
	overlays.add_child(node)
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func close_top_overlay() -> bool:
	var n := overlays.get_child_count()
	if n == 0:
		return false
	var top := overlays.get_child(n - 1)
	if top.has_method("close"):
		top.close()
	else:
		top.queue_free()
	return true


func close_all_overlays() -> void:
	for c in overlays.get_children():
		c.queue_free()


func has_overlay() -> bool:
	for c in overlays.get_children():
		if not c.is_queued_for_deletion():
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if _busy:
			return
		if has_overlay():
			close_top_overlay()
		elif screen and screen.has_method("on_escape"):
			screen.on_escape()
