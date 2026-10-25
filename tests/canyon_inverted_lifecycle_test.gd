extends "res://tests/canyon_inverted_scroll_test.gd"


func _run() -> void:
	_isolate_collection()
	progress = root.get_node("CollectionProgress")
	var strength := 0.8 if OS.get_cmdline_user_args().has("--weak") else 1.0
	for index in [27,29]:
		var only := 0
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--room="): only=int(arg.trim_prefix("--room="))
		if only>0 and only!=index+1: continue
		await _inverted_lifecycle(index,strength)
		if failed: return
	monitor_view = false
	_release_inputs()
	if OS.get_cmdline_user_args().has("--keep-fixture"): print("CANYON_INVERTED_SAVED_PATH ",progress.save_path)
	else: DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	print("CANYON_INVERTED_LIFECYCLE_TEST_OK (",checks," checks)")
	quit()


func _inverted_lifecycle(index: int, strength: float) -> void:
	var id := "inverted_return_08" if index==27 else "inverted_wind_09"
	var count: int = progress.get_count("canyon")
	for interruption in ["retry","death","leave"]:
		await _inverted_fresh(index)
		await _inverted_pickup(strength,interruption=="death")
		_check(_scroll()._follower==player and not _scroll()._secured and respawns==0,"The interruption fixture really reaches a native pending pickup")
		if failed: return
		monitor_view = false
		if interruption=="retry":
			await _pulse("reset")
			await _step(6)
		elif interruption=="death":
			await _inverted_die()
		else:
			stage.get_node("PauseMenu").return_to_select()
			await _step(4)
		if interruption!="leave": _check(_scroll()._follower==null and _scroll().global_position==_scroll()._origin,"The actual interruption restores the pending scroll")
		_check(progress.get_count("canyon")==count and not progress.has_scroll("canyon",id),"A pending pickup never changes the saved count")
		if failed: return
	await _inverted_trip(index,strength)
	if failed: return
	_check(progress.get_count("canyon")==count+1 and progress.has_scroll("canyon",id),"The real branch and main exit persist one confirmed ID")
	await _inverted_fresh(index)
	_check(_scroll()._secured and _scroll().modulate.a<1,"A fresh native room shows a faint confirmed scroll")
	await _pulse("reset")
	await _step(6)
	_check(progress.get_count("canyon")==count+1,"R preserves the confirmed collection")
	monitor_view = false
	await _inverted_die()
	_check(progress.get_count("canyon")==count+1 and player.gravity_direction==1 and player.is_dash_ready(),"Actual death preserves the collection and resets normal gravity and Dash")
	await _inverted_fresh(index)
	await _inverted_pickup(strength)
	_check(_scroll()._secured and _scroll()._follower==null and _scroll().overlaps_body(player),"Actual controls recontact the faint native marker without a new follower")
	_check(progress.get_count("canyon")==count+1,"Revisiting never duplicates the saved ID")
	monitor_view = false
	stage.get_node("PauseMenu").return_to_select()
	await _step(4)
	var card: Button = current_scene.get_node("Margin/Content/Stages/Stage5")
	var expected := "%d / 11" % (count+1)
	_check(card.get_node("Content/Collection/Count").text==expected and card.accessibility_name.contains("巻物 "+expected),"Selection displays and announces the actual saved count out of eleven")
	progress._collected.clear()
	progress.load_progress()
	_check(progress.get_count("canyon")==count+1 and progress.has_scroll("canyon",id),"A real reload retains the unfinished stage collection")
	print("INVERTED_LIFECYCLE room=",index+1," strength=",strength," count=",count+1)


func _inverted_fresh(index: int) -> void:
	monitor_view = false
	await _setup(index)
	stage.set_hints_visible(true)
	monitor_view = true


func _inverted_die() -> void:
	var before := respawns
	_release_inputs()
	Input.action_press("move_left")
	Input.action_press("move_down")
	if player.is_dash_ready(): await _pulse("dash")
	for frame in 600:
		if respawns>before: break
		_release_inputs()
		Input.action_press("move_left")
		if player.is_on_floor() and _scroll()._follower==player: Input.action_press("jump")
		await _step()
	_release_inputs()
	await _step(6)
	_check(respawns==before+1,"Normal movement reaches one actual death without changing position or velocity")
