extends SceneTree

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var fixture := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--fixture=user://corridor_more_"):fixture=argument.trim_prefix("--fixture=")
	assert(not fixture.is_empty(),"Pass the previous integration process's isolated save fixture")
	var progress:=root.get_node("CollectionProgress")
	progress.save_path=fixture
	progress._collected.clear()
	progress.load_progress()
	assert(progress.get_count("companion")==3,"A fresh Godot process loads all three saved companion scrolls")
	change_scene_to_file("res://scenes/stage_select.tscn")
	await process_frame
	await process_frame
	var card:=current_scene.get_node("Margin/Content/Stages/Stage4")
	assert(card.get_node("Content/Collection/Count").text=="3 / 3" and card.accessibility_name.contains("巻物 3 / 3"),"The fresh selection displays and announces three out of three")
	change_scene_to_file("res://scenes/stage_4.tscn")
	await process_frame
	await process_frame
	for section in [6,9,12]:
		assert(current_scene.rooms.get_child(section).get_node("Scroll").modulate.a<1,"All actual collection nodes remain faint after restart")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture))
	print("CORRIDOR_MORE_RELOAD_TEST_OK (5 checks)")
	quit()
