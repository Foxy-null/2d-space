extends "res://tests/canyon_entry_scroll_test.gd"


func _run() -> void:
	_isolate_collection()
	progress = root.get_node("CollectionProgress")
	var strengths: Array = [1.0,0.8]
	if OS.get_cmdline_user_args().has("--strong") or OS.get_cmdline_user_args().has("--screenshots"): strengths=[1.0]
	if OS.get_cmdline_user_args().has("--weak"): strengths=[0.8]
	for strength in strengths:
		progress._collected.clear()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
		for index in [30,32]:
			var selected := 0
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--room="): selected=int(arg.trim_prefix("--room="))
			if selected>0 and selected!=index+1: continue
			await _application_lifecycle(index,strength)
			if failed: return
	monitor_view=false
	_release_inputs()
	if OS.get_cmdline_user_args().has("--keep-fixture"): print("CANYON_APPLICATIONS_SAVED_PATH ",progress.save_path)
	else: DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	print("CANYON_APPLICATIONS_SCROLL_TEST_OK ",checks," checks")
	quit()


func _application_lifecycle(index: int, strength: float) -> void:
	var id := "boots_loft_10" if index==30 else "wall_loft_11"
	var count: int = progress.get_count("canyon")
	if not OS.get_cmdline_user_args().has("--branch-only") and not OS.get_cmdline_user_args().has("--screenshots"):
		for interruption in ["retry","death","leave"]:
			await _entry_setup(index)
			await _entry_pickup(strength)
			if failed: return
			_check(_scroll()._follower==player and not _scroll()._secured and not player.is_on_floor(),"The real interrupted pickup is airborne and pending")
			monitor_view=false
			if interruption=="retry":
				await _pulse("reset")
				await _step(6)
			elif interruption=="death": await _application_die()
			else:
				stage.get_node("PauseMenu").return_to_select()
				await _step(4)
			if interruption!="leave":
				_check(_scroll()._follower==null and _scroll().global_position==_scroll()._origin,"The actual interruption restores the native scroll")
			_check(progress.get_count("canyon")==count and not progress.has_scroll("canyon",id),"A pending interruption never writes its ID")
			if failed: return
	await _entry_setup(index)
	var started := Engine.get_physics_frames()
	await _entry_pickup(strength)
	if failed: return
	await _capture("room%d_scroll_touch"%(index+1))
	await _entry_scroll_land(strength)
	if failed: return
	_check(progress.has_scroll("canyon",id) and respawns==0,"The actual optional static shelf secures this scroll")
	var stopped := player.position
	await _step(180)
	_check(player.is_on_floor() and player.position.distance_to(stopped)<2 and respawns==0,"The confirmed optional shelf stays safe for three seconds")
	_application_preview()
	await _capture("room%d_scroll_rest"%(index+1))
	if failed: return
	if index==30:
		await _land_at_wide_rest(strength)
	else:
		await _pulse("jump")
		for frame in 20:
			_entry_horizontal(1740,strength)
			await _step()
		_release_inputs()
		Input.action_press("move_right",strength)
		Input.action_press("move_up")
		await _pulse("dash")
		for frame in 600:
			_steer_to(Vector2(1740,774),false,strength)
			await _step()
			if player.is_on_floor() and absf(player.position.y-774)<2 and absf(_x()-1740)<30: break
			if respawns>0: break
		_release_inputs()
		_check(player.is_on_floor() and absf(player.position.y-774)<2 and respawns==0,"The upper optional branch returns onto the same real rock top")
	var seconds := float(Engine.get_physics_frames()-started)/60
	print("APPLICATION_SCROLL_RETURN room=",index+1," axis=",strength," seconds=",seconds)
	_check(seconds<30,"Entrance, optional collection and actual return stay below thirty seconds")
	await _capture("room%d_scroll_return"%(index+1))
	if failed: return
	if index==30:
		await _repeat_wide_third(strength,20)
		await _entry_finish(strength)
	else: await _applications_wall_finish(strength,20)
	_release_inputs()
	_check((stage.completed and respawns==0) if index==32 else (stage.transitioning and stage.room_index==31 and respawns==1),"The confirmed detour rejoins its own main exit")
	if failed: return
	if OS.get_cmdline_user_args().has("--branch-only"): return
	await _entry_setup(index)
	_check(_scroll()._secured and _scroll().modulate.a<1,"A revisit displays the faint confirmed native scroll")
	await _pulse("reset")
	await _step(6)
	_check(progress.get_count("canyon")==count+1,"R preserves the confirmed collection")
	monitor_view=false
	await _application_die()
	_check(progress.get_count("canyon")==count+1 and stage.room_index==index and player.is_dash_ready(),"Actual death preserves collection and resets this checkpoint")
	await _entry_setup(index)
	await _entry_pickup(strength)
	_check(_scroll()._secured and _scroll()._follower==null and _scroll().overlaps_body(player),"Real controls recontact the faint marker without a second follower")
	_check(progress.get_count("canyon")==count+1,"Recontact never duplicates its saved ID")
	monitor_view=false
	stage.get_node("PauseMenu").return_to_select()
	await _step(4)
	var card: Button=current_scene.get_node("Margin/Content/Stages/Stage5")
	var expected:="%d / 11"%(count+1)
	_check(card.get_node("Content/Collection/Count").text==expected and card.accessibility_name.contains("巻物 "+expected),"Selection displays and announces the actual saved count")
	await _capture("room%d_scroll_selection"%(index+1))
	progress._collected.clear()
	progress.load_progress()
	_check(progress.get_count("canyon")==count+1 and progress.has_scroll("canyon",id),"A real reload preserves the unfinished-stage collection")


func _entry_pickup(strength: float, _from_rest := false) -> void:
	monitor_view=true
	if stage.room_index==30:
		await _applications_boots_begin(strength,20)
		for frame in 1200:
			if stage.next_bumper>=3 or respawns>0: break
			_steer(strength)
			await _step()
		_check(stage.next_bumper==3 and respawns==0,"The boots branch starts after its actual extra jump and three reflections")
	else:
		await _applications_wall_begin(strength,20)
		await _pulse("jump")
	if failed: return
	await _capture("room%d_scroll_approach"%(stage.room_index+1))
	for frame in 600:
		if _application_touched() or respawns>0: break
		_steer_to(_scroll().position,false,strength)
		await _step()
	_release_inputs()
	_check(_application_touched() and respawns==0,"Actual controls contact the optional airborne native scroll")


func _application_touched() -> bool:
	return _scroll()._follower==player or (_scroll()._secured and _scroll().overlaps_body(player))


func _application_die() -> void:
	var before := respawns
	_release_inputs()
	Input.action_press("move_left")
	Input.action_press("move_down")
	if player.is_dash_ready(): await _pulse("dash")
	for frame in 900:
		if respawns>before: break
		_release_inputs()
		Input.action_press("move_left")
		if player.is_on_floor() and _scroll()._follower==player: Input.action_press("jump")
		await _step()
	_release_inputs()
	await _step(6)
	_check(respawns==before+1,"Normal controls encounter a real death without moving the fixture")


func _application_preview() -> void:
	var room: Node2D=stage.rooms.get_child(stage.room_index)
	var shape: CollisionShape2D=room.get_node("Rest/Collision" if stage.room_index==30 else "ClimbWall/Collision")
	var bounds: Rect2=shape.get_global_transform_with_canvas()*shape.shape.get_rect()
	if stage.room_index==32: bounds.size.y=16
	_application_visible(bounds,"The next actual return landing")
	shape=room.get_node("ScrollRest/Collision")
	_application_visible(shape.get_global_transform_with_canvas()*shape.shape.get_rect(),"The real optional shelf")


func _application_visible(bounds: Rect2, label: String) -> void:
	_check(root.get_visible_rect().encloses(bounds),label+" is wholly visible: "+str(bounds))
	for path in ["HUD/Info","HUD/Hint","HUD/PauseButton"]:
		var panel: Control=stage.get_node(path)
		_check(not panel.visible or not panel.get_global_rect().intersects(bounds),label+" remains outside "+path)


func _capture(label: String) -> void:
	# The main route owns entrance images after applying the hint setting.
	if label.ends_with("_entrance"): return
	if label.ends_with("_approach"):
		var room: Node2D=stage.rooms.get_child(stage.room_index)
		for name in ["Scroll","ScrollMark"]:
			var node: Node2D=room.get_node(name)
			_application_visible(node.get_global_transform_with_canvas()*Rect2(-22,-22,44,44),"The actual optional "+name)
	if not OS.get_cmdline_user_args().has("--screenshots"): return
	await process_frame
	RenderingServer.force_draw()
	var directory:="res://docs/screenshots/canyon-applications/"+("hints" if OS.get_cmdline_user_args().has("--hints") else "default")
	DirAccess.make_dir_recursive_absolute(directory)
	_check(root.get_texture().get_image().save_png(directory+"/"+label+".png")==OK,"The actual native optional image is saved")
