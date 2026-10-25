extends "res://tests/gravity_parachute_route_test.gd"


func _run() -> void:
	progress=root.get_node("CollectionProgress")
	var path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--save="):path=arg.trim_prefix("--save=")
	_check(path.begins_with("user://gravity_para_scroll_") and path.ends_with(".cfg"),"Read only a supplied isolated first-process fixture")
	progress.save_path=path
	progress._collected.clear()
	progress.load_progress()
	_check(progress.get_count("gravity")==2 and progress.has_scroll("gravity","parachute_loft_07") and progress.has_scroll("gravity","folded_current_08"),"A separate process loads both actually collected new IDs")
	change_scene_to_file("res://scenes/stage_select.tscn")
	await _step(4)
	var card: Button=current_scene.get_node("Margin/Content/Stages/Stage3")
	_check(card.get_node("Content/Collection/Count").text=="2 / 8" and card.accessibility_name.contains("巻物 2 / 8"),"A separate process exposes two of eight visually and accessibly")
	for index in [21,23]:
		await _fresh_para(index)
		_check(stage.rooms.get_child(index).get_node("Scroll")._secured,"Both native nodes are secured after process restart")
	# The retained old branches have their own real-input suites; combine their IDs only as a count fixture.
	for id in ["wall_loft_01","inverted_return_02","upper_current_03","left_depth_04","wind_return_05","upper_return_06"]:
		_check(progress.collect_scroll("gravity",id)==OK,"Old-ID count fixture combines with the actually reloaded new IDs")
	monitor_view=false
	change_scene_to_file("res://scenes/stage_select.tscn")
	await _step(4)
	card=current_scene.get_node("Margin/Content/Stages/Stage3")
	_check(card.get_node("Content/Collection/Count").text=="8 / 8" and card.accessibility_name.contains("巻物 8 / 8"),"The combined eight-ID fixture uses the real total visually and accessibly")
	current_scene.queue_free()
	await _step(5)
	DirAccess.remove_absolute(path)
	print("GRAVITY_PARACHUTE_RELOAD_TEST_OK %d checks"%checks)
	quit()
