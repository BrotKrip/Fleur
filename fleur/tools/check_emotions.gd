extends SceneTree
## Проверка покрытия эмоций, прозрачности PNG и синтаксиса сцен.
## Godot --headless --path fleur --script res://tools/check_emotions.gd
## Для игровых скриншотов и листов просмотра убрать --headless и добавить -- --screens=<папка>

const ART_ROOT := "res://assets/art/characters/"
var failed := 0
var output := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screens="):
			output = arg.substr(10)
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	if not ok:
		failed += 1
		push_error(message)


func _run() -> void:
	if output != "" and DisplayServer.get_name() == "headless":
		push_error("Для --screens нужен запуск без --headless.")
		quit(1)
		return
	var catalog := _catalog()
	var timeout := 90.0 + (catalog.size() * 3.0 if output != "" else 0.0)
	create_timer(timeout).timeout.connect(func():
		push_error("Проверка эмоций превысила отведённое время.")
		quit(1))
	var content = root.get_node("Content")
	# При --script автозагрузки регистрируются после компиляции SceneTree.
	# Загружаем Art здесь, когда Content уже доступен.
	var art = load("res://ui/art.gd")
	var required := {}
	for scene in content.scenes.values():
		for node in scene.get("nodes", []):
			var pid := ""
			var mood := ""
			if node.has("show"):
				pid = str(node["show"])
				mood = str(node.get("mood", ""))
			elif node.has("mood"):
				pid = str(node["mood"])
				mood = str(node.get("as", ""))
			elif node.has("s") and node.has("as"):
				pid = str(node["s"])
				mood = str(node["as"])
			var file: String = art.mood_file(mood)
			if pid != "" and file != "" and file != "neutral":
				required[pid + "/" + file] = true
	for key: String in required:
		var pieces := key.split("/", true, 1)
		check(catalog.get(pieces[0], {}).has(pieces[1]), "Нет нужной эмоции: " + key)
	for mood in ["smile", "serious"]:
		check(ResourceLoader.exists(ART_ROOT + "char_tiori/" + mood + ".png"), "Нет дополнительной эмоции Тиори: " + mood)
	var image_count := 0
	for pid: String in catalog:
		for mood: String in catalog[pid]:
			_check_image(art, pid, mood, catalog[pid][mood])
			image_count += 1
	print("ART COVERAGE: ", required.size(), " используемых эмоций; персонажей с вариантами: ", catalog.size(), "; PNG: ", image_count)
	check(art._expressions.size() <= art.EXPRESSION_CACHE_LIMIT, "Кэш эмоций превысил свой предел")
	if failed > 0:
		quit(1)
		return

	# Проверяем настоящий проигрыватель с безопасной тестовой сценой, не меняя сюжет.
	var game = root.get_node("Game")
	var rules = root.get_node("Rules")
	game.settings["autosave"] = false
	game.settings["text_speed"] = 0
	root.add_child(load("res://main.tscn").instantiate())
	await create_timer(1.4).timeout
	game.state = rules.new_state()
	var sample := "@id __emotion_check\n@bg vasari\n@show char_charlotte right улыбка\nN: Выход на сцену с улыбкой.\nchar_charlotte [серьёзно]: Реплика меняет выражение лица.\n@mood char_charlotte тревога\nN: Смена эмоции во время повествования.\nchar_charlotte [обычно]: Возврат к базовому спрайту.\n@hide char_charlotte\n@show char_josie left смех\nN: Жози выходит на сцену со смехом."
	content.scenes["__emotion_check"] = content.parse_scene(sample, "__emotion_check.scene")
	game.enter_scene("__emotion_check", {})
	await create_timer(3.0).timeout
	var vn = game.main.screen
	if vn == null or not vn.has_method("_advance"):
		check(false, "Тестовая сцена не открылась")
		quit(1)
		return
	check(_portrait_is(vn, "char_charlotte", "char_charlotte/smile.png"), "@show: неверная эмоция")
	await _shot("scene_01_smile")
	vn._advance()
	await create_timer(0.25).timeout
	check(_portrait_is(vn, "char_charlotte", "char_charlotte/serious.png"), "Реплика: неверная эмоция")
	vn._advance()
	await create_timer(0.25).timeout
	check(_portrait_is(vn, "char_charlotte", "char_charlotte/worried.png"), "@mood: неверная эмоция")
	await _shot("scene_02_worried")
	vn._advance()
	await create_timer(0.25).timeout
	check(_portrait_is(vn, "char_charlotte", "characters/char_charlotte.png"), "[обычно]: неверный базовый спрайт")
	await _shot("scene_00_neutral")
	vn._advance()
	await create_timer(0.6).timeout
	check(_portrait_is(vn, "char_josie", "char_josie/laugh.png"), "@show Жози: неверная эмоция")
	await _shot("scene_03_laugh")
	var shot: Dictionary = content.parse_scene("@bg apartment_evening fireplace").nodes[0]
	check(shot.bg == "apartment_evening" and shot.get("lighting") == "fireplace", "Не разобран свет кадра")
	vn._set_bg(shot.bg, shot.lighting)
	await create_timer(0.75).timeout
	var material: ShaderMaterial = vn.figures_layer.material
	var fire: Dictionary = content.world.figure_lighting.fireplace
	check(vn.figures.char_josie.use_parent_material, "Фигура не получила освещение кадра")
	check(is_equal_approx(material.get_shader_parameter("light_strength"), fire.light_strength), "Не включён источник у камина")
	vn._set_bg("vasari")
	game.state.phase = 3
	await create_timer(0.85).timeout
	var night: Dictionary = content.figure_lighting("vasari", "night")
	check(is_equal_approx(material.get_shader_parameter("brightness"), night.brightness), "При смене времени сохранился дневной свет")
	if output != "":
		await _gallery(game, catalog)
	await root.get_node("Sound").drain()
	print("EMOTIONS CHECK: ", "OK" if failed == 0 else "FAILED", " (", failed, ")")
	quit(0 if failed == 0 else 1)


func _portrait_is(vn: Node, pid: String, suffix: String) -> bool:
	if not vn.figures.has(pid):
		return false
	var figure = vn.figures[pid]
	return is_instance_valid(figure) and figure.portrait != null and figure.portrait.resource_path.ends_with(suffix)


func _catalog() -> Dictionary:
	var catalog := {}
	# Обе схемы имён из Art.portrait. Вложенный вариант имеет приоритет.
	for file in DirAccess.get_files_at(ART_ROOT):
		if file.ends_with(".png"):
			var stem := file.get_basename()
			var split := stem.rfind("_")
			while split > 0:
				var pid := stem.left(split)
				if FileAccess.file_exists(ART_ROOT + pid + ".png"):
					if not catalog.has(pid):
						catalog[pid] = {}
					catalog[pid][stem.substr(split + 1)] = ART_ROOT + file
					break
				split = pid.rfind("_")
	for pid in DirAccess.get_directories_at(ART_ROOT):
		if pid == "ref":
			continue
		for file in DirAccess.get_files_at(ART_ROOT + pid):
			if file.ends_with(".png"):
				if not catalog.has(pid):
					catalog[pid] = {}
				catalog[pid][file.get_basename()] = ART_ROOT + pid + "/" + file
	for pid: String in catalog:
		var variants: Dictionary = catalog[pid]
		var neutral: String = variants.get("neutral", ART_ROOT + pid + ".png")
		variants.erase("neutral")
		catalog[pid] = {"neutral": neutral}
		catalog[pid].merge(variants)
	return catalog


func _check_image(art: Script, pid: String, mood: String, path: String) -> void:
	var texture: Texture2D = art.portrait(pid, mood)
	check(texture != null and texture.resource_path == path, "Art.portrait вернул неверный спрайт: " + path)
	if texture != null:
		if mood != "neutral":
			check(not art._textures.has(path), "Эмоция осталась в постоянном кэше: " + path)
		# Проверяем рисунки по одному, затем отдаём память предыдущей текстуры.
		art._textures.erase(texture.resource_path)
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	check(img != null and not img.is_empty(), "Не читается PNG: " + path)
	if img != null and not img.is_empty():
		check(img.detect_alpha() != Image.ALPHA_NONE and img.get_used_rect().has_area(), "Пустой PNG или нет прозрачности: " + path)
		check(img.get_width() >= 800 and img.get_height() >= 1200, "Слишком маленький спрайт: " + path)


func _shot(name: String) -> void:
	if output == "":
		return
	DirAccess.make_dir_recursive_absolute(output)
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(output.path_join(name + ".png"))
	check(result == OK, "Не записан скриншот: " + name)


func _gallery(game: Node, catalog: Dictionary) -> void:
	game.main.visible = false
	var panel := ColorRect.new()
	panel.color = Color("20333c")
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(panel)
	var view := root.get_visible_rect().size
	for pid: String in catalog:
		var paths: Array = catalog[pid].values()
		var moods: Array = catalog[pid].keys()
		for page in ceili(paths.size() / 4.0):
			for child in panel.get_children():
				child.queue_free()
			await process_frame
			for col in 4:
				var index := page * 4 + col
				if index >= paths.size():
					break
				var image := TextureRect.new()
				image.texture = load(paths[index])
				image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				image.position = Vector2(col * view.x / 4.0 + 10, 50)
				image.size = Vector2(view.x / 4.0 - 20, view.y - 85)
				panel.add_child(image)
				var label := Label.new()
				label.text = pid.trim_prefix("char_") + " / " + ("обычно" if index == 0 else str(moods[index]))
				label.position = Vector2(col * view.x / 4.0 + 16, 15)
				label.add_theme_font_size_override("font_size", 20)
				panel.add_child(label)
			await _shot("gallery_%s_%d" % [pid, page + 1])
	panel.queue_free()
