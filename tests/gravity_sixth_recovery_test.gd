extends "res://tests/gravity_sixth_route_test.gd"


func _run() -> void:
	progress = root.get_node("CollectionProgress")
	progress.save_path = "user://gravity_sixth_recovery_%d.cfg" % OS.get_process_id()
	progress._collected.clear()
	for arg in OS.get_cmdline_user_args(): _check(arg in ["--hints","--seams-only"],"Use a known recovery argument")
	if not args_have("--seams-only"):
		await _sixth_immediate_resource_retry()
		for index in range(31,37):
			await _sixth_fresh(index)
			await _sixth_entry(index)
			await _retry()
			var room: Node2D = stage.rooms.get_child(index)
			_check(respawns==1 and player.get_held_object()==null and player.position.distance_to(room.get_node("Spawn").global_position)<5,"Mid-course R releases the object and returns to the actual native checkpoint")
			await _sixth_contact_death(index)
			actions.clear()
			flips.clear()
			monitor_view = true
			var before := respawns
			await _sixth_course(index)
			_check(respawns==before and stage.cleared.has(index),"The actual six-link course remains playable after native spike death")
			await _retry()
			_check(stage.cleared.has(index) and room.get_node("Goal").is_pressed() and stage.completed==(index==36),"Confirmed R preserves the actual arrival and only room37 completes the stage")
	await _sixth_seams()
	monitor_view = false
	_release_inputs()
	current_scene.queue_free()
	await _step(5)
	if FileAccess.file_exists(progress.save_path): DirAccess.remove_absolute(progress.save_path)
	print("GRAVITY_SIXTH_RECOVERY_TEST_%s %d checks" % ["FAILED" if failed else "OK",checks])
	quit(1 if failed else 0)


func _sixth_contact_death(index: int) -> void:
	monitor_view = false
	var before := respawns
	var hits := [0]
	for area in stage.rooms.get_child(index).find_children("*","Area2D",true,false):
		if area is SpikeBlock: area.player_hit.connect(func(): hits[0]+=1,CONNECT_ONE_SHOT)
	if index==31:
		_para_drive(450)
		await _jump()
		await _para_walk(450)
		_para_drive(550)
	elif index==35:
		await _para_walk(70)
		await _jump()
	else:
		_para_drive(500 if index in [34,36] else 1200)
		if index==34: await _jump()
	await _until(func(): return respawns>before,1000,"Actual movement reaches a native side, ceiling or lower spike")
	_release_inputs()
	await _step(4)
	_check(hits[0]>0 and respawns==before+1 and player.position.distance_to(player._spawn_position)<5,"One real swept spike contact restores the same checkpoint exactly once")
	_check(player.gravity_direction==1 and player.is_dash_ready() and player.get_held_object()==null,"Real contact death restores gravity, Dash and the held-object state")


func _sixth_seams() -> void:
	await _sixth_fresh(30)
	_fifth_connect()
	_check_sixth_returns()
	await _fifth_course(30)
	_check(not stage.completed,"The actual former room31 final remains intermediate")
	_para_drive(2350)
	await _until(func(): return stage.room_index==31,180,"Walk through the real old31/new32 exit")
	_release_inputs()
	await _step(25)
	for index in range(31,37):
		actions.clear()
		flips.clear()
		_check(stage.room_index==index and player.gravity_direction==1 and player.is_dash_ready() and player.get_held_object()==null and player.controls_enabled,"The real forward transfer restores this room's native entrance and resources")
		await _sixth_course(index)
		if index<36:
			_para_drive(2350)
			await _until(func(): return stage.room_index==index+1,180,"Walk through each actual new forward boundary")
			_release_inputs()
			await _step(25)
	_check(stage.completed and stage.cleared.size()==7,"Only the actual room37 final completes this continuous old31-plus-six course")
	for index in range(36,30,-1):
		var before := respawns
		for frame in 900:
			if stage.room_index==index-1: break
			_para_drive(-20)
			if player.is_on_floor() and player.is_on_wall(): await _jump()
			await _step()
		_release_inputs()
		await _step(25)
		_check(stage.room_index==index-1 and stage.cleared.has(index-1) and not stage.transitioning and player.controls_enabled and respawns==before+1 and not stage.get_node("HUD/Completion").visible,"Each opened left return makes one normal transfer to the preceding right entrance")
		var entrance: Marker2D = stage.rooms.get_child(index-1).get_node("Return")
		_check(player.position.distance_to(entrance.global_position)<5,"The actual left transfer stays at its real Return after twenty-five frames")
		await _retry()
		_check(player.position.distance_to(entrance.global_position)<5 and player.gravity_direction==1,"R after a physical left transfer uses the preceding native Return")
	_check(progress.get_count("gravity")==0,"The complete mandatory seam route leaves all ten native scrolls untouched")


func _check_sixth_returns() -> void:
	var shape: CollisionShape2D = player.get_node("CollisionShape2D")
	for index in range(31,37):
		var room: Node2D = stage.rooms.get_child(index)
		var marker: Marker2D = room.get_node("Return")
		var bounds := shape.shape.get_rect()
		bounds.position += marker.global_position
		for part in ["Base","Case","Cap"]:
			var body: CollisionShape2D = room.get_node("Goal/%s/Collision" % part)
			var goal_bounds := Rect2(body.global_transform*body.shape.get_rect().position,body.shape.get_rect().size)
			_check(not bounds.intersects(goal_bounds),"Every new Return clears the actual Goal body: room%d %s" % [index+1,part])


func _sixth_immediate_resource_retry() -> void:
	for index in [33,35]:
		await _sixth_fresh(index)
		monitor_view = false
		var room: Node2D = stage.rooms.get_child(index)
		var resource: Area2D = room.get_node("Boots" if index==33 else "DashCrystal")
		if index==33:
			await _para_walk(1720)
		else:
			await _sixth_entry(index)
			await _para_walk(830)
			_para_drive(1100)
			await _jump()
			await _step(20)
			await _para_dash(Vector2(1,1))
			await _until(func(): return actions.get("sixth_crystal",0)>0,60,"The actual first diagonal Dash consumes the real Crystal")
		_check(not resource._available and resource._respawn_left>0,"The real pickup is still consumed before its automatic respawn timer")
		var consumed := Engine.get_physics_frames()
		await _retry()
		await _step(2)
		_check(Engine.get_physics_frames()-consumed<150 and resource._available and resource._respawn_left==0 and resource.visible and resource.monitoring and not resource.get_node("CollisionShape2D").disabled,"Immediate R restores the same native resource before the 2.5-second automatic reappearance")
		_check(player.position.distance_to(room.get_node("Spawn").global_position)<5 and player.is_dash_ready() and not player.is_air_jump_ready(),"Resource retry restores the actual checkpoint and clears spent extra-Jump state")
