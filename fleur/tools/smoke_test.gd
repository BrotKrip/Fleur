extends Node
## Автопрогон первого акта через настоящий интерфейс (для разработки).
## Запуск: Godot --path fleur -- --smoke=<папка для скриншотов>
## Сначала — разговор через лист (собеседник + тема + подход), потом сюжет «жадным игроком»:
## любое доступное сюжетное действие, иначе разговор, который открывает сцену, иначе время идёт.
## В конце — сохранение, загрузка, пауза, настройки.

var out_dir := ""
var step := 0
var choice_plan := {}   # id сцены -> индексы выборов по порядку
var test_slot := "smoke_" + str(Time.get_ticks_usec())
var trace := PackedStringArray()

## Действия, которые повторяются бесконечно или не двигают сюжет.
const SKIP := ["talk", "josie_dinner_repeat", "ask_eye_note", "hunt", "sleep", "file_case", "give_article"]
## Шаги, которые теперь идут через разговор: [собеседник, тема, флаг «уже сделано»].
const TALK_STEPS := [
	["char_louis", "info_samples", "louis_talk_done"],
]
var case_shot := false


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
	print("SMOKE TRACE:\n  ", "\n  ".join(trace.slice(maxi(0, trace.size() - 25))))
	print("SMOKE FAIL: ", what, " | mode=", Game.mode, " day=", Game.state.get("day"), " phase=", Game.state.get("phase"))
	get_tree().quit(1)


func expect(cond: bool, what: String) -> void:
	if not cond:
		fail(what)


func stamp() -> String:
	return "д%s/%s" % [Game.state["day"], Rules.PHASE_KEYS[int(Game.state["phase"])]]


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
		if Game.mode == "activity" and "eng" in Game.main.screen:
			await play_duel()
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
	trace.append(stamp() + " сцена " + sid)
	for k in 800:
		if Game.mode != "vn" or Game.main.screen != vn:
			return
		if vn.waiting == "choice":
			await wait(0.75)
			if not shot_done:
				await shot("vn_" + sid)
				shot_done = true
			var live: Array = []
			for b in vn.choices.get_children():
				if b is Button and not b.disabled and not b.is_queued_for_deletion():
					live.append(b)
			if live.is_empty():
				fail("в сцене %s нет доступных вариантов" % sid)
				return
			var idx: int = plan.pop_front() if plan.size() > 0 else 0
			(live[mini(idx, live.size() - 1)] as Button).emit_signal("pressed")
		elif vn.waiting == "click":
			vn._advance()
			vn._advance()
		await wait(0.01)


var duel_shots := {}


## Поединок через настоящий экран: «разумный игрок» из tools/duel_sim.gd жмёт за нас.
func play_duel(prefer := "") -> Dictionary:
	var scr = Game.main.screen
	var did: String = scr.duel_id
	trace.append("%s поединок %s" % [stamp(), did])
	await wait(0.6)
	if not duel_shots.has(did):
		await shot("duel_intro_" + did)
	if scr.overlay:
		scr.overlay.queue_free()
		scr.overlay = null
	var sim = load("res://tools/duel_sim.gd")
	var first: bool = not duel_shots.has(did)
	if first:
		# один ход целиком через анимации: раздача, полёт карты, ход противника
		scr._begin()
		await wait(1.6)
		await shot("duel_hand_" + did)
		for c in scr.eng.hand:
			if scr.eng.can_play(c) and scr.eng.needs_target(c):
				scr._play(c["uid"])
				await wait(0.42)
				await shot("duel_strike_" + did)
				break
		for k in 60:
			if not scr._busy:
				break
			await wait(0.1)
		if scr.eng.result.is_empty():
			scr._end_turn()
			await wait(1.05)
			await shot("duel_enemy_turn_" + did)
			for k in 80:
				if not scr._busy:
					break
				await wait(0.1)
	var open_shot := false
	for k in 40:
		if not scr.eng.result.is_empty():
			break
		if scr.eng.any_open() and not open_shot and first:
			# решающий приём через кинематографичную развязку
			open_shot = true
			var fs: Array = scr.eng.finishers()
			if fs.size() > 0:
				var pick: String = fs[0]["id"]
				for f in fs:
					if f["id"] == prefer:
						pick = prefer
				scr._refresh()
				await shot("duel_open_" + did)
				scr.eng.finish_with(pick, scr._open_target())
				scr._playback()
				await wait(0.75)
				await shot("duel_finisher_" + did)
				await wait(2.4)
				continue
		sim.ai_turn(scr.eng, prefer, first and not open_shot)
		scr._after_action()
		await wait(0.12)
	expect(not scr.eng.result.is_empty(), "поединок %s не закончился" % did)
	await wait(0.5)
	if not duel_shots.has(did):
		await shot("duel_end_" + did)
	duel_shots[did] = true
	var payload: Dictionary = scr.outcome_payload()
	trace.append("%s поединок %s: %s" % [stamp(), did, payload["outcome"]])
	Game.finish_activity(scr.q, payload, scr.get_title())
	await wait(1.0)
	return payload


func table():
	return Game.main.screen


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


func locations() -> Array:
	var out := []
	for id in Game.state["cards"]:
		if Rules.is_location(id):
			out.append(id)
	return out


## Любое доступное сюжетное действие где угодно на карте.
func try_story(done_count: Dictionary) -> bool:
	var s: Dictionary = Game.state
	for loc in locations():
		for a in Rules.actions_for(s, loc):
			var id: String = a["id"]
			if SKIP.has(id) or a.get("visible") == null or int(done_count.get(id, 0)) >= 2:
				continue
			var slots := {}
			for sl in a.get("slots", []):
				var cands := Rules.slot_candidates(sl, s, Rules.action_ctx(a, loc, slots))
				if cands.size() > 0:
					slots[sl["id"]] = cands[0]
			if not Rules.can_do(a, s, Rules.action_ctx(a, loc, slots))["ok"]:
				continue
			done_count[id] = int(done_count.get(id, 0)) + 1
			trace.append("%s %s @ %s %s" % [stamp(), id, loc, JSON.stringify(slots) if slots.size() > 0 else ""])
			table()._travel(loc)
			await wait(0.2)
			table()._after(Game.do_action(a, loc, slots))
			await settle()
			return true
	return false


## Разговор, который открывает сюжетную сцену (бывшие билеты).
func try_talks() -> bool:
	var s: Dictionary = Game.state
	var a: Dictionary = Content.actions["talk"]
	for p in TALK_STEPS:
		if s["flags"].get(p[2], false) or not s["cards"].has(p[0]) or not s["cards"].has(p[1]):
			continue
		var where = Rules.where_is(s, p[0])
		if where == null:
			continue
		var slots := {"who": p[0], "topic": p[1]}
		var r := Rules.resolve_talk(s, Rules.action_ctx(a, where, slots))
		if not r["entry"].has("scene"):
			continue
		trace.append("%s разговор %s + %s @ %s" % [stamp(), p[0], p[1], where])
		table()._travel(where)
		await wait(0.2)
		table()._after(Game.do_action(a, where, slots))
		await settle()
		expect(s["flags"].get(p[2], false), "разговор %s + %s не открыл сцену" % [p[0], p[1]])
		return true
	return false


## Подшить в дело всё, что к нему относится (первый раз — через бросок на папку и лист).
func try_file() -> bool:
	var s: Dictionary = Game.state
	var a: Dictionary = Content.actions["file_case"]
	if not Rules.test(a.get("visible"), s, Rules.action_ctx(a, "aff_nectar", {})):
		return false
	for ev in Content.def("aff_nectar").get("evidence", {}):
		if not s["cards"].has(ev) or s["flags"].get("filed:" + ev, false):
			continue
		var before := Rules.case_stage(s, "aff_nectar")
		trace.append("%s подшить %s (стадия %d)" % [stamp(), ev, before])
		if not case_shot:
			case_shot = true
			table()._file_into("aff_nectar", ev)
			await wait(0.4)
			expect(table().sheet != null, "лист «Подшить в дело» не открылся")
			await shot("case_sheet")
			table().sheet.confirmed.emit(table().sheet.slots())
			await wait(0.6)
			await shot("case_result")
		else:
			table()._after(Game.do_action(a, "aff_nectar", {"case": "aff_nectar", "evidence": ev}))
		await settle()
		expect(s["flags"].get("filed:" + ev, false), "не подшилось: " + ev)
		return true
	return false


## Обвинение: сначала ложное (дядя Марсель), потом верное. Только после разговора с отцом.
func try_accuse() -> bool:
	var s: Dictionary = Game.state
	var a: Dictionary = Content.actions["give_article"]
	if not s["flags"].get("father_talk_done", false) or s["flags"].get("first_arc_done", false):
		return false
	var where := "loc_steambird"
	if not Rules.test(a.get("visible"), s, Rules.action_ctx(a, where, {})):
		return false
	table()._travel(where)
	await wait(0.2)
	if not s["flags"].get("accuse_marcel_refused", false):
		trace.append("%s обвинение: Марсель + поставки" % stamp())
		table()._choose_action(a, where, {"case": "aff_nectar", "who": "char_marcel", "proof": "info_cabriera"})
		await wait(0.5)
		await shot("accuse_sheet")
		table().sheet.confirmed.emit(table().sheet.slots())
		await wait(0.6)
		await shot("accuse_refused")
		await settle()
		expect(s["flags"].get("accuse_marcel_refused", false) and not s["flags"].get("first_arc_done", false), "Шарлотта должна отказать в обвинении Марселя")
		return true
	trace.append("%s обвинение: отец + распоряжение" % stamp())
	table()._after(Game.do_action(a, where, {"case": "aff_nectar", "who": "char_adrian", "proof": "info_father_order"}))
	await settle()
	expect(s["flags"].get("first_arc_done", false), "верное обвинение должно закрыть дело")
	return true


## Разговор через лист: бросаем тему на портрет, кладём подход, подтверждаем.
func talk_ui(who: String, topic: String, approach: String) -> void:
	var s: Dictionary = Game.state
	for k in 6:
		if Rules.where_is(s, who) != null:
			break
		await pass_time((int(s["phase"]) + 1) % 4)
	var where = Rules.where_is(s, who)
	expect(where != null, who + " нигде не найти")
	table()._travel(where)
	await wait(0.3)
	table()._talk_with(who, topic)
	await wait(0.4)
	var sheet = table().sheet
	expect(sheet != null, "лист разговора не открылся")
	for sb in sheet.slot_boxes:
		if sb.slot["id"] == "approach":
			table()._put_in_slot(table().nodes[approach], sb)
	await shot("talk_sheet")
	trace.append("%s разговор (лист) %s + %s + %s" % [stamp(), who, topic, approach])
	sheet.confirmed.emit(sheet.slots())
	await wait(0.6)
	await shot("talk_result")
	await settle()


func _run() -> void:
	# Автопрогон не должен перезаписывать сохранения игрока.
	Game.settings["autosave"] = false
	await wait(1.6)
	await shot("menu")
	Game.new_game()
	await wait(3.2)
	await shot("prologue")
	await settle()
	await shot("table_day1")
	var s: Dictionary = Game.state
	expect(s["cards"].has("ap_charm") and s["cards"].has("ap_candor"), "карты подходов на столе")

	# Разговор с подходом: тема + манера, подход уходит на отдых.
	await talk_ui("arue", "sl_eye", "ap_purse")
	expect(s["rel"].get("arue", []).has("Свой человек"), "Аруэ реагирует на кошелёк")
	expect(Rules.is_resting(s, "ap_purse"), "кошелёк отдыхает после разговора")
	await shot("table_after_talk")

	# Первый акт целиком.
	var done_count := {}
	var saved := false
	for it in 500:
		if s["flags"].get("arc_epilogue_seen", false):
			break
		if not saved and s["flags"].get("louis_talk_done", false):
			expect(Game.save_slot(test_slot), "сохранение")
			saved = true
			await shot("table_after_louis")
		if await try_file():
			continue
		if await try_story(done_count):
			continue
		if await try_talks():
			continue
		if await try_accuse():
			continue
		if int(s["phase"]) == 3:
			await sleep_night()
		else:
			table()._on_wait()
			await settle()
		expect(int(s["day"]) < 40, "сюжет застрял")
	expect(Rules.case_stage(s, "aff_nectar") == 4, "дело дошло до последней стадии")
	expect(s["flags"].get("accused_adrian", false), "статья через обвинение")
	expect(not s["cards"].has("dl_article"), "срок снят после статьи")
	for f in ["louis_talk_done", "father_talk_done", "first_arc_done", "arc_epilogue_seen", "louis_warehouse_asked", "father_warehouse_asked"]:
		expect(s["flags"].get(f, false), "не дошли до " + f)
	for f in ["chevreuse_office_shared", "josie_arrived", "city_night_finished", "clorinde_button_night",
			"ledgers_read", "furina_sketch_ready", "furina_sketch_delivered", "article_seen"]:
		expect(s["flags"].get(f, false), "пропущен эпизод до расследования: " + f)
	await shot("table_epilogue")
	var used := PackedStringArray()
	for k in s["counters"]:
		if str(k).begins_with("used:"):
			used.append("%s×%s" % [str(k).substr(5), s["counters"][k]])
	print("SMOKE подходы: ", ", ".join(used))
	print("SMOKE поединки: тренировки ", s["counters"].get("duel:training", 0), ", честь ", s["counters"].get("duel:honor", 0), ", виконт: ", s["rel"].get("viscount", []))
	print("SMOKE финал: день ", s["day"], ", шагов ", trace.size())

	expect(saved, "сохранение было сделано")
	expect(Game.load_slot(test_slot), "загрузка")
	await settle()
	expect(Game.state["flags"].get("louis_talk_done", false) and not Game.state["flags"].get("father_talk_done", false), "загружено состояние после Луи-Марка")
	# Ветка срока: ничего не делать, пока номер не уйдёт в печать без Флёра.
	expect(Game.state["cards"].has("dl_article"), "срок номера на столе")
	await shot("deadline_card")
	for k in 40:
		if Game.state["flags"].get("first_arc_done", false):
			break
		if int(Game.state["phase"]) == 3:
			await sleep_night()
		else:
			table()._on_wait()
			await settle()
	expect(Game.state["flags"].get("article_without_fleur", false), "номер вышел без Флёра")
	expect(Game.state["rel"].get("char_adrian", []).has("Узнал из газеты"), "отец узнал из газеты")
	trace.append("%s срок истёк: статья без Флёра" % stamp())
	# Уличная схватка: двое противников, решающие приёмы выводят из боя по одному.
	Game.start_queue_item({"type": "activity", "id": "duel", "params": {"duel": "docks_street"}, "onResult": "duel"})
	await wait(1.6)
	expect(Game.mode == "activity", "уличная схватка открылась")
	var street := await play_duel()
	await settle()
	expect(int(Game.state["counters"].get("duel:street", 0)) == 1, "схватка засчитана в привычки")
	expect(street["outcome"] != "wound" or Game.state["cards"].has("st_wounded"), "рана после схватки")
	Dialogs.pause()
	await shot("pause")
	expect(Game.main.has_overlay(), "меню паузы")
	Game.main.close_all_overlays()
	await wait(0.1)
	Dialogs.settings()
	await shot("settings")
	Game.main.close_all_overlays()
	Game.delete_slot(test_slot)
	print("SMOKE TRACE:\n  ", "\n  ".join(trace))
	print("SMOKE OK")
	Game.main.quit_game()
