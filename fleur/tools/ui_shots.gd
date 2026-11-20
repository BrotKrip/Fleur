extends Node
## Снимки интерфейса после правок по отзывам (для разработки).
## Запуск: Godot --path fleur -- --uishots=<папка>
## Стол в первый день (печати подходов и кнопки), лист разговора, настройки,
## курсивная реплика, спрятанная рамка, пропуск и смена эмоции. Партию не сохраняет.

var out := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--uishots="):
			out = a.substr(10)
	_go.call_deferred()


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("UISHOT ", name)


func wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _go() -> void:
	Game.settings["autosave"] = false
	await wait(0.8)
	Game.new_game()
	Game.state["queue"] = []
	Game.state["notices"] = []
	Game.to_table()
	for k in 30:
		await wait(0.1)
		if Game.main.has_overlay():
			Game.main.close_top_overlay()
	await wait(1.5)
	await shot("1_table_day1")
	var ts = Game.main.screen
	if "--deskonly" in OS.get_cmdline_user_args():
		# Только стол: обычный вид и общий план всего стола.
		ts.focus_rect(Rect2(Vector2.ZERO, ts.WORLD), 1.0, true)
		await wait(2.0)
		await shot("1b_table_overview")
		# Камера как у игрока: отдаление до упора, приближение и сдвиги к краям стола.
		var views := [["2a_zoom_min", ts.zoom_min(), ts.WORLD / 2.0], ["2b_zoom_max", ts.ZOOM_MAX, ts.WORLD / 2.0],
			["2c_pan_tl", 1.0, Vector2.ZERO], ["2d_pan_tr", 1.0, Vector2(ts.WORLD.x, 0)],
			["2e_pan_bl", 1.0, Vector2(0, ts.WORLD.y)], ["2f_pan_br", 1.0, ts.WORLD],
			["2g_max_tl", ts.ZOOM_MAX, Vector2.ZERO], ["2h_min_br", ts.zoom_min(), ts.WORLD]]
		for v in views:
			ts._user_cam_time = ts._clock
			ts.zoom_target = v[1]
			ts.cam_target = v[2]
			ts._anchored = false
			ts._clamp_camera()
			await wait(1.6)
			await shot(v[0])
		# Переезд из левого верхнего угла в правый нижний с отдалением: кадры на ходу.
		ts.zoom_target = ts.ZOOM_MAX
		ts.cam_target = Vector2.ZERO
		ts._clamp_camera()
		await wait(1.6)
		ts.zoom_target = ts.zoom_min()
		ts.cam_target = ts.WORLD
		ts._smooth = 0.55
		ts._clamp_camera()
		for k in 3:
			await wait(0.18)
			await shot("3_motion_%d" % k)
		ts._home_camera(true)
		# Вечер.
		Game.state["phase"] = 2
		ts._apply_light(true)
		ts.focus_rect(Rect2(0, 760, 900, 520), 1.0, true)
		await wait(2.0)
		await shot("1c_table_evening")
		get_tree().quit()
		return
	# Разговор в «Лютесе»: собеседник рядом один — ложится в ячейку сам.
	ts._travel("loc_lutes")
	await wait(0.4)
	ts._choose_action(Content.actions["talk"], "loc_lutes")
	await wait(1.0)
	await shot("2_talk_sheet")
	print("UISHOT talk who=", ts.sheet.slots().get("who"))
	ts._close_sheet()
	Dialogs.settings()
	await wait(0.6)
	await shot("3_settings")
	Game.main.close_all_overlays()
	# Сцена: курсив с «Д» в начале строки, затем спрятанная рамка, затем пропуск.
	Game.settings["text_speed"] = 0
	Game.enter_scene("adele_arrival", {})
	await wait(1.5)
	var vn = Game.main.screen
	var mood_shot := false
	for k in 400:
		if "Дома её" in vn.text_label.text:
			break
		if vn.waiting == "choice":
			(vn.choices.get_child(0) as Button).emit_signal("pressed")
		else:
			var figure: VNFigure = vn.figures.values()[0] if not vn.figures.is_empty() else null
			var previous: Texture2D = figure.portrait if figure else null
			vn._advance()
			if not mood_shot and is_instance_valid(figure) and previous != null and figure.portrait != previous:
				mood_shot = true
				await shot("4_mood_change")
		await get_tree().process_frame
	await wait(0.4)
	await shot("5_italic_line")
	vn._toggle_ui()
	await wait(0.3)
	await shot("6_ui_hidden")
	vn._toggle_ui()
	vn.skip_button.button_pressed = true
	vn._toggle_skip()
	await wait(0.5)
	await shot("7_skipping")
	# Поединок: рука приёмов после вступления (длинные названия в шапке карты).
	if is_instance_valid(vn):
		vn.skip_button.button_pressed = false
		vn._toggle_skip()
	Game.main.close_all_overlays()
	await wait(0.6)
	while Game.main._busy:
		await wait(0.1)
	Game.enter_activity({"id": "duel", "params": {"duel": "lamotte_honor"}})
	for k in 60:
		await wait(0.1)
		if "duel_id" in Game.main.screen:
			break
	await wait(2.6)   # заголовок на затемнении успевает погаснуть
	var duel = Game.main.screen
	await shot("8_duel_intro")
	if duel.overlay:
		duel.overlay.queue_free()
		duel.overlay = null
	duel._begin()
	await wait(2.5)
	await shot("9_duel_hand")
	print("UISHOT done")
	get_tree().quit()
