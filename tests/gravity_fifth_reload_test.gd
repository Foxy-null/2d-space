extends SceneTree

var checks := 0
var failed := false


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error(message)
		quit(1)


func _run() -> void:
	var progress := root.get_node("CollectionProgress")
	var path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--save="): path = arg.trim_prefix("--save=")
	var valid := path.begins_with("user://gravity_fifth_scroll_") and path.ends_with(".cfg") and FileAccess.file_exists(path)
	_check(valid, "Use the genuinely saved, PID-isolated branch fixture")
	if not valid: return
	progress.save_path = path
	progress._collected.clear()
	progress.load_progress()
	for id in ["wind_wall_loft_09","inverted_observatory_10"]:
		_check(progress.has_scroll("gravity",id),"The separate process reloads each actually collected new native ID")
	_check(progress.get_count("gravity")==2 and progress.TOTALS["gravity"]==10,"The two real pickups retain the current ten-scroll denominator")
	change_scene_to_file("res://scenes/stage_select.tscn")
	for frame in 4: await physics_frame
	_check_selection("2 / 10")
	if OS.get_cmdline_user_args().has("--screenshots"):
		await process_frame
		RenderingServer.force_draw()
		_check(root.get_texture().get_image().save_png("res://docs/screenshots/gravity-fifth/selection.png")==OK,"Save native selection with the two genuinely reloaded pickups")
	change_scene_to_file("res://scenes/stage_3.tscn")
	for frame in 4: await physics_frame
	for index in [27,29]:
		var scroll: Area2D = current_scene.get_node("Rooms").get_child(index).get_node("Scroll")
		_check(scroll._secured and scroll.modulate.a<1,"The separate process shows the actual confirmed native node faintly")
	# Count-only compatibility fixture; actual old pickups are exercised by their retained branch suites.
	for id in ["wall_loft_01","inverted_return_02","upper_current_03","left_depth_04","wind_return_05","upper_return_06","parachute_loft_07","folded_current_08"]:
		_check(progress.collect_scroll("gravity",id)==OK,"The eight retained IDs combine with the two actual new pickups")
	progress._collected.clear()
	progress.load_progress()
	_check(progress.get_count("gravity")==10,"The ten-ID count fixture survives a real file reload")
	change_scene_to_file("res://scenes/stage_select.tscn")
	for frame in 4: await physics_frame
	_check_selection("10 / 10")
	DirAccess.remove_absolute(path)
	current_scene.queue_free()
	for frame in 4: await physics_frame
	print("GRAVITY_FIFTH_RELOAD_TEST_%s %d checks" % ["FAILED" if failed else "OK",checks])
	quit(1 if failed else 0)


func _check_selection(expected: String) -> void:
	var card: Button = current_scene.get_node("Margin/Content/Stages/Stage3")
	_check(card.get_node("Content/Collection/Count").text==expected and card.accessibility_name.contains("巻物 "+expected) and not card.disabled,"Visible and accessible selection uses the same retained total")
