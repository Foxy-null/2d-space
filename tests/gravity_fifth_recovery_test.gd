extends "res://tests/gravity_fifth_route_test.gd"


func _run() -> void:
	progress = root.get_node("CollectionProgress")
	progress.save_path = "user://gravity_fifth_recovery_%d.cfg" % OS.get_process_id()
	progress._collected.clear()
	if not OS.get_cmdline_user_args().has("--seams-only"):
		for index in range(25,31):
			await _fresh_para(index)
			_fifth_connect()
			await _fifth_entry(index)
			await _retry()
			var room: Node2D = stage.rooms.get_child(index)
			_check(respawns==1 and player.get_held_object()==null and player.position.distance_to(room.get_node("Spawn").global_position)<5, "Actual R releases the object and returns to this native checkpoint")
			_check(player.gravity_direction==1 and player.is_dash_ready(), "R restores normal gravity and Dash")
			await _fifth_contact_death(index)
			actions.clear()
			flips.clear()
			monitor_view = true
			var before := respawns
			await _fifth_course(index)
			_check(respawns==before and stage.cleared.has(index), "The full course remains playable after the actual contact death")
			await _retry()
			_check(stage.cleared.has(index) and room.get_node("Goal").is_pressed() and stage.completed==(index==stage.rooms.get_child_count()-1), "R keeps the real arrival; only the actual final room completes the stage")
	await _fifth_seams()
	monitor_view = false
	_release_inputs()
	current_scene.queue_free()
	await _step(5)
	if FileAccess.file_exists(progress.save_path): DirAccess.remove_absolute(progress.save_path)
	print("GRAVITY_FIFTH_RECOVERY_TEST_%s %d checks" % ["FAILED" if failed else "OK",checks])
	quit(1 if failed else 0)


func _fifth_contact_death(index: int) -> void:
	monitor_view = false
	var room: Node2D = stage.rooms.get_child(index)
	var before := respawns
	var hits := [0]
	for area in room.find_children("*","Area2D",true,false):
		if area is SpikeBlock: area.player_hit.connect(func(): hits[0]+=1,CONNECT_ONE_SHOT)
	if index==25:
		await _para_walk(70)
		await _jump()
	else:
		_para_drive(1000 if index in [26,28] else (1500 if index==30 else 900))
	await _until(func(): return respawns>before,650,"Real movement reaches a native side, ceiling or pit spike")
	_release_inputs()
	await _step(4)
	_check(hits[0]>0 and respawns==before+1 and player.position.distance_to(player._spawn_position)<5, "An actual swept spike collision restores the same checkpoint exactly once")
	_check(player.gravity_direction==1 and player.is_dash_ready() and player.get_held_object()==null, "Contact death restores gravity, Dash and held-object state")


func _fifth_seams() -> void:
	await _fresh_para(24)
	_check_fifth_return_markers()
	monitor_view = false
	await _para_course(24)
	_check(not stage.completed,"The former room25 final remains intermediate after its actual route")
	await _cross_room_boundary()
	_fifth_connect()
	for index in range(25,31):
		actions.clear()
		flips.clear()
		_check(stage.room_index==index and player.gravity_direction==1 and player.is_dash_ready() and player.get_held_object()==null and player.controls_enabled, "A real forward transfer restores this room's resources and native entrance")
		await _fifth_course(index)
		if index<30:
			await _cross_room_boundary()
	_check(not stage.completed and stage.cleared.size()==7,"The actual old25-plus-six route stays intermediate before the new room32")
	for index in range(30,24,-1):
		var before_transfer := respawns
		await _cross_room_boundary(false)
		_check(stage.room_index==index-1 and stage.cleared.has(index-1) and not stage.transitioning and player.controls_enabled and respawns==before_transfer+1 and not stage.get_node("HUD/Completion").visible, "Every entrance-side return reaches the preceding arrival checkpoint and hides completion")
		await _retry()
		_check(player.position.distance_to(player._spawn_position)<5 and player.gravity_direction==1, "Retry after physical backtracking uses the preceding room's native Return marker")


func _check_fifth_return_markers() -> void:
	var shape: CollisionShape2D = player.get_node("CollisionShape2D")
	for index in range(25,31):
		var room: Node2D = stage.rooms.get_child(index)
		var arrival: Marker2D = room.get_node("Return")
		var bounds := shape.shape.get_rect()
		bounds.position += arrival.global_position
		for part in ["Base","Case","Cap"]:
			var body: CollisionShape2D = room.get_node("Goal/%s/Collision" % part)
			var goal_bounds := Rect2(body.global_transform*body.shape.get_rect().position,body.shape.get_rect().size)
			_check(not bounds.intersects(goal_bounds),"Every new native Return marker clears the actual Goal body: room%d %s" % [index+1,part])
