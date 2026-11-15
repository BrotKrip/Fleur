extends Control
## Галерея базы персонажей (для разработки): все VN-фигуры сеткой, спрайты и плейсхолдеры.
## Запуск: Godot --path fleur -- --gallery[=<папка для скриншотов>]
## Колёсико — прокрутка, Esc — выход. С папкой сохраняет снимки страниц и закрывается.

const CELL := Vector2(210, 330)
var out_dir := ""
var holder: Control


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--gallery="):
			out_dir = a.substr(10)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("1a1612")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	holder = Control.new()
	add_child(holder)
	var ids: Array = Content.characters.keys()
	ids.sort_custom(func(a, b): return _order(a) < _order(b))
	var cols := int(get_viewport_rect().size.x / CELL.x)
	for k in ids.size():
		var pid: String = ids[k]
		var pos := Vector2(k % cols, k / cols) * CELL + Vector2(10, 10)
		var f := VNFigure.new()
		f.setup(pid)
		f.base_scale = 0.43
		f.position = pos + Vector2(CELL.x / 2 - 210, CELL.y - 60 - 640)
		holder.add_child(f)
		var l := Label.new()
		var d := Content.def(pid)
		l.text = "%s\n%s%s" % [Rules.txt(d.get("title"), {"flags": {}, "cards": {}, "rel": {}, "counters": {}, "whereabouts": {}, "day": 1, "phase": 0}), pid, "" if Art.portrait(pid) else "  ·  заготовка"]
		l.position = pos + Vector2(0, CELL.y - 54)
		l.size = Vector2(CELL.x - 10, 40)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 13)
		holder.add_child(l)
	if out_dir != "":
		_capture.call_deferred(ceili(float(ids.size()) / cols))


func _order(pid: String) -> String:
	var role := str(Content.def(pid).get("role", "main"))
	return {"main": "0", "family": "1", "major": "2", "secondary": "3", "episodic": "4"}.get(role, "5") + pid


func _capture(rows: int) -> void:
	if DirAccess.make_dir_recursive_absolute(out_dir) != OK:
		push_error("Не удалось создать папку галереи: " + out_dir)
		get_tree().quit(1)
		return
	var page_h := get_viewport_rect().size.y
	# Каждая фигура попадает на страницу целиком, а не разрезается границей снимков.
	var rows_per_page := maxi(1, floori(page_h / CELL.y))
	var page_span := rows_per_page * CELL.y
	var pages := ceili(float(rows) / rows_per_page)
	if page_span < page_h:
		var margin := ColorRect.new()
		margin.color = Color("1a1612")
		margin.position = Vector2(0, page_span)
		margin.size = Vector2(get_viewport_rect().size.x, page_h - page_span)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(margin)
	await get_tree().create_timer(1.0).timeout
	for p in pages:
		holder.position.y = -p * page_span
		await get_tree().create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		var path := out_dir.path_join("gallery_%d.png" % p)
		if get_viewport().get_texture().get_image().save_png(path) != OK:
			push_error("Не удалось записать галерею: " + path)
			get_tree().quit(1)
			return
	print("GALLERY OK: ", pages, " pages")
	get_tree().quit()


func _input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			holder.position.y -= 60
		elif e.button_index == MOUSE_BUTTON_WHEEL_UP:
			holder.position.y = minf(0, holder.position.y + 60)
	elif e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		get_tree().quit()
