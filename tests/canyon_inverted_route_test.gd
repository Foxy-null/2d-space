extends "res://tests/canyon_entry_route_test.gd"


func _run() -> void:
	_isolate_collection()
	progress = root.get_node("CollectionProgress")
	var selected := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--room="): selected = int(arg.trim_prefix("--room="))
	var profiles: Array = [[1.0,16],[1.0,20],[1.0,24],[0.8,16],[0.8,20],[0.8,24]]
	var delay := 20
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--delay="): delay = int(arg.trim_prefix("--delay="))
	if OS.get_cmdline_user_args().has("--quick") or OS.get_cmdline_user_args().has("--screenshots"): profiles = [[1.0,20]]
	if OS.get_cmdline_user_args().has("--weak"): profiles = [[0.8,delay]]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile="): profiles = [profiles[int(arg.trim_prefix("--profile="))]]
	for profile in profiles:
		for index in [27,28,29]:
			if selected > 0 and selected != index+1: continue
			await _inverted_course(index,profile[0],profile[1])
			if failed: return
	monitor_view = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	print("CANYON_INVERTED_ROUTE_TEST_OK (",checks," checks)")
	quit()


func _inverted_course(index: int, strength: float, delay: int) -> void:
	monitor_view = false
	await _setup(index)
	stage.set_hints_visible(OS.get_cmdline_user_args().has("--hints"))
	if OS.get_cmdline_user_args().has("--screenshots"): await _step()
	monitor_view = true
	if index == 29:
		var shape: CollisionShape2D = stage.rooms.get_child(index).get_node("Scroll/CollisionShape2D")
		var bounds: Rect2 = shape.get_global_transform_with_canvas() * shape.shape.get_rect()
		_check(root.get_visible_rect().encloses(bounds),"The actual optional scroll is wholly visible from the final entrance")
		for path in ["HUD/Info","HUD/Hint","HUD/PauseButton"]:
			var panel: Control = stage.get_node(path)
			_check(not panel.visible or not panel.get_global_rect().intersects(bounds),"The entrance scroll remains outside the visible "+panel.name)
	Input.action_press("move_right",strength)
	_check(is_equal_approx(Input.get_axis("move_left","move_right"),strength),"The real horizontal axis matches the reported strength")
	_release_inputs()
	var started := Engine.get_physics_frames()
	_inverted_snapshot("room%d_entrance" % (index+1))
	await _inverted_main(strength,delay)
	if failed: return
	_release_inputs()
	var seconds := float(Engine.get_physics_frames()-started)/60
	print("INV_COMPLETE room=",index+1," strength=",strength," delay=",delay," seconds=",seconds," respawns=",respawns)
	_check((stage.completed and respawns==0) if index==29 else (stage.transitioning and stage.room_index==index+1 and respawns==1),"The inverted native route reaches its actual normal exit")
	_check(seconds<30,"The actual retry including three-second rests stays below thirty seconds")
	_check(progress.get_count("canyon")==0,"The actual main route leaves the optional scrolls untouched")
	if index==29: _inverted_snapshot("room30_goal")
	if index==29 and OS.get_cmdline_user_args().has("--practice"):
		await _pulse("jump")
		await _step(120)
		_check(stage.completed and respawns==0,"A real jump after completion preserves safe playable space and visible feedback")


func _capture(_label: String) -> void:
	pass # This fixture captures after setting its own hint state.
