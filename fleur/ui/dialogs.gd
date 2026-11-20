class_name Dialogs
extends RefCounted
## Служебные окна: пауза, настройки, сохранение/загрузка, журнал, подтверждение.


static func _open(sh: Sheet) -> Sheet:
	Game.main.open_overlay(sh)
	return sh


static func pause() -> void:
	var sh := Sheet.new(420)
	sh.add_kicker("Пауза")
	sh.add_title("Послевкусие")
	sh.add_rule()
	sh.add_button("Вернуться к столу", sh.close)
	sh.add_button("Сохранить", func():
		sh.close()
		saves("save"))
	sh.add_button("Загрузить", func():
		sh.close()
		saves("load"))
	sh.add_button("Журнал", func():
		sh.close()
		journal())
	sh.add_button("Настройки", func():
		sh.close()
		settings())
	sh.add_button("Выйти в главное меню", func():
		sh.close()
		confirm("Выйти в главное меню? Прогресс сохранится в автосохранении.", func():
			Game.autosave()
			Game.show_menu()))
	sh.add_button("Выйти из игры", func():
		sh.close()
		confirm("Закрыть игру? Прогресс сохранится в автосохранении.", func():
			Game.autosave()
			Game.main.quit_game()))
	_open(sh)


static func confirm(text: String, on_yes: Callable) -> void:
	var sh := Sheet.new(460)
	sh.add_text(text)
	sh.add_row([
		Sheet.make_button("Нет", sh.close),
		Sheet.make_button("Да", func():
			sh.close()
			on_yes.call()),
	])
	_open(sh)


static func settings() -> void:
	var sh := Sheet.new(520)
	sh.add_kicker("Настройки")
	sh.add_title("Как удобнее")
	sh.add_rule()

	# Все ползунки — строки одной высоты: подпись слева, ползунок справа, ручка по центру дорожки.
	var slider_row := func(caption: String, slider: HSlider) -> Label:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var label := Label.new()
		label.theme_type_variation = "Ink"
		label.text = caption
		label.custom_minimum_size = Vector2(236, 30)   # по самой длинной подписи: ползунки встают в один столбец
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(label)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_FILL
		slider.custom_minimum_size.y = 30
		row.add_child(slider)
		sh.body.add_child(row)
		return label

	var speed_name := func(v):
		return "Текст: " + ("мгновенно" if int(v) == 0 else str(int(v)) + " зн./с")
	var sl := HSlider.new()
	sl.min_value = 0
	sl.max_value = 120
	sl.step = 5
	sl.value = float(Game.settings["text_speed"])
	var speed_lbl: Label = slider_row.call(speed_name.call(Game.settings["text_speed"]), sl)
	sl.value_changed.connect(func(v):
		Game.set_setting("text_speed", int(v))
		speed_lbl.text = speed_name.call(v))

	for pair in [["volume", "Общая громкость"], ["music_volume", "Музыка"], ["ambience_volume", "Атмосфера мест"], ["effects_volume", "Действия и интерфейс"]]:
		var slider := HSlider.new()
		slider.max_value = 1.0
		slider.step = 0.05
		var key: String = pair[0]
		slider.value = float(Game.settings[key])
		slider.value_changed.connect(func(v): Game.set_setting(key, v))
		slider_row.call(pair[1], slider)

	for pair in [["fullscreen", "Полноэкранный режим"], ["autosave", "Автосохранение"], ["hints", "Подсказки на столе"]]:
		var cb := CheckBox.new()
		cb.text = pair[1]
		cb.button_pressed = bool(Game.settings[pair[0]])
		var key: String = pair[0]
		cb.toggled.connect(func(on): Game.set_setting(key, on))
		sh.body.add_child(cb)
	sh.add_row([Sheet.make_button("Готово", sh.close)])
	_open(sh)


static func saves(mode: String) -> void:
	var sh := Sheet.new(600)
	sh.add_kicker("Записи")
	sh.add_title("Сохранить партию" if mode == "save" else "Загрузить партию")
	sh.add_rule()
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	sh.body.add_child(list)
	var fns := {}
	fns["rebuild"] = func():
		for c in list.get_children():
			c.queue_free()
		for slot in Game.SLOTS:
			if mode == "save" and slot == "auto":
				continue
			var data := Game.read_slot(slot)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			var info := VBoxContainer.new()
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var name_l := Label.new()
			name_l.text = "Автосохранение" if slot == "auto" else "Запись " + slot
			name_l.theme_type_variation = "Ink"
			var desc := Label.new()
			desc.theme_type_variation = "InkSoft"
			if data.is_empty():
				desc.text = "пусто"
			elif data.get("incompatible", false):
				desc.text = "от старой версии игры"
			else:
				desc.text = "День %d, %s · %s" % [int(data["day"]), Rules.PHASES[int(data["phase"])].to_lower(), str(data.get("saved_at", "")).replace("T", " ")]
			info.add_child(name_l)
			info.add_child(desc)
			row.add_child(info)
			if mode == "save":
				row.add_child(Sheet.make_button("Перезаписать" if not data.is_empty() else "Сохранить", func():
					Game.save_slot(slot)
					fns["rebuild"].call()))
			else:
				var b := Sheet.make_button("Загрузить", func():
					sh.close()
					Game.load_slot(slot))
				b.disabled = data.is_empty() or data.get("incompatible", false)
				row.add_child(b)
			if not data.is_empty() and slot != "auto":
				row.add_child(Sheet.make_button("Стереть", func():
					Game.delete_slot(slot)
					fns["rebuild"].call(), "InkButton"))
			list.add_child(row)
	fns["rebuild"].call()
	if mode == "save" and Game.mode != "table":
		sh.add_text("Сохраняться можно только за столом.", "InkSoft")
	sh.add_row([Sheet.make_button("Закрыть", sh.close)])
	_open(sh)


static func journal() -> void:
	Sound.play("ui_page")
	var sh := Sheet.new(640)
	sh.add_kicker("Записная книжка")
	sh.add_title("Что было")
	sh.add_rule()
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 460)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	scroll.add_child(col)
	sh.body.add_child(scroll)
	var log: Array = Game.state.get("log", [])
	for i in range(log.size() - 1, -1, -1):
		var e: Dictionary = log[i]
		var l := Label.new()
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 560
		l.theme_type_variation = "InkSoft" if e.get("kind") in ["system", "expire"] else "Ink"
		l.add_theme_font_size_override("font_size", 16)
		l.text = "День %d, %s. %s" % [int(e["day"]), Rules.PHASES[int(e["phase"])].to_lower(), e["text"]]
		col.add_child(l)
	sh.add_row([Sheet.make_button("Закрыть", sh.close)])
	_open(sh)
