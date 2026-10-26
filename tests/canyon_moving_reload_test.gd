extends SceneTree

var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if not _check(arg in ["--screenshots", "--keep-fixture"], "Known moving-reload argument: " + arg): return
	var fixture := OS.get_environment("CANYON_MOVING_FIXTURE")
	var suffix := fixture.trim_prefix("user://stage_5_route_").trim_suffix(".cfg")
	if not _check(fixture.begins_with("user://stage_5_route_") and fixture.ends_with(".cfg") and suffix.is_valid_int() and int(suffix) > 0, "Load only the isolated PID save printed by the real route"): return
	if not _check(FileAccess.file_exists(fixture), "The prior process left a real integration save file"): return
	var progress := root.get_node("CollectionProgress")
	progress.save_path = fixture
	progress._collected.clear()
	progress.load_progress()
	if not _check(progress.TOTALS["canyon"] == 12 and progress.get_count("canyon") == 1 and progress.has_scroll("canyon", "moving_sky_12"), "A fresh process loads exactly the one physically collected twelfth ID"): return
	if not _check(change_scene_to_file("res://scenes/stage_select.tscn") == OK, "Open the native selection scene"): return
	await process_frame
	await process_frame
	var card: Button = current_scene.get_node("Margin/Content/Stages/Stage5")
	if not _check(card.get_node("Content/Collection/Count").text == "1 / 12" and card.accessibility_name.contains("巻物 1 / 12"), "The fresh selection displays and announces the actual saved count"): return
	if OS.get_cmdline_user_args().has("--screenshots"):
		await process_frame
		RenderingServer.force_draw()
		DirAccess.make_dir_recursive_absolute("res://docs/screenshots/canyon-moving")
		if not _check(root.get_texture().get_image().save_png("res://docs/screenshots/canyon-moving/stage_selection_1.png") == OK, "Capture the actual fresh-process selection"): return
	if not _check(change_scene_to_file("res://scenes/stage_5.tscn") == OK, "Load the actual native stage in the new process"): return
	await process_frame
	await process_frame
	var scroll: Area2D = current_scene.rooms.get_child(33).get_node("Scroll")
	if not _check(scroll.scroll_id == "moving_sky_12" and scroll._secured and scroll.modulate.a < 1 and scroll._follower == null, "The real room34 marker starts faint and confirmed after process restart"): return
	if not _check(progress.collect_scroll("canyon", "moving_sky_12") == OK and progress.get_count("canyon") == 1, "A duplicate never increases the saved count"): return
	progress._collected.clear()
	progress.load_progress()
	if not _check(progress.get_count("canyon") == 1 and progress.has_scroll("canyon", "moving_sky_12"), "The duplicate check also preserves the real disk record"): return
	# The eleven legacy IDs are count compatibility only; their actual routes are separate.
	for id in ["turning_sky_01","left_sky_02","deep_return_03","wide_sky_04","wind_fold_05","spring_loft_06","updraft_left_07","inverted_return_08","inverted_wind_09","boots_loft_10","wall_loft_11"]:
		if not _check(progress.collect_scroll("canyon",id)==OK,"The old saved ID merges without dropping the real moving scroll"):return
	progress._collected.clear()
	progress.load_progress()
	if not _check(progress.get_count("canyon")==12 and progress.has_scroll("canyon","moving_sky_12"),"The separate legacy compatibility fixture preserves twelve unique IDs"):return
	if not _check(change_scene_to_file("res://scenes/stage_select.tscn")==OK,"Reopen selection for the compatibility fixture"):return
	await process_frame
	await process_frame
	card=current_scene.get_node("Margin/Content/Stages/Stage5")
	if not _check(card.get_node("Content/Collection/Count").text=="12 / 12" and card.accessibility_name.contains("巻物 12 / 12"),"The compatibility fixture displays and announces the complete native total"):return
	if not OS.get_cmdline_user_args().has("--keep-fixture"):
		if not _check(DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture)) == OK, "Remove only this isolated integration save"): return
	print("CANYON_MOVING_RELOAD_TEST_OK ", checks, " checks")
	quit()


func _check(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		push_error("CANYON_MOVING_RELOAD: " + message)
		quit(1)
	return condition
