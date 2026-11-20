extends Control
## ВРЕМЕННАЯ активность «Охота у акватории Морт» — заготовка будущей «рыбалки».
## Вид сверху. Лодка ходит свободно. Гарпун заряжается и вонзается в конкретную часть твари;
## трос работает как пружина — тварь буксирует лодку, а лодка удерживает тварь.
## Части тела копят урон; разрушенная часть мигает, и рывок троса вырывает её — это и есть добыча.
## У твари есть фазы: кружение, таран с замахом, удар хвостом, уход на глубину (срывает гарпун), бегство.
## Интерфейс активности: setup(params, queue_item), get_title(); по окончании — Game.finish_activity().

const Regalia = preload("res://ui/regalia.gd")

const W := 1280.0
const H := 720.0
const WALL := 70.0                # у верхнего края — южная стена города
const ACTIVITY_ART := "res://assets/art/activities/"
const INSTRUMENT := Color("091a22")
const BRASS_LIGHT := Color("cfb481")
const HUD_INK := Color("e5e0d2")
const SEA_GLASS := Color("95bbb9")
const RAY_RECT := Rect2(-164, -122, 270, 244)
const PART_LABELS := {"plate": "Щиток", "wing_l": "Л. крыло", "wing_r": "П. крыло", "tail": "Хвост"}
const HARPOON_LABELS := {
	"ready": "Готов", "charging": "Заряжается", "flying": "Летит",
	"attached": "Держит", "returning": "Возвращается", "cooldown": "Перезарядка",
}

# Границы на спрайте идут по сочленениям. Каждая часть может мигать и отделяться.
const RAY_REGIONS := {
	"body": [Vector2(-52, -12), Vector2(-62, -20), Vector2(-35, -32), Vector2(15, -36),
		Vector2(58, -27), Vector2(50, 0), Vector2(58, 27), Vector2(15, 36),
		Vector2(-35, 32), Vector2(-62, 20), Vector2(-52, 12)],
	"plate": [Vector2(58, -27), Vector2(106, -27), Vector2(106, 27), Vector2(58, 27), Vector2(50, 0)],
	"tail": [Vector2(-164, -24), Vector2(-62, -20), Vector2(-52, -12), Vector2(-52, 12),
		Vector2(-62, 20), Vector2(-164, 24)],
	"wing_l": [Vector2(-164, -122), Vector2(106, -122), Vector2(106, -27), Vector2(58, -27),
		Vector2(15, -36), Vector2(-35, -32), Vector2(-62, -20), Vector2(-164, -24)],
	"wing_r": [Vector2(-164, 24), Vector2(-62, 20), Vector2(-35, 32), Vector2(15, 36),
		Vector2(58, 27), Vector2(106, 27), Vector2(106, 122), Vector2(-164, 122)],
}

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
var dash_recharge := DASH_RECHARGE

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
var heading: Label
var hint: Label
var end_panel: PanelContainer
var retreat_btn: Button
var water_texture: Texture2D
var boat_texture: Texture2D
var ray_texture: Texture2D
var ray_uvs := {}


func setup(p: Dictionary, queue_item: Dictionary) -> void:
	params = p
	q = queue_item
	big = bool(p.get("big", false))
	# состояния на столе: "mods": {"hunt": {"time": ±секунды, "dash": множитель перезарядки рывка}}
	for cid in Game.state.get("cards", {}):
		var hm: Dictionary = Content.def(cid).get("mods", {}).get("hunt", {})
		time_limit += float(hm.get("time", 0))
		dash_recharge *= float(hm.get("dash", 1.0))
	time_limit = maxf(time_limit, 60.0)


func get_title() -> String:
	return "Охота у акватории Морт"


# ---------------------------------------------------------------- создание

func _ready() -> void:
	Sound.environment("backgrounds", "morte", Rules.phase_key(Game.state))
	_prepare_art()
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
	bgc.color = Color("07151f")
	bgc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bgc)
	heading = Label.new()
	heading.text = get_title()
	heading.add_theme_font_override("font", Look.font("display_bold"))
	heading.add_theme_font_size_override("font_size", 36)
	heading.add_theme_color_override("font_color", HUD_INK)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(heading)
	hint = Label.new()
	hint.text = "WASD — лодка    Пробел — рывок    ЛКМ — пики    ПКМ — зарядить и бросить гарпун · повторно — дёрнуть трос"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", SEA_GLASS)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)
	stage = Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_STOP
	stage.clip_contents = true
	stage.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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


func _prepare_art() -> void:
	water_texture = _activity_texture("harpoon_water.webp")
	boat_texture = _activity_texture("harpoon_boat.png")
	ray_texture = _activity_texture("harpoon_ray.png")
	for key in RAY_REGIONS:
		var uvs := PackedVector2Array()
		for point: Vector2 in RAY_REGIONS[key]:
			uvs.append((point - RAY_RECT.position) / RAY_RECT.size)
		ray_uvs[key] = uvs


func _activity_texture(file: String) -> Texture2D:
	var path := ACTIVITY_ART + file
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func _part(name: String, off: Vector2, r: float, hp: float, armored: bool, loot: String) -> Dictionary:
	return {"name": name, "off": off, "r": r, "hp": hp, "max": hp, "armored": armored, "loot": loot,
		"broken": false, "ripped": false, "hit": 0.0}


func _layout() -> void:
	var s := size if size.x > 10 else get_viewport_rect().size
	var k := maxf(0.05, minf((s.x - 60) / W, (s.y - 128) / H))
	stage.size = Vector2(W, H)
	stage.scale = Vector2(k, k)
	stage.position = Vector2((s.x - W * k) / 2, 62)
	heading.position = Vector2(stage.position.x, 7)
	var footer_y := stage.position.y + H * k + 10
	retreat_btn.reset_size()
	retreat_btn.position = Vector2(stage.position.x + W * k - retreat_btn.size.x, footer_y)
	hint.position = Vector2(stage.position.x, footer_y + 9)
	hint.size.x = maxf(1.0, retreat_btn.position.x - hint.position.x - 20)
	if end_panel.visible:
		end_panel.position = (s - end_panel.size) / 2


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
	Sound.play("boat_splash", -5.0)
	_splash(boat["pos"], 10, Color(0.8, 0.95, 1.0, 0.8))


func _throw_spear() -> void:
	var from: Vector2 = boat["pos"]
	var dir := (_mouse() - from).normalized()
	spears.append({"pos": from + dir * 20, "vel": dir * SPEAR_SPEED, "dist": 0.0})
	spear_cd = SPEAR_COOLDOWN


func _fire_harpoon() -> void:
	Sound.play("boat_spool")
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
		if boat["dash_t"] >= dash_recharge:
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
	Sound.play("boat_hull")
	if int(boat["hp"]) == 2:
		Sound.play("danger")
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
		Sound.play("boat_line_break")
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
				Sound.play("boat_splash")
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
	if not loot.is_empty():
		v.add_child(_loot_grid(loot))
	var b := Button.new()
	b.text = "Вернуться на причал"
	b.pressed.connect(func():
		Game.finish_activity(q, ended, get_title()))
	v.add_child(b)
	end_panel.add_child(v)
	end_panel.visible = true
	await get_tree().process_frame
	end_panel.position = (size - end_panel.size) / 2


func _loot_grid(loot: Array) -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 5)
	var counts := {}
	for id in loot:
		counts[id] = int(counts.get(id, 0)) + 1
	for id in counts:
		var row := HBoxContainer.new()
		row.custom_minimum_size.x = 215
		row.add_theme_constant_override("separation", 7)
		var icon := TextureRect.new()
		icon.texture = Art.prop(id)
		icon.custom_minimum_size = Vector2(42, 38)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var label := Label.new()
		label.theme_type_variation = "InkSoft"
		label.add_theme_font_size_override("font_size", 13)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text = str(Content.def(id).get("title", id))
		if counts[id] > 1:
			label.text += " ×%d" % counts[id]
		row.add_child(label)
		grid.add_child(row)
	return grid


# ---------------------------------------------------------------- рисование

func _draw_stage() -> void:
	var g := stage
	_shake_off = Vector2(sin(t * 121), cos(t * 163)) * shake * 8.0
	g.draw_set_transform(_shake_off, 0, Vector2.ONE)
	_draw_water(g)
	if prey["state"] != "dive":
		_draw_wake(g, prey["pos"], prey["vel"], prey["scale"] * 2.1, 0.33)
	_draw_wake(g, boat["pos"], boat["vel"], 1.0, 0.7)
	_draw_prey(g)
	for d in debris:
		if ray_texture:
			_draw_ray_region(g, d["key"], d["pos"], d["rot"], prey["scale"], Color("c9d9d3"), true)
		else:
			_draw_part_shape(g, d["key"], d["pos"], d["rot"], prey["scale"], Color("5b7f8c"), 1.0, true)
	for p in particles:
		var c: Color = p["col"]
		c.a *= clampf(p["ttl"] * 1.5, 0, 1)
		g.draw_circle(p["pos"], p["r"], c, true, -1.0, true)
	_draw_rope(g)
	for s in spears:
		var dir: Vector2 = (s["vel"] as Vector2).normalized()
		g.draw_line(s["pos"] - dir * 49, s["pos"] - dir * 15, Color(0.8, 0.95, 1.0, 0.24), 1.5, true)
		g.draw_line(s["pos"] - dir * 16, s["pos"], BRASS_LIGHT, 2.0, true)
		_draw_hook(g, s["pos"], dir, 0.55)
	_draw_boat(g)
	_draw_aim(g)
	var popup_font := Look.font("serif_bold")
	for u in popups:
		var c2: Color = u["col"]
		c2.a = clampf(u["ttl"], 0, 1)
		var start: Vector2 = u["pos"] - Vector2(220, 0)
		g.draw_string_outline(popup_font, start, u["text"], HORIZONTAL_ALIGNMENT_CENTER, 440, 17, 5, Color(INSTRUMENT, 0.88 * c2.a))
		g.draw_string(popup_font, start, u["text"], HORIZONTAL_ALIGNMENT_CENTER, 440, 17, c2)
	g.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	g.draw_rect(Rect2(0.5, 0.5, W - 1.0, H - 1.0), Color(BRASS_LIGHT, 0.67), false, 1.0)
	_draw_hud(g)


func _draw_water(g: Control) -> void:
	var field := Rect2(0, 0, W, H)
	if water_texture:
		g.draw_texture_rect(water_texture, field.grow(8), false)
	else:
		var water := PackedVector2Array([Vector2(-8, WALL), Vector2(W + 8, WALL), Vector2(W + 8, H + 8), Vector2(-8, H + 8)])
		g.draw_polygon(water, PackedColorArray([Color("234650"), Color("143844"), Color("0a2636"), Color("112b3b")]))
		g.draw_rect(Rect2(-8, -8, W + 16, WALL + 8), Color("53594f"))
		g.draw_rect(Rect2(-8, WALL - 14, W + 16, 14), Color("303f3e"))
		g.draw_line(Vector2(-8, WALL), Vector2(W + 8, WALL), Color("798579"), 2.0)
		for x in range(0, int(W), 112):
			g.draw_line(Vector2(x, 2), Vector2(x + 14, WALL - 3), Color("343d36"), 2.0, true)
	for idx in 52:
		var length := 15.0 + fposmod(idx * 13.3, 43.0)
		var x := fposmod(idx * 217.43 + t * (13.0 + idx % 5), W)
		var y := WALL + 8 + fposmod(idx * 71.3 + t * 2.4, H - WALL - 12)
		var drift := Vector2(x, y)
		var alpha := (0.5 + 0.5 * sin(t * 1.4 + idx * 1.9)) * 0.16
		g.draw_polyline(PackedVector2Array([drift, drift + Vector2(length * 0.43, -1.5),
			drift + Vector2(length * 0.7, -1.1), drift + Vector2(length, 1.0)]), Color(SEA_GLASS, alpha), 1.2, true)


func _draw_wake(g: Control, pos: Vector2, velocity: Vector2, scale_factor: float, opacity: float) -> void:
	var strength := clampf(velocity.length() / BOAT_MAX, 0.0, 1.0)
	if strength < 0.08:
		return
	g.draw_set_transform(_shake_off + pos, velocity.angle(), Vector2.ONE * scale_factor)
	for i in 5:
		var phase := fposmod(t * 2.4 + i * 0.2, 1.0)
		var span := 8.0 + phase * 18.0
		var aft := 5.0 + phase * (34.0 + strength * 45.0)
		var alpha := sin(phase * PI) * opacity * strength
		for side: float in [-1.0, 1.0]:
			g.draw_polyline(PackedVector2Array([Vector2(-aft - 14, span * side), Vector2(-aft - 5, (span - 5) * side),
				Vector2(-aft + 5, (span - 8) * side)]), Color(Color("b8d9d6"), alpha), 1.7, true)
	g.draw_set_transform(_shake_off, 0, Vector2.ONE)


func _draw_ray_region(g: Control, key: String, pos: Vector2, rot: float, sc: float, tint: Color, loose := false) -> void:
	var origin := (prey["parts"][key]["off"] as Vector2) if loose else Vector2.ZERO
	g.draw_set_transform(_shake_off + pos - (origin * sc).rotated(rot), rot, Vector2.ONE * sc)
	g.draw_polygon(PackedVector2Array(RAY_REGIONS[key]), PackedColorArray([tint]), ray_uvs[key], ray_texture)
	g.draw_set_transform(_shake_off, 0, Vector2.ONE)


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
	g.draw_set_transform(_shake_off + pos + Vector2(9, 13), rot, Vector2(sc, sc))
	for i in 3:
		var shadow_size := Vector2(77, 50) + Vector2(6, 6) * i
		g.draw_colored_polygon(Look.ellipse(Vector2.ZERO, shadow_size, 28), Color(0.01, 0.08, 0.11, 0.12 * a))
	g.draw_set_transform(_shake_off, 0, Vector2.ONE)
	if p["telegraph"] > 0:
		var pulse := 0.55 + 0.45 * sin(t * 20.0)
		var warning := Color(1.0, 0.65, 0.28, (0.58 + 0.34 * pulse) * a)
		if p["state"] == "lash":
			g.draw_arc(_part_world("tail"), 120 * sc, 0, TAU, 56, warning, 2, true)
		else:
			var front := pos + Vector2.from_angle(rot) * 100.0 * sc
			var dir := Vector2.from_angle(rot)
			g.draw_dashed_line(front, front + dir * 165.0 * sc, warning, 2.0, 11.0, true, true)
			g.draw_arc(pos, 106 * sc, rot - 0.55, rot + 0.55, 24, warning, 2.5, true)
	if ray_texture:
		for key in ["wing_l", "wing_r", "tail", "body", "plate"]:
			if not p["parts"][key]["ripped"]:
				var base := Color("799193") if p["dead"] or p["state"] == "dive" else Color.WHITE
				var tint := _part_color(key, base)
				if p["parts"][key]["hit"] > 0:
					tint = Color(1.35, 1.35, 1.35)
				tint.a = a
				_draw_ray_region(g, key, pos, rot, sc, tint)
		return
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
	g.draw_polyline(Look.offset(pts, Vector2(1, 2)), Color(INSTRUMENT, 0.8), 3.5, true)
	g.draw_polyline(pts, col, 2.0, true)
	_draw_hook(g, b, (b - a).normalized(), 1.0)


func _draw_hook(g: Control, tip: Vector2, dir: Vector2, k: float) -> void:
	var side := dir.orthogonal() * k
	var back := tip - dir * 14.0 * k
	var barb := tip + dir * 3.0 * k
	var shape := PackedVector2Array([barb, back + side * 5.0, tip - dir * 9.0 * k, back - side * 5.0])
	g.draw_colored_polygon(shape, Color("d8d6c5"))
	g.draw_line(back, barb, Color("fdf1cb"), 1.0, true)


func _draw_boat(g: Control) -> void:
	var pos: Vector2 = boat["pos"]
	var flicker: bool = boat["invuln"] > 0 and int(t * 12) % 2 == 0
	g.draw_set_transform(_shake_off + pos, boat["rot"], Vector2.ONE)
	g.draw_colored_polygon(Look.ellipse(Vector2(3, 5), Vector2(36, 17), 26), Color(INSTRUMENT, 0.55))
	if boat_texture:
		var boat_size := boat_texture.get_size()
		boat_size *= minf(77.0 / boat_size.x, 41.0 / boat_size.y)
		var color := Color(1, 0.55, 0.44) if flicker else Color.WHITE
		g.draw_texture_rect(boat_texture, Rect2(-boat_size * 0.5, boat_size), false, color)
	else:
		var hull := PackedVector2Array([Vector2(35, 0), Vector2(16, -15), Vector2(-26, -15), Vector2(-34, -7),
			Vector2(-34, 7), Vector2(-26, 15), Vector2(16, 15)])
		g.draw_colored_polygon(hull, Color("704934") if not flicker else Color("c09070"))
		for y: float in [-8.0, -4.0, 0.0, 4.0, 8.0]:
			g.draw_line(Vector2(-27, y), Vector2(27 - absf(y), y), Color("a06d44"), 1.1, true)
		Look.outline(g, hull, BRASS_LIGHT, 2.0)
		for x: float in [-21.0, 9.0]:
			g.draw_rect(Rect2(x - 3, -11, 6, 22), Color("352922"))
		g.draw_circle(Vector2(17, 0), 5, BRASS_LIGHT, false, 2.0, true)
		g.draw_line(Vector2(-1, 0), Vector2(25, 0), Color("dbd1b6"), 2.0, true)
	g.draw_set_transform(_shake_off, 0, Vector2.ONE)


func _draw_aim(g: Control) -> void:
	if not ended.is_empty():
		return
	var m := _mouse()
	var bp: Vector2 = boat["pos"]
	if not Rect2(0, 0, W, H).has_point(m):
		return
	var key := _part_at(m)
	var reticle_color := Color(BRASS_LIGHT, 0.9) if key.is_empty() else Color("f4d593")
	if harpoon["state"] == "charging":
		var k := clampf(harpoon["charge"] / HARPOON_MIN_CHARGE, 0, 1)
		var ready: bool = harpoon["charge"] >= HARPOON_MIN_CHARGE
		var dir := (m - bp).normalized()
		g.draw_dashed_line(bp + dir * 37.0, bp + dir * HARPOON_RANGE * 0.85, Color(BRASS_LIGHT, 0.35 + 0.35 * k), 1.7, 7.0, true, true)
		g.draw_arc(bp, 29, 0, TAU, 32, Color(INSTRUMENT, 0.86), 4.0, true)
		g.draw_arc(bp, 29, -PI / 2, -PI / 2 + TAU * k, 32, Color("f7d187") if ready else HUD_INK, 3.0, true)
	g.draw_arc(m, 11, 0, TAU, 26, Color(INSTRUMENT, 0.72), 3.0, true)
	g.draw_arc(m, 11, 0, TAU, 26, reticle_color, 1.0, true)
	for dir in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		g.draw_line(m + dir * 9, m + dir * 16, reticle_color, 1.5, true)
	g.draw_circle(m, 2, reticle_color, true, -1.0, true)
	if not key.is_empty() and key != "body":
		var label := str(PART_LABELS[key])
		var f := Look.font("serif_bold")
		var origin := Vector2(clampf(m.x - 52.0, 5.0, W - 109.0), m.y + 30.0)
		g.draw_string_outline(f, origin, label, HORIZONTAL_ALIGNMENT_CENTER, 104, 13, 5, INSTRUMENT)
		g.draw_string(f, origin, label, HORIZONTAL_ALIGNMENT_CENTER, 104, 13, reticle_color)


func _draw_hud(g: Control) -> void:
	var display := Look.font("display_bold")
	var label := Look.font("sans")
	var brass := Color("dfab6b")
	var teal := Color("7ad7d1")
	var navy := Color("193744")
	Regalia.panel(g, Rect2(12, 7, 252, 81), navy, 22)
	Look.text_c(g, label, 73, 30, "Корпус", 16, HUD_INK, 95)
	Look.text_c(g, label, 197, 30, "Рывки", 16, HUD_INK, 95)
	for i in 3:
		var hull := Vector2(42 + i * 32, 56)
		var intact := i < int(boat["hp"])
		Regalia.gem(g, hull, 12, Color("d87d66"), intact)
		if intact:
			var rim := PackedVector2Array([hull + Vector2(-5, -3), hull + Vector2(5, -3), hull + Vector2(3, 3), hull + Vector2(-3, 3), hull + Vector2(-5, -3)])
			g.draw_polyline(rim, Regalia.IVORY, 1.15, true)
		var dash := Vector2(165 + i * 32, 56)
		var charged := i < int(boat["dash"])
		Regalia.gem(g, dash, 12, teal, charged)
		if charged:
			g.draw_polyline(PackedVector2Array([dash + Vector2(-4, -4), dash + Vector2(2, 0), dash + Vector2(-4, 4)]), Regalia.IVORY, 1.25, true)
		elif i == int(boat["dash"]):
			var charge := clampf(boat["dash_t"] / dash_recharge, 0.0, 1.0)
			if charge > 0.0:
				g.draw_arc(dash, 14.5, -PI / 2, -PI / 2 + TAU * charge, 24, teal, 2, true)

	Regalia.panel(g, Rect2(W * 0.5 - 292, 7, 584, 81), navy, 23)
	var prey_name := "Крупный панцирный скат" if big else "Панцирный скат"
	var health := clampf(prey["hp"] / prey["max"], 0.0, 1.0)
	Regalia.dial(g, Vector2(392, 46), 33, health, Color("ed957e"), str(ceili(maxf(0.0, prey["hp"]))))
	var name_y := 31 if big else 44
	g.draw_multiline_string(display, Vector2(438, name_y), prey_name, HORIZONTAL_ALIGNMENT_LEFT, 227, 20, 2, HUD_INK, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND)
	g.draw_string(label, Vector2(439, 73 if big else 65), "Здоровье из %d" % int(prey["max"]), HORIZONTAL_ALIGNMENT_LEFT, 226, 13, SEA_GLASS)
	var x := 694.0
	for key in PART_LABELS:
		var part: Dictionary = prey["parts"][key]
		var pct := clampf(float(part["hp"]) / float(part["max"]), 0.0, 1.0)
		var tint := teal
		var mark := ""
		if part["ripped"]:
			pct = 0.0
			mark = "×"
		elif part["broken"]:
			pct = 1.0
			tint = brass.lerp(Color("fff0b6"), 0.5 + 0.5 * sin(t * 7.0))
			mark = "!"
		Regalia.dial(g, Vector2(x, 40), 21, pct, tint, mark)
		Look.text_c(g, label, x, 75, PART_LABELS[key], 12, SEA_GLASS, 57)
		x += 63.0

	Regalia.panel(g, Rect2(W - 265, 7, 253, 81), navy, 23)
	var hook := Vector2(W - 228, 46)
	var state_name := str(harpoon["state"])
	var hook_color := teal if state_name == "ready" or state_name == "attached" else brass
	Regalia.gem(g, hook, 24, hook_color.darkened(0.45))
	_draw_hook(g, hook + Vector2(9, -9), Vector2(1, -1).normalized(), 1.15)
	g.draw_string(label, Vector2(W - 195, 38), "Гарпун", HORIZONTAL_ALIGNMENT_LEFT, 90, 14, SEA_GLASS)
	g.draw_string(display, Vector2(W - 195, 61), HARPOON_LABELS[state_name], HORIZONTAL_ALIGNMENT_LEFT, 103, 16, HUD_INK)
	var seconds := maxi(0, int(ceil(time_limit - t)))
	var time_text := "%d:%02d" % [floori(seconds / 60.0), seconds % 60]
	var time_color := brass if seconds > 15 else Color("ed7d64")
	Regalia.dial(g, Vector2(W - 48, 46), 32, float(seconds) / maxf(1.0, time_limit), time_color, time_text)
