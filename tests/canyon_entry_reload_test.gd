extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var fixture := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--fixture=user://canyon_entry_scroll_"): fixture = argument.trim_prefix("--fixture=")
	assert(not fixture.is_empty(), "Pass the PID-isolated native branch save")
	var progress := root.get_node("CollectionProgress")
	progress.save_path = fixture
	progress._collected.clear()
	progress.load_progress()
	assert(progress.get_count("canyon") == 2 and progress.has_scroll("canyon", "spring_loft_06") and progress.has_scroll("canyon", "updraft_left_07"), "A separate process loads both actual native new scroll IDs")
	change_scene_to_file("res://scenes/stage_select.tscn")
	await process_frame
	await process_frame
	var card: Button = current_scene.get_node("Margin/Content/Stages/Stage5")
	assert(card.get_node("Content/Collection/Count").text == "2 / 12" and card.accessibility_name.contains("巻物 2 / 12"), "A fresh selection displays and announces two out of twelve")
	change_scene_to_file("res://scenes/stage_5.tscn")
	await process_frame
	await process_frame
	for index in [24, 26]:
		assert(current_scene.rooms.get_child(index).get_node("Scroll").modulate.a < 1, "The native scroll remains faint after restarting the process")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture))
	print("CANYON_ENTRY_RELOAD_TEST_OK (5 checks)")
	quit()
