extends "res://tests/tower_fifth_route_test.gd"


func _run() -> void:
	var profiles: Array=[[1.0,16],[1.0,20],[1.0,24],[0.8,16],[0.8,20],[0.8,24]]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile="):profiles=[profiles[int(arg.trim_prefix("--profile="))]]
	var first:=31
	var last:=34
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--section="):
			first=int(arg.trim_prefix("--section="))-1
			last=first+1
	for profile in profiles:
		upper_strength=profile[0]
		upper_jump_delay=profile[1]
		upper_dash_delay=profile[1]
		await _fresh_fourth(30 if OS.get_cmdline_user_args().has("--old31") else first)
		_assert_static_checkpoint()
		if OS.get_cmdline_user_args().has("--old31"):
			await _fifth_course(30)
			_check(stage.checkpoint_index==31 and not stage.completed and respawns==0,"The actual former final route lands on CP32")
		for section in range(first,last):
			actions.clear()
			climb_frames=0
			await _application_course(section)
			_check(respawns==0,"Every real application retains its native checkpoint without respawning")
			if section==31:_check(climb_frames>0 and actions.get("creature_jump",0)>0,"The actual bare climb and carried extra jump both contribute")
			if section==32:_check(actions.get("dash",0)>=3,"The actual refill and spring route contribute three Dashes")
			if section==33:_check(actions.get("air_jump",0)==1 and climb_frames>0,"The actual Boot and wall climb both contribute")
			if failed:return
	monitor_view=false
	_release()
	current_scene.queue_free()
	await _step(18)
	print("TOWER_APPLICATION_ROUTE_TEST_OK checks=",checks," observed_frames=",observed_frames)
	quit(1 if failed else 0)


func _fifth_view(phase: String) -> void:
	if phase!="31_completed" and not phase.begins_with("32_") and not phase.begins_with("33_") and not phase.begins_with("34_"):return
	if phase=="31_completed":
		var point: Marker2D=stage.checkpoints.get_child(31)
		_check_next_visible(point.get_global_transform_with_canvas()*Rect2(-108,-52,48,56),"The former summit reveals its actual CP32 flag")
	if phase in ["32_wall","32_carry"]:
		var point: Marker2D=stage.checkpoints.get_child(32)
		_check_next_visible(point.get_global_transform_with_canvas()*Rect2(-108,-52,48,56),"The next CP33 flag remains outside the hint")
		var label: Label=point.get_node("Label")
		_check_next_visible(label.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,label.size),"The next CP33 number remains visible")
	var faces:={"32_entry":["Application32Wall",200],"32_wall":["Application32Rest",550],"32_carry":["Application33Checkpoint",-150],"33_rest":["Application34Checkpoint",200],"34_rest":["Application34Wall",1000],"34_wall":["ApplicationSummit",400],"34_goal":["ApplicationSummit",400]}
	if faces.has(phase):
		var destination: Array=faces[phase]
		var shape: CollisionShape2D=stage.get_node("Terrain/"+destination[0]+"/Collision")
		var face:=shape.shape.get_rect()
		face.position.x=clampf(float(destination[1])-shape.global_position.x-80,face.position.x,face.end.x-160)
		face.size=Vector2(160,minf(16,face.size.y))
		_check_next_visible(shape.get_global_transform_with_canvas()*face,phase+" next static face")
	var items:={"32_wall":"Application32Companion","33_entry":"Application33Dash","33_rest":"Application33Spring","34_entry":"Application34Boot"}
	if items.has(phase):
		var shape: CollisionShape2D=stage.get_node("Items/"+items[phase]+"/CollisionShape2D")
		_check_next_visible(shape.get_global_transform_with_canvas()*shape.shape.get_rect(),phase+" real item")
	if phase=="34_goal":
		for part in ["Case","Cap","Base"]:
			var shape: CollisionShape2D=stage.get_node("Goal/"+part+"/Collision")
			_check_next_visible(shape.get_global_transform_with_canvas()*shape.shape.get_rect(),"The actual last Goal "+part)
	if not OS.get_cmdline_user_args().has("--screenshots"):return
	await process_frame
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots/tower-applications")
	_check(root.get_texture().get_image().save_png("res://docs/screenshots/tower-applications/%s%s.png"%[phase,"_hints" if stage.hints_visible else ""])==OK,"Save the actual application route")
