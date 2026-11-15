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
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = &"Effects"
		add_child(player)
		effects.append(player)


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
			stream.loop = folder == "ambience"
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
