extends "res://tests/gravity_parachute_route_test.gd"


func _run() -> void:
	progress=root.get_node("CollectionProgress")
	progress.save_path="user://gravity_para_recovery_%d.cfg"%OS.get_process_id()
	progress._collected.clear()
	for index in [21,22,23,24]:
		await _fresh_para(index)
		await _para_start(index)
		await _key(KEY_R)
		var room: Node2D=stage.rooms.get_child(index)
		_check(respawns==1 and player.position.distance_to(room.get_node("Spawn").global_position)<5 and player.get_held_object()==null,"Actual R returns to the unchanged native entrance and releases the Parachute")
		_check(player.gravity_direction==1 and player.is_dash_ready(),"R restores normal gravity and Dash")
		monitor_view=false
		var hits:=[0]
		for spike in room.find_children("*","Area2D",true,false):
			if spike is SpikeBlock:spike.player_hit.connect(func():hits[0]+=1)
		_para_drive(1850 if index==22 else (1500 if index==23 else 950))
		await _until(func():return respawns>1,480,"Actual movement reaches a native pit or wall spike")
		_release_inputs()
		await _step(4)
		_check(hits[0]>0 and player.position.distance_to(room.get_node("Spawn").global_position)<5,"A real swept spike hit restores the same checkpoint")
		monitor_view=true
		var previous:=respawns
		await _para_course(index)
		_check(respawns==previous and stage.cleared.has(index),"The complete route remains playable after real death")
		await _key(KEY_R)
		_check(stage.cleared.has(index) and room.get_node("Goal").is_pressed(),"R preserves a physically pressed arrival")
		_check(not stage.completed,"All four retained umbrella additions remain intermediate before the actual final room")
	await _seams()
	monitor_view=false
	_release_inputs()
	current_scene.queue_free()
	await _step(5)
	if FileAccess.file_exists(progress.save_path):DirAccess.remove_absolute(progress.save_path)
	print("GRAVITY_PARACHUTE_RECOVERY_TEST_OK %d checks"%checks)
	quit()


func _seams() -> void:
	await _fresh_para(20)
	monitor_view=false
	await _third_course(20)
	_check(not stage.completed and stage.cleared.has(20),"The actual former final arrival is now intermediate")
	_para_drive(2350)
	await _until(func():return stage.room_index==21,200,"Cross the real old21/new22 boundary")
	_release_inputs()
	await _step(25)
	_check(not stage.transitioning and player.controls_enabled and player.gravity_direction==1,"The transition tween returns normal input at the new entrance")
	var creature: Grabbable=stage.rooms.get_child(21).get_node("Parachute")
	var home:=creature.global_position
	await _para_grab()
	_para_drive(-10)
	await _until(func():return stage.room_index==20,200,"Carry the actual new Parachute to the old room's left-return boundary")
	_release_inputs()
	await _step(25)
	_check(player.get_held_object()==null and creature.global_position.distance_to(home)<5,"Normal native transfer resets the same carried object at its home; no predecessor carry is injected")
	_check(stage.cleared.has(20) and not stage.completed,"Old completion remains intermediate after returning left")
	_para_drive(2350)
	await _until(func():return stage.room_index==21,200,"Re-enter the new room through the old opened exit")
	_release_inputs()
	await _step(25)
	await _para_course(21)
	_para_drive(2350)
	await _until(func():return stage.room_index==22,200,"The newly cleared first addition connects to the right-entry left-facing room")
	_release_inputs()
	await _step(25)
	_check(absf(_para_x()-2232)<5 and player.gravity_direction==1 and player.controls_enabled,"The second addition really spawns at its native right entrance")
	await _para_course(22)
	for frame in 700:
		if stage.room_index==21:break
		_para_drive(-10)
		if player.is_on_floor() and player.is_on_wall():await _jump()
		await _step()
	_release_inputs()
	await _step(25)
	_check(stage.room_index==21 and stage.cleared.has(21) and stage.cleared.has(22),"The opened left-facing room naturally returns through its left boundary and preserves both arrivals")
