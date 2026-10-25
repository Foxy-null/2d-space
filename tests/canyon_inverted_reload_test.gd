extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var fixture := OS.get_environment("CANYON_INVERTED_FIXTURE")
	assert(fixture.begins_with("user://stage_5_route_"),"Use the isolated real integration save")
	var progress := root.get_node("CollectionProgress")
	progress.save_path = fixture
	progress._collected.clear()
	progress.load_progress()
	assert(progress.get_count("canyon")==2 and progress.has_scroll("canyon","inverted_return_08") and progress.has_scroll("canyon","inverted_wind_09"),"A separate process loads both actual native IDs")
	change_scene_to_file.call_deferred("res://scenes/stage_select.tscn")
	_verify.call_deferred()


func _verify() -> void:
	await process_frame
	await process_frame
	var card: Button = current_scene.get_node("Margin/Content/Stages/Stage5")
	assert(card.get_node("Content/Collection/Count").text=="2 / 9" and card.accessibility_name.contains("巻物 2 / 9"),"A fresh selection displays and announces two out of nine")
	var screenshots := OS.get_cmdline_user_args().has("--screenshots")
	if screenshots:
		RenderingServer.force_draw()
		assert(root.get_texture().get_image().save_png("res://docs/screenshots/canyon-inverted/stage_selection_2.png")==OK,"Capture the real saved selection count")
	change_scene_to_file("res://scenes/stage_5.tscn")
	await process_frame
	await process_frame
	for index in [27,29]: assert(current_scene.rooms.get_child(index).get_node("Scroll").modulate.a<1,"A native confirmed marker remains faint after restart")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(root.get_node("CollectionProgress").save_path))
	print("CANYON_INVERTED_RELOAD_TEST_OK (",6 if screenshots else 5," checks)")
	quit()
