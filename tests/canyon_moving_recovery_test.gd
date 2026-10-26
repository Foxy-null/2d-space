extends "res://tests/canyon_moving_route_test.gd"

func _run() -> void:
	_isolate_collection()
	progress=root.get_node("CollectionProgress")
	monitor_view=false
	await _setup(33)
	stage.set_hints_visible(true)
	if OS.get_cmdline_user_args().has("--phases-only"):
		await _moving_phases()
		return
	var room:Node2D=stage.rooms.get_child(33)
	var moving:Node2D=room.get_node("Bumpers/Bumper3")
	var minimum:=INF
	var maximum:=-INF
	for frame in 193:
		await _step()
		minimum=minf(minimum,moving.position.x)
		maximum=maxf(maximum,moving.position.x)
		_check(room.get_node("Route").points[3].distance_to(moving.position)<0.01,"The actual moving reflection and optional route line agree every physics frame")
		_check(player.is_on_floor() and respawns==0,"The native entrance permits a full safe motion cycle")
		if failed:return
	_check(maximum-minimum>140,"The real third reflection traverses its visible rail")
	await _key(KEY_ESCAPE)
	var paused_position:=moving.position
	await _step(24)
	_check(paused and moving.position==paused_position,"The actual Pause menu stops native reflection motion")
	await _key(KEY_ESCAPE)
	await _step(6)
	_check(not paused and moving.position!=paused_position,"Closing Pause resumes the same live animation")
	await _moving_first(0.8)
	await _land_at_wide_rest(0.8)
	for frame in 240:
		_entry_horizontal(1840,0.8)
		await _step()
		if absf(_x()-1840)<5 and absf(player.velocity.x)<15:break
	await _pulse("jump")
	for frame in 32:
		_entry_horizontal(1840,0.8)
		await _step()
		if not room.get_node("Items/Boots")._available:break
	_check(not room.get_node("Items/Boots")._available and player.is_air_jump_ready(),"Recovery starts immediately after actual Boot consumption")
	if failed:return
	await _pulse("reset")
	await _step(12)
	_moving_checkpoint(1)
	if failed:return
	await _moving_first(0.8)
	_release_inputs()
	Input.action_press("move_left",0.8)
	for frame in 900:
		if respawns>1:break
		await _step()
	_release_inputs()
	await _step(12)
	_moving_checkpoint(2)
	if failed:return
	stage.set_hints_visible(true)
	monitor_view=true
	await _moving_main(0.8,24)
	_check(stage.completed and respawns==2,"The weak actual replay reaches Goal after R and real death")
	if failed:return
	monitor_view=false
	await _setup(32)
	stage.set_hints_visible(true)
	monitor_view=true
	await _applications_main(0.8,24)
	_check(stage.transitioning and stage.room_index==33 and respawns==1,"The former final room transfers into the new native checkpoint")
	await _step(25)
	await _moving_main(0.8,24)
	_check(stage.completed and respawns==1,"The real old-to-new transfer reaches the unique Goal without extra death")
	if failed:return
	monitor_view=false
	_release_inputs()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	print("CANYON_MOVING_RECOVERY_TEST_OK ",checks," checks")
	quit()

func _moving_checkpoint(expected:int) -> void:
	var room:Node2D=stage.rooms.get_child(33)
	_check(respawns==expected and stage.room_index==33 and stage.next_bumper==0,"Only the current real checkpoint resets")
	_check(player.global_position.distance_to(room.get_node("Spawn").global_position)<8 and player.is_on_floor() and player.controls_enabled,"The actual entrance supports a controllable player after recovery")
	_check(player.is_dash_ready() and player.gravity_direction==1 and not player.is_air_jump_ready(),"Actual recovery restores Dash and normal gravity without granting Boot")
	_check(room.get_node("Items/Boots")._available,"The same consumed Boot is immediately available after R and death")

func _moving_phases() -> void:
	for strength in [1.0,0.8]:
		for phase in [0,48,96,144]:
			monitor_view=false
			await _setup(33)
			stage.set_hints_visible(true)
			await _step(phase)
			monitor_view=true
			await _moving_first(strength)
			if failed:return
			await _land_at_wide_rest(strength)
			_release_inputs()
			await _step(180)
			_check(player.is_on_floor() and respawns==0,"Each real quarter-cycle phase reaches a safe three-second rest")
			if failed:return
	monitor_view=false
	_release_inputs()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	print("CANYON_MOVING_PHASES_TEST_OK ",checks," checks")
	quit()
