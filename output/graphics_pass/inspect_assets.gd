extends SceneTree
## Одноразовый просмотр материалов в настоящем экране стола, без сохранения партии.
var game
var rules
var main
var out_dir := "C:/Users/kaiza/Documents/Game/output/graphics_pass"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	game = root.get_node("Game")
	rules = root.get_node("Rules")
	game.settings["autosave"] = false
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.5).timeout
	game.state = rules.new_state()
	for id in ["it_crate", "it_nectar_bottle", "it_coat"]:
		rules.add_card(game.state, id, {}, rules.new_api())
	game.state["queue"] = []
	game.state["notices"] = []
	game.state["layout"] = {
		"it_crate": [828, 320, -0.045],
		"it_nectar_bottle": [510, 354, -0.025],
		"it_coat": [1028, 315, 0.045],
		"it_hairpin": [1010, 753, -0.04],
		"it_rapier": [588, 736, -0.015],
	}
	game.to_table()
	await create_timer(2.0).timeout
	await _shot("desk_day")
	game.state["phase"] = 3
	main.screen._apply_light(true)
	main.screen.dial.refresh()
	await create_timer(1.0).timeout
	await _shot("desk_night")
	game.state["phase"] = 0
	main.screen._apply_light(true)
	main.screen.dial.refresh()
	await create_timer(1.0).timeout
	var dialogs = load("res://ui/dialogs.gd")
	dialogs.pause()
	await create_timer(0.3).timeout
	await _shot("stationery_pause")
	print("GRAPHICS REVIEW OK")
	quit()

func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(out_dir.path_join(label + ".png"))
	if result != OK:
		push_error("Screenshot failed: " + label)
		quit(1)
