extends Control
## ВРЕМЕННАЯ активность «Охота у акватории Морт» — заготовка будущей «рыбалки».
## Вид сверху. Лодка ходит свободно. Гарпун заряжается и вонзается в конкретную часть твари;
## трос работает как пружина — тварь буксирует лодку, а лодка удерживает тварь.
## Части тела копят урон; разрушенная часть мигает, и рывок троса вырывает её — это и есть добыча.
## У твари есть фазы: кружение, таран с замахом, удар хвостом, уход на глубину (срывает гарпун), бегство.
## Интерфейс активности: setup(params, queue_item), get_title(); по окончании — Game.finish_activity().

const W := 1280.0
const H := 720.0
const WALL := 70.0                # у верхнего края — южная стена города

# Лодка
const BOAT_ACCEL := 900.0
const BOAT_MAX := 250.0
const BOAT_DRAG := 2.4
const DASH_IMPULSE := 560.0
const DASH_RECHARGE := 2.6

# Гарпун и трос
const HARPOON_SPEED := 980.0
const HARPOON_RANGE := 560.0
const HARPOON_MIN_CHARGE := 0.45
const ROPE_REST := 170.0
const ROPE_K := 3.2               # жёсткость пружины для лодки
const ROPE_K_PREY := 0.9          # насколько лодка удерживает тварь
const ROPE_SNAP := 600.0
const HARPOON_DAMAGE := 14.0
const RIP_DAMAGE := 34.0

# Пики (лёгкое оружие)
const SPEAR_SPEED := 820.0
const SPEAR_RANGE := 430.0
const SPEAR_DAMAGE := 6.0
const SPEAR_COOLDOWN := 0.32

var params := {}
var q := {}
var big := false
var t := 0.0
var time_limit := 150.0

var boat := {}
var harpoon := {}
var spears: Array = []
var prey := {}
var debris: Array = []
var particles: Array = []
var popups: Array = []
var collected: Array = []
var ended: Dictionary = {}
var slowmo := 0.0
var shake := 0.0
var lmb := false
var rmb := false
var spear_cd := 0.0
var _shake_off := Vector2.ZERO

var stage: Control
var hint: Label
var end_panel: PanelContainer
var retreat_btn: Button


func setup(p: Dictionary, queue_item: Dictionary) -> void:
	params = p
	q = queue_item
	big = bool(p.get("big", false))


func get_title() -> String:
	return "Охота у акватории Морт"


# ---------------------------------------------------------------- создание

func _ready() -> void:
	boat = {"pos": Vector2(W / 2, H - 140), "vel": Vector2.ZERO, "rot": -PI / 2, "hp": 3, "invuln": 0.0, "dash": 3, "dash_t": 0.0}
	harpoon = {"state": "ready", "pos": Vector2.ZERO, "vel": Vector2.ZERO, "charge": 0.0, "part": "", "local": Vector2.ZERO, "dist": 0.0, "cd": 0.0}
	var sc := 1.3 if big else 1.0
	prey = {
		"pos": Vector2(W * 0.3, H * 0.4), "rot": 0.0, "speed": 0.0, "vel": Vector2.ZERO,
		"scale": sc, "hp": 320.0 if big else 200.0, "max": 320.0 if big else 200.0,
		"state": "circle", "state_t": 3.0, "weight": 1.0, "dive_cd": 6.0, "fled": false, "alpha": 1.0,
		"telegraph": 0.0, "dead": false,
		"parts": {
			"plate": _part("головной щиток", Vector2(74, 0), 30, 70.0, true, "it_skate_plate"),
			"wing_l": _part("левое крыло", Vector2(-6, -72), 34, 45.0, false, "it_skate_fin"),
			"wing_r": _part("правое крыло", Vector2(-6, 72), 34, 45.0, false, "it_skate_fin"),
			"tail": _part("хвост", Vector2(-120, 0), 22, 35.0, false, "it_skate_spine"),
			"body": _part("тело", Vector2(0, 0), 50, INF, false, ""),
		},
	}

	var bgc := ColorRect.new()
	bgc.color = Color("061018")
	bgc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bgc)
	hint = Label.new()
	hint.text = "WASD — лодка · Пробел — рывок · ЛКМ — пики · ПКМ: зажать и отпустить — гарпун, нажать ещё раз — рвануть трос · Временный режим"
	hint.position = Vector2(30, 16)
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color("cdbf9f"))
	add_child(hint)
	stage = Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_STOP
	stage.clip_contents = true
	stage.draw.connect(_draw_stage)
	stage.gui_input.connect(_stage_input)
	add_child(stage)
	retreat_btn = Button.new()
	retreat_btn.text = "Отступить"
	retreat_btn.focus_mode = Control.FOCUS_NONE
	retreat_btn.pressed.connect(func():
		_end("retreat"))
	add_child(retreat_btn)
	end_panel = PanelContainer.new()
	end_panel.theme_type_variation = "Paper"
	end_panel.visible = false
	add_child(end_panel)
	resized.connect(_layout)
	_layout()


func _part(name: String, off: Vector2, r: float, hp: float, armored: bool, loot: String) -> Dictionary:
	return {"name": name, "off": off, "r": r, "hp": hp, "max": hp, "armored": armored, "loot": loot,
		"broken": false, "ripped": false, "hit": 0.0}


func _layout() -> void:
	var s := size if size.x > 10 else get_viewport_rect().size
	var k := minf((s.x - 60) / W, (s.y - 110) / H)
	stage.size = Vector2(W, H)
	stage.scale = Vector2(k, k)
	stage.position = Vector2((s.x - W * k) / 2, 48)
	retreat_btn.position = Vector2(stage.position.x + W * k - 130, stage.position.y + H * k + 8)


func on_escape() -> void:
	Dialogs.pause()


# ---------------------------------------------------------------- ввод

func _stage_input(e: InputEvent) -> void:
	if not ended.is_empty():
		return
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_LEFT:
			lmb = e.pressed
		elif e.button_index == MOUSE_BUTTON_RIGHT:
			if e.pressed:
				rmb = true
				if harpoon["state"] == "attached":
					_yank()
				elif harpoon["state"] == "ready":
					harpoon["state"] = "charging"
					harpoon["charge"] = 0.0
			else:
				rmb = false
				if harpoon["state"] == "charging":
					if harpoon["charge"] >= HARPOON_MIN_CHARGE:
						_fire_harpoon()
					else:
						harpoon["state"] = "ready"


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and ended.is_empty():
		if e.keycode in [KEY_SPACE, KEY_SHIFT]:
			_dash()
		elif e.keycode == KEY_E and harpoon["state"] == "attached":
			_yank()


func _mouse() -> Vector2:
	return stage.get_local_mouse_position()


func _input_dir() -> Vector2:
	var d := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		d.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		d.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		d.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		d.y += 1
	return d.normalized()


# ---------------------------------------------------------------- действия игрока

func _dash() -> void:
	if int(boat["dash"]) <= 0:
		return
	boat["dash"] = int(boat["dash"]) - 1
	var dir: Vector2 = _input_dir()
	if dir == Vector2.ZERO:
		dir = Vector2.from_angle(boat["rot"])
	boat["vel"] += dir * DASH_IMPULSE
	_splash(boat["pos"], 10, Color(0.8, 0.95, 1.0, 0.8))


func _throw_spear() -> void:
	var from: Vector2 = boat["pos"]
	var dir := (_mouse() - from).normalized()
	spears.append({"pos": from + dir * 20, "vel": dir * SPEAR_SPEED, "dist": 0.0})
	spear_cd = SPEAR_COOLDOWN


func _fire_harpoon() -> void:
	var from: Vector2 = boat["pos"]
	var dir := (_mouse() - from).normalized()
	var power := clampf(harpoon["charge"] / 1.2, 0.6, 1.0)
	harpoon["state"] = "flying"
	harpoon["pos"] = from + dir * 22
	harpoon["vel"] = dir * HARPOON_SPEED * power
	harpoon["dist"] = 0.0


func _yank() -> void:
	var key: String = harpoon["part"]
	var part: Dictionary = prey["parts"].get(key, {})
	if not part.is_empty() and part["broken"] and not part["ripped"] and not prey["dead"]:
		_rip(key)
	else:
		_popup(_harpoon_anchor(), "рывок", Color(0.85, 0.85, 0.8))
		prey["vel"] += (boat["pos"] - prey["pos"]).normalized() * 60.0
	_release_harpoon()


func _rip(key: String) -> void:
	var part: Dictionary = prey["parts"][key]
	part["ripped"] = true
	var wp := _part_world(key)
	var dir: Vector2 = ((boat["pos"] as Vector2) - wp).normalized()
	debris.append({"key": key, "pos": wp, "vel": dir * 520.0, "rot": prey["rot"], "spin": randf_range(-6, 6), "loot": part["loot"], "name": part["name"], "t": 0.0})
	prey["hp"] -= RIP_DAMAGE
	prey["weight"] = maxf(0.35, prey["weight"] - 0.17)
	_blood(wp, 26)
	_popup(wp, "Вырван " + part["name"] + "!", Color(1.0, 0.75, 0.3))
	slowmo = 0.35
	shake = 0.5
	if prey["state"] in ["circle", "windup"]:
		prey["state"] = "recoil"
		prey["state_t"] = 0.8


func _release_harpoon() -> void:
	if harpoon["state"] == "attached":
		harpoon["pos"] = _harpoon_anchor()
	if harpoon["state"] in ["attached", "flying"]:
		harpoon["state"] = "returning"
		harpoon["part"] = ""


# ---------------------------------------------------------------- геометрия твари

func _part_world(key: String) -> Vector2:
	var p: Dictionary = prey["parts"][key]
	return prey["pos"] + (p["off"] * prey["scale"]).rotated(prey["rot"])


func _part_radius(key: String) -> float:
	return float(prey["parts"][key]["r"]) * prey["scale"]


func _harpoon_anchor() -> Vector2:
	if harpoon["state"] == "attached":
		return prey["pos"] + (harpoon["local"] as Vector2).rotated(prey["rot"])
	return harpoon["pos"]


func _targetable() -> bool:
	return prey["state"] != "dive" and not prey["dead"]


## Какая часть под точкой (щиток и крылья проверяются раньше тела).
func _part_at(p: Vector2) -> String:
	if not _targetable():
		return ""
	for key in ["plate", "tail", "wing_l", "wing_r", "body"]:
		var part: Dictionary = prey["parts"][key]
		if part["ripped"]:
			continue
		if p.distance_to(_part_world(key)) <= _part_radius(key):
			return key
	return ""


func _damage_part(key: String, dmg: float, pos: Vector2) -> void:
	var part: Dictionary = prey["parts"][key]
	part["hit"] = 0.15
	if key == "body":
		prey["hp"] -= dmg
		_blood(pos, 4)
		return
	if part["broken"]:
		prey["hp"] -= dmg * 0.5
		return
	part["hp"] -= dmg
	prey["hp"] -= dmg * 0.5
	_blood(pos, 3)
	if part["hp"] <= 0:
		part["hp"] = 0.0
		part["broken"] = true
		_popup(_part_world(key), "Рви!", Color(1.0, 0.55, 0.2))


# ---------------------------------------------------------------- обновление

func _process(delta: float) -> void:
	var paused: bool = Game.main != null and Game.main.has_overlay()
	if not paused:
		var real := minf(delta, 0.05)
		var dt := real * (0.25 if slowmo > 0 else 1.0)
		slowmo = maxf(0.0, slowmo - real)
		shake = maxf(0.0, shake - real * 1.6)
		if ended.is_empty():
			_update(dt)
		else:
			_update_after(dt)
	stage.queue_redraw()


func _update(dt: float) -> void:
	t += dt
	_update_boat(dt)
	_update_weapons(dt)
	_update_prey(dt)
	_update_rope(dt)
	_update_fx(dt)
	if prey["hp"] <= 0 and not prey["dead"]:
		prey["dead"] = true
		_release_harpoon()
		_popup(prey["pos"], "Добыт!", Color(1, 0.9, 0.5))
		get_tree().create_timer(1.4).timeout.connect(func():
			_end("win"))
	elif int(boat["hp"]) <= 0:
		_end("lost")
	elif t >= time_limit:
		_end("escaped")
	elif prey["fled"] and not Rect2(-120, -120, W + 240, H + 240).has_point(prey["pos"]):
		_end("escaped")


func _update_after(dt: float) -> void:
	_update_fx(dt)
	for d in debris:
		d["pos"] = (d["pos"] as Vector2).lerp(boat["pos"], 1.0 - exp(-4.0 * dt))


func _update_boat(dt: float) -> void:
	var dir := _input_dir()
	var v: Vector2 = boat["vel"]
	v += dir * BOAT_ACCEL * dt
	var limit := BOAT_MAX
	if harpoon["state"] == "attached":
		limit += prey["vel"].length() * 0.25
	if v.length() > limit and dir != Vector2.ZERO:
		v = v.lerp(v.normalized() * limit, 1.0 - exp(-6.0 * dt))
	v *= exp(-BOAT_DRAG * dt * (0.5 if dir != Vector2.ZERO else 1.0))
	boat["vel"] = v
	var np: Vector2 = boat["pos"] + v * dt
	np.x = clampf(np.x, 24, W - 24)
	np.y = clampf(np.y, WALL + 20, H - 24)
	boat["pos"] = np
	if v.length() > 20:
		boat["rot"] = lerp_angle(boat["rot"], v.angle(), 1.0 - exp(-8.0 * dt))
	boat["invuln"] = maxf(0.0, boat["invuln"] - dt)
	if int(boat["dash"]) < 3:
		boat["dash_t"] += dt
		if boat["dash_t"] >= DASH_RECHARGE:
			boat["dash_t"] = 0.0
			boat["dash"] = int(boat["dash"]) + 1
	# касание твари
	if _targetable() and boat["invuln"] <= 0:
		for key in ["plate", "body", "wing_l", "wing_r"]:
			if prey["parts"][key]["ripped"]:
				continue
			if (boat["pos"] as Vector2).distance_to(_part_world(key)) < _part_radius(key) + 16:
				var away: Vector2 = ((boat["pos"] as Vector2) - prey["pos"]).normalized()
				if prey["state"] in ["charge", "surface"] and key in ["plate", "body"]:
					_hurt_boat(away * 520.0, "Таран!")
				else:
					boat["vel"] += away * 140.0
				break


func _hurt_boat(knock: Vector2, text: String) -> void:
	boat["hp"] = int(boat["hp"]) - 1
	boat["invuln"] = 1.2
	boat["vel"] += knock
	shake = 0.7
	_splash(boat["pos"], 16, Color(0.9, 0.95, 1.0, 0.9))
	_popup(boat["pos"], text if int(boat["hp"]) > 0 else "Лодка опрокинута!", Color(1, 0.5, 0.45))


func _update_weapons(dt: float) -> void:
	spear_cd = maxf(0.0, spear_cd - dt)
	if lmb and spear_cd <= 0 and ended.is_empty():
		_throw_spear()
	var keep := []
	for s in spears:
		s["pos"] += s["vel"] * dt
		s["dist"] += SPEAR_SPEED * dt
		var key := _part_at(s["pos"])
		if key != "":
			var part: Dictionary = prey["parts"][key]
			var dmg := SPEAR_DAMAGE * (0.35 if part["armored"] and not part["broken"] else 1.0)
			_damage_part(key, dmg, s["pos"])
			continue
		if s["dist"] < SPEAR_RANGE:
			keep.append(s)
	spears = keep

	match harpoon["state"]:
		"charging":
			harpoon["charge"] = minf(harpoon["charge"] + dt, 1.5)
		"flying":
			harpoon["pos"] += harpoon["vel"] * dt
			harpoon["dist"] += harpoon["vel"].length() * dt
			var key2 := _part_at(harpoon["pos"])
			if key2 != "":
				var part2: Dictionary = prey["parts"][key2]
				if part2["armored"] and not part2["broken"]:
					_popup(harpoon["pos"], "Блок", Color(1, 0.95, 0.5))
					_splash(harpoon["pos"], 6, Color(1, 1, 0.8, 0.8))
					harpoon["state"] = "returning"
				else:
					harpoon["state"] = "attached"
					harpoon["part"] = key2
					harpoon["local"] = ((harpoon["pos"] as Vector2) - prey["pos"]).rotated(-prey["rot"])
					_damage_part(key2, HARPOON_DAMAGE, harpoon["pos"])
					prey["vel"] += (harpoon["vel"] as Vector2).normalized() * 70.0
					shake = 0.3
			elif harpoon["dist"] > HARPOON_RANGE:
				harpoon["state"] = "returning"
		"returning":
			var to: Vector2 = (boat["pos"] as Vector2) - harpoon["pos"]
			if to.length() < 26:
				harpoon["state"] = "cooldown"
				harpoon["cd"] = 0.35
			else:
				harpoon["pos"] += to.normalized() * minf(to.length(), 1300.0 * dt)
		"cooldown":
			harpoon["cd"] -= dt
			if harpoon["cd"] <= 0:
				harpoon["state"] = "charging" if rmb else "ready"
				harpoon["charge"] = 0.0
		"attached":
			if prey["parts"].get(harpoon["part"], {}).get("ripped", false):
				_release_harpoon()


func _update_rope(dt: float) -> void:
	if harpoon["state"] != "attached":
		return
	var anchor := _harpoon_anchor()
	var bp: Vector2 = boat["pos"]
	var d := bp.distance_to(anchor)
	if d > ROPE_SNAP:
		_popup((bp + anchor) / 2, "Трос лопнул", Color(1, 0.6, 0.5))
		harpoon["state"] = "cooldown"
		harpoon["cd"] = 2.5
		return
	if d > ROPE_REST:
		var stretch := d - ROPE_REST
		var dir := (anchor - bp) / d
		# тварь буксирует лодку
		boat["vel"] += dir * stretch * ROPE_K * dt
		boat["vel"] += (prey["vel"] as Vector2) * 0.9 * dt
		# а лодка держит тварь
		prey["vel"] -= dir * stretch * ROPE_K_PREY * dt


func _update_prey(dt: float) -> void:
	var p := prey
	if p["dead"]:
		p["vel"] *= exp(-2.0 * dt)
		p["pos"] += p["vel"] * dt
		return
	var bp: Vector2 = boat["pos"]
	var to_boat := bp - (p["pos"] as Vector2)
	var dist := to_boat.length()
	var harpooned: bool = harpoon["state"] == "attached"
	var mult: float = p["weight"] * (0.62 if harpooned else 1.0)
	var turn := 2.4 * (0.65 if (p["parts"]["wing_l"]["ripped"] or p["parts"]["wing_r"]["ripped"]) else 1.0)
	var desired := Vector2.from_angle(p["rot"])
	var speed := 150.0
	p["state_t"] -= dt
	p["dive_cd"] -= dt
	p["telegraph"] = maxf(0.0, p["telegraph"] - dt)
	p["alpha"] = lerpf(p["alpha"], 0.22 if p["state"] == "dive" else 1.0, 1.0 - exp(-5.0 * dt))

	if not p["fled"] and p["hp"] < p["max"] * 0.25 and p["state"] != "dive":
		p["fled"] = true
		p["state"] = "flee"
		_popup(p["pos"], "Скат уходит!", Color(0.8, 0.9, 1.0))

	match p["state"]:
		"circle":
			var radial := to_boat.normalized()
			var tangent := radial.orthogonal()
			var want := 280.0
			desired = (tangent + radial * clampf((dist - want) / 120.0, -1.0, 1.0)).normalized()
			if p["state_t"] <= 0:
				_choose_attack(dist)
		"windup":
			desired = to_boat.normalized()
			speed = 40.0
			turn *= 2.2
			if p["state_t"] <= 0:
				p["state"] = "charge"
				p["state_t"] = 1.1
		"charge":
			speed = 430.0
			turn = 0.5
			if p["state_t"] <= 0:
				p["state"] = "circle"
				p["state_t"] = randf_range(2.5, 4.0)
		"surface":
			speed = 360.0
			turn = 1.0
			desired = to_boat.normalized()
			if p["state_t"] <= 0:
				p["state"] = "circle"
				p["state_t"] = 3.0
		"lash":
			speed = 60.0
			var tail_p := _part_world("tail")
			if p["state_t"] <= 0.3 and p["state_t"] > 0.0 and bp.distance_to(tail_p) < 120.0 * p["scale"] and boat["invuln"] <= 0:
				_hurt_boat((bp - tail_p).normalized() * 420.0, "Удар хвостом!")
			p["rot"] += sin(t * 30.0) * 0.05
			if p["state_t"] <= 0:
				p["state"] = "circle"
				p["state_t"] = 2.0
		"dive":
			speed = 260.0
			var behind := bp - Vector2.from_angle(boat["rot"]) * 200.0
			desired = (behind - (p["pos"] as Vector2)).normalized()
			turn *= 1.6
			if p["state_t"] <= 0:
				p["state"] = "surface"
				p["state_t"] = 0.9
				_splash(p["pos"], 24, Color(0.8, 0.95, 1.0, 0.8))
				_popup(p["pos"], "Всплывает!", Color(1, 0.8, 0.6))
		"recoil":
			speed = 90.0
			desired = -to_boat.normalized()
			if p["state_t"] <= 0:
				p["state"] = "circle"
				p["state_t"] = 2.0
		"flee":
			speed = 230.0
			var exit := Vector2(p["pos"].x, H + 200) if p["pos"].y > H / 2 else Vector2(-200 if p["pos"].x < W / 2 else W + 200, p["pos"].y)
			desired = (exit - (p["pos"] as Vector2)).normalized()

	var ang := desired.angle()
	p["rot"] = rotate_toward(p["rot"], ang, turn * dt)
	var fwd := Vector2.from_angle(p["rot"]) * speed * mult
	p["vel"] = (p["vel"] as Vector2).lerp(fwd, 1.0 - exp(-3.0 * dt))
	var np: Vector2 = p["pos"] + p["vel"] * dt
	if not p["fled"]:
		np.x = clampf(np.x, 60, W - 60)
		np.y = clampf(np.y, WALL + 60, H - 60)
	p["pos"] = np
	for key in p["parts"]:
		p["parts"][key]["hit"] = maxf(0.0, p["parts"][key]["hit"] - dt)


func _choose_attack(dist: float) -> void:
	var p := prey
	var tail_ok: bool = not p["parts"]["tail"]["ripped"]
	var tail_close: bool = tail_ok and (boat["pos"] as Vector2).distance_to(_part_world("tail")) < 170.0 * p["scale"]
	if tail_close:
		p["state"] = "lash"
		p["state_t"] = 0.8
		p["telegraph"] = 0.5
	elif p["dive_cd"] <= 0 and randf() < 0.4:
		p["state"] = "dive"
		p["state_t"] = 2.6
		p["dive_cd"] = 9.0
		if harpoon["state"] == "attached":
			_popup(_harpoon_anchor(), "Ушёл на глубину — гарпун сорван", Color(0.8, 0.9, 1.0))
			_release_harpoon()
		_splash(p["pos"], 20, Color(0.8, 0.95, 1.0, 0.8))
	else:
		p["state"] = "windup"
		p["state_t"] = 0.85
		p["telegraph"] = 0.85


func _update_fx(dt: float) -> void:
	var keep := []
	for d in debris:
		d["t"] += dt
		d["pos"] += d["vel"] * dt
		d["vel"] *= exp(-1.8 * dt)
		d["rot"] += d["spin"] * dt
		d["spin"] *= exp(-1.5 * dt)
		if (d["pos"] as Vector2).distance_to(boat["pos"]) < 46 and d["t"] > 0.25:
			collected.append(d["loot"])
			_popup(boat["pos"], "+ " + d["name"], Color(0.7, 1.0, 0.7))
			continue
		keep.append(d)
	debris = keep
	var kp := []
	for p in particles:
		p["ttl"] -= dt
		p["pos"] += p["vel"] * dt
		p["vel"] *= exp(-3.0 * dt)
		if p["ttl"] > 0:
			kp.append(p)
	particles = kp
	var ku := []
	for u in popups:
		u["ttl"] -= dt
		u["pos"] += Vector2(0, -26) * dt
		if u["ttl"] > 0:
			ku.append(u)
	popups = ku


func _blood(pos: Vector2, n: int) -> void:
	for i in n:
		particles.append({"pos": pos, "vel": Vector2.from_angle(randf() * TAU) * randf_range(30, 170), "ttl": randf_range(0.5, 1.4), "col": Color(0.2, 0.35, 0.55, 0.85), "r": randf_range(2, 5)})


func _splash(pos: Vector2, n: int, col: Color) -> void:
	for i in n:
		particles.append({"pos": pos, "vel": Vector2.from_angle(randf() * TAU) * randf_range(60, 200), "ttl": randf_range(0.3, 0.8), "col": col, "r": randf_range(1.5, 3.5)})


func _popup(pos: Vector2, text: String, col: Color) -> void:
	popups.append({"pos": pos + Vector2(0, -20), "text": text, "col": col, "ttl": 1.4})


# ---------------------------------------------------------------- итог

func _end(outcome: String) -> void:
	if not ended.is_empty():
		return
	lmb = false
	var loot := collected.duplicate()
	for d in debris:
		loot.append(d["loot"])
	var lines := []
	if outcome == "win":
		lines.append("Крупный панцирный скат поднят к борту. Теперь лодочникам на причале будет чем хвастаться по-настоящему." if big else "Панцирный скат поднят к борту.")
		loot.append("it_skate_meat")
		if big:
			loot.append_array(["it_skate_meat", "it_skate_pearl"])
	var ripped := 0
	for key in prey["parts"]:
		if prey["parts"][key]["ripped"]:
			ripped += 1
	if ripped > 0:
		lines.append("Вырвано частей: %d." % ripped)
	elif outcome == "win":
		lines.append("Ни одной части вырвать не удалось — только мясо.")
	ended = {"outcome": outcome, "loot": loot, "summary": " ".join(PackedStringArray(lines))}
	retreat_btn.disabled = true
	var titles := {"win": "Добыча", "escaped": "Ушёл", "lost": "Лодка перевернулась", "retreat": "Отступление"}
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	var tl := Label.new()
	tl.theme_type_variation = "InkTitle"
	tl.text = titles[outcome]
	v.add_child(tl)
	var coast := Art.background("morte")
	if coast:
		var postcard := TextureRect.new()
		postcard.texture = coast
		postcard.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		postcard.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		postcard.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		postcard.custom_minimum_size = Vector2(440, 230)
		postcard.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(postcard)
	if ended["summary"] != "":
		var sl := Label.new()
		sl.theme_type_variation = "Ink"
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sl.custom_minimum_size.x = 440
		sl.text = ended["summary"]
		v.add_child(sl)
	var b := Button.new()
	b.text = "Вернуться на причал"
	b.pressed.connect(func():
		Game.finish_activity(q, ended, get_title()))
	v.add_child(b)
	end_panel.add_child(v)
	end_panel.visible = true
	await get_tree().process_frame
	end_panel.position = (size - end_panel.size) / 2


# ---------------------------------------------------------------- рисование

func _draw_stage() -> void:
	var g := stage
	_shake_off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 8.0
	g.draw_set_transform(_shake_off, 0, Vector2.ONE)
	# вода
	g.draw_rect(Rect2(0, 0, W, H), Color("0f3b52"))
	for i in 18:
		var y := WALL + i * 38.0
		var a := sin(t * 0.6 + i * 1.7) * 18.0
		g.draw_line(Vector2(0, y + a), Vector2(W, y - a), Color(0.6, 0.85, 0.95, 0.05), 2.0)
	for i in 26:
		var cx := fposmod(i * 211.0 + t * 12.0, W)
		var cy := WALL + fposmod(i * 97.0 + t * 7.0, H - WALL)
		g.draw_arc(Vector2(cx, cy), 18 + (i % 4) * 6, 0.3, 2.2, 8, Color(0.75, 0.95, 1.0, 0.05), 2.0)
	# южная стена города
	g.draw_rect(Rect2(0, 0, W, WALL), Color("9c9a90"))
	g.draw_rect(Rect2(0, WALL - 10, W, 10), Color("6e6c64"))
	for x in range(30, int(W), 170):
		g.draw_rect(Rect2(x, 6, 60, WALL - 22), Color("b5b3a8"))
		g.draw_circle(Vector2(x + 30, 14), 12, Color("2f8c86"))
		g.draw_circle(Vector2(x + 30, 30), 4, Color(0.5, 0.85, 1.0, 0.8))

	_draw_prey(g)
	for d in debris:
		_draw_part_shape(g, d["key"], d["pos"], d["rot"], prey["scale"], Color("5b7f8c"), 1.0, true)
	for p in particles:
		var c: Color = p["col"]
		c.a *= clampf(p["ttl"] * 1.5, 0, 1)
		g.draw_circle(p["pos"], p["r"], c)
	_draw_rope(g)
	for s in spears:
		var dir: Vector2 = (s["vel"] as Vector2).normalized()
		g.draw_line(s["pos"] - dir * 14, s["pos"], Color("e8e2d0"), 2.0)
	_draw_boat(g)
	_draw_aim(g)
	for u in popups:
		var c2: Color = u["col"]
		c2.a = clampf(u["ttl"], 0, 1)
		g.draw_string(Look.font("serif_bold"), u["pos"] - Vector2(150, 0), u["text"], HORIZONTAL_ALIGNMENT_CENTER, 300, 18, c2)
	g.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	_draw_hud(g)


func _draw_part_shape(g: Control, key: String, pos: Vector2, rot: float, sc: float, col: Color, alpha: float, loose := false) -> void:
	g.draw_set_transform(_shake_off + pos, rot, Vector2(sc, sc))
	col.a *= alpha
	match key:
		"wing_l", "wing_r":
			var s := -1.0 if key == "wing_l" else 1.0
			var base := Vector2(0, 0) if loose else Vector2(0, s * 24)
			var wing := PackedVector2Array([Vector2(36, 0), Vector2(22, s * 40), Vector2(0, s * 74), Vector2(-16, s * 96),
				Vector2(-24, s * 84), Vector2(-30, s * 50), Vector2(-40, s * 8), Vector2(-20, 0)])
			if loose:
				wing = Look.offset(wing, Vector2(0, -s * 48))
			else:
				wing = Look.offset(wing, base)
			g.draw_colored_polygon(wing, col)
			g.draw_polyline(wing, Color(0.1, 0.2, 0.25, 0.5 * alpha), 1.5, true)
		"tail":
			if loose:
				g.draw_line(Vector2(-40, 0), Vector2(40, 0), col, 6.0)
				g.draw_colored_polygon(PackedVector2Array([Vector2(36, -6), Vector2(62, 0), Vector2(36, 6)]), Color("ddd2b0", alpha))
			else:
				g.draw_line(Vector2(-40, 0), Vector2(-138, 0), col, 7.0)
				g.draw_colored_polygon(PackedVector2Array([Vector2(-132, -7), Vector2(-160, 0), Vector2(-132, 7)]), Color("ddd2b0", alpha))
		"plate":
			var c := Vector2.ZERO if loose else Vector2(74, 0)
			g.draw_colored_polygon(Look.ellipse(c, Vector2(30, 36), 24), col)
			g.draw_arc(c, 22, -1.2, 1.2, 12, Color(0.85, 0.95, 0.9, 0.6 * alpha), 2.0)
	g.draw_set_transform(_shake_off, 0, Vector2.ONE)


func _part_color(key: String, base: Color) -> Color:
	var part: Dictionary = prey["parts"][key]
	if part["hit"] > 0:
		return Color(1, 1, 1)
	if part["broken"]:
		var k := 0.5 + 0.5 * sin(t * 14.0)
		return base.lerp(Color(0.95, 0.15, 0.1), 0.55 + 0.35 * k)
	if part["max"] < INF and part["max"] > 0:
		var dmg: float = 1.0 - float(part["hp"]) / float(part["max"])
		return base.lerp(Color(0.7, 0.3, 0.3), dmg * 0.6)
	return base


func _draw_prey(g: Control) -> void:
	var p := prey
	var a: float = p["alpha"]
	var pos: Vector2 = p["pos"]
	var rot: float = p["rot"]
	var sc: float = p["scale"]
	var body_col := Color("2f5f6e") if not p["dead"] else Color("4d5a60")
	# тень/глубина
	g.draw_set_transform(_shake_off + pos + Vector2(8, 12), rot, Vector2(sc, sc))
	g.draw_colored_polygon(Look.ellipse(Vector2.ZERO, Vector2(80, 70), 24), Color(0, 0, 0, 0.25 * a))
	g.draw_set_transform(_shake_off, 0, Vector2.ONE)
	if p["telegraph"] > 0:
		g.draw_arc(pos, 110 * sc, 0, TAU, 40, Color(1, 0.6, 0.2, 0.6 * a), 3.0)
	for key in ["wing_l", "wing_r", "tail"]:
		if not p["parts"][key]["ripped"]:
			_draw_part_shape(g, key, pos, rot, sc, _part_color(key, body_col.lightened(0.08)), a)
	# тело
	g.draw_set_transform(_shake_off + pos, rot, Vector2(sc, sc))
	g.draw_colored_polygon(Look.ellipse(Vector2.ZERO, Vector2(62, 46), 32), Color(_part_color("body", body_col), a))
	g.draw_colored_polygon(Look.ellipse(Vector2(-6, 0), Vector2(40, 22), 24), Color(0.6, 0.85, 0.9, 0.12 * a))
	for key in ["wing_l", "wing_r", "tail", "plate"]:
		if p["parts"][key]["ripped"]:
			var o: Vector2 = p["parts"][key]["off"] * 0.55
			g.draw_circle(o, 10, Color(0.18, 0.28, 0.45, 0.9 * a))
	g.draw_set_transform(_shake_off, 0, Vector2.ONE)
	if not p["parts"]["plate"]["ripped"]:
		var pc := _part_color("plate", Color("8fb3a6"))
		_draw_part_shape(g, "plate", pos, rot, sc, pc, a)
	var eye := pos + (Vector2(58, 0) * sc).rotated(rot)
	g.draw_circle(eye + Vector2.from_angle(rot + PI / 2) * 14 * sc, 4, Color(1, 0.92, 0.5, a))
	g.draw_circle(eye + Vector2.from_angle(rot - PI / 2) * 14 * sc, 4, Color(1, 0.92, 0.5, a))


func _draw_rope(g: Control) -> void:
	var st: String = harpoon["state"]
	if st in ["ready", "charging", "cooldown"]:
		return
	var a: Vector2 = boat["pos"]
	var b := _harpoon_anchor()
	var d := a.distance_to(b)
	var sag := maxf(0.0, ROPE_REST - d) * 0.35 + 6.0
	var col := Color(0.9, 0.85, 0.7, 0.9)
	if st == "attached" and d > ROPE_REST:
		var k := clampf((d - ROPE_REST) / (ROPE_SNAP - ROPE_REST), 0, 1)
		sag = 0.0
		col = col.lerp(Color(1, 0.35, 0.3), k)
	var nrm := (b - a).orthogonal().normalized()
	var pts := PackedVector2Array()
	for i in 17:
		var u := i / 16.0
		pts.append(a.lerp(b, u) + nrm * sin(u * PI) * sag)
	g.draw_polyline(pts, col, 2.0, true)
	var dir := (b - a).normalized()
	g.draw_colored_polygon(PackedVector2Array([b + dir * 10, b + dir.orthogonal() * 5 - dir * 4, b - dir.orthogonal() * 5 - dir * 4]), Color("d8d0b8"))


func _draw_boat(g: Control) -> void:
	var pos: Vector2 = boat["pos"]
	var flicker: bool = boat["invuln"] > 0 and int(t * 12) % 2 == 0
	g.draw_set_transform(_shake_off + pos, boat["rot"], Vector2.ONE)
	g.draw_colored_polygon(Look.ellipse(Vector2(4, 6), Vector2(30, 14), 20), Color(0, 0, 0, 0.3))
	var hull := PackedVector2Array([Vector2(30, 0), Vector2(14, -12), Vector2(-26, -11), Vector2(-30, 0), Vector2(-26, 11), Vector2(14, 12)])
	g.draw_colored_polygon(hull, Color("6b4428") if not flicker else Color("c09070"))
	g.draw_polyline(hull + PackedVector2Array([hull[0]]), Color("3a2414"), 2.0, true)
	g.draw_line(Vector2(-20, 0), Vector2(18, 0), Color("4a2e1a"), 2.0)
	g.draw_set_transform(_shake_off, 0, Vector2.ONE)
	g.draw_circle(pos, 9, Color("1e2c4f"))
	g.draw_arc(pos, 9, 0, TAU, 16, Look.GOLD, 2.0)


func _draw_aim(g: Control) -> void:
	if not ended.is_empty():
		return
	var m := _mouse()
	var bp: Vector2 = boat["pos"]
	if harpoon["state"] == "charging":
		var k := clampf(harpoon["charge"] / HARPOON_MIN_CHARGE, 0, 1)
		var ready: bool = harpoon["charge"] >= HARPOON_MIN_CHARGE
		var dir := (m - bp).normalized()
		g.draw_line(bp, bp + dir * HARPOON_RANGE * 0.85, Color(1, 0.85, 0.4, 0.25 + 0.35 * k), 2.0)
		g.draw_arc(bp, 26, -PI / 2, -PI / 2 + TAU * k, 24, Color(1, 0.85, 0.4, 0.9) if ready else Color(0.9, 0.9, 0.9, 0.7), 3.0)
	g.draw_arc(m, 11, 0, TAU, 20, Color(1, 0.95, 0.8, 0.85), 1.5)
	g.draw_line(m - Vector2(16, 0), m - Vector2(6, 0), Color(1, 0.95, 0.8, 0.7), 1.0)
	g.draw_line(m + Vector2(6, 0), m + Vector2(16, 0), Color(1, 0.95, 0.8, 0.7), 1.0)


func _draw_hud(g: Control) -> void:
	var f := Look.font("serif")
	var y := H - 16.0
	var txt := "Лодка: %s    Рывки: %s    Гарпун: %s    %d с" % [
		"♥".repeat(maxi(0, int(boat["hp"]))), "●".repeat(int(boat["dash"])) + "○".repeat(3 - int(boat["dash"])),
		{"ready": "готов", "charging": "заряд", "flying": "летит", "attached": "держит", "returning": "возвращается", "cooldown": "перезарядка"}.get(harpoon["state"], ""),
		maxi(0, int(ceil(time_limit - t)))]
	g.draw_rect(Rect2(0, H - 40, W, 40), Color(0, 0, 0, 0.45))
	g.draw_string(f, Vector2(16, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("e8dcc0"))
	# здоровье твари и её части
	var bw := 280.0
	var bx := W - bw - 16
	g.draw_rect(Rect2(bx, H - 30, bw, 12), Color(0.15, 0.1, 0.1, 0.8))
	g.draw_rect(Rect2(bx, H - 30, bw * clampf(prey["hp"] / prey["max"], 0, 1), 12), Color(0.75, 0.25, 0.2))
	var px := bx - 10
	for key in ["tail", "wing_r", "wing_l", "plate"]:
		var part: Dictionary = prey["parts"][key]
		var col := Color(0.5, 0.75, 0.8)
		if part["ripped"]:
			col = Color(0.35, 0.35, 0.35)
		elif part["broken"]:
			col = Color(1, 0.3, 0.2) if int(t * 6) % 2 == 0 else Color(1, 0.7, 0.3)
		var label: String = {"tail": "хв", "wing_r": "пк", "wing_l": "лк", "plate": "щт"}[key]
		var w := 34.0
		px -= w + 4
		g.draw_rect(Rect2(px, H - 34, w, 20), Color(col, 0.35))
		g.draw_string(f, Vector2(px, H - 18), label, HORIZONTAL_ALIGNMENT_CENTER, w, 14, col)
