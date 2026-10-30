extends "res://tests/canyon_inverted_route_test.gd"


func _run() -> void:
	_isolate_collection()
	progress = root.get_node("CollectionProgress")
	var strengths: Array = [0.8] if OS.get_cmdline_user_args().has("--weak") else [1.0,0.8]
	if OS.get_cmdline_user_args().has("--screenshots"): strengths = [1.0]
	for strength in strengths:
		progress._collected.clear()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
		for index in [27,29]:
			var only := 0
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--room="): only=int(arg.trim_prefix("--room="))
			if only>0 and only!=index+1: continue
			await _inverted_trip(index,strength)
			if failed: return
	monitor_view = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	print("CANYON_INVERTED_SCROLL_TEST_OK (",checks," checks)")
	quit()


func _inverted_trip(index: int, strength: float) -> void:
	monitor_view = false
	await _setup(index)
	stage.set_hints_visible(not OS.get_cmdline_user_args().has("--screenshots") or OS.get_cmdline_user_args().has("--hints"))
	monitor_view = true
	var started := Engine.get_physics_frames()
	await _inverted_pickup(strength)
	if failed: return
	_check(_scroll()._follower==player and not _scroll()._secured and not player.is_on_floor(),"The native detour contacts its airborne pending scroll")
	_inverted_snapshot("room%d_scroll_touch" % (index+1))
	var rest: Node2D = stage.rooms.get_child(index).get_node("ScrollRest")
	for frame in 900:
		_entry_horizontal(rest.position.x,strength)
		await _step()
		if player.is_on_floor() and absf(player.position.y-rest.position.y-34)<2 and absf(player.velocity.x)<40: break
		if respawns>0: break
	_release_inputs()
	await _step(20)
	_check(player.is_on_floor() and _scroll()._secured and respawns==0,"The actual static shelf safely secures its own scroll")
	var stopped := player.position
	await _step(180)
	_check(player.is_on_floor() and player.position.distance_to(stopped)<2,"The actual scroll shelf allows three stationary seconds")
	_inverted_branch_preview(index)
	_inverted_snapshot("room%d_scroll_rest" % (index+1))
	if failed: return
	if index==27:
		Input.action_press("move_right",strength)
		await _pulse("jump")
		await _step(20)
		_release_inputs()
		Input.action_press("move_right",strength)
		Input.action_press("move_down")
		await _pulse("dash")
		await _step(10)
		await _inverted_rest("Rest",strength)
	else:
		for frame in 180:
			_entry_horizontal(220,strength)
			await _step()
			if _x()>215 and player.position.y<980: break
		_check(player.gravity_direction<0 and player.position.y<980 and respawns==0,"The inverted branch clears its real ceiling edge before returning upward")
		await _inverted_throw(strength)
		await _inverted_launch(strength)
	_check(respawns==0,"Actual controls return to the original main route without a death")
	print("INV_SCROLL_RETURN room=",index+1," strength=",strength," seconds=",float(Engine.get_physics_frames()-started)/60," p=",Vector2(_x(),player.position.y))
	_inverted_snapshot("room%d_scroll_return" % (index+1))
	if failed: return
	await _inverted_chain(strength)
	_check((stage.completed and respawns==0) if index==stage.rooms.get_child_count()-1 else (stage.transitioning and stage.room_index==index+1 and respawns==1),"The confirmed optional detour rejoins its actual next exit")
	if failed: return


func _inverted_pickup(strength: float, from_rest := false) -> void:
	if stage.room_index==27:
		await _inverted_begin(strength)
		for frame in 1200:
			if stage.next_bumper>=3 or respawns>0: break
			_inverted_steer(strength)
			await _step()
		_check(stage.next_bumper==3 and respawns==0,"The optional inverted detour starts after three native reflections")
		_inverted_optional_preview()
		_inverted_snapshot("room28_scroll_approach")
		if from_rest:
			for frame in 600:
				_entry_horizontal(1030,strength)
				await _step()
				if player.is_on_floor() and absf(player.position.y-1506)<2 and absf(player.velocity.x)<40: break
			_check(player.is_on_floor() and not _scroll()._secured and _scroll()._follower==null and respawns==0,"The real death fixture first reaches the far side of the optional ceiling without pickup")
			for frame in 180:
				_entry_horizontal(970,strength)
				await _step()
				if absf(_x()-970)<5 and absf(player.velocity.x)<30: break
			await _pulse("jump")
		else:
			for frame in 20:
				_entry_horizontal(950,strength)
				await _step()
			_release_inputs()
			Input.action_press("move_left",strength)
			Input.action_press("move_down")
			await _pulse("dash")
	else:
		Input.action_press("wall_grab")
		await _step()
		_check(player.get_held_object()!=null,"The optional wind detour carries the actual entrance parachute")
		for frame in 900:
			_entry_horizontal(180 if player.gravity_direction==1 else 60,strength)
			await _step()
			if player.gravity_direction<0 and player.is_on_floor() and absf(player.position.y-1092)<2 and absf(_x()-60)<20 and absf(player.velocity.x)<40: break
			if respawns>0: break
		_check(player.gravity_direction==-1 and player.is_on_floor() and absf(player.position.y-1092)<2 and respawns==0,"The actual wind and Up gate reach the inverted optional ceiling")
		_inverted_optional_preview()
		_inverted_snapshot("room30_scroll_approach")
		_release_inputs()
		await _pulse("jump")
		await _step(16)
		if not _inverted_scroll_touched():
			Input.action_press("move_down")
			await _pulse("dash")
	for frame in 600:
		if _inverted_scroll_touched() or respawns>0: break
		_entry_horizontal(_scroll().position.x,strength)
		await _step()
	_release_inputs()


func _inverted_scroll_touched() -> bool:
	return _scroll()._follower==player or (_scroll()._secured and _scroll().overlaps_body(player))


func _inverted_visible(bounds: Rect2, label: String) -> void:
	_check(root.get_visible_rect().encloses(bounds),label+" is fully visible: "+str(bounds))
	for path in ["HUD/Info","HUD/Hint","HUD/PauseButton"]:
		var panel: Control = stage.get_node(path)
		_check(not panel.visible or not panel.get_global_rect().intersects(bounds),label+" stays outside "+path)


func _inverted_optional_preview() -> void:
	var room: Node2D = stage.rooms.get_child(stage.room_index)
	for name in ["Scroll","ScrollMark"]:
		var node: Node2D = room.get_node(name)
		_inverted_visible(node.get_global_transform_with_canvas()*Rect2(-16,-20,32,40),"The actual optional "+name)


func _inverted_branch_preview(index: int) -> void:
	var room: Node2D = stage.rooms.get_child(index)
	var path := "Rest/Collision" if index==27 else "Gates/Up/CollisionShape2D"
	var shape: CollisionShape2D = room.get_node(path)
	_inverted_visible(shape.get_global_transform_with_canvas()*shape.shape.get_rect(),"The actual next return landing or gate")
	shape = room.get_node("ScrollRest/Collision")
	_inverted_visible(shape.get_global_transform_with_canvas()*shape.shape.get_rect(),"The actual optional confirmation shelf")
	_inverted_optional_preview()
