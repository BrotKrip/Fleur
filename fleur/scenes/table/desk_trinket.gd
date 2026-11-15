class_name DeskTrinket
extends Control
## Безделушки на краях стола: если их тронуть, они оживают и отпускают
## словечко в духе хозяина. Ничего не дают, в партии ничего не меняют и не сохраняются.
## Лежат под картами, поэтому брошенную сверху карту не перехватывают.
## Нажатие проходит дальше на стол, и стол можно сдвигать, взявшись прямо за безделушку.

const FOOTPRINT := {
	"swan": Vector2(144, 128),
	"mirror": Vector2(124, 92),
	"bell": Vector2(96, 88),
	"letters": Vector2(172, 94),
	"hat": Vector2(176, 154),
	"glass": Vector2(100, 108),
}
## Масштаб миниатюры относительно писем и настольного звонка.
const SCALE := {"swan": 0.82}
## Где под предметом появляется реплика (верхняя середина строки).
const QUIP_AT := {
	"swan": Vector2(70, 122),
	"mirror": Vector2(62, 100),
	"bell": Vector2(48, 96),
	"letters": Vector2(86, 102),
	"hat": Vector2(86, 162),
	"glass": Vector2(50, 116),
}
## Где предмет откликается на курсор: прозрачные поля вокруг него оставлены столу.
const HIT := {
	"swan": [Rect2(25, 9, 33, 20), Rect2(123, 71, 15, 15)],
	"mirror": [Rect2(8, 7, 65, 59), Rect2(64, 52, 27, 18), Rect2(86, 65, 33, 20)],
	"bell": [Rect2(21, 7, 54, 74), Rect2(8, 22, 81, 43)],
	"letters": [Rect2(8, 6, 158, 84)],
	"hat": [Rect2(36, 15, 99, 115), Rect2(50, 103, 71, 44)],
	"glass": [Rect2(20, 14, 60, 65), Rect2(35, 70, 30, 28)],
}
const LINES := {
	"swan": [
		"Без четверти безупречность.",
		"Шевалье не опаздывают. Шевалье задерживаются.",
		"Фонтейнская механика: изящно и немного скрипит. Почти как я по утрам.",
		"Поёт так, будто я встаю раньше полудня. Льстец.",
		"Подарок поклонницы. Или кредитора? Нет, кредиторы дарят счета.",
	],
	"swan_drop": ["…Так и было задумано."],
	"swan_fix": ["Никто ничего не видел."],
	"mirror": [
		"Безупречно. Как вчера, только лучше.",
		"Кто этот красавец? А, это снова я.",
		"Профиль — для монет, анфас — для афиш.",
		"Зеркальце, не льсти. Впрочем, продолжай.",
		"Ни одной лишней складки. Кроме модных.",
		"Если бы Архонты лепили людей, они лепили бы с меня.",
		"Свет сегодня падает выгодно. На меня, разумеется.",
	],
	"mirror_rare": ["Седина?! …Нет, блик. Архонты милосердны."],
	"bell": ["Посыльный! …Ах да. Посыльного у меня нет."],
	"bell_note": ["«Месье, звонок — для гостей, а не для музыкальных упражнений». — Консьержка"],
	"bell_hush": ["Дзинь. Шёпотом.", "Это не я. Это колокольчик.", "Консьержка не узнает. Консьержка всё узнает."],
	"hat": [
		"Шляпа кланяется за меня. Берегу спину для вальса.",
		"Мадам. Мадемуазель. Месье. Шляпа приветствует всех.",
		"Перо подлинное. Птица — не очень.",
		"Цилиндр от «Дома Тиори». Счёт — тоже от «Дома Тиори».",
	],
	"hat_fly": ["Так задумано. Это называется «небрежно»."],
	"hat_fix": ["Небрежность хороша в меру."],
	"glass": [
		"Букет: вишня, дуб и лёгкая заносчивость.",
		"«Нектар». Скромное вино для нескромного вечера.",
		"Глоток для вдохновения. Второй — для храбрости.",
		"Только распробовать. Исключительно по делу.",
	],
	"glass_refill": ["Бутылка, к счастью, ближе, чем угрызения совести."],
	"glass_spill": ["Это жертва. Архонтам. Они оценят."],
	"letters": [
		"«Видела вас на набережной — вы как с открытки». Я и есть открытка.",
		"«Шевалье, вы мне снились». Разумеется. Куда мне ещё деваться ночью?",
		"«Подпишите мой веер». Подписал дважды. Пусть хвастается.",
		"«С любовью, М.» Которая из М.? Их у меня одиннадцать.",
		"«Вы ужасно танцуете». Злопыхательница. Положу на почётное место.",
		"«Верните мой зонт». Не поклонница. Но ведь запомнила.",
		"«Вы задолжали за перчатки». Почтальон перепутал стопку.",
		"«Ваш портрет из «Паровой птицы» стоит у меня на комоде». Мудрое вложение.",
	],
}
const WOOD_HI := Color("c89a64")
const WOOD_LO := Color("7e5631")
const WINE := Color("6e1022")
const ART_PARTS := {
	"swan": ["swan_plinth", "swan_body", "swan_head", "swan_wing"],
	"mirror": ["mirror"],
	"bell": ["bell_base", "bell_dome", "bell_button", "bell_note"],
	"letters": ["letters_stack", "letters_envelope"],
	"hat": ["hat_stand", "hat_crown", "hat_feather"],
	"glass": ["glass", "glass_side", "glass_spill"],
}

var kind := ""
var quip_layer: Control
var hovered := false
var hov := 0.0
var t := 0.0
var awake := 0.0          # сколько ещё перерисовывать каждый кадр
var streak := 0           # тычки подряд, без долгих пауз
var last_poke := -10.0
var _press := Vector2.INF
static var _bubble: Label    # на столе говорит кто-то один: новая реплика сменяет прежнюю
var _said := {}           # какая реплика из списка следующая
var _busy := false        # идёт «номер»: падает голова, опрокидывается бокал

# Состояние только для вида.
var flap := 0.0           # лебедь машет, цилиндр кланяется, колокольчик дрожит
var drop := 0.0           # голова лебедя: 0 на месте, 1 укатилась
var headless := false
var crooked := 0.0        # цилиндр набекрень
var fly := 0.0            # цилиндр в полёте
var level := 0.85         # вино в бокале
var tip := 0.0            # бокал опрокинут
var puddle := 0.0
var glint := -1.0         # блик бежит по зеркальцу
var note := 0.0           # записка консьержки выглядывает из-под колокольчика
var note_left := 0.0
var lift := 0.0           # верхний конверт
var press := 0.0          # кнопка колокольчика
var _parts: Dictionary[String, Texture2D] = {}
var _next_clock_update := 0.0


func _init(k: String) -> void:
	kind = k


func _ready() -> void:
	for part: String in ART_PARTS[kind]:
		var texture := Art.prop("desk_trinket_" + part)
		if texture == null:
			_parts.clear()
			break
		_parts[part] = texture
	size = FOOTPRINT[kind]
	scale = Vector2.ONE * float(SCALE.get(kind, 1.0))
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func(): hovered = true)
	mouse_exited.connect(func(): hovered = false)
	for key in LINES:
		_said[key] = randi() % LINES[key].size()


func _has_point(p: Vector2) -> bool:
	if kind == "swan":
		var radial := (p - Vector2(69.5, 67.5)) / Vector2(59, 52)
		if radial.length_squared() <= 1.0 or (drop > 0.55 and Rect2(3, 85, 48, 37).has_point(p)):
			return true
	if kind == "glass" and tip > 0.5:
		return Rect2(44, 55, 113, 48).has_point(p)
	for r in HIT[kind]:
		if r.has_point(p):
			return true
	return false


func _gui_input(e: InputEvent) -> void:
	# Событие не поглощается: стол под предметом тоже его получает и может сдвинуться.
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_press = e.global_position
		elif _press != Vector2.INF:
			if e.global_position.distance_to(_press) < 6.0:
				_poke()
			_press = Vector2.INF


func _process(dt: float) -> void:
	t += dt
	if kind == "swan" and t >= _next_clock_update:
		_next_clock_update = t + 60.0 - float(Time.get_time_dict_from_system()["second"])
		queue_redraw()
	var target := 1.0 if hovered else 0.0
	if hov != target:
		hov = move_toward(hov, target, dt * 5.0)
		awake = maxf(awake, 0.05)
	if note_left > 0.0:
		note_left -= dt
		if note_left <= 0.0:
			_tween(0.6).tween_property(self, "note", 0.0, 0.6)
	if awake > 0.0 or hovered:
		awake -= dt
		queue_redraw()


func _tween(seconds: float) -> Tween:
	awake = maxf(awake, seconds + 0.15)
	return create_tween()


func _line(key: String) -> String:
	var list: Array = LINES[key]
	var i: int = _said[key]
	_said[key] = (i + 1) % list.size()
	return list[i]


## Реплика рукописной строкой под предметом; поверх карт, но под листами и записками.
func _say(text: String) -> void:
	if quip_layer == null:
		return
	if is_instance_valid(_bubble):
		_bubble.queue_free()
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Look.font("hand"))
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", Color("f4e8c8"))
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.045, 0.02, 0.9))
	l.add_theme_constant_override("outline_size", 7)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.custom_minimum_size = Vector2(300, 0)
	l.size = Vector2(300, 0)
	var at: Vector2 = position + QUIP_AT[kind] * scale
	l.position = at - Vector2(150, -4)
	l.modulate.a = 0.0
	quip_layer.add_child(l)
	_bubble = l
	var tw := l.create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.18)
	tw.parallel().tween_property(l, "position:y", at.y, 0.18)
	tw.tween_interval(1.5 + text.length() * 0.045)
	tw.tween_property(l, "modulate:a", 0.0, 0.55)
	tw.parallel().tween_property(l, "position:y", at.y - 12, 0.55)
	tw.tween_callback(l.queue_free)


# ---------------------------------------------------------------- отклики

func _poke() -> void:
	streak = streak + 1 if t - last_poke < 1.2 else 1
	last_poke = t
	if _busy:
		return
	match kind:
		"swan": _poke_swan()
		"mirror": _poke_mirror()
		"bell": _poke_bell()
		"hat": _poke_hat()
		"glass": _poke_glass()
		"letters": _poke_letters()


func _poke_swan() -> void:
	if headless:
		headless = false
		Sound.play("latch", -4.0)
		_tween(0.4).tween_property(self, "drop", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_say(_line("swan_fix"))
		streak = 0
		return
	Sound.play("ui_dial", 2.0)
	Sound.play("swan_chime")
	flap = 1.0
	var tw := _tween(1.6)
	tw.tween_property(self, "flap", 0.0, 1.6).set_ease(Tween.EASE_IN)
	if streak >= 5 or randf() < 0.05:
		# На пятый раз завод не выдерживает
		_busy = true
		headless = true
		streak = 0
		tw.parallel().tween_property(self, "drop", 1.0, 1.0).set_delay(0.45)
		tw.parallel().tween_callback(func(): Sound.play("latch", 1.0)).set_delay(0.5)
		tw.parallel().tween_callback(func(): Sound.play("ui_card", 2.0)).set_delay(0.95)
		tw.tween_callback(func():
			_busy = false
			_say(_line("swan_drop")))
	else:
		_say(_line("swan"))


func _poke_mirror() -> void:
	Sound.play("desk_glint")
	glint = 0.0
	_tween(0.6).tween_property(self, "glint", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
	_say(_line("mirror_rare") if randf() < 0.1 else _line("mirror"))


func _poke_bell() -> void:
	press = 1.0
	flap = 1.0
	var tw := _tween(1.2)
	tw.tween_property(self, "press", 0.0, 0.18)
	tw.parallel().tween_property(self, "flap", 0.0, 1.1)
	if note > 0.0 or note_left > 0.0:
		Sound.play("desk_bell", -15.0)
		if streak % 2 == 1:
			_say(_line("bell_hush"))
		note_left = maxf(note_left, 12.0)
		return
	Sound.play("desk_bell", -2.0)
	if streak == 3:
		_say(_line("bell"))
	elif streak >= 6:
		streak = 0
		note_left = 20.0
		var slide := _tween(0.9)
		slide.tween_interval(0.35)
		slide.tween_callback(func(): Sound.play("ui_paper", -2.0))
		slide.tween_property(self, "note", 1.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		slide.tween_callback(func(): _say(_line("bell_note")))


func _poke_hat() -> void:
	if crooked > 0.5:
		Sound.play("clothes", -6.0)
		_tween(0.4).tween_property(self, "crooked", 0.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_say(_line("hat_fix"))
		streak = 0
		return
	if streak >= 4:
		_busy = true
		streak = 0
		Sound.play("clothes", -2.0)
		var tw := _tween(1.1)
		tw.tween_property(self, "fly", 1.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.parallel().tween_property(self, "crooked", 1.0, 0.3).set_delay(0.6)
		tw.tween_callback(func():
			fly = 0.0
			_busy = false
			Sound.play("ui_card", 1.0)
			_say(_line("hat_fly")))
		return
	Sound.play("clothes", -7.0)
	var bow := _tween(1.4)
	bow.tween_property(self, "flap", 1.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	bow.tween_property(self, "flap", 0.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if streak == 1:
		_say(_line("hat"))


func _poke_glass() -> void:
	if streak >= 3 and level > 0.05:
		_busy = true
		streak = 0
		Sound.play("glass", 0.0)
		var tw := _tween(6.4)
		tw.tween_property(self, "tip", 1.0, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(self, "level", 0.0, 0.5)
		tw.parallel().tween_property(self, "puddle", 1.0, 1.1).set_delay(0.2).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_callback(func(): _say(_line("glass_spill"))).set_delay(0.35)
		tw.tween_interval(2.6)
		tw.tween_property(self, "tip", 0.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func(): Sound.play("cork", -4.0))
		tw.tween_property(self, "level", 0.85, 0.7)
		tw.parallel().tween_property(self, "puddle", 0.0, 1.8)
		tw.tween_callback(func(): _busy = false)
		return
	if level < 0.2:
		Sound.play("cork", -3.0)
		_tween(0.8).tween_property(self, "level", 0.85, 0.7).set_delay(0.1)
		_say(_line("glass_refill"))
		return
	Sound.play("glass", -14.0)
	flap = 1.0
	var tw := _tween(0.9)
	tw.tween_property(self, "level", maxf(0.0, level - 0.28), 0.5)
	tw.parallel().tween_property(self, "flap", 0.0, 0.9)
	if streak == 1:
		_say(_line("glass"))


func _poke_letters() -> void:
	Sound.play("ui_paper", -1.0)
	var tw := _tween(1.1)
	tw.tween_property(self, "lift", 1.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.5)
	tw.tween_property(self, "lift", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_say(_line("letters"))


# ---------------------------------------------------------------- рисование

func _draw() -> void:
	match kind:
		"swan": _draw_swan()
		"mirror": _draw_mirror()
		"bell": _draw_bell()
		"letters": _draw_letters()
		"hat": _draw_hat()
		"glass": _draw_glass()


func _up() -> Vector2:
	return Vector2(0, -2.0 * hov)


func _shade(c: Color) -> Color:
	return c.lerp(Color(1.0, 0.96, 0.86), 0.08 * hov)


func _part(id: String, rect: Rect2, alpha := 1.0) -> void:
	var light := 0.08 * hov
	draw_texture_rect(_parts[id], rect, false, Color(1.0 + light, 1.0 + light * 0.8, 1.0 + light * 0.5, alpha))


func _contact(c: Vector2, r: Vector2, alpha: float) -> void:
	for i in 4:
		var k := 1.0 - i * 0.18
		draw_colored_polygon(Look.ellipse(c, r * k, 28), Color(0.02, 0.01, 0.0, alpha * 0.3))


## Боковина цилиндрического предмета (барабан, подставка): между верхним и нижним эллипсом.
func _drum(top: Vector2, r: Vector2, height: float, hi: Color, lo: Color, lid: Color) -> void:
	var side := PackedVector2Array()
	for i in 21:
		var a := PI * i / 20.0
		side.append(top + Vector2(cos(a) * r.x, sin(a) * r.y + height))
	for i in range(20, -1, -1):
		var a := PI * i / 20.0
		side.append(top + Vector2(cos(a) * r.x, sin(a) * r.y))
	Look.fill_v(self, side, hi, lo)
	draw_colored_polygon(Look.ellipse(top, r, 32), lid)
	Look.outline(self, Look.ellipse(top, r, 32), Color(0.1, 0.06, 0.02, 0.45), 1.0)


func _bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		var s := float(i) / n
		var u := 1.0 - s
		out.append(p0 * u * u * u + p1 * 3.0 * u * u * s + p2 * 3.0 * u * s * s + p3 * s * s * s)
	return out


# Циферблат утоплен в крышку шкатулки перед фигуркой.
func _draw_swan() -> void:
	var up := _up()
	var base := Rect2(Vector2(11, 16) + up, Vector2(117, 103))
	var brass := _shade(Color("b48b4d"))
	var enamel := _shade(Color("ede1c8"))
	_contact(Vector2(71, 74), Vector2(59, 48), 0.38)
	var key := Vector2(128, 78) + up
	var turn := absf(cos(t * 2.2)) if (hovered or flap > 0.0) else 0.82
	draw_line(key - Vector2(9, 1.5), key + Vector2(3, 0), Look.BRASS_DARK, 2.8, true)
	var bow := Look.ellipse(key + Vector2(4, 0), Vector2(2 + 3.4 * turn, 6), 18)
	Look.fill_v(self, bow, brass.lightened(0.3), Look.BRASS_DARK)
	for side: float in [-1.0, 1.0]:
		draw_colored_polygon(Look.ellipse(key + Vector2(4, 2.7 * side), Vector2(1.8 * turn, 1.3), 12), Color("5d4029"))

	if _parts.is_empty():
		_drum(Vector2(69, 64) + up, Vector2(56, 44), 8, brass, Color("534533"), _shade(Color("927444")))
	else:
		_part("swan_plinth", base)
	var dial := Vector2(69, 86) + up
	if _parts.is_empty():
		draw_circle(dial, 16.5, Look.BRASS_DARK, true, -1, true)
		draw_circle(dial, 14.5, Color("eee0c1"), true, -1, true)
	draw_set_transform(dial, 0.0, Vector2(1.13, 1.22))
	for h in 12:
		var angle := TAU * h / 12.0
		var radial := Vector2(sin(angle), -cos(angle))
		draw_line(radial * 10.1, radial * 11.8, Look.INK_SOFT, 0.9, true)
	var now := Time.get_time_dict_from_system()
	var minute := TAU * float(now["minute"]) / 60.0
	var hour := TAU * (float(now["hour"] % 12) + float(now["minute"]) / 60.0) / 12.0
	draw_line(Vector2.ZERO, Vector2(sin(hour), -cos(hour)) * 7, Look.INK, 1.65, true)
	draw_line(Vector2.ZERO, Vector2(sin(minute), -cos(minute)) * 9.7, Look.INK, 1.1, true)
	draw_circle(Vector2.ZERO, 1.35, Look.BRASS_DARK, true, -1, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var bird := up + Vector2(0, sin(t * 20.0) * 0.9 * flap)
	var head_home := Vector2(47, 23) + bird
	var body := Rect2(Vector2(44, 16) + bird, Vector2(74, 61))
	if _parts.is_empty():
		var neck := _bezier(Vector2(63, 44) + bird, Vector2(57, 37) + bird, Vector2(64, 20) + bird, head_home, 14)
		draw_polyline(neck, enamel.darkened(0.35), 9.0, true)
		draw_polyline(neck, enamel, 6.0, true)
		draw_set_transform(Vector2(86, 52) + bird, 0.58, Vector2.ONE)
		var back := Look.ellipse(Vector2.ZERO, Vector2(33, 16), 28)
		Look.fill_v(self, back, enamel, Color("c5b59a"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_texture_rect(_parts["swan_body"], Rect2(body.position + Vector2(1.6, 2.4), body.size), false, Color(0.05, 0.03, 0.01, 0.31))
		_part("swan_body", body)
	# Ближнее крыло отходит от спинки, оставаясь на одном шарнире.
	var stroke := flap * (0.65 + 0.35 * cos(t * 22.0))
	draw_set_transform(Vector2(62, 50) + bird, stroke * 0.62, Vector2(1, 1.0 - stroke * 0.14))
	if _parts.is_empty():
		var feathers := PackedVector2Array([Vector2(-2, -6), Vector2(11, -7), Vector2(46, 27), Vector2(25, 21), Vector2(5, 9)])
		Look.fill_v(self, feathers, enamel, Color("c8baa0"))
		Look.outline(self, feathers, brass.darkened(0.23), 1.0)
	else:
		_part("swan_wing", Rect2(-1, -9, 49, 39))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var head := head_home
	if drop > 0.0:
		draw_circle(head_home, 2.5, brass, true, -1, true)
		var edge := Vector2(25, 66) + up
		var rest := Vector2(18, 101)
		if drop < 0.55:
			var u := drop / 0.55
			head = head_home.lerp(edge, u) - Vector2(0, 56.0 * u * (1.0 - u))
		else:
			var u := (drop - 0.55) / 0.45
			head = edge.lerp(rest, u) - Vector2(0, 29.0 * u * (1.0 - u))
	# В сборе штырёк входит в шею, а край эмали перекрывает латунную муфту.
	if not _parts.is_empty():
		head += Vector2(8, -2) * (1.0 - smoothstep(0.0, 0.3, drop))
	draw_set_transform(head, drop * 9.0, Vector2.ONE)
	if _parts.is_empty():
		var beak := PackedVector2Array([Vector2(-14, -7), Vector2(-27, -9), Vector2(-15, -3)])
		draw_colored_polygon(beak, Color("b87232"))
		draw_colored_polygon(Look.ellipse(Vector2(-8, -3), Vector2(9, 6.5), 20), enamel)
		draw_circle(Vector2(-13, -3), 1.15, Look.INK, true, -1, true)
	else:
		var rect := Rect2(-29, -13, 32, 18)
		if drop > 0.0:
			_part("swan_head", rect, minf(1.0, drop * 10.0))
		if drop < 0.1:
			# Контур втулки на исходном рисунке. Сам штырёк виден только у снятой головы.
			var uv := PackedVector2Array([
				Vector2.ZERO, Vector2(0.64, 0), Vector2(0.76, 0.34), Vector2(0.82, 0.47),
				Vector2(0.856, 0.62), Vector2(0.863, 0.78), Vector2(0.836, 0.90),
				Vector2(0.796, 0.97), Vector2(0.785, 1), Vector2.DOWN])
			var fit := Transform2D(0.0, rect.size, 0.0, rect.position)
			draw_polygon(fit * uv, PackedColorArray([_shade(Color.WHITE)]), uv, _parts["swan_head"])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# Карманное зеркальце в латунной оправе.
func _draw_mirror() -> void:
	var up := _up()
	var c := Vector2(50, 44) + up
	var glass := Look.ellipse(c, Vector2(33, 27))
	if not _parts.is_empty():
		var rect := Rect2(Vector2(7, 3) + up, Vector2(110, 85))
		draw_texture_rect(_parts["mirror"], Rect2(rect.position + Vector2(1, 2), rect.size), false, Color(0.08, 0.04, 0.02, 0.27))
		_part("mirror", rect)
		c = Vector2(41.5, 35.5) + up
		glass = Look.ellipse(c, Vector2(30, 27), 48)
	else:
		_contact(Vector2(64, 52), Vector2(56, 38), 0.4)
		draw_line(Vector2(80, 60) + up, Vector2(114, 84) + up, Look.BRASS_DARK, 12.0, true)
		draw_line(Vector2(80, 58) + up, Vector2(114, 82) + up, _shade(Look.BRASS), 8.0, true)
		draw_line(Vector2(86, 60) + up, Vector2(110, 78) + up, Color(1, 0.92, 0.65, 0.4), 2.0, true)
		draw_circle(Vector2(115, 84) + up, 6.0, _shade(Look.BRASS), true, -1, true)
		draw_colored_polygon(Look.ellipse(c, Vector2(43, 37)), Look.BRASS_DARK)
		Look.fill_v(self, Look.ellipse(c, Vector2(40, 34)), _shade(Color("d9b462")), Color("8a6726"))
		Look.fill_v(self, glass, _shade(Color("aebfc6")), Color("586c78"))
		draw_arc(c, 22, PI * 1.05, PI * 1.45, 12, Color(1, 1, 1, 0.35), 3.0, true)
	var g := glint
	if g < 0.0 or g >= 1.0:
		g = fmod(t * 0.5, 1.8) if hovered else -1.0
	if g >= 0.0 and g < 1.0:
		var x := lerpf(-52.0, 52.0, g)
		var start := c + Vector2(x + 2, -40)
		var end := c + Vector2(x - 14, 40)
		for spread: float in [-9.0, 9.0]:
			var offset := Vector2(spread, 0)
			var band := PackedVector2Array([start, start + offset, end + offset, end])
			for piece in Geometry2D.intersect_polygons(band, glass):
				var colors := PackedColorArray()
				for p: Vector2 in piece:
					var distance_x := absf(p.x - start.x + (p.y - start.y) * 0.2)
					colors.append(Color(1.0, 0.98, 0.92, 0.44 * clampf(1.0 - distance_x / absf(spread), 0.0, 1.0)))
				draw_polygon(piece, colors)
	if glint > 0.35 and glint < 1.0:
		var s := sin(PI * (glint - 0.35) / 0.65) * 9.0
		var sc := c + Vector2(18, -16)
		draw_line(sc - Vector2(s, 0), sc + Vector2(s, 0), Color(1, 1, 0.95, 0.9), 1.5, true)
		draw_line(sc - Vector2(0, s), sc + Vector2(0, s), Color(1, 1, 0.95, 0.9), 1.5, true)
	if _parts.is_empty():
		Look.outline(self, glass, Color(0.25, 0.18, 0.06, 0.6), 1.0)


# Латунный звонок посыльного на деревянном кружке.
func _draw_bell() -> void:
	var up := _up()
	if note > 0.0:
		# записка консьержки выползает из-под звонка
		var nc := Vector2(48, 66).lerp(Vector2(-6, 70), note)
		draw_set_transform(nc, -0.14, Vector2.ONE)
		if not _parts.is_empty():
			_part("bell_note", Rect2(-34, -15, 68, 30))
		else:
			var paper := Look.torn_rect(Rect2(-34, -15, 68, 30), 31, false, true, 2.0)
			Look.soft_shadow(self, paper, Vector2(2, 3), 3, 0.35)
			draw_colored_polygon(paper, Look.PAPER)
			Look.fake_lines(self, Rect2(-28, -9, 52, 14), Color(0.25, 0.18, 0.12, 0.45), 5.0, 3)
			draw_line(Vector2(6, 9), Vector2(26, 7), Color(0.25, 0.18, 0.12, 0.6), 1.2, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not _parts.is_empty():
		var base := Rect2(Vector2(8, 4) + up, Vector2(80, 82))
		draw_texture_rect(_parts["bell_base"], Rect2(base.position + Vector2(2, 3), base.size), false, Color(0.06, 0.03, 0.02, 0.32))
		_part("bell_base", base)
		var ripple := sin(t * 70.0) * 0.025 * flap
		draw_set_transform(Vector2(48, 42) + up, ripple, Vector2(1.0 + ripple, 1.0 - ripple))
		_part("bell_dome", Rect2(-36, -39, 72, 74))
		_part("bell_button", Rect2(-7.5, -24 + press * 2.5, 15, 16))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	_contact(Vector2(50, 76), Vector2(44, 12), 0.5)
	_drum(Vector2(48, 66) + up, Vector2(42, 11), 8, Color("3c2617"), Color("1f140c"), _shade(Color("5b3b24")))
	var jit := sin(t * 70.0) * 0.025 * flap
	var c := Vector2(48, 64) + up
	var dome := PackedVector2Array()
	for i in 25:
		var a := PI + PI * i / 24.0
		dome.append(c + Vector2(cos(a) * 33.0 * (1.0 + jit), sin(a) * 36.0 * (1.0 - jit)))
	Look.fill_v(self, dome, _shade(Color("e6c26e")), Color("8a6424"))
	draw_arc(c, 26, PI * 1.12, PI * 1.42, 14, Color(1, 0.95, 0.75, 0.55), 3.0, true)
	Look.outline(self, dome, Color(0.28, 0.18, 0.05, 0.55), 1.0)
	draw_colored_polygon(Look.ellipse(c, Vector2(33, 5), 28), Color("6e5220"))
	var pr := press * 4.0
	draw_rect(Rect2(c.x - 3, c.y - 46 + pr, 6, 12), Look.BRASS_DARK)
	draw_circle(Vector2(c.x, c.y - 47 + pr), 6.5, _shade(Look.BRASS), true, -1, true)
	draw_circle(Vector2(c.x - 2, c.y - 49 + pr), 2.2, Color(1, 0.95, 0.75, 0.6), true, -1, true)


# Стопка писем поклонниц под лентой, сверху один конверт без ленты.
func _draw_letters() -> void:
	var up := _up()
	if not _parts.is_empty():
		draw_texture_rect(_parts["letters_stack"], Rect2(9.5, 11, 143, 80), false, Color(0.11, 0.06, 0.02, 0.22))
		_part("letters_stack", Rect2(8, 9, 143, 80))
	else:
		_contact(Vector2(90, 54), Vector2(80, 34), 0.35)
		var stack := [[Vector2(82, 56), -0.07, Color("e7d9bd")], [Vector2(92, 52), 0.05, Color("ead0cf")], [Vector2(86, 50), -0.02, Color("dcd2e5")]]
		for e in stack:
			_envelope(e[0], e[1], e[2], false)
		# лента крест-накрест с бантом
		draw_set_transform(Vector2(86, 50), -0.02, Vector2.ONE)
		draw_rect(Rect2(-66, -4, 132, 8), Look.WAX)
		draw_rect(Rect2(-4, -36, 8, 72), Look.WAX)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var top_pos := Vector2(94, 44) + up + Vector2(10, -22) * lift
	var top_rot := 0.05 - 0.12 * lift - 0.03 * hov
	if not _parts.is_empty():
		draw_set_transform(top_pos, top_rot, Vector2.ONE)
		var r := Rect2(-58, -32, 116, 64)
		var shadow := Rect2(r.position + Vector2(1.5, 1.5 + lift * 5.0), r.size)
		draw_texture_rect(_parts["letters_envelope"], shadow, false, Color(0.12, 0.07, 0.03, 0.22))
		_part("letters_envelope", r)
		if hov > 0.04:
			var fold := PackedVector2Array([r.end - Vector2(12 * hov, 0), r.end, r.end - Vector2(0, 9 * hov)])
			draw_colored_polygon(fold, Color(0.97, 0.89, 0.71, 0.92 * hov))
			draw_line(fold[0], fold[2], Color(0.45, 0.31, 0.17, 0.6 * hov), 1.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		_envelope(top_pos, top_rot, _shade(Color("f2e7cf")), true)


func _envelope(c: Vector2, rot: float, col: Color, seal: bool) -> void:
	draw_set_transform(c, rot, Vector2.ONE)
	var r := Rect2(-62, -34, 124, 68)
	var p := Look.rrect(r, 2.0)
	Look.soft_shadow(self, p, Vector2(2, 3), 3, 0.3)
	draw_colored_polygon(p, col)
	var crease := Color(0.35, 0.25, 0.15, 0.35)
	draw_line(r.position, Vector2(0, 4), crease, 1.0, true)
	draw_line(Vector2(r.end.x, r.position.y), Vector2(0, 4), crease, 1.0, true)
	draw_line(Vector2(r.position.x, r.end.y), Vector2(-14, -6), crease, 1.0, true)
	draw_line(r.end, Vector2(14, -6), crease, 1.0, true)
	Look.outline(self, p, Color(0.3, 0.2, 0.1, 0.35), 1.0)
	if seal:
		draw_circle(Vector2(0, 4), 7.0, Look.WAX, true, -1, true)
		draw_circle(Vector2(-1.5, 2.5), 3.0, Color(1, 0.6, 0.6, 0.25), true, -1, true)
		if hov > 0.0:
			# уголок приподнимается под пальцем
			var fold := PackedVector2Array([r.end - Vector2(18 * hov, 0), r.end, r.end - Vector2(0, 14 * hov)])
			draw_colored_polygon(fold, col.lightened(0.1))
			draw_polyline(PackedVector2Array([fold[0], fold[2]]), crease, 1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# Цилиндр закрывает болванку сверху. Под полями видна передняя часть деревянной подставки.
func _draw_hat() -> void:
	_contact(Vector2(87, 122), Vector2(43, 26), 0.26)
	if not _parts.is_empty():
		_part("hat_stand", Rect2(46, 38, 80, 110))
	else:
		_drum(Vector2(86, 119), Vector2(39, 25), 4.0, WOOD_HI, WOOD_LO, Color("805730"))
		var block := Look.ellipse(Vector2(86, 79), Vector2(32, 37), 40)
		Look.fill_v(self, block, Color("c99a5c"), Color("85532b"))

	var arc := sin(PI * fly)
	var pos := Vector2(84, 65) + _up() + Vector2(9, 4) * crooked + Vector2(-2, -8) * flap + Vector2(15, -54) * arc
	var rot := -0.13 * flap + 0.28 * crooked + TAU * fly
	var hat_scale := Vector2(1.0, 1.0 - 0.10 * flap)
	draw_set_transform(pos, rot, hat_scale)
	if not _parts.is_empty():
		_part("hat_crown", Rect2(-62, -61, 124, 124))
	else:
		_drum(Vector2.ZERO, Vector2(60, 49), 4.0, Color("38313c"), Color("191622"), Color("242331"))
		_drum(Vector2(0, -13), Vector2(44, 39), 19.0, Color("65404b"), Color("472137"), Color("30323b"))
	var sway := sin(t * 8.0) * (0.2 * flap + 0.1 * hov + 0.22 * absf(arc))
	var clip_pos := pos + (Vector2(31, 29) * hat_scale).rotated(rot)
	draw_set_transform(clip_pos, rot + sway, hat_scale)
	if not _parts.is_empty():
		_part("hat_feather", Rect2(0, -40, 28, 41))
	else:
		Look.fill_v(self, PackedVector2Array([Vector2.ZERO, Vector2(8, -23), Vector2(29, -41), Vector2(20, -14)]), Color("679f96"), Color("245e59"))
		draw_line(Vector2.ZERO, Vector2(29, -41), Color("abc1ac"), 1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# У стоящего бокала чаша закрывает большую часть ножки. У упавшего виден профиль.
func _draw_glass() -> void:
	if puddle > 0.0:
		var pc := Vector2(171, 85)
		var pr := Vector2(11 + 31 * puddle, 5 + 10 * puddle)
		if not _parts.is_empty():
			_part("glass_spill", Rect2(pc - pr, pr * 2.0), minf(1.0, puddle * 1.6))
		else:
			draw_colored_polygon(Look.ellipse(pc, pr, 28), Color(0.36, 0.04, 0.09, 0.75 * minf(1.0, puddle * 1.6)))
	var tilt := clampf(tip, 0.0, 1.0)
	var side := smoothstep(0.42, 0.65, tilt)
	_contact(Vector2(51, 85), Vector2(19, 13), 0.28 * (1.0 - side))
	if side > 0.0:
		_contact(Vector2(106, 85), Vector2(48, 16), 0.22 * side)
	if side < 1.0:
		var pivot := Vector2(50, 83) + _up() * (1.0 - tilt) + Vector2(32, 6) * tilt
		draw_set_transform(pivot, tilt * 1.12, Vector2.ONE)
		if not _parts.is_empty():
			_part("glass", Rect2(-38, -76, 76, 91), 1.0 - side)
		else:
			var rim := Look.ellipse(Vector2(0, -40), Vector2(37, 34), 44)
			Look.outline(self, rim, Color(0.94, 0.88, 0.71, 0.9 * (1.0 - side)), 1.3)
			Look.outline(self, Look.ellipse(Vector2(0, 0), Vector2(18, 14), 36), Color(0.9, 0.93, 0.94, 0.65 * (1.0 - side)), 1.0)
		if level > 0.01:
			_draw_wine(1.0 - side)
	if side > 0.0:
		var center := Vector2(50, 51).lerp(Vector2(104, 78), tilt)
		draw_set_transform(center, lerpf(-0.6, 0.0, tilt), Vector2.ONE)
		if not _parts.is_empty():
			_part("glass_side", Rect2(-59, -36, 118, 72), side)
		else:
			var line_color := Color(0.92, 0.88, 0.78, 0.78 * side)
			Look.outline(self, Look.ellipse(Vector2(47, 0), Vector2(9, 33), 36), line_color, 1.2)
			draw_polyline(PackedVector2Array([Vector2(47, -33), Vector2(12, -17), Vector2(-8, 0), Vector2(-46, 0)]), line_color, 1.5, true)
			draw_polyline(PackedVector2Array([Vector2(47, 33), Vector2(12, 17), Vector2(-8, 0)]), line_color, 1.5, true)
			Look.outline(self, Look.ellipse(Vector2(-47, 0), Vector2(5, 22), 32), line_color, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## При глотке поверхность вина опускается к центру чаши и занимает меньшую площадь.
func _draw_wine(alpha: float) -> void:
	var center := Vector2(0, lerpf(-16.0, -42.0, level))
	var radius := 33.0 * pow(level, 0.40)
	var surface := Look.ellipse(center, Vector2(radius, radius * 0.91), 48)
	var wave := sin(t * 6.0) * (hov + flap) * 1.2
	for i in surface.size():
		surface[i].y -= wave * surface[i].x / radius
	var lower := surface.duplicate()
	for i in lower.size():
		lower[i].y += 2.0 + 3.0 * level
	Look.fill_v(self, lower, Color(0.33, 0.045, 0.10, 0.58 * alpha), Color(0.30, 0.035, 0.10, 0.76 * alpha))
	Look.fill_v(self, surface, Color(0.27, 0.032, 0.085, 0.88 * alpha), Color(0.43, 0.085, 0.16, 0.76 * alpha))
	Look.outline(self, surface, Color(0.91, 0.54, 0.48, 0.42 * alpha), 0.75)
	var reflection := PackedVector2Array()
	for i in range(26, 33):
		reflection.append(center + (surface[i] - center) * 0.91)
	draw_polyline(reflection, Color(1, 0.78, 0.65, 0.35 * alpha), 0.85, true)
