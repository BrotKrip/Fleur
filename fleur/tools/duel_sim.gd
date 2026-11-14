extends Node
## Прогон поединков простым разумным игроком: сколько раз чем кончается (для настройки баланса).
## Запуск: Godot --headless --path fleur -- --duelsim

static func ai_turn(eng: DuelEngine, prefer_finisher := "", stop_on_open := false) -> void:
	## Ход «разумного» игрока: решающий приём, если можно; стойку, если раскрыт;
	## против контрстойки — не атаковать; иначе финт перед ударом, удары, защита по намерению.
	for guard_loop in 12:
		if not eng.result.is_empty():
			return
		if eng.any_open():
			if stop_on_open:
				return
			var fs := eng.finishers()
			if fs.size() > 0:
				var pick: String = fs[0]["id"]
				for f in fs:
					if f["id"] == prefer_finisher:
						pick = prefer_finisher
				eng.finish_with(pick)
				return
		var best: Dictionary = {}
		var best_score := -999.0
		var incoming := 0
		var countering := false
		for e in eng.alive():
			if e["intent"].get("kind") in ["attack", "press", "decisive"]:
				incoming += eng.intent_value(e) * int(e["intent"].get("count", 1))
			if e["intent"].get("kind") == "counter":
				countering = true
		for c in eng.hand:
			if not eng.can_play(c):
				continue
			var fx: Dictionary = eng.card_def(c).get("fx", {})
			var sc := 0.0
			if eng.fleur["open"]:
				sc += float(fx.get("balance", 0)) * 3.0
			var attack := fx.has("hit") or fx.has("hits")
			if attack:
				sc += 2.0 + float(fx.get("hit", 0)) * 0.4
				if countering:
					sc -= 8.0
			if fx.get("feint", false) and not eng.fleur["feint"]:
				sc += 3.0
			if fx.has("guard") and incoming > eng.fleur["guard"]:
				sc += float(mini(int(fx["guard"]), incoming - int(eng.fleur["guard"]))) * 0.7
			if fx.has("balance"):
				sc += float(eng.fleur["max"] - eng.fleur["balance"]) * 0.2
			if fx.has("panache"):
				sc += 0.5
			sc -= float(eng.card_def(c).get("cost", 1)) * 0.6
			if sc > best_score:
				best_score = sc
				best = c
		if best.is_empty() or best_score < 0.0:
			break
		eng.play(best["uid"])
	eng.end_turn()


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var s := Rules.new_state()
	for duel_id in Content.duel["duels"]:
		for setup_name in ["fresh", "practiced"]:
			var s2: Dictionary = s.duplicate(true)
			if setup_name == "practiced":
				s2["counters"] = {"duel:training": 3, "duel:honor": 1, "duel:street": 1}
			var tally := {}
			var turns := 0
			for k in 300:
				var eng := DuelEngine.new()
				eng.rng.seed = k * 7919 + 13
				eng.setup(duel_id, Content.duel, s2)
				for t in 40:
					if not eng.result.is_empty():
						break
					ai_turn(eng, "buttons")
				var o := str(eng.result.get("outcome", "none"))
				tally[o] = int(tally.get(o, 0)) + 1
				turns += int(eng.result.get("turns", 0))
			print("DUELSIM %s [%s]: %s, ходов в среднем %.1f" % [duel_id, setup_name, JSON.stringify(tally), turns / 300.0])
	get_tree().quit()
