extends SceneTree
# Компилирует все скрипты проекта и печатает ошибки. Запуск: Godot --headless --path fleur --script res://tools/check_all.gd
func _initialize() -> void:
	var bad := 0
	for path in _walk("res://"):
		var s = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if s == null or not s.can_instantiate():
			print("BROKEN: ", path)
			bad += 1
	_mood_report()
	print("CHECK DONE, broken: ", bad)
	quit(bad)

func _walk(dir: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	for f in d.get_files():
		if f.ends_with(".gd") and not f.begins_with("check_all"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		if not sub.begins_with("."):
			out.append_array(_walk(dir.path_join(sub)))
	return out


# Какие эмоции упоминаются в сценах и для каких ещё нет отдельного спрайта.
func _mood_report() -> void:
	var content = root.get_node_or_null("Content")
	if content == null:
		return
	var used := {}
	for sid in content.scenes:
		for n in content.scenes[sid].get("nodes", []):
			var pid := ""
			var mood := ""
			if n.has("show") and n.has("mood"):
				pid = n["show"]; mood = n["mood"]
			elif n.has("mood"):
				pid = n["mood"]; mood = n.get("as", "")
			elif n.has("s") and n.has("as"):
				pid = n["s"]; mood = n["as"]
			if pid != "" and mood != "":
				var file: String = str(content.world.get("mood_aliases", {}).get(mood.to_lower(), mood.to_lower()))
				if file == "neutral":
					continue
				used[pid + "/" + file] = mood
	var missing := []
	for key in used:
		var parts: PackedStringArray = key.split("/")
		var a := "res://assets/art/characters/%s/%s.png" % [parts[0], parts[1]]
		var b := "res://assets/art/characters/%s_%s.png" % [parts[0], parts[1]]
		if not ResourceLoader.exists(a) and not ResourceLoader.exists(b):
			missing.append("  characters/%s.png  (в сценах: «%s»)" % [key, used[key]])
	missing.sort()
	if missing.size() > 0:
		print("Спрайтов эмоций пока нет (показывается обычный спрайт):")
		for m in missing:
			print(m)
