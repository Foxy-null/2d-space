extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var fixture := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--fixture=user://corridor_fifth_scroll_"): fixture = argument.trim_prefix("--fixture=")
	assert(not fixture.is_empty(), "Pass the isolated wide-room integration save")
	var progress := root.get_node("CollectionProgress")
	progress.save_path = fixture
	progress._collected.clear()
	progress.load_progress()
	assert(progress.get_count("companion") == 2 and progress.has_scroll("companion", "refill_upper_08") and progress.has_scroll("companion", "inverted_left_09"), "A separate process loads both actual new scroll IDs")
	change_scene_to_file("res://scenes/stage_select.tscn")
	await process_frame
	await process_frame
	var card: Button = current_scene.get_node("Margin/Content/Stages/Stage4")
	assert(card.get_node("Content/Collection/Count").text == "2 / 9" and card.accessibility_name.contains("巻物 2 / 9"), "A fresh selection displays and announces two out of nine")
	change_scene_to_file("res://scenes/stage_4.tscn")
	await process_frame
	await process_frame
	for section in [24, 27]:
		assert(current_scene.rooms.get_child(section).get_node("Scroll").modulate.a < 1, "The native new scroll remains faint after restart")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture))
	print("CORRIDOR_FIFTH_RELOAD_TEST_OK (5 checks)")
	quit()
