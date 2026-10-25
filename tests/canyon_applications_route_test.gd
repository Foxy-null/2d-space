extends "res://tests/canyon_inverted_route_test.gd"


func _run() -> void:
	_isolate_collection()
	progress = root.get_node("CollectionProgress")
	var profiles: Array = [[1.0,16],[1.0,20],[1.0,24],[0.8,16],[0.8,20],[0.8,24]]
	if OS.get_cmdline_user_args().has("--quick") or OS.get_cmdline_user_args().has("--screenshots"): profiles = [[1.0,20]]
	var selected := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--room="): selected = int(arg.trim_prefix("--room="))
		if arg.begins_with("--profile="): profiles = [profiles[int(arg.trim_prefix("--profile="))]]
	for profile in profiles:
		for index in [30,31,32]:
			if selected>0 and index+1!=selected: continue
			await _applications_course(index,profile[0],profile[1])
			if failed: return
	monitor_view = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	print("CANYON_APPLICATIONS_ROUTE_TEST_OK ",checks," checks")
	quit()


func _applications_course(index: int, strength: float, delay: int) -> void:
	monitor_view = false
	await _setup(index)
	stage.set_hints_visible(OS.get_cmdline_user_args().has("--hints"))
	await _step()
	monitor_view = true
	Input.action_press("move_right",strength)
	_check(is_equal_approx(Input.get_axis("move_left","move_right"),strength),"The live horizontal axis matches the tested strength")
	_release_inputs()
	await _application_capture("room%d_entrance" % (index+1))
	var started := Engine.get_physics_frames()
	await _applications_main(strength,delay)
	if failed: return
	_release_inputs()
	var seconds := float(Engine.get_physics_frames()-started)/60
	print("APPLICATION_",index+1," axis=",strength," delay=",delay," seconds=",seconds," next=",stage.next_bumper," respawns=",respawns)
	_check((stage.completed and respawns==0) if index==stage.rooms.get_child_count()-1 else (stage.transitioning and stage.room_index==index+1 and respawns==1),"The entire actual new route reaches its own normal exit")
	_check(seconds<30,"The actual successful retry including three-second rests stays below thirty seconds")
	_check(progress.get_count("canyon")==0,"The main route leaves both optional scrolls untouched")
	if failed: return
	if stage.completed:
		await _application_capture("room33_goal")
		if OS.get_cmdline_user_args().has("--practice"):
			await _pulse("jump")
			await _step(120)
			_check(stage.completed and respawns==0,"A real practice jump preserves visible completion and safe player bounds")


func _application_capture(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--screenshots"): return
	await process_frame
	RenderingServer.force_draw()
	var directory := "res://docs/screenshots/canyon-applications/"+("hints" if stage.hints_visible else "default")
	DirAccess.make_dir_recursive_absolute(directory)
	_check(root.get_texture().get_image().save_png(directory+"/"+label+".png")==OK,"The actual native route image is saved")


func _check(ok: bool, message: String) -> void:
	super._check(ok,message)
	if not ok and is_instance_valid(player):
		print("APPLICATION_FAIL p=",Vector2(_x(),player.position.y)," v=",player.velocity," next=",stage.next_bumper," respawns=",respawns)


func _inverted_snapshot(label: String) -> void:
	_application_snapshot(label)
