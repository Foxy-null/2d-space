extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var fixture := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--fixture=user://tower_route_"): fixture=argument.trim_prefix("--fixture=")
	if not _check(not fixture.is_empty(),"Pass the isolated actual tower integration save"): return
	var progress := root.get_node("CollectionProgress")
	progress.save_path=fixture
	progress._collected.clear()
	progress.load_progress()
	if not _check(progress.get_count("tower")==1 and progress.has_scroll("tower","wind_glide_06"),"A separate process loads the actual wind-branch ID"): return
	change_scene_to_file("res://scenes/stage_select.tscn")
	await process_frame
	await process_frame
	var card: Button=current_scene.get_node("Margin/Content/Stages/Stage2")
	if not _check(card.get_node("Content/Collection/Count").text=="1 / 8" and card.accessibility_name.contains("巻物 1 / 8"),"Fresh selection displays and announces one out of eight"): return
	change_scene_to_file("res://scenes/stage_2.tscn")
	await process_frame
	await process_frame
	if not _check(current_scene.get_node("ScrollBranch/ParachuteScroll").modulate.a<1,"The actual new scroll remains faint after restart"): return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture))
	print("TOWER_PARACHUTE_RELOAD_TEST_OK (3 checks)")
	quit()

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
