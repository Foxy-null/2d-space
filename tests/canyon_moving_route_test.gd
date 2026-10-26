extends "res://tests/canyon_applications_route_test.gd"

func _run() -> void:
	_isolate_collection()
	progress=root.get_node("CollectionProgress")
	var profiles: Array=[[1.0,16],[1.0,20],[1.0,24],[0.8,16],[0.8,20],[0.8,24]]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile="):profiles=[profiles[int(arg.trim_prefix("--profile="))]]
	for profile in profiles:
		monitor_view=false
		await _setup(33)
		stage.set_hints_visible(OS.get_cmdline_user_args().has("--hints"))
		await _step(2)
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--phase="): await _step(int(arg.trim_prefix("--phase=")))
		monitor_view=true
		await _moving_capture("room34_entrance")
		var started:=Engine.get_physics_frames()
		await _moving_main(profile[0],profile[1])
		if failed:return
		_check(stage.completed and respawns==0 and stage.next_bumper==6,"The actual moving route reaches its unique final Goal")
		_check(float(Engine.get_physics_frames()-started)/60<30,"A successful native moving route stays below thirty seconds including its rest")
		print("CANYON_MOVING_SECONDS axis=",profile[0]," gap=",profile[1]," seconds=",float(Engine.get_physics_frames()-started)/60)
		await _moving_capture("room34_goal")
		if failed:return
	monitor_view=false
	_release_inputs()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	print("CANYON_MOVING_ROUTE_TEST_OK ",checks," checks")
	quit()

func _moving_snapshot(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--screenshots"):return
	stage._update_hud()
	RenderingServer.force_draw()
	var directory:="res://docs/screenshots/canyon-moving/"+("hints" if stage.hints_visible else "default")
	DirAccess.make_dir_recursive_absolute(directory)
	_check(root.get_texture().get_image().save_png(directory+"/"+label+".png")==OK,"Save the real moving route phase")

func _moving_capture(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--screenshots"):return
	await process_frame
	RenderingServer.force_draw()
	var directory:="res://docs/screenshots/canyon-moving/"+("hints" if stage.hints_visible else "default")
	DirAccess.make_dir_recursive_absolute(directory)
	_check(root.get_texture().get_image().save_png(directory+"/"+label+".png")==OK,"Save the real moving route")

func _step(count: int=1) -> void:
	for frame in count:
		await super._step()
		if monitor_view and is_instance_valid(stage) and stage.room_index==33 and stage.next_bumper==0 and not stage.transitioning:
			_check_first_reflection()
		if monitor_view and is_instance_valid(stage) and stage.room_index==33 and stage.next_bumper==2:
			_check(stage.target_marker.global_position.distance_to(stage._bumpers().get_child(2).global_position)<0.01,"The actual optional target tracks the moving third reflection")
