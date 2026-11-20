extends Node
## Общий звук для стола, новеллы и активностей. Переход через экран не обрывает ту же запись.

const AUDIO_ROOT := "res://assets/audio/"
const VOICES := 10
var ambience := Bed.new()
var music := Bed.new()
var effects: Array[AudioStreamPlayer] = []
var next_voice := 0
var streams := {}
var last_cue := {}
var variation := RandomNumberGenerator.new()
var closing := false


class Bed extends Node:
	var players: Array[AudioStreamPlayer] = []
	var selected: AudioStreamPlayer
	var id := ""
	var fade: Tween
	var gain: float
	var duration: float
	var remember_position: bool
	var bookmarks := {}

	func setup(bus: StringName, db: float, seconds: float, remember: bool) -> void:
		gain = db_to_linear(db)
		duration = seconds
		remember_position = remember
		for i in 2:
			var player := AudioStreamPlayer.new()
			player.bus = bus
			add_child(player)
			players.append(player)

	func change(next_id: String, stream: AudioStream) -> void:
		if id == next_id:
			return
		if fade:
			fade.kill()
		if remember_position and selected:
			if selected.playing:
				bookmarks[id] = selected.get_playback_position()
			else:
				bookmarks.erase(id)
		id = next_id
		selected = null
		if stream:
			for player in players:
				if player.stream == stream and player.playing:
					selected = player
					break
			if not selected:
				selected = players[0]
				if selected.playing and (not players[1].playing or players[1].volume_linear < selected.volume_linear):
					selected = players[1]
				selected.stop()
				selected.stream = stream
				selected.volume_linear = 0.0
				selected.play(float(bookmarks.get(id, 0.0)))
		fade = create_tween().set_parallel()
		for player in players:
			if player == selected:
				fade.tween_property(player, "volume_linear", gain, duration)
			elif player.playing:
				var outgoing := fade.tween_property(player, "volume_linear", 0.0, duration)
				outgoing.finished.connect(player.stop)
		# Также возможна тишина после естественного окончания композиции.
		if not selected and not players[0].playing and not players[1].playing:
			fade.kill()


func _ready() -> void:
	add_child(ambience)
	add_child(music)
	ambience.setup(&"Ambience", -3.5, 0.9, false)
	music.setup(&"Music", -12.0, 1.6, true)
	# Записи короткие (1,5–3 минуты), а сцена идёт дольше: после конца — пауза и повтор.
	for player in music.players:
		player.finished.connect(_music_finished.bind(player))
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = &"Effects"
		add_child(player)
		effects.append(player)


## Трек доиграл: немного тишины, затем он же снова, с мягким нарастанием.
## Если за паузу сцена сменила музыку или выключила её, повтора не будет.
## Пауза пропорциональна длине: у тридцатисекундной петли — пара секунд, у трёхминутной — до 16.
const MUSIC_GAP := Vector2(0.08, 0.12)
const MUSIC_GAP_MAX := 16.0
const MUSIC_RETURN := 3.0
## Короткие петли веб-страниц без затухания в конце: повторяются без шва и без паузы.
const SEAMLESS := ["rotating_realm", "lumidouces_repose"]

func _music_finished(player: AudioStreamPlayer) -> void:
	if closing or player != music.selected:
		return
	var id := music.id
	var length := player.stream.get_length() if player.stream else 120.0
	var gap := minf(length * variation.randf_range(MUSIC_GAP.x, MUSIC_GAP.y), MUSIC_GAP_MAX)
	await get_tree().create_timer(maxf(gap, 2.0)).timeout
	if closing or music.id != id or music.selected != player or player.playing:
		return
	music.bookmarks.erase(id)
	player.volume_linear = 0.0
	player.play()
	if music.fade:
		music.fade.kill()
	music.fade = create_tween()
	music.fade.tween_property(player, "volume_linear", music.gain, MUSIC_RETURN)


func stop_all() -> void:
	for bed in [music, ambience]:
		if bed.fade:
			bed.fade.kill()
		bed.id = ""
		bed.selected = null
		bed.bookmarks.clear()
	for player in music.players + ambience.players + effects:
		player.stop()
		player.stream = null
	streams.clear()


func _exit_tree() -> void:
	stop_all()


func drain() -> void:
	closing = true
	stop_all()
	# Дать аудиопотоку вернуть последние буферы до завершения движка.
	var until := Time.get_ticks_msec() + 150
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


func _stream(folder: String, id: String, extension: String) -> AudioStream:
	if id.is_empty():
		return null
	var path := AUDIO_ROOT + folder + "/" + id + extension
	if not streams.has(path):
		var stream: AudioStream = load(path)
		if stream is AudioStreamOggVorbis:
			stream.loop = folder == "ambience" or (folder == "music" and id in SEAMLESS)
		streams[path] = stream
	return streams[path]


func environment(section: String, id: String, phase: String, light := "", score_override := "") -> void:
	if closing:
		return
	var data := Content.soundscapes
	if light in ["street_evening", "street_night"]:
		phase = light.trim_prefix("street_")
	var setting = data.get(section, {}).get(id, "apartment_day")
	if setting is Dictionary:
		setting = setting.get(phase, setting.get("day", "apartment_day"))
	var bed_id := str(data.get("lighting_overrides", {}).get(light, setting))
	ambience.change(bed_id, _stream("ambience", bed_id, ".ogg"))
	var bg := id
	if section == "locations":
		bg = str(Content.def(id).get("bg", "apartment"))
	set_background_music(bg, score_override)


func set_background_music(bg: String, override_id: String) -> void:
	if not closing:
		set_music(Content.soundscapes.get("music", {}).get(bg, "") if override_id.is_empty() else override_id)


func set_music(id: String) -> void:
	if id == "off":
		id = ""
	music.change(id, _stream("music", id, ".ogg"))


func play(id: String, offset_db := 0.0) -> void:
	if closing:
		return
	# Быстрое листание и серия попаданий не должны складываться в треск.
	var now := Time.get_ticks_msec()
	if now - int(last_cue.get(id, -1000)) < 100:
		return
	last_cue[id] = now
	var sample := _stream("sfx", id, ".wav")
	if not sample:
		return
	var voice := effects[next_voice]
	next_voice = (next_voice + 1) % VOICES
	voice.stop()
	voice.stream = sample
	voice.volume_db = (-7.0 if id.begins_with("ui_") else -4.5) + offset_db
	voice.pitch_scale = variation.randf_range(0.96, 1.04) if id not in ["furina", "clue", "danger"] else 1.0
	voice.play()
