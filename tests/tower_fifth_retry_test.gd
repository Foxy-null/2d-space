extends "res://tests/tower_fifth_route_test.gd"

func _run() -> void:
	upper_strength=0.8
	upper_jump_delay=20
	upper_dash_delay=20
	var first:=25
	var last:=31
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--section="):
			first=int(arg.trim_prefix("--section="))-1
			last=first+1
	for section in range(first,last):
		await _fresh_fourth(section)
		stage.set_hints_visible(true)
		_assert_static_checkpoint()
		if section==29:
			await _fifth30_lower()
			await _wind_rise(-2200,-36800)
			_check(player._winds.has(stage.get_node("Items/Fifth30Wind").get_instance_id()) and player.get_held_object()==stage.get_node("Items/Fifth30Parachute"),"R preparation really holds the same native parachute inside its live updraft")
		else:
			if section==25:
				await _more_walk(-900)
				await _more_grab("Fifth26Companion")
			await _upper_pulse("jump")
			await _step(8)
			await _upper_dash()
			await _step(4)
		await _upper_pulse("reset")
		_release()
		await _step(8)
		_check(respawns==1 and stage.checkpoint_index==section,"An actual moving R returns once to the same new checkpoint")
		_check(player.is_on_floor() and player.position.distance_to(player._spawn_position)<3 and player.is_dash_ready() and player.get_wall_stamina()>2.9,"R restores the real static floor and movement resources")
		_assert_static_checkpoint()
		_check(player._winds.is_empty() and player.get_held_object()==null,"R clears the old wind registrations and carried native object")
		monitor_view=false
		var fall_direction: String="move_left" if section==25 else "move_right"
		Input.action_press(fall_direction,upper_strength)
		Input.action_press("move_down")
		await _upper_pulse("dash")
		for frame in 720:
			Input.action_press(fall_direction,upper_strength)
			await _step()
			if respawns>1:break
		_release()
		await _step(8)
		_check(respawns==2 and stage.checkpoint_index==section and player.is_on_floor() and player.position.distance_to(player._spawn_position)<3,"Actual controls leave the native floor and fall once back to the same checkpoint")
		if failed:return
		_check(player.is_dash_ready() and player.get_wall_stamina()>2.9 and player.get_held_object()==null,"Real death restores resources and native objects")
		monitor_view=true
		await _fifth_course(section)
		_check(respawns==2 and root.get_node("CollectionProgress").get_count("tower")==0,"The restored real course replays without a fall or an optional pickup")
		if section==30:_check(stage.completed and stage.get_node("Goal").is_pressed(),"The replay physically presses the unique final Goal")
		print("FIFTH_RETRY_NATIVE section=",section+1," resets=1 falls=1")
	monitor_view=false
	_release()
	current_scene.queue_free()
	await _step(18)
	print("TOWER_FIFTH_RETRY_TEST_OK checks=",checks)
	quit(1 if failed else 0)
