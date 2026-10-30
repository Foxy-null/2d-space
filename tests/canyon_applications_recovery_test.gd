extends "res://tests/canyon_applications_route_test.gd"


func _run() -> void:
	_isolate_collection()
	progress=root.get_node("CollectionProgress")
	for index in [30,31,32]:
		monitor_view=false
		await _setup(index)
		await _application_seed(index,"inverted" if index==31 else "resource")
		if failed:return
		await _pulse("reset")
		await _step(12)
		_application_checkpoint(index,1)
		if failed:return
		var before_death:=1
		if index==31:
			await _application_seed(index)
			if failed:return
			await _pulse("reset")
			await _step(12)
			before_death=2
			_application_checkpoint(index,before_death)
		await _application_seed(index)
		_release_inputs()
		Input.action_press("move_left",0.8)
		for frame in 600:
			if respawns>before_death:break
			await _step()
		_release_inputs()
		await _step(12)
		_application_checkpoint(index,before_death+1)
		if failed:return
		stage.set_hints_visible(true)
		monitor_view=true
		await _applications_main(0.8,24)
		monitor_view=false
		_check((stage.completed and respawns==before_death+1) if index==stage.rooms.get_child_count()-1 else (stage.transitioning and stage.room_index==index+1 and respawns==before_death+2),"A real weak-input replay reaches its own exit after R and death")
		if failed:return
	# Actual transfers preserve the preceding room's real item/resource consequences.
	await _setup(29)
	stage.set_hints_visible(true)
	monitor_view=true
	await _inverted_main(0.8,24)
	_check(stage.transitioning and stage.room_index==30 and respawns==1,"The former final room reaches the actual boots checkpoint")
	await _step(25)
	for index in [30,31,32]:
		var before:=respawns
		await _applications_main(0.8,24)
		if failed:return
		_check((stage.completed and respawns==before) if index==stage.rooms.get_child_count()-1 else (stage.transitioning and stage.room_index==index+1 and respawns==before+1),"The integrated weak-input route uses normal transfers")
		if index<32:await _step(25)
		if failed:return
	_check(progress.get_count("canyon")==0,"The integrated main route leaves all optional scrolls untouched")
	monitor_view=false
	for lane in [300.0,1500.0,2100.0]:
		await _setup(31)
		var room:Node2D=stage.rooms.get_child(31)
		var barrier:Area2D=room.get_node("Hazards/ExitUpper")
		var hits:Array[bool]=[]
		barrier.player_hit.connect(func():hits.append(true))
		# Only this isolated hazard fixture sets position/gravity; the replays above do not.
		player.global_position=room.global_position+Vector2(3550,lane)
		player.set_gravity_direction(-1)
		player.velocity=Vector2.ZERO
		player._contacts_valid=false
		Input.action_press("move_right")
		await _pulse("dash")
		for frame in 60:
			if respawns>0:break
			await _step()
		_release_inputs()
		await _step(12)
		_check(hits.size()==1 and not stage.transitioning and not stage.completed,"The visible full-height barrier creates one real spike hit at this lane")
		_application_checkpoint(31,1)
		if failed:return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	print("CANYON_APPLICATIONS_RECOVERY_TEST_OK ",checks," checks")
	quit()


func _application_seed(index:int, phase:String="resource") -> void:
	match index:
		30:await _applications_boots_begin(0.8,24)
		31:
			if phase=="inverted": await _inverted_begin(0.8)
			else:
				await _applications_relay_begin(0.8,24)
				if failed:return
				await _applications_relay_refill(0.8,24)
		32:await _entry_begin(0.8)


func _application_checkpoint(index:int, expected:int) -> void:
	var room:Node2D=stage.rooms.get_child(index)
	_check(respawns==expected and stage.room_index==index and stage.next_bumper==0,"Only this native checkpoint and route guide reset")
	_check(player.global_position.distance_to(room.get_node("Spawn").global_position)<8 and player.is_on_floor() and player.controls_enabled,"The actual native entrance supports a controllable player")
	_check(player.gravity_direction==1 and player.is_dash_ready() and is_equal_approx(player.get_wall_stamina(),player.wall_stamina_max),"R and actual death restore normal gravity, Dash and wall stamina")
	if index==30:
		_check(room.get_node("Items/Boots")._available and not player.is_air_jump_ready(),"The same actual boots reset without a granted air jump")
	if index==31: _check(room.get_node("Items/Refill")._available,"The real consumed middle refill is immediately available after R or death")
