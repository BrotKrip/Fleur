extends Node
## Реестр контента. Всё игровое содержимое лежит в res://data/*.json и редактируется без правки кода.

var cards: Dictionary = {}
var characters: Dictionary = {}
var actions: Dictionary = {}
var events: Dictionary = {}
var scenes: Dictionary = {}
var world: Dictionary = {}
var soundscapes: Dictionary = {}
var talk: Dictionary = {}
var duel: Dictionary = {}


func _init() -> void:
	cards = _load_json("res://data/cards.json")
	characters = _load_json("res://data/characters.json")
	# База персонажей: data/characters/*.json дополняет основной состав.
	# Персонаж появляется на столе, только когда его карту добавят в партию.
	var cdir := DirAccess.open("res://data/characters")
	if cdir:
		for f in cdir.get_files():
			if f.ends_with(".json"):
				var extra := _load_json("res://data/characters/" + f)
				for cid in extra:
					if characters.has(cid):
						push_warning("Персонаж %s описан дважды (%s)" % [cid, f])
					else:
						characters[cid] = extra[cid]
	actions = _load_json("res://data/actions.json")
	events = _load_json("res://data/events.json")
	world = _load_json("res://data/world.json")
	soundscapes = _load_json("res://data/soundscapes.json")
	if FileAccess.file_exists("res://data/talk.json"):
		talk = _load_json("res://data/talk.json")
	if FileAccess.file_exists("res://data/duel.json"):
		duel = _load_json("res://data/duel.json")
	for table in [cards, characters, actions, events]:
		for id in table:
			table[id]["id"] = id
	var dir := DirAccess.open("res://data/scenes")
	if dir:
		for f in dir.get_files():
			if f.ends_with(".json"):
				var sc: Dictionary = _load_json("res://data/scenes/" + f)
				scenes[sc.get("id", f.get_basename())] = sc
			elif f.ends_with(".scene"):
				var sc2 := parse_scene(FileAccess.get_file_as_string("res://data/scenes/" + f), f)
				scenes[sc2.get("id", f.get_basename())] = sc2


func _load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Не удалось прочитать " + path)
		return {}
	var data = JSON.parse_string(text)
	if data == null or not (data is Dictionary):
		push_error("Ошибка JSON в " + path)
		return {}
	return data


## Определение карты или человека по id.
func def(id: String) -> Dictionary:
	if cards.has(id):
		return cards[id]
	if characters.has(id):
		return characters[id]
	return {}


func background(id: String) -> Dictionary:
	return world.get("backgrounds", {}).get(id, {})


func figure_lighting(id: String, phase: String, shot_profile := "") -> Dictionary:
	var profiles: Dictionary = world.get("figure_lighting", {})
	if profiles.has(shot_profile):
		return profiles[shot_profile]
	var fallback := "day" if phase == "morning" else phase
	var setting = background(id).get("lighting", fallback)
	if setting is Dictionary:
		setting = setting.get(phase, setting.get("day", fallback))
	return profiles.get(setting, profiles.get(fallback, {}))


## Текстовый формат сцен (data/scenes/*.scene) — чтобы сцены можно было писать как прозу.
##   @id имя / @after следующая_сцена
##   @bg имя [профиль_света] / @show id [left|center|right] / @hide id
##   @label имя / @goto имя / @if {условие JSON} -> имя / @do [эффекты JSON] / @end
##   N: текст                      — повествование
##   кто: текст                    — реплика (fleur, char_..., или говорящий из world.json)
##   кто [эмоция]: текст           — реплика со сменой эмоции (держится, пока не сменят)
##   @show id [место] [эмоция] / @mood id эмоция — выход с эмоцией / смена без реплики
##   @choice, затем строки «- метка | текст», под ними «  ? {условие}», «  ! [эффекты]»
##   и «  ~ ap_charm» — вариант требует подхода Флёра (карта должна быть готова) и тратит его
## «кто [эмоция]: текст»
static var _MOOD_LINE: RegEx = RegEx.create_from_string(r"^([A-Za-z_][A-Za-z0-9_]*)\s*\[([^\]]+)\]\s*:\s(.*)$")


func parse_scene(text: String, fname := "") -> Dictionary:
	var sc := {"id": fname.get_basename(), "nodes": []}
	var nodes: Array = sc["nodes"]
	var cur_choice = null
	var cur_opt = null
	var ln := 0
	for raw in text.split(String.chr(10)):
		ln += 1
		var line := raw.strip_edges(false, true)
		var s := line.strip_edges()
		if s == "" or s.begins_with("#"):
			continue
		if cur_opt != null and s.begins_with("~ "):
			cur_opt["ap"] = s.substr(2).strip_edges()
			continue
		if cur_opt != null and (s.begins_with("? ") or s.begins_with("! ")):
			var j = JSON.parse_string(s.substr(2))
			if j == null:
				push_error("%s:%d — ошибка JSON" % [fname, ln])
			elif s.begins_with("?"):
				cur_opt["when"] = j
			else:
				cur_opt["effects"] = j
			continue
		if cur_choice != null and s.begins_with("- "):
			var body := s.substr(2)
			var bar := body.find("|")
			cur_opt = {"goto": body.substr(0, bar).strip_edges(), "t": body.substr(bar + 1).strip_edges()}
			cur_choice["choice"].append(cur_opt)
			continue
		cur_choice = null
		cur_opt = null
		if s.begins_with("@"):
			var sp := s.find(" ")
			var cmd := s.substr(1) if sp < 0 else s.substr(1, sp - 1)
			var arg := "" if sp < 0 else s.substr(sp + 1).strip_edges()
			match cmd:
				"id", "title", "after", "music":
					sc[cmd] = arg
				"sfx":
					nodes.append({"sfx": arg})
				"bg":
					var parts := arg.split(" ", false, 1)
					var shot := {"bg": parts[0] if not parts.is_empty() else ""}
					if parts.size() > 1:
						shot["lighting"] = parts[1].strip_edges()
					nodes.append(shot)
				"show":
					var parts := arg.split(" ", false)
					var shown := {"show": parts[0], "at": parts[1] if parts.size() > 1 else "center"}
					if parts.size() > 2:
						shown["mood"] = " ".join(parts.slice(2))
					nodes.append(shown)
				"mood":
					var mp := arg.split(" ", false, 1)
					nodes.append({"mood": mp[0], "as": mp[1] if mp.size() > 1 else ""})
				"hide":
					nodes.append({"hide": arg})
				"label":
					nodes.append({"label": arg})
				"goto":
					nodes.append({"goto": arg})
				"if":
					var arrow := arg.rfind("->")
					nodes.append({"if": JSON.parse_string(arg.substr(0, arrow)), "goto": arg.substr(arrow + 2).strip_edges()})
				"do":
					var eff = JSON.parse_string(arg)
					if eff == null:
						push_error("%s:%d — ошибка JSON" % [fname, ln])
					nodes.append({"do": eff})
				"end":
					nodes.append({"end": true})
				"choice":
					cur_choice = {"choice": []}
					nodes.append(cur_choice)
				"hub":
					# хаб тем: выбранный вариант исчезает, «@back» возвращает к оставшимся
					cur_choice = {"choice": [], "hub": true}
					nodes.append(cur_choice)
				"back":
					nodes.append({"back": true})
				_:
					push_error("%s:%d — неизвестная команда @%s" % [fname, ln, cmd])
			continue
		var mood_line := _MOOD_LINE.search(s)
		if mood_line:
			nodes.append({"s": mood_line.get_string(1), "as": mood_line.get_string(2).strip_edges(), "t": mood_line.get_string(3)})
			continue
		var colon := s.find(": ")
		if colon > 0 and not s.substr(0, colon).contains(" "):
			var who := s.substr(0, colon)
			var said := s.substr(colon + 2)
			if who == "N":
				nodes.append({"n": said})
			else:
				nodes.append({"s": who, "t": said})
		else:
			nodes.append({"n": s})
	return sc
