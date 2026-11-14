extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.add_child(load("res://main.tscn").instantiate())
	await create_timer(2.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Users/kaiza/Documents/Game/output/menu_min.png")
	print("MENU SIZE ", root.size, " canvas ", root.get_visible_rect().size)
	var game = root.get_node("Game")
	var rules = root.get_node("Rules")
	game.settings["autosave"] = false
	game.state = rules.new_state()
	game.state["queue"].clear()
	game.state["notices"].clear()
	game.to_table()
	await create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Users/kaiza/Documents/Game/output/table_scroll.png")
	game.main.screen.spread.action_scroll.scroll_vertical = 10000
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Users/kaiza/Documents/Game/output/table_scroll_bottom.png")
	print("SCROLL ", game.main.screen.spread.action_scroll.scroll_vertical)
	quit()
