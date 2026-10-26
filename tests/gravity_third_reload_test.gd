extends "res://tests/gravity_third_route_test.gd"


func _run() -> void:
	progress = root.get_node("CollectionProgress")
	var path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--save="): path = argument.trim_prefix("--save=")
	_check(path.begins_with("user://gravity_third_") and path.ends_with(".cfg"), "Read only the explicitly supplied isolated first-process fixture")
	progress.save_path = path
	progress._collected.clear()
	progress.load_progress()
	_check(progress.get_count("gravity") == 6, "The separate process loads all six unique confirmed IDs")
	change_scene_to_file("res://scenes/stage_select.tscn")
	await _step(4)
	var card: Button = current_scene.get_node("Margin/Content/Stages/Stage3")
	_check(card.get_node("Content/Collection/Count").text == "6 / 10" and card.accessibility_name.contains("巻物 6 / 10"), "A new process exposes six of ten in visible and accessible stage selection")
	await _fresh(17)
	var faded := 0
	for room in stage.rooms.get_children():
		for node in room.find_children("*", "Area2D", true, false):
			if node.get_script() != null and node.get_script().resource_path == "res://scripts/scroll_collectible.gd" and progress.has_scroll("gravity",node.scroll_id):
				_check(node.modulate.a < 1 and progress.has_scroll("gravity",node.scroll_id), "Each actual native scroll is already faint in the restarted process")
				faded += 1
	_check(faded == 6, "The restarted scene has exactly six confirmed physical scroll nodes")
	await _finish()
