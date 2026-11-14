class_name DuelEngine
extends RefCounted
## Логика фехтовального поединка без интерфейса (её же гоняет автопроверка).
##
## Основа — как в карточных боях: колода, рука из пяти карт, три единицы энергии на ход,
## защита и видимые намерения противника. Поединок — борьба за инициативу:
##  • Защита поглощает удары и сбрасывается в начале своего хода.
##  • Равновесие — стойка и контроль дистанции. Опустилось до нуля — фехтовальщик «раскрыт».
##  • Раскрытого противника можно закончить решающим приёмом (касание, обезоруживание,
##    клинок к горлу, срезанные пуговицы). Раскрытого Флёра противник закончит своим
##    решающим приёмом, если тот за свой ход не восстановит равновесие.
##  • Инициатива переходит к тому, кто пробил защиту или полностью отбил удар;
##    у кого она — бьёт на 2 сильнее.
##  • Блеск — стиль Флёра: эффектные приёмы его копят, эффектные развязки его требуют.

const HAND := 5
const ENERGY := 3
const INIT_BONUS := 2
const SERIES_BONUS := 3

var id := ""
var def: Dictionary = {}
var context := ""
var cards: Dictionary = {}           # описания карт Флёра
var fleur := {}
var enemies: Array = []
var initiative := ""                 # "fleur", "enemy" или ""
var deck: Array = []
var hand: Array = []
var discard: Array = []
var turn := 0
var energy := 0
var attacks_this_turn := 0
var last_turn_attacks := 0
var result: Dictionary = {}
var events: Array = []               # [{kind, text, target, amount}] — для интерфейса
var rng := RandomNumberGenerator.new()
var _uid := 0


func setup(duel_id: String, data: Dictionary, s: Dictionary) -> void:
	id = duel_id
	def = data["duels"][duel_id]
	context = str(def.get("context", "training"))
	cards = data["cards"]
	var bal := int(data.get("fleur", {}).get("balance", 14))
	if s["cards"].has("st_hangover"):
		bal -= 2
	fleur = {"balance": bal, "max": bal, "guard": 0, "panache": 0, "prepared": 0, "feint": false,
		"counter": 0, "open": false, "wounds": 0, "regen": int(data.get("fleur", {}).get("regen", 1))}
	for eid in def["enemies"]:
		var od: Dictionary = data["opponents"][eid]
		_uid += 1
		enemies.append({"uid": _uid, "id": eid, "def": od, "title": od["title"], "pid": od.get("pid", ""),
			"balance": int(od["balance"]), "max": int(od["balance"]), "guard": 0, "regen": int(od.get("regen", 1)),
			"open": false, "out": false, "step": 0, "prepared": 0, "fury": 0, "intent": {}})
	# колода: основа + особенности поединка + то, чему Флёр научился своими привычками
	var list: Array = data["decks"]["base"].duplicate()
	var ctx_deck: Dictionary = data["decks"].get(context, {})
	for c in ctx_deck.get("remove", []):
		list.erase(c)
	list.append_array(ctx_deck.get("add", []))
	for u in data.get("unlocks", []):
		if Rules.test(u.get("when"), s, {}) and (u.get("contexts", []).is_empty() or u["contexts"].has(context)):
			list.append_array(u["add"])
	for c in list:
		_uid += 1
		deck.append({"uid": _uid, "id": c})
	_shuffle(deck)
	for e in enemies:
		_pick_intent(e)
	var extra_draw := 1 if s["cards"].has("st_sharp") else 0
	var energy_mod := -1 if s["cards"].has("st_tired") else 0
	_start_turn(extra_draw, energy_mod)


# ---------------------------------------------------------------- ход Флёра

func _start_turn(extra_draw := 0, energy_mod := 0) -> void:
	turn += 1
	fleur["guard"] = 0
	fleur["counter"] = 0
	if not fleur["open"]:
		fleur["balance"] = mini(fleur["max"], fleur["balance"] + fleur["regen"])
	energy = ENERGY + energy_mod
	last_turn_attacks = attacks_this_turn
	attacks_this_turn = 0
	_draw(HAND + extra_draw)
	if turn > int(def.get("max_rounds", 10)):
		_finish("time")


func _draw(n: int) -> void:
	for k in n:
		if deck.is_empty():
			if discard.is_empty():
				return
			deck = discard
			discard = []
			_shuffle(deck)
		hand.append(deck.pop_back())


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp


func card_def(c: Dictionary) -> Dictionary:
	return cards.get(c["id"], {})


func needs_target(c: Dictionary) -> bool:
	var fx: Dictionary = card_def(c).get("fx", {})
	return fx.has("hit") or fx.has("hits") or fx.has("break")


func can_play(c: Dictionary) -> bool:
	return result.is_empty() and int(card_def(c).get("cost", 1)) <= energy


func alive() -> Array:
	var out := []
	for e in enemies:
		if not e["out"]:
			out.append(e)
	return out


func play(uid: int, target_uid := -1) -> bool:
	var c: Dictionary = {}
	for h in hand:
		if h["uid"] == uid:
			c = h
	if c.is_empty() or not can_play(c):
		return false
	var d := card_def(c)
	var fx: Dictionary = d.get("fx", {})
	var target: Dictionary = _enemy(target_uid)
	if target.is_empty() and alive().size() > 0:
		target = alive()[0]
	energy -= int(d.get("cost", 1))
	hand.erase(c)
	discard.append(c)
	_ev("play", "Флёр: %s." % d["title"], target.get("uid", -1) if needs_target(c) else -1, 0, {"card": c["id"], "card_kind": str(d.get("kind", "skill"))})
	if fx.has("panache"):
		_panache(int(fx["panache"]))
	if fx.has("guard"):
		fleur["guard"] += int(fx["guard"])
	if fx.has("balance"):
		fleur["balance"] = mini(fleur["max"], fleur["balance"] + int(fx["balance"]))
		if fleur["open"] and fleur["balance"] > 0:
			fleur["open"] = false
			_ev("recover", "Флёр восстановил стойку.")
	if fx.has("self_balance"):
		_fleur_balance(-int(fx["self_balance"]))
	if fx.has("prepare"):
		fleur["prepared"] += int(fx["prepare"])
	if fx.get("feint", false):
		fleur["feint"] = true
	if fx.has("counter"):
		fleur["counter"] += int(fx["counter"])
	if fx.get("initiative", false):
		_set_initiative("fleur")
	if fx.has("draw"):
		_draw(int(fx["draw"]))
	if fx.has("energy"):
		energy += int(fx["energy"])
	if fx.has("break") and not target.is_empty():
		_enemy_balance(target, -int(fx["break"]))
	if fx.has("hit") and not target.is_empty():
		_attack(target, int(fx["hit"]), fx.get("pierce", false))
	if fx.has("hits") and not target.is_empty():
		for k in int(fx["hits"][1]):
			if target["out"] or not result.is_empty():
				break
			_attack(target, int(fx["hits"][0]), fx.get("pierce", false))
	return true


func _attack(e: Dictionary, base: int, pierce: bool) -> void:
	attacks_this_turn += 1
	var dmg: int = base + int(fleur["prepared"])
	fleur["prepared"] = 0
	if initiative == "fleur":
		dmg += INIT_BONUS
	if attacks_this_turn == 3:
		dmg += SERIES_BONUS
		_ev("series", "Серия: третий удар подряд.")
	if fleur["feint"]:
		pierce = true
		fleur["feint"] = false
	var through := dmg
	if not pierce:
		var absorbed := mini(e["guard"], dmg)
		e["guard"] -= absorbed
		through = dmg - absorbed
	_ev("hit", "", e["uid"], through, {"absorbed": dmg - through})
	if through > 0:
		_enemy_balance(e, -through)
		_set_initiative("fleur")
	# Контрстойка противника: отвечает на атаку
	if e["intent"].get("kind") == "counter" and not e["out"] and result.is_empty():
		var n := int(e["intent"]["n"])
		e["intent"] = {"kind": "guard", "n": 0, "label": "Отвечено", "spent": true}
		_ev("counter", "%s ловит атаку на противоходе." % e["title"], e["uid"], 0, {"by": "enemy"})
		_hit_fleur(e, n)


func finishers() -> Array:
	## Решающие приёмы, доступные сейчас: противник раскрыт.
	var out := []
	for f in def.get("finishers", []):
		if fleur["panache"] < int(f.get("panache", 0)):
			continue
		out.append(f)
	return out


func any_open() -> bool:
	for e in alive():
		if e["open"]:
			return true
	return false


func finish_with(fid: String, target_uid := -1) -> bool:
	var e := _enemy(target_uid)
	if e.is_empty():
		for x in alive():
			if x["open"]:
				e = x
				break
	if e.is_empty() or not e["open"]:
		return false
	var f: Dictionary = {}
	for x in finishers():
		if x["id"] == fid:
			f = x
	if f.is_empty():
		return false
	_ev("finisher", "%s: %s." % [f["title"], e["title"]], e["uid"], 0, {"finisher": fid, "outcome": str(f.get("outcome", fid))})
	if f.get("removes", false):
		e["out"] = true
		e["open"] = false
		if alive().is_empty():
			_finish(str(f.get("outcome", "win")))
		return true
	_finish(str(f.get("outcome", fid)))
	return true


func yield_duel() -> void:
	if result.is_empty():
		_finish("yield")


# ---------------------------------------------------------------- ход противника

func end_turn() -> void:
	if not result.is_empty():
		return
	discard.append_array(hand)
	hand.clear()
	fleur["prepared"] = 0
	fleur["feint"] = false
	for e in alive():
		if not result.is_empty():
			return
		e["guard"] = 0
		if e["open"]:
			e["open"] = false
			e["balance"] = int(ceil(e["max"] * 0.45))
			_ev("recover", "%s собирается и снова встаёт в стойку." % e["title"], e["uid"])
		else:
			e["balance"] = mini(e["max"], e["balance"] + e["regen"])
			_act(e)
		if result.is_empty() and not e["out"]:
			_pick_intent(e)
	if result.is_empty():
		_start_turn()


func _act(e: Dictionary) -> void:
	var it: Dictionary = e["intent"]
	_ev("act", "", e["uid"], 0, {"intent": str(it.get("kind", "")), "label": str(it.get("label", ""))})
	match str(it.get("kind", "")):
		"attack":
			for k in int(it.get("count", 1)):
				if result.is_empty():
					_hit_fleur(e, int(it["n"]) + e["fury"])
		"press":
			_set_initiative("enemy")
			_hit_fleur(e, int(it["n"]) + e["fury"])
		"guard":
			e["guard"] += int(it.get("n", 0))
		"feint":
			e["prepared"] += int(it.get("n", 3))
			_fleur_balance(-int(it.get("unsettle", 2)))
			_ev("feint", "%s: финт. Следующий удар будет сильнее." % e["title"], e["uid"])
		"taunt":
			e["fury"] += int(it.get("fury", 2))
			e["guard"] += int(it.get("guard", 0))
			_ev("taunt", "%s распаляется на публику." % e["title"], e["uid"])
		"recover":
			e["balance"] = mini(e["max"], e["balance"] + int(it.get("n", 3)))
		"counter":
			# контрстойка ловит атаки во время хода Флёра; если он не атаковал — выпад из той же стойки
			if not it.get("spent", false):
				_hit_fleur(e, maxi(1, int(it["n"]) - 3))
		"decisive":
			if fleur["open"]:
				_ev("decisive", "%s: решающий приём." % e["title"], e["uid"])
				_finish("wound" if (fleur["wounds"] > 0 or context == "street") else "loss")
			else:
				_ev("recover", "Флёр ушёл из-под решающего приёма.")


func _hit_fleur(e: Dictionary, n: int) -> void:
	var dmg: int = n + int(e["prepared"])
	e["prepared"] = 0
	if initiative == "enemy":
		dmg += INIT_BONUS
	var absorbed := mini(fleur["guard"], dmg)
	fleur["guard"] -= absorbed
	var through := dmg - absorbed
	_ev("hit_fleur", "", e["uid"], through, {"absorbed": absorbed})
	if through <= 0 and dmg > 0:
		_set_initiative("fleur")
		_ev("parry", "Флёр полностью отбил удар и перехватил инициативу.")
		var fury_gain := int(e["def"].get("fury_on_block", 0))
		if fury_gain > 0:
			e["fury"] += fury_gain
			_ev("taunt", "%s злится: удар отбит при всех." % e["title"], e["uid"])
	else:
		_set_initiative("enemy")
		if e["def"].get("wounds", false) and through >= 3:
			fleur["wounds"] += 1
			_ev("wound", "Нож прошёл по рукаву — это уже не царапина на камзоле.")
		_fleur_balance(-through)
	if fleur["counter"] > 0 and not e["out"] and result.is_empty():
		var c := int(fleur["counter"])
		fleur["counter"] = 0
		_ev("counter", "Флёр отвечает контратакой.", e["uid"], 0, {"by": "fleur"})
		var g := mini(e["guard"], c)
		e["guard"] -= g
		_enemy_balance(e, -(c - g))


# ---------------------------------------------------------------- намерения

func _pick_intent(e: Dictionary) -> void:
	var od: Dictionary = e["def"]
	if fleur["open"]:
		e["intent"] = {"kind": "decisive", "label": str(od.get("decisive", "Решающий приём"))}
		return
	# Клоринда читает соперника: серия атак — и она уже ждёт следующую в контрстойке
	var reads := int(od.get("reads", 0))
	if reads > 0 and attacks_this_turn >= reads:
		e["intent"] = {"kind": "counter", "n": int(od.get("counter_n", 7)), "label": "Контрстойка"}
		return
	var pat: Array = od["pattern"]
	var it: Dictionary = pat[e["step"] % pat.size()].duplicate()
	e["step"] += 1
	if od.get("shuffle", false) and rng.randf() < 0.35:
		it = pat[rng.randi_range(0, pat.size() - 1)].duplicate()
	e["intent"] = it


func intent_value(e: Dictionary) -> int:
	## Сколько на самом деле придёт по Флёру (с яростью, подготовкой и инициативой).
	var it: Dictionary = e["intent"]
	if not (it.get("kind") in ["attack", "press", "counter"]):
		return int(it.get("n", 0))
	var n: int = int(it.get("n", 0)) + int(e["prepared"])
	if it.get("kind") != "counter":
		n += int(e["fury"])
	if initiative == "enemy" or it.get("kind") == "press":
		n += INIT_BONUS
	return n


# ---------------------------------------------------------------- служебное

func _enemy(uid: int) -> Dictionary:
	for e in enemies:
		if e["uid"] == uid and not e["out"]:
			return e
	return {}


func _enemy_balance(e: Dictionary, delta: int) -> void:
	e["balance"] = clampi(e["balance"] + delta, 0, e["max"])
	if e["balance"] <= 0 and not e["open"]:
		e["open"] = true
		e["intent"] = {"kind": "recover", "label": "Раскрыт: собирается", "n": 0}
		fleur["broke"] = int(fleur.get("broke", 0)) + 1
		_set_initiative("fleur")
		_ev("open", "%s раскрыт. Сейчас — решающий приём." % e["title"], e["uid"])


func _fleur_balance(delta: int) -> void:
	fleur["balance"] = clampi(fleur["balance"] + delta, 0, fleur["max"])
	if fleur["balance"] <= 0 and not fleur["open"]:
		fleur["open"] = true
		_ev("open_fleur", "Флёр раскрыт. Если за ход не восстановить стойку, противник закончит поединок.")
		for e in alive():
			if not e["open"]:
				e["intent"] = {"kind": "decisive", "label": str(e["def"].get("decisive", "Решающий приём"))}


func _set_initiative(who: String) -> void:
	if initiative != who:
		initiative = who
		_ev("initiative", "Инициатива у Флёра." if who == "fleur" else "Инициатива у противника.")


func _panache(n: int) -> void:
	fleur["panache"] = clampi(fleur["panache"] + n, 0, 10)


func _ev(kind: String, text: String, target := -1, amount := 0, extra := {}) -> void:
	var ev := {"kind": kind, "text": text, "target": target, "amount": amount}
	ev.merge(extra)
	events.append(ev)


func _finish(outcome: String) -> void:
	if not result.is_empty():
		return
	result = {"outcome": outcome, "turns": turn, "panache": fleur["panache"], "broke": int(fleur.get("broke", 0)), "wounds": fleur["wounds"]}
	_ev("end", "")
