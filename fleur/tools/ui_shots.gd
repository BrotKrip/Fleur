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
			vn._advance()
			if not mood_shot and vn.figures.size() > 0:
				var f = vn.figures.values()[0]
				if f._blend < 1.0 and f._prev_portrait != null:
					mood_shot = true
					await wait(0.08)
					await shot("4_mood_midblend")
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
	print("UISHOT done")
	get_tree().quit()
