extends Control
## Фехтовальный поединок (активность). Логика — в DuelEngine, здесь сцена, анимация и ввод.
## События движка проигрываются по очереди: выпад, удар, искры, перехват инициативы, раскрытие.
## Интерфейс активности: setup(params, queue_item), get_title(); по окончании — Game.finish_activity().

const KIND_COLOR := {"attack": Color("8c2a22"), "guard": Color("24486a"), "skill": Color("3c5a2a")}
const CONTEXT_TITLE := {"training": "Тренировка", "honor": "Дело чести", "street": "Схватка"}
const END_TITLE := {"win": "Победа", "clean": "Чистая победа", "disarm": "Обезоружен", "throat": "Клинок у горла",
	"humiliate": "Пуговицы на песке", "loss": "Поражение", "wound": "Ранен", "time": "Ничья", "yield": "Клинок опущен"}
const CARD_SIZE := Vector2(158, 214)
const STEEL := Color("dfe8f0")
const BLOOD := Color("e0482e")
const GOLD := Color("f5d98b")

var params: Dictionary = {}
var q: Dictionary = {}
var eng: DuelEngine
var duel_id := ""
var target_uid := -1

var bg_rect: TextureRect
var stage: Control
var fx: FxLayer
var enemy_row: HBoxContainer
var enemy_views: Dictionary = {}     # uid -> EnemyView
var init_coin: Control
var fleur_panel: Control
var hand_layer: Control
var hand_nodes: Array = []           # HandCard в руке, по порядку
var deck_pile: Control
var discard_pile: Control
var finisher_bar: HBoxContainer
var log_box: VBoxContainer
var end_btn: Button
var yield_btn: Button
var overlay: Control
var float_layer: Control
var banner: Control
var banner_label: Label
var flash: ColorRect
var bar_top: ColorRect
var bar_bottom: ColorRect

var fleur_disp := {"balance": 0.0, "guard": 0.0}
var disp_init := ""
var _coin_flip := 1.0
var _shake := 0.0
var _busy := false
var _t := 0.0
var _last_intents: Dictionary = {}


# ================================================================ эффекты поверх сцены

class FxLayer:
	extends Control
	var sparks: Array = []
	var slashes: Array = []
	var rings: Array = []
	var discs: Array = []
	var blades: Array = []
	var dust: Array = []
	var red := 0.0          # красная виньетка (удар по Флёру)
	var gold := 0.0         # золотое свечение (раскрытие противника)
	var danger := 0.0       # постоянная тревога, пока Флёр раскрыт

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for k in 34:
			dust.append({"p": Vector2(randf() * 1600, randf() * 900), "v": Vector2(randf_range(-6, 6), randf_range(-14, -4)), "r": randf_range(0.8, 2.2), "a": randf_range(0.08, 0.25)})

	func burst(p: Vector2, n: int, col: Color, speed := 380.0) -> void:
		for k in n:
			var a := randf() * TAU
			var v := Vector2.from_angle(a) * randf_range(speed * 0.35, speed)
			sparks.append({"p": p, "v": v, "life": randf_range(0.25, 0.55), "max": 0.55, "col": col})

	func slash(a: Vector2, b: Vector2, col: Color, w := 7.0, life := 0.32) -> void:
		slashes.append({"a": a, "b": b, "col": col, "w": w, "life": life, "max": life})

	func ring(c: Vector2, col: Color, r1 := 90.0, life := 0.45) -> void:
		rings.append({"c": c, "r1": r1, "col": col, "life": life, "max": life})

	func buttons(c: Vector2, n: int) -> void:
		for k in n:
			discs.append({"p": c + Vector2(randf_range(-30, 30), randf_range(-60, 40)), "v": Vector2(randf_range(-260, 260), randf_range(-420, -120)),
				"rot": randf() * TAU, "vr": randf_range(-12, 12), "life": 1.6})

	func blade(c: Vector2) -> void:
		blades.append({"p": c, "v": Vector2(randf_range(160, 260) * (1 if randf() < 0.5 else -1), -520), "rot": 0.0, "vr": 14.0, "life": 1.4})

	func _process(delta: float) -> void:
		var s := size if size.x > 10 else get_viewport_rect().size
		for d in dust:
			d["p"] += d["v"] * delta
			if d["p"].y < -10:
				d["p"] = Vector2(randf() * s.x, s.y + 10)
		for sp in sparks:
			sp["p"] += sp["v"] * delta
			sp["v"] *= 0.9
			sp["v"].y += 500 * delta
			sp["life"] -= delta
		sparks = sparks.filter(func(x): return x["life"] > 0)
		for sl in slashes:
			sl["life"] -= delta
		slashes = slashes.filter(func(x): return x["life"] > 0)
		for r in rings:
			r["life"] -= delta
		rings = rings.filter(func(x): return x["life"] > 0)
		for d in discs:
			d["p"] += d["v"] * delta
			d["v"].y += 900 * delta
			d["rot"] += d["vr"] * delta
			d["life"] -= delta
		discs = discs.filter(func(x): return x["life"] > 0)
		for b in blades:
			b["p"] += b["v"] * delta
			b["v"].y += 800 * delta
			b["rot"] += b["vr"] * delta
			b["life"] -= delta
		blades = blades.filter(func(x): return x["life"] > 0)
		red = maxf(0.0, red - delta * 1.6)
		gold = maxf(0.0, gold - delta * 1.2)
		queue_redraw()

	func _vignette(col: Color, strength: float) -> void:
		var s := size
		var c0 := Color(col, 0.0)
		var c1 := Color(col, strength)
		var e := minf(s.x, s.y) * 0.32
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), Vector2(s.x - e, e), Vector2(e, e)]), PackedColorArray([c1, c1, c0, c0]))
		draw_polygon(PackedVector2Array([Vector2(0, s.y), Vector2(e, s.y - e), Vector2(s.x - e, s.y - e), s]), PackedColorArray([c1, c0, c0, c1]))
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(e, e), Vector2(e, s.y - e), Vector2(0, s.y)]), PackedColorArray([c1, c0, c0, c1]))
		draw_polygon(PackedVector2Array([Vector2(s.x, 0), s, Vector2(s.x - e, s.y - e), Vector2(s.x - e, e)]), PackedColorArray([c1, c1, c0, c0]))

	func _draw() -> void:
		_vignette(Color.BLACK, 0.55)
		for d in dust:
			draw_circle(d["p"], d["r"], Color(1.0, 0.93, 0.75, d["a"]))
		if red > 0.0:
			_vignette(Color(0.85, 0.08, 0.04), red * 0.7)
		if danger > 0.0:
			_vignette(Color(0.7, 0.05, 0.02), danger * (0.25 + 0.12 * sin(Time.get_ticks_msec() * 0.006)))
		if gold > 0.0:
			_vignette(Color(1.0, 0.8, 0.35), gold * 0.45)
		for r in rings:
			var k: float = 1.0 - r["life"] / r["max"]
			draw_arc(r["c"], r["r1"] * (0.2 + 0.8 * k), 0, TAU, 48, Color(r["col"], 1.0 - k), 4.0 * (1.0 - k) + 1.0, true)
		for sl in slashes:
			var k: float = sl["life"] / sl["max"]
			var a: Vector2 = sl["a"]
			var b: Vector2 = sl["b"]
			var mid := a.lerp(b, 0.5) + (b - a).orthogonal().normalized() * 18.0
			var pts := PackedVector2Array()
			for i in 13:
				var tt := i / 12.0
				pts.append(a.lerp(mid, tt).lerp(mid.lerp(b, tt), tt))
			draw_polyline(pts, Color(sl["col"], 0.25 * k), sl["w"] * 3.0, true)
			draw_polyline(pts, Color(sl["col"], 0.9 * k), sl["w"] * k, true)
			draw_polyline(pts, Color(1, 1, 1, k), maxf(1.0, sl["w"] * 0.3 * k), true)
		for sp in sparks:
			var k: float = sp["life"] / sp["max"]
			var v: Vector2 = sp["v"]
			draw_line(sp["p"], sp["p"] - v * 0.035, Color(sp["col"], k), 2.0, true)
		for d in discs:
			var a := clampf(d["life"], 0.0, 1.0)
			draw_circle(d["p"], 7.0, Color(0.92, 0.88, 0.8, a))
			draw_arc(d["p"], 7.0, 0, TAU, 16, Color(0.5, 0.42, 0.3, a), 1.2, true)
			for h in [-1.0, 1.0]:
				draw_circle(d["p"] + Vector2.from_angle(d["rot"]) * 2.3 * h, 1.2, Color(0.4, 0.33, 0.25, a))
		for b in blades:
			var a := clampf(b["life"], 0.0, 1.0)
			var dir := Vector2.from_angle(b["rot"])
			draw_line(b["p"] - dir * 48, b["p"] + dir * 48, Color(STEEL, a), 3.0, true)
			draw_line(b["p"] - dir * 48, b["p"] - dir * 38, Color(0.75, 0.6, 0.3, a), 7.0, true)


# ================================================================ противник на сцене

class EnemyView:
	extends Control
	var e: Dictionary
	var eng: DuelEngine
	var selected := false
	var disp_bal := 0.0
	var disp_guard := 0.0
	var offset := Vector2.ZERO
	var zoom := 1.0
	var tilt := 0.0
	var flash_col := Color(1, 0.3, 0.2, 0.0)
	var stamp := 0.0        # 0 — нет штампа, 1 — лёг
	var intent_pop := 1.0
	var _tex: Texture2D
	var _t := 0.0
	signal chosen(uid: int)

	func _init(enemy: Dictionary, engine: DuelEngine) -> void:
		e = enemy
		eng = engine
		custom_minimum_size = Vector2(250, 384)
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		disp_bal = float(e["balance"])
		if str(e["pid"]) != "":
			_tex = Art.portrait(str(e["pid"]))

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			chosen.emit(e["uid"])

	func center_global() -> Vector2:
		return global_position + Vector2(size.x / 2, 190)

	func lunge() -> void:
		var tw := create_tween()
		tw.tween_property(self, "offset", Vector2(0, 60), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(self, "zoom", 1.12, 0.12)
		tw.tween_property(self, "offset", Vector2.ZERO, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(self, "zoom", 1.0, 0.28)

	func recoil(strong: bool) -> void:
		flash_col = Color(1, 0.25, 0.15, 0.6 if strong else 0.3)
		var tw := create_tween()
		tw.tween_property(self, "offset", Vector2(randf_range(-18, 18), -26 if strong else -12), 0.07)
		tw.parallel().tween_property(self, "tilt", randf_range(-0.12, 0.12), 0.07)
		tw.tween_property(self, "offset", Vector2.ZERO, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(self, "tilt", 0.0, 0.35)
		tw.parallel().tween_property(self, "flash_col:a", 0.0, 0.35)

	func clank() -> void:
		flash_col = Color(0.75, 0.88, 1.0, 0.45)
		create_tween().tween_property(self, "flash_col:a", 0.0, 0.3)

	func slam_stamp() -> void:
		stamp = 0.001
		create_tween().tween_property(self, "stamp", 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func pop_intent() -> void:
		var moods: Dictionary = e["def"].get("portrait_moods", {})
		if not moods.is_empty():
			var state := "open" if e["open"] else str(e["intent"].get("kind", ""))
			_tex = Art.portrait(str(e["pid"]), str(moods.get(state, "")))
		intent_pop = 0.4
		create_tween().tween_property(self, "intent_pop", 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func fall() -> void:
		var tw := create_tween()
		tw.tween_property(self, "tilt", 0.35, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(self, "offset", Vector2(30, 40), 0.5)
		tw.parallel().tween_property(self, "modulate:a", 0.45, 0.5)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c := Vector2(size.x / 2, 190)
		var dim := 0.4 if e["out"] else 1.0
		# намерение — над портретом
		draw_set_transform(Vector2(size.x / 2, 34), 0.0, Vector2.ONE * intent_pop)
		_draw_intent(Vector2.ZERO)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# портрет в овале: дышит, выпадает вперёд, отшатывается
		var breathe := 1.0 + sin(_t * 1.8 + float(e["uid"])) * 0.012
		draw_set_transform(c + offset, tilt, Vector2.ONE * zoom * breathe)
		var oval := PackedVector2Array()
		for k in 48:
			var a := TAU * k / 48
			oval.append(Vector2(cos(a) * 92, sin(a) * 118))
		var glow := 0.0
		if e["open"]:
			glow = 0.5 + 0.5 * sin(_t * 6.0)
			draw_colored_polygon(_scaled(oval, 1.12), Color(1.0, 0.75, 0.3, 0.18 + 0.15 * glow))
		if eng.intent_value(e) > 0 and str(e["intent"].get("kind", "")) in ["attack", "press", "decisive"]:
			draw_colored_polygon(_scaled(oval, 1.07), Color(0.9, 0.2, 0.1, 0.10 + 0.06 * sin(_t * 4.0)))
		draw_colored_polygon(oval, Color(0.08, 0.06, 0.05, 0.9))
		if _tex:
			var region := Art.cover_region(_tex, Vector2(184, 236))
			var uvs := PackedVector2Array()
			for p in oval:
				var lp := (p + Vector2(92, 118)) / Vector2(184, 236)
				uvs.append((region.position + lp * region.size) / _tex.get_size())
			draw_colored_polygon(oval, Color(dim, dim, dim, 1), uvs, _tex)
		else:
			draw_circle(Vector2(0, -30), 34, Color(0.28, 0.24, 0.22, dim))
			draw_colored_polygon(PackedVector2Array([Vector2(-60, 90), Vector2(60, 90), Vector2(40, 10), Vector2(-40, 10)]), Color(0.28, 0.24, 0.22, dim))
		if flash_col.a > 0.0:
			draw_colored_polygon(oval, flash_col)
		var rim := Color("f0d27a") if selected else Look.BRASS
		if e["open"]:
			rim = Color(1.0, 0.82, 0.4).lerp(Color.WHITE, glow * 0.5)
		draw_polyline(oval + PackedVector2Array([oval[0]]), rim, 4.0 if (selected or e["open"]) else 2.5, true)
		if e["open"] and stamp <= 0.0:
			stamp = 1.0
		if not e["open"]:
			stamp = 0.0
		if stamp > 0.0 and e["open"]:
			var sc := lerpf(2.4, 1.0, clampf(stamp, 0.0, 1.0))
			draw_set_transform(c + offset + Vector2(0, 40), -0.18, Vector2.ONE * sc)
			draw_rect(Rect2(-84, -22, 168, 44), Color(0.78, 0.12, 0.08, 0.9 * clampf(stamp, 0, 1)), false, 3.5)
			draw_string(Look.font("serif_bold"), Vector2(-84, 9), "РАСКРЫТ", HORIZONTAL_ALIGNMENT_CENTER, 168, 24, Color(0.9, 0.16, 0.1, clampf(stamp, 0, 1)))
		if e["out"]:
			draw_set_transform(c, -0.18, Vector2.ONE)
			draw_string(Look.font("serif_bold"), Vector2(-90, 8), "ВНЕ БОЯ", HORIZONTAL_ALIGNMENT_CENTER, 180, 22, Color(0.95, 0.88, 0.7, 0.95))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# имя и шкалы (без сдвигов, чтобы читались)
		Look.text_c(self, Look.font("serif_bold"), size.x / 2, 336, str(e["title"]), 19, Color(0.96, 0.9, 0.78, dim), size.x)
		var bar := Rect2(24, 345, size.x - 48, 12)
		draw_rect(bar, Color(0, 0, 0, 0.6))
		var real := float(e["balance"]) / maxf(1.0, float(e["max"]))
		var shown := disp_bal / maxf(1.0, float(e["max"]))
		if shown > real:
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * shown, bar.size.y)), Color(0.95, 0.9, 0.75, 0.8))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * minf(real, shown), bar.size.y)), Color("c8a14e") if not e["open"] else Color("b03a2a"))
		draw_rect(bar, Look.BRASS_DARK, false, 1.0)
		Look.text_c(self, Look.font("sans"), size.x / 2, 374, "равновесие %d / %d" % [int(round(disp_bal)), e["max"]], 12, Color(0.92, 0.86, 0.72, dim), size.x)
		if disp_guard > 0.5:
			_shield(Vector2(size.x - 40, 290), int(round(disp_guard)))

	func _scaled(pts: PackedVector2Array, k: float) -> PackedVector2Array:
		var out := PackedVector2Array()
		for p in pts:
			out.append(p * k)
		return out

	func _shield(p: Vector2, n: int) -> void:
		var pts := PackedVector2Array([p + Vector2(-18, -20), p + Vector2(18, -20), p + Vector2(16, 6), p + Vector2(0, 22), p + Vector2(-16, 6)])
		draw_colored_polygon(pts, Color("2e4f6e"))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color("c9d7e2"), 2.0, true)
		Look.text_c(self, Look.font("serif_bold"), p.x, p.y + 7, str(n), 17, Color.WHITE, 40)

	func _draw_intent(p: Vector2) -> void:
		if e["out"]:
			return
		var it: Dictionary = e["intent"]
		var kind := str(it.get("kind", ""))
		var col := Color("efe3c4")
		var glyph := "•"
		var num := ""
		match kind:
			"attack", "press":
				col = Color("f2c1a8")
				glyph = "⚔"
				num = str(eng.intent_value(e)) + ((" ×%d" % int(it.get("count", 1))) if int(it.get("count", 1)) > 1 else "")
			"counter":
				col = Color("f3d68a")
				glyph = "↺"
				num = str(eng.intent_value(e))
			"guard":
				col = Color("c9d7e2")
				glyph = "⛨"
				num = str(it.get("n", "")) if int(it.get("n", 0)) > 0 else ""
			"feint":
				col = Color("d9c9f0")
				glyph = "≈"
			"taunt":
				col = Color("f2b38a")
				glyph = "!"
			"recover":
				col = Color("bfe0c0")
				glyph = "…"
			"decisive":
				col = Color(1.0, 0.42 + 0.2 * sin(_t * 8.0), 0.3)
				glyph = "✦"
		var label := str(it.get("label", ""))
		var text := "%s %s  %s" % [glyph, num, label] if num != "" else "%s  %s" % [glyph, label]
		var f := Look.font("serif_bold")
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 26
		var r := Rect2(p - Vector2(w / 2, 18), Vector2(w, 34))
		draw_colored_polygon(Look.rrect(r, 8), Color(0.07, 0.05, 0.04, 0.9))
		draw_polyline(Look.rrect(r, 8), col, 2.0, true)
		draw_string(f, r.position + Vector2(0, 24), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 17, col)


# ================================================================ карта приёма в руке

class HandCard:
	extends Control
	var c: Dictionary
	var d: Dictionary
	var playable := true
	var home := Vector2.ZERO
	var home_rot := 0.0
	var hover := false
	var glow := 0.0
	signal play(uid: int)
	signal hovered(card)

	func _init(card: Dictionary, def_: Dictionary) -> void:
		c = card
		d = def_
		size = CARD_SIZE
		pivot_offset = CARD_SIZE / 2
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func():
			hover = true
			hovered.emit(self))
		mouse_exited.connect(func():
			hover = false
			hovered.emit(self))

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and playable:
			play.emit(c["uid"])

	func _process(delta: float) -> void:
		var target := 1.0 if (hover and playable) else 0.0
		glow = lerpf(glow, target, 1.0 - exp(-12.0 * delta))
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2(4, 4), size - Vector2(8, 8))
		var shape := Look.rrect(r, 8)
		if glow > 0.02:
			var kc0: Color = KIND_COLOR.get(str(d.get("kind", "skill")), Color("555555"))
			draw_colored_polygon(Look.rrect(r.grow(6), 12), Color(kc0.lightened(0.5), 0.35 * glow))
		Look.soft_shadow(self, shape, Vector2(2, 6 + glow * 8), 6, 0.6)
		var a := 1.0 if playable else 0.55
		Look.fill_v(self, shape, Color(0.97, 0.93, 0.84, a), Color(0.88, 0.81, 0.68, a))
		var kc: Color = KIND_COLOR.get(str(d.get("kind", "skill")), Color("555555"))
		draw_rect(Rect2(r.position + Vector2(0, 46), Vector2(r.size.x, 4)), kc)
		Look.outline(self, shape, Color(0.35, 0.25, 0.12, 0.8), 1.5)
		var cc := r.position + Vector2(20, 20)
		draw_circle(cc, 16, Look.BRASS_DARK)
		draw_circle(cc, 13, Look.BRASS if playable else Color(0.45, 0.4, 0.35))
		Look.text_c(self, Look.font("serif_bold"), cc.x, cc.y + 7, str(int(d.get("cost", 1))), 19, Color("2a1c0c"), 30)
		draw_multiline_string(Look.font("serif_bold"), r.position + Vector2(40, 26), str(d.get("title", "")), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 46, 15, 2, Look.INK)
		draw_multiline_string(Look.font("serif"), r.position + Vector2(10, 74), str(d.get("text", "")), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 20, 13, 8, Look.INK)
		# значок рода приёма
		var ic := r.position + Vector2(r.size.x / 2, r.size.y - 26)
		match str(d.get("kind", "")):
			"attack":
				draw_line(ic + Vector2(-16, 10), ic + Vector2(16, -10), Color(kc, 0.55), 3.0, true)
				draw_line(ic + Vector2(-12, 4), ic + Vector2(-6, 14), Color(kc, 0.55), 3.0, true)
			"guard":
				var sh := PackedVector2Array([ic + Vector2(-12, -12), ic + Vector2(12, -12), ic + Vector2(10, 4), ic + Vector2(0, 14), ic + Vector2(-10, 4)])
				draw_polyline(sh + PackedVector2Array([sh[0]]), Color(kc, 0.55), 2.5, true)
			_:
				draw_arc(ic, 11, 0, TAU, 24, Color(kc, 0.55), 2.5, true)


# ================================================================ построение

func setup(p: Dictionary, queue_item: Dictionary) -> void:
	params = p
	q = queue_item
	duel_id = str(p.get("duel", "clorinde_training"))
	eng = DuelEngine.new()
	eng.setup(duel_id, Content.duel, Game.state)
	fleur_disp = {"balance": float(eng.fleur["balance"]), "guard": 0.0}


func get_title() -> String:
	return str(eng.def.get("title", "Поединок"))


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Sound.environment("backgrounds", str(eng.def.get("bg", "practice")), Rules.phase_key(Game.state), "", "off")
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	bg_rect = TextureRect.new()
	bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_rect.texture = Art.background(str(eng.def.get("bg", "practice")))
	if bg_rect.texture == null:
		bg_rect.texture = Art.background("city")
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_rect)
	var dark := ColorRect.new()
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark.color = Color(0.03, 0.02, 0.02, 0.55)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dark)

	stage = Control.new()
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)

	var title := Label.new()
	title.position = Vector2(40, 24)
	title.add_theme_font_override("font", Look.font("serif"))
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("f0e4c7"))
	title.text = get_title()
	stage.add_child(title)
	var sub := Label.new()
	sub.position = Vector2(42, 60)
	sub.add_theme_font_override("font", Look.font("serif_italic"))
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", Color("cdbf9f"))
	sub.text = CONTEXT_TITLE.get(eng.context, "")
	stage.add_child(sub)

	enemy_row = HBoxContainer.new()
	enemy_row.add_theme_constant_override("separation", 40)
	enemy_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stage.add_child(enemy_row)
	for e in eng.enemies:
		var v := EnemyView.new(e, eng)
		v.chosen.connect(_choose_target)
		enemy_row.add_child(v)
		enemy_views[e["uid"]] = v
		_last_intents[e["uid"]] = str(e["intent"])

	init_coin = Control.new()
	init_coin.size = Vector2(300, 64)
	init_coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	init_coin.draw.connect(_draw_coin)
	stage.add_child(init_coin)

	fleur_panel = Control.new()
	fleur_panel.size = Vector2(300, 220)
	fleur_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fleur_panel.draw.connect(_draw_fleur)
	stage.add_child(fleur_panel)

	deck_pile = _pile(true)
	stage.add_child(deck_pile)
	discard_pile = _pile(false)
	stage.add_child(discard_pile)

	finisher_bar = HBoxContainer.new()
	finisher_bar.add_theme_constant_override("separation", 14)
	finisher_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	stage.add_child(finisher_bar)

	log_box = VBoxContainer.new()
	log_box.add_theme_constant_override("separation", 4)
	stage.add_child(log_box)

	end_btn = _brass_button("Конец хода")
	end_btn.pressed.connect(_end_turn)
	stage.add_child(end_btn)
	yield_btn = _brass_button("Опустить клинок", true)
	yield_btn.tooltip_text = "Признать поединок. Иногда это самый умный исход."
	yield_btn.pressed.connect(func():
		if _busy or not eng.result.is_empty():
			return
		eng.yield_duel()
		_playback())
	stage.add_child(yield_btn)

	hand_layer = Control.new()
	hand_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	hand_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hand_layer)

	fx = FxLayer.new()
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fx)
	float_layer = Control.new()
	float_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	float_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(float_layer)

	bar_top = ColorRect.new()
	bar_top.color = Color.BLACK
	bar_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar_top)
	bar_bottom = ColorRect.new()
	bar_bottom.color = Color.BLACK
	bar_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar_bottom)

	banner = Control.new()
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.modulate.a = 0.0
	banner.draw.connect(func():
		var w := banner.size.x
		banner.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, banner.size.y), Vector2(0, banner.size.y)]),
			PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]))
		var mid := Rect2(w * 0.15, 0, w * 0.7, banner.size.y)
		banner.draw_polygon(PackedVector2Array([mid.position, Vector2(mid.end.x, mid.position.y), mid.end, Vector2(mid.position.x, mid.end.y)]),
			PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]))
		for x in range(0, int(w), 4):
			var k := 1.0 - absf(x / w - 0.5) * 2.0
			banner.draw_line(Vector2(x, 0), Vector2(x, banner.size.y), Color(0.05, 0.03, 0.02, 0.8 * k), 4.0)
		banner.draw_line(Vector2(w * 0.2, 2), Vector2(w * 0.8, 2), Color(GOLD, 0.6), 1.5)
		banner.draw_line(Vector2(w * 0.2, banner.size.y - 2), Vector2(w * 0.8, banner.size.y - 2), Color(GOLD, 0.6), 1.5))
	add_child(banner)
	banner_label = Label.new()
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner_label.add_theme_font_override("font", Look.font("serif"))
	banner_label.add_theme_font_size_override("font_size", 40)
	banner_label.add_theme_color_override("font_color", Color("f4e8ca"))
	banner.add_child(banner_label)

	flash = ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1, 1, 1, 0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)

	resized.connect(_layout)
	_layout()
	_refresh()
	_show_intro()


func _layout() -> void:
	var s := _screen()
	bg_rect.size = s * 1.1
	bg_rect.position = -s * 0.05
	bg_rect.pivot_offset = bg_rect.size / 2
	enemy_row.position = Vector2(0, 70)
	enemy_row.size = Vector2(s.x, 384)
	init_coin.position = Vector2(s.x / 2 - 110, 456)
	fleur_panel.position = Vector2(30, s.y - 240)
	finisher_bar.position = Vector2(340, s.y - 330)
	finisher_bar.size = Vector2(s.x - 680, 60)
	log_box.position = Vector2(s.x - 330, 110)
	log_box.size = Vector2(300, 300)
	deck_pile.position = Vector2(350, s.y - 130)
	discard_pile.position = Vector2(s.x - 410, s.y - 130)
	end_btn.position = Vector2(s.x - 300, s.y - 160)
	yield_btn.position = Vector2(s.x - 300, s.y - 96)
	banner.position = Vector2(0, s.y * 0.42 - 45)
	banner.size = Vector2(s.x, 90)
	banner_label.size = banner.size
	bar_top.size = Vector2(s.x, 0)
	bar_bottom.position = Vector2(0, s.y)
	bar_bottom.size = Vector2(s.x, 0)
	_fan(false)


func _screen() -> Vector2:
	return size if size.x > 10 else get_viewport_rect().size


func _pile(is_deck: bool) -> Control:
	var p := Control.new()
	p.size = Vector2(64, 88)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.draw.connect(func():
		var n: int = eng.deck.size() if is_deck else eng.discard.size()
		for k in mini(n, 5):
			var r := Rect2(Vector2(k * 1.5, -k * 1.5), p.size)
			p.draw_colored_polygon(Look.rrect(r, 5), Color("5a2a22") if is_deck else Color("3a3530"))
			p.draw_polyline(Look.rrect(r, 5), Look.BRASS_DARK, 1.2, true)
		if n == 0:
			p.draw_polyline(Look.rrect(Rect2(Vector2.ZERO, p.size), 5), Color(0.6, 0.5, 0.35, 0.4), 1.0, true)
		Look.text_c(p, Look.font("serif_bold"), p.size.x / 2, p.size.y / 2 + 8, str(n), 22, Color("f0e4c7"), 60)
		Look.text_c(p, Look.font("serif_italic"), p.size.x / 2, p.size.y + 18, "колода" if is_deck else "сброс", 13, Color("d8caa8"), 90))
	return p


func _brass_button(text: String, quiet := false) -> Button:
	var b := Button.new()
	b.text = text
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("b8924f") if not quiet else Color(0.2, 0.15, 0.1, 0.8)
	sb.border_color = Color("5a4120") if not quiet else Color("8a7048")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(1, 3)
	var sh := sb.duplicate() as StyleBoxFlat
	sh.bg_color = sb.bg_color.lightened(0.15)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sh)
	b.add_theme_stylebox_override("pressed", sh)
	b.add_theme_stylebox_override("focus", sh)
	var sd := sb.duplicate() as StyleBoxFlat
	sd.bg_color = sb.bg_color.darkened(0.35)
	b.add_theme_stylebox_override("disabled", sd)
	var fc := Color("2a1c0c") if not quiet else Color("e6d6b0")
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, fc)
	b.add_theme_color_override("font_disabled_color", Color(fc, 0.5))
	b.add_theme_font_override("font", Look.font("serif_bold"))
	b.add_theme_font_size_override("font_size", 18 if not quiet else 15)
	b.custom_minimum_size = Vector2(240, 0)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


# ================================================================ кадр

func _process(delta: float) -> void:
	_t += delta
	# фон медленно дышит — сцена не стоит на месте
	bg_rect.scale = Vector2.ONE * (1.0 + 0.015 * sin(_t * 0.15))
	bg_rect.position = -_screen() * 0.05 + Vector2(sin(_t * 0.09) * 14, cos(_t * 0.07) * 8)
	if _shake > 0.05:
		stage.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
		hand_layer.position = stage.position * 0.6
		_shake = lerpf(_shake, 0.0, 1.0 - exp(-10.0 * delta))
	elif stage.position != Vector2.ZERO:
		stage.position = Vector2.ZERO
		hand_layer.position = Vector2.ZERO
	fx.danger = lerpf(fx.danger, 1.0 if eng.fleur["open"] and eng.result.is_empty() else 0.0, 1.0 - exp(-4.0 * delta))
	if eng.any_open() and eng.result.is_empty():
		for b in finisher_bar.get_children():
			if b is Button and not b.disabled:
				b.modulate = Color(1, 1, 1).lerp(Color(1.25, 1.1, 0.8), 0.5 + 0.5 * sin(_t * 5.0))
	init_coin.queue_redraw()
	fleur_panel.queue_redraw()


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _flash(col: Color, peak := 0.5, dur := 0.25) -> void:
	flash.color = Color(col, peak)
	create_tween().tween_property(flash, "color:a", 0.0, dur)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


# ================================================================ панели

func _draw_coin() -> void:
	var who := disp_init
	var c := Vector2(32, 32)
	var col := Look.BRASS if who != "" else Color(0.4, 0.35, 0.3)
	init_coin.draw_set_transform(c, 0.0, Vector2(absf(_coin_flip), 1.0))
	init_coin.draw_circle(Vector2.ZERO, 26, Look.BRASS_DARK)
	init_coin.draw_circle(Vector2.ZERO, 22, col)
	init_coin.draw_arc(Vector2.ZERO, 18, 0, TAU, 32, Color(1, 0.95, 0.75, 0.4), 1.2, true)
	Look.text_c(init_coin, Look.font("serif_bold"), 0, 8, "↑" if who == "enemy" else ("↓" if who == "fleur" else "·"), 22, Color("2a1c0c"), 40)
	init_coin.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var t := "Инициатива у Флёра" if who == "fleur" else ("Инициатива у противника" if who == "enemy" else "Инициатива ничья")
	init_coin.draw_string(Look.font("serif_italic"), Vector2(66, 30), t, HORIZONTAL_ALIGNMENT_LEFT, 240, 15, Color("efe3c4"))
	init_coin.draw_string(Look.font("sans"), Vector2(66, 48), "у кого она — бьёт на 2 сильнее", HORIZONTAL_ALIGNMENT_LEFT, 260, 11, Color(0.85, 0.78, 0.62, 0.7))


func _draw_fleur() -> void:
	var f: Dictionary = eng.fleur
	var p := fleur_panel
	var box := Look.rrect(Rect2(0, 0, p.size.x, p.size.y), 10)
	p.draw_colored_polygon(box, Color(0.07, 0.05, 0.04, 0.85))
	var rim := Look.BRASS_DARK
	if f["open"] and eng.result.is_empty():
		rim = Color(1.0, 0.3, 0.2).lerp(Look.BRASS_DARK, 0.5 + 0.5 * sin(_t * 6.0))
	p.draw_polyline(box + PackedVector2Array([box[0]]), rim, 2.5, true)
	p.draw_string(Look.font("serif_bold"), Vector2(18, 34), "Флёр", HORIZONTAL_ALIGNMENT_LEFT, 200, 22, Color("f0e4c7"))
	if f["open"]:
		p.draw_string(Look.font("serif_bold"), Vector2(110, 34), "РАСКРЫТ", HORIZONTAL_ALIGNMENT_LEFT, 200, 18, Color("ff6a50"))
	var bar := Rect2(18, 50, p.size.x - 36, 14)
	p.draw_rect(bar, Color(0, 0, 0, 0.6))
	var real := float(f["balance"]) / maxf(1.0, float(f["max"]))
	var shown := float(fleur_disp["balance"]) / maxf(1.0, float(f["max"]))
	if shown > real:
		p.draw_rect(Rect2(bar.position, Vector2(bar.size.x * shown, bar.size.y)), Color(1.0, 0.75, 0.65, 0.8))
	p.draw_rect(Rect2(bar.position, Vector2(bar.size.x * minf(real, shown), bar.size.y)), Color("c8a14e") if not f["open"] else Color("b03a2a"))
	p.draw_rect(bar, Look.BRASS_DARK, false, 1.0)
	p.draw_string(Look.font("sans"), Vector2(18, 82), "Равновесие %d / %d" % [int(round(float(fleur_disp["balance"]))), f["max"]], HORIZONTAL_ALIGNMENT_LEFT, 200, 13, Color("e6d6b0"))
	var g := int(round(float(fleur_disp["guard"])))
	p.draw_string(Look.font("sans"), Vector2(180, 82), "Защита %d" % g, HORIZONTAL_ALIGNMENT_LEFT, 120, 13, Color("c9d7e2") if g > 0 else Color(0.6, 0.65, 0.7))
	p.draw_string(Look.font("sans"), Vector2(18, 112), "Силы", HORIZONTAL_ALIGNMENT_LEFT, 80, 13, Color("e6d6b0"))
	for k in maxi(eng.energy, DuelEngine.ENERGY):
		var cc := Vector2(80 + k * 30, 107)
		var on: bool = k < eng.energy
		if on:
			p.draw_circle(cc, 13 + sin(_t * 3.0 + k) * 0.8, Color(1.0, 0.85, 0.4, 0.18))
		p.draw_circle(cc, 11, Look.BRASS_DARK)
		p.draw_circle(cc, 9, Color("f0c860") if on else Color(0.25, 0.2, 0.15))
	p.draw_string(Look.font("sans"), Vector2(18, 144), "Блеск", HORIZONTAL_ALIGNMENT_LEFT, 80, 13, Color("e6d6b0"))
	for k in 10:
		var cc := Vector2(80 + k * 20, 139)
		var lit: bool = k < int(f["panache"])
		var sc := 1.0 + (0.15 * sin(_t * 5.0 + k) if lit else 0.0)
		var dia := PackedVector2Array([cc + Vector2(0, -7) * sc, cc + Vector2(6, 0) * sc, cc + Vector2(0, 7) * sc, cc + Vector2(-6, 0) * sc])
		p.draw_colored_polygon(dia, GOLD if lit else Color(0.25, 0.2, 0.15))
	var notes := PackedStringArray()
	if int(f["prepared"]) > 0:
		notes.append("следующий удар +%d" % f["prepared"])
	if f["feint"]:
		notes.append("финт: сквозь защиту")
	if int(f["counter"]) > 0:
		notes.append("контратака %d" % f["counter"])
	if int(f["wounds"]) > 0:
		notes.append("ранен")
	p.draw_string(Look.font("serif_italic"), Vector2(18, 178), ", ".join(notes), HORIZONTAL_ALIGNMENT_LEFT, p.size.x - 30, 13, Color("f3d68a"))
	p.draw_string(Look.font("sans"), Vector2(18, 204), "Ход %d из %d" % [eng.turn, int(eng.def.get("max_rounds", 10))], HORIZONTAL_ALIGNMENT_LEFT, 200, 12, Color(0.85, 0.78, 0.62, 0.7))


# ================================================================ рука

func _hand_slot(i: int, n: int) -> Array:
	var s := _screen()
	var mid := (n - 1) / 2.0
	var step := minf(116.0, 560.0 / maxf(1.0, n - 1)) if n > 1 else 0.0
	var x := s.x / 2 + (i - mid) * step - CARD_SIZE.x / 2
	var y := s.y - 228 + pow(absf(i - mid), 2.0) * 7.0
	return [Vector2(x, y), (i - mid) * 0.055]


func _fan(animate := true) -> void:
	var n := hand_nodes.size()
	for i in n:
		var hc: HandCard = hand_nodes[i]
		var slot := _hand_slot(i, n)
		hc.home = slot[0]
		hc.home_rot = slot[1]
		if animate:
			var tw := hc.create_tween().set_parallel()
			tw.tween_property(hc, "position", hc.home, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(hc, "rotation", hc.home_rot, 0.25)
			tw.tween_property(hc, "scale", Vector2.ONE, 0.25)
		else:
			hc.position = hc.home
			hc.rotation = hc.home_rot


func _on_card_hover(hc: HandCard) -> void:
	if _busy or not is_instance_valid(hc):
		return
	var tw := hc.create_tween().set_parallel()
	if hc.hover:
		hand_layer.move_child(hc, -1)
		tw.tween_property(hc, "position", hc.home + Vector2(0, -42), 0.12).set_ease(Tween.EASE_OUT)
		tw.tween_property(hc, "rotation", 0.0, 0.12)
		tw.tween_property(hc, "scale", Vector2.ONE * 1.12, 0.12)
	else:
		tw.tween_property(hc, "position", hc.home, 0.15)
		tw.tween_property(hc, "rotation", hc.home_rot, 0.15)
		tw.tween_property(hc, "scale", Vector2.ONE, 0.15)
		var idx := hand_nodes.find(hc)
		if idx >= 0:
			hand_layer.move_child(hc, idx)


func _deal(animate := true) -> void:
	for hc in hand_nodes:
		if is_instance_valid(hc):
			hc.queue_free()
	hand_nodes.clear()
	var n := eng.hand.size()
	var from := deck_pile.global_position - hand_layer.global_position
	for i in n:
		var c: Dictionary = eng.hand[i]
		var hc := HandCard.new(c, eng.card_def(c))
		hc.playable = eng.can_play(c)
		hc.play.connect(_play)
		hc.hovered.connect(_on_card_hover)
		hand_layer.add_child(hc)
		hand_nodes.append(hc)
		var slot := _hand_slot(i, n)
		hc.home = slot[0]
		hc.home_rot = slot[1]
		if animate:
			hc.position = from
			hc.scale = Vector2.ONE * 0.4
			hc.rotation = -0.6
			hc.modulate.a = 0.0
			var tw := hc.create_tween()
			tw.tween_interval(0.07 * i)
			tw.tween_property(hc, "modulate:a", 1.0, 0.05)
			tw.parallel().tween_property(hc, "position", hc.home, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(hc, "rotation", hc.home_rot, 0.35)
			tw.parallel().tween_property(hc, "scale", Vector2.ONE, 0.35)
		else:
			hc.position = hc.home
			hc.rotation = hc.home_rot
	deck_pile.queue_redraw()


func _sync_playable() -> void:
	for hc in hand_nodes:
		if is_instance_valid(hc):
			hc.playable = eng.can_play(hc.c) and not _busy


func _discard_hand() -> void:
	var to := discard_pile.global_position - hand_layer.global_position
	var i := 0
	for node in hand_nodes:
		if not is_instance_valid(node):
			continue
		var hc: HandCard = node
		var tw := hc.create_tween()
		tw.tween_interval(0.04 * i)
		tw.tween_property(hc, "position", to, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(hc, "scale", Vector2.ONE * 0.35, 0.28)
		tw.parallel().tween_property(hc, "rotation", 0.8, 0.28)
		tw.tween_callback(hc.queue_free)
		i += 1
	hand_nodes.clear()


# ================================================================ обновление

func _refresh() -> void:
	for uid in enemy_views:
		var v: EnemyView = enemy_views[uid]
		v.selected = uid == _target() and eng.alive().size() > 1
		var key := str(v.e["intent"])
		if _last_intents.get(uid, "") != key:
			_last_intents[uid] = key
			v.pop_intent()
	_sync_playable()
	for c in finisher_bar.get_children():
		c.queue_free()
	if eng.any_open() and eng.result.is_empty():
		var lbl := Label.new()
		lbl.text = "Решающий приём:"
		lbl.add_theme_font_override("font", Look.font("serif_italic"))
		lbl.add_theme_font_size_override("font_size", 17)
		lbl.add_theme_color_override("font_color", GOLD)
		finisher_bar.add_child(lbl)
		for f in eng.def.get("finishers", []):
			var ok: bool = int(eng.fleur["panache"]) >= int(f.get("panache", 0))
			var b := _brass_button(str(f["title"]))
			b.custom_minimum_size = Vector2(170, 0)
			b.tooltip_text = str(f.get("text", ""))
			b.disabled = not ok or _busy
			if not ok:
				b.text += "  (Блеск %d)" % int(f.get("panache", 0))
			var fid := str(f["id"])
			b.pressed.connect(func():
				if _busy:
					return
				eng.finish_with(fid, _open_target())
				_playback())
			finisher_bar.add_child(b)
			b.scale = Vector2(0.6, 0.6)
			b.pivot_offset = Vector2(85, 20)
			b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	end_btn.disabled = not eng.result.is_empty() or _busy
	yield_btn.disabled = not eng.result.is_empty() or _busy
	deck_pile.queue_redraw()
	discard_pile.queue_redraw()


func _settle_displays(dur := 0.35) -> void:
	## Плавно довести показанные цифры до настоящих (восстановление, сброс защиты в начале хода).
	for uid in enemy_views:
		var v: EnemyView = enemy_views[uid]
		var tw := v.create_tween().set_parallel()
		tw.tween_property(v, "disp_bal", float(v.e["balance"]), dur)
		tw.tween_property(v, "disp_guard", float(v.e["guard"]), dur)
	var tw2 := create_tween().set_parallel()
	tw2.tween_method(func(x): fleur_disp["balance"] = x, float(fleur_disp["balance"]), float(eng.fleur["balance"]), dur)
	tw2.tween_method(func(x): fleur_disp["guard"] = x, float(fleur_disp["guard"]), float(eng.fleur["guard"]), dur)
	if disp_init != eng.initiative:
		_flip_coin(eng.initiative)


func _target() -> int:
	var alive := eng.alive()
	for e in alive:
		if e["uid"] == target_uid:
			return target_uid
	return alive[0]["uid"] if alive.size() > 0 else -1


func _open_target() -> int:
	var t := _target()
	for e in eng.alive():
		if e["uid"] == t and e["open"]:
			return t
	for e in eng.alive():
		if e["open"]:
			return e["uid"]
	return -1


func _choose_target(uid: int) -> void:
	target_uid = uid
	_refresh()


# ================================================================ ход игрока

func _play(uid: int) -> void:
	if _busy or not eng.result.is_empty():
		return
	var hc: HandCard = null
	for h in hand_nodes:
		if is_instance_valid(h) and h.c["uid"] == uid:
			hc = h
	if hc == null or not eng.can_play(hc.c):
		return
	_busy = true
	_sync_playable()
	var d := eng.card_def(hc.c)
	var tgt := _target()
	var v: EnemyView = enemy_views.get(tgt)
	var aim: Vector2
	if eng.needs_target(hc.c) and v:
		aim = v.center_global() - hand_layer.global_position - CARD_SIZE / 2
	else:
		aim = fleur_panel.global_position + Vector2(150, -40) - hand_layer.global_position - CARD_SIZE / 2
	hand_nodes.erase(hc)
	hand_layer.move_child(hc, -1)
	# карта взлетает и уходит в цель
	var tw := hc.create_tween()
	tw.tween_property(hc, "position", hc.position + Vector2(0, -60), 0.1).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(hc, "scale", Vector2.ONE * 1.15, 0.1)
	tw.parallel().tween_property(hc, "rotation", 0.0, 0.1)
	tw.tween_property(hc, "position", aim, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(hc, "scale", Vector2.ONE * 0.45, 0.2)
	tw.tween_property(hc, "modulate:a", 0.0, 0.1)
	await tw.finished
	var kc: Color = KIND_COLOR.get(str(d.get("kind", "skill")), Color.WHITE)
	fx.ring(hc.global_position + CARD_SIZE * 0.225 - fx.global_position, kc.lightened(0.5), 70.0, 0.35)
	hc.queue_free()
	_fan(true)
	eng.play(uid, tgt)
	await _playback()
	_busy = false
	_refresh()


func _end_turn() -> void:
	if _busy or not eng.result.is_empty():
		return
	_busy = true
	_refresh()
	_discard_hand()
	await _wait(0.3)
	discard_pile.queue_redraw()
	eng.end_turn()
	await _banner("Ход противника", Color("f2c1a8"))
	await _playback()
	if eng.result.is_empty():
		await _banner("Ваш ход", Color("f4e8ca"))
		_deal(true)
		await _wait(0.35)
	_busy = false
	_refresh()


func _banner(text: String, col: Color) -> void:
	banner_label.text = text
	banner_label.add_theme_color_override("font_color", col)
	banner.queue_redraw()
	banner.scale = Vector2(1.0, 0.3)
	banner.pivot_offset = banner.size / 2
	var tw := create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.14)
	tw.parallel().tween_property(banner, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.45)
	tw.tween_property(banner, "modulate:a", 0.0, 0.2)
	await tw.finished


func _flip_coin(to: String) -> void:
	var tw := create_tween()
	tw.tween_property(self, "_coin_flip", 0.0, 0.1)
	tw.tween_callback(func(): disp_init = to)
	tw.tween_property(self, "_coin_flip", 1.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	fx.ring(init_coin.global_position + Vector2(32, 32) - fx.global_position, GOLD, 60.0, 0.4)


# ================================================================ проигрывание событий

## Мгновенная синхронизация без анимаций (её зовёт автопроверка после своих ходов).
func _after_action() -> void:
	for ev in eng.events:
		if str(ev.get("text", "")) != "":
			_log(str(ev["text"]), str(ev["kind"]))
	eng.events.clear()
	for uid in enemy_views:
		enemy_views[uid].disp_bal = float(enemy_views[uid].e["balance"])
		enemy_views[uid].disp_guard = float(enemy_views[uid].e["guard"])
	fleur_disp = {"balance": float(eng.fleur["balance"]), "guard": float(eng.fleur["guard"])}
	disp_init = eng.initiative
	_deal(false)
	_refresh()
	if not eng.result.is_empty():
		_show_end()


func _playback() -> void:
	var list: Array = eng.events.duplicate()
	eng.events.clear()
	var fcenter := fleur_panel.global_position + Vector2(150, 40) - fx.global_position
	for ev in list:
		var text := str(ev.get("text", ""))
		var v: EnemyView = enemy_views.get(ev.get("target", -1))
		var vc := (v.center_global() - fx.global_position) if v else Vector2.ZERO
		match str(ev["kind"]):
			"act":
				if v:
					match str(ev.get("intent", "")):
						"attack", "press", "decisive":
							v.lunge()
							await _wait(0.12)
						"guard":
							fx.ring(vc, Color("c9d7e2"), 120.0)
							await _wait(0.2)
						"taunt":
							fx.ring(vc, Color("f2b38a"), 140.0)
							_float(vc + Vector2(0, -80), "!", Color("f2b38a"), 46)
							await _wait(0.3)
						"recover":
							fx.ring(vc, Color("bfe0c0"), 110.0)
							await _wait(0.2)
			"hit":
				if v:
					Sound.play("blades", -3.0)
					var through := int(ev["amount"])
					var absorbed := int(ev.get("absorbed", 0))
					var dir := Vector2.from_angle(randf_range(-0.6, 0.6) + (PI if randf() < 0.5 else 0.0))
					fx.slash(vc - dir * 110 + Vector2(0, -20), vc + dir * 110 + Vector2(0, 20), STEEL, 8.0)
					v.disp_guard = maxf(0.0, v.disp_guard - absorbed)
					v.disp_bal = maxf(0.0, v.disp_bal - through)
					if through > 0:
						v.recoil(through >= 8)
						fx.burst(vc, 10 + through, Color(1.0, 0.6, 0.4))
						shake(3.0 + through * 0.4)
						_float(vc + Vector2(0, -60), "−%d" % through, Color("ffb08a"), 30 + mini(through, 14))
					else:
						v.clank()
						fx.burst(vc + Vector2(randf_range(-40, 40), -20), 18, Color(0.85, 0.92, 1.0), 460.0)
						_float(vc + Vector2(0, -60), "отбито", Color("c9d7e2"), 26)
					await _wait(0.26)
			"hit_fleur":
				Sound.play("blades", -3.0)
				var through2 := int(ev["amount"])
				fleur_disp["guard"] = maxf(0.0, float(fleur_disp["guard"]) - int(ev.get("absorbed", 0)))
				fleur_disp["balance"] = maxf(0.0, float(fleur_disp["balance"]) - through2)
				fx.slash(fcenter + Vector2(-140, -80), fcenter + Vector2(140, 60), Color(1.0, 0.5, 0.4) if through2 > 0 else STEEL, 9.0)
				if through2 > 0:
					shake(6.0 + through2 * 0.6)
					fx.red = minf(0.75, 0.3 + through2 * 0.04)
					fx.burst(fcenter, 12 + through2, Color(1.0, 0.45, 0.3))
					_float(fcenter + Vector2(0, -70), "−%d" % through2, Color("ff8a70"), 30 + mini(through2, 14))
					_panel_jolt()
				else:
					fx.burst(fcenter + Vector2(0, -50), 22, Color(0.85, 0.92, 1.0), 480.0)
					_flash(Color(0.75, 0.88, 1.0), 0.18, 0.2)
					_float(fcenter + Vector2(0, -70), "Парад!", Color("c9d7e2"), 30)
					shake(2.5)
				await _wait(0.3)
			"parry":
				_float(Vector2(_screen().x / 2, 430), "Перехват!", GOLD, 34)
				await _wait(0.15)
			"initiative":
				_flip_coin("fleur" if "Флёра" in text else "enemy")
				await _wait(0.12)
			"series":
				_float(Vector2(_screen().x / 2, _screen().y * 0.45), "СЕРИЯ", GOLD, 54)
				_flash(Color(1.0, 0.85, 0.5), 0.12, 0.25)
				await _wait(0.15)
			"counter":
				if v:
					if str(ev.get("by", "")) == "enemy":
						v.clank()
						fx.slash(vc + Vector2(-60, 40), fcenter + Vector2(40, -40), Color("f3d68a"), 7.0, 0.4)
						_float(vc + Vector2(0, -90), "Противоход!", Color("f3d68a"), 30)
					else:
						fx.slash(fcenter + Vector2(0, -60), vc, Color("f3d68a"), 7.0, 0.4)
						_float(fcenter + Vector2(0, -100), "Контратака!", Color("f3d68a"), 30)
					await _wait(0.25)
			"feint":
				if v:
					_float(vc + Vector2(0, -90), "финт", Color("d9c9f0"), 26)
					var ghost := v.offset
					var tw := v.create_tween()
					tw.tween_property(v, "offset", ghost + Vector2(-30, 0), 0.08)
					tw.tween_property(v, "offset", ghost + Vector2(30, 10), 0.1)
					tw.tween_property(v, "offset", ghost, 0.12)
					await _wait(0.25)
			"taunt":
				pass
			"open":
				if v:
					v.disp_bal = 0.0
					v.slam_stamp()
					fx.gold = 1.0
					fx.burst(vc, 40, GOLD, 520.0)
					_flash(Color.WHITE, 0.45, 0.35)
					shake(9.0)
					Engine.time_scale = 0.35
					await _wait(0.12)
					Engine.time_scale = 1.0
					await _wait(0.4)
			"open_fleur":
				fleur_disp["balance"] = 0.0
				_flash(Color(0.9, 0.1, 0.05), 0.22, 0.4)
				shake(8.0)
				_float(fcenter + Vector2(0, -110), "Флёр раскрыт", Color("ff6a50"), 32)
				await _wait(0.5)
			"recover":
				if v:
					fx.ring(vc, Color("bfe0c0"), 110.0)
				else:
					fx.ring(fcenter, Color("bfe0c0"), 110.0)
				await _wait(0.15)
			"wound":
				fx.slash(fcenter + Vector2(-90, 50), fcenter + Vector2(90, -30), BLOOD, 10.0, 0.6)
				fx.red = 1.0
				await _wait(0.3)
			"decisive":
				if v:
					v.lunge()
				await _wait(0.1)
				var s := _screen()
				fx.slash(Vector2(s.x * 0.15, s.y * 0.2), Vector2(s.x * 0.85, s.y * 0.8), BLOOD, 14.0, 0.7)
				_flash(Color(0.9, 0.1, 0.05), 0.3, 0.5)
				fx.red = 0.8
				shake(14.0)
				await _wait(0.7)
			"finisher":
				await _finisher_cinematic(ev, v)
		if text != "":
			_log(text, str(ev["kind"]))
	_settle_displays()
	_refresh()
	if not eng.result.is_empty():
		await _wait(0.4)
		_show_end()


func _finisher_cinematic(ev: Dictionary, v: EnemyView) -> void:
	var s := _screen()
	var vc := (v.center_global() - fx.global_position) if v else s / 2
	# полосы «кино», замедление, рассечка через весь экран
	var bars := create_tween().set_parallel()
	bars.tween_property(bar_top, "size:y", s.y * 0.11, 0.25).set_ease(Tween.EASE_OUT)
	bars.tween_property(bar_bottom, "position:y", s.y * 0.89, 0.25).set_ease(Tween.EASE_OUT)
	bars.tween_property(bar_bottom, "size:y", s.y * 0.11, 0.25)
	await _wait(0.25)
	Engine.time_scale = 0.4
	fx.slash(vc + Vector2(-s.x * 0.4, 120), vc + Vector2(s.x * 0.4, -120), Color.WHITE, 12.0, 0.6)
	await _wait(0.12)
	Engine.time_scale = 1.0
	_flash(Color.WHITE, 0.6, 0.45)
	shake(10.0)
	var fid := str(ev.get("finisher", ""))
	match fid:
		"buttons":
			fx.buttons(vc, 18)
			fx.burst(vc, 30, GOLD, 420.0)
		"disarm":
			fx.blade(vc + Vector2(40, -20))
			fx.burst(vc, 24, STEEL, 480.0)
		"throat":
			if v:
				var tw := v.create_tween()
				tw.tween_property(v, "zoom", 1.18, 0.4).set_ease(Tween.EASE_OUT)
			fx.slash(vc + Vector2(-260, 60), vc + Vector2(-30, 40), STEEL, 4.0, 1.2)
			fx.red = 0.5
		"knockdown":
			if v:
				v.fall()
			fx.burst(vc + Vector2(0, 80), 30, Color(0.8, 0.7, 0.55), 300.0)
		_:
			fx.burst(vc, 28, STEEL, 460.0)
	if v and v.e["out"] and fid != "knockdown":
		v.fall()
	var title: String = str(END_TITLE.get(str(ev.get("outcome", "")), "")) if eng.result.size() > 0 else str(ev.get("text", "")).trim_suffix(".")
	if title == "":
		title = str(ev.get("text", "")).trim_suffix(".")
	_float(Vector2(s.x / 2, s.y * 0.42), title, GOLD, 58, 1.4)
	await _wait(1.1)
	var back := create_tween().set_parallel()
	back.tween_property(bar_top, "size:y", 0.0, 0.3)
	back.tween_property(bar_bottom, "position:y", s.y, 0.3)
	back.tween_property(bar_bottom, "size:y", 0.0, 0.3)


func _panel_jolt() -> void:
	var base := Vector2(30, _screen().y - 240)
	var tw := create_tween()
	for k in 4:
		tw.tween_property(fleur_panel, "position", base + Vector2(randf_range(-9, 9), randf_range(-5, 5)), 0.04)
	tw.tween_property(fleur_panel, "position", base, 0.06)


func _log(text: String, kind: String) -> void:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 300
	l.add_theme_font_override("font", Look.font("serif"))
	l.add_theme_font_size_override("font_size", 14)
	var col := Color("e6d6b0")
	if kind in ["open", "finisher", "decisive", "open_fleur", "wound"]:
		col = Color("ffb08a")
	elif kind in ["initiative", "parry", "series", "counter"]:
		col = Color("f3d68a")
	l.add_theme_color_override("font_color", col)
	l.text = text
	l.modulate.a = 0.0
	log_box.add_child(l)
	create_tween().tween_property(l, "modulate:a", 1.0, 0.2)
	while log_box.get_child_count() > 9:
		var old := log_box.get_child(0)
		log_box.remove_child(old)
		old.queue_free()
	var i := 0
	for c in log_box.get_children():
		(c as Control).self_modulate.a = 0.45 + 0.55 * float(i + 1) / log_box.get_child_count()
		i += 1


func _float(p: Vector2, text: String, col: Color, fsize := 30, hold := 0.5) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Look.font("serif_bold"))
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	float_layer.add_child(l)
	var w := Look.font("serif_bold").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	l.position = p - Vector2(w / 2, fsize * 0.6)
	l.pivot_offset = Vector2(w / 2, fsize * 0.6)
	l.scale = Vector2.ONE * 1.8
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_property(l, "position:y", l.position.y - 40, 0.5).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)


# ================================================================ вступление и итог

func _panel(width: float) -> PanelContainer:
	if overlay:
		overlay.queue_free()
	overlay = ColorRect.new()
	(overlay as ColorRect).color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var p := PanelContainer.new()
	p.theme_type_variation = "Paper"
	p.custom_minimum_size = Vector2(width, 0)
	overlay.add_child(p)
	return p


func _center(p: Control) -> void:
	await get_tree().process_frame
	if is_instance_valid(p):
		var s := _screen()
		p.position = (s - p.size) / 2
		p.pivot_offset = p.size / 2
		p.scale = Vector2.ONE * 0.85
		p.modulate.a = 0.0
		var tw := p.create_tween().set_parallel()
		tw.tween_property(p, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "modulate:a", 1.0, 0.2)


func _show_intro() -> void:
	var p := _panel(620)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var k := Label.new()
	k.theme_type_variation = "Kicker"
	k.text = CONTEXT_TITLE.get(eng.context, "").to_upper()
	v.add_child(k)
	var t := Label.new()
	t.theme_type_variation = "InkTitle"
	t.text = get_title()
	v.add_child(t)
	var lines := PackedStringArray([str(eng.def.get("intro", ""))])
	for e in eng.enemies:
		lines.append("%s: %s" % [e["title"], str(e["def"].get("style", ""))])
	if bool(Game.settings.get("hints", true)):
		lines.append("Над противником — его намерение на этот ход. Защита гасит удары, равновесие — стойка: у кого оно кончилось, тот раскрыт. Раскрытого противника можно закончить решающим приёмом; раскрытому Флёру нужно за ход восстановить стойку.")
	var body := Label.new()
	body.theme_type_variation = "Ink"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = 580
	body.text = "\n\n".join(lines)
	v.add_child(body)
	var go := Button.new()
	go.text = "К бою"
	go.pressed.connect(func():
		overlay.queue_free()
		overlay = null
		_begin())
	v.add_child(go)
	_center(p)


func _begin() -> void:
	_busy = true
	Sound.play("danger" if eng.context == "street" else "scabbard")
	disp_init = eng.initiative
	await _banner(get_title(), Color("f4e8ca"))
	_deal(true)
	await _wait(0.4)
	_busy = false
	_refresh()


func _outcome_entry(key: String) -> Dictionary:
	var variants: Array = eng.def.get("outcomes", {}).get(key, [])
	for v in variants:
		if v.has("when") and not Rules.test(v["when"], Game.state):
			continue
		if int(eng.result.get("broke", 0)) < int(v.get("min_broke", 0)):
			continue
		if int(eng.result.get("panache", 0)) < int(v.get("min_panache", 0)):
			continue
		return v
	return {}


func outcome_payload() -> Dictionary:
	var key := str(eng.result.get("outcome", ""))
	var entry := _outcome_entry(key)
	var effects: Array = entry.get("effects", []).duplicate()
	effects.append({"counter": ["duel:" + eng.context, 1]})
	effects.append({"flag": "duel:%s:%s" % [duel_id, key]})
	return {"outcome": key, "summary": str(entry.get("summary", "")), "effects": effects, "duel": duel_id,
		"panache": eng.result.get("panache", 0)}


func _show_end() -> void:
	if overlay and overlay.has_meta("end"):
		return
	var payload := outcome_payload()
	var good: bool = payload["outcome"] in ["win", "clean", "disarm", "throat", "humiliate"]
	if good:
		fx.gold = 1.0
	var p := _panel(560)
	overlay.set_meta("end", true)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	var t := Label.new()
	t.theme_type_variation = "InkTitle"
	t.text = END_TITLE.get(payload["outcome"], "Поединок окончен")
	v.add_child(t)
	var body := Label.new()
	body.theme_type_variation = "Ink"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = 520
	body.text = payload["summary"]
	v.add_child(body)
	var b := Button.new()
	b.text = "Вернуться"
	b.pressed.connect(func():
		Game.finish_activity(q, payload, get_title()))
	v.add_child(b)
	_center(p)
