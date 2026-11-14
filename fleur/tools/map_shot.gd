extends Node
## Снимок карты города со всеми местами (для разработки).
## Запуск: Godot --path fleur -- --mapshot=<файл.png>
## Открывает все места, показывает стол и сохраняет вырезку с картой. Партию не сохраняет.
## --tableshot=<папка>: снимки всего стола — исходный вид, после «Прибрать стол» и общий план.

func _ready() -> void:
	_go.call_deferred()


func _go() -> void:
	var out := ""
	var table_dir := ""
	var vnline := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--vnline="):
			vnline = a.substr(9)
	if vnline != "":
		# --vnline=<сцена>|<кусок реплики>|<файл.png>: снимок окна диалога на этой реплике
		var parts := vnline.split("|")
		Game.settings["autosave"] = false
		Game.settings["text_speed"] = 0
		await get_tree().create_timer(0.8).timeout
		Game.new_game()
		Game.state["queue"] = []
		Game.enter_scene(parts[0], {})
		await get_tree().create_timer(1.5).timeout
		var vn = Game.main.screen
		for k in 400:
			if parts[1] in vn.text_label.text:
				break
			if vn.waiting == "choice":
				(vn.choices.get_child(0) as Button).emit_signal("pressed")
			else:
				vn._advance()
			await get_tree().process_frame
		await get_tree().create_timer(0.3).timeout
		var bar = vn.dialog_scroll.get_v_scroll_bar()
		print("VNLINE font=%d overflow=%s" % [vn.text_label.get_theme_font_size("font_size"), str(bar.max_value > bar.page + 1)])
		await _save_full(parts[2])
		get_tree().quit()
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mapshot="):
			out = a.substr(10)
		elif a.begins_with("--tableshot="):
			table_dir = a.substr(12)
	Game.settings["autosave"] = false
	await get_tree().create_timer(0.8).timeout
	Game.new_game()
	Game.state["queue"] = []
	Game.state["notices"] = []
	for id in Content.cards:
		if Rules.is_location(id) and not Game.state["cards"].has(id):
			Game.state["cards"][id] = {"id": id, "lifetime": null, "count": 1, "fresh": false}
	Game.to_table()
	for k in 40:
		await get_tree().create_timer(0.1).timeout
		if Game.main.has_overlay():
			Game.main.close_top_overlay()
	var ts = Game.main.screen
	if table_dir != "":
		for id in ["char_charlotte", "char_chevreuse", "char_navia", "char_emilie", "rum_verdier", "rum_nectar", "info_harvest", "info_witness", "aff_nectar", "it_city_sample", "dl_article", "it_cloth_owl", "st_tired"]:
			if Content.def(id).size() > 0:
				Game.state["cards"][id] = {"id": id, "lifetime": 20 if id == "dl_article" else null, "count": 1, "fresh": false}
		ts.sync_cards(true)
		await get_tree().create_timer(1.5).timeout
		await _save_full(table_dir.path_join("1_home.png"))
		ts._tidy()
		await get_tree().create_timer(2.0).timeout
		await _save_full(table_dir.path_join("2_tidy_overview.png"))
		# масштаб колесом к курсору: точка стола под курсором не должна уплывать
		ts._home_camera(true)
		var cursor := Vector2(400, 500)
		var before: Vector2 = ts.screen_to_world(cursor)
		for k in 4:
			ts._zoom_at(cursor, 1.1)
			await get_tree().create_timer(0.05).timeout
		await get_tree().create_timer(1.2).timeout
		print("ZOOMCHECK drift=%.2f zoom=%.3f" % [ts.screen_to_world(cursor).distance_to(before), ts.cam_zoom])
		ts._home_camera()
		ts.zoom_target = 1.3
		ts.cam_target = Vector2(640, 860)
		await get_tree().create_timer(1.5).timeout
		await _save_full(table_dir.path_join("3_close.png"))
		get_tree().quit()
		return
	var m = ts.map
	m.queue_redraw()
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var to_pixels: Transform2D = get_viewport().get_final_transform() * m.get_global_transform_with_canvas()
	var r := Rect2i(to_pixels * Rect2(Vector2.ZERO, m.size).grow(12))
	img = img.get_region(r.intersection(Rect2i(Vector2i.ZERO, img.get_size())))
	img.save_png(out)
	print("MAPSHOT ", out)
	get_tree().quit()


func _save_full(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("TABLESHOT ", path)
