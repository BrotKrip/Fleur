extends Node
## Правила мира: условия, эффекты, время, события, действия.
## Состояние игры — обычный Dictionary, сохраняется в JSON как есть.
## Условия и эффекты — декларативные словари из res://data (см. README).

const PHASES := ["Утро", "День", "Вечер", "Ночь"]
const PHASE_KEYS := ["morning", "day", "evening", "night"]
const SAVE_VERSION := 2


# ---------------------------------------------------------------- состояние

func new_state() -> Dictionary:
	var s := {
		"version": SAVE_VERSION, "day": 1, "phase": 0,
		"cards": {}, "rel": {}, "flags": {}, "counters": {}, "whereabouts": {},
		"scheduled": [], "fired": {}, "fired_at": {}, "done_day": {},
		"notices": [], "queue": [], "log": [],
		"layout": {}, "here": "loc_apartment",
	}
	var api := new_api()
	var start: Dictionary = Content.world.get("start", {})
	for id in start.get("cards", []):
		add_card(s, id, {}, api)
	apply(start.get("effects", []), s, {}, api)
	check_events(s, api)
	return s


func new_api() -> Dictionary:
	return {"changes": []}


func abs_time(s: Dictionary) -> int:
	return (int(s["day"]) - 1) * 4 + int(s["phase"])


func phase_key(s: Dictionary) -> String:
	return PHASE_KEYS[int(s["phase"])]


func txt(t, s: Dictionary, ctx: Dictionary = {}) -> String:
	if t == null:
		return ""
	if t is String:
		return t
	if t is Array:
		var out := ""
		for part in t:
			if part is String:
				out += ("\n" if out != "" else "") + part
			elif test(part.get("when"), s, ctx):
				if out != "":
					out += str(part.get("sep", "\n"))
				out += str(part.get("text", ""))
		return out
	return str(t)


func title_of(id: String, s: Dictionary) -> String:
	var d := Content.def(id)
	if d.has("stages"):
		var st: Array = d["stages"]
		return txt(st[clampi(case_stage(s, id), 0, st.size() - 1)].get("title", d.get("title")), s)
	return txt(d.get("title"), s) if not d.is_empty() else id


# ---------------------------------------------------------------- карты

func add_card(s: Dictionary, id: String, opts: Dictionary, api: Dictionary) -> bool:
	var d := Content.def(id)
	if d.is_empty():
		push_warning("Неизвестная карта: " + id)
		return false
	var lifetime = opts.get("lifetime", d.get("lifetime"))
	var cards: Dictionary = s["cards"]
	if cards.has(id):
		var ex: Dictionary = cards[id]
		if d.get("stack", false):
			ex["count"] = int(ex.get("count", 1)) + int(opts.get("count", 1))
			api["changes"].append({"kind": "gain", "id": id})
		if lifetime != null:
			var cur = ex.get("lifetime")
			ex["lifetime"] = maxi(int(cur) if cur != null else 0, int(lifetime))
		return false
	var lt = null
	if lifetime != null:
		lt = int(lifetime)
	cards[id] = {"id": id, "lifetime": lt, "count": int(opts.get("count", 1)), "fresh": true}
	if d.get("type") == "person" and not s["rel"].has(id):
		s["rel"][id] = d.get("rel", []).duplicate()
	api["changes"].append({"kind": "gain", "id": id})
	return true


func remove_card(s: Dictionary, id: String, api: Dictionary) -> bool:
	var cards: Dictionary = s["cards"]
	if not cards.has(id):
		return false
	var d := Content.def(id)
	if d.get("stack", false) and int(cards[id].get("count", 1)) > 1:
		cards[id]["count"] = int(cards[id]["count"]) - 1
	else:
		cards.erase(id)
	api["changes"].append({"kind": "lose", "id": id})
	return true


func has_card(s: Dictionary, id: String) -> bool:
	return s["cards"].has(id)


func is_location(id) -> bool:
	return id is String and Content.def(id).get("type") == "location"


# ---------------------------------------------------------------- люди

func where_is(s: Dictionary, pid: String):
	var w = s["whereabouts"].get(pid)
	if w != null and (w.get("until") == null or int(w["until"]) > abs_time(s)):
		return w.get("loc")
	var d: Dictionary = Content.characters.get(pid, {})
	var sch = d.get("schedule")
	if sch == null:
		return null
	for entry in sch:
		if test(entry.get("when"), s, {}):
			return entry.get("map", {}).get(phase_key(s))
	return null


func people_at(s: Dictionary, loc: String) -> Array:
	var out := []
	for id in s["cards"]:
		if Content.def(id).get("type") == "person" and where_is(s, id) == loc:
			out.append(id)
	return out


# ---------------------------------------------------------------- условия

func _resolve(v, ctx: Dictionary):
	if not (v is String) or not v.begins_with("$"):
		return v
	var key: String = v.substr(1)
	if key == "here":
		return ctx.get("here")
	return ctx.get("slots", {}).get(key)


func _list(v) -> Array:
	return v if v is Array else [v]


func _pairs(v) -> Array:
	return v if (v is Array and v.size() > 0 and v[0] is Array) else [v]


func test(c, s: Dictionary, ctx: Dictionary = {}) -> bool:
	if c == null:
		return true
	if c is Array:
		for x in c:
			if not test(x, s, ctx):
				return false
		return true
	if not (c is Dictionary):
		return true
	for k in c:
		var v = c[k]
		match k:
			"all":
				for x in v:
					if not test(x, s, ctx):
						return false
			"any":
				var ok := false
				for x in v:
					if test(x, s, ctx):
						ok = true
						break
				if not ok:
					return false
			"not":
				if test(v, s, ctx):
					return false
			"flag":
				for f in _list(v):
					if not s["flags"].get(f, false):
						return false
			"noFlag":
				for f in _list(v):
					if s["flags"].get(f, false):
						return false
			"has":
				for id in _list(v):
					if not s["cards"].has(str(_resolve(id, ctx))):
						return false
			"lacks":
				for id in _list(v):
					if s["cards"].has(str(_resolve(id, ctx))):
						return false
			"phase":
				if not _list(v).has(phase_key(s)):
					return false
			"day":
				if int(s["day"]) != int(v):
					return false
			"dayGte":
				if int(s["day"]) < int(v):
					return false
			"rel":
				var who = _resolve(v[0], ctx)
				if not s["rel"].get(who, []).has(v[1]):
					return false
			"noRel":
				var who2 = _resolve(v[0], ctx)
				if s["rel"].get(who2, []).has(v[1]):
					return false
			"present":
				if where_is(s, str(_resolve(v[0], ctx))) != _resolve(v[1], ctx):
					return false
			"slot":
				if ctx.get("slots", {}).get(v[0]) != v[1]:
					return false
			"slotFilled":
				if ctx.get("slots", {}).get(v) == null:
					return false
			"slotEmpty":
				if ctx.get("slots", {}).get(v) != null:
					return false
			"ctx":
				if ctx.get(v[0]) != v[1]:
					return false
			"counterGte":
				if int(s["counters"].get(v[0], 0)) < int(v[1]):
					return false
			"counterLt":
				if int(s["counters"].get(v[0], 0)) >= int(v[1]):
					return false
			"daysSince":
				var key: String = "day:" + str(v[0])
				if not s["counters"].has(key) or int(s["day"]) - int(s["counters"][key]) < int(v[1]):
					return false
			"someoneHere":
				if (people_at(s, str(ctx.get("here", ""))).size() > 0) != bool(v):
					return false
			"ready":
				for id in _list(v):
					if not s["cards"].has(id) or int(s["cards"][id].get("rest", 0)) > 0:
						return false
			"fired":
				if not s["fired"].has(v):
					return false
			"placeExpired":
				var w = s["whereabouts"].get(v)
				if w == null or w.get("until") == null or int(w["until"]) > abs_time(s):
					return false
			"chance":
				if randf() >= float(v):
					return false
			_:
				push_warning("Неизвестное условие: " + str(k))
	return true


# ---------------------------------------------------------------- эффекты

func apply(effects, s: Dictionary, ctx: Dictionary, api: Dictionary) -> void:
	if effects == null:
		return
	for e in _list(effects):
		if not (e is Dictionary):
			continue
		if e.has("if"):
			apply(e.get("then") if test(e["if"], s, ctx) else e.get("else"), s, ctx, api)
			continue
		for k in e:
			var v = e[k]
			match k:
				"add":
					for it in _list(v):
						if it is String:
							add_card(s, str(_resolve(it, ctx)), {}, api)
						else:
							add_card(s, str(_resolve(it["id"], ctx)), it, api)
				"remove":
					for id in _list(v):
						remove_card(s, str(_resolve(id, ctx)), api)
				"flag":
					for f in _list(v):
						s["flags"][f] = true
				"unflag":
					for f in _list(v):
						s["flags"].erase(f)
				"counter":
					for p in _pairs(v):
						s["counters"][p[0]] = int(s["counters"].get(p[0], 0)) + int(p[1])
				"relAdd":
					for p in _pairs(v):
						var who = str(_resolve(p[0], ctx))
						if not s["rel"].has(who):
							s["rel"][who] = []
						if not s["rel"][who].has(p[1]):
							s["rel"][who].append(p[1])
							api["changes"].append({"kind": "rel", "who": who, "tag": p[1], "add": true})
				"relRemove":
					for p in _pairs(v):
						var who = str(_resolve(p[0], ctx))
						var lst: Array = s["rel"].get(who, [])
						if lst.has(p[1]):
							lst.erase(p[1])
							api["changes"].append({"kind": "rel", "who": who, "tag": p[1], "add": false})
				"log":
					log_entry(s, txt(v, s, ctx))
				"notice":
					s["notices"].append({"title": txt(v.get("title"), s, ctx), "text": txt(v.get("text"), s, ctx), "kind": v.get("kind", "event")})
				"scene":
					if v is String:
						s["queue"].append({"type": "scene", "id": v, "ctx": {}})
					else:
						s["queue"].append({"type": "scene", "id": v["id"], "ctx": v.get("ctx", {})})
				"activity":
					s["queue"].append({"type": "activity", "id": v["id"], "params": v.get("params", {}), "onResult": v.get("onResult")})
				"schedule":
					s["scheduled"].append({"event": v["event"], "at": abs_time(s) + int(v.get("in", 1))})
				"event":
					fire_event(s, v, api, true)
				"place":
					var until = null
					if v.get("for") != null:
						until = abs_time(s) + int(v["for"])
					s["whereabouts"][str(_resolve(v["who"], ctx))] = {"loc": v.get("loc"), "until": until}
				"unplace":
					s["whereabouts"].erase(v)
				"spend":
					for id in _list(v):
						spend_approach(s, str(_resolve(id, ctx)), api)
				"stamp":
					s["counters"]["day:" + str(v)] = int(s["day"])
				"wait":
					advance(s, int(v), api)
				"then", "else":
					pass
				_:
					push_warning("Неизвестный эффект: " + str(k))


func log_entry(s: Dictionary, text: String, kind := "text") -> void:
	if text.is_empty():
		return
	s["log"].append({"day": s["day"], "phase": s["phase"], "text": text, "kind": kind})
	while s["log"].size() > 200:
		s["log"].pop_front()


# ---------------------------------------------------------------- время

## Продвигает время. Если по ходу возникла сцена или активность, продвижение прерывается:
## мир «перебил» планы (например, звонок в дверь посреди сна).
func advance(s: Dictionary, n: int, api: Dictionary) -> void:
	var queued: int = s["queue"].size()
	for i in n:
		_step(s, api)
		if s["queue"].size() > queued and i < n - 1:
			log_entry(s, "Планы пришлось прервать.", "system")
			break


func _step(s: Dictionary, api: Dictionary) -> void:
	var was_night := int(s["phase"]) == 3
	s["phase"] = int(s["phase"]) + 1
	if s["phase"] > 3:
		s["phase"] = 0
		s["day"] = int(s["day"]) + 1
	if was_night:
		if not s["flags"].get("_slept", false):
			add_card(s, "st_tired", {}, api)
			log_entry(s, "Ночь прошла без сна. Это будет заметно.", "system")
		s["flags"].erase("_slept")

	for id in s["cards"].keys():
		var inst: Dictionary = s["cards"][id]
		if int(inst.get("rest", 0)) > 0:
			inst["rest"] = int(inst["rest"]) - 1
		if inst.get("lifetime") == null:
			continue
		inst["lifetime"] = int(inst["lifetime"]) - 1
		if int(inst["lifetime"]) <= 0:
			var d := Content.def(id)
			s["cards"].erase(id)
			api["changes"].append({"kind": "expire", "id": id})
			if d.has("expireText"):
				log_entry(s, txt(d["expireText"], s), "expire")
			apply(d.get("onExpire"), s, {}, api)
	check_events(s, api)


# ---------------------------------------------------------------- события

func check_events(s: Dictionary, api: Dictionary) -> void:
	var t := abs_time(s)
	var due := []
	var rest := []
	for x in s["scheduled"]:
		if int(x["at"]) <= t:
			due.append(x)
		else:
			rest.append(x)
	s["scheduled"] = rest
	for x in due:
		fire_event(s, x["event"], api, true)

	for id in Content.events:
		var ev: Dictionary = Content.events[id]
		if ev.get("manual", false):
			continue
		if ev.get("repeat", false):
			if s["fired"].has(id) and t - int(s["fired_at"].get(id, -999)) < int(ev.get("cooldown", 4)):
				continue
		elif s["fired"].has(id):
			continue
		if not test(ev.get("when"), s, {}):
			continue
		if ev.get("chance") != null and randf() >= float(ev["chance"]):
			continue
		fire_event(s, id, api)


func fire_event(s: Dictionary, id: String, api: Dictionary, forced := false) -> void:
	var ev: Dictionary = Content.events.get(id, {})
	if ev.is_empty():
		push_warning("Неизвестное событие: " + id)
		return
	if forced and ev.get("when") != null and not test(ev["when"], s, {}):
		return
	s["fired"][id] = int(s["fired"].get(id, 0)) + 1
	s["fired_at"][id] = abs_time(s)
	if ev.has("title") or ev.has("text"):
		s["notices"].append({"title": txt(ev.get("title"), s), "text": txt(ev.get("text"), s), "kind": ev.get("kind", "event")})
	if ev.has("logText"):
		log_entry(s, txt(ev["logText"], s), "event")
	apply(ev.get("effects"), s, {}, api)


# ---------------------------------------------------------------- действия

func actions_for(s: Dictionary, where: String) -> Array:
	var out := []
	for id in Content.actions:
		var a: Dictionary = Content.actions[id]
		var matches: bool = a.get("at") == where or a.get("on") == where or (a.get("at") == "*" and is_location(where))
		if matches and test(a.get("visible"), s, action_ctx(a, where, {})):
			out.append(a)
	return out


func action_ctx(a: Dictionary, where: String, slots: Dictionary) -> Dictionary:
	var here = a.get("here")
	if here == null and is_location(where):
		here = where
	return {"here": here, "slots": slots, "actionId": a["id"]}


func slot_accepts(slot: Dictionary, id: String, s: Dictionary, ctx: Dictionary) -> bool:
	var d := Content.def(id)
	if d.is_empty() or not s["cards"].has(id):
		return false
	if slot.has("types") and not slot["types"].has(d.get("type")):
		return false
	if slot.has("ids") and not slot["ids"].has(id):
		return false
	if slot.has("tags"):
		for t in slot["tags"]:
			if not d.get("tags", []).has(t):
				return false
	if slot.get("present", false) and where_is(s, id) != ctx.get("here"):
		return false
	if slot.has("notFlagged") and s["flags"].get(str(slot["notFlagged"]) + id, false):
		return false
	if int(s["cards"][id].get("rest", 0)) > 0:
		return false
	if slot.has("exclude_slot") and ctx.get("slots", {}).get(slot["exclude_slot"]) == id:
		return false
	return true


func slot_candidates(slot: Dictionary, s: Dictionary, ctx: Dictionary) -> Array:
	var out := []
	for id in s["cards"]:
		if slot_accepts(slot, id, s, ctx):
			out.append(id)
	return out


func cost_of(a: Dictionary, s: Dictionary) -> int:
	var c = a.get("cost", 1)
	if c is String and c == "untilMorning":
		return 4 - int(s["phase"])
	return int(c)


## Можно ли выполнить действие: { ok, reason }.
func can_do(a: Dictionary, s: Dictionary, ctx: Dictionary) -> Dictionary:
	if a.get("once", false) and s["flags"].get("done:" + a["id"], false):
		return {"ok": false, "reason": "Уже сделано."}
	if a.get("daily", false) and int(s["done_day"].get(a["id"], -1)) == int(s["day"]):
		return {"ok": false, "reason": "Сегодня уже было."}
	if a.has("phases") and not a["phases"].has(phase_key(s)):
		var names := []
		for p in a["phases"]:
			names.append(PHASES[PHASE_KEYS.find(p)].to_lower())
		return {"ok": false, "reason": "Только: " + ", ".join(names) + "."}
	for r in _list(a.get("req", [])):
		var cond = r.get("cond", r) if r is Dictionary else r
		if not test(cond, s, ctx):
			return {"ok": false, "reason": r.get("reason", "Не сейчас.") if r is Dictionary else "Не сейчас."}
	for sl in a.get("slots", []):
		if sl.get("required", false) and ctx.get("slots", {}).get(sl["id"]) == null:
			return {"ok": false, "reason": "Нужно: " + str(sl["label"]).to_lower() + ".", "needs_slot": true}
	return {"ok": true}


## Выполнить действие. Возвращает { title, text }.
func perform(a: Dictionary, s: Dictionary, ctx: Dictionary, api: Dictionary) -> Dictionary:
	if a.get("talk", false):
		return perform_talk(a, s, ctx, api)
	if a.get("case", false):
		return perform_case(a, s, ctx, api)
	var outcome: Dictionary = {}
	for o in a.get("outcomes", []):
		if test(o.get("when"), s, ctx):
			outcome = o
			break
	var text := txt(outcome.get("text"), s, ctx)
	log_entry(s, (str(a["title"]) + ". " + text).strip_edges(), "action")
	apply(outcome.get("effects"), s, ctx, api)
	if a.get("once", false):
		s["flags"]["done:" + a["id"]] = true
	if a.get("daily", false):
		s["done_day"][a["id"]] = s["day"]
	if outcome.get("sleep", false) or a.get("sleep", false):
		s["flags"]["_slept"] = true
	var cost = outcome.get("cost", a.get("cost", 1))
	if cost is String and cost == "untilMorning":
		advance(s, 4 - int(s["phase"]), api)
	elif int(cost) > 0:
		advance(s, int(cost), api)
	return {"title": txt(outcome.get("title"), s, ctx) if outcome.has("title") else str(a["title"]), "text": text, "silent": outcome.get("silent", false)}


func mark_seen(s: Dictionary) -> void:
	for id in s["cards"]:
		s["cards"][id]["fresh"] = false


# ---------------------------------------------------------------- подходы Флёра

## Подход (Обаяние, Клинок, Фамилия, Кошелёк, Откровенность) после использования «отдыхает»
## несколько частей дня: карта лежит на столе, но в ячейки её положить нельзя.
func spend_approach(s: Dictionary, id: String, api: Dictionary) -> void:
	if not s["cards"].has(id):
		return
	s["cards"][id]["rest"] = int(Content.def(id).get("recharge", 3))
	s["counters"]["used:" + id] = int(s["counters"].get("used:" + id, 0)) + 1
	api["changes"].append({"kind": "spent", "id": id})


func is_resting(s: Dictionary, id: String) -> bool:
	return s["cards"].has(id) and int(s["cards"][id].get("rest", 0)) > 0


# ---------------------------------------------------------------- разговоры

## Разговор: собеседник + тема (любая карта) + необязательный подход.
## Реакции лежат в data/talk.json: talk[собеседник].topics[тема | "type:<тип>" | "*"] — список вариантов,
## срабатывает первый подходящий (when, approach). Если подход положен, но вариант его не учитывает,
## собеседник отвечает на сам подход строкой из talk[собеседник].approaches.
func resolve_talk(s: Dictionary, ctx: Dictionary) -> Dictionary:
	var who := str(ctx.get("slots", {}).get("who", ""))
	var topic := str(ctx.get("slots", {}).get("topic", ""))
	var ap = ctx.get("slots", {}).get("approach")
	var book: Dictionary = Content.talk.get(who, {})
	var tdef := Content.def(topic)
	var keys := [topic, "type:" + str(tdef.get("type", "")), "*"]
	var books := [[who, book], ["_default", Content.talk.get("_default", {})]]
	for pair in books:
		for key in keys:
			var entries: Array = pair[1].get("topics", {}).get(key, [])
			for i in entries.size():
				var e: Dictionary = entries[i]
				if e.has("approach") and (ap == null or not _list(e["approach"]).has(ap)):
					continue
				if not test(e.get("when"), s, ctx):
					continue
				var once_key := "talk:%s:%s:%d" % [who, key, i]
				if e.get("once", false) and s["flags"].get(once_key, false):
					if e.has("again"):
						return {"entry": {"text": e["again"], "cost": 0}, "key": once_key, "general": true, "uses_approach": false}
					continue
				var general: bool = key == "*" or pair[0] == "_default"
				return {"entry": e, "key": once_key, "general": general, "uses_approach": e.has("approach")}
	return {"entry": {"text": book.get("default", "{who} не находит, что на это сказать."), "cost": 0}, "key": "", "general": true, "uses_approach": false}


func _talk_text(t, s: Dictionary, ctx: Dictionary) -> String:
	var who := str(ctx.get("slots", {}).get("who", ""))
	var topic := str(ctx.get("slots", {}).get("topic", ""))
	return txt(t, s, ctx).replace("{who}", title_of(who, s)).replace("{topic}", title_of(topic, s))


func perform_talk(a: Dictionary, s: Dictionary, ctx: Dictionary, api: Dictionary) -> Dictionary:
	var who := str(ctx["slots"].get("who", ""))
	var ap = ctx["slots"].get("approach")
	var res := resolve_talk(s, ctx)
	var e: Dictionary = res["entry"]
	var parts := PackedStringArray()
	var text := _talk_text(e.get("text"), s, ctx)
	if text != "":
		parts.append(text)
	apply(e.get("effects"), s, ctx, api)
	if e.get("once", false) and res["key"] != "":
		s["flags"][res["key"]] = true
	# подход: либо его учёл сам вариант, либо собеседник реагирует на манеру
	if ap != null:
		if not res["uses_approach"]:
			var ar: Dictionary = Content.talk.get(who, {}).get("approaches", {}).get(ap, {})
			if ar.is_empty():
				ar = Content.talk.get("_default", {}).get("approaches", {}).get(ap, {})
			var at := _talk_text(ar.get("text", ""), s, ctx)
			if at != "":
				parts.append(at)
			apply(ar.get("effects"), s, ctx, api)
		spend_approach(s, str(ap), api)
	if e.has("scene"):
		apply({"scene": e["scene"]}, s, ctx, api)
	var full := "\n\n".join(parts)
	log_entry(s, "Разговор: %s — %s. %s" % [title_of(who, s), title_of(str(ctx["slots"].get("topic", "")), s), full.left(220)], "action")
	# сцена сама распоряжается временем; общие ответы ничего не стоят
	var cost = e.get("cost", 0 if (res["general"] or e.has("scene")) else 1)
	if int(cost) > 0:
		advance(s, int(cost), api)
	var title := _talk_text(e.get("title", "Разговор: {who}"), s, ctx)
	return {"title": title, "text": full, "silent": e.has("scene") and full == ""}


# ---------------------------------------------------------------- дело по стадиям
## Карта дела с полем "stages" растёт, когда в неё подшивают улики нужных групп.
## stages[i] = {title, mark, need: группа, text, effects}; evidence = {id карты: {group, text}}.

func case_stage(s: Dictionary, id: String) -> int:
	return int(s["counters"].get("stage:" + id, 0))


func case_filed(s: Dictionary, id: String) -> Array:
	var out := []
	for ev in Content.def(id).get("evidence", {}):
		if s["flags"].get("filed:" + str(ev), false):
			out.append(ev)
	return out


func _case_groups(s: Dictionary, id: String) -> Dictionary:
	var ev: Dictionary = Content.def(id).get("evidence", {})
	var groups := {}
	for e in case_filed(s, id):
		groups[str(ev[e].get("group", ""))] = true
	return groups


func file_evidence(s: Dictionary, case_id: String, ev_id: String, ctx: Dictionary, api: Dictionary) -> PackedStringArray:
	var d := Content.def(case_id)
	var parts := PackedStringArray()
	var ev: Dictionary = d.get("evidence", {}).get(ev_id, {})
	s["flags"]["filed:" + ev_id] = true
	api["changes"].append({"kind": "filed", "id": ev_id, "case": case_id})
	var t := txt(ev.get("text", ""), s, ctx)
	if t != "":
		parts.append(t)
	var stages: Array = d["stages"]
	var old := case_stage(s, case_id)
	var groups := _case_groups(s, case_id)
	var st := 0
	for i in range(1, stages.size()):
		if groups.has(str(stages[i].get("need", ""))):
			st = i
		else:
			break
	if st > old:
		s["counters"]["stage:" + case_id] = st
		for i in range(old + 1, st + 1):
			var line := txt(stages[i].get("text", ""), s, ctx)
			if line != "":
				parts.append(line)
			apply(stages[i].get("effects"), s, ctx, api)
		api["changes"].append({"kind": "stage", "id": case_id, "stage": st})
		log_entry(s, "Дело теперь называется иначе: «%s»." % title_of(case_id, s), "system")
	return parts


func perform_case(a: Dictionary, s: Dictionary, ctx: Dictionary, api: Dictionary) -> Dictionary:
	var case_id := str(ctx["slots"].get("case", ""))
	var ev_id := str(ctx["slots"].get("evidence", ""))
	var d := Content.def(case_id)
	var parts := PackedStringArray()
	if not d.get("evidence", {}).has(ev_id):
		parts.append(txt(d.get("unrelated", "К делу это не относится."), s, ctx))
	else:
		parts = file_evidence(s, case_id, ev_id, ctx, api)
	var full := "

".join(parts)
	log_entry(s, "%s: %s. %s" % [title_of(case_id, s), title_of(ev_id, s), full.left(200)], "action")
	var cost := cost_of(a, s)
	if cost > 0:
		advance(s, cost, api)
	return {"title": txt(a.get("title"), s, ctx), "text": full}
