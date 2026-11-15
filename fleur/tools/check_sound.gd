extends SceneTree
## Проверка звуковых ресурсов, ссылок в сценарии и переходов между местами.

var failed := 0
var checked := {}


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, message: String) -> void:
	if not ok:
		failed += 1
		push_error(message)


func resource(folder: String, id: String, extension: String) -> void:
	var path := "res://assets/audio/%s/%s.%s" % [folder, id, extension]
	if checked.has(path):
		return
	checked[path] = true
	var stream := load(path) as AudioStream
	check(stream != null and stream.get_length() > 0.0, "Пустой звук: " + path)


func run() -> void:
	var content = root.get_node("Content")
	var sound = root.get_node("Sound")
	var game = root.get_node("Game")
	var data: Dictionary = content.soundscapes
	for id in content.world.backgrounds:
		check(data.backgrounds.has(id), "Нет атмосферы для фона " + id)
	for id in content.cards:
		if content.cards[id].get("type") == "location":
			check(data.locations.has(id), "Нет атмосферы для локации " + id)
	for section in ["backgrounds", "locations", "lighting_overrides"]:
		for setting in data[section].values():
			for id in (setting.values() if setting is Dictionary else [setting]):
				resource("ambience", id, "ogg")
	for id in data.music.values():
		resource("music", id, "ogg")
	for scene in content.scenes.values():
		if scene.get("music", "off") != "off":
			resource("music", scene.music, "ogg")
		for node in scene.nodes:
			if node.has("sfx"):
				resource("sfx", node.sfx, "wav")
			if node.has("score") and node.score not in ["off", "auto"]:
				resource("music", node.score, "ogg")
	for id in ["ui_map", "ui_paper", "ui_card", "ui_seal", "ui_folder", "ui_page", "ui_dial", "ui_drag", "clue", "danger", "blades", "scabbard"]:
		resource("sfx", id, "wav")
	for id in ["boat_spool", "boat_hull", "boat_splash", "boat_line_break"]:
		resource("sfx", id, "wav")

	sound.environment("locations", "loc_lutes", "day")
	var cafe: AudioStreamPlayer = sound.ambience.selected
	var score: AudioStreamPlayer = sound.music.selected
	check(cafe.playing and cafe.stream.loop, "Фон кафе не зациклен")
	check(score.playing and not score.stream.loop, "Музыка должна сыграть до конца")
	sound.environment("backgrounds", "lutes", "day")
	check(cafe == sound.ambience.selected and score == sound.music.selected, "Переход со стола в кафе прервал запись")
	sound.environment("backgrounds", "vasari", "night")
	sound.environment("backgrounds", "lutes", "evening")
	await create_timer(1.9).timeout
	check(cafe.playing and is_equal_approx(cafe.volume_linear, sound.ambience.gain), "Повторный вход в кафе потерял фон")
	for player in sound.ambience.players:
		if player != cafe:
			check(not player.playing, "Старый фон продолжает звучать")
	sound.environment("backgrounds", "apartment_evening", "evening", "fireplace", "off")
	await create_timer(1.9).timeout
	check(sound.ambience.id == "hearth" and sound.ambience.selected.playing, "Не слышен камин")
	for player in sound.music.players:
		check(not player.playing, "Музыка не затихла")
	await check_score_changes(content, game, sound)
	sound.play("ui_seal")
	check(sound.effects.any(func(player): return player.playing and player.bus == &"Effects"), "Сургуч не дошёл до шины эффектов")
	game.settings.effects_volume = 0.0
	game.apply_settings()
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Effects")), "Ноль на регуляторе не выключил эффекты")
	await sound.drain()
	print("SOUND CHECK: ", checked.size(), " ресурсов, ошибок: ", failed)
	quit(1 if failed else 0)


func check_score_changes(content: Node, game: Node, sound: Node) -> void:
	game.state = root.get_node("Rules").new_state()
	game.settings.text_speed = 0
	var vn = load("res://scenes/vn/vn_screen.gd").new()
	var script := "@music le_spectacle\n@bg lutes\nN: 1\n@score off\n@bg vasari\nN: 2\n@score anns_anapausis\nN: 3\n@score auto\nN: 4"
	vn.setup(content.parse_scene(script), {})
	root.add_child(vn)
	await process_frame
	await process_frame
	check(sound.music.id == "le_spectacle", "Не звучит вступительная тема сцены")
	vn._advance()
	check(sound.music.id == "" and sound.ambience.selected != null, "При смене фона потерялась музыкальная пауза")
	var bed: AudioStreamPlayer = sound.ambience.selected
	vn._advance()
	check(sound.music.id == "anns_anapausis", "Новая тема не вступила на реплике")
	vn._advance()
	check(sound.music.id == content.soundscapes.music.vasari and sound.ambience.selected == bed, "Не вернулась музыка места")
	vn.queue_free()
	await process_frame
