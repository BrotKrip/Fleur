extends Node
## Оркестратор: состояние партии, переключение режимов (меню / стол / VN / активности),
## сохранения и настройки.

const SAVE_DIR := "user://saves"
const SLOTS := ["auto", "1", "2", "3", "4", "5"]
const SETTINGS_PATH := "user://settings.cfg"
const VOLUME_BUSES := {"volume": "Master", "music_volume": "Music", "ambience_volume": "Ambience", "effects_volume": "Effects"}

const ACTIVITY_SCRIPTS := {
	"harpoon": "res://scenes/activities/harpoon.gd",
	"duel": "res://scenes/activities/duel.gd",
}

var state: Dictionary = {}
var mode := "menu"
var main: Node = null  # корневой Main, выставляет себя в _ready

var settings := {
	"text_speed": 45,      # символов в секунду, 0 — мгновенно
	"fullscreen": false,
	"autosave": true,
	"volume": 0.7,
	"music_volume": 1.0,
	"ambience_volume": 1.0,
	"effects_volume": 1.0,
	"hints": true,
	"adult_content": true,
}

## Изменения, которые надо показать на столе после возвращения из VN/активности.
var pending_return: Dictionary = {}


func _ready() -> void:
	load_settings()


# ---------------------------------------------------------------- режимы

func show_menu() -> void:
	mode = "menu"
	main.swap(load("res://scenes/menu/main_menu.gd").new())


func new_game() -> void:
	state = Rules.new_state()
	var first: Dictionary = state["queue"][0] if state["queue"].size() > 0 else {}
	if first.get("type") == "scene":
		state["queue"].pop_front()
		enter_scene(first["id"], first.get("ctx", {}))
	else:
		to_table({"title": "День первый"})


func to_table(opts: Dictionary = {}) -> void:
	mode = "table"
	main.swap(load("res://scenes/table/table_screen.gd").new(), opts.get("title", ""))


func enter_scene(id: String, ctx: Dictionary, history: Array = [], changes: Array = []) -> void:
	var scene: Dictionary = Content.scenes.get(id, {})
	if scene.is_empty():
		push_error("Нет сцены " + id)
		return
	mode = "vn"
	var vn = load("res://scenes/vn/vn_screen.gd").new()
	vn.setup(scene, ctx)
	vn.history = history
	vn.api["changes"].append_array(changes)
	main.swap(vn, "")


func finish_scene(changes: Array, continuation: String, history: Array) -> void:
	if not continuation.is_empty():
		var next := {"type": "scene", "id": continuation, "ctx": {}}
		if state["queue"].is_empty():
			next["history"] = history
			next["changes"] = changes
			# В сохранении следующая сцена ещё лежит в очереди.
			if settings["autosave"]:
				state["queue"].append(next)
				_write_slot("auto")
				state["queue"].pop_front()
			start_queue_item(next)
			return
		state["queue"].append(next)
	pending_return = {"title": "Что изменилось", "text": "", "changes": changes}
	to_table()


func enter_activity(q: Dictionary) -> void:
	var path: String = ACTIVITY_SCRIPTS.get(q["id"], "")
	if path.is_empty():
		push_error("Нет активности " + str(q["id"]))
		return
	mode = "activity"
	var act = load(path).new()
	act.setup(q.get("params", {}), q)
	main.swap(act, act.get_title())


func finish_activity(q: Dictionary, result: Dictionary, title: String) -> void:
	var api := Rules.new_api()
	var rule: Dictionary = Content.world.get("activity_results", {}).get(str(q.get("onResult", "")), {})
	for id in result.get("loot", []):
		Rules.add_card(state, id, {}, api)
	if result.get("outcome") == "lost":
		Rules.apply(rule.get("lost_effects"), state, {}, api)
	Rules.apply(result.get("effects"), state, {}, api)
	var tail: String = rule.get("texts", {}).get(result.get("outcome", ""), "")
	var parts := PackedStringArray()
	for p in [str(result.get("summary", "")), tail]:
		if p != "":
			parts.append(p)
	var text := "\n\n".join(parts)
	Rules.log_entry(state, title + ": " + (tail if tail != "" else str(result.get("summary", ""))), "action")
	pending_return = {"title": title, "text": text, "changes": api["changes"]}
	to_table()


## Следующий шаг потока после действия: уведомление, сцена/активность или ничего.
func next_flow_item() -> Dictionary:
	if state["notices"].size() > 0:
		return {"type": "notice", "data": state["notices"].pop_front()}
	if state["queue"].size() > 0:
		return state["queue"].pop_front()
	return {}


func start_queue_item(q: Dictionary) -> void:
	if q["type"] == "scene":
		enter_scene(q["id"], q.get("ctx", {}), q.get("history", []), q.get("changes", []))
	elif q["type"] == "activity":
		enter_activity(q)


# ---------------------------------------------------------------- действия

func do_action(action: Dictionary, where: String, slots: Dictionary) -> Dictionary:
	var ctx := Rules.action_ctx(action, where, slots)
	var check := Rules.can_do(action, state, ctx)
	if not check["ok"]:
		return {"error": check["reason"]}
	var api := Rules.new_api()
	Rules.mark_seen(state)
	var res := Rules.perform(action, state, ctx, api)
	res["changes"] = api["changes"]
	res["silent"] = action.get("silent", false) or res.get("silent", false)
	return res


func build_ended() -> bool:
	return not state.is_empty() and state["flags"].get("meropide_interval_done", false)


func wait_phase() -> Dictionary:
	var api := Rules.new_api()
	Rules.mark_seen(state)
	Rules.log_entry(state, "Флёр позволил времени идти своим чередом.", "action")
	Rules.advance(state, 1, api)
	return {"title": "Время идёт", "text": "", "changes": api["changes"]}


# ---------------------------------------------------------------- сохранения

func _slot_path(slot: String) -> String:
	return SAVE_DIR + "/" + slot + ".json"


func save_slot(slot: String) -> bool:
	if mode != "table" or state.is_empty():
		return false
	return _write_slot(slot)


func _write_slot(slot: String) -> bool:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var f := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({
		"version": Rules.SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"day": state["day"], "phase": state["phase"],
		"state": state,
	}))
	return true


func read_slot(slot: String) -> Dictionary:
	if not FileAccess.file_exists(_slot_path(slot)):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(_slot_path(slot)))
	if not (data is Dictionary):
		return {}
	if int(data.get("version", 0)) != Rules.SAVE_VERSION:
		data["incompatible"] = true
	return data


func delete_slot(slot: String) -> void:
	if FileAccess.file_exists(_slot_path(slot)):
		DirAccess.remove_absolute(_slot_path(slot))


func load_slot(slot: String) -> bool:
	var data := read_slot(slot)
	if data.is_empty() or data.get("incompatible", false):
		return false
	state = data["state"]
	# В старой версии этот флаг ставился в последней строке opera_release.
	if state["flags"].get("build_end", false) and not state["fired"].has("ev_sillage_open"):
		Rules.fire_event(state, "ev_sillage_open", Rules.new_api(), true)
	elif state["fired_at"].has("ev_sillage_open") and not state["counters"].has("day:sillage_open"):
		var opening_phase := int(state["fired_at"]["ev_sillage_open"])
		state["counters"]["day:sillage_open"] = 1 + floori(opening_phase / 4.0)
		# В прежнем разговоре Мелус уже назвал камеру и попросил найти Одиль.
		if state["flags"].get("sillage_lead", false) and not state["flags"].get("sillage_store", false):
			state["flags"]["sillage_old_directions"] = true
	Rules.mark_seen(state)
	to_table({"title": "День " + str(int(state["day"]))})
	return true


func latest_slot() -> String:
	var best := ""
	var best_time := ""
	for slot in SLOTS:
		var d := read_slot(slot)
		if d.is_empty() or d.get("incompatible", false):
			continue
		var t := FileAccess.get_modified_time(_slot_path(slot))
		if best == "" or str(t) > best_time:
			best = slot
			best_time = str(t)
	return best


func autosave() -> void:
	if settings["autosave"] and mode == "table" and not state.is_empty():
		save_slot("auto")


# ---------------------------------------------------------------- настройки

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		for k in settings:
			settings[k] = cfg.get_value("settings", k, settings[k])
	apply_settings()


func set_setting(key: String, value) -> void:
	settings[key] = value
	var cfg := ConfigFile.new()
	for k in settings:
		cfg.set_value("settings", k, settings[k])
	cfg.save(SETTINGS_PATH)
	apply_settings()


func apply_settings() -> void:
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if settings["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want and not (want == DisplayServer.WINDOW_MODE_WINDOWED and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED):
		DisplayServer.window_set_mode(want)
	for key in VOLUME_BUSES:
		var bus := AudioServer.get_bus_index(VOLUME_BUSES[key])
		var gain := clampf(float(settings[key]), 0.0, 1.0)
		AudioServer.set_bus_mute(bus, gain == 0.0)
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(gain, 0.0001)))
