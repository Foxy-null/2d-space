extends "res://tests/tower_fourth_route_test.gd"

func _run() -> void:
	upper_strength=0.8
	upper_jump_delay=20
	upper_dash_delay=20
	for section in range(19,25):
		actions.clear()
		await _fresh_fourth(section)
		stage.set_hints_visible(true)
		await _upper_pulse("jump")
		await _step(8)
		await _upper_dash()
		await _step(4)
		await _upper_pulse("reset")
		_release()
		await _step(8)
		_check(respawns==1 and stage.checkpoint_index==section,"An actual R during movement restores the same new checkpoint exactly once")
		_check(player.is_on_floor() and player.position.distance_to(player._spawn_position)<3 and player.is_dash_ready() and player.get_wall_stamina()>2.9,"R restores the real safe floor and movement resources")
		monitor_view=false
		Input.action_press("move_right",upper_strength)
		Input.action_press("move_down")
		await _upper_pulse("dash")
		for frame in 720:
			Input.action_press("move_right",upper_strength)
			await _step()
			if respawns>1:break
		_release()
		await _step(8)
		_check(respawns==2 and stage.checkpoint_index==section and player.is_on_floor() and player.position.distance_to(player._spawn_position)<3,"Actual input off the native floor causes one real fall back to the same checkpoint")
		_check(player.is_dash_ready() and player.get_wall_stamina()>2.9 and player.get_held_object()==null,"The real fall restores resources and objects without injecting physics state")
		monitor_view=true
		await _fourth_course(section)
		_check(respawns==2 and root.get_node("CollectionProgress").get_count("tower")==0,"The restored native course can be replayed without a fall or optional collection")
		if section==24:_check(stage.checkpoint_index==25 and not stage.completed,"The replay physically reaches the new CP26 without completing the new summit")
		print("FOURTH_RETRY_NATIVE section=",section+1," resets=1 falls=1 next_cp=",stage.checkpoint_index+1)
	monitor_view=false
	_release()
	current_scene.queue_free()
	await _step(18)
	print("TOWER_FOURTH_RETRY_TEST_OK checks=",checks)
	quit(1 if failed else 0)
