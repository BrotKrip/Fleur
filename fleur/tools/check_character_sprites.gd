extends SceneTree
## Проверяет, что вся текущая база персонажей имеет импортированные прозрачные PNG.
## Godot --headless --path fleur --script res://tools/check_character_sprites.gd

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var content = root.get_node("Content")
	# Зависимость от Content доступна после создания автозагрузок.
	var art = load("res://ui/art.gd")
	var bad := 0
	var hashes := {}
	var ids: Array = content.characters.keys()
	ids.sort()
	for pid in ids:
		var path := "res://assets/art/characters/%s.png" % pid
		if not ResourceLoader.exists(path):
			push_error("Нет импортированного базового спрайта: " + path)
			bad += 1
			continue
		var sprite: Texture2D = art.portrait(pid)
		if sprite == null or sprite.resource_path != path:
			push_error("Art.portrait не подхватил базовый PNG: " + str(pid))
			bad += 1
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image == null or image.is_empty():
			push_error("Не читается PNG: " + path)
			bad += 1
			continue
		if image.detect_alpha() == Image.ALPHA_NONE or not image.get_used_rect().has_area():
			push_error("Пустой спрайт или отсутствует прозрачность: " + path)
			bad += 1
		var transparent := 0
		var solid := 0
		for y in 32:
			for x in 32:
				var alpha := image.get_pixel(int((x + 0.5) * image.get_width() / 32.0), int((y + 0.5) * image.get_height() / 32.0)).a
				if alpha <= 0.01:
					transparent += 1
				if alpha >= 0.95:
					solid += 1
		if transparent < 50 or solid < 50:
			push_error("Нет прозрачного фона или непрозрачной фигуры: " + path)
			bad += 1
		if image.get_width() < 700 or image.get_height() < 1000:
			push_error("Недостаточное разрешение: " + path)
			bad += 1
		var hash := FileAccess.get_sha256(path)
		if hashes.has(hash):
			push_error("Одинаковые спрайты у разных персонажей: %s / %s" % [hashes[hash], pid])
			bad += 1
		hashes[hash] = pid
	print("CHARACTER SPRITES: ", ids.size(), " checked, ", bad, " errors")
	quit(0 if bad == 0 else 1)
