extends Node
## Автопрогон первой части через настоящий интерфейс (для разработки).
## Запуск: Godot --path fleur -- --smoke=<папка для скриншотов>
## Проходит сюжет от пролога до склада: стол, путешествия, сцены, выборы, письма, сохранение.

var out_dir := ""
var step := 0
var choice_plan := {}   # id сцены -> индексы выборов по порядку
var test_slot := "smoke_" + str(Time.get_ticks_usec())


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--smoke="):
			out_dir = a.substr(8)
	_run.call_deferred()


func shot(name: String) -> void:
	if out_dir == "":
		return
	# Дождаться прилёта новых карточек, чтобы снимок показывал итоговую раскладку.
	await wait(0.9)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("%02d_%s.png" % [step, name]))
	step += 1


func wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func fail(what: String) -> void:
	print("SMOKE FAIL: ", what, " | mode=", Game.mode, " day=", Game.state.get("day"), " phase=", Game.state.get("phase"))
	get_tree().quit(1)


func expect(cond: bool, what: String) -> void:
	if not cond:
		fail(what)


## Ждёт стол, закрывая листы-итоги и проигрывая сцены.
func settle() -> void:
	for k in 600:
		await wait(0.05)
		if Game.main._busy:
			continue
		if Game.main.has_overlay():
			Game.main.close_top_overlay()
			continue
		if Game.mode == "vn":
			await play_scene()
			continue
		if Game.mode == "table":
			await wait(0.25)
			if not Game.main.has_overlay() and not Game.main._busy and Game.mode == "table":
				return
	fail("не дождались стола")


func play_scene() -> void:
	var vn = Game.main.screen
	var sid: String = str(vn.scene.get("id", ""))
	var plan: Array = choice_plan.get(sid, [])
	var shot_done := false
	for k in 800:
		if Game.mode != "vn" or Game.main.screen != vn:
			return
		if vn.waiting == "choice":
			await wait(0.75)
			if not shot_done:
				await shot("vn_" + sid)
				shot_done = true
			var idx: int = plan.pop_front() if plan.size() > 0 else 0
			idx = mini(idx, vn.choices.get_child_count() - 1)
			(vn.choices.get_child(idx) as Button).emit_signal("pressed")
		elif vn.waiting == "click":
			vn._advance()
			vn._advance()
		await wait(0.01)


func table():
	return Game.main.screen


func act(id: String, where: String) -> void:
	table()._travel(where)
	await wait(0.2)
	table()._choose_action(Content.actions[id], where)
	await settle()


func pass_time(to_phase: int) -> void:
	for k in 8:
		if int(Game.state["phase"]) == to_phase:
			return
		table()._on_wait()
		await settle()


func sleep_night() -> void:
	table()._travel("loc_apartment")
	if int(Game.state["phase"]) < 2:
		await pass_time(2)
	table()._choose_action(Content.actions["sleep"], "loc_apartment")
	await settle()


func _run() -> void:
	# Автопрогон не должен перезаписывать сохранения игрока.
	Game.settings["autosave"] = false
	choice_plan = {
		"charlotte_first": [0],
		"josie_arrives": [0],
		"debor_bar": [0],
		"reception": [0, 0, 0, 0],
		"warehouse": [2, 0, 0],
	}
	await wait(1.6)
	await shot("menu")
	Game.new_game()
	await wait(3.2)
	await shot("prologue")
	await settle()
	await shot("table_day1")
	expect(Game.state["cards"].has("it_crate") and Game.state["cards"].has("letter_mother"), "ящик и письмо")

	await act("clorinde_sit", "loc_lutes")
	expect(Game.state["flags"].has("clorinde_met"), "сцена с Клориндой")
	await act("take_bottle", "loc_apartment")

	table()._travel("loc_vasari")
	await wait(0.3)
	await shot("spread_vasari")
	await act("approach_charlotte", "loc_vasari")
	expect(Game.state["flags"].has("met_charlotte"), "знакомство с Шарлоттой")
	await shot("table_after_charlotte")
	await act("tiori_order", "loc_tiori")

	await sleep_night()
	expect(int(Game.state["day"]) == 2, "день 2")
	expect(Game.state["cards"].has("info_harvest"), "Жози про урожай")
	await shot("table_day2")
	await act("coffee", "loc_lutes")
	expect(Game.state["cards"].has("rum_verdier"), "слух про мадам Вердье")

	await pass_time(2)
	await act("debor_bar_meet", "loc_debor")
	expect(Game.state["flags"].has("bar_done"), "бар")
	await sleep_night()
	expect(int(Game.state["day"]) == 3, "день 3")
	await pass_time(2)
	await act("josie_dinner_first", "loc_apartment")
	expect(Game.state["flags"].has("josie_dinner_done"), "ужин с Жози")
	await sleep_night()
	expect(int(Game.state["day"]) == 4, "день 4")
	expect(Game.state["cards"].has("it_coat"), "камзол от Тиори")

	expect(Game.save_slot(test_slot), "сохранение")
	await pass_time(2)
	await act("reception", "loc_debor")
	expect(Game.state["flags"].has("reception_done"), "приём")
	expect(Game.state["flags"].has("warehouse_ready"), "склад открыт")
	await shot("table_after_reception")

	await pass_time(3)
	await act("warehouse", "loc_docks")
	expect(Game.state["flags"].has("slice_done"), "склад")
	await shot("table_after_warehouse")
	await sleep_night()
	expect(Game.state["fired"].has("ev_slice_end"), "эпилог")
	await shot("table_epilogue")

	expect(Game.load_slot(test_slot), "загрузка")
	await settle()
	expect(int(Game.state["day"]) == 4, "загружен четверг")
	Dialogs.pause()
	await shot("pause")
	expect(Game.main.has_overlay(), "меню паузы")
	Game.main.close_all_overlays()
	await wait(0.1)
	Dialogs.settings()
	await shot("settings")
	Game.main.close_all_overlays()
	Game.delete_slot(test_slot)
	print("SMOKE OK")
	get_tree().quit(0)
