class_name Art
extends RefCounted
## Единая точка доступа к временным артам. Точный ID имеет приоритет над алиасом.
## При отсутствии ресурса экраны продолжают использовать процедурное рисование.

const ROOT := "res://assets/art/"
const BACKGROUNDS := {
	"apartment_morning": "apartment", "apartment_evening": "apartment", "apartment_night": "apartment",
	"vasari": "city", "lutes": "cafe", "tiori": "boutique",
	"docks": "coast", "docks_night": "coast",
	"debor": "manor", "debor_hall": "manor", "debor_bar": "bar",
	"steambird": "city",
}

static var _textures: Dictionary = {}


## Материалы столешницы, подложки и печатных листов.
static func surface(id: String) -> Texture2D:
	return _texture(ROOT + "materials/" + id + ".png")


## Отдельные предметы с прозрачным фоном.
static func prop(id: String) -> Texture2D:
	return _texture(ROOT + "props/" + id + ".png")


static func background(id: String) -> Texture2D:
	var exact := _texture(ROOT + "backgrounds/" + id + ".png")
	if exact:
		return exact
	var alias: String = str(BACKGROUNDS.get(id, ""))
	return _texture(ROOT + "backgrounds/" + alias + ".png") if alias != "" else null


## Спрайт персонажа. mood — эмоция из сцены («улыбка», "smile"...).
## Ищется: characters/<id>/<эмоция>.png, затем characters/<id>_<эмоция>.png,
## затем обычный спрайт (characters/<id>/neutral.png или characters/<id>.png).
## Русские названия эмоций переводятся в имена файлов через "mood_aliases" в data/world.json.
static func portrait(pid: String, mood := "") -> Texture2D:
	var file := mood_file(mood)
	if file != "" and file != "neutral":
		for path in [ROOT + "characters/" + pid + "/" + file + ".png", ROOT + "characters/" + pid + "_" + file + ".png"]:
			var found := _texture(path)
			if found:
				return found
		_warn_missing(pid, file)
	var neutral := _texture(ROOT + "characters/" + pid + "/neutral.png")
	return neutral if neutral else _texture(ROOT + "characters/" + pid + ".png")


static func mood_file(mood: String) -> String:
	var key := mood.strip_edges().to_lower()
	if key == "":
		return ""
	return str(Content.world.get("mood_aliases", {}).get(key, key))


static var _warned: Dictionary = {}


static func _warn_missing(pid: String, file: String) -> void:
	var key := pid + "/" + file
	if _warned.has(key) or not _texture(ROOT + "characters/" + pid + ".png") and not _texture(ROOT + "characters/" + pid + "/neutral.png"):
		return
	_warned[key] = true
	push_warning("Нет спрайта эмоции: %scharacters/%s/%s.png — показан обычный." % [ROOT, pid, file])


static func background_tint(id: String) -> Color:
	# Точные варианты уже содержат собственное освещение.
	if _texture(ROOT + "backgrounds/" + id + ".png"):
		return Color.WHITE
	if id.ends_with("_night"):
		return Color(0.38, 0.48, 0.68)
	if id.ends_with("_evening"):
		return Color(0.86, 0.63, 0.49)
	return Color.WHITE


static func cover_region(texture: Texture2D, target: Vector2) -> Rect2:
	# Центральная вырезка без растяжения — общая для открыток и портретных карточек.
	var source := texture.get_size()
	var ratio := maxf(target.x / source.x, target.y / source.y)
	var crop := target / ratio
	return Rect2((source - crop) * 0.5, crop)


static func _texture(path: String) -> Texture2D:
	if _textures.has(path):
		return _textures[path] as Texture2D
	if not ResourceLoader.exists(path):
		return null
	var texture := load(path) as Texture2D
	if texture:
		_textures[path] = texture
	return texture
