extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var fixture := OS.get_environment("CANYON_APPLICATIONS_FIXTURE")
	assert(fixture.begins_with("user://stage_5_route_"),"Use the isolated real integration save")
	var progress := root.get_node("CollectionProgress")
	progress.save_path = fixture
	progress._collected.clear()
	progress.load_progress()
	assert(progress.get_count("canyon")==2 and progress.has_scroll("canyon","boots_loft_10") and progress.has_scroll("canyon","wall_loft_11"),"A separate process loads both actual native IDs")
	change_scene_to_file.call_deferred("res://scenes/stage_select.tscn")
	_verify.call_deferred()


func _verify() -> void:
	await process_frame
	await process_frame
	var card: Button = current_scene.get_node("Margin/Content/Stages/Stage5")
	assert(card.get_node("Content/Collection/Count").text=="2 / 11" and card.accessibility_name.contains("巻物 2 / 11"),"A fresh selection displays and announces two out of eleven")
	var screenshots := OS.get_cmdline_user_args().has("--screenshots")
	if screenshots:
		RenderingServer.force_draw()
		assert(root.get_texture().get_image().save_png("res://docs/screenshots/canyon-applications/stage_selection_2.png")==OK,"Capture the real saved selection count")
	change_scene_to_file("res://scenes/stage_5.tscn")
	await process_frame
	await process_frame
	for index in [30,32]: assert(current_scene.rooms.get_child(index).get_node("Scroll").modulate.a<1,"A native confirmed marker remains faint after restart")
	var progress:=root.get_node("CollectionProgress")
	# Count-only legacy-ID compatibility; the nine old routes are exercised separately.
	for id in ["turning_sky_01","left_sky_02","deep_return_03","wide_sky_04","wind_fold_05","spring_loft_06","updraft_left_07","inverted_return_08","inverted_wind_09"]:
		assert(progress.collect_scroll("canyon",id)==OK,"A legacy fixture ID merges without dropping the real new collection")
	progress._collected.clear()
	progress.load_progress()
	assert(progress.get_count("canyon")==11 and progress.has_scroll("canyon","boots_loft_10") and progress.has_scroll("canyon","wall_loft_11"),"The compatibility fixture reloads all eleven unique IDs")
	assert(progress.collect_scroll("canyon","boots_loft_10")==OK and progress.get_count("canyon")==11,"A duplicate ID never increases the saved total")
	change_scene_to_file("res://scenes/stage_select.tscn")
	await process_frame
	await process_frame
	card=current_scene.get_node("Margin/Content/Stages/Stage5")
	assert(card.get_node("Content/Collection/Count").text=="11 / 11" and card.accessibility_name.contains("巻物 11 / 11"),"The compatibility fixture displays and announces the complete total")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(root.get_node("CollectionProgress").save_path))
	print("CANYON_APPLICATIONS_RELOAD_TEST_OK (",18 if screenshots else 17," checks)")
	quit()
